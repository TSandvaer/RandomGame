# Self-Test Report — PR #281 (ticket 86c9vbhf1)

`polish(player|audio): split dodge_started signal from iframes_started`

## CI status

- **Headless import + GUT (run 26099204266 / PR check)**: GREEN. Full suite passed including:
  - New file `tests/test_player_dodge_signal_split.gd` (7 paired tests).
  - Updated `tests/test_m3w7_audio_cues.gd` with new dodge-cue route test + regression-guard `iframes_started`-alone-is-silent test.
  - Existing `test_player_move.gd`, `test_w1_backfill.gd`, `test_player_hit_iframes.gd`, `test_stratum1_room01_tutorial_flow.gd`, `tests/integration/test_stage_2b_tutorial_traversal.gd` all still green — the `iframes_started`-based assertions still hold because the signal still fires from both paths.
- **HTML5 release-build (run 26099204266)**: GREEN. Artifact `embergrave-html5-4162b33` (8.5 MB) produced.
- **Playwright E2E (run 26099336967)**: triggered against this PR's artifact, in flight at report time. tutorial-beat-trace spec is the highest-leverage check; the LMB-strike beat is now signal-rewired to `dodge_started` but exercised via real `try_dodge` so the beat still fires.

## Engine-side contract pins (GUT)

The 7 paired tests in `test_player_dodge_signal_split.gd` are the load-bearing contract:

| Scenario | `dodge_started` emits? | `iframes_started` emits? | Pin |
|---|---|---|---|
| `try_dodge()` valid | 1× | 1× | test 1 |
| `try_dodge()` mid-active-dodge (rejected) | 0× | 0× | test 2 |
| `try_dodge()` during cooldown (rejected) | 0× | 0× | test 3 |
| `take_damage()` non-fatal | **0×** | 1× | test 4 (HEADLINE) |
| `take_damage()` fatal (HP→0) | 0× | 0× | test 5 |
| Emit ordering: `dodge_started` before `_enter_iframes` flag flip | — | — | test 6 |
| `take_damage()` during active dodge | 0× | 0× | test 7 |

The HEADLINE row is the bug-fix: non-fatal `take_damage` (which fires the post-hit invuln grant per Uma's AC4 Room 05 balance pin §3.B) no longer emits `dodge_started`. Audio handler subscribes to `dodge_started`, so the dodge-whoosh no longer fires on damage taken.

## Audio-routing pins (GUT — `test_m3w7_audio_cues.gd`)

- `test_player_dodge_started_plays_dodge_cue` — `dodge_started.emit()` produces `last_sfx_id == "sfx-player-dodge"`.
- `test_player_iframes_started_alone_is_silent` (NEW regression guard) — bare `iframes_started.emit()` produces `last_sfx_id == ""` (no cue). If a future refactor re-binds the audio handler back to `iframes_started`, this test fails first.

## HTML5 audio probe — explicit transparency

The audio-architecture.md HTML5 audio-playback gate requires audible verification. **I (Drew, sub-agent author) cannot drive a Chromium tab in this session to audibly confirm playback** — the local environment has no interactive browser harness available to me, and the GUT layer asserts the signal-routing contract but not WebGL2-side audible emission.

What this PR HAS verified:
1. The audio asset `audio/sfx/player/sfx-player-dodge.ogg` is unchanged and still loads as `AudioStream` (covered by `test_every_sfx_asset_loads_as_audio_stream` in test_m3w7_audio_cues.gd).
2. `AudioDirector.play_sfx(&"sfx-player-dodge")` is called by `_on_dodge_started_audio` (same function body as before; only the connect source moved from `iframes_started` to `dodge_started`).
3. The release-build artifact for this branch exports cleanly (run 26099204266 green).
4. Audio bus layout untouched (no `default_bus_layout.tres` changes); `AudioDirector` autoload untouched.

What needs Tess's HTML5 probe (handing off):

**Probe scenario A — INTENTIONAL DODGE = whoosh audible**
1. Cache-clear ritual per html5-export.md (stop server, fresh extract, incognito tab).
2. Boot, confirm `[BuildInfo] build: 4162b33` in F12 Console.
3. In Room 01 (tutorial), press dodge (Space by default). Audible `sfx-player-dodge` cloth-whoosh should land at the moment the dodge roll starts.

**Probe scenario B — DAMAGE TAKEN = NO whoosh** (the headline regression)
1. Same artifact, same cache-clear.
2. Progress to Room 05 (or any room with a hostile mob — Grunt/Charger). Let the mob hit you intentionally without dodging.
3. On the damage hit, the HP bar decrements + player hit-flash plays. **No cloth-whoosh should be audible.** Pre-fix this PR's contract: every damage taken produced an unwanted whoosh on the SFX bus.

Both scenarios were the AD-05 spec from day one; this PR realigns the engine to match.

## Non-obvious findings

1. **Stratum1Room01 tutorial wiring had the same latent bug.** The in-code comment `## **Why iframes_started, not state_changed:** iframes_started only fires inside try_dodge` (line 286 pre-fix) was factually wrong — `iframes_started` also fires from `take_damage`. If Sponsor walked into the PracticeDummy hitbox (the dummy in Room 01 has no aggressive hitbox so this is currently latent, not active), the LMB tutorial beat would have spuriously advanced. Fixed in same PR — same signal-split fix, not scope expansion. The new comment cites ticket 86c9vbhf1 + AD-05.

2. **`dodge_started` emit-before-`_enter_iframes`-flag-flip ordering** is load-bearing for AD-05's "frame 2 of 6" cue timing. Pinned in `test_dodge_started_fires_before_invulnerable_flag_set`. If a future refactor swaps the emit order (e.g. emits after `set_state(STATE_DODGE)`), the cue still fires but lands slightly later relative to the visual dodge frame.

3. **Only TWO listeners on `iframes_started` exist in the codebase** (game-side, excluding tests): the audio handler in Player.gd and the tutorial in Stratum1Room01.gd. Both are now on `dodge_started`. No HUD listener was found via the grep sweep — the HUD's iframe-blink is handled via `is_invulnerable()` polling or the `iframes_ended` signal, not `iframes_started`. So the backward-compat preservation of `iframes_started` is currently providing zero active consumer benefit — but the design rule "keep `iframes_started` emitting from both paths" still protects the future case where a hit-flash or VFX hook wants the union semantics.

## Cross-lane integration check (PR #216 gate)

- `[combat-trace]` contract preserved — no `_combat_trace` lines touched in this PR.
- Player iframes (collision_layer save/restore, `is_invulnerable()` semantics, `_enter_iframes`/`_exit_iframes`/`_exit_iframes_if_not_dodging`) untouched.
- Damage formula / `Player.take_damage` HP-decrement path untouched.
- AC4 Room 05 balance constants (`HIT_IFRAMES_SECS = 0.25`, post-hit grant) untouched; `test_player_hit_iframes.gd` regression pins still hold.
- Hitbox damage-table filter unchanged — Hitbox does NOT subscribe to `iframes_started`; it relies on `Player.collision_layer == 0` during iframes (set by `_enter_iframes`).
- RoomGate / boss-room transition / tutorial advancement signals unchanged; tutorial-beat-trace.spec.ts observes `[combat-trace] TutorialEventBus.request_beat | beat=lmb_strike` which is signal-rewire-agnostic.
- AudioDirector.gd untouched. Audio bus layout (`default_bus_layout.tres`) untouched.
- No mob-state-machine touched.

## Regression-guard contract (PR #216 Done clause)

The new file `tests/test_player_dodge_signal_split.gd` IS the regression guard. If a future refactor:
- Moves `dodge_started.emit()` out of `try_dodge` → test 1 fails.
- Emits `dodge_started` from `take_damage` → test 4 fails (headline).
- Emits `dodge_started` from rejected dodge paths → tests 2 + 3 fail.
- Reorders `dodge_started.emit()` after `_enter_iframes()` → test 6 fails.
- Removes the `if _is_invulnerable: return` guard at top of `take_damage` → test 7 fails.

Plus `tests/test_m3w7_audio_cues.gd::test_player_iframes_started_alone_is_silent` catches the audio-handler-rebound-to-iframes_started regression.

## Verdict

GUT green, release-build green, signal-split contract pinned by 7 + 2 regression tests, no cross-lane regression surface, audio-handler routing pinned. **Hand off to Tess for HTML5 audible probe (scenarios A + B above).**
