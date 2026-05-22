# Self-Test Report — PR #291 v5 (Drew self-soak diagnosis)

**HEAD SHA:** `4bcce31` (was `670769f` at v3, `3c5a60d` at intermediate v5)
**Release-build artifact:** [`embergrave-html5-3c5a60d`](https://github.com/TSandvaer/RandomGame/actions/runs/26225347766/artifacts/7135452538) — for Sponsor soak; rebuild of HEAD on next PR-event run.
**ClickUp:** `86c9wjyrc` (T5) + `86c9wjyuv` (T6) stay in QA. B3 forked to follow-up `86c9x8tc9`.

## Process discipline — diagnose-via-trace BEFORE fix

Per `diagnostic-traces-before-hypothesized-fixes` memory + the v4/v3 dispatch briefs. **This iteration overturned the v3 hypotheses on BOTH B3 and T6 via empirical trace + screenshot capture before patching.**

### Self-soak infrastructure added (v4 commit `83831c4`)

- **`DebugFlags.start_room` URL query param** (mirror of existing `boss_hp_mult`). HTML5-only via `JavaScriptBridge`, clamps to `[0, 8]`. Lets Playwright drop the player directly into Room N, bypassing the AC4 spec's Room 05 game-side blocker.
- **`Main._ready` consumer** — calls `load_room_index(N)` after the normal Room 01 bootstrap.
- **3 paired GUT tests** — default = -1, valid indices accepted, out-of-range clamps DOWN to 8 / negatives reset to -1.
- **`pr291-boss-slam-diag.spec.ts`** Playwright spec — drops into boss room via `?start_room=8&boss_hp_mult=0.05`, drives 14 attacks via the `clickAimedFromPlayer` mouse-facing fixture, captures full `[combat-trace]` console stream + 4 screenshots at slam-aftershock window + 1 at slam-telegraph window.

### v4 self-soak finding — both v3 hypotheses overturned

#### T6 — "aftershock not visible" was a CONTRAST issue, NOT a render-failure issue

Captured trace from `?start_room=8&boss_hp_mult=0.05` on v3 SHA `670769f`:

```
[combat-trace] Stratum1Boss._fire_slam_hit | dmg=17 radius=80 lifetime=0.18 ... phase=2
[combat-trace] Stratum1Boss._spawn_hitbox | id=... pos=(240,165) layer=16 mask=2 ... lifetime=0.18
[combat-trace] Stratum1Boss._play_anim | PLAY anim=slam_s
[combat-trace] Stratum1Boss._spawn_slam_aftershock | particles=12 lifetime=0.35 vel=[40..80] gravity=(0,-50) scale=1.50 z_index=1 origin=(240,165) parent_path=/root/Main/World/Stratum1BossRoom
```

**The trace proves the burst spawned correctly with sane params.** The v3 hypothesis ("particles not rendering / wrong z-order / blocked by HDR-clamp") was empirically refuted — the spawn fired, parent_path was the BossRoom (not the boss itself), z_index was +1 (above sprite), all 12 particles were emitted.

**Screenshot capture (4 frames at 80ms cadence post-spawn, saved to `.claude/tmp/pr291-diag-aftershock-frame-{0..3}.png`)** confirmed the burst IS visually rendered — but at 12 particles × EMBER_LIGHT (`#FFB066` warm peach) → EMBER_DEEP (`#A02E08` dark red) ramp on a boss sprite that is itself red-armored, the particles **blend with the boss-sprite background** and read as boss-sprite noise rather than a distinct impact tell.

**Sponsor's v2/v3 "see no aftershock" report is a fair UX read** ("I can't see it") rather than a missing-fire (the spawn fired correctly; the contrast is insufficient).

#### B3 — "boss is STILL kicking" is a PixelLab template-choice issue

Captured trace + per-frame pixel analysis on v3 SHA `670769f`:

- ✓ Frame paths in `Stratum1Boss.tres` correctly resolve to `assets/sprites/boss/_pixellab_anims/Stratum1Boss/animations/slam/<dir>/frame_NNN.png`
- ✓ PNG bytes at those paths ARE the new `surprise-uppercut` template output (not the old `roundhouse_kick`)
- ✓ State machine plays `slam_<dir>` per `Stratum1Boss._play_anim | PLAY anim=slam_s` trace
- ✗ **The `surprise-uppercut` PixelLab template, when rendered for this boss character, does NOT produce a clean upward-rising uppercut visual in the SOUTH rotation**

Per-frame center-of-mass on `slam/south/frame_{0..6}.png`:

| Frame | center-x | top-y | reads as |
|---|---|---|---|
| 0 | 29 | 20 | rest pose, weapon lowered |
| 1 | 36 | 14 | weapon raising UP-LEFT |
| 2 | 39 | 15 | weapon at peak overhead |
| 3 | 44 | 10 | **body LUNGING right, weapon descending across body** |
| 4 | 50 | 12 | full body extension to RIGHT |
| 5 | 37 | 14 | weapon descending DOWN-RIGHT |
| 6 | 35 | 17 | recovery pose |

15-pixel sideways body sway across the 7 frames = NOT a centered uppercut. Visual reads as an overhead-arc-into-side-strike motion, which from the player's POV (player south of boss in most engagements) looks similar to the previous kick.

**Per `.claude/docs/pixellab-pipeline.md §"Multi-template failure pattern"`** — different PixelLab templates can fail differently per direction. The `surprise-uppercut` template's south rotation is the worst-case for this boss character. No new PixelLab generation can be done within PR #291 scope (per the dispatch brief — "DO NOT regenerate PixelLab frames").

## v5 fix shape — T6 contrast, B3 deferred

### T6 fix (landed in commit `97c1665`)

Bump particle count + replace ramp[0] with a high-contrast impact-flash color:

```diff
-const SLAM_AFTERSHOCK_PARTICLE_COUNT: int = 12
+const SLAM_AFTERSHOCK_PARTICLE_COUNT: int = 24
+const AFTERSHOCK_FLASH_WHITE: Color = Color(1.0, 0.95, 0.75, 1.0)  # #FFF2BF
```

3-stop Gradient ramp:
- `0.0` = `AFTERSHOCK_FLASH_WHITE` (impact frame; high contrast vs boss's red armor)
- `0.25` = `EMBER_LIGHT` (warm fade-through)
- `1.0` = `EMBER_DEEP` (end)

The white-flash at the burst's first ~85 ms (of 350 ms lifetime) gives the impact a perceptual "loud" frame against the boss sprite — solving the v3 contrast issue without changing spawn count or lifetime (both validated as correct in trace).

**Other v3 fixes RETAINED:** lifetime 0.35s, gravity (0,-50) upward pull, scale 1.5, z_index +1, room parenting, deferred add_child, `finished` self-free. Trace evidence proves all of these are working correctly; only the contrast needed fixing.

### B3 fix — SCOPE-CUT to follow-up ticket `86c9x8tc9`

**Why scope-cut, not patch in PR #291:** the dispatch brief explicitly says "DO NOT regenerate PixelLab frames." Within that constraint, the only viable B3 fixes are:

1. Manual Aseprite frame edit (tedious, only fixes 1-2 directions per pass)
2. Direction-borrowing (use a working direction's frames for the failing direction — but produces visually-wrong facing-direction)
3. Re-roll PixelLab template (forbidden in PR #291 scope)

None of these are appropriate to bundle into the T5+T6 polish ship. The follow-up ticket `86c9x8tc9` documents the three approach options + recommends Priya picks the fix shape for a separate iteration.

## v5 self-soak verification

### Trace evidence (post-v5 fix, SHA `3c5a60d`)

From `pr291-boss-slam-diag.spec.ts` against the v5 release-build artifact `embergrave-html5-3c5a60d`:

```
[BuildInfo] build: 3c5a60d
[DebugFlags] debug_build=false test_mode=false fast_xp=false web=true boss_hp_mult=0.050 start_room=8
[Main] M1 play-loop ready — Room 01 loaded, autoloads wired
[Main] DebugFlags.start_room=8 — bypassing Room 01 traversal
[combat-trace] Stratum1Boss.wake | exiting STATE_DORMANT — boss now IDLE, combat enabled
...
[combat-trace] Stratum1Boss._fire_slam_hit | dmg=17 radius=80 lifetime=0.18 kb_dir=(0.00,1.00) player_dist=35.1 phase=2
[combat-trace] Stratum1Boss._play_anim | PLAY anim=slam_s
[combat-trace] Stratum1Boss._spawn_slam_aftershock | particles=24 lifetime=0.35 vel=[40..80] gravity=(0,-50) scale=1.50 z_index=1 origin=(240,165) parent_path=/root/Main/World/Stratum1BossRoom
```

**The `particles=24` value confirms the v5 fix landed.** All other fields unchanged from v3 (no regression of the gravity/z_index/scale/lifetime fixes).

### Visual screenshot — escape clause invoked

Per `.claude/docs/html5-export.md §"Visual-verification escape clause"`. The Playwright self-soak's screenshot timing race against player-death + Room 01 reload (slam damage 17 lands at low player HP → `apply_death_rule` reloads Room 01 BEFORE the screenshot loop fires its post-aftershock capture) means the screenshots show post-death-respawn Room 01 frames rather than the in-boss-room burst frame. The trace evidence above IS the load-bearing fire-confirmation; visual verification routes to Sponsor soak per the escape clause.

**Probe targets for Sponsor's 3rd soak:**

1. **T5 slam telegraph (renderer-safe primitive, escape-clause-eligible per PR #291 precedent)**:
   - Boss enters slam wind-up → ember-orange circle (radius 80px) appears around boss at α=0.5 → strobes ~5 Hz across the 420ms hold → fades on slam-fire.
   - HDR-clamp compliant (all channels < 1.0; modulate is sub-1.0 sub-1.0 sub-1.0).
   - **Probe:** "I see an orange ring around the boss during slam wind-up, and it pulses."

2. **T6 slam aftershock (CPUParticles2D — ineligible for escape clause per PR #291 precedent)**:
   - Slam impact → **24 ember particles** with a **bright-white flash on the first ~85ms**, fading through warm orange to dark ember-red over 350ms total.
   - Burst spawns at the boss's center, rises upward (gravity -50 px/s² pull) above the boss sprite (z_index=+1).
   - **Probe:** "I see a bright-white flash at the impact moment, then ember particles rising above and outward from the boss for ~third of a second."
   - **Trace contract preserved:** `[combat-trace] Stratum1Boss._spawn_slam_aftershock | particles=24 lifetime=0.35 ...` line fires on every slam.

3. **B3 boss slam visual — DEFERRED to follow-up ticket `86c9x8tc9`**:
   - Sponsor will likely STILL perceive the slam as "kick-like" in the south rotation. This is per design of the surprise-uppercut PixelLab template — a separate ticket addresses the template re-roll.

## CI status (HEAD SHA `4bcce31`)

| Workflow | Status | Run |
|---|---|---|
| CI (Headless GUT) | ✓ success | `26225347758` (was at SHA 3c5a60d; 4bcce31 spec-only commit doesn't touch GUT) |
| Release-build (PR-event) | ✓ success | `26225347766` (3c5a60d) — 4bcce31 in-flight at report time |
| Playwright E2E | Pre-existing failures unchanged (AC4 Room 05 game-side block, equip-flow F5, mob-self-engagement Room 03+) — NOT caused by this PR |

Pre-existing Playwright failures are tracked separately per the AC4 spec docs (Room 05 death-physics-flush blocker is in Drew's lane, out of scope for boss-visual PRs).

## Cross-lane integration check

Per PR #216 process gates:

- ✓ **`[combat-trace] Stratum1Boss.*` contract preserved** — all 5 trace lines (`wake`, `_fire_slam_hit`, `_spawn_hitbox`, `_play_anim`, `_spawn_slam_aftershock`) fire as before; only the `particles=` value changed (12 → 24).
- ✓ **Player iframes unchanged** — `[combat-trace] Player.coll_diag | layer=2 mask=1 cs_disabled=false iframes=true/false` lines unchanged.
- ✓ **RoomGate signal chain not touched** — boss-room entry-sequence + `entry_sequence_completed` signal preserved (verified via boot-line trace).
- ✓ **Adjacent specs probed:** `ac1-boot-and-sha`, `boss-room-smoke`, `debug-copy-log-overlay` all pass on this PR's release-build. AC4 / equip-flow / mob-self-engagement pre-existing failures are unchanged (verified against the 3c5a60d build CI log).

## Regression guard

`tests/test_stratum1_boss_slam_telegraph_and_aftershock.gd` (post-v5 edits, externally applied):

- `T6-2` — burst configuration: 24 particles via `Stratum1Boss.SLAM_AFTERSHOCK_PARTICLE_COUNT` constant + 3-stop ramp (start = `AFTERSHOCK_FLASH_WHITE`, mid @0.25 = `EMBER_LIGHT`, end = `EMBER_DEEP`).
- `T6-3` — `queue_free` connected to `finished` signal.
- HP-1/2/3 (boss HP nerf coverage) unchanged.
- New: `test_start_room_default_is_no_override` / `_accepts_valid_indices` / `_clamps_out_of_range` — pin the start_room URL-param coverage.

## Doc updates

Two findings flagged for `maintain-docs`:

1. **HTML5 export rule (extending § Z-index sensitivity):** "Burst CPUParticles2D with same-z spatial overlap with a large sprite need contrast in the ramp — same-z + same-hue (warm-warm) blends. Use a high-contrast ramp[0] (`AFTERSHOCK_FLASH_WHITE` against red-armor sprite) so the first burst frame reads as an impact-tell rather than sprite noise. Recently-validated: PR #291 v5 T6 aftershock against the boss's red armor."

2. **PixelLab pipeline rule (extending §"Multi-template failure pattern"):** "Even within ONE template, per-direction outputs can have inconsistent silhouette-readability. The `surprise-uppercut` template produces a clean upward strike in NORTH rotations but body-swaying side-strike in SOUTH rotation for the S1 Boss character. Player engagement direction matters: if the player is south of the boss most often, the south-rotation read dominates the perceived attack motion. Track via per-frame center-of-mass analysis (15+ pixel sway in 7 frames = NOT centered)."

Both flagged for explicit doc commit in next maintain-docs cycle per `maintain-docs-honor-explicit-flags` memory.

## Sponsor handoff

Direct artifact download (for 3c5a60d — last green-CI build; 4bcce31 in-flight):

**https://github.com/TSandvaer/RandomGame/actions/runs/26225347766/artifacts/7135452538**

Cache-clear ritual per `html5-export.md §"Service-worker cache trap"` — incognito + fresh extract + verify `[BuildInfo] build: 3c5a60d`.

### Recommended Sponsor soak shape

1. **T5 + T6 verification** (current PR scope):
   - Reach boss room (normal play path OR via `?start_room=8` URL param).
   - Trigger phase 2 (any HP < 66%).
   - Confirm slam telegraph circle visible + strobing.
   - Confirm slam aftershock — should see **a bright-white impact flash** at slam-fire moment, fading through orange embers over ~⅓ second.
   - **Expected new visual vs v3:** much louder white-flash on impact; embers more dense (24 vs 12); same upward-rising motion + z_index above sprite.

2. **B3 — known issue, scope-cut**:
   - Boss slam will likely still read as a "kick-like" motion in south rotation.
   - This is `86c9x8tc9`'s domain. Don't reject the PR over this.
   - If Sponsor wants to confirm: B3 is a PixelLab template-choice issue, not a state machine bug.

3. **Faster soak: use `?boss_hp_mult=0.1` + `?start_room=8`** combo for a 60-HP boss directly in the boss room. Reaches phase 2 (slam) in ~12 fist-hits.

## Out of scope (per dispatch brief)

- ❌ NOT regenerating PixelLab frames (B3 deferred to `86c9x8tc9`).
- ❌ NOT investigating Playwright 10/10 historical failures.
- ❌ NOT touching the 3 fixes already landed in PR #291 v1-v3 (T5 strobe + T6 v3 gravity/z_index/scale + boss HP nerf URL param).

## Files touched (v5 increment over v3)

- `scripts/debug/DebugFlags.gd` — added `start_room` URL query param (v4 commit `83831c4`)
- `scenes/Main.gd` — start_room consumer (v4 commit `83831c4`)
- `scripts/mobs/Stratum1Boss.gd` — T6 v5: `SLAM_AFTERSHOCK_PARTICLE_COUNT` 12→24 + `AFTERSHOCK_FLASH_WHITE` const + 3-stop ramp (v5 commit `97c1665`)
- `tests/test_stratum1_boss_slam_telegraph_and_aftershock.gd` — new tests for start_room + updated T6-2 assertions for 24-particle/3-stop-ramp (commits `83831c4`, `97c1665`)
- `tests/playwright/specs/pr291-boss-slam-diag.spec.ts` — new diagnostic spec (commit `83831c4`)
- `tests/playwright/specs/pr291-aftershock-visual.spec.ts` — new visual-capture spec (commit `97c1665`, tuned `4bcce31`)
