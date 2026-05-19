# test(m3): walk-feel decouple regression spec (Playwright) — PR #274 regression class

ClickUp: [`86c9va3f3`](https://app.clickup.com/t/86c9va3f3)

Drew peer-review per [[tess-cant-self-qa-peer-review]] — game-side Player.gd
edit (one-line `sprite_rot=` extension of the `Player.pos` harness-observability
trace) plus a Playwright spec authored by Tess. Tess-authored ⇒ needs Drew/Devon
peer review per memory; game-side Player.gd surface ⇒ Drew.

## Why

PR #274 (M3W-2 Player AnimatedSprite2D wiring) shipped TWO parallel fixes to the
Sponsor 2026-05-18 soak finding "character looks at mouse cursor while walking":

1. **Fix #1 — `_resolve_anim_dir`** (`scripts/player/Player.gd:~1672`). WALK/IDLE
   animation-name selection routes by movement-velocity octant; ATTACK/DODGE/HIT
   /DIE continue to route by `_facing` (cursor).
2. **Fix #2 — `_update_sprite_rotation`** (`scripts/player/Player.gd:~1201`). The
   Sprite child's `rotation` property pinned at `0.0` in all states — directional
   frames carry orientation, the node transform stays identity.

Both fixes have GUT pins (`tests/test_player_mouse_facing.gd` for Fix #2 helper,
`tests/test_player_animation_wire.gd` for Fix #1 anim resolver). Neither GUT pin
covers the **HTML5 release-build** integration surface: real keyboard input
driven through the browser canvas across the boot + walk + direction-change loop.
The original Sponsor finding was Sponsor-soak-only because no Playwright spec
exercised the decouple class either. This PR closes that gap.

Either fix surface could silently re-couple to `_facing` in a future refactor:

- Fix #1 regression: someone restores `dir_suffix_for_facing(_facing)` for the
  WALK/IDLE branch — anim plays `walk_e` while WASD points north.
- Fix #2 regression: someone deletes the `rotation = 0.0` pin or re-introduces
  a rotation setter elsewhere (e.g. in `_physics_process` or `_on_state_changed`),
  or rotates the Sprite child at the `.tscn` scene level — sprite visibly tracks
  cursor mid-walk.

## What ships

### New spec — `tests/playwright/specs/player-walk-feel-decouple.spec.ts`

Three tests exercise both surfaces in the HTML5 release-build:

1. **`north-walk-with-east-cursor`** — Mouse pinned EAST (250 px offset),
   WASD held W (north) for 1.5 s. Asserts `walk_n` anim fires, NO `walk_e` /
   `walk_ne` / `walk_se` anims emit, and every `sprite_rot=` value is < 1e-3 rad.

2. **`multi-direction sweep with stuck-east cursor`** — Mouse pinned SE (so a
   rotation regression emits `sprite_rot ≈ 0.785 rad`, easily above epsilon).
   Walk N (W key), S (S key), W (A key) in sequence. Each phase asserts its
   expected anim appears, no east-leaning anim appears, and rotation stays ~0.

3. **`idle-with-cursor-rotation`** — No WASD. Mouse swept E → S → W → N (each
   400 ms). Asserts `sprite_rot ≈ 0` across all 4 cardinals — pins Fix #2
   against an idle-only regression that would only manifest outside WALK state.

### Player.gd extension — `sprite_rot=` field on `Player.pos` trace

One-line append to the existing `Player.pos` throttled trace (HTML5-only via
the `combat_trace_enabled()` shim — zero cost on desktop / headless GUT). The
spec parses `sprite_rot=` from `[combat-trace] Player.pos | pos=... state=...
sprite_rot=<rad>` lines. The existing `latestPlayerPos` consumer's regex
(`pos=\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)`) is unaffected — `sprite_rot=` appends
after `state=...`, not in the middle.

GUT side `test_sprite_rotation_stays_zero_across_facing` already pins the
helper logic; the new trace field exposes the same data to the browser harness.

## Acceptance criteria

- [x] AC#1: New spec file `tests/playwright/specs/player-walk-feel-decouple.spec.ts`
      committed
- [x] AC#2: Spec drives WASD movement and probes BOTH surfaces in same scenarios
      (anim-name + sprite-rotation)
- [x] AC#3: Spec passes on current `main` (see Self-Test Report comment for the
      release-build run output)
- [x] AC#4: Spec **fails demonstrably** if either fix is reverted — verified by
      local revert-hack on throwaway branch (see Self-Test Report for the
      revert-test results)
- [x] AC#5: Standard test-conventions — universal warning gate via
      `../fixtures/test-base` import, deterministic seeding, release-build
      fixture

## Doc updates

None — `.claude/docs/combat-architecture.md` already documents the two parallel
surfaces under §"Sprite-node topology, Seam 2: Player aim-rotation". The new
trace field is a harness-observability detail, not architectural; the inline
comments in `Player.gd:~458` link back to the spec.

## Files touched

- `scripts/player/Player.gd` — append `sprite_rot=%.6f` to the existing
  `Player.pos` throttled trace (HTML5-only, zero desktop cost)
- `tests/playwright/specs/player-walk-feel-decouple.spec.ts` — new spec, 3 tests
