# TimeScaleDirector — Stacked-Request Ownership of `Engine.time_scale`

> **STATUS — Landed on `main` via PR #285 (merge commit `9efcfc8`, 2026-05-20).** This doc captures the design contract semantically; before writing any caller code, verify exact GDScript signatures against `scripts/combat/TimeScaleDirector.gd`. Tess approved on a respin that fixed a Dict-value-equality bug in the generation-token guard (Devon switched to a monotonic int counter).

## What this is

`TimeScaleDirector` is an **autoload** that owns `Engine.time_scale` exclusively. No other node should write `Engine.time_scale` directly once it has callers. It implements a **stacked-request model**: multiple systems can concurrently hold a slow-motion or freeze request without clobbering each other. The Director resolves the stack and writes the final `Engine.time_scale` value each time the stack changes.

This is the same Director pattern as `AudioDirector` (see [`.claude/docs/audio-architecture.md`](.claude/docs/audio-architecture.md)) applied to time-scale: a single authoritative autoload owns a shared engine resource, and callers register/release named intent rather than writing the resource directly.

Foundation tickets: **T11** (Wave 1) introduces the Director; **T2** (hit-pause) and **T3** (phase-transition slow-mo) are Wave 1 consumers that depend on it.

## Stacked-request model

Any system that wants to slow time registers a request with a desired scale and a priority, then releases the request when the effect ends. The Director holds a live stack of all active requests and recomputes `Engine.time_scale` on every push/pop.

**Resolution rule — two-layer:**

1. **Lowest scale wins** among all active requests. If hit-pause wants 0.0 and phase-transition slow-mo wants 0.3, the combined result would be 0.0.
2. **Priority overlay** on top of lowest-scale. Priority allows intent to take precedence when "lowest scale" would produce a semantically wrong result. Example: hit-pause is `PRIORITY_FREEZE` (highest defined constant); a phase-transition request at `PRIORITY_DEFAULT` would not suppress a freeze even if both are active. The priority field is the design call Devon made to resolve T2-vs-T3 conflict (hit-pause natural scale 0.0 < phase-transition 0.3, but intent is inverse, so priority resolves it explicitly).

Known priority constants (TODO: verify exact integer values against source once PR #285 lands):
- `PRIORITY_DEFAULT` — baseline requests (phase-transition slow-mo, cosmetic time-distortion)
- `PRIORITY_FREEZE` — reserved for `freeze()` hit-pause requests; highest defined priority

## Public API — semantic description

> Exact GDScript signatures are NOT verified. See `scripts/combat/TimeScaleDirector.gd` for the real signatures.

**Register a slow-mo request.** Callers register a request specifying a desired scale and priority. The Director validates scale is in `[0.01, 1.0]` and emits a warning if the value falls outside that range. A `0.0` value passed to the generic request method is **rejected** — the `0.0` case is structurally reserved for the `freeze()` sugar (see below). This makes intent visible: you cannot accidentally freeze by passing `0.0` to the generic path.

**Release a request.** Each registered request can be released individually. Releasing updates the stack and recomputes `Engine.time_scale`. If the stack is empty after the release, `Engine.time_scale` returns to `1.0`.

**`freeze(duration)` sugar.** The canonical path for full-stop hit-pause. Internally registers a `PRIORITY_FREEZE` request at scale `0.0` and auto-expires it after `duration` seconds using a real-time `SceneTreeTimer` (see below). Callers that need hit-pause should always use `freeze()`, not the generic request path.

## `ignore_time_scale=true` — freeze-timer requirement

The `freeze(duration)` auto-expiry timer **must** use `SceneTree.create_timer(duration, process_always=true, process_in_physics=false, ignore_time_scale=true)`. Because `Engine.time_scale = 0.0` stops all process callbacks and scaled-delta accumulation, a normal Timer would never fire — the freeze would become permanent. The `ignore_time_scale=true` flag routes the timer through wall-clock, guaranteeing the release fires at the intended wall-time duration regardless of the current time scale.

**GUT regression pin:** `test_freeze_auto_release_works_despite_scale_0` — verifies the auto-release fires correctly when scale is 0.0.

**Generalization:** this `ignore_time_scale=true` pattern applies to any game-side `SceneTreeTimer` that must fire unconditionally during slow-mo or freeze — real-time hazards, timeout safeties, UI countdowns. It is NOT the right choice for timers that should slow with the game (e.g. `RoomGate` death-wait, which should animate at the current game speed — see [`.claude/docs/combat-architecture.md` § Engine.time_scale interactions](.claude/docs/combat-architecture.md)).

## Scaled tweens — intentional pause during freeze

**The inverse rule:** `Tween` objects created with `create_tween()` and no `ignore_time_scale` override advance on **scaled `_process` delta** — they pause when `Engine.time_scale = 0.0` and resume when it returns to normal. This is the **correct choice** for cinematic tweens that must stay synchronised with the freeze moment.

**Canonical example:** `BossDefeatedTitleCard._start_tween()` (`scripts/ui/BossDefeatedTitleCard.gd`). The card's 1.2 s pre-fade delay + 0.4 s fade-in use a default (scaled) tween so that if a future T2 hit-pause `freeze()` overlaps the boss-died event, the card "feels" the freeze and fades in only after the freeze releases — synchronised with the sibling T16 horn and ember effects, which are also scaled.

> Uma's formulation (M3-T4 brief, §3): "The card 'feels' the freeze and lands after it."

**Decision rule:**

| Tween goal | Correct timer type |
|---|---|
| Cinematic effect that should pause during hit-pause | Default `create_tween()` — scaled, no extra flags |
| Safety-net / real-time hazard / UI countdown that must fire regardless | `ignore_time_scale=true` `SceneTreeTimer` (see above) |

**The mistake to avoid:** wrapping a cinematic tween delay in an `ignore_time_scale=true` timer when the intent is cinematic synchronisation. That decouples the visual from the freeze rhythm.

**Note on #287 T2 hit-pause:** the `freeze()` call from T2 lands after `boss_defeated` fires. Because the title card's tween is scaled, the two effects compose automatically with no coordination code — the Director's stack governs both. (Interaction-test pending T2 merge.)

## InventoryPanel migration policy

`InventoryPanel` (`scripts/ui/InventoryPanel.gd`) is the **only remaining direct writer** of `Engine.time_scale` at the time T11 lands. `StatAllocationPanel` (`scripts/ui/StatAllocationPanel.gd`) is a second direct writer.

**Migration is intentionally deferred.** The migration trigger is: a **second non-director writer lands in the codebase** (i.e. T2 or T3 go through without migrating InventoryPanel). At that point, three concurrent writers creates a clobber risk large enough to justify the migration cost. Until then, the existing InventoryPanel behaviour is preserved to avoid scope creep.

**Harness consequence during the migration window:** the `Engine.time_scale != 1.0` / wall-clock divergence hazard documented in `.claude/docs/combat-architecture.md` § Engine.time_scale interactions still applies. InventoryPanel and StatAllocationPanel are direct writers; Playwright specs that cross the L1→L2 XP boundary or open the inventory during combat must still use the Escape-press idiom to dismiss slow-mo panels. The Director does not change this until InventoryPanel is migrated.

## Cross-references

- [Audio Architecture](.claude/docs/audio-architecture.md) — `AudioDirector` autoload is the parallel pattern for BGM/Ambient ownership
- [Combat Architecture](.claude/docs/combat-architecture.md) § Engine.time_scale interactions — wall-clock vs game-clock divergence hazard, InventoryPanel/StatAllocationPanel as current direct writers, Playwright Escape-press idiom
- `scripts/combat/TimeScaleDirector.gd` — authoritative source for exact signatures (available once PR #285 merges to main)
