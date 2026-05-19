# chore(test): clean stale orphan GUT-test refs in Playwright specs (86c9va3h8)

## Summary

PR #274 (M3W-2, Player AnimatedSprite2D wiring) inverted the sprite-rotation contract: pre-M3W-2 the `Sprite` node tracked `_facing.angle()`; post-M3W-2 the AnimatedSprite2D carries direction via per-frame art and node rotation is pinned to `0.0`. Fix #2 in PR #274 (commit `d22a87f`) deleted the old GUT test `test_sprite_rotation_updates_when_present` and added `test_sprite_rotation_stays_zero_across_facing` in its place. The Playwright header doc in `mouse-direction-attacks.spec.ts:52` still referenced the deleted test name and described the inverted contract.

## Changes

### `tests/playwright/specs/mouse-direction-attacks.spec.ts` (line 49-54)

- **Decision:** update (not remove). The "what this spec deliberately does NOT cover" block is load-bearing context — it explains why the spec doesn't take screenshots and where the rotation invariant is pinned. Removing the bullet would lose that signal. Updating to the new test name + the new (inverted) semantic claim preserves the intent.
- **Before:** "The GUT side `test_sprite_rotation_updates_when_present` pins the wiring" — describes the pre-M3W-2 contract (sprite rotates with facing).
- **After:** "Post-M3W-2 the AnimatedSprite2D carries direction via per-frame art, so the Sprite node's `.rotation` is pinned to 0 across all `_facing` angles. The GUT side `test_sprite_rotation_stays_zero_across_facing` pins that invariance" — describes the current contract.

### `tests/playwright/specs/ac4-boss-clear.spec.ts` (line 349) — sibling orphan swept

While in the broader spec corpus I scanned every `test_*` reference and found one more orphan: `test_room_gate_3mob_concurrent_death_unlock` doesn't exist as a function name. The actual GUT test is `test_3mob_concurrent_death_with_death_wait_unlocks` in `tests/test_room_gate.gd:244`. Updated the comment to point at the real name and include the file path for future grep-ability.

## Sibling-orphan sweep result

Scanned every `test_[a-z_]+` reference under `tests/playwright/`. Cross-checked each against the GUT-side `tests/*.gd` files:

| Reference | Status |
|---|---|
| `test_sprite_rotation_updates_when_present` | ORPHAN (deleted in PR #274) — fixed this PR |
| `test_room_gate_3mob_concurrent_death_unlock` | ORPHAN (never existed — wrong name) — fixed this PR |
| `test_mouse_inside_deadzone_keeps_last_facing` | LIVE — `tests/test_player_mouse_facing.gd:38` |
| `test_hp_regen` (filename ref) | LIVE — `tests/test_hp_regen.gd` |
| `test_playwright_trace_string_contract` (filename ref) | LIVE — `tests/test_playwright_trace_string_contract.gd` |
| `test_tutorial_event_bus_combat_trace` (filename ref) | LIVE — `tests/test_tutorial_event_bus_combat_trace.gd` |
| `test_grunt_state_chasing_string_value_matches_trace_contract` | LIVE |
| `test_team_constants_match_trace_string_contract` | LIVE |
| `test_no_warning_guard` | LIVE |
| `test_force_close_inventory`, `test_equip_swap_*`, `test_inventory*`, `test_hitbox*` | LIVE (prefix/name match) |

Both orphans found are swept in this PR. No further substantive sibling refs to flag.

## Verification

- `npx tsc --noEmit` on both edited spec files: clean (exit 0). Comment-only changes are TS-syntax-safe; semantics of the test bodies are untouched.
- CI runs the full Playwright suite against the release artifact — comment-only edits cannot regress test behavior.

## Regression guard

The same drift class (deleted GUT test name lingers in Playwright spec comments) is the kind of orphan that this PR sweeps. A structural regression guard would require either a) lint-style enforcement that every `` `test_*` `` token inside specs resolves to a live GUT function, or b) a meta-test that grep-checks `tests/playwright/` against `tests/*.gd`. Neither lands in this PR (scope-cut per "lightweight chore"); flagging the gap so a future ticket can codify if drift recurs.

## Cross-lane integration check

- **Engine surfaces:** none touched. No source code under `scripts/` or `scenes/` changed.
- **Test infra:** Playwright spec comment edits only. No fixture changes, no `test-base.ts` changes, no `console-capture.ts` changes.
- **GUT side:** referenced but not modified — the live `test_sprite_rotation_stays_zero_across_facing` already exists in `tests/test_player_mouse_facing.gd:162`.
- **Documentation:** no `.claude/docs/` updates needed — the docs already describe the M3W-2 sprite-rotation-pin-to-zero contract (`combat-architecture.md` §"Sprite-node topology, Seam 2" is cross-referenced from the GUT test).

## ClickUp

- Ticket: [86c9va3h8](https://app.clickup.com/t/86c9va3h8)
- Status: in progress → ready for qa test on PR open
