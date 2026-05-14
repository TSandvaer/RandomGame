# M2 W1 UX Polish — Connected Design Pass (3 tickets)

**Owner:** Uma (UX / design specs) · **Phase:** M2 Week 1 polish wave · **Drives:** Devon's implementation PR
**ClickUp tickets:** `86c9q5qyd` (Stats panel "Damage --") · `86c9q7p38` (Save-confirmation toast) · `86c9q7p48` (Equipped vs in-grid distinction)
**Status:** Locked for Devon hand-off pending Tess design-review sign-off.

---

## Why this exists

Three small UX/inventory polish gaps surfaced across Sponsor's M1 RC soak attempts. They are documented as known issues in `team/orchestrator/M1-RC-RELEASE-NOTES.md` § "Known issues — deferred to M2 Week 1":

> **6. Stats panel reads "Damage --" with iron_sword equipped** — ticket `86c9q5qyd`. Cosmetic; combat math correct, only the UI display gap.
>
> **7. No explicit save-confirmation toast/indicator** — ticket `86c9q7p38`. Auto-save fires but no visible cue.
>
> **8. Equipped vs in-grid items have no visual distinction in inventory** — ticket `86c9q7p48`. Sponsor request from soak attempt 2.

The orchestrator + Sponsor scoped these as ONE connected design pass with shared vocabulary so Devon can implement all three with consistent patterns. Individually each item is small (~4–8 lines of GDScript per fix); shipped as a wave with a shared visual grammar they read as a coherent polish pass instead of three disjoint cosmetic tweaks.

**Sponsor quote (paraphrased — needs Sponsor confirmation if quoted verbatim publicly):** the equipped-distinction request was logged as *"I couldn't tell which sword was equipped"* in the orchestrator brief for this dispatch. The release-notes line above is the canonical M1 RC writeup; the verbatim soak phrasing (M1 RC soak attempt 2, build `3937831`) was paraphrased into the M2 W1 ticket title. Treated as paraphrased here.

The other two items are cosmetic-gap reports without verbatim Sponsor quotes — both surfaced in Sponsor's M1 RC soaks 2–5 as "noticed during play, filed as polish, not run-blocking" per the M1 RC release-notes P2/P3 classification. Devon can confirm with orchestrator if a verbatim quote-source is needed for any commit-message attribution.

---

## Shared vocabulary — the connecting thread

The three fixes are bound by **two visual primitives** that recur across all three:

### 1. The "positive-affirmation green" — `#7AC773`

This is the existing "Heal popup (M2+) — Soft green; reserved" entry in `team/uma-ux/palette.md` § "Status / state colors". M1 ships with no callers. **This polish wave is its first use,** and it becomes the canonical "saved / equipped / positive-state" color across the whole game from M2 onward.

**Why this color, not ember-orange:**
- Ember-orange (`#FF6A2A`) is the player's *flame* — it carries the brand identity (level-up glow, crits, T6 gear, panel section headers). Re-using it for "saved" / "equipped" dilutes that semantic load. A player who sees ember should think "I leveled up" or "this is mythic loot," not "the file saved."
- Soft-green (`#7AC773`) is reserved in palette.md explicitly as the heal/positive cue. Sponsor's mental model from other action-RPGs is the same — green = positive feedback, ember = heat/intensity. The palette author (Uma, prior turn) flagged it M2+ on purpose; this is the M2+ moment.
- All channels strictly sub-1.0 → HTML5 HDR-clamp safe per `.claude/docs/html5-export.md` § "HDR modulate clamp."

### 2. Status-text typography — Label, sub-1.0 colors, no Polygon2D

All three tickets surface tiny status-text affordances (a stats line, a toast string, a slot badge). The shared rule:

- **Use `Label` (Godot Control) or `RichTextLabel` for any text.** Both render via Godot's font pipeline, identical across `gl_compatibility` (HTML5) and `forward_plus` (desktop).
- **Use `ColorRect` for any solid-fill background, outline, or badge plate.** Per `.claude/docs/html5-export.md` and PR #137 cautionary tale, **never** use `Polygon2D` for outlines / shapes / badges in HTML5-shipped UI. ColorRect renders identically across renderers.
- **All tween / modulate target colors strictly sub-1.0 on every channel.** No `Color(1.4, ...)` HDR values; the HTML5 sRGB pipeline clamps them and the perceptible delta vanishes (PR #137 / #115 / #122 cautionary tale).
- **No Polygon2D-based visual effect anywhere in this wave.** Eliminates the `gl_compatibility` divergence class entirely.

### 3. Connection through Inventory autoload signals

All three fixes hook into existing Inventory / Save signals — none requires a new global signal or autoload:

- `Inventory.item_equipped(item, slot)` / `Inventory.item_unequipped(item, slot)` — already emitted from `Inventory.equip()` / `Inventory.unequip()`. Drives ticket 1 (Stats panel refresh) and ticket 3 (badge re-render).
- A NEW `Save.save_completed(slot, ok)` signal — single-line addition in `scripts/save/Save.gd` at the end of `save_game()`. Drives ticket 2 (toast). Devon's only signal-add for the wave; everything else hooks into existing emitters.

---

## Per-ticket design

### Ticket 1 — `86c9q5qyd` Stats panel: "Damage --" → equipped weapon damage

#### Current behavior

`scripts/ui/InventoryPanel.gd:252` — `_refresh_stats()` builds the BBCode block with three hardcoded `--` placeholders:

```gdscript
bbc += "Damage    --\n"
bbc += "Defense   --\n"
bbc += "Crit      --\n"
```

The `--` was a M1-era placeholder before the affix system landed. Combat math is correct (`Damage.compute_player_damage(_equipped_weapon, edge, kind)` reads `_equipped_weapon.base_stats.damage` per `scripts/combat/Damage.gd`); only the *display* in the inventory panel never read it back.

#### Designed behavior

**Damage line:** read the equipped weapon's `base_stats.damage` from `Inventory.get_equipped(&"weapon")` and render the integer value. Fistless = `1` (FIST_DAMAGE per `scripts/combat/Damage.gd:81`).

**Display format (locked):**

```
Damage    6
```

— integer only, right-aligned with the existing block. **No "(iron_sword)" suffix** in M1; the weapon name is already visible in the equipped-row slot button (PR #150 + this wave's ticket-3 fix make it more legible). Adding the name to the stats column would create redundancy with the equipped row's own label.

**No-weapon-equipped fallback:** when `Inventory.get_equipped(&"weapon") == null`, render:

```
Damage    1  [color=#B8AC8E](fists)[/color]
```

Where `#B8AC8E` is the existing "HUD caption / hint" muted-parchment color from `palette.md`. The `(fists)` parenthetical clarifies that 1 is real — it's the FIST_DAMAGE constant, not a placeholder. This is the design call against the alternative "stay --" — Sponsor's mental model is "if I see a number, that number is what I deal," and FIST_DAMAGE=1 is what the player actually deals fistless. Hiding it behind `--` was the M1 RC bug.

**Defense line:** read armor's `base_stats.armor` from `Inventory.get_equipped(&"armor")` analogously; fallback to `0` (no armor = no reduction).

```
Defense   0
```

(no `(unarmored)` parenthetical — 0 is unambiguously "no armor" without help).

**Crit line:** **leave as `--` for M1.** Crit is not yet in M1 combat math (`Damage.compute_player_damage` doesn't roll crit; crit popup is M2+ per `team/uma-ux/palette.md`). Replacing with `0` would falsely promise a stat that doesn't exist.

```
Crit      --
```

Add a tiny hint above the line:

```
Crit      --  [color=#B8AC8E](M2)[/color]
```

— forward-compat tag so the `--` is no longer ambiguous.

#### Update trigger

**Signal-driven**, NOT polling. The panel already subscribes to `Inventory.item_equipped` / `Inventory.item_unequipped` in `_ready()` (lines 105-109) and refreshes via `_on_equipped_changed → _refresh_stats()` (line 408). The fix is fully inside `_refresh_stats()` — no new connections.

The signal-driven path is also the one that prevents the M1 RC product-vs-component miss (PR #145 / #146 boot-order class): equipping seeds the same code path that the panel reads, so a save-restore that re-equips will fire the signal and update the panel correctly. Polling (read on every panel-open frame) would mask save-restore bugs — exactly the failure mode `combat-architecture.md` § "Equipped-weapon dual-surface rule" warns against.

#### File path Devon touches

- `scripts/ui/InventoryPanel.gd` — `_refresh_stats()` only. ~20 lines changed.
- **Optional helper:** add `_compute_displayed_damage() -> int` and `_compute_displayed_defense() -> int` private methods so the BBCode template stays readable. Devon's call.

#### Acceptance criteria

- **AC1.1:** With iron_sword equipped (`damage=6` per `resources/items/weapons/iron_sword.tres:10`), opening Tab and reading the Stats panel shows `Damage    6`.
- **AC1.2:** With no weapon equipped (fistless), Stats panel shows `Damage    1  (fists)` in muted-parchment.
- **AC1.3:** Equipping a different weapon (via grid click) updates the Stats panel within one frame — driven by `item_equipped` signal, not polling.
- **AC1.4:** Unequipping the weapon (left-click on equipped slot) updates Stats panel to `Damage    1  (fists)` immediately.
- **AC1.5:** No regression on Defense or Crit lines — Defense reads `0` if no armor; Crit stays `--  (M2)`.
- **AC1.6 (HTML5 exemption):** the line is rendered via `RichTextLabel.bbcode` — same Godot text-rendering pipeline as every other HUD label. Exempt from HTML5 visual-verification gate per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate" platform-agnostic-fixes-are-exempt rule. Devon's Self-Test must claim this exemption.

---

### Ticket 2 — `86c9q7p38` Save-confirmation toast

#### Current behavior

`scripts/save/Save.gd:110-126` — `save_game()` writes the JSON, fires `push_error` on failure, but emits **no signal on success**. The auto-save trigger sites (`scenes/Main.gd:802` `_on_room_cleared`, `:816` `_on_stratum_exit_unlocked`, `:777` `_save_on_quit`, plus `StatAllocationPanel.gd:590,601` on stat allocation) all save silently. Sponsor has no signal whether their save took.

#### Designed behavior

**Affordance: bottom-right ephemeral toast** with a single line of text + small soft-green dot icon, fading in over 200 ms, holding 1.4 s, fading out over 600 ms. Total on-screen duration **2.2 s**.

**Why bottom-right toast, not the alternatives:**

| Option | Why rejected |
|---|---|
| Persistent "Saved 3s ago" footer | Always-on visual noise; the message is non-events-most-of-the-time. Sponsor doesn't care once they trust it works; persistent text becomes a nag. |
| File-icon flash in the corner | Requires an icon asset; PNG-art deferred to M2 polish wave. Toast is text-only — ships in M1's programmer-art tier. |
| Center-screen toast | Steals focus from gameplay. Save fires on room-clear which is exactly when the player is moving through the door — center-toast would block the next combat read. |
| Audio-only ding | M1 ships silent (BB-8 audio stub scope per `team/uma-ux/audio-direction.md`). Audio cue is M2+; a visual cue is M1's only option. |

Bottom-right is consistent with the sponsor-soak-checklist's documented HUD layout — the build SHA already lives there, so the toast appears in the "system-status corner" Sponsor's eye already knows to glance at after a checkpoint.

#### Visual spec (locked)

- **Container:** a `Control` parented to the HUD CanvasLayer (NOT the InventoryPanel CanvasLayer — toast must be visible during normal gameplay, not just inside Tab).
- **Anchor:** bottom-right, offset `-260, -64` from the `BOTTOM_RIGHT` preset (above the build-SHA footer if any, below any existing bottom-right HUD widgets).
- **Background plate:** `ColorRect`, `120 × 28 px`, color `Color(0.10588235, 0.10196078, 0.12156863, 0.85)` — same panel-bg color as InventoryPanel at slightly lower opacity (`0.85` vs `0.92`) so it reads as "transient overlay" not "permanent panel."
- **Soft-green dot:** `ColorRect` (NOT a Polygon2D / circle shape — a small square is HTML5-safe and at 8×8 px reads as a status pip just fine), `8 × 8 px` square, color `Color(0.478, 0.780, 0.451, 1.0)` = `#7AC773` (the shared positive-green vocabulary). Position `8 px` from left, vertically centered.
- **Text label:** `Label` (NOT RichTextLabel — single line, plain), text = `"Saved"`. Font color `#E8E4D6` (HUD body text). Font size `12`. Position `24 px` from left of plate, vertically centered.
- **No animation on the dot itself.** The whole toast fades in / out as one Control via `modulate` tween. A pulsing dot would be visual noise for a 2.2 s widget.

#### Animation (HTML5-safe)

`modulate` tween on the toast's root Control:

- **Hidden state:** `modulate = Color(1, 1, 1, 0.0)` (alpha 0).
- **Fade in:** tween modulate.a → `1.0` over `0.20 s`, `Tween.TRANS_LINEAR / EASE_OUT`.
- **Hold:** `1.40 s` at full alpha.
- **Fade out:** tween modulate.a → `0.0` over `0.60 s`, `Tween.TRANS_LINEAR / EASE_IN`.
- **Free:** `queue_free()` after fade-out completes (or hide + reuse the node — Devon's call; pool-vs-recreate is an implementation detail).

The tween is on `modulate.a` (alpha) of a Control / ColorRect — no HDR risk, no Polygon2D, no parent-cascade concern (the toast is a leaf widget). Renderer-identical across desktop and HTML5.

#### Trigger

**New signal: `Save.save_completed(slot: int, ok: bool)`** — one-line addition in `scripts/save/Save.gd`:

```gdscript
signal save_completed(slot: int, ok: bool)
```

Emitted from `save_game()` after the existing return paths:

- After `atomic_write` succeeds: `save_completed.emit(slot, true)` — drives the toast.
- On `atomic_write` failure path (existing `push_error` line): `save_completed.emit(slot, false)` — for symmetry; toast may show a red-tinted "Save failed" variant in M2, but **for M1 the toast only reacts to `ok=true`** (failure is already surfaced via the `push_error` red console line that Tess + Sponsor watch for). Don't show a "Save failed" toast in M1 — failure-state UI is M2 scope and would create a Sponsor "what do I do now" prompt with no recovery action.

The toast widget connects to `Save.save_completed` from the HUD's `_ready()`:

```gdscript
Save.save_completed.connect(_on_save_completed)
```

Where the HUD `_on_save_completed(slot, ok)` ignores `ok=false` for M1 and shows the toast on `ok=true`.

#### Throttle

Save can fire multiple times in quick succession (e.g. room clear → stratum exit unlock → boss death → loot pickup-save in a 2-second window). The toast SHOULD NOT spam.

**Throttle rule (locked):** if a toast is currently visible AND a new `save_completed(true)` arrives, **reset the existing toast's hold timer to full 1.40 s** (extend, don't queue a new one). The visual effect is "the dot stays a little longer" — the player still sees one toast per save burst, not three stacked toasts.

Devon's implementation: a single `Control` toast widget that owns its tween; on signal, kill the existing tween and restart the hold + fade-out chain. No queue, no stacking.

#### File paths Devon touches

- `scripts/save/Save.gd` — add 1 signal declaration + 2 emit lines (success + failure paths). ~3 lines added.
- `scenes/Main.gd` (or wherever the HUD root lives — confirm with Devon at dispatch time; current best-guess is the `BootBanner` widget's parent CanvasLayer per `team/uma-ux/sponsor-soak-checklist-v2.md` §0.3) — instantiate the toast Control at boot, connect to `Save.save_completed`. New widget script: `scripts/ui/SaveToast.gd` (~60-80 lines including the build-UI + tween + throttle logic).
- New scene OR pure-script — Devon's call. SaveToast can be a script-built Control like InventoryPanel's panel build (no `.tscn` needed) or a small `scenes/ui/SaveToast.tscn`. Either is fine; pure-script keeps the footprint smaller.

#### Acceptance criteria

- **AC2.1:** Walking through Room01 door → `room_cleared` fires → `_persist_to_save()` runs → toast appears bottom-right with "Saved" text + green pip, fades in over 0.2 s.
- **AC2.2:** Toast holds 1.4 s at full alpha.
- **AC2.3:** Toast fades out over 0.6 s; total visible window is 2.2 s.
- **AC2.4:** During StatAllocationPanel allocation save (`Save.save_game(SAVE_SLOT, data)` at `StatAllocationPanel.gd:590`), the same toast fires (signal-driven, not call-site-specific).
- **AC2.5:** Throttle — saves at t=0 and t=0.5 s show ONE toast, not two; the second save resets the hold timer (visible at the 0.5 s mark for a fresh 1.4 s).
- **AC2.6:** On `save_game()` failure (`push_error` path), no toast is shown for M1; Tess's console-error watch is the failure surface.
- **AC2.7 (HTML5 verification):** the toast modulate-alpha tween is on a `Control` whose only painted children are `ColorRect` plate + `ColorRect` dot + `Label` text. All three render identically across renderers. Devon's Self-Test must explicitly state: "no Polygon2D used; all colors sub-1.0 on every channel; `modulate.a` tween confirmed visible in HTML5 release-build artifact." This is the **HTML5 visual-verification gate** per `.claude/docs/html5-export.md`.

---

### Ticket 3 — `86c9q7p48` Equipped vs in-grid item visual distinction

#### Current behavior

`scripts/ui/InventoryPanel.gd:311-331` — `_render_cell()` renders all cells (equipped row + grid) with the same Button styling, only color-tier-coding the font. The equipped row at lines 488-505 (`_build_equipped_row`) builds 5 button slots with the same `96×96 px` size and no visual marker for "this slot's item is equipped." A weapon sitting in the grid AND a weapon sitting in the equipped row look identical (same icon-less button text, same tier-color font).

Sponsor's M1 RC soak attempt 2 surfaced: with iron_sword equipped, the equipped row shows `iron sword` and the grid (after picking up another weapon) shows another `iron sword` — **no visual cue distinguishes the equipped one from the in-grid one.**

#### Designed behavior

**Affordance: ember-green outline + "EQUIPPED" badge on equipped-row slots.** Two reinforcing cues so the player can read the state from across the screen AND read it close-up.

**Why both, not either-or:**
- Outline alone: subtle for color-blind players + low-contrast monitor calibrations. Sponsor's M1 RC was on a programmer-art tier; high-contrast cue is the safer call.
- Badge alone: works for hover-distance reading but doesn't pop at panel-open glance.
- Both: the outline catches the eye, the badge confirms close-up. Together they cost ~15 lines of GDScript and one ColorRect frame per equipped slot.

**Why NOT alternatives:**

| Alternative | Why rejected |
|---|---|
| Inventory-side dock (separate "equipped" panel column) | Major layout rework; ticket scope is "make the existing equipped row legible," not "redesign the panel." |
| Stripe of color through the slot | Polygon-shape risk (slanted stripe → Polygon2D temptation); ColorRect-only outline is HTML5-safer. |
| Gold tint on the equipped item's font | Conflicts with the tier-color font system (`TIER_COLORS` dict at lines 72-79). Equipped T1 item would lose its bone-white tier color. |
| Animated pulse on the equipped slot | Constant motion = constant visual noise during a 30-min soak; `combat-architecture.md` § Mob hit-flash documents the "modulate cascade" risk; a tween on the equipped-row Button would interfere with the slot's existing `modulate` for disabled state. |

#### Visual spec (locked)

##### Outline — equipped-row slots that contain an item

A 4-sided ColorRect outline drawn behind the slot Button. **Implementation: 4 ColorRect children of the slot Button** (top, bottom, left, right edges), each `2 px` thick, color `#7AC773` (the shared positive-green vocabulary).

- **Top edge:** ColorRect at `(0, -2)` size `(96, 2)` — full-width strip above the button.
- **Bottom edge:** ColorRect at `(0, 96)` size `(96, 2)` — full-width strip below.
- **Left edge:** ColorRect at `(-2, -2)` size `(2, 100)` — full-height strip left.
- **Right edge:** ColorRect at `(96, -2)` size `(2, 100)` — full-height strip right.

Outline visible only when `Inventory.get_equipped(slot) != null` for that slot's `slot` key. When unequipped, all 4 ColorRects are hidden (`visible = false`).

**Why 4 ColorRects, not a single one with a NinePatchRect or border-shader:** keeps the visual primitive flat (4 axis-aligned rectangles); no shader code; no Polygon2D; HTML5-identical. NinePatchRect would also work but introduces a 9-slice texture asset that doesn't exist yet — programmer-art constraint.

##### "EQUIPPED" badge — small text strip at slot top-left

A small `Label` overlay at the equipped slot's top-left corner reading `EQUIPPED` in compact uppercase.

- **Position:** offset `(2, 2)` from slot top-left, layered above the Button (z_index = 1 within the slot).
- **Background:** ColorRect, size `(60, 12)`, color `Color(0.478, 0.780, 0.451, 0.92)` = `#7AC773` at 92% alpha (the shared positive-green; 92% matches the InventoryPanel background-plate alpha for a "this is a real chrome element" read).
- **Text:** `Label`, text = `"EQUIPPED"`, font color `Color(0.10588235, 0.10196078, 0.12156863, 1.0)` = `#1B1A1F` (panel background dark — high contrast on the green plate). Font size `9`, horizontal-align center, vertical-align center.

The badge is visible iff the slot has an equipped item — same visibility rule as the outline. When the slot is empty, both outline and badge are hidden.

##### Why the same green for both surfaces

The shared-vocabulary commitment: `#7AC773` is the "saved/equipped/positive" semantic anchor across the entire wave. Toast pip + equipped outline + equipped badge ALL use this exact color. A player who learns "green = positive feedback" from the save-toast in their first 2 minutes will read the equipped outline correctly the first time they open Tab.

#### Update trigger

**Signal-driven** via existing `_refresh_equipped_row()` at `InventoryPanel.gd:267-280`. The fix:

1. In `_build_equipped_row()` (line 476), when constructing each slot button, also build the 4 outline ColorRects + 1 badge Label/ColorRect-pair as children. Default `visible = false`.
2. In `_refresh_equipped_row()` (line 267), after the existing `_render_cell()` call, add: `_set_equipped_indicator(btn, item != null)` — a new helper that flips visibility on the 5 indicator nodes.

The fix is fully inside InventoryPanel — no other file touched.

#### F5-reload survival

The indicator is **stateless** — it's a pure projection of `Inventory.get_equipped(slot) != null`. After F5-reload:

1. `Inventory.restore_from_save` re-populates `_equipped` from the save JSON.
2. InventoryPanel's `_ready` reconnects to `item_equipped` / `item_unequipped` signals.
3. First time Tab is pressed → `open()` → `_refresh_all()` → `_refresh_equipped_row()` → indicator flips on.

**No per-instance state stored on the indicator nodes.** F5-survival is implicit. The state is in `Inventory._equipped` (already F5-survivable per save schema v3 `equipped` block) and the indicator is pure presentation.

The Self-Test for ticket 3 includes an F5-reload manual probe: equip iron_sword → F5 → open Tab → confirm green outline + EQUIPPED badge re-renders.

#### File paths Devon touches

- `scripts/ui/InventoryPanel.gd` — `_build_equipped_row()` extension + new `_set_equipped_indicator(btn, has_item)` helper + 1-line addition in `_refresh_equipped_row()`. ~30-40 lines added; existing logic untouched.

#### Acceptance criteria

- **AC3.1:** With iron_sword equipped, opening Tab → equipped-row weapon slot has a green (#7AC773) outline (4 sides, 2 px) AND a green "EQUIPPED" badge top-left.
- **AC3.2:** With no weapon equipped, the weapon slot has no outline + no badge — same visual state as the dimmed M2 slots.
- **AC3.3:** Picking up a second iron_sword and putting it in the grid (no equip) → grid cell renders with NO outline and NO badge (in-grid items are visually distinct from equipped).
- **AC3.4:** Left-clicking the in-grid second iron_sword to swap-equip → outline + badge MOVE to the new equipped instance immediately (signal-driven via `item_equipped`).
- **AC3.5:** Unequipping (left-click on equipped slot) → outline + badge hide immediately (signal-driven via `item_unequipped`).
- **AC3.6 (F5 survival):** equip iron_sword → Tab close → F5 reload → boot completes → Tab open → outline + badge present without any user action.
- **AC3.7 (HTML5 verification):** outline = 4 axis-aligned ColorRects; badge = ColorRect plate + Label text. No Polygon2D anywhere. All colors sub-1.0 per channel. Renderer-identical desktop ↔ HTML5. Devon's Self-Test must claim this exemption.

---

## Implementation notes for Devon

### File-touch summary

| File | What changes | Approx LOC |
|---|---|---|
| `scripts/save/Save.gd` | Add `signal save_completed(slot, ok)`; emit on success path AND failure path | +3 lines |
| `scripts/ui/InventoryPanel.gd` | `_refresh_stats` reads equipped damage/armor; `_build_equipped_row` adds outline + badge nodes; `_refresh_equipped_row` toggles indicator visibility | +50-70 lines, no deletions |
| `scripts/ui/SaveToast.gd` (new) | Toast widget — ColorRect plate + dot + Label, modulate.a tween, throttle on repeat saves, connects to `Save.save_completed` | +80-100 lines |
| `scenes/Main.gd` (or wherever HUD root lives) | Instantiate `SaveToast` and add to HUD CanvasLayer at boot | +3-5 lines |

**No new scenes required.** SaveToast can be pure-script (mirroring InventoryPanel's script-built UI pattern). If Devon prefers a scene, `scenes/ui/SaveToast.tscn` is fine — the spec is renderer-orthogonal.

### Existing API hooks Devon uses

| Hook | Source | Purpose |
|---|---|---|
| `Inventory.get_equipped(slot: StringName) -> ItemInstance` | `scripts/inventory/Inventory.gd:214` | Read equipped weapon/armor for stats display + indicator state |
| `Inventory.item_equipped(item, slot)` signal | `scripts/inventory/Inventory.gd:87` | Drives Stats panel refresh + equipped indicator on |
| `Inventory.item_unequipped(item, slot)` signal | `scripts/inventory/Inventory.gd:88` | Drives Stats panel refresh + equipped indicator off |
| `ItemInstance.def.base_stats.damage` | `scripts/content/ItemBaseStats.gd:10` | Equipped-weapon damage value for Stats display |
| `ItemInstance.def.base_stats.armor` | `scripts/content/ItemBaseStats.gd:13` | Equipped-armor defense value for Stats display |
| `Damage.FIST_DAMAGE` | `scripts/combat/Damage.gd:81` | Constant `1` for fistless display fallback |
| `Save.save_game(slot, data) -> bool` | `scripts/save/Save.gd:110` | Existing API; new `save_completed` signal emits at end |

### Naming conventions

- **Signal name:** `save_completed` (NOT `save_finished` / `save_done` / `on_save`). Past-tense + `completed` matches Inventory's own `item_equipped` / `item_unequipped` past-participle naming.
- **Toast script class:** `SaveToast` (extends Control).
- **Indicator helper:** `_set_equipped_indicator(btn: Button, has_item: bool) -> void`.
- **Color constant in InventoryPanel.gd:** `const COLOR_EQUIPPED_INDICATOR: Color = Color(0.478, 0.780, 0.451, 1.0)` — the shared positive-green. Re-export from a single source so SaveToast can read the same constant. Devon's call whether to put it on `InventoryPanel` static, on a new `Palette` namespace constant, or on `SaveToast` itself with a doc-comment cross-reference.

### Test bar (mandatory per `team/TESTING_BAR.md`)

For each ticket, paired GUT tests must include:

**Tier 1 — visual-primitive invariants (mandatory):**
- Ticket 1: assert `_refresh_stats()` produces a BBCode block where the Damage line contains `"6"` when iron_sword is equipped (via Inventory autoload), AND `"1"` + `"(fists)"` when unequipped.
- Ticket 2: assert `Save.save_completed` signal fires with `(slot, true)` after a successful `save_game(slot, data)` call.
- Ticket 3: assert `_set_equipped_indicator(btn, true)` makes all 5 indicator nodes (4 outline + 1 badge) `visible == true`; `_set_equipped_indicator(btn, false)` makes all 5 `visible == false`.

**Tier 2 — integration through the real signal path (mandatory for state changes):**
- Ticket 1: drive a real `Inventory.equip(item, &"weapon")` → assert the panel's `_stats_label.text` contains the new damage value within one frame.
- Ticket 2: drive a real `Save.save_game(0)` from a test → assert the toast widget's `modulate.a` is non-zero (mid-fade or full) within 0.3 s.
- Ticket 3: drive a real `Inventory.equip(item, &"weapon")` → assert all 5 indicator nodes on the weapon slot button are `visible == true` within one frame.

**Tier 3 — F5-reload integration (mandatory for ticket 3 specifically):**
- Ticket 3: simulate save → restore via `Inventory.restore_from_save(data, item_resolver, affix_resolver)` → assert indicator nodes re-renders correctly when InventoryPanel is reopened.

**HTML5 visual-verification gate:**
- Ticket 1: exempt (RichTextLabel BBCode only — same Godot text pipeline).
- Ticket 2: **MANDATORY** — Self-Test Report must include explicit HTML5 release-build verification (toast actually fades in/out in WebGL2). Modulate-alpha tween on a Control is the visual effect; the gate is binding even though ColorRect itself is renderer-safe (test bar codified after PR #115/#122 cautionary tale).
- Ticket 3: **MANDATORY** — Self-Test Report must include HTML5 release-build screenshot of equipped slot showing green outline + badge in `gl_compatibility` renderer. Outline is 4 ColorRects (renderer-safe primitive) but the gate is binding for any visible-state-change PR per `.claude/docs/html5-export.md`.

### HTML5-specific must-haves

Repeating from the shared-vocabulary section so Devon can checklist:

- **Zero `Polygon2D` usage** anywhere in this wave. Outline = 4 ColorRects. Badge = ColorRect + Label. Toast = ColorRect + ColorRect + Label.
- **All `Color()` channels strictly sub-1.0.** The `#7AC773` value `Color(0.478, 0.780, 0.451, 1.0)` is safe; verify any ad-hoc colors Devon adds.
- **No `z_index = -1`** anywhere in this wave (per `html5-export.md` § "Z-index sensitivity"). The badge sits at `z_index = 1` within the slot for "above the Button"; the outline 4-sides sit at default `z_index = 0` parented as Button siblings (not children) so they paint *next to* not behind the Button.
- **Modulate tweens on visible-draw nodes only.** SaveToast's `modulate.a` tween is on the toast Control (the visible-draw root). Indicator nodes have no tween (visibility-toggle only — no modulate concerns).

### Connection to combat-architecture.md § "Equipped-weapon dual-surface rule"

Ticket 1's design treats `Inventory.get_equipped(&"weapon")` as the single read source. This is consistent with the dual-surface rule: the panel reads the *Inventory autoload* surface (truth for UI), not the *Player._equipped_weapon* surface (truth for combat). The two are kept in lockstep via `Inventory.equip()` → `_apply_equip_to_player()` → `Player.equip_item()`. If the dual surfaces diverge (a regression of PR #145 / #146 class), the Stats panel will display whichever value `Inventory.get_equipped` has — which IS the correct behavior because the panel is a view of Inventory state, not a view of the combat-active weapon.

This is intentional. **The Stats panel showing wrong damage when surfaces diverge would be a bug; the Stats panel showing the Inventory's equipped weapon while combat reads a different surface is the integration-bug class itself, and the panel is a faithful reporter of the surface it's bound to.** Tess's paired tests should verify panel-reads-Inventory; combat-reads-Player is a separate test in the dual-surface bar.

---

## Self-Test for the design doc

**Tone consistency confirmed against:**

- `team/uma-ux/hp-regen-design.md` — same shape (Why this exists → Intent → per-component spec → Implementation notes for Devon → AC list → HTML5 verification claim). Section ordering mirrored as closely as the 3-ticket structure permits.
- `team/tess-qa/playwright-harness-design.md` — same paste-ready-for-Devon-implementation shape (file paths called out, existing API hooks tabled, naming conventions explicit).

**Reference scenes/scripts read:**

- `scripts/ui/InventoryPanel.gd` (full file) — confirmed `_refresh_stats` BBCode shape, `_build_equipped_row` slot structure, signal subscriptions in `_ready`, palette constants.
- `scripts/inventory/Inventory.gd` (full file) — confirmed `get_equipped` API, `item_equipped` / `item_unequipped` signal contract.
- `scripts/save/Save.gd` (full file) — confirmed `save_game` return-path structure for new `save_completed` signal placement.
- `scripts/content/ItemBaseStats.gd` — confirmed `damage: int` and `armor: int` exported fields exist.
- `scripts/combat/Damage.gd` (relevant lines) — confirmed `FIST_DAMAGE = 1` constant for fistless fallback.
- `scenes/Main.gd:730-820` — confirmed `_persist_to_save()` calls `save_game()` from auto-save trigger sites.
- `team/uma-ux/palette.md` — confirmed `#7AC773` is reserved as "Heal popup (M2+)" color; this is its first use.
- `team/orchestrator/M1-RC-RELEASE-NOTES.md` — confirmed M1 RC ticket attribution + release-notes paraphrasing source.

**Cross-checked against:**

- `.claude/docs/html5-export.md` — HDR clamp rule (sub-1.0 colors), Polygon2D ban, z-index rule, visual-verification gate scope.
- `.claude/docs/combat-architecture.md` § "Equipped-weapon dual-surface rule" — Stats panel reads Inventory surface (not Player surface), consistent with the rule.
- `.claude/docs/orchestration-overview.md` § "Hard gates" — Self-Test Report gate + HTML5 visual-verification gate + ClickUp status gate all called out in Devon's hand-off.

**No contradictions surfaced** with `team/DECISIONS.md`, `team/TESTING_BAR.md`, or any prior Uma design doc.

---

## Open questions for orchestrator / Sponsor

1. **Devon-vs-Drew on the Damage display format.** ~~Open until Devon dispatch — defaulting to `(fists)` for now.~~ **RESOLVED (Devon impl PR M2 W1):** kept `(fists)` per Uma default. Ships with `Damage    1  (fists)` for fistless. If Drew wants symmetrical `(unarmed)` later, that's a one-string swap — Defense fallback intentionally has no parenthetical (per design § Ticket 1: "0 is unambiguously 'no armor' without help"), so symmetric grammar isn't load-bearing.

2. **SaveToast on save-failure.** **RESOLVED (Devon impl):** M1 toast ignores `ok=false`; the `Save.save_completed` signal still fires on the failure path so M2+ can wire a red-tinted variant without an API change. Existing `push_error` console line remains the M1 failure surface.

3. **Single Palette namespace constant for `#7AC773`.** **RESOLVED per Uma's M2 W1 recommendation (NO):** `InventoryPanel.gd` declares `COLOR_EQUIPPED_INDICATOR` + `COLOR_EQUIPPED_BADGE_PLATE` + `COLOR_EQUIPPED_BADGE_TEXT`; `SaveToast.gd` declares `COLOR_PIP` (same hex, separate constant with cross-reference docstring). Two use sites, two declarations, no shared namespace yet. If a third use site appears in M2 W2, refactor into `scripts/ui/Palette.gd` namespace.

4. **Toast "Saved" copy vs. "Game saved" / "Progress saved".** **RESOLVED (Devon impl):** locked to "Saved" per Uma's terse-HUD-copy precedent.

5. **Indicator color-blind accessibility.** Status unchanged — accessible-enough for M1; revisit if Sponsor flags it.

6. **Toast position interaction with the BootBanner.** **RESOLVED (Devon impl):** BootBanner sits bottom-CENTER with `offset_top = -150` (Main.gd:639) and ends at `offset_bottom = -32`. Toast sits bottom-RIGHT at `(-260, -64)` — 260 px from the right edge, 64 px above the bottom. The two regions don't overlap (BootBanner is centered text spanning vertically from -150 to -32; toast plate is 120 × 28 starting at -260 from the right at y=-64 from the bottom). Visual confirmation in HTML5 release-build screenshot.

---

## M2 W2 Addendum — Color-blind secondary cue for equipped distinction (`86c9qah1q`)

**Owner:** Uma (UX / design specs) · **Phase:** M2 Week 2 · **Drives:** Devon's follow-up implementation
**ClickUp ticket:** `86c9qah1q`
**Status:** Design locked — ready for Devon dispatch.

---

### Context

The M2 W1 equipped-indicator (ticket `86c9q7p48`, shipped PR #160) uses two visual cues:

1. A 2 px `#7AC773` green outline on all four sides of the equipped slot.
2. A `#7AC773`-plate badge reading `EQUIPPED` in dark text (`#1B1A1F`).

The outline is a **single-hue green signal** — invisible to red-green-deficient viewers (protanopia / deuteranopia, affecting ~8% of male players). The badge text itself is shape-readable if the player can read the word, but the badge plate is also green. Neither cue survives monochrome rendering (e.g. grayscale display mode, OLED power-saving) or severe low-contrast environments.

M2 W2 requirement: add an explicit **non-color** secondary cue so the equipped state is unambiguous to all CVD types and in monochrome.

---

### Option evaluation

Three candidates were evaluated against four criteria:
- **HTML5 / `gl_compatibility` renderer safety** (no Polygon2D, no HDR colors, no negative z_index)
- **CVD coverage** (protanopia, deuteranopia, tritanopia, and monochrome/grayscale)
- **Visual noise** in a dense 8×3 inventory grid
- **Implementation cost for Devon**

#### Option A — Glyph in the EQUIPPED badge

Prepend a checkmark glyph (U+2713 `✓`) to the badge text: `"✓ EQUIPPED"`.

| Criterion | Assessment |
|---|---|
| HTML5 safety | **Fully safe.** The glyph is a Unicode character rendered by Godot's font pipeline via the existing `Label` node inside `BadgePlate`. Label renders identically across `gl_compatibility` (HTML5) and `forward_plus` (desktop) — same as every other HUD text. No new node type, no Polygon2D, no shader. |
| CVD coverage | **Covers all CVD types + monochrome.** The checkmark is a shape cue — it reads in grayscale, under protanopia/deuteranopia/tritanopia simulation, and for any viewer who can distinguish the character from surrounding text. Even if the green badge plate is invisible in CVD simulation, the `✓` shape distinguishes the badge from an empty slot. |
| Visual noise | **Minimal.** The badge is already 60 × 12 px. Adding `✓` widens the rendered text slightly; at font size 9 the glyph is approximately 7 px wide. The badge plate may need to grow from 60 px to 68 px wide (see exact spec below). The density of the surrounding grid is unaffected. |
| Implementation cost | **Lowest of the three.** Devon changes one string constant (`"EQUIPPED"` → `"✓ EQUIPPED"`) and adjusts the badge plate width. One line of GDScript changed; zero new nodes. |

#### Option B — Luminance blend (brighten slot bg ~8%)

Modulate the equipped slot Button to raise its luminance ~8% vs. unequipped slots.

| Criterion | Assessment |
|---|---|
| HTML5 safety | **Risky.** `_render_cell` (InventoryPanel.gd:384–387) already mutates `btn.modulate` for the disabled-state dimming path (`Color(1,1,1,0.4)` when disabled). A second modulate consumer on the same Button risks a conflict or cascade reset — the existing code path would silently override an equipped-brightness modulate on any `_render_cell` call. Requires careful ordering or a second modulate surface (e.g. a child ColorRect overlay), which raises complexity. |
| CVD coverage | **Insufficient as a primary accessibility cue.** An 8% brightness lift on an already-dark slot (#1B1A1F ≈ luminance 0.05) produces a slot luminance of ≈ 0.054 — a delta of ~7% relative luminance. WCAG 2.1 AA contrast for UI components requires a contrast ratio of 3:1 between active and inactive states. The 8% luminance bump does not reach that threshold. Luminance-only cues also fail completely on displays with poor gamma calibration (common in gaming monitors tuned for high contrast). |
| Visual noise | Low — the brighten is subtle by design. |
| Implementation cost | Medium — requires a non-conflicting implementation strategy (child ColorRect overlay vs. direct modulate), and carries ongoing fragility risk if `_render_cell`'s modulate logic evolves. |

**Verdict: rejected.** Fails the CVD threshold; carries a load-bearing btn.modulate conflict risk.

#### Option C — Pattern fill (diagonal striped overlay)

Add a diagonal stripe pattern over the equipped slot.

| Criterion | Assessment |
|---|---|
| HTML5 safety | **Blocked.** Diagonal stripes require a Polygon2D (explicitly banned per `.claude/docs/html5-export.md` § Polygon2D rendering quirks and PR #137 cautionary tale) or a `ShaderMaterial` (no shader authoring in programmer-art tier; introduces a new primitive class for one slot effect). Neither `ColorRect` nor `Label` can produce a diagonal stripe natively. The only HTML5-safe path would be pre-baked diagonal-stripe PNG texture tiles applied via a TextureRect, which introduces an asset-pipeline dependency that doesn't exist yet. |
| CVD coverage | Good if the pattern were achievable. |
| Visual noise | Medium-to-high in a dense 8-column grid — diagonal stripes compete visually with item names. |
| Implementation cost | High — Polygon2D banned; shader requires new primitive class; texture requires art-pipeline stub. |

**Verdict: rejected.** Blocked by HTML5 Polygon2D ban; implementation cost is disproportionate to the M2 W2 scope.

---

### Decision: Option A with a refined badge spec

**Recommended:** Option A — glyph prefix in the EQUIPPED badge.

**Rationale (one line):** the `✓` checkmark renders through the existing Label font pipeline (HTML5-safe, zero new nodes), survives all CVD types and monochrome, adds no grid-density noise, and costs Devon one string constant change.

A combination approach was considered (A + B together) but rejected: Option B's luminance cue fails the CVD accessibility threshold even as a secondary signal, and its btn.modulate conflict risk is not worth the marginal reinforcement. Option A alone is sufficient as a genuine non-color cue.

---

### Design spec (locked for Devon implementation)

#### Change 1 — Badge text and plate width

**File:** `scripts/ui/InventoryPanel.gd`, function `_build_equipped_indicators_for_slot`.

| Property | Current value | New value |
|---|---|---|
| `badge_label.text` | `"EQUIPPED"` | `"✓ EQUIPPED"` |
| `plate.size` | `Vector2(60, 12)` | `Vector2(72, 12)` |

The plate grows from 60 px to 72 px to accommodate the glyph prefix at font size 9. At 9 pt, `✓ EQUIPPED` measures approximately 66–68 px on Godot's default font; 72 px gives 2 px breathing room on each side of the existing center-align.

No other badge properties change. Color constants (`COLOR_EQUIPPED_BADGE_PLATE`, `COLOR_EQUIPPED_BADGE_TEXT`) are unchanged.

The badge position (offset `(2, 2)` from slot top-left) remains. The plate's right edge moves from x=62 to x=74 — still fully inside the 96 px slot width with 22 px clearance on the right.

#### Change 2 — Badge position anchor update (minor)

The `BadgePlate` ColorRect is already positioned at `(2, 2)` with `size (60, 12)` in `_build_equipped_indicators_for_slot` (InventoryPanel.gd:613). Devon updates only `plate.size = Vector2(72, 12)` and `badge_label.text = "✓ EQUIPPED"`. No repositioning needed.

#### No changes to

- The 4 outline ColorRect edges (positions, sizes, colors).
- `_set_equipped_indicator` visibility logic — it drives `BadgePlate` visibility; `BadgeLabel` is a child of `BadgePlate` so it inherits visibility automatically.
- `COLOR_EQUIPPED_INDICATOR`, `COLOR_EQUIPPED_BADGE_PLATE`, `COLOR_EQUIPPED_BADGE_TEXT` constants — unchanged.
- Any other InventoryPanel function.
- Ticket 3 (PR #160) acceptance criteria — AC3.1 through AC3.7 remain satisfied. The badge now contains `✓ EQUIPPED` where previously `EQUIPPED`; tests that assert badge `visible == true` / `visible == false` are still valid. Tests that assert `badge_label.text == "EQUIPPED"` must be updated to `badge_label.text == "✓ EQUIPPED"`.

#### Integration point in `_set_equipped_indicator`

No change to this function's logic. It drives `BadgePlate.visible` via `get_node_or_null("BadgePlate")` — `BadgeLabel` is a child of the plate and inherits visibility. The glyph change is purely in the Label's text content, which `_set_equipped_indicator` does not touch.

```
_set_equipped_indicator(btn, has_item)
    → finds "OutlineTop", "OutlineBottom", "OutlineLeft", "OutlineRight", "BadgePlate"
    → sets each .visible = has_item
    → BadgeLabel inherits BadgePlate.visible automatically (parent-child)
```

#### Godot font pipeline note (HTML5 safety confirmation)

U+2713 (`✓`) is included in Godot 4.3's bundled fallback font (Noto Sans). The Label renders it at font size 9 via the same CPU-side rasterizer path as all other HUD text — identical across `gl_compatibility` (HTML5) and `forward_plus` (desktop). There is no WebGL2-specific glyph rendering path that would cause divergence. This exempts the change from the HTML5 visual-verification gate's "screenshot required" requirement under the platform-agnostic-fixes rule — but Devon's Self-Test Report MUST explicitly claim this exemption by stating: _"glyph rendered via Godot Label font pipeline, identical across renderers; no Polygon2D, no shader, no modulate."_

If Devon is uncertain whether the glyph renders in the production font (i.e., a custom font is substituted at some point in M2+), the fallback is to use `"[check] EQUIPPED"` as ASCII-safe text. Document this fallback risk in the implementation PR if a custom font is in scope.

---

### Acceptance criteria (ticket `86c9qah1q`)

- **AC-CB1:** With iron_sword equipped, the EQUIPPED badge reads `✓ EQUIPPED` (checkmark visible, not just the word EQUIPPED). Badge plate is 72 × 12 px, centered text, font size 9, all existing colors unchanged.
- **AC-CB2:** In a browser accessibility simulation (Chrome DevTools → Rendering → Emulate vision deficiencies → Deuteranopia), the badge text `✓ EQUIPPED` is distinguishable from the empty slot — the checkmark glyph shape is readable regardless of hue perception.
- **AC-CB3:** With no weapon equipped, the badge is hidden (same as AC3.2 from ticket 3). No regression.
- **AC-CB4:** Equipping / unequipping updates the badge visibility correctly (driven by `_set_equipped_indicator`, same signal path as AC3.4/AC3.5 from ticket 3). No new signal connections required.
- **AC-CB5 (HTML5 exemption):** badge text change is via Label — same Godot font pipeline as all other HUD text. Devon's Self-Test Report must claim this exemption explicitly: _"glyph rendered via Label font pipeline, identical across renderers; no Polygon2D, no shader."_
- **AC-CB6 (regression):** Any existing GUT test that asserts `badge_label.text == "EQUIPPED"` is updated to assert `badge_label.text == "✓ EQUIPPED"`. CI must be green before PR opens.

---

### Test bar additions (mandatory, paired with implementation)

**Tier 1 (visual-primitive invariant):**
- Assert `badge_label.text == "✓ EQUIPPED"` for any equipped slot — replaces the prior `== "EQUIPPED"` assertion in `tests/test_m2_w1_ux_polish.gd` (or equivalent test file targeting ticket 3 badge content).
- Assert `plate.size == Vector2(72, 12)` — plate width is the load-bearing layout change; test the actual built node, not a constant.

**Tier 2 (accessibility-simulation note):** GUT cannot drive Chrome's CVD simulation. This is acknowledged. The AC-CB2 check is a manual Self-Test step — Devon opens the HTML5 release-build in Chrome with Deuteranopia simulation active and confirms the glyph is visible. Screenshot in Self-Test Report.

---

### What the HTML5 visual-verification gate needs to check

1. Badge text reads `✓ EQUIPPED` (not just `EQUIPPED`) — verify via screenshot of the equipped slot at Tab-open in the HTML5 artifact.
2. Badge plate is visually wider (72 px vs 60 px) — confirm the text is not clipped.
3. Glyph `✓` renders as the checkmark character (not a box / missing glyph) — confirms the bundled Godot font includes U+2713 in the HTML5 export.
4. All existing ticket 3 visual checks still pass (4-sided green outline visible, badge hidden when slot is empty).

---

### Hand-off checklist for Devon (M2 W2, ticket `86c9qah1q`)

- [ ] In `_build_equipped_indicators_for_slot` (InventoryPanel.gd:624–631): change `badge_label.text = "EQUIPPED"` → `"✓ EQUIPPED"` and `plate.size = Vector2(60, 12)` → `Vector2(72, 12)`.
- [ ] Update any GUT test asserting `badge_label.text == "EQUIPPED"` → `"✓ EQUIPPED"`.
- [ ] Update any GUT test asserting `plate.size == Vector2(60, 12)` → `Vector2(72, 12)`.
- [ ] Self-Test Report on PR: include HTML5 screenshot of badge showing `✓ EQUIPPED` text; claim Label-pipeline exemption explicitly; include Chrome Deuteranopia simulation screenshot (AC-CB2).
- [ ] ClickUp `86c9qah1q` flip to `in progress` on branch open, `ready for qa test` on PR open.
- [ ] PR title: `design(ux): color-blind secondary cue for equipped distinction (#86c9qah1q)`.

---

## Hand-off checklist for Devon

- [ ] Add `signal save_completed(slot: int, ok: bool)` to `Save.gd` + emit on both success and failure paths.
- [ ] Implement Stats panel damage/defense reads from `Inventory.get_equipped` in `InventoryPanel._refresh_stats` (Ticket 1).
- [ ] Build `SaveToast` widget (script-built or scene-built; pure-script preferred) — bottom-right, modulate.a tween, throttle on repeat saves, connect to `Save.save_completed` (Ticket 2).
- [ ] Add equipped-indicator (4 outline ColorRects + 1 badge ColorRect/Label pair) per equipped slot in `InventoryPanel._build_equipped_row`; toggle via `_set_equipped_indicator` from `_refresh_equipped_row` (Ticket 3).
- [ ] Use `Color(0.478, 0.780, 0.451, 1.0)` = `#7AC773` for ALL three tickets' positive-state cues (toast pip, equipped outline, EQUIPPED badge).
- [ ] Paired GUT tests covering AC1.1–AC1.6, AC2.1–AC2.7, AC3.1–AC3.7.
- [ ] Self-Test Report comment on PR before Tess review (per `team/TESTING_BAR.md` + `.claude/docs/orchestration-overview.md` § Hard gates).
- [ ] Self-Test Report claims HTML5 verification: SaveToast tween + equipped outline/badge visible in HTML5 release-build artifact (per HTML5 visual-verification gate).
- [ ] Self-Test Report claims Ticket 1 platform-agnostic exemption (RichTextLabel-only, same text pipeline as every other HUD label).
- [ ] ClickUp `86c9q5qyd` + `86c9q7p38` + `86c9q7p48` flip to `ready for qa test` on PR open.
- [ ] PR title: `feat(ui): M2 W1 polish wave — stats panel + save toast + equipped distinction (#86c9q5qyd #86c9q7p38 #86c9q7p48)` (or Devon's chosen wording — ticket IDs in title is the ClickUp-gate convention).
