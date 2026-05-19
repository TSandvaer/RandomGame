# Self-Test Report — PR #282 (ticket 86c9va3f3)

## Local release-build run — spec passes on test branch artifact

Branch SHA: `bd227c1` (test/m3w2-walk-feel-decouple-regression after the
`sprite_rot=` trace extension + new spec)

Release build: GitHub Actions run [`26099257791`](https://github.com/TSandvaer/RandomGame/actions/runs/26099257791)
producing artifact `embergrave-html5-bd227c1`.

```
$ RELEASE_BUILD_ARTIFACT_PATH=...\embergrave-html5-bd227c1 npx playwright test player-walk-feel-decouple.spec.ts

Running 3 tests using 1 worker
  ok 1 north-walk-with-east-cursor: anim follows velocity, sprite rotation pinned at 0 (7.0s)
  ok 2 multi-direction sweep with stuck-east cursor: anim follows each WASD direction, sprite rotation never leaks (7.4s)
  ok 3 idle-with-cursor-rotation: sprite rotation pinned at 0 even as cursor sweeps cardinals (4.9s)
  3 passed (22.8s)
```

## Revert-hack verification — spec catches both regression classes

Per AC#4, both fixes were independently reverted on throwaway branches; the
spec was run against a release-build of each reverted state. Both throwaway
branches have been deleted from origin after verification.

### Fix #2 revert — `_update_sprite_rotation` re-coupled to `_facing.angle()`

Branch: `throwaway/revert-test-walk-feel` (`cbad159`, DELETED). Release-build
run [`26099417065`](https://github.com/TSandvaer/RandomGame/actions/runs/26099417065).

```
3 failed
  [chromium] north-walk-with-east-cursor — sprite_rot 0.823841 > epsilon 0.001
  [chromium] multi-direction sweep — sprite_rot 0.823841 > epsilon 0.001
  [chromium] idle-with-cursor-rotation — sprite_rot 1.570796 > epsilon 0.001
```

The idle test caught the south-cursor case: `sprite_rot = +π/2 ≈ 1.570796 rad`
(atan2 of mouse-south delta). All 3 tests caught the regression with clear
error messages naming Surface 2 and the actual leaked rotation value.

Note: `0.823841` (not the nominal `+π/4 ≈ 0.785`) is observed because the
mouse-SE click position depends on the live player position via Player.pos
trace — by the time the trace emits, the player has walked north a few px,
shifting `_facing.angle()` slightly. The post-fix-merge spec asserts `< 1e-3`
either way, so the noise margin is irrelevant.

### Fix #1 revert — `_resolve_anim_dir` re-coupled to `_facing`

Branch: `throwaway/revert-test-walk-feel-fix1` (`018d774`, DELETED). Release-build
run [`26099635330`](https://github.com/TSandvaer/RandomGame/actions/runs/26099635330).

```
2 failed
  [chromium] north-walk-with-east-cursor — Expected anim 'walk_n' during 1.5 s
    of W-key hold. Got anim names: [(walk_e during walk)] — Surface 1 regression
  [chromium] multi-direction sweep — Phase 1 (north (W)): expected 'walk_n'.
    Got anim names: ["walk_se","walk_se","walk_se"] — every phase routed by
    SE cursor instead of WASD-direction velocity
  1 passed [idle-with-cursor-rotation — Fix #2 untouched, rotation still pinned;
    anim names not checked in idle test]
```

Test 2's failure message is particularly diagnostic: the entire 3-phase sweep
(W → S → A keys) emitted `walk_se` on every phase, exactly matching the cursor
direction. A future reviewer faced with that array can instantly diagnose
"Fix #1 regressed" without needing to consult the spec source.

## Surface coverage matrix

| Test | Fix #1 (anim follows velocity) | Fix #2 (sprite rotation pinned) |
|---|---|---|
| 1 — north-walk-with-east-cursor | covered (asserts walk_n appears + forbidden east-anims absent) | covered (asserts sprite_rot < 1e-3) |
| 2 — multi-direction sweep | covered (per-phase walk_n / walk_s / walk_w + sweep-wide forbidden) | covered (asserts sprite_rot < 1e-3 across all 3 phases with non-cardinal cursor) |
| 3 — idle-with-cursor-rotation | not checked (no movement) | covered against idle-only regression (cursor sweeps all 4 cardinals, rotation pinned) |

Tests 1 and 2 cover the joint failure case; test 3 isolates Fix #2 against an
idle-only regression that would slip past tests 1/2 (e.g. someone refactors
`_update_sprite_rotation` to set rotation only when in STATE_IDLE).

## Universal warning gate

Spec imports `test` from `../fixtures/test-base` per `.claude/docs/test-conventions.md`
universal-warning gate. No `USER WARNING:` / `USER ERROR:` lines emit during
the 3 tests against the test-branch artifact.

## Regression guard

This spec IS the regression guard. The Fix #1 + Fix #2 surfaces in
`scripts/player/Player.gd` are the regression class; the spec exercises both
simultaneously in the HTML5 release-build, complementing the existing
GUT pins (`test_player_mouse_facing.gd::test_sprite_rotation_stays_zero_across_facing`
+ `test_player_animation_wire.gd::test_walk_anim_velocity_octant_for_all_8_directions`).

## Cross-lane integration check

- `latestPlayerPos` consumer in `tests/playwright/fixtures/mouse-facing.ts:218-230`
  parses `pos=(\s*(-?\d+)\s*,\s*(-?\d+)\s*)` from `Player.pos` lines — appending
  `sprite_rot=` after the `state=` field does not affect this regex.
  Verified by `tsc --noEmit` clean compile of the entire Playwright suite +
  green run of the existing `mouse-direction-attacks.spec.ts` (which also
  uses `latestPlayerPos`) in a fresh run against the same test-branch artifact.

- GUT side: `Player.gd` `_physics_process` edit is purely an append to an
  existing throttled trace. The local-variable read of `Sprite.rotation`
  reads a property that the existing GUT test
  `test_sprite_rotation_stays_zero_across_facing` already pins to `0.0`. No
  GUT test behavior changes; the new `_combat_trace` print is wrapped by the
  `OS.has_feature("web")` shim, so headless GUT emits nothing.

## HTML5 release-build visual-verification gate

Per `.claude/docs/html5-export.md`, this PR's changes are not in the Tween /
modulate / Polygon2D / CPUParticles2D / Area2D-state classes — the
`Player.pos` trace extension is a string-format append (no renderer surface)
and the spec adds no new rendering primitives. The spec ITSELF validates the
HTML5 release-build visual behavior (sprite rotation observability + anim-name
emission), so the gate is the spec's job, not a separate screenshot.

## Files touched

- `scripts/player/Player.gd` — append `sprite_rot=%.6f` field to existing
  `Player.pos` throttled trace
- `tests/playwright/specs/player-walk-feel-decouple.spec.ts` — new spec
  (3 tests, 488 lines incl. docstring)
- `team/tess-qa/pr-body-m3w2-walk-feel-decouple.md` — PR body source
- `team/tess-qa/pr-282-self-test-report.md` — this report
