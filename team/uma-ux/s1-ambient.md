# Stratum-1 Ambient Direction Brief (M3 Tier 2 — T10)

**Owner:** Uma · **Phase:** M3 Tier 2 Wave 2 — direction-only · **Drives:** Devon's T10 implementation (composer source + `AudioDirector` API surface + transition wiring) and Tess's validation against AD-02 / AD-17 / AD-24 / new T10 checks.

This doc is the tonal direction for the **Stratum-1 ambient stream** that lands as foundation for Uma BI-03 (ambient cuts to 0% on boss-room entry) and Uma F4 (ambient resumes at 60% post-defeat). Cue ID is already locked in [`audio-direction.md`](audio-direction.md) row 95: **`amb-stratum1-room`**. This brief specifies the texture, dB target, fade shapes, and sourcing strategy that turn that locked row into a shippable cue.

The companion runtime/integration doc is [`.claude/docs/audio-architecture.md`](../../.claude/docs/audio-architecture.md) (5-bus layout, `AudioDirector` autoload). The 5-bus structure + Ambient bus -18 dB target are the constraints the texture is mixed against.

## Tonal anchor (lead with this)

> **Stratum 1 reads as "a stone cloister settled into silence — the monks are gone but the room hasn't noticed yet."**

The S2 ambient texture (Cinder Vaults — steam-hiss bed + sub-bass vein-pulse hum + scree-rustle ticks) is built around *active pressure*: the place is venting heat, the rock is still under load, the world is mechanically alive. **S1 ambient is the inverse.** The cloister is *post-active* — the rituals stopped, the candles went out, but the architecture is still here holding its breath. The ambient should sound like the **absence of activity in a place that used to have it**, not like a deep-tunnel system that's actively working.

**Distinct stratum identity, NOT tone-match S2.** S2's audio-direction §1 cousin to its sub-pressure visual (slow frame-drum heartbeat + steam-hiss + bronze bell as struck-iron-strut) is a different *kind* of room. S1's audio cousin is sparser: it's the cloister's *natural reverb tail* with the smallest possible amount of content suspended in it. The S1 bed should make a player's footstep feel **important** — every footstep is the loudest event in the room until combat starts.

This anchor also lets the S1→S2 transition (descend portal) carry tonal weight: silence-with-stone gives way to pressure-with-rust. If S1 ambient mimicked S2's pressure texture, the descent loses its narrative beat.

## Reference texture (what the cue contains)

Sit in the dark-folk-chamber discipline from [`audio-direction.md §1`](audio-direction.md) (no synths, no orchestral, no chiptune; small acoustic, real-room reverb). The S1 bed is the **most-restrained** stratum-ambient in the project — by design, since stratum-1 is the player's introduction to the world's audio language.

**Layered content (in mix-order from quietest to most-present):**

1. **Room tone — soft stone reverb tail.** A 1.4 s real-stone reverb (small chapel, not a hall or plate) holding an inaudible sustain. Functionally: the room "sounds large" without any source. Implementation: thin filtered-pink-noise bed reverbed heavily, peak ~ -42 dBFS pre-bus.
2. **Distant drip — irregular, sparse.** Single water-drop ticks at irregular intervals (~12–25 s apart, jittered, never on a beat). Reads as "deep stone has groundwater somewhere." Drops are physically close (no reverb wash on the drops themselves — dry-close) which contrasts the room-tone reverb tail and reads as "drip is *here*; the room is *vast*." Peak ~ -32 dBFS pre-bus.
3. **Faint wind through arches — sub-audible.** Filtered wind-through-stone, sub-300 Hz bias, slow modulation (~ 0.05 Hz). Reads as "air is moving but you can't tell where from." This is the layer that prevents the bed from feeling *muted* — silence-with-air, not silence-with-vacuum. Peak ~ -38 dBFS pre-bus.

**Anti-content (do NOT include):**

- **No torch crackle in the room bed.** Torch crackle is the *positional* `amb-stratum1-torch` cue (already locked, [`audio-direction.md`](audio-direction.md) row 96), wired separately when the player is within 4 tiles of a wall-torch sprite. Layering crackle into `amb-stratum1-room` would make every room sound torch-lit even when there's no torch in view.
- **No frame-drum heartbeat.** That's S2's pressure-cousin; using it here breaks the stratum-identity contract.
- **No bronze-bell strikes in the ambient.** The bell is a *cue* (`sfx-bell-struck`) reserved for narrative moments (splash, death, boss intro, boss kill). Putting it into the ambient bed cheapens the strike.
- **No musical pitch content.** If a layer has a discernible pitch (a sustained cello drone, a singing-bowl hum, etc.), the bed becomes proto-BGM. The BGM (`mus-stratum1-bgm`) is the pitched layer; ambient is texture.

## Volume / loudness targets

Per [`audio-architecture.md`](../../.claude/docs/audio-architecture.md) the **Ambient bus sits at -18 dB** below Master. Within that:

- **`amb-stratum1-room` mix-bus peak:** -24 dBFS at file level (so -42 dBFS at Master after the -18 dB Ambient-bus attenuation).
- **Resume-after-defeat (F4) target:** 60% of nominal gain. Mapped to dB: ~-4.4 dB *additional* attenuation on the bed for the post-defeat resume, on top of the -18 dB bus. The 60% comes from [`boss-intro.md`](boss-intro.md) F4 — "stratum-1 ambient resumes at 60% volume (slightly quieter than pre-fight — the room feels emptier now, deliberately)." This is intentional: the post-defeat room *is* emptier; the audio mix follows the diegesis.
- **Cross-stratum-relative loudness:** S1 bed should sit ~3 dB *quieter* than S2's `amb-stratum2-room` will sit. The contrast helps sell descent-as-pressure-increase. (Compositional rule, not a hard tester pin.)

Composer should master to the -24 dBFS file peak; Devon's `AudioStreamPlayer.volume_db = 0.0` baseline + the Ambient bus -18 dB does the rest. The 60% resume is a `volume_db = -4.4` tween-target on the player, not a re-encode.

## Cross-fade shapes

### BI-03 — fade-out on boss-room entry

Per [`boss-intro.md`](boss-intro.md) Beat 2: "Stratum-1 ambient music fades to 0% over 0.6 s. Hard mute by T+0.6." Already locked numerically. This brief locks the **curve shape**:

- **Curve:** ease-out cubic (`Tween.EASE_OUT`, `Tween.TRANS_CUBIC`).
- **Duration:** 600 ms (matches the locked number; matches audio-direction §3 rule 4 boss-intro Beat 5 inverse).
- **Tonal rationale:** linear feels like a fader being pulled — mechanical. Ease-out cubic front-loads the attenuation so the bed *dives* quickly in the first 200 ms and tails into silence over the remaining 400 ms. Reads as "the room is closing around the player," which is the BI-03 + BI-04 vignette-deepening companion beat. The audio cousin to the vignette curve (eased) is an eased fade.
- **No cross-fade with `amb-boss-room-pre`.** The locked spec ([`audio-direction.md`](audio-direction.md) row 97) calls `amb-boss-room-pre` a *filtered version of `amb-stratum1-room`* that replaces it before boss-aggro fires. For T10 scope we **do not implement** the pre-boss bed — boss-entry transitions room→silence (then BGM takes over per BI-05). The `amb-boss-room-pre` cue is M2 baseline content, deferred until S1 boss room is ambient-pre-staged. T10 ships `play_stratum1_ambient()` + `stop_stratum1_ambient()` only; `amb-boss-room-pre` is a separate ticket.

### F4 — fade-in to 60% on `boss_defeated`

Per [`boss-intro.md`](boss-intro.md) Beat F4: "Boss music does not return; stratum-1 ambient resumes at 60% volume (slightly quieter than pre-fight — the room feels emptier now, deliberately)." Locks the timing window (T+2.4 s onward in the boss-defeated cinematic). This brief locks the curve + duration:

- **Curve:** ease-in-out quadratic (`Tween.EASE_IN_OUT`, `Tween.TRANS_QUAD`).
- **Duration:** 800 ms.
- **Target gain:** -4.4 dB on the `AmbientPlayer` (= 60% of nominal).
- **Tonal rationale:** the resume is *reflective* — the moment after the climax where the player breathes. A 600 ms fade-out (entry) is punchy; an 800 ms fade-in (resume) is gentler. The asymmetry (resume longer than entry) is intentional: entry is the room *closing* on the player; resume is the room *settling back* around them. Ease-in-out (vs ease-out for entry) gives the resume an *unhurried* shape — no sudden attack, no abrupt arrival at full gain.
- **Coordination with title card.** Per [`audio-architecture.md`](../../.claude/docs/audio-architecture.md) § "Tonal pattern — silence as punctuation": the boss-defeat title card holds in silence by design. The F4 ambient resume must start **after** the title-card hold completes (T+2.4 s per `boss-intro.md`), not under it. Devon's wiring: hook the resume to the `boss_defeated_card_dismissed` or equivalent end-of-card signal, not to the raw `boss_defeated` event. If a tighter signal isn't available, a `SceneTreeTimer(2.4, ignore_time_scale=true)` from `boss_defeated` is acceptable — `ignore_time_scale` because the boss-defeat freeze (T2/T11) may still be active when the timer should fire.

### Idempotence

`play_stratum1_ambient()` must follow the same idempotence pattern as `play_stratum2_ambient()` in [`audio-architecture.md`](../../.claude/docs/audio-architecture.md) § "Idempotence": no-op if the same stream is already playing on the AmbientPlayer at the requested gain. This matters for the **room-cycle case** — a player who walks back through the boss-defeated room re-enters S1 R1 normally; the ambient should already be playing at 60%, and the room-load callback should be a no-op, not a re-seed to position 0.

## Composer prompt / sourcing strategy

Per [`audio-sourcing-pipeline.md`](audio-sourcing-pipeline.md) row 217: `amb-stratum1-room` is routed to **freesound (cave/dungeon ambient) + DAW mix**, ~20 min cycle, M2-w1 priority. The M2-w1 path didn't ship (M2 closed with stratum-2 placeholders only); T10 is the resurrection of this cue under M3 Tier 2.

**Sourcing strategy (in order of preference):**

1. **Freesound CC0 query strategy.** Search keys: `"stone room ambient"`, `"cathedral interior"`, `"dungeon room quiet"`, `"crypt ambient"`. Filter by:
   - CC0 only (no attribution-required licenses; M3 license-audit clean).
   - Length ≥ 60 s OR loopable (we need a seamless 60–90 s loop).
   - No music content. No clear pitched notes. No identifiable speech.
   - **Reject** anything with heavy synth processing, mechanical-noise (HVAC, machinery), or organic-foliage (this is interior stone, not exterior).
   Curate 3 candidates, A/B them against the tonal anchor ("stone cloister settled into silence"), pick the one that *least* sounds like content.
2. **DAW mix on top of the freesound bed.** Add the three texture layers (room tone, distant drips, faint wind) at the relative-mix levels above. The drip layer is the most-likely needing hand-record or freesound-supplemental (single-drop samples, pitched-down, placed at irregular intervals).
3. **Fallback — placeholder synthesis** if Tier 2 dispatch hits the same constraints as W3-T9 (no DAW, no sample library). Use the same `audio/_src/composer/compose_*.py` pattern Devon's W3-T9 established for stratum-2. Three layers: filtered pink noise (room tone + reverb tail), sparse parametric synth drops at jittered intervals (distant drip), sub-300 Hz LFO-modulated wind (faint wind through arches). Disclose per [`audio-direction.md §6`](audio-direction.md) placeholder-synthesis-disclosure, flag with `<deferred-M3>` marker — promotion to freesound + DAW mix lands in M3 audio polish backlog.

**Format:** 44.1 kHz **stereo** OGG Vorbis at **q7** (matches the music + ambient quality lock from `audio-direction.md §4`). NOT q5 — q5 is SFX-only; ambient gets the higher-quality encoding because looping over a 60–90 s loop magnifies any compression artifact.

**File path:** `audio/ambient/stratum1/amb-stratum1-room.ogg`. Single file, no variants.

## AudioDirector API additions (Devon's T10 surface)

The implementation contract for Devon's T10. The shape mirrors the existing S2 API in [`audio-architecture.md`](../../.claude/docs/audio-architecture.md) § "Public API" so cross-stratum patterns stay consistent:

```gdscript
# Start S1 ambient bed. Fade in over fade_in_ms.
# Idempotent: no-op if amb-stratum1-room is already playing at requested gain.
AudioDirector.play_stratum1_ambient(fade_in_ms := 800, target_gain_db := 0.0)

# Stop S1 ambient with fade-out (used by BI-03 entry).
# Ease-out cubic curve on the fade.
AudioDirector.stop_stratum1_ambient(fade_out_ms := 600)

# Resume S1 ambient at 60% post-defeat (F4).
# Equivalent to play_stratum1_ambient(800, -4.4) with ease-in-out quad curve.
# Convenience wrapper so the F4 caller doesn't have to compute the dB math.
AudioDirector.resume_stratum1_ambient_at_60_percent(fade_in_ms := 800)
```

Devon's call on whether `resume_stratum1_ambient_at_60_percent` is a separate method or whether `play_stratum1_ambient()` takes a curve-style enum parameter. The brief locks the **two curves** (entry ease-out cubic; resume ease-in-out quadratic); the **method-shape** is Devon's implementation freedom.

### Trigger wiring

- **`play_stratum1_ambient()`** fires from any Stratum-1 room's `_ready()` after first-user-gesture (per the HTML5 audio-playback gate — but stratum-1 entry is normally post-DescendScreen-click, which IS a gesture, so safe). For the initial boot case where the player loads directly into S1 R1 with no prior gesture: the first player-input event (movement key / mouse click) is the gesture-forwarder. Devon's lane.
- **`stop_stratum1_ambient(600)`** fires from `Stratum1BossRoom.entry_sequence_started` signal handler (the same signal that fires the BGM crossfade per `audio-architecture.md` § "S1 boss-room — no-current-BGM case").
- **`resume_stratum1_ambient_at_60_percent(800)`** fires from `boss_defeated_card_dismissed` (or end-of-title-card signal); falls back to `SceneTreeTimer(2.4, ignore_time_scale=true)` from `boss_defeated` if a dismissal signal isn't surfaced.

### Idempotence + room-cycle case

A player who walks out of the boss room post-defeat and re-enters a non-boss S1 room must NOT trigger a fresh `play_stratum1_ambient()` re-seed. The room-load handler should call `play_stratum1_ambient(0, -4.4)` (zero fade, current 60% gain) which the idempotence guard catches as no-op. Or — cleaner — the room-load handler doesn't call the audio API at all if `_last_ambient_path == STREAM_PATH_S1_AMBIENT && _ambient_player.playing`. Devon's call on the exact guard placement.

## Tester checklist (yes/no)

| ID | Check | Pass criterion |
|---|---|---|
| T10-AMB-01 | `amb-stratum1-room.ogg` exists at `audio/ambient/stratum1/amb-stratum1-room.ogg` | yes |
| T10-AMB-02 | File is 44.1 kHz stereo OGG Vorbis at q7 quality | yes |
| T10-AMB-03 | File peak level is -24 dBFS ± 1 dB | yes |
| T10-AMB-04 | Ambient is audibly present on entering any S1 room (no longer silent-dungeon) | yes (Sponsor soak) |
| T10-AMB-05 | Ambient does NOT contain musical pitch content (sustained drones with discernible pitch) | yes |
| T10-AMB-06 | Ambient does NOT contain frame-drum heartbeat content (S2's pressure-cousin) | yes |
| T10-AMB-07 | On boss-room entry (`entry_sequence_started`), ambient fades to 0% over 600 ms with ease-out cubic curve | yes |
| T10-AMB-08 | On boss-defeated + title-card-dismissed (T+2.4 s post boss_defeated), ambient resumes at 60% over 800 ms with ease-in-out quad curve | yes |
| T10-AMB-09 | Idempotent across room-cycle: walking S1 R1 → S1 R2 → S1 R1 does NOT re-seed the ambient (no audible glitch / position jump) | yes |
| T10-AMB-10 | Idempotent across rapid call: two `play_stratum1_ambient()` calls within 100 ms produce one continuous bed, not two overlapping streams | yes |
| T10-AMB-11 | Resume gain at F4 is -4.4 dB on the AmbientPlayer (= 60% of nominal) | yes |
| T10-AMB-12 | Sub-Sponsor probe: room 1 → room 2 → room 1 cycle — does the ambient register as "I'm back in the cloister" (not "audio reset")? | yes (Sponsor soak) |
| T10-AMB-13 | HTML5 release-build Self-Test Report confirms audible playback (per `audio-architecture.md` HTML5 audio-playback gate) | yes |

T10-AMB-04 and T10-AMB-12 are subjective Sponsor-probe items. The composer's deliverable is the file; the integration's deliverable is the API + wiring + tests; the *feel* deliverable is Sponsor's soak verdict.

## How to validate the direction

A reviewer (Devon implementing or Tess validating) should:

1. **Listen test.** Play the candidate `amb-stratum1-room.ogg` in isolation for 60 seconds. Ask: does this sound like "a stone cloister settled into silence" or does it sound like "active mechanical pressure"? If active-mechanical, reject — wrong stratum identity.
2. **A/B against S2 stratum identity.** Play `amb-stratum2-room.ogg` (existing) → S1 candidate. The S1 candidate should be **noticeably sparser, quieter, and less pulsed** than S2. If S1 sounds like S2-with-different-content, reject — texture-discipline failed.
3. **Cross-fade test.** Trigger `stop_stratum1_ambient(600)` in-game and confirm the fade *shape* (front-loaded dive in first 200 ms, tail to silence over remaining 400 ms). A linear fade is rejection-eligible. The shape is the tonal beat.
4. **Resume-gain test.** Trigger F4 resume and confirm the 60% gain (visually verifiable on the AmbientPlayer.volume_db readout in editor; audibly verifiable in HTML5 soak as "quieter than pre-fight"). The post-defeat room should *feel* emptier than pre-fight.

## Cross-references

- [`audio-direction.md`](audio-direction.md) row 95 — `amb-stratum1-room` cue ID + initial direction (this brief refines + expands).
- [`audio-direction.md §3 rule 4`](audio-direction.md) — boss-intro ducking spec (BGM hard-mute on Beat 2; ambient analogous treatment).
- [`audio-direction.md §6`](audio-direction.md) — placeholder synthesis disclosure pattern (precedent for fallback if DAW sourcing unavailable).
- [`audio-sourcing-pipeline.md`](audio-sourcing-pipeline.md) row 217 — `amb-stratum1-room` sourcing route (freesound + DAW mix, M2-w1 priority — now resurrected under M3 T10).
- [`boss-intro.md`](boss-intro.md) Beat 2 (BI-03) — ambient fade-out trigger + 600 ms locked duration.
- [`boss-intro.md`](boss-intro.md) Beat F4 (BI-28) — ambient resume at 60% trigger + timing window.
- [`.claude/docs/audio-architecture.md`](../../.claude/docs/audio-architecture.md) — `AudioDirector` autoload API shape; S2 API as template for S1; HTML5 audio-playback gate; tonal pattern of silence-as-punctuation.
- [`palette-stratum-2.md §8 q6`](palette-stratum-2.md) — S2 BGM directional revisit (separate; not blocked by T10).

## Hand-off

- **Devon (T10 implementation):** §"Composer prompt / sourcing strategy" + §"AudioDirector API additions" + §"Tester checklist". Ship the source file under `audio/ambient/stratum1/` + the API methods + the trigger wiring + the paired GUT tests. HTML5 audio-playback gate Self-Test Report required.
- **Tess (T10 validation):** §"Tester checklist" (T10-AMB-01 through T10-AMB-13); §"How to validate the direction" for the subjective items.
- **Sponsor (soak):** T10-AMB-04 and T10-AMB-12 are the Sponsor-probe items. Listen for "I'm in the cloister" identity on first room entry; listen for "the room feels emptier" on post-defeat resume.

## Decision draft

(For Priya's weekly DECISIONS.md batch. Not for direct edit to `team/DECISIONS.md` per Uma role rules.)

- **Decision draft (2026-05-20):** **Stratum-1 ambient identity: distinct-from-S2, NOT cross-stratum-tone-match.** S1 bed reads as "stone cloister settled into silence" (sparse, post-active, real-room reverb tail with three quiet content layers); S2 bed reads as "active pressure" (steam-hiss + sub-bass vein-pulse + scree). Cross-stratum-reuse decision pattern (mirrors the boss-music UNIQUE decision logged 2026-05-15). Affects: T10 composer source, M3+ stratum identity policy. Reversibility: cue file is single-file replace per `audio-direction.md §4 versioning`; no engine code couples to the texture choice.

## Non-obvious findings

(For the maintain-docs Stop hook to consider for `.claude/docs/` capture.)

1. **Stratum ambient cross-stratum-distinct policy.** The S1 vs S2 ambient identity decision (distinct, not tone-match) is the same shape as the boss-music UNIQUE decision (DECISIONS.md 2026-05-15). Both decisions follow the rule: **stratum identity > cross-stratum economy** when the tonal contrast between strata is load-bearing for the descent narrative. **Capture timing:** after T10 ships and the cross-stratum A/B becomes audible-in-the-product, the pattern is worth capturing as a project-level audio-direction discipline (in `.claude/docs/audio-architecture.md` § "Tonal pattern — cross-stratum distinct ambient" or as a sibling to the silence-as-punctuation section). The maintain-docs Stop hook on T10's merge PR is the right capture moment.

2. **Fade-curve discipline as tonal beats.** Linear fades vs eased fades is not just an animation-feel detail; the curve *shape* is part of the tonal direction (this brief locks ease-out cubic for entry and ease-in-out quadratic for resume, with explicit rationale). **Capture timing:** if a second audio direction brief lands with the same curve-discipline pattern, the rule should land in `.claude/docs/audio-architecture.md`. Not yet doc-worthy from one brief.
