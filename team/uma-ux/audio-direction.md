# Audio Direction & Cue List — Embergrave (M1 + M2 baseline)

**Owner:** Uma · **Phase:** M1 with M2 baseline · **Drives:** Devon's audio bus / `AudioStreamPlayer` wiring (week-3+), Drew's mob-event audio hooks, Tess's "did the cue fire at the right moment?" checklist, the eventual sourcing pass (procedural / freesound / AI / hand-Foley).

This is the single audio-direction call for Embergrave. It anchors against `visual-direction.md` (pixel-art at 96 px/tile, dark-fantasy ember-and-stone palette, single warm light source per scene) and against the audio maps already specified in `death-restart-flow.md` and `boss-intro.md`. Concrete enough that a tester can check whether a cue is in the right place; concrete enough that a sourcing pass knows what to hunt for.

## 1. Tonal direction

**Embergrave sounds like a stone room with one lit fire in it.** The musical aesthetic is **dark-folk chamber** — small ensemble, intimate, hand-played, with a deliberate sparseness that lets silence breathe. Picture two cellos, a low Nordic frame drum, an upright piano with felt on the hammers, a single struck bronze bell, a hurdy-gurdy drone for tension, and the occasional warm horn (think alphorn or low trombone) for climax beats. **No synths. No orchestral swell. No chiptune.** Reverb is a real-room reverb (small chapel, ~1.4 s tail), not a plate or a hall — every sound feels physical, like it's bouncing off the same stone walls the player is walking past.

Anchored against the pixel-art house style: the visual direction commits to *hand-painted-feel pixel art* (not retro-clean, not cel-shaded), with a single warm key light per scene and ember accents on a desaturated ground. The audio analogue is **acoustic, sparse, and warm-on-cold** — a cello drone is the audio cousin of a vignette; a struck bell is the audio cousin of an ember accent; the absence of drums in ambient passages is the audio cousin of restraint in tilesets. References that capture the right texture: **Dark Souls 1's main menu and Firelink Shrine ambient** (sparse strings + bell, single warm focal point), **Hellblade: Senua's Sacrifice's chant-and-drone passages** (intimate, claustrophobic, never grand), **Inside (Playdead)** for the discipline of *almost no music, then a single instrument when it matters*, and **The Witcher 3's Skellige folk ensemble** for the small-acoustic instrumentation logic. Anti-references: orchestral cinematic (Skyrim main theme), electronic (Hyper Light Drifter — visually adjacent but tonally wrong for Embergrave), chiptune (any), big-band action scoring (Hades — UI-clarity reference only, not music reference).

## 2. Cue list (M1 + M2 baseline)

Coverage: every audio cue M1+M2 needs. Priority column maps to sourcing order — `M1 must` cues block M1 RC; `M1 nice` cues ship if cheap, defer if not; `M2` cues are scoped now so the cue IDs and naming convention don't churn later.

### SFX — combat & player

| Cue ID                 | Type | Trigger (engine event)                                  | Mood / keyword         | Length    | Source plan                                                 | Priority   |
|------------------------|------|---------------------------------------------------------|------------------------|-----------|-------------------------------------------------------------|------------|
| `sfx-player-hit-light` | SFX  | Player takes damage, HP loss < 25% max                  | thud, leather, grunt   | 0.20 s    | freesound (leather impact + soft male grunt, layered)       | M1 must    |
| `sfx-player-hit-heavy` | SFX  | Player takes damage, HP loss >= 25% max                 | thud + bone, gasp      | 0.30 s    | freesound (bone-on-leather impact + sharp inhale)           | M1 must    |
| `sfx-player-die`       | SFX  | Player HP reaches 0 (death-flow Beat A)                 | wet final breath       | 0.40 s    | freesound (single exhale) + reverb tail                     | M1 must    |
| `sfx-player-dodge`     | SFX  | Dodge-roll i-frame window starts (frame 2 of 6)         | cloth whoosh           | 0.18 s    | freesound (cape/cloth swing) — keep it dry, no synth swoosh | M1 must    |
| `sfx-player-attack-light` | SFX | Light-attack swing animation starts (frame 1 of 4)    | short blade swing      | 0.15 s    | freesound (sword swing, short)                              | M1 must    |
| `sfx-player-attack-heavy` | SFX | Heavy-attack swing animation starts (frame 1 of 8)    | longer blade swing + grunt | 0.30 s | freesound (sword swing) + male effort grunt layered         | M1 must    |
| `sfx-player-hit-connect-light` | SFX | Light-attack hitbox overlaps mob hurtbox          | meaty thwack           | 0.20 s    | freesound (blade-on-flesh)                                  | M1 must    |
| `sfx-player-hit-connect-heavy` | SFX | Heavy-attack hitbox overlaps mob hurtbox + 60 ms hit-stop | wet crunch + bone   | 0.30 s    | freesound (blade-on-flesh, layered with bone-snap)          | M1 must    |
| `sfx-player-block`     | SFX  | (M2) shield/parry block lands                           | metal clang            | 0.20 s    | freesound (sword-on-shield)                                 | M2         |
| `sfx-footstep-stone`   | SFX  | Player walk anim foot-down frame on stone tileset       | leather on stone       | 0.15 s    | hand-Foley (4 variants, randomized to avoid loop fatigue)   | M1 must    |
| `sfx-footstep-dirt`    | SFX  | (M2) Player walk anim foot-down frame on dirt tileset   | leather on dirt        | 0.15 s    | hand-Foley (4 variants)                                     | M2         |

### SFX — mobs

| Cue ID                 | Type | Trigger (engine event)                                  | Mood / keyword         | Length    | Source plan                                                 | Priority   |
|------------------------|------|---------------------------------------------------------|------------------------|-----------|-------------------------------------------------------------|------------|
| `sfx-grunt-aggro`      | SFX  | Grunt mob enters `aggro` state (Drew's state machine)   | guttural snarl         | 0.40 s    | freesound (zombie/orc growl, short) + pitch-shift           | M1 must    |
| `sfx-grunt-attack`     | SFX  | Grunt swing telegraph completes, swing fires            | grunt + swing          | 0.35 s    | freesound (orc effort grunt) + cloth/weapon swing layered   | M1 must    |
| `sfx-grunt-hit`        | SFX  | Grunt takes damage (any source)                         | pained yelp            | 0.25 s    | freesound (creature yelp)                                   | M1 must    |
| `sfx-grunt-die`        | SFX  | Grunt HP reaches 0 → `mob_died` signal fires            | death gurgle + collapse| 0.50 s    | freesound (creature death, layered with thud)               | M1 must    |
| `sfx-shooter-attack`   | SFX  | (M2) Shooter mob fires projectile                       | bow twang or hiss      | 0.25 s    | freesound                                                   | M2         |
| `sfx-shooter-die`      | SFX  | (M2) Shooter HP=0                                       | (variant of grunt-die) | 0.50 s    | freesound (different creature voice from grunt)             | M2         |
| `sfx-charger-windup`   | SFX  | (M2) Charger telegraph dash start                       | scrape + breath        | 0.40 s    | freesound (hoof-scrape + bestial inhale)                    | M2         |
| `sfx-charger-impact`   | SFX  | (M2) Charger collides with player or wall               | heavy body slam        | 0.40 s    | freesound (body slam)                                       | M2         |
| `sfx-charger-die`      | SFX  | (M2) Charger HP=0                                       | bestial bellow + thud  | 0.60 s    | freesound (large-creature death)                            | M2         |
| `sfx-boss-aggro`       | SFX  | (boss-intro Beat 3) Boss wake animation fires           | low brass + impact stinger | 0.60 s| freesound (brass note) + hand-layered stone-impact          | M1 must    |
| `sfx-boss-phase-break` | SFX  | Boss HP crosses 66% / 33% threshold                     | tritone tension chord  | 0.40 s    | hand-composed (cello + double-stop) — only acoustic source  | M1 must    |
| `sfx-boss-hit`         | SFX  | Boss takes damage                                       | deep impact + reverb   | 0.30 s    | freesound (large-creature hit), reverb-heavier than grunt   | M1 must    |
| `sfx-boss-die`         | SFX  | Boss HP=0, phase-3 (boss-defeated Beat F1)              | combat audio CUT + bell| (silence + 1.5 s bell tail) | reuse `sfx-bell-struck`; the silence IS the cue | M1 must |
| `sfx-boss-kill-horn`   | SFX  | Boss-defeated Beat F2 (T+0.3 → T+1.2)                   | sustained warm horn    | 0.90 s    | hand-composed (alphorn or low trombone sample)              | M1 must    |

### SFX — items, world, UI

| Cue ID                 | Type | Trigger (engine event)                                  | Mood / keyword         | Length    | Source plan                                                 | Priority   |
|------------------------|------|---------------------------------------------------------|------------------------|-----------|-------------------------------------------------------------|------------|
| `sfx-item-drop`        | SFX  | LootRoller spawns Pickup at mob death position          | metal-leather thud     | 0.30 s    | freesound (item drop) — pitch-varied per tier               | M1 must    |
| `sfx-item-pickup`      | SFX  | Player overlaps Pickup → ItemInstance enters inventory  | warm chime, single bell-tone | 0.40 s | hand-composed (bell tone, tier-pitched: T1 low, T2 mid, T3 bright) | M1 must |
| `sfx-item-equip`       | SFX  | Player equips item from inventory panel                 | leather strap + click  | 0.30 s    | freesound (leather + buckle)                                | M1 nice    |
| `sfx-item-tier-T2`     | SFX  | (layer) Pickup spawned with tier=2                      | extra bell harmonic    | 0.40 s    | hand-composed; layered over `sfx-item-pickup`               | M1 nice    |
| `sfx-item-tier-T3`     | SFX  | (layer) Pickup spawned with tier=3                      | bright two-bell chime  | 0.50 s    | hand-composed; layered over `sfx-item-pickup`               | M1 nice    |
| `sfx-bell-struck`      | SFX  | Splash screen / death Beat C / boss intro Beat 4 / boss kill Beat F1 | single bronze bell | 1.50 s with tail | hand-Foley (single bell strike, recorded once and reused EVERYWHERE) | M1 must |
| `sfx-door-open`        | SFX  | Player opens unlocked door (or boss-defeated unlock)    | wood + iron creak + chime | 0.50 s | freesound (door creak) + hand-composed soft chime layered (matches boss-defeated `door_unlock_chime.ogg`) | M1 must |
| `sfx-door-slam-heavy`  | SFX  | Boss-room threshold crossed (boss-intro Beat 1)         | iron-on-stone thud     | 0.50 s    | freesound (dungeon door slam) — heavy, low-frequency        | M1 must    |
| `sfx-level-up`         | SFX  | Player XP threshold crosses level boundary              | rising bell triad + warm horn flourish | 1.20 s | hand-composed (3 bells ascending + horn note)         | M1 must    |
| `sfx-stat-allocate`    | SFX  | Player spends a stat point in stats panel               | soft click + chime     | 0.20 s    | hand-Foley (UI click) + tone layer                          | M1 nice    |
| `sfx-ui-click`         | SFX  | Any menu button or list item click                      | soft wood-on-wood click| 0.10 s    | hand-Foley (small wooden tap, recorded once)                | M1 must    |
| `sfx-ui-hover`         | SFX  | Mouse hovers a focusable UI element                     | very soft tick         | 0.05 s    | hand-Foley (fingernail tap, very quiet)                     | M1 nice    |
| `sfx-ui-tab-open`      | SFX  | Inventory / stats panel opens                           | parchment unfurl       | 0.30 s    | freesound (paper rustle)                                    | M1 nice    |
| `sfx-ui-tab-close`     | SFX  | Inventory / stats panel closes                          | parchment fold         | 0.20 s    | freesound (paper fold)                                      | M1 nice    |
| `sfx-tick-soft`        | SFX  | Run-summary number-tick animation, 60 ms cadence        | soft click             | 0.04 s    | hand-Foley (very quiet click, near-silent)                  | M1 must    |
| `sfx-save-success`     | SFX  | `Save.save_game()` completes successfully (auto-save or manual) | quiet bell tap   | 0.30 s    | hand-composed (single muted bell-tone, deliberately quieter than item-pickup so it never pulls focus) | M1 must |
| `sfx-save-fail`        | SFX  | `Save.save_game()` raises an exception                  | dull thud, low         | 0.30 s    | freesound (low thud, no music)                              | M1 nice    |
| `sfx-ember-rise`       | SFX  | Death Beat F (descend-again confirm) / level-up flourish | upward whoosh, warm   | 0.80 s    | hand-composed (filtered noise sweep + bell tail)            | M1 must    |
| `sfx-summary-pad`      | SFX  | Death Beat D → E (transition to summary screen)         | sustained warm pad     | 0.40 s in, sustained loop until dismissed | hand-composed (cello drone, simple)         | M1 must    |
| `sfx-string-low-death` | SFX  | Death Beat B (embers gather, sustained string fade-in)  | low cello drone        | 0.80 s ramp + sustain | hand-composed (single cello, low register)              | M1 must    |

### Music

| Cue ID                 | Type  | Trigger (engine event)                                 | Mood / keyword         | Length / loop spec     | Source plan                                              | Priority   |
|------------------------|-------|--------------------------------------------------------|------------------------|------------------------|----------------------------------------------------------|------------|
| `mus-title`            | Music | Title screen visible                                   | sparse, mournful, hopeful | ~60 s loop          | hand-composed or curated (cello + piano + bell)          | M1 must    |
| `mus-stratum1-bgm`     | Music | Player in stratum-1 non-boss rooms (looped)            | tense, low, wandering  | ~90–120 s loop, no hard stop | hand-composed (cello drone + frame drum heartbeat + sparse piano) | M1 must |
| `mus-boss-stratum1`    | Music | Boss-intro Beat 5 onward, until boss defeated          | driving, frame drum + cello + brass swells | ~60 s loop | hand-composed (single track for all 3 phases in M1 — phase-aware layering is M2+) | M1 must |
| `mus-boss-stratum1-ph1`| Music | (M2) Boss phase 1 stem (drum + cello)                  | tense                  | ~60 s loop, layer-A   | hand-composed (stem of mus-boss-stratum1)                | M2         |
| `mus-boss-stratum1-ph2`| Music | (M2) Boss phase 2 stem (adds piano + horn)             | escalating             | ~60 s loop, layer-B   | hand-composed (stem of mus-boss-stratum1)                | M2         |
| `mus-boss-stratum1-ph3`| Music | (M2) Boss phase 3 stem (full ensemble + bell)          | climactic              | ~60 s loop, layer-C   | hand-composed (stem of mus-boss-stratum1)                | M2         |
| `mus-stratum2-bgm`     | Music | (M2) Player in stratum-2 (Sunken Library)              | quiet, eerie, teal-bronze | ~120 s loop          | hand-composed                                            | M2         |
| `mus-victory-pad`      | Music | Boss-defeated Beat F4 → stratum-clear ambient resume   | quiet relief, simple cello chord | 4 s sustained, no loop | hand-composed                                  | M1 must    |

### Ambient

| Cue ID                 | Type    | Trigger (engine event)                               | Mood / keyword         | Length / loop spec     | Source plan                                              | Priority   |
|------------------------|---------|------------------------------------------------------|------------------------|------------------------|----------------------------------------------------------|------------|
| `amb-stratum1-room`    | Ambient | Player in any stratum-1 room (always-on, layered under BGM) | stone-room tone, distant drip, faint wind | 60 s loop (min per visual-direction.md) | freesound (cave/dungeon ambient) + hand-mix | M1 must |
| `amb-stratum1-torch`   | Ambient | Player within 4 tiles of a wall-torch (positional)   | soft flame crackle     | 30 s loop, positional, low gain | freesound (torch crackle) — looped seamlessly         | M1 must    |
| `amb-boss-room-pre`    | Ambient | Player in boss room before boss-aggro fires          | quieter, deeper room tone | 30 s loop, replaces amb-stratum1-room | hand-mix (filtered version of amb-stratum1-room) | M1 must |
| `amb-stratum2-room`    | Ambient | (M2) Player in stratum-2 rooms                       | water drip + parchment rustle | 60 s loop          | freesound + hand-mix                                     | M2         |
| `amb-wind-distant`     | Ambient | (M2) Special chunks with "outside" feel              | distant wind, faint    | 60 s loop, low gain   | freesound                                                | M2         |

**Coverage check vs. task spec:**
- Enemy hit/death — `sfx-grunt-hit`, `sfx-grunt-die` (M1); `sfx-shooter-*`, `sfx-charger-*` (M2); `sfx-boss-hit`, `sfx-boss-die` (M1).
- Player hit/death — `sfx-player-hit-light/heavy`, `sfx-player-die`.
- Level-up — `sfx-level-up` (M1) + reused `sfx-ember-rise` flourish.
- Item-pickup — `sfx-item-pickup` (M1) + tier layers `sfx-item-tier-T2/T3` (M1 nice).
- Door-open — `sfx-door-open` (M1) + `sfx-door-slam-heavy` for boss room.
- Footsteps — `sfx-footstep-stone` (M1) + `sfx-footstep-dirt` (M2).
- Dodge whoosh — `sfx-player-dodge`.
- Ambient stratum-1 loop — `amb-stratum1-room` + `amb-stratum1-torch`.
- Stratum-1 BGM — `mus-stratum1-bgm`.
- Boss intro sting — `sfx-boss-aggro` (Beat 3) + reused `sfx-bell-struck` (Beat 4).
- Boss music (3 phases) — `mus-boss-stratum1` (M1, single loop covers all phases) + `mus-boss-stratum1-ph1/2/3` stems (M2 layer-aware).
- UI clicks — `sfx-ui-click` (M1 must) + `sfx-ui-hover/tab-open/tab-close/stat-allocate` (M1 nice).
- Save success — `sfx-save-success` (M1) + `sfx-save-fail` (M1 nice).

## 3. Mixing & ducking rules

**Bus structure** (Devon's call on the Godot AudioServer wiring; this is the spec):

- `Master` — final output. Reference level: peak -1 dBFS, target loudness -16 LUFS for HTML5 (browser playback gets compressed; we leave headroom).
- `BGM` bus — all `mus-*` cues. Default: -12 dB relative to Master.
- `Ambient` bus — all `amb-*` cues. Default: -18 dB relative to Master (always-on bed; never the focus).
- `SFX` bus — all `sfx-*` cues except UI. Default: -6 dB relative to Master (player actions are loudest, this is correct).
- `UI` bus — UI clicks / hover / tab open-close / save success / number-ticks. Default: -10 dB relative to Master. Sits below SFX so a fight playing under an open inventory panel still reads.
- `Voice` bus — reserved for M2+. Default: -4 dB. (Voice will be the loudest layer when it ships; ducking targets it as primary trigger.)

**Ducking rules** (sidechain logic — Godot supports this via `AudioEffectCompressor` with `sidechain` set):

1. **`SFX` ducks `BGM` by -6 dB** when an SFX with priority `M1 must` plays. Attack 50 ms, release 400 ms. Result: gunshots, hits, dodges punch through the music without the music feeling absent. Threshold: SFX bus peak > -18 dBFS.
2. **`SFX` ducks `Ambient` by -3 dB** under the same trigger — ambient bed quietens during action so SFX reads cleanly.
3. **Death sequence (Beat A): `BGM` hard-mutes** to 0% over 200 ms (per `death-restart-flow.md`). Ambient drops to 30%. Resume at Beat F (descend-again confirm).
4. **Boss intro (Beat 2): `BGM` (stratum-1) hard-mutes** to 0% over 600 ms. `mus-boss-stratum1` fades in over 600 ms starting at Beat 5. No overlap.
5. **Boss-defeated (Beat F1): all combat SFX cuts hard, boss music cuts hard.** Only `sfx-bell-struck` and (Beat F2) `sfx-boss-kill-horn` play. Stratum-1 ambient resumes at Beat F4 at 60% gain.
6. **Inventory panel open (player Tab): `BGM` ducks by -3 dB, `Ambient` ducks by -3 dB, `SFX` continues at full** (combat keeps firing under the panel since the panel doesn't pause time fully). Restore on close, 200 ms ramp.
7. **Voice (M2+) ducks BGM by -9 dB and Ambient by -6 dB.** Voice is the most precious layer; everything else gets out of its way.

**No ducking** during normal exploration — BGM, ambient, and footsteps coexist naturally because the BGM is sparse by design (cello drone + frame drum heartbeat — there's space for a footstep to land in between hits).

## 4. Source-of-truth flow

**Folder layout** (under repo root):

```
audio/
  sfx/
    player/        # sfx-player-*.ogg
    mobs/          # sfx-grunt-*.ogg, sfx-shooter-*.ogg, sfx-charger-*.ogg, sfx-boss-*.ogg
    items/         # sfx-item-*.ogg, sfx-bell-struck.ogg
    world/         # sfx-door-*.ogg, sfx-footstep-*.ogg
    ui/            # sfx-ui-*.ogg, sfx-tick-soft.ogg, sfx-save-*.ogg, sfx-stat-allocate.ogg
    flow/          # sfx-ember-rise.ogg, sfx-summary-pad.ogg, sfx-string-low-death.ogg, sfx-level-up.ogg
  music/
    title/         # mus-title.ogg
    stratum1/      # mus-stratum1-bgm.ogg, mus-boss-stratum1.ogg, mus-boss-stratum1-ph1/2/3.ogg
    stratum2/      # M2: mus-stratum2-bgm.ogg
    common/        # mus-victory-pad.ogg
  ambient/
    stratum1/      # amb-stratum1-room.ogg, amb-stratum1-torch.ogg, amb-boss-room-pre.ogg
    stratum2/      # M2
    common/        # amb-wind-distant.ogg
  _src/            # OPTIONAL — high-fidelity source files (WAV/FLAC/Reaper projects). gitignored if any single file > 10 MB per GIT_PROTOCOL.md.
```

**Format:** **OGG Vorbis** for all shipped audio. Quality setting: q5 (~160 kbps VBR) for SFX, q7 (~224 kbps VBR) for music and ambient. OGG is Godot 4.3's native format with lowest runtime cost and works in HTML5 builds.

**Sample rate:** 44.1 kHz mono for SFX (saves space; spatial positioning in Godot uses bus pan, not stereo source). 44.1 kHz stereo for music and ambient.

**Naming convention:** `<bus>-<role>-<descriptor>[-<variant>].ogg`, all lowercase, kebab-case, matching the cue ID column above. Examples: `sfx-grunt-die.ogg`, `sfx-footstep-stone-01.ogg` through `-04.ogg` for the 4 randomized variants, `mus-stratum1-bgm.ogg`, `amb-stratum1-torch.ogg`. Cue ID == filename stem; Godot resource path is `res://audio/<type>/<scope>/<cue-id>.ogg`. Devon's audio-loader can build a single dictionary `cue_id → AudioStream` keyed off the filenames — no per-cue authoring in the scene tree.

**Source-of-truth discipline** (matching the resolution+format discipline from `visual-direction.md`):

- Ship-format (OGG) lives under `audio/<type>/<scope>/`. Committed to git.
- Hi-fi source (WAV/FLAC) lives under `audio/_src/` only if needed; **only commit if < 10 MB**. Anything heavier stays out of the repo (link in a `team/uma-ux/audio-sources.md` registry instead — to be added on first source-pass dispatch).
- AI-generated WIPs are not committed — same rule as visual-direction. Only curated finals.
- Hand-Foley raw recordings are not committed unless they're the actual ship asset.
- One cue, one file. No multi-cue stems unless explicitly the M2 phase-music layered approach (where the stems ARE the cues).

**Versioning:** if a cue gets re-recorded, the file replaces in place. We do not ship `sfx-grunt-die-v2.ogg` — the cue ID is permanent, the file underneath can change. Tess regression: the audio-cue-fires test is by event firing, not by content matching.

## 5. Tester checklist (yes/no)

| ID    | Check                                                                                                | Pass criterion (yes/no) |
|-------|------------------------------------------------------------------------------------------------------|-------------------------|
| AD-01 | Stratum-1 BGM (`mus-stratum1-bgm`) plays on entering any stratum-1 room and loops without a click   | yes                     |
| AD-02 | Stratum-1 ambient (`amb-stratum1-room`) plays under the BGM, audibly quieter (~6 dB lower)           | yes                     |
| AD-03 | Wall-torch ambient (`amb-stratum1-torch`) is louder when player is within 4 tiles of a torch sprite | yes                     |
| AD-04 | `sfx-footstep-stone` fires once per foot-down anim frame; uses 4 randomized variants (no obvious loop) | yes                   |
| AD-05 | `sfx-player-dodge` fires when dodge-roll i-frame window starts (frame 2 of 6, ~33 ms in)            | yes                     |
| AD-06 | `sfx-player-attack-light` fires on swing frame 1 of 4 — not before, not after                       | yes                     |
| AD-07 | `sfx-player-hit-connect-heavy` plays simultaneous with the 60 ms hit-stop on heavy-attack contact    | yes                     |
| AD-08 | `sfx-grunt-aggro` fires the moment Grunt enters aggro state (state-machine transition, NOT on spawn) | yes                     |
| AD-09 | `sfx-grunt-die` fires exactly once per grunt death; rapid-hit spam does NOT produce a second fire   | yes                     |
| AD-10 | `sfx-player-hit-light` vs. `sfx-player-hit-heavy` correctly switches at the 25%-of-max threshold    | yes                     |
| AD-11 | BGM ducks by ~6 dB when an SFX-bus M1-must cue plays; restores within 400 ms of cue end             | yes                     |
| AD-12 | On player death (Beat A), BGM mutes within 200 ms and ambient drops to ~30%                         | yes                     |
| AD-13 | Death Beat C: `sfx-bell-struck` plays at T+1.2 s exactly                                            | yes                     |
| AD-14 | Death Beat F (Descend Again confirm): `sfx-ember-rise` plays before fade-up to S1 R1                | yes                     |
| AD-15 | Run-summary number-ticks: `sfx-tick-soft` plays at 60 ms cadence, halts instantly on any key press  | yes                     |
| AD-16 | Boss-intro Beat 1: `sfx-door-slam-heavy` plays simultaneously with the door visual closing          | yes                     |
| AD-17 | Boss-intro Beat 2: stratum-1 BGM fades to 0% over 600 ms                                            | yes                     |
| AD-18 | Boss-intro Beat 3: `sfx-boss-aggro` plays during the boss wake animation                            | yes                     |
| AD-19 | Boss-intro Beat 4: `sfx-bell-struck` plays at T+1.4 s (single strike, not a peal)                   | yes                     |
| AD-20 | Boss-intro Beat 5: `mus-boss-stratum1` fades in over 600 ms                                         | yes                     |
| AD-21 | Phase break (boss HP 66% / 33%): `sfx-boss-phase-break` plays once per crossing                     | yes                     |
| AD-22 | Boss-defeated Beat F1: combat SFX + boss music cut hard; `sfx-bell-struck` plays at T+0.1 s         | yes                     |
| AD-23 | Boss-defeated Beat F2: `sfx-boss-kill-horn` plays for ~0.9 s ending as embers exit screen           | yes                     |
| AD-24 | Boss-defeated Beat F4: stratum-1 ambient resumes at ~60% gain (quieter than pre-fight)              | yes                     |
| AD-25 | `sfx-item-drop` plays when LootRoller spawns a Pickup; pitch varies subtly per tier                  | yes                     |
| AD-26 | `sfx-item-pickup` plays once per pickup; tier-T2/T3 layers add an extra harmonic if those layers ship | yes                   |
| AD-27 | `sfx-door-open` plays when the player opens an unlocked door (not the boss-room door)                | yes                     |
| AD-28 | `sfx-level-up` plays the moment XP threshold is crossed; layered `sfx-ember-rise` flourish audible  | yes                     |
| AD-29 | `sfx-ui-click` plays on every menu button click; `sfx-ui-hover` on focus change (if shipped)        | yes                     |
| AD-30 | `sfx-ui-tab-open` plays on inventory panel open; BGM and ambient duck by ~3 dB while panel is open  | yes                     |
| AD-31 | `sfx-save-success` plays after every successful save (auto and manual); quieter than item-pickup    | yes                     |
| AD-32 | All shipped audio files are OGG Vorbis at the spec'd quality (q5 SFX / q7 music+ambient)            | yes                     |
| AD-33 | All audio files live under `audio/<type>/<scope>/` matching the source-of-truth folder layout       | yes                     |
| AD-34 | All filenames match the cue ID (kebab-case, `<bus>-<role>-<descriptor>.ogg`)                        | yes                     |
| AD-35 | No audio file in the repo exceeds 10 MB                                                             | yes                     |
| AD-36 | Master output measured at -16 LUFS ±2 LU during a typical stratum-1 combat encounter                | yes                     |
| AD-37 | Master output peak never exceeds -1 dBFS (no clipping in HTML5 export)                              | yes                     |

## Cross-role decisions to log in DECISIONS.md

When this doc commits, the following cross-role calls move into `team/DECISIONS.md` (Uma to append on next dispatch — same mechanism as the visual-direction decision):

1. **Audio aesthetic lock**: dark-folk chamber (acoustic, sparse, small-ensemble; no synths, no orchestral, no chiptune). Constrains all music sourcing decisions through M2 and the eventual M3 scoring contract.
2. **Audio bus + ducking spec**: 5-bus structure (Master / BGM / Ambient / SFX / UI; Voice reserved for M2). Sidechain ducking on SFX→BGM (-6 dB) and SFX→Ambient (-3 dB). Constrains Devon's `AudioServer` setup when the audio-engine ticket lands.
3. **OGG Vorbis as the sole shipped format**, q5 SFX / q7 music+ambient, 44.1 kHz mono SFX / 44.1 kHz stereo music+ambient. Constrains every sourcing pass and Drew's any-mob-audio commit.
4. **Cue-ID == filename** discipline (kebab-case, bus-prefix, `<bus>-<role>-<descriptor>[-variant].ogg`). Constrains Devon's audio-loader implementation: a flat `cue_id → AudioStream` dictionary, no per-scene authoring.

## Open questions (for Priya / orchestrator)

- **Sourcing pass dispatch shape**: do we hand the `M1 must` cue list to a single dispatched run that hunts freesound + records hand-Foley + ships placeholders, or split it into 3 parallel dispatches by source type (freesound / hand-Foley / hand-composed)? Uma's lean: **single dispatch** — it's faster to keep one ear on the whole soundscape than to integrate three sourcing passes after the fact. Awaiting Priya's call.
- **M3 scoring contract**: the M1 placeholder track for `mus-stratum1-bgm` ships as a hand-composed ~90 s loop. M3 promotes this to a real composer's pass. We should not commission the M3 pass before M1 RC has been played by the Sponsor — the music conversation is too dependent on how the game actually feels. Defer.
- **Voice acting (M2+)**: not in scope for M1 or for this doc's M2 baseline beyond the bus reservation. If M2 adds NPC dialogue, the voice tonal direction is a follow-up doc.
