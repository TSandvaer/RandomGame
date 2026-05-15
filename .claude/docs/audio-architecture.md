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

## Cross-references

- Content side (cue list, mood direction, sourcing plan, tester checklist):
  [`team/uma-ux/audio-direction.md`](../../team/uma-ux/audio-direction.md)
- Boss-music decision (unique, not cross-stratum-reuse):
  [`team/DECISIONS.md`](../../team/DECISIONS.md) 2026-05-15 entry
- HTML5 export quirks + service-worker cache trap:
  [`html5-export.md`](html5-export.md)
- Placeholder synthesis disclosure (M2 ships placeholders, M3 promotion plan):
  `team/uma-ux/audio-direction.md` §6
