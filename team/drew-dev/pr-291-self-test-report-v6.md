# PR #291 Self-Test Report v6 — author HTML5 self-soak (per Tess REQUEST CHANGES 2026-05-21)

**Verdict: PASS — T6 v5 fix visually verified in author's own browser session against release artifact.**

## Procedural acknowledgement

The v5 Self-Test Report invoked the visual-verification escape clause for T6. Tess (correctly) REQUEST CHANGES'd that — the v5 fix shipped `?start_room=N` URL-param tooling AND `pr291-aftershock-visual.spec.ts` in the same PR, which makes CLI-agent self-soak structurally feasible. The escape clause's CLI-edge case (test-conventions.md § "Author HTML5 self-soak") only applies when self-soak is structurally infeasible. It is not.

This v6 corrects that. Author self-soak now executed and documented below.

## Soak setup

- **Artifact:** `embergrave-html5-5d7ee84.zip` from release run `26226285338` ([artifact link](https://github.com/TSandvaer/RandomGame/actions/runs/26226285338/artifacts/7135861255))
- **Extracted to:** worktree `.claude/tmp/soak-5d7ee84/embergrave-html5-5d7ee84/` (gitignored — see nit cleanup below)
- **Served via:** `RELEASE_BUILD_ARTIFACT_PATH=... npx playwright test ...` (canonical artifact-server fixture, ephemeral port)
- **URL:** `?start_room=8&boss_hp_mult=0.05` — boss room (index 8 per `DebugFlags.START_ROOM_MAX`), boss at 30 HP (600 × 0.05) → phase 2 latches at 18 HP, well within combat window
- **BuildInfo SHA verified:** `5d7ee84` visible bottom-left of every captured frame

## Spec design

The v5 `pr291-aftershock-visual.spec.ts` runs 120ms iteration cadence with one screenshot per iteration. Its time-stamps confirmed an iteration boundary lands at t+241ms post-aftershock-fire — that's PAST the 0-85ms `AFTERSHOCK_FLASH_WHITE` ramp[0] window. To catch the white-flash frame I ran a tight-cadence local-only capture spec (not committed — used solely for this self-soak) that:

1. Polls trace lines every 20ms during combat
2. On `_spawn_slam_aftershock` detection, fires 12 screenshots at ~20ms intervals (covers 0-240ms post-fire — the flash + ember-light ramp window)
3. Plus 3 late frames at 50ms intervals (ember-deep + post-burst)

Tighter cadence used screenshot-serialization overhead (~160ms per frame) as the actual interval — frame indices remain monotonic and labeled with `Date.now() - aftershockFiredAt`.

## T6 v5 fix observed in browser

**Trace confirmation:**
```
[combat-trace] Stratum1Boss._spawn_slam_aftershock | particles=24 lifetime=0.35 vel=[40..80] gravity=(0,-50) scale=1.50 z_index=1 origin=(240,165) parent_path=/root/Main/World/Stratum1BossRoom
```
- `particles=24` ✓ (up from v3's 12)
- `lifetime=0.35` ✓
- `parent_path=/root/Main/World/Stratum1BossRoom` ✓ (room-parenting, so burst persists past slam-recovery)
- `scale=1.50` ✓
- `z_index=1` ✓ (above boss z=0)

**Screenshot evidence** (committed to `team/drew-dev/pr291-v5-self-soak-evidence/`):

| Frame | t post-fire | Ramp phase | Observation |
|---|---|---|---|
| `burst-00-flash-window.png` | ~1 ms | ramp[0] AFTERSHOCK_FLASH_WHITE (#FFF2BF) | Dense pinkish-white particle cluster around boss feet. The bright-white impact frame is captured — particles read distinct from the boss's red armor due to luminance contrast (the v3-v4 issue was ember-only ramp washed out against red; v5 ramp[0] flash-white solves this). |
| `burst-01-ember-light.png` | 163 ms | ramp[0.25] EMBER_LIGHT transition | Particles have spread outward radially — lighter dots scattered around boss with gravity lifting them slightly upward (gravity=(0,-50)). Ramp transitioning through ember-light. |
| `burst-02-ember-deep.png` | 330 ms | ramp[1.0] EMBER_DEEP | Particles further spread, ramp colors deeper red — still distinct in shape from boss sprite. Within 350 ms lifetime tail. |
| `burst-03-post-burst.png` | 505 ms | post-lifetime tail | Some particles still visible mid-flight (one_shot tween residual). Confirms burst persists past slam-recovery (slam animation ~400 ms). |

## T5 telegraph blink — also verified

Pre-fire screenshot (frame `pre-011` from the canonical interleaved-capture spec, captured 293ms before aftershock fire) shows the **red `draw_arc` outline circle around the boss** at the SLAM_HIT radius. The 5 Hz alpha-strobe (modulate.a [0.25 ↔ 1.0]) was visible across consecutive pre-frames as alpha variation in the indicator ring. T5 verified.

## B4 HP nerf — also verified

`?boss_hp_mult=0.05` applied — boss HP HUD reads near-empty throughout combat (boss died at frame 4 of one combat sequence; spec re-attacked across multiple phase cycles). Resolved value path: `DebugFlags._resolve_boss_hp_mult()` → `Stratum1Boss._resolve_boss_hp_mult()` returns 0.05 → max_hp = 30. Behaves correctly.

## B3 (slam-kick / weapon-uppercut) — acknowledged deferred

Slam animation still plays the body-aligned side-strike rather than a weapon-uppercut, per the known per-direction PixelLab template variance documented in follow-up `86c9x8tc9`. Out of scope for this PR.

## Console

- BuildInfo `5d7ee84` confirmed (visible bottom-left every frame)
- `[combat-trace] Stratum1Boss._spawn_slam_aftershock` line present with `particles=24`
- No red errors — universal `USER WARNING` / `USER ERROR` zero-assertion (test-base.ts auto-teardown) passed
- Universal console-warning gate green

## Nit cleanup (per Tess's non-blocking notes)

- **`.claude/tmp/` gitignored** — added `**/.claude/tmp/` pattern (matches both worktree-root and nested `tests/playwright/.claude/tmp/`). Prior `.claude/tmp/` screenshots are not committed; this v6 self-soak's screenshot evidence lives in `team/drew-dev/pr291-v5-self-soak-evidence/` (committed, since these are the gate-clearing artifacts).
- **Stale base / rebase** — `git fetch origin && git rebase origin/main` performed before push. Base now caught up to current main.

## Pass/fail call

**PASS** — T6 v5 fix observed in author's own Playwright session against the release artifact. The `AFTERSHOCK_FLASH_WHITE` ramp[0] impact frame is perceptually distinct from the boss's red armor (luminance contrast, not hue contrast); particles render at scale=1.5 z=1 above boss sprite; 24-particle count visible; room-parenting confirmed via trace.

Re-requesting Tess QA.
