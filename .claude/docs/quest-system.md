# Quest System — runtime topology, save seam, dialogue side-effect channel

What this doc covers: the runtime quest pipeline for Embergrave's M3 Tier 3 W2 bounty system — the `QuestDef` / `QuestState` Resource schema, the stateless `QuestStateResolver` that maps `(npc_id, player bounty state)` to a dialogue branch_key, the `QuestActionRouter` autoload that listens on `DialogueController` signals and mutates Player bounty state, the Player save round-trip seam, and the Main.gd wiring that ties them together.

**Status — W2-T2 (PR #347) shipped the listener stub; W2-T6 (PR #352) extended it with persistence; PR #362 closed the Main.gd save-wiring gap.** Bounty content (NPC bounty-poster dialogue → actual progression → reward) lives in sub-track 5b — see § "Bounty content surface — Drew TBD (sub-track 5b)" at the end.

## Resource schema

Two authoring-side Resources + one runtime instance Resource:

```
QuestDef                 (resources/quests/<quest_id>.tres — authoring-side template)
├── quest_id: StringName              ── &"s1_recover_stoker_proof"
├── display_name: String              ── "Recover the Stoker's Proof" (UI surface)
├── accept_branch_quote: String       ── content/quest-log surface
├── complete_branch_quote: String     ── content/quest-log surface
└── reward_payload: Dictionary        ── { "xp": 250, "gold": 50, "items": [...] } — additive; reward-pipeline consumes (W3+)

QuestState               (in-memory + persisted runtime instance)
├── quest_id: StringName              ── matches QuestDef.quest_id
├── accepted_at_tick: int             ── Time.get_ticks_msec() at accept (telemetry; not consumed today)
├── completion_progress: Dictionary   ── permissive per-archetype shape ({ "kills_remaining": N } etc.)
└── state: StringName                 ── &"quest_active" / &"quest_completed" / &"quest_failed" (M4+)
```

**QuestState lifecycle states** (mirrors the DialogueTreeDef branch-key convention):

- `&"pre_quest"` — NOT a valid QuestState state. The QuestState is not instantiated until the player accepts the bounty; before that, the dialogue tree's `pre_quest` branch is the offer-prompt surface.
- `&"quest_active"` — bounty in progress; Player.active_bounty holds this QuestState.
- `&"quest_completed"` — briefly observed during turn-in. By the time downstream code reads it, the QuestState has already moved off `Player.active_bounty` into the `Player.completed_bounties[]` Array.
- `&"quest_failed"` — M4+ surface; reserved, not emitted by W2-T6.

**Why a Resource (not a plain Dictionary).** Typing the runtime state lets the inspector author test fixtures, lets `@export var` fields catch typos at parse time, and lets GUT tests smoke-load `.tres` fixtures without staging a full save layer. The persistence layer (`to_dict` / `from_dict`) keeps the on-disk format JSON-compatible (no custom Resource serialisation in save files).

**Single-active-bounty structural lock (W2-T7 §9 v6 trigger guard).** Player owns at most ONE active QuestState. Multi-concurrent-bounty is deferred to v6. `QuestActionRouter._handle_accept_bounty` REJECTS `accept_bounty` when `Player.active_bounty != null` and emits `WarningBus.warn(..., "quest")` — the rejection is structural, not a bug.

**Cites:** `scripts/quests/QuestDef.gd`, `scripts/quests/QuestState.gd`.

## QuestStateResolver — stateless branch-key resolver

`scripts/quests/QuestStateResolver.gd` is a pure, side-effect-free RefCounted: given `(npc_id, active_bounty, completed_bounties)`, return the StringName branch_key that `DialogueController.open(tree, branch_key)` should navigate to.

**Why a separate class** — keeps the branch-resolution matrix observable without staging the full Player + Save layer in tests. The W2-T6 ticket Part D specified "isolates the branch-key resolution logic from the controller" so a paired GUT test can pin the 4-state matrix cheaply (`tests/test_quest_state_resolver.gd`, 11 tests).

### NPC → offered-quest map

A small const Dictionary `QuestStateResolver.NPC_OFFERED_QUEST` maps a hub/stratum NPC's `npc_id` to the `quest_id` they OFFER. W2-T6 ships exactly one entry:

```gdscript
const NPC_OFFERED_QUEST: Dictionary = {
    &"hub_sister_ennick": &"s1_recover_stoker_proof",
}
```

The map is the canonical authority for "what quest does THIS npc offer." `QuestActionRouter` consults it on every `accept_bounty:<npc_id>` / `complete_bounty:<npc_id>` to resolve the quest_id.

**Why a const Dictionary (not a `.tres` registry).** The map is currently 1 entry. A `.tres` registry adds load-order complexity (need to defer until ContentRegistry boots) for negligible authoring win. When the map reaches ~5-10 entries OR when Sponsor signals a multi-stratum quest expansion, lift to a `.tres` registry under `resources/quests/` with the same shape (npc_id → quest_id).

**Stability invariant** — once an NPC's quest_id is shipped, renaming would orphan player saves (their `completed_bounties` reference the old id). Add new entries; never rename existing entries without a save-migration step.

### Branch resolution matrix

| Player state | Branch returned |
|---|---|
| No active bounty AND NPC's quest not in completed_bounties | `&"pre_quest"` |
| `active_bounty.quest_id == NPC's offered quest_id` | `&"quest_active"` |
| NPC's offered quest_id in `completed_bounties` | `&"quest_completed"` |
| NPC offers no quest (vendor/lore NPC) | `&"flavor"` |
| `active_bounty` for a DIFFERENT NPC's quest | `&"pre_quest"` (the NPC's tree can text-gate "I see you walk with a bounty already" in pre_quest content) |

Resolution check order: completed FIRST (so a player who completed and re-talks doesn't see `pre_quest` even if they currently have no active bounty), then `quest_active` match, then `pre_quest` fallthrough.

**Composition with `DialogueTreeDef.resolve_branch`.** Caller pattern:

```gdscript
var key: StringName = QuestStateResolver.resolve_branch_key(
    npc_id, player.active_bounty, player.completed_bounties)
DialogueController.open(tree, key)
```

`DialogueController` then walks `tree.branches.has(key)` → falls back to `tree.default_branch_key` if the NPC's tree lacks the resolved key (e.g. a flavor-only NPC with no `pre_quest` branch). The resolver picks the *ideal* key; the controller's fallback handles missing keys.

**Cite:** `scripts/quests/QuestStateResolver.gd::resolve_branch_key`. Test: `tests/test_quest_state_resolver.gd` (11 tests across the matrix).

## QuestActionRouter autoload — listener + persistence

`scripts/quests/QuestActionRouter.gd` is the runtime owner of bounty-state mutation. Registered as `QuestActionRouter="*res://scripts/quests/QuestActionRouter.gd"` in `project.godot` (line 36, under `DialogueController` line 35).

> **Naming note.** Earlier design docs reference a "BountyController" — that name was not adopted. The shipped autoload is `QuestActionRouter`. It listens on dialogue signals AND mutates bounty state; the two concerns share one autoload because the mutation is directly triggered by a dialogue side-effect verb. If the surface grows beyond bounty (faction state, codex unlocks, NPC-relationship deltas), a split into `BountyController` + `QuestActionRouter` could re-surface; today, one autoload is correct.

### Signal surface

```gdscript
# Listener-stub echoes (W2-T2, PR #347)
signal quest_action_received(action_id, npc_id, branch_key)
signal dialogue_closed_observed(npc_id)

# Persistence emits (W2-T6, PR #352)
signal quest_accepted(quest_id: StringName)     ── fires AFTER Player.active_bounty written
signal quest_completed(quest_id: StringName)    ── fires AFTER Player.completed_bounties appended + active_bounty cleared
```

`quest_accepted` / `quest_completed` are the consumer hooks for the W3+ reward pipeline (XP/gold/item grant on completion), world-map UI quest-target zones, and any future BountyController-style content layer.

### Subscriptions

At autoload-ready time (`_ready()`, line 149), the router subscribes to three `DialogueController` signals:

- `quest_action_invoked(action_id, npc_id)` → `_on_quest_action_invoked` (line 256) — the verb-dispatch entry point.
- `branch_opened(npc_id, branch_key)` → `_on_branch_opened` (line 230) — captures the controller's current branch into `_current_branch_key`.
- `dialogue_closed(npc_id)` → `_on_dialogue_closed` (line 299) — mirror-only echo.

The subscriptions are defensive — if `DialogueController` is missing (autoload-stripped GUT test context), the router stays quiet without `WarningBus.warn` so it doesn't taint `NoWarningGuard`.

### Verb dispatch

The router parses `action_id` as `<verb>:<target>` (split on the FIRST `:` only — future targets containing `:` resolve cleanly). Two verbs are wired today:

- `accept_bounty:<npc_id>` → `_handle_accept_bounty(npc_id)` (line 312)
- `complete_bounty:<npc_id>` → `_handle_complete_bounty(npc_id)` (line 353)

`open_vendor:<npc_id>` / `reforge:<slot>` / `abandon_bounty` are recognized as verb constants but stay as listener-only no-ops in W2-T6 — Track 3 W3+ wires them.

### Accept flow

`_handle_accept_bounty(npc_id)`:

1. Resolve Player via the `&"player"` group. No Player → no-op (defensive; stub state still records the event for tests).
2. Lookup `QuestStateResolver.NPC_OFFERED_QUEST[npc_id]`. Missing → `WarningBus.warn(..., "quest")`.
3. Check `Player.active_bounty` — non-null → `WarningBus.warn(..., "quest")` (single-active-bounty lock).
4. Instantiate a fresh `QuestState`, set `quest_id` / `accepted_at_tick` / empty `completion_progress` / `state = &"quest_active"`, write to `Player.active_bounty`.
5. Emit `quest_accepted(quest_id)`.

### Complete flow

`_handle_complete_bounty(npc_id)`:

1. Resolve Player. No Player → no-op.
2. Lookup `NPC_OFFERED_QUEST[npc_id]`. Missing → `WarningBus.warn(..., "quest")`.
3. Read `Player.active_bounty` — null → `WarningBus.warn(..., "quest")`.
4. Verify `active.quest_id == expected_quest_id` — mismatch → `WarningBus.warn(..., "quest")` (catches a content/engine drift class).
5. Append `active.quest_id` to `Player.completed_bounties`, clear `Player.active_bounty` to null.
6. Emit `quest_completed(quest_id)`.

### Read-order discipline (Drew nit, PR #320)

`DialogueController.dialogue_closed` is single-arg `(npc_id: StringName)` — NOT two-arg. `DialogueController.close()` is no-args. The controller calls `_reset_state()` (clearing `_branch_key = &""`) BEFORE emitting `dialogue_closed`.

Consequence: any listener that needs the branch_key for write-side bounty mutation MUST capture it BEFORE `close()` clears state. The router does this by:

- Capturing `_current_branch_key` continuously via `branch_opened` (line 244).
- Snapshotting it into `_action_branch_key` at `quest_action_invoked` time (line 266) — controller emits `quest_action_invoked` BEFORE navigation per `.claude/docs/dialogue-system.md` § "Signal surface", so `_current_branch_key` is still the originating branch at snapshot time.
- The snapshot lives in this autoload's state, NOT the controller's — survives both navigation AND close.

Pinned by `tests/test_quest_action_listener_reads_branch_key_before_close.gd` (4 ACs: behavioural read-order, source-scan against `current_branch_key()` in `_on_dialogue_closed`, signal-shape pin on `dialogue_closed` single-arg, method-shape pin on `close()` no-arg).

**Cite:** `scripts/quests/QuestActionRouter.gd`.

## Save integration

The QuestState save seam is fully additive within `schema_version = 5` — no version bump. Three layers:

### 1. Player runtime fields

`scripts/player/Player.gd` defines:

- `var active_bounty: Variant = null` (line 412) — holds `QuestState` or `null`. Variant-typed because GDScript strict-typing `QuestState` rejects the null case.
- `var completed_bounties: Array = []` (line 423) — Array of StringName quest_ids that have been completed.

### 2. Player.to_save_dict / restore_from_save_dict

Defined at `scripts/player/Player.gd:2096` (`to_save_dict`) and `scripts/player/Player.gd:2142` (`restore_from_save_dict`):

- `to_save_dict()` returns `{ "active_bounty": <QuestState.to_dict()> or null, "completed_bounties": Array[String], ... }`.
- `restore_from_save_dict(character)` reads both keys with `has()`-guard defensive defaults (null / `[]`) and reconstructs via `QuestState.from_dict()`.

`QuestState.to_dict()` / `QuestState.from_dict(payload)` are symmetric and JSON-safe — StringName fields stringified for JSON compatibility.

### 3. Save.gd backfill — `_backfill_v5_tier3_quest_fields`

Defined at `scripts/save/Save.gd:573`, called unconditionally from `Save.gd::migrate` at line 333 (OUTSIDE the version-gate). This is the PR #352 pattern documented in `.claude/docs/save-architecture.md` § "Backfill outside the version-gate":

```gdscript
# scripts/save/Save.gd::migrate (simplified)
if from_version < SCHEMA_VERSION:
    out = _upgrade_payload(out, from_version)
# Backfill runs on EVERY load — including same-version reloads of saves
# written by an earlier v5 build (before the quest fields landed).
out = _backfill_v5_tier3_quest_fields(out)
```

The backfill adds `active_bounty: null` + `completed_bounties: []` to `data.character` if either key is absent. This catches:

- Legacy v0..v4 saves (chained-migrated up to v5, then backfilled).
- Pre-W2-T6 v5 saves (read as `schema_version == 5`, version-gate skips them, backfill catches the missing keys).

**See `.claude/docs/save-architecture.md`** for the full pattern rationale and when-to-use rubric for `_upgrade_payload` vs `has()`-guard vs backfill-outside-the-version-gate.

### 4. Main.gd invocation (existence ≠ invocation gotcha)

**The trap, worked example:** PR #352 added `Player.to_save_dict` + `Player.restore_from_save_dict` + the migration backfill. All tests at the Save.gd-migrate seam passed. BUT the methods were never wired into `scenes/Main.gd::_persist_to_save` (`scenes/Main.gd:1161`) or `Main._load_save_or_defaults` (`scenes/Main.gd:1103`). In-memory Player state never round-tripped; the fields survived only because the migration backfill wrote non-null defaults on every load. PR #362 (W2-T5 world-map UI, commit `9393473`) closed the gap with one-line invocations on both sides:

```gdscript
# scenes/Main.gd:1156 (read)
if _player != null and _player.has_method("restore_from_save_dict"):
    _player.restore_from_save_dict(character)

# scenes/Main.gd:1184 (write)
if _player != null and _player.has_method("to_save_dict"):
    var player_save: Dictionary = _player.to_save_dict()
    # ... merged into payload before save
```

**Why this was silent for 3 weeks:** backfill from PR #352 provided non-null shapes, so nothing crashed on read; tests covered the migrate seam (payload-in → payload-out), not the integration seam (live Player → Main → Save → Main → live Player). Method presence in `Player.gd` reads as "wired" on a casual grep; the call-site absence in `Main.gd` is the load-bearing fact.

**Future-PR checklist** for any new `to_save_dict` surface (mobs, quest-state, inventory, world-map, NPC roster):

1. Add the method on the system.
2. Add the migration-side handling (`_backfill_<scope>_<fields>` OR read-site default).
3. **Wire the call-site in `scenes/Main.gd`** — grep for the method name across `scenes/`, not just for its definition.
4. Add an integration-surface test that exercises Main↔system↔Save↔Main, not just Save.gd-migrate in isolation.

See `.claude/docs/save-architecture.md` § "Main-side wiring" for the generalized three-seam audit rule.

## Testing surface

GUT pins (under universal warning gate per `.claude/docs/test-conventions.md`):

- `tests/test_quest_def.gd` — 2 tests (Resource defaults + class_name).
- `tests/test_quest_state.gd` — 9 tests (to_dict/from_dict symmetry + null handling).
- `tests/test_quest_state_resolver.gd` — 11 tests (4-state matrix across npc / active_bounty / completed_bounties tuples).
- `tests/test_quest_action_router_stub.gd` — 6 tests (W2-T2 listener-stub behavior).
- `tests/test_quest_action_router_persists.gd` — 7 tests (accept/complete/reject paths + signal emissions).
- `tests/test_quest_action_listener_reads_branch_key_before_close.gd` — 4 tests (Drew-nit read-order pin, source-scan, signal/method shape).
- `tests/test_quest_state_save_roundtrip.gd` — 4 tests (fresh save + pre-W2-T6 v5 backfill + idempotence).
- `tests/test_save_migrate_quest_fields_backfill.gd` — 4 tests (v3 + v4 backfill + Player snap symmetry).

Playwright pin:

- `tests/playwright/specs/quest-state-boot.spec.ts` — HTML5 boot-smoke (autoload registration + signal capture + no quest-class warnings).

## Bounty content surface — Drew TBD (sub-track 5b)

**Out of scope today; sub-track 5b owns the content + integration layer.** The engine surface above is the substrate; the content layer ties it to actual gameplay flow:

- **NPC bounty-poster placement** in hub-town scenes — a body_entered Area2D on Sister Ennick (or whatever bounty-poster NPC) triggers `DialogueController.open(tree, branch_key)` where `branch_key` comes from `QuestStateResolver.resolve_branch_key(...)`.
- **Bounty progression hooks** — what actually fills `QuestState.completion_progress`. The current `s1_recover_stoker_proof` quest's progression mechanic is undefined at this layer; sub-track 5b decides whether it's a kill-counter, an item-pickup signal, a zone-exploration flag, etc.
- **Reward dispatch on `quest_completed`** — XP / gold / item grants. The W2-T6 surface ships the signal hook (`QuestActionRouter.quest_completed(quest_id)`); the actual reward subscriber lands in a Track 3 W3 reward-pipeline ticket.
- **Quest-log UI** — the W2-T5 world-map panel (PR #362) is the geographic surface; a separate quest-log UI surfaces active/completed bounties as text.
- **Multi-bounty design** — the single-active-bounty structural lock is a W2-T7 §9 v6 trigger guard; if Sponsor signals multi-concurrent-bounty as needed, the engine surface above needs revisiting (Player.active_bounty type changes from `Variant` to `Array[QuestState]`, save shape mirrors).

When sub-track 5b consumes this doc: the engine surfaces above are stable contract. The signal names (`quest_accepted` / `quest_completed`), the resolver shape, the save shape, and the verb-dispatch pattern are the bedrock. Content additions are additive entries to `QuestStateResolver.NPC_OFFERED_QUEST` + new `QuestDef.tres` files under `resources/quests/` + new dialogue trees referencing the same npc_ids.

## Cross-references

- `.claude/docs/dialogue-system.md` — DialogueController autoload, signal surface (`quest_action_invoked` ordering vs navigation), DialogueTreeDef branch resolution, single-session guard, attack-input gating convention.
- `.claude/docs/save-architecture.md` — version-gate vs `has()`-guard vs backfill-outside-the-version-gate patterns; the Main-side wiring three-seam audit rule worked through PR #352 → PR #362.
- `.claude/docs/test-conventions.md` § "Universal warning gate" — `WarningBus.warn(..., "quest")` is the load-bearing surface for QuestActionRouter rejection paths.
- `team/devon-dev/save-schema-v5-tier3-additions.md` §2.1 + §2.5 — authoring-side shape lock for `active_bounty` / `completed_bounties`.
- PRs: [#347](https://github.com/TSandvaer/RandomGame/pull/347) (W2-T2 listener stub), [#352](https://github.com/TSandvaer/RandomGame/pull/352) (W2-T6 persistence), [#362](https://github.com/TSandvaer/RandomGame/pull/362) (W2-T5 world-map UI; incidentally closed the Main-side save-wiring gap for active_bounty / completed_bounties).
- ClickUp: `86c9y0zyv` (W2-T2), `86c9y7ydg` (W2-T6), `86c9y10fv` (W2-T5).
