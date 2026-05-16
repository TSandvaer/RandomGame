# Inventory "Drop" vs "Trash" — Triage Analysis

**Author:** Uma (UX)
**Date:** 2026-05-16
**Origin:** Sponsor M2 W3 soak finding — "if i right click to drop an item, it should drop on the ground so i can pick it, up, if not then it should not say drop, it should say trash."
**Status:** Recommending Option (a). Awaiting Sponsor design ack.

---

## 1. Current behavior (with code refs)

`scripts/ui/InventoryPanel.gd:516-518` — Right-click on an inventory grid cell with an item:

```gdscript
MOUSE_BUTTON_RIGHT:
    # Drop — for M1 just remove.
    inv.remove(item)
```

`scripts/inventory/Inventory.gd` — `remove(item)` is a pure list-removal: pulls the `ItemInstance` from `_items`, emits `inventory_changed`, returns. **No `Pickup` is spawned in the world.** No save state is touched (next save snapshot just won't include that item).

`scripts/ui/InventoryPanel.gd:897` — Footer hint shipped to the player:

```
"[Tab] close   [LMB] equip/unequip   [RMB] drop   [Esc] quick close"
```

Inline docstring (line 23) and test name (`tests/test_inventory_panel.gd:166-177` — `test_right_click_inventory_drops_item`) both use the verb "drop". Test docstring is explicit: `"M1 simplification — no spawn"`.

**Equipped-slot RMB is a no-op** — `_handle_equipped_click` (line 521) early-returns on anything that isn't `MOUSE_BUTTON_LEFT`. The "Drop" verb only applies to inventory-grid cells.

## 2. Sponsor's mental model

Right-click → "Drop" should mean **ground-drop with re-pickup affordance**. The verb "drop" in an inventory action UI is, in every action-RPG Sponsor has played, the gateway to "I want to look at this item on the ground, maybe pick it back up, maybe leave it for later". When the verb says "drop" but the item vaporizes, the UI lies — Sponsor explicitly flagged it as needing one of two fixes.

## 3. Option (a) — Rename "Drop" → "Trash"

### Pros

- **Tiny PR.** Three lines of source (footer string + docstring) + a test name + a test message. No new behavior.
- **Immediate honesty.** UI label matches what the code does. Sponsor's principle satisfied with zero gameplay-mechanic risk.
- **Doesn't permanently commit to the new label.** If real ground-drop ships post-M1, "Trash" can be renamed back (or, better: a "Trash" verb stays AND a separate "Drop" verb is added, giving the player both — final / one-way commit / dispose vs lay-on-ground).
- **Avoids the instant-re-pickup trap.** Item disposal that doesn't risk being undone by a Pickup spawning at the player's exact feet (see Option (b) §"Risk: instant re-pickup").
- **Sets up a small SFX cue later.** A "Trash" verb on the UI bus opens the door to a crumple/discard sound that signals finality, which a ground-drop would NOT want (drop = soft sound, trash = decisive sound).

### Cons

- **Gives up an inventory verb permanently** (or accepts a future rename if real-drop ships). Minor — the label space at the footer hint has room for both verbs eventually.
- **Doesn't satisfy the more ambitious mental model.** If Sponsor's preference is the gameplay mechanic, this is "label honesty as a substitute for the feature they wanted". The recommendation acknowledges this tradeoff and routes the gameplay mechanic to a future ticket.

### Scope

- `scripts/ui/InventoryPanel.gd:23` — docstring `right-click ... -> drop (M1: just remove; no ground spawn)` → `right-click ... -> trash (item permanently removed; no ground drop in M1)`.
- `scripts/ui/InventoryPanel.gd:517` — comment `# Drop — for M1 just remove.` → `# Trash — permanently remove the item.`
- `scripts/ui/InventoryPanel.gd:897` — footer hint `[RMB] drop` → `[RMB] trash`.
- `tests/test_inventory_panel.gd:12,166-177` — header comment + test name (`test_right_click_inventory_drops_item` → `test_right_click_inventory_trashes_item`) + assertion message strings.

Approx 6 lines diff. No gameplay behavior change. CI risk: nil. HTML5 visual-verification gate: not applicable (no Tween/modulate/Polygon2D/CPUParticles2D/Area2D touched) — footer hint is a plain `Label` text reassignment.

## 4. Option (b) — Implement real "Drop on ground"

### Pros

- **Matches the Sponsor mental model exactly.** RMB → item appears on the floor, player can walk over it to re-pickup. Same affordance as every action-RPG.
- **Opens gameplay surface:** pick up a sword, equip, change mind, drop, swap for a different one without the dropped item lost. The "look at it on the ground, decide later" workflow.
- **Plays cleanly with existing systems.** `Pickup` scene is already loot-tested; `MobLootSpawner._test_force_spawn_pickup` is the closest existing template (it bypasses the roll path and just instantiates a `Pickup` at a position).

### Cons

- **New gameplay mechanic during M1 RC runway.** Adds verification surface (paired tests + HTML5 visual gate + Playwright spec for the drop-then-pickup loop) at a time when Sponsor is still soaking M2 W3.
- **Risk: instant re-pickup.** `Pickup._activate_and_check_initial_overlap` immediately collects against any player already overlapping at spawn position (PR #143's PracticeDummy fix). Dropping the item at the player's foot tile re-collects it within ~1 frame. Mitigations needed:
  - (i) Toss offset — drop the Pickup at `player.position + Vector2(0, 16)` or similar, clear of the player body. Looks fine in a top-down ARPG.
  - (ii) Pickup grace window — `Pickup` skips initial-overlap check for N ms after spawn. Tiny refactor of the encapsulated-monitoring pattern; needs combat-architecture doc update.
- **Risk: room-transition disposal.** Per `scenes/Main.gd:432-434`, pickups parent under the current room and free on room transition. **A dropped sword vanishes when the player walks through a door.** This matches existing loot behavior (Sponsor's M2 RC "boss room 8 cannot loot dropped" finding) but worth confirming with Sponsor that the new mechanic inherits the same constraint — players are likely to expect "drop in safe room, fetch later".
- **Save/load complexity (if persistence wanted).** Ground items are currently NOT in the save schema. If dropped items should survive a quit-relaunch (Sponsor M2 W3 AC6 ritual), that's a schema migration + restore plumbing. **Likely out of scope** even for option (b) — same as boss-room loot, ground items persist for the session and free on room transition.
- **Visual + audio:** drop deserves a small SFX cue (UI bus or SFX bus thump) and possibly a tiny visual bounce/scatter so the eye registers what happened. Both deferrable but add scope.
- **Playwright spec needed.** Drop-then-re-pickup is a gameplay loop that the harness must protect — otherwise a future Pickup-pattern refactor silently breaks the verb.

### Effort estimate (rough, agent-hours)

- New `Inventory.drop_at(item, world_pos)` method + wire `InventoryPanel._handle_inventory_click` to look up player position + current room: **2-3h**
- Toss-offset or grace-window decision + implementation: **1-2h**
- Paired GUT tests (drop spawns Pickup, drop+walk re-collects, drop near full inventory edge cases): **2-3h**
- HTML5 visual gate — release build + spot screenshot: **1h** (mostly waiting)
- Playwright spec — drop-then-pickup loop, room-transition disposal: **2-3h**
- Self-Test Report + Sponsor soak + iterations: **2h**

**Total: ~10-14 agent-hours end-to-end**, plus Sponsor design ack on (toss-offset vs grace-window) and (room-transition persistence).

### Touched files (if greenlit)

- `scripts/inventory/Inventory.gd` — new `drop_at(item, world_pos)` method that emits `inventory_changed` + spawns Pickup
- `scripts/ui/InventoryPanel.gd` — RMB handler swaps `inv.remove(item)` → `inv.drop_at(item, _player_world_pos())`; needs player + room lookup helpers
- `scripts/loot/Pickup.gd` — possibly grace-window logic (if (ii) chosen over (i))
- `scenes/Main.gd` — possibly expose current-room helper for the panel to find a parent
- `tests/test_inventory_panel.gd` — rewrite test 7 to assert Pickup spawn instead of bare removal
- `tests/test_inventory.gd` — new GUT tests on `Inventory.drop_at`
- `tests/playwright/specs/inventory-drop-and-recollect.spec.ts` — new spec
- `.claude/docs/combat-architecture.md` — possibly update Pickup encapsulated-monitoring section
- `team/uma-ux/inventory-stats-panel.md` — update spec to document the verb + interaction model
- `team/DECISIONS.md` — log decision via Priya weekly batch (toss-offset vs grace-window, room-transition disposal)

## 5. Recommendation: **Option (a) — rename to "Trash"**

### Reasoning

1. **M1 RC runway is tight.** Sponsor M2 W3 is mid-soak. Adding a new gameplay mechanic now is wrong-timed — the testing-bar overhead (paired tests + HTML5 visual gate + Playwright spec + Sponsor soak) eats agent hours that the M1 closer needs more.

2. **The instant-re-pickup trap means option (b) is NOT a 1-PR change.** Toss-offset or grace-window decision + implementation + tests adds a full day-equivalent of scope before it's safe to merge. The bandaid-retirement memory (`bandaid-retirement-scope-blowup`) is the cautionary precedent: "small UX fixes" that touch the Pickup/Inventory pipeline tend to bloom into multi-file PRs.

3. **Sponsor's framing was conditional.** "if X then Y, else Z" — they explicitly listed "Trash" as the acceptable alternative. They're not demanding the gameplay mechanic; they're demanding the label match. Option (a) satisfies the stated principle at minimum cost.

4. **Renaming later is cheap.** If real ground-drop ships post-M1 (highly recommended ticket — see §6 below), the rename costs another 6-line PR. No painful one-way commitment.

5. **The "Trash" label opens a tiny SFX upgrade path** without making promises the mechanic can't keep. A future M3 polish pass can add a UI-bus crumple cue to "Trash" without any gameplay-mechanic risk. Audio direction stays clean.

6. **Doesn't block option (b) at all.** A post-M1 ticket can ship REAL drop-on-ground alongside "Trash" — players get both verbs (RMB to trash, Shift+RMB or a context menu for drop). The label "Trash" disambiguates the two when both ship.

## 6. Follow-up ticket recommendation (for Sponsor's queue)

Once M1 RC ships, open `[M2+] Inventory: real drop-on-ground RMB verb with re-pickup` as a Drew/Devon ticket with:

- Effort estimate from §4 (~10-14 agent-hours)
- Touched files list from §4
- Three open design questions for Sponsor:
  1. Toss-offset vs grace-window for the instant-re-pickup trap
  2. Room-transition disposal — ground items vanish on door-walk, yes/no?
  3. Verb arrangement — does "Drop" replace "Trash" entirely (and player loses dispose-verb) or do both ship side-by-side (RMB vs Shift+RMB or context menu)?

This triage doc archives the analysis so the future ticket doesn't re-derive the cost. Cross-link from the ticket.

## 7. PR plan (this triage's deliverable)

Branch: `uma/inventory-drop-vs-trash-triage` (already cut from fresh `origin/main`).

PR title: `fix(ui): rename inventory "Drop" → "Trash" — match actual no-ground-drop behavior`

PR contents:
- This triage doc (`team/uma-ux/inventory-drop-vs-trash-triage.md`)
- `scripts/ui/InventoryPanel.gd` — 3 source-string changes (docstring + comment + footer hint)
- `tests/test_inventory_panel.gd` — test header + test name + assertion message updates
- `.claude/docs/html5-export.md` — INI-escape pitfall sub-section under "Debug-tooling via head_include" (bonus task)

Self-Test Report comment: GUT `tests/test_inventory_panel.gd` pass + manual confirmation of footer hint string in a local Godot run (no HTML5 visual gate trigger — Label text reassignment is renderer-agnostic).

ClickUp ticket: to be created with PR.

**Do NOT merge** without Sponsor design ack. The triage doc is the deliverable for Sponsor's review; the rename PR is queued and ready once they approve the recommendation.
