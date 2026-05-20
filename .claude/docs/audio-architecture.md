# Audio Architecture — bus layout, AudioDirector, transitions

What this doc covers: the runtime audio plumbing for Embergrave. The
`default_bus_layout.tres` 5-bus structure, the `AudioDirector` autoload
that owns global BGM/Ambient transitions, the S1→S2 transition wiring,
the boss-room crossfade pattern, and the HTML5 audio-playback gate.

For the **content side** of audio (cue list, mood direction, sourcing
plan, dB targets per cue, tester checklist), see
[`team/uma-ux/audio-direction.md`](../../team/uma-ux/audio-direction.md).
This doc is the runtime / integration counterpart.

## Bus layout

`default_bus_layout.tres` at the repo root, registered via
`project.godot::[audio] buses/default_bus_layout`. Five buses:

| Bus | dB | Purpose |
|---|---|---|
| `Master` | 0 dB | Final output (reference level: peak -1 dBFS, target -16 LUFS HTML5) |
| `BGM` | -12 dB | All `mus-*` cues (stratum BGM, boss music) |
| `Ambient` | -18 dB | All `amb-*` cues (room ambient bed, torch loops) |
| `SFX` | -6 dB | All `sfx-*` combat / item / world cues (NOT UI) |
| `UI` | -10 dB | UI clicks, save toast, tab open/close, ticks |

`Voice` bus is intentionally **not** provisioned yet — reserved for M2+
per `audio-direction.md §3`. Adding the same day the first voice cue
ships.

**Sidechain ducking** (SFX→BGM -6 dB, SFX→Ambient -3 dB, panel-open duck)
is intentionally **deferred** to a follow-up PR — the W3-T9 baseline
establishes buses so cue consumers can target by name; the
`AudioEffectCompressor` wiring lands as a second pass once we have
audible content to tune against.

**Regression guard:** `tests/test_audio_bus_layout.gd` — asserts all 5
buses exist by name, dB targets match, Master parent relationship holds,
no boot-time mute/solo. If a future PR drops the layout or renames a bus,
every `AudioStreamPlayer.bus = "BGM"` setter silently falls back to
Master (Godot's default) and the dB attenuations vanish; this test
catches that at CI time.

## AudioDirector autoload

`scripts/audio/AudioDirector.gd` is the central owner of BGM + Ambient
transitions. Registered as autoload `AudioDirector` in `project.godot`.

### Why an autoload, not a Main.gd member

Every stratum-transition, boss-room load, and player-death event needs
to reach the audio plumbing from a distinct call site. Routing through
`Main.gd` would couple audio to the M1 play-loop scene (which is itself
getting torn down + rebuilt on respawn). An autoload survives scene-tree
swaps and is reachable as `AudioDirector.play_stratum2_bgm()` from any
node.

### Node topology

```
AudioDirector (Node, autoload)
├── BgmPlayer (AudioStreamPlayer, bus = BGM)
├── BgmCrossfadePlayer (AudioStreamPlayer, bus = BGM)
└── AmbientPlayer (AudioStreamPlayer, bus = Ambient)
```

Two BGM players exist so crossfades have a "from" and "to" slot. After
a crossfade completes, the variable references swap so future calls
operate on the right player without ambiguity. The crossfade companion
is the same `BGM`-bus class; only the variable role changes.

### Public API

```gdscript
# S1→S2 entry. Fade in (default 600 ms) on the BGM bus.
AudioDirector.play_stratum2_bgm(fade_in_ms := 600)

# S1→S2 entry. Fade in (default 600 ms) on the Ambient bus.
AudioDirector.play_stratum2_ambient(fade_in_ms := 600)

# Convenience: fires both at once. Canonical Main.gd / DescendScreen entry.
AudioDirector.play_stratum2_entry()

# Boss room — crossfade BGM to mus-boss-stratum2.ogg over 600 ms.
# Honors Uma's UNIQUE not-cross-stratum-reuse decision (DECISIONS.md 2026-05-15).
AudioDirector.crossfade_to_boss_stratum2(fade_ms := 600)

# Boss room (S1) — crossfade BGM to mus-boss-stratum1.ogg over 600 ms.
# Same role-swap pattern as the S2 variant.
AudioDirector.crossfade_to_boss_stratum1(fade_ms := 600)

# S1 ambient — start/keep playing the room bed. Idempotent across room-cycle.
# Default fade 800 ms ease-in-out quadratic. target_gain_db = 0.0 nominal.
AudioDirector.play_stratum1_ambient(fade_in_ms := 800, target_gain_db := 0.0)

# S1 ambient — fade out on boss-room entry (BI-03). 600 ms ease-out cubic.
AudioDirector.stop_stratum1_ambient(fade_out_ms := 600)

# S1 ambient — F4 post-defeat resume sugar. Wraps play_stratum1_ambient with
# the -4.4 dB (60% nominal) target. Caller doesn't compute dB math.
AudioDirector.resume_stratum1_ambient_at_60_percent(fade_in_ms := 800)

# Global stop — used by player-death (Beat A) and "leave to title" paths.
AudioDirector.stop_all_music(fade_out_ms := 600)
```

### Idempotence

`play_stratum2_bgm()` checks `_last_bgm_path == STREAM_PATH_S2_BGM && _bgm_player.playing`
before kicking the cue. A second call while the same stream is already
playing is a no-op — won't re-seed the position to 0 or glitch the loop.
Same for `play_stratum2_ambient()` and `crossfade_to_boss_stratum2()`.

### Stream caching

Streams (`AudioStreamOggVorbis`) are lazy-loaded on first use and cached.
The first call to `play_stratum2_bgm()` pays the `.ogg` decode + resource
load cost; subsequent calls reuse the same `AudioStream` object. This
matters less in Godot 4.3 (resource cache handles repeated `load()`
calls cheaply) but explicit caching makes the cost path unambiguous.

### Stream loop flag

OGG cues are looped via `AudioStreamOggVorbis.loop = true` set on the
stream resource at first load. `_set_stream_loop()` uses `"loop" in stream`
to check for the property before setting — works on both `AudioStreamOggVorbis`
and `AudioStreamWAV` (different sub-property names internally, but both
expose `loop` at the GDScript level).

## Transition wiring

### S1→S2 entry trigger

`Main._on_descend_restart_run()` — fires when the player clicks "Return
to Stratum 1" on the DescendScreen. This is semantically the S1→S2
stratum step even though the M1 placeholder reloads Room 01 rather than
a real Stratum 2 scene. Firing S2 audio here means the audio identity
for Cinder Vaults is audible from the moment the player chooses to
descend.

When an actual S2 scene transition lands (post-M2 W3), this trigger
moves to the scene-load callback alongside `_load_room_at_index(0)`.
The wiring is one line — search for `audio_director.play_stratum2_entry()`
in `scenes/Main.gd`.

### Boss-room crossfade (deferred)

`Stratum2BossRoom.tscn` does not exist yet — W2-T3 ticket lands the boss
room scene. When it does, the wiring is:

```gdscript
# In Stratum2BossRoom._ready() or its equivalent of
# Stratum1BossRoom.entry_sequence_started signal handler:
var ad: Node = get_tree().root.get_node_or_null("AudioDirector")
if ad != null and ad.has_method("crossfade_to_boss_stratum2"):
    ad.crossfade_to_boss_stratum2()
```

The crossfade duration (600 ms) matches `audio-direction.md §3 Ducking
rule 4` for boss-intro Beat 5.

### S1 boss-room — no-current-BGM case (pure fade-in, not a swap)

`Stratum1BossRoom` enters **silent** — no stratum BGM is playing on the BGM bus
before the entry sequence fires. This is a structural asymmetry from the S2
boss-room case, where ambient/stratum BGM is active and the crossfade is a
true swap (fade out current → fade in boss BGM simultaneously).

For S1 the crossfade implementation must treat the "no current BGM" case as a
**pure fade-in**: bring the boss BGM up from silence without attempting to fade
out a non-playing stream. Failing to handle this correctly produces one of two
silent bugs:

- If the code tries to fade FROM the idle `BgmPlayer` (volume = -inf), boss BGM
  plays at zero volume and is inaudible.
- If the code short-circuits entirely when no stream is playing, the fade is
  skipped and boss BGM starts abruptly at full volume.

**Implementation guard:** before starting any crossfade, check whether the
current `BgmPlayer` is actually playing (`_bgm_player.playing`). If not,
skip the fade-out half and start only the fade-in on `BgmCrossfadePlayer`.

| Scenario | `BgmPlayer.playing` on entry | Correct behaviour |
|---|---|---|
| S2 boss room (nominal) | `true` — stratum BGM active | Crossfade: fade OUT running stream, fade IN boss BGM |
| S1 boss room (silent entry) | `false` — no BGM active | Pure fade-in: skip the fade-out step; start `BgmCrossfadePlayer` at volume 0 and tween to nominal |

**Implementation note (PR #288 — in QA at time of writing):** `AudioDirector.crossfade_to_boss_bgm()`
gates the fade-out branch on `_bgm_player.playing` before starting the tween. If `_bgm_player`
is not playing, it skips straight to the fade-in branch on `_bgm_crossfade_player`. This
is the pattern to follow for any future `crossfade_to_boss_stratumN()` variant.

### Player death (Beat A)

`Main._on_player_died()` calls `stop_all_music(200)` synchronously so
the audio cut lands alongside Uma's Beat A visual freeze rather than one
frame later. Per `audio-direction.md §3 Ducking rule 3`.

## HTML5 audio-playback gate

Browsers gate `AudioContext` activation behind a user gesture (click,
keypress, touch). Until the player interacts with the page, ALL audio is
silently silenced — `AudioStreamPlayer.play()` succeeds from the
engine's perspective but no sound emits.

Embergrave currently boots straight into Stratum1Room01 (no menu, no
title screen). The first audio cue MUST fire **after** a user gesture
or it will be silent in HTML5 only — desktop/headless are unaffected.

### Safe-by-default cue sites

- **DescendScreen "Return to Stratum 1" button click** → S2 BGM + Ambient.
  Click IS a user gesture; AudioContext unlocks here.
- **First player attack input** → SFX cues. Mouse/keyboard press is a
  gesture.
- **First inventory toggle** → UI cues.

### Unsafe cue sites (need explicit gesture forward)

- **Any `_ready` of a scene loaded at boot** — no gesture yet. Don't fire
  audio from there.
- **Any signal that fires before the player has pressed any key.**

If a future cue needs to fire pre-gesture (e.g. title-screen music), an
explicit `AudioContext.resume()` hook is needed. Intentionally not added
now — no current cue is in that path.

### Verification gate

PRs touching the audio pipeline (`scripts/audio/`, `default_bus_layout.tres`,
`AudioStreamPlayer` wiring on scene roots) require an **HTML5
release-build audio-playback Self-Test Report** before merge — analogous
to the visual-verification gate in `html5-export.md`. Headless GUT cannot
verify playback.

Verification protocol:

1. `gh workflow run release-github.yml --ref <branch>`
2. Wait for the run, download artifact, extract to a fresh folder.
3. `python -m http.server 8000` in the extracted dir.
4. Open `http://localhost:8000` in incognito (bypasses service-worker
   cache per `html5-export.md`).
5. F12 → Console; watch for `AudioContext` warnings (`"The AudioContext
   was not allowed to start"`, `AudioDecodingError`, etc.).
6. Walk through the scenario that fires the cue (e.g. die → respawn →
   walk to boss → kill boss → click descend portal → "Return to Stratum 1"
   → S2 BGM should kick in).
7. **Audibly verify** the cue plays. The browser console excerpt + the
   audible confirmation are both required in the PR's Self-Test Report.

## Tonal pattern — silence as punctuation

**Rule:** when a UI moment must land hard (defeat title card, stratum-clear card, narrative beat), **the absence of audio IS the cue** — do not add a sting, chime, or bell under the card. Adding audio under a silence-anchored moment diffuses the tonal weight; the preceding gameplay audio (e.g. the F2 boss horn) is the audio event, and the silence that follows is the punctuation.

> Uma's formulation (M3-T4 brief, §3): "The F2 horn IS the audio. The silence after IS the punctuation."

**As-built example:** `BossDefeatedTitleCard` (`scripts/ui/BossDefeatedTitleCard.gd`) fires no audio. The boss horn (sibling ticket T16) completes at approximately T+2.1 of the boss-died timeline; the card fades in at T+1.2 and the horn tails out into silence during the hold phase. The 0.8 s hold is audibly empty by design.

**Negative spec for any future "moment-lands-here" surface:**
- No bell / chime / sting under the card.
- No UI cue reuse (`sfx-ui-tab-open` is a panel cue, not a defeat cue).
- No `sfx-ember-rise` reuse — ember-rise is the player's-flame-forward cue (descend, level-up); the boss-death card is about the boss being *gone*, not the player ascending. Wrong tonal register.

**Future application:** any stratum-clear card, intro sting, or narrative-beat UI surface should default to *no audio under the card* and require an explicit Uma decision to add audio. The emotional beat lives in the contrast with the preceding fight audio, not in a new cue.

**Exception:** a cue is acceptable under the card only if Uma explicitly identifies it as additive (e.g. a very low ambient swell that reinforces silence rather than filling it). This is a creative call, not a technical one; default is silence.

## Tonal pattern — cross-stratum distinct ambient (project-level policy)

**Rule:** every stratum's BGM and ambient bed is **distinct content** from every other stratum's, NOT a tone-match cousin. Same dark-folk-chamber palette discipline (per `audio-direction.md §1`), DIFFERENT composition / texture / pacing. The contrast between strata is load-bearing for the descent narrative — if S1 ambient mimics S2's pressure texture, the S1→S2 descent loses its tonal beat.

**Decision shape:** the same project-level rule as boss music. The boss-music UNIQUE decision (DECISIONS.md 2026-05-15) established that S1 boss music is NOT a remix of S2 boss music — different composition, separate `compose_*` script, distinct identity. The ambient parallel (S1 ambient = "stone cloister settled into silence" / S2 ambient = "Cinder Vaults active pressure") follows the same shape. **Stratum identity > cross-stratum economy** is the underlying principle: the descent narrative is the asset, and the inter-stratum contrast IS the gameplay.

**Empirical anchors:**
- **S2 ambient** (`amb-stratum2-room.ogg`, PR #210): steam-hiss + sub-bass vein-pulse + scree-rustle — active pressure, mechanically alive room.
- **S1 ambient** (`amb-stratum1-room.ogg`, PR T10 / `86c9wjyke`): soft stone reverb tail + irregular distant drips + faint sub-300 Hz wind — post-active sparsity, a cloister settled into silence.
- **S2 boss music** (`mus-boss-stratum2.ogg`, PR #210): minor-third cello tension (D2 + F2) + driving 80 BPM frame drum.
- **S1 boss music** (`mus-boss-stratum1.ogg`, PR #288 T1): perfect-fifth cello (D2 + A2) + steadier 72 BPM ritual drum.

**Implementation tell:** every stratum's audio gets its own `compose_*.py` placeholder script. If a future PR proposes reusing one stratum's OGG for another (e.g. "amb-stratum1-room.ogg = amb-stratum2-room.ogg with a low-pass filter"), reject under this policy — same shape as the boss-music UNIQUE precedent.

**Future application:** any new stratum (S3+) ships its own distinct BGM + ambient bed. The cost (one more `compose_*.py` + asset) is small; the value (preserving the descent narrative) is large.

## Stratum-1 ambient — wiring + curves

The S1 ambient bed is wired in three places, all gated on the **same Uma-locked curves** for tonal consistency:

| Trigger | API call | Duration | Curve | Target dB |
|---|---|---|---|---|
| Room load (non-boss) | `play_stratum1_ambient()` | 800 ms | ease-in-out quadratic | 0 dB (full) |
| Boss-room entry (BI-03) | `stop_stratum1_ambient()` | 600 ms | **ease-out cubic** | -80 (silence) |
| Boss defeated (F4) | `resume_stratum1_ambient_at_60_percent()` | 800 ms | ease-in-out quadratic | -4.4 dB (60%) |

**Curve discipline (Uma's brief §"Cross-fade shapes"):** the entry fade-out is **ease-out cubic** (front-loaded "dive") while the resume fade-in is **ease-in-out quadratic** (gentle, unhurried). The asymmetry IS the tonal beat — entry is "the room closing around the player"; resume is "the room settling back around them". A linear fade on either rejects under Uma's direction.

**Wiring rationale (T10):**

- **Room-load callback** (`Main._load_room_at_index`, index 0..7): Single fan-out site, hits idempotence on every room-cycle (R1→R2→R1 no-op). Index 8 (boss room) is explicitly skipped — the entry-sequence handler is the only ambient-control path inside the boss room.
- **`Stratum1BossRoom.entry_sequence_started` handler** (`_on_entry_sequence_started_audio`): Fires at Beat 2 (T+0 of the 1.8 s entry sequence). The ambient duck PRECEDES the BGM kick by ~1.2 s — BI-03 (ambient-off) is Beat 2, BI-05 (boss-BGM-on) is Beat 5. Two different beats; same `Stratum1BossRoom` signal pair (`started` / `completed`) carries both.
- **`BossDefeatedTitleCard.title_card_dismissed` handler** (wired in `Main._on_boss_defeated`): Fires AFTER the silence-as-punctuation hold completes, so the F4 resume doesn't land under the card. Uma's brief §"F4 / Coordination with title card" locks the post-card timing.

**Cold-boot first-room HTML5 caveat:** on a fresh-load run the player loads directly into Room01 with no prior gesture. `play_stratum1_ambient` runs from `_load_room_at_index` (during boot `_ready`), which is pre-gesture — the HTML5 AudioContext is still locked, so `.play()` succeeds silently with no audible output. The bed becomes audible on the player's first input (WASD / mouse), which unlocks the context retroactively. This is the same gate every other audio cue inherits per § HTML5 audio-playback gate; no engine-side `AudioContext.resume()` hook is needed because the playing-but-silent state self-heals on first input.

## `[combat-trace]` audio observability — Playwright QA pattern

Headless GUT cannot hear audio; `AudioStreamPlayer.play()` succeeds silently in the test environment. The `[combat-trace]` shim is the Playwright-observable audio surrogate: `AudioDirector.play_sfx` emits a `[combat-trace] AudioDirector.play_sfx | cue_id=<id>` console line (HTML5 only via `OS.has_feature("web")`) whenever a SFX cue is dispatched.

**Trace shape:**
```
[combat-trace] AudioDirector.play_sfx | cue_id=sfx-player-dodge
```
The `cue_id` must match the `AD-XX` entry in `team/uma-ux/audio-direction.md` exactly — derive it from the constant, never guess.

**Validated probe pattern (PR #281 — dodge-signal split, AD-05 verification):**

- Scenario A (positive — intentional dodge): Space press → assert exactly 1 `sfx-player-dodge` cue line within the probe window.
- Scenario B (negative — passive damage 20s window): assert N `Player.take_damage` lines AND **0** `sfx-player-dodge` lines. The high event-count + zero target-cue confirmation is load-bearing: it proves the signal was suppressed, not just absent due to a missed trigger.

```typescript
const traceLogs: string[] = [];
page.on("console", msg => {
  if (msg.text().includes("[combat-trace] AudioDirector.play_sfx")) {
    traceLogs.push(msg.text());
  }
});

// Positive — cue fires on trigger
await page.keyboard.press("Space");
const positive = traceLogs.filter(l => l.includes("cue_id=sfx-player-dodge"));
expect(positive).toHaveLength(1);

// Negative — cue does NOT fire on passive damage (must use ≥15s window; see test-conventions.md)
const beforeDamage = traceLogs.length;
await page.waitForTimeout(20_000);
const negative = traceLogs.slice(beforeDamage).filter(l => l.includes("cue_id=sfx-player-dodge"));
expect(negative).toHaveLength(0);
```

**Coupling note.** The trace fires inside `AudioDirector.play_sfx()`, NOT at individual `AudioStreamPlayer.play()` call sites. If a future refactor bypasses `play_sfx` and calls `.play()` directly, the trace goes silent — the Playwright spec passes vacuously. Any SFX-routing refactor must audit whether the call still goes through `play_sfx`.

**HTML5-only limitation.** Same gate as all `[combat-trace]` lines (`OS.has_feature("web") == true`). The trace is a no-op in headless GUT — Playwright HTML5 specs are the **only** automated coverage for SFX-trigger correctness. Audible confirmation in the Self-Test Report (per the HTML5 audio-playback gate above) is still required; the trace probe is the machine-checkable counterpart, not a replacement.

## Cross-references

- Content side (cue list, mood direction, sourcing plan, tester checklist):
  [`team/uma-ux/audio-direction.md`](../../team/uma-ux/audio-direction.md)
- Boss-music decision (unique, not cross-stratum-reuse):
  [`team/DECISIONS.md`](../../team/DECISIONS.md) 2026-05-15 entry
- HTML5 export quirks + service-worker cache trap:
  [`html5-export.md`](html5-export.md)
- Placeholder synthesis disclosure (M2 ships placeholders, M3 promotion plan):
  `team/uma-ux/audio-direction.md` §6
