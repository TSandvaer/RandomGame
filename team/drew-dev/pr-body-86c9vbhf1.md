# polish(player|audio): split `dodge_started` signal from `iframes_started`

ClickUp `86c9vbhf1`. Restores Uma's `team/uma-ux/audio-direction.md §AD-05` semantics: "dodge-whoosh plays ONLY on intentional dodge".

## Problem

Tess flagged on PR #278: dodge-whoosh (`sfx-player-dodge`) fires on every `iframes_started` emit. But `Player.iframes_started` emits from BOTH:

- `try_dodge()` → `_enter_iframes()` (intentional dodge — the AD-05 trigger)
- `take_damage()` → `_enter_iframes()` (post-hit invuln grant — Uma's AC4 Room 05 balance pin §3.B, ticket 86c9u4mdc)

So every damage taken produced an unwanted whoosh — violating AD-05 "intentional dodge ONLY".

## Diagnostic trace evidence

Confirmed by reading the engine-side emit paths in `scripts/player/Player.gd` BEFORE writing the fix (per `diagnostic-traces-before-hypothesized-fixes`):

| Path | Call site | `_enter_iframes` reached? | `iframes_started` emit? | `dodge_started` emit (post-fix)? |
|---|---|---|---|---|
| Valid `try_dodge()` | line 944, after `can_dodge()` passes | yes (line 962) | yes (1×) | **yes** (1×) |
| `take_damage()` non-fatal | line 723, after `if _is_invulnerable: return` and after `if hp_current == 0: _die(); return` | yes (line 802) | yes (1×) | **no** (the bug fix) |
| `take_damage()` while already invulnerable | line 723 | NO — early return at line 726 | no | no |
| `take_damage()` fatal | line 723 | NO — early return at line 780 after `_die()` | no | no |
| Rejected `try_dodge()` (cooldown / mid-dodge) | line 944 | NO — early return at line 946 | no | no |

The ticket's framing was correct on first read this time — no diagnostic refutation needed. The fix shape proposed in the brief (add dedicated `dodge_started`, keep `iframes_started` backward-compat) is the minimal change that satisfies AD-05 without churning HUD/Hitbox/test consumers that depend on `iframes_started`.

## Fix

1. **New signal `dodge_started` on Player** (`scripts/player/Player.gd:50-62`). Emitted ONLY from `try_dodge()` after `can_dodge()` validation passes, BEFORE `_enter_iframes()` so the audio cue lands at the same instant the i-frame window opens (matches AD-05 "frame 2 of 6 of the dodge animation").

2. **`iframes_started` behavior unchanged.** Both paths still emit it. HUD blink, Hitbox damage-table drop, AC4 Room 05 balance tests, dodge-VFX hooks all keep working unchanged.

3. **Audio listener rewired** (`scripts/player/Player.gd:434-450`). `_on_dodge_started_audio` (renamed from `_on_iframes_started_audio`) connects to `dodge_started`. Same `ad.play_sfx(&"sfx-player-dodge")` body — only the signal source changes.

4. **Tutorial listener also rewired** (`scripts/levels/Stratum1Room01.gd:253-254`, `_on_player_dodge_started`). The Stratum1Room01 tutorial LMB-strike beat subscribed to `iframes_started`. The in-code comment claimed "iframes_started only fires inside try_dodge" — that was **factually wrong**; the tutorial's first damage taken (e.g. dummy hitback if Sponsor walked into a stationary PracticeDummy hitbox cluster) would have spuriously advanced the LMB beat. Same fix shape: subscribe to `dodge_started` instead. This is the SAME signal-split fix — same line of code, same correction — not scope expansion.

## Tests

### New file: `tests/test_player_dodge_signal_split.gd` (7 paired tests)

Pins the engine-side signal-split contract:

1. `try_dodge()` valid → emits BOTH `dodge_started` AND `iframes_started` (1× each).
2. `try_dodge()` rejected during active dodge → emits NEITHER.
3. `try_dodge()` rejected during cooldown → emits NEITHER.
4. `take_damage()` non-fatal → emits ONLY `iframes_started`, NEVER `dodge_started` (headline regression guard).
5. `take_damage()` fatal → emits NEITHER (death path consumes the frame).
6. `dodge_started` fires BEFORE `_enter_iframes` flips `is_invulnerable` (audio cue lands at iframe-window-open instant per AD-05).
7. `take_damage()` during active dodge → emits NEITHER (early-returns at the `_is_invulnerable` guard before reaching `_enter_iframes`).

NoWarningGuard wired per `.claude/docs/test-conventions.md` Universal warning gate.

### Updated: `tests/test_m3w7_audio_cues.gd`

- `test_player_iframes_started_plays_dodge_cue` → renamed to `test_player_dodge_started_plays_dodge_cue`, emits `dodge_started` instead.
- **NEW** `test_player_iframes_started_alone_is_silent` — explicit regression guard. Bare `iframes_started.emit()` MUST NOT produce `sfx-player-dodge` (the bug PR #278 shipped).
- Docstring updated: `Player.iframes_started → NO SFX (post-hit grant path)`.

### Preserved test coverage

The existing `iframes_started`-based assertions remain green by construction:

- `test_player_move.gd::test_iframes_signal_fires` (line 79) — `try_dodge` still calls `_enter_iframes` which emits `iframes_started` exactly once.
- `test_w1_backfill.gd::test_iframes_signal_count_per_dodge_is_one_each` (line 334) — same.
- `test_player_hit_iframes.gd` — entire file pins `take_damage` → `_enter_iframes` invariants which are untouched.
- `test_stratum1_room01_tutorial_flow.gd::test_dodge_fires_lmb_strike_beat` (line 121) — exercises real `try_dodge`, which now emits `dodge_started`; the tutorial listener was rewired to that signal, so the beat still latches.
- `tests/integration/test_stage_2b_tutorial_traversal.gd` — same: real `try_dodge` path.
- `tests/playwright/specs/tutorial-beat-trace.spec.ts` — observes the `[combat-trace] TutorialEventBus.request_beat | beat=lmb_strike` line. Spec is signal-agnostic; rewire preserves the beat emit.

## Cross-lane integration check (PR #216 gate)

- `[combat-trace]` contract preserved — no `_combat_trace` lines touched.
- Player iframes unchanged — `_enter_iframes` / `_exit_iframes` / `_exit_iframes_if_not_dodging` untouched; collision-layer save/restore untouched; `is_invulnerable()` returns same values at same times.
- AC4 Room 05 balance (`HIT_IFRAMES_SECS = 0.25` post-hit grant) untouched. `test_player_hit_iframes.gd` regression pins still hold.
- Audio path: `AudioDirector.play_sfx(&"sfx-player-dodge")` unchanged — only the upstream signal source moves.
- Hitbox team semantics untouched — Hitbox does NOT subscribe to `iframes_started`; it polls `Player.is_invulnerable()` via the collision_layer drop. Signal-split has zero impact on hitbox damage filtering.
- RoomGate signal chain untouched.
- HUD/PlayerHud `iframes_started`/`iframes_ended` listeners (if any) — unchanged: `iframes_started` still fires on both paths.

## HTML5 release-build visual-audio probe

Per `.claude/docs/audio-architecture.md` HTML5 audio-playback gate — see Self-Test Report comment.

## Doc updates

None. The change preserves existing `iframes_started` semantics and adds a sibling signal; combat-architecture / audio-architecture docs already cover the signal-split pattern at the abstraction level (`signal X fired by Y`). The audio-direction.md AD-05 already specifies "intentional dodge ONLY" — this PR makes the engine honor that, the doc is the source of truth and stays as-is.

## Non-obvious findings

- **Stratum1Room01 tutorial wiring had the same latent bug.** The in-code comment "iframes_started only fires inside try_dodge" was wrong — `take_damage`'s post-hit grant also emits it. Drew-side audit caught this during the grep sweep for `iframes_started.connect`. Fixed in the same PR (it's the same signal-split fix, not scope expansion).
- **`dodge_started` emit ordering vs `_enter_iframes`** matters for the AD-05 "frame 2 of 6" cue timing. Pinned in `test_dodge_started_fires_before_invulnerable_flag_set` — the observer of `dodge_started` sees `is_invulnerable() == false` because the emit precedes the flag flip.
- **Tutorial LMB-beat is a stronger semantic match for `dodge_started` than `iframes_started`**: the comment in Stratum1Room01.gd explicitly wanted "the moment a dodge actually starts" — that's `dodge_started` by construction.

## Test commands

```
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=tests -gprefix=test_ -gsuffix=.gd -ginclude_subdirs=true \
  -gselect=test_player_dodge_signal_split.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gselect=test_m3w7_audio_cues.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gselect=test_stratum1_room01_tutorial_flow.gd
```

## Ticket

ClickUp `86c9vbhf1` — Drew lane. Polish, no scope expansion.
