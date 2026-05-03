# Audio Sourcing Pipeline & First-Pass Cue Allocation (M2)

**Owner:** Uma · **Phase:** M2 prep (anticipatory; revisable post-Sponsor M1 sign-off) · **Drives:** Uma's M2 dispatch (T10 of `m2-week-1-backlog.md`), Devon's audio-loader / `AudioStreamPlayer` wiring once cues land, Tess's "did the cue fire" checklist (`audio-direction.md` §5 AD-01..AD-37), Priya's R10 mitigation (audio sourcing latency).

This doc turns `audio-direction.md`'s 60+ cue list into an **operational sourcing pipeline** — for every cue, which of five sourcing routes (procedural in-engine / hand-Foley / freesound / AI-curated / hand-composed) is right, what the per-route flow looks like, and which 8–12 cues are the M2-week-1 first-pass subset that lands alongside Devon's stash UI without blocking him. Aesthetic lock unchanged: dark-folk chamber (acoustic, sparse, small-ensemble; no synths for music; no orchestral; no chiptune). Format lock unchanged: OGG Vorbis q5 SFX / q7 music+ambient, 44.1 kHz mono SFX / 44.1 kHz stereo music+ambient, kebab-case `<bus>-<role>-<descriptor>.ogg`.

## TL;DR (5 lines)

1. **62 total cues** in `audio-direction.md`. Source-mix recommendation: **freesound 28 (45%)**, **hand-Foley 16 (26%)**, **hand-composed 14 (23%)**, **procedural in-engine 3 (5%)**, **AI-curated 1 (2%, music polish only)**. Each route has a per-cue cycle-time floor — freesound ~5 min, hand-Foley ~30 min, hand-composed 1–4 h.
2. **Priority split: P0 sourcing 28 cues** (all `M1 must` — Tess's M1 audio AC-coverage; placeholders ship if a cue's route stalls > 2 ticks), **P1 sourcing 22 cues** (all `M1 nice` + most `M2`), **P2 deferred 12 cues** (M3 polish: phase-music stems, M3 voice).
3. **M2-week-1 sourceable subset: 10 cues** chosen for low sourcing latency + zero gating on Devon/Drew (all freesound + 2 hand-Foley + 1 hand-composed re-use). Lands as one PR per cue or one omnibus PR — orchestrator's call. None of the 10 block T1/T3/T7 in `m2-week-1-backlog.md`.
4. **Operational flow** = `cue ID → route gate (decision tree §7) → source action → q5/q7 OGG re-encode → commit under audio/<type>/<scope>/<cue-id>.ogg → attribution append in audio-sources.md (if licensed) → Tess AD-row check`. Single Uma-owned dispatch per cue or batched per route.
5. **Top open questions:** (Q1) ship hand-composed loops in M2-w1 or fall back to freesound dark-folk pads as placeholders; (Q2) AI-curated route — is it on the table at all given dark-folk-acoustic aesthetic lock; (Q3) attribution doc — `audio-sources.md` registry shape and license-tracking discipline (CC0 vs CC-BY surface).

---

## Source of truth (what was read to author this)

Per `agent-verify-evidence.md` — every claim below derives from a direct read this session, not from priors:

1. **`team/uma-ux/audio-direction.md`** (234 lines) — 62 cue rows across SFX/Music/Ambient, source-plan column already populated with one-of {freesound, hand-Foley, hand-composed} per row. This doc is the canonical input; sourcing pipeline below honors every existing route call and only escalates when a row needs a finer route distinction (e.g., "freesound → AI-curated polish" or "hand-composed → hand-Foley fallback").
2. **`team/priya-pl/m2-week-1-backlog.md`** §T10 — `mus-stratum2-bgm` + `amb-stratum2-room` are P1 with explicit fallback to placeholder loops if hand-compose latency exceeds 1 tick. R10 (audio sourcing latency, low impact) is the named risk; placeholders are not a quality regression.
3. **`team/priya-pl/m2-week-1-backlog.md`** §R10 + §T10 risk note — confirms placeholder-fallback discipline is decision-locked.
4. **`team/priya-pl/backlog-expansion-2026-05-02.md`** §T-EXP-6 — this ticket's scope explicitly enumerates the five sourcing routes and asks for a decision tree per route + per-cue allocation table + first-pass M2-w1 sourceable subset (8–12 cues).
5. **`team/uma-ux/combat-visual-feedback.md`** §7 — already maps 9 audio cue IDs (from `audio-direction.md`) to combat visual events. M1 RC bug-bash + Devon's `86c9m36zh` combat fix surface a tight first-pass need: player attack + hit-connect + grunt-hit/die cues are the next-most-visible audio gap if Sponsor re-soaks post-fix.
6. **`team/DECISIONS.md`** lines 351–365 — confirms the five M2-onset locks (stash UI, save schema v4, stratum-2 biome, M2 week-1 backlog, combat VFX) all in place; audio aesthetic lock + 5-bus + OGG + cue-ID==filename **still pending DECISIONS.md formal append** (carry-forward from Uma run-002 / run-003 — captured in `audio-direction.md` §"Cross-role decisions to log" but not yet appended). Flagged for Uma's next dispatch (separate from this doc — keeps PR scope clean).
7. **`team/uma-ux/audio-direction.md`** §4 source-of-truth flow — the folder layout (`audio/sfx/{player,mobs,items,world,ui,flow}/`, `audio/music/{title,stratum1,stratum2,common}/`, `audio/ambient/{stratum1,stratum2,common}/`, optional `audio/_src/` for hi-fi if <10 MB) and naming convention (`<bus>-<role>-<descriptor>[-variant].ogg`, all lowercase, kebab-case, cue-ID == filename stem) are pre-locked. This pipeline doc honors them verbatim.

This doc does NOT re-derive direction. It operationalizes the existing direction.

---

## Per-source-method playbook

The five routes. Each has: **when this route applies**, **flow**, **per-cue cycle time**, **commit pattern**, **anti-pattern**.

### Route 1 — Procedural in-engine

**When this route applies:** rare, but a fit for **algorithmic/parameterized cues** where authoring a static file would freeze a parameter we want to vary at runtime. Realistic candidates: `sfx-tick-soft` (60 ms cadence number-tick — a `AudioStreamGenerator` with a 4 kHz pure-tone burst gated by ADSR is cheaper than 4 hand-Foley variants and avoids the obvious-loop problem), `sfx-ui-hover` (very-soft single tick — same shape), and **only those two**. Procedural is *not* the right route for music or ambient (dark-folk chamber doesn't survive synthesis); not the right route for combat SFX (visual cues lock the timing — a procedural blast doesn't read as "blade meets flesh").

**Flow:** (a) Devon implements the generator script (`scripts/audio/ProceduralCueBank.gd` autoload — `play_cue(cue_id: StringName)` switch); (b) Uma supplies the parameter spec (frequency / ADSR envelope / amplitude); (c) audio-loader treats the cue ID as a virtual stream — same dictionary key, different stream class.

**Per-cue cycle time:** 30 min (Uma supplies spec, Devon writes ~10 lines). Same-tick if Devon has bandwidth.

**Commit pattern:** zero file under `audio/`. Cue ID maps to procedural generator entry. Tess's AD-row check still fires by event (the test "did the cue fire" doesn't care if the source was a file or a generator). No attribution.

**Anti-pattern:** procedurally generating cues we already have a clear sample-based vision for (player attacks, mob deaths, music). Synth-as-shortcut breaks the dark-folk aesthetic on first listen.

**Route 1 cue count: 3** (`sfx-tick-soft`, `sfx-ui-hover`, optional fallback for `sfx-stat-allocate` UI tone layer). All M1 must / nice.

### Route 2 — Hand-Foley

**When this route applies:** **physical-source cues** that benefit from real-world recording — footsteps, leather rustles, bell strikes, parchment, wooden taps, soft clicks. The dark-folk aesthetic (`audio-direction.md` §1) explicitly calls for "real-room reverb, every sound feels physical." Hand-Foley is the route for any cue where "leather on stone" or "fingernail tap" is the keyword. Bell-tone cues (`sfx-bell-struck` and any layer that re-uses it) are hand-Foley first; if the bell strike gets recorded once, every layered cue (`sfx-item-pickup`, `sfx-level-up`, death Beat C, boss Beat 4 + F1) re-uses the same source.

**Equipment notes:**
- **Recorder:** any modern phone (iPhone Voice Memos / Android Recorder) records 48 kHz / 16-bit AAC out of the box. Re-encode to 44.1 kHz mono WAV in DAW for editing, export q5 OGG. iPhone in a quiet room beats a $200 USB mic in a noisy one — room treatment > gear.
- **Source props:** leather belt + flat stone (footsteps), small bronze bell or tuning fork or struck glass (bell tone — pitch by jar size), single sheet of parchment / printer paper (rustle), wooden chopstick on a wooden cutting board (UI clicks), cape / scarf swung past the mic (cloth whoosh for dodge).
- **Room:** small room with carpet, late at night, devices off. Stand 30–60 cm from the source. Multiple takes always — pick the best in DAW.

**Recording flow:** (a) record 6–10 takes per source action; (b) import to DAW (Audacity or Reaper free tier — Aseprite-pipeline parallel, no license cost); (c) cut to per-cue length per `audio-direction.md` cue-list duration column; (d) light EQ (high-pass at 60 Hz to kill room rumble; a soft +2 dB shelf at 4–6 kHz on bell tones for "shimmer"); (e) light compression (~3:1, 6–10 ms attack, 80 ms release — dynamic but tight); (f) reverb sparingly — small chapel ~1.4 s tail per `audio-direction.md` §1, dry on UI clicks; (g) export 44.1 kHz mono OGG q5; (h) commit + log to attribution doc as "hand-Foley by Uma 2026-05-DD" (no license bookkeeping required for self-recordings; just a creator+date row).

**Per-cue cycle time:** ~30 min for a single cue (recording + edit + encode). Batched route for 4 footstep variants is ~45 min total (record 8 takes once, cut into 4 variants in DAW). Bell strike is ~30 min once but reused everywhere — amortized cost is sub-5-min per re-use.

**Commit pattern:** OGG under `audio/sfx/<scope>/<cue-id>.ogg`. Hi-fi WAV NOT committed unless < 10 MB AND it's the actual ship asset. Source raw recordings under `audio/_src/foley/<cue-id>-raw.wav` only if needed and small; otherwise discarded after the OGG export. Attribution row in `audio-sources.md`: `cue-id | hand-Foley | Uma | 2026-05-DD | (no license)`.

**Anti-pattern:** trying to hand-Foley a death gurgle / orc roar / boss horn — those need either creature samples or hand-composed instruments. Foley is for *non-vocal physical* sounds.

**Route 2 cue count: 16** — all 4 footstep variants (`sfx-footstep-stone-01..04`), `sfx-footstep-dirt` (M2), `sfx-bell-struck` (recorded once, reused by 4 layered cues), `sfx-ui-click`, `sfx-stat-allocate` (click portion), `sfx-tick-soft` (alternate to procedural — cheap to record once if procedural slips), `sfx-string-low-death` *if* Uma owns a cello (otherwise hand-composed route — see §Route 5).

### Route 3 — Freesound-licensed (CC0 / CC-BY)

**When this route applies:** **creature sounds, weapon swings, impacts, doors, ambients** — anything where (a) a quality recording exists in the wild, (b) self-recording is impractical (no orc growl in the kitchen), (c) the cue tonality is locked enough that we can search-and-curate. This is the highest-volume route in M1 must — most of `audio-direction.md`'s combat / mob / world SFX columns already say "freesound".

**Search strategy** (Freesound.org — Uma's primary source; alternates: Mixkit, Pixabay Audio, all CC0):
- **License filter:** `license:Creative Commons 0` first (CC0 = public domain, zero attribution overhead). If no CC0 result fits, fall back to `license:Attribution` (CC-BY 4.0) — attribution row mandatory.
- **Query shape:** keyword + duration filter + sample-rate filter. Example: `sword swing short` + duration ≤ 1 s + sample rate ≥ 44.1 kHz. Filter to `Sound effect` + sort by `Best match`.
- **Curate 3–5 candidates** before committing. A single cue benefits from layering (e.g., `sfx-player-hit-connect-heavy` = blade-on-flesh + bone-snap = two CC0 samples mixed in DAW).
- **Common-name traps:** "footsteps" returns 10000+ results; "leather boots stone" returns 80 — narrow your query.
- **Rejection signals:** loud room tone (browser-noisy), inconsistent volume across one take, obvious phone-mic'd-in-a-bedroom recordings, cues with music bed underneath (we don't ship someone else's track ducked under our SFX), license unclear / restrictive.

**Flow:** (a) freesound search → 3–5 candidates; (b) listen in browser → shortlist 1–2; (c) download WAV / FLAC originals; (d) DAW: trim head + tail silence, normalize peak to -3 dBFS, mix layers if relevant, light EQ to fit the dark-folk aesthetic (cut harsh > 6 kHz on metallic samples; warm low end > 200 Hz on creature sounds); (e) export 44.1 kHz mono OGG q5 (or stereo q7 for ambient); (f) commit + log to `audio-sources.md` with creator handle + freesound URL + license string + sample ID(s) used.

**Per-cue cycle time:** **~5 min** for a found cue, **~15 min** if the cue requires layering 2+ samples. Layered impact cues (heavy attack + bone) are the longer end.

**Commit pattern:** OGG under `audio/sfx/<scope>/<cue-id>.ogg`. **Always log** in `audio-sources.md` even for CC0 (auditor's trail for "did we license this right" is more valuable than the per-license-row labor).

**Attribution doc — `audio-sources.md` registry shape** (NEW doc; ships in this PR? — see §Open questions Q3. **Recommendation: ship it as a sibling doc in this PR**, headers + zero rows; rows fill as cues land):

```
# audio-sources.md
| cue ID | route | source URL or creator | license | sourced | notes |
|--------|-------|----------------------|---------|---------|-------|
| sfx-player-hit-light | freesound | https://freesound.org/s/12345/ by user-x | CC0 1.0 | 2026-05-DD | layered with sfx-player-hit-light-grunt |
```

**Anti-pattern:** assuming license. Always click through to verify CC0 vs CC-BY. CC-BY-NC is unusable (we ship the game; "non-commercial" doesn't fit). CC-BY-SA is risky (share-alike infects the project license — skip unless legal-cleared, which we won't do for an early-stage hobby project).

**Route 3 cue count: 28** — most of M1's mob hit/death/aggro SFX, player hit cues, item drop / equip / tab open-close, door open / slam, save fail, all M2 mob cues (charger/shooter/Stoker windups, hits, deaths), all stratum-1 + stratum-2 ambient room beds + torch loop. 28 of 62 cues.

### Route 4 — AI-curated (Stable Audio / Riffusion / udio.ai / similar)

**When this route applies:** **rare and bounded.** The dark-folk-chamber aesthetic lock (no synths, no orchestral swell, no chiptune) is hostile to most music-generation outputs — they tend toward overproduced, glossy, modern-instrument timbres that don't match a stone-room-with-one-fire feel. Two narrow uses survive:
- **Inspiration / mood-board generation** — generate 10 short prompts at "low cello drone, frame drum heartbeat, sparse piano, small chamber" and pick reference clips that inform Uma's hand-composed authoring (Route 5). Output is **not committed**; only the inspiration informs the actual hand-composed work.
- **Polish overlay** — once a hand-composed loop exists, AI-curated soft layers (e.g., a 60 s tonal pad to bed under `mus-stratum1-bgm`) can be generated, post-processed (low-pass at 2 kHz, -18 dB gain, EQ-matched to the cello) and mixed in DAW. This is **stretch, not blocking** for M2.

**Prompt strategy** (if used at all): explicit anti-keywords first — `no synth, no orchestral, no electric, no drums, no vocals`. Positive keywords: `solo cello`, `frame drum`, `bronze bell`, `hurdy-gurdy drone`, `small acoustic ensemble`, `dark folk`, `chamber`, `mournful`, `intimate`. Length: keep prompts short and re-roll. Most outputs will fail the aesthetic check; budget 20+ generations per usable clip.

**Post-processing:** mandatory. AI outputs at 44.1 kHz often have artifacts — light de-noise, low-pass roll-off above 8 kHz to take the digital sheen off, light tape-saturation if the DAW has a free plugin. Then OGG q7 export.

**Per-cue cycle time:** ~10 min generation + 20 min curation + 30 min post-processing = **1 hour** per usable polish layer. Higher cycle time than freesound, lower than full hand-compose.

**Commit pattern:** committed OGG. **Attribution row mandatory** — log model name + version + prompt in `audio-sources.md` so we have an auditor's trail. Most AI-music-gen tools have evolving license terms; favor outputs we're allowed to re-license, otherwise route is dead.

**Anti-pattern:** using AI-curated as the **primary** source for any music or ambient cue. Aesthetic-lock contradiction — the timbre won't match. Music is hand-composed; ambient is freesound + DAW mix; AI is polish-only.

**Route 4 cue count: 1** — at most a polish layer for `mus-stratum1-bgm` or `mus-stratum2-bgm`. **Defer to M2-week-2 or M3** unless an AI tool's output happens to slot cleanly. Most likely outcome: zero AI-curated cues ship in M2.

### Route 5 — Hand-composed

**When this route applies:** **all music** (4 M1 must + 5 M2/M3 stems) and **a small set of pitched SFX** that are aesthetically melodic — bell-triad layers (`sfx-item-tier-T2`, `sfx-item-tier-T3`), `sfx-boss-phase-break` (cello double-stop), `sfx-boss-kill-horn`, `sfx-level-up` (bell triad + horn flourish), `sfx-ember-rise` (filtered noise + bell tail), `sfx-summary-pad` (cello drone), `sfx-string-low-death` (cello drone — if Uma owns a cello, this could route to hand-Foley instead; default = hand-composed for control). Plus `sfx-save-success` (single muted bell-tone, hand-composed for pitch control).

**Collaboration plan or DIY** (Uma's call):
- **DIY (default):** Uma authors in DAW (Reaper free tier, or LMMS, or Ardour). Sample libraries: Spitfire LABS (free, includes solo cello + felt piano + frame drum) covers most of the dark-folk-chamber palette. Bell tones can be sampled from hand-Foley (Route 2) and pitched in DAW. Hurdy-gurdy drone available via free Decent Sampler libraries.
- **Collaboration (stretch):** if a hand-composed pass takes > 4 hours per cue, Uma flags Priya for "should we commission a single composer's pass for the M3 promotion of `mus-stratum1-bgm`?" Cost vs. quality call. Out of scope for M2-week-1.

**Per-cue cycle time:** **1–4 hours** for a hand-composed cue. Wide variance. ~1 h for a single sustained cello drone (`sfx-summary-pad`, `sfx-string-low-death`), ~2 h for a single-instrument layered cue (`sfx-ember-rise`, `sfx-boss-phase-break`), ~3–4 h for a music loop (~60–120 s, multi-instrument, hand-arranged — `mus-stratum1-bgm`, `mus-stratum2-bgm`, `mus-boss-stratum1`, `mus-title`).

**Commit pattern:** OGG q7 (music) or q5 (single-instrument SFX) under `audio/music/<scope>/` or `audio/sfx/flow/`. Hi-fi DAW project files NOT committed (will exceed 10 MB) — link to a personal cloud / blob in `audio-sources.md` if needed. **Attribution:** "hand-composed by Uma 2026-05-DD" — same shape as hand-Foley, no license overhead.

**Versioning:** if Uma re-records an instrument or arranges a better take, the OGG file replaces in place per `audio-direction.md` §4 versioning rule. We do not ship `mus-stratum1-bgm-v2.ogg`.

**Anti-pattern:** hand-composing under deadline pressure. If the route would take > 4 h on a P0/M1-must cue, **fall back to placeholder loop from freesound** (license-cleared, dark-folk-keyword search, q7 OGG) and queue the hand-composed promotion for M3. Per `m2-week-1-backlog.md` §R10, placeholder is the explicit acceptable fallback — not a regression.

**Route 5 cue count: 14** — includes both music (the 4 M1 must + the M2/M3 stems), and the small pitched-SFX cluster. Heaviest-latency route.

---

## Cue-by-cue source allocation table

Every M1+M2 cue from `audio-direction.md`, recommended route, priority bucket. Priority = **M2-w1** (the first-pass subset, see §10), **M2-w2+** (other M1-must / M1-nice cues that ship in M2 weeks 2+), **deferred-M3** (M2 cues whose route or scope makes them M3 polish).

### SFX — combat & player

| cue ID | route | priority |
|--------|-------|----------|
| `sfx-player-hit-light` | freesound (leather impact + grunt layered) | M2-w1 |
| `sfx-player-hit-heavy` | freesound (bone-leather impact + inhale layered) | M2-w1 |
| `sfx-player-die` | freesound (single exhale) + reverb in DAW | M2-w2+ |
| `sfx-player-dodge` | freesound (cape/cloth swing, dry) | M2-w1 |
| `sfx-player-attack-light` | freesound (sword swing, short) | M2-w1 |
| `sfx-player-attack-heavy` | freesound (sword swing) + freesound effort grunt layered | M2-w1 |
| `sfx-player-hit-connect-light` | freesound (blade-on-flesh) | M2-w1 |
| `sfx-player-hit-connect-heavy` | freesound (blade-on-flesh + bone-snap layered) | M2-w1 |
| `sfx-player-block` (M2) | freesound (sword-on-shield) | M2-w2+ |
| `sfx-footstep-stone` (4 variants) | hand-Foley (1 batch session) | M2-w2+ |
| `sfx-footstep-dirt` (M2, 4 variants) | hand-Foley | deferred-M3 |

### SFX — mobs

| cue ID | route | priority |
|--------|-------|----------|
| `sfx-grunt-aggro` | freesound (creature growl + pitch shift) | M2-w1 |
| `sfx-grunt-attack` | freesound (effort grunt + cloth swing) | M2-w2+ |
| `sfx-grunt-hit` | freesound (creature yelp) | M2-w1 |
| `sfx-grunt-die` | freesound (creature death + thud) | M2-w1 |
| `sfx-shooter-attack` (M2) | freesound (bow twang) | M2-w2+ |
| `sfx-shooter-die` (M2) | freesound (different creature voice) | M2-w2+ |
| `sfx-charger-windup` (M2) | freesound (hoof-scrape + inhale) | M2-w2+ |
| `sfx-charger-impact` (M2) | freesound (body slam) | M2-w2+ |
| `sfx-charger-die` (M2) | freesound (large-creature death) | M2-w2+ |
| `sfx-boss-aggro` | freesound (brass note) + hand-Foley stone-impact | M2-w2+ |
| `sfx-boss-phase-break` | hand-composed (cello double-stop) | M2-w2+ |
| `sfx-boss-hit` | freesound (large-creature hit) + reverb | M2-w2+ |
| `sfx-boss-die` | (re-uses `sfx-bell-struck` + silence) | M2-w2+ (no new file) |
| `sfx-boss-kill-horn` | hand-composed (alphorn or low trombone — Spitfire LABS sample) | M2-w2+ |

### SFX — items, world, UI

| cue ID | route | priority |
|--------|-------|----------|
| `sfx-item-drop` | freesound (item drop, pitch-varied per tier) | M2-w1 |
| `sfx-item-pickup` | hand-composed (bell tone, tier-pitched) | M2-w2+ |
| `sfx-item-equip` | freesound (leather + buckle) | M2-w2+ |
| `sfx-item-tier-T2` | hand-composed (bell harmonic layer) | deferred-M3 |
| `sfx-item-tier-T3` | hand-composed (two-bell chime) | deferred-M3 |
| `sfx-bell-struck` | hand-Foley (single recording, reused everywhere) | M2-w1 |
| `sfx-door-open` | freesound (door creak) + hand-composed chime layer | M2-w2+ |
| `sfx-door-slam-heavy` | freesound (dungeon door slam) | M2-w2+ |
| `sfx-level-up` | hand-composed (bell triad + horn) | M2-w2+ |
| `sfx-stat-allocate` | hand-Foley (UI click) + procedural tone layer | M2-w2+ |
| `sfx-ui-click` | hand-Foley (wooden tap, recorded once) | M2-w1 |
| `sfx-ui-hover` | procedural (very-soft fingernail tick) | M2-w2+ |
| `sfx-ui-tab-open` | freesound (paper rustle) | M2-w2+ |
| `sfx-ui-tab-close` | freesound (paper fold) | M2-w2+ |
| `sfx-tick-soft` | procedural (4 kHz pure-tone burst, ADSR-gated) | M2-w2+ |
| `sfx-save-success` | hand-composed (muted bell-tone) | M2-w2+ |
| `sfx-save-fail` | freesound (low thud) | deferred-M3 |
| `sfx-ember-rise` | hand-composed (filtered noise + bell tail) | M2-w2+ |
| `sfx-summary-pad` | hand-composed (cello drone, simple) | M2-w2+ |
| `sfx-string-low-death` | hand-composed (single cello, low register) | M2-w2+ |

### Music

| cue ID | route | priority |
|--------|-------|----------|
| `mus-title` | hand-composed (cello + piano + bell, ~60 s loop) | M2-w2+ |
| `mus-stratum1-bgm` | hand-composed (cello drone + frame drum + sparse piano, ~90–120 s) | M2-w2+ (placeholder freesound dark-folk loop is the M2-w1 fallback) |
| `mus-boss-stratum1` | hand-composed (single track for all 3 phases in M1) | M2-w2+ |
| `mus-boss-stratum1-ph1/2/3` (M2 stems) | hand-composed (stems of `mus-boss-stratum1`) | deferred-M3 |
| `mus-stratum2-bgm` (M2) | hand-composed (~120 s) — placeholder freesound fallback per T10 R10 | M2-w2+ |
| `mus-victory-pad` | hand-composed (4 s sustained cello chord) | M2-w2+ |

### Ambient

| cue ID | route | priority |
|--------|-------|----------|
| `amb-stratum1-room` | freesound (cave/dungeon ambient) + DAW mix | M2-w1 |
| `amb-stratum1-torch` | freesound (torch crackle) + seamless loop edit | M2-w2+ |
| `amb-boss-room-pre` | (filtered version of `amb-stratum1-room`) | M2-w2+ (no new source) |
| `amb-stratum2-room` (M2) | freesound (steam-hiss + scree-rustle + vein-pulse hum) + DAW mix | M2-w2+ |
| `amb-wind-distant` (M2) | freesound (distant wind) | deferred-M3 |

**Source-mix totals across the 62 cues:**
- freesound: 28 (45%)
- hand-Foley: 16 (26%) — note: `sfx-bell-struck` recorded once → 4 reuse cues, so route-cue ratio is high
- hand-composed: 14 (23%)
- procedural in-engine: 3 (5%)
- AI-curated: 1 polish-only (2%) — likely zero in M2

---

## Operational flow — design says it → file is in repo

For every cue, the path:

1. **Cue locked** — already done in `audio-direction.md` cue-list rows. Cue ID + trigger + length + mood-keyword + source-plan all set.
2. **Route gate** — apply this doc's decision tree (§7 below). Output = one of {procedural, hand-Foley, freesound, AI-curated, hand-composed} + estimated cycle time.
3. **Source action** — execute the per-route flow above.
4. **Encode + naming** — 44.1 kHz mono q5 OGG (SFX) or 44.1 kHz stereo q7 OGG (music + ambient). Filename = cue-ID kebab-case + `.ogg`. Variant suffix `-NN` for 4-variant batches (footsteps).
5. **Commit** — under `audio/<type>/<scope>/<cue-id>.ogg`. Hi-fi source under `audio/_src/` only if < 10 MB AND it's the actual ship asset; otherwise discard.
6. **Attribution** — append row to `team/uma-ux/audio-sources.md` with cue-ID, route, source-or-creator, license, date, notes. **Even for self-recorded / hand-composed** rows. Auditor's trail > per-row labor.
7. **Wire** — Devon's audio-loader (per `audio-direction.md` §4: "Devon's audio-loader can build a single dictionary `cue_id → AudioStream` keyed off the filenames") picks up the new file automatically. No scene-tree edits.
8. **Tess gate** — Tess re-runs the relevant `audio-direction.md` §5 AD-row check. Pass = cue plays at the right engine event with the right ducking / mix.

**Commit cadence:** one PR per cue (clean) OR one PR per route batch (efficient). Recommendation: **batch by route** for M2-week-1 — author 5 freesound cues + 1 hand-Foley batch + 1 hand-composed + ship as one `feat(audio): M2-w1 first-pass cue batch` PR. Reduces per-PR review overhead and lets Devon wire all cues in one autoload pass.

---

## Decision tree — given a cue row, which route?

```
cue is music? → Route 5 (hand-composed). Fallback to placeholder freesound dark-folk loop if cycle > 1 tick.
cue is ambient? → Route 3 (freesound) + DAW mix.
cue is pitched SFX (bell, horn, cello, melodic)? → Route 5 (hand-composed).
  └─ exception: if Uma has a real cello/bell/horn → Route 2 (hand-Foley).
cue is procedural-friendly (algorithmic burst, gated tone, runtime-varied)? → Route 1 (procedural).
cue is physical-source, real-world reproducible (footstep, leather, paper, wood, click)? → Route 2 (hand-Foley).
cue is creature / weapon / impact / door / world? → Route 3 (freesound).
all others (rare polish layers, music overlay): → Route 4 (AI-curated, stretch only).
hand-composed cycle > 1 tick AND M2-w1 priority? → fall back to Route 3 (freesound placeholder), per R10.
```

---

## First-pass M2-week-1 sourceable subset (10 cues)

Goal: **8–12 cues** that can land alongside Devon's stash UI / save migration without blocking Drew/Devon. Selection criteria: (a) freesound or hand-Foley route (low cycle time), (b) high-visibility cue (combat / first-room / first-pickup), (c) zero gating on a not-yet-shipped feature, (d) reuses a single hand-Foley source if possible.

**The 10 (ordered by sourcing latency, lowest first):**

1. **`sfx-ui-click`** — hand-Foley, ~30 min. Wooden tap recorded once. Shipped immediately benefits every menu/inventory open in the live game.
2. **`sfx-bell-struck`** — hand-Foley, ~30 min. **Highest leverage** — single recording, reused by `sfx-item-pickup` (M2-w2+), `sfx-level-up`, `sfx-boss-die`, `sfx-boss-kill-horn` chord chain, splash / death Beat C / boss intro Beat 4. M2-w1 ships the source file; the layered cues that depend on it ship in week-2+ once the bell exists.
3. **`sfx-player-attack-light`** — freesound, ~5 min. Sword-swing-short query.
4. **`sfx-player-attack-heavy`** — freesound, ~10 min. Layered sword swing + effort grunt.
5. **`sfx-player-hit-connect-light`** — freesound, ~5 min. Blade-on-flesh.
6. **`sfx-player-hit-connect-heavy`** — freesound, ~15 min. Blade-on-flesh + bone-snap layered.
7. **`sfx-player-hit-light`** — freesound, ~10 min. Leather impact + soft grunt layered.
8. **`sfx-player-dodge`** — freesound, ~5 min. Cape/cloth swing, dry.
9. **`sfx-grunt-die`** — freesound, ~5 min. Creature death + thud.
10. **`amb-stratum1-room`** — freesound + DAW mix, ~20 min. Cave/dungeon ambient bed; immediately enriches every stratum-1 room.

**Total Uma effort estimate:** ~2.5 hours of focused authoring + ~1 hour of DAW + encoding + attribution logging = **~3.5 hours of one Uma dispatch**, sized M (3–5 ticks).

**Why these 10:**
- 7 of them are combat / player-action cues — Sponsor's M1 RC bug-bash flagged combat-feel as the visible gap. Audio cues amplify Devon's combat-fix landing.
- `sfx-bell-struck` is the highest-multiplier cue — one recording unlocks 5+ derivative cues for week-2.
- `amb-stratum1-room` is the always-on audio bed — adding it once flips every stratum-1 room from "silent dungeon" to "stone room with a fire," which is the dark-folk aesthetic anchor in audio.
- Zero of these 10 require Devon's audio-bus wiring beyond what `audio-direction.md` §3 already specs. Files land; Devon's audio-loader picks them up; Tess validates the AD-row checks fire.

**Anti-list (NOT in the 10):**
- `sfx-grunt-aggro` — freesound but lower visibility than `sfx-grunt-die` if Sponsor is killing grunts in 2–3 hits.
- `mus-stratum1-bgm` — would be highest-leverage but cycle time too high for a single dispatch (4 h hand-composed; placeholder freesound dark-folk loop is acceptable but punts the aesthetic call). Recommend dispatching as a separate M2-w1 ticket if envelope allows; otherwise M2-w2.
- `sfx-footstep-stone` (4 variants) — hand-Foley batch session ~45 min; fits, but moves to M2-w2 since combat audio is more bug-bash-relevant per Sponsor's last soak.
- All M2-only cues (charger / shooter / Stoker windups, S2 ambient, S2 BGM) — wait for T4–T6 sprite/scene work to land before authoring audio for them.

---

## Open questions (for orchestrator / Priya)

1. **Should the hand-composed `mus-stratum1-bgm` placeholder ship in M2-w1, or accept silence + freesound ambient bed only until M2-w2's hand-composed pass?** Uma's lean: **silence + ambient bed** in M2-w1. Adding a dark-folk-keyword freesound loop now risks a tonal mismatch when the hand-composed loop replaces it (player learns the placeholder, then the upgrade feels like a regression). Better to ship the full ambient bed (item 10 above) and let the room breathe quietly — matches `audio-direction.md` §1 "the discipline of *almost no music, then a single instrument when it matters*." Awaiting Priya's call.
2. **Is AI-curated (Route 4) on the table at all given the dark-folk-acoustic aesthetic lock?** Uma's lean: **defer to M3** unless an opportunistic polish layer surfaces. The aesthetic lock is hostile to most music-gen output timbres; budget for AI-curated is realistically zero in M2. Listing it as a route at all is for completeness — DECISIONS.md should not commit budget here.
3. **`audio-sources.md` attribution registry — ship as a sibling NEW doc in this PR (headers + zero rows) or wait until the first cue lands and ship with row 1?** Uma's lean: **ship it now in this PR** with headers + zero rows + clear filing rules. Zero-overhead to author; gives every future audio dispatch a known target file; avoids a "where do I log this" question on the very first sourcing PR. Awaiting Priya's call (deviation from "doc lands when first row exists" — minor).

---

## Caveat — this is a draft, revisable

Same disposition as `m2-week-1-backlog.md` and `combat-visual-feedback.md`. Revisions land if:
- Sponsor's M1 RC re-soak (post combat-fix) surfaces audio-feel pushback that adjusts route assignments.
- Uma's first hand-Foley session yields different cycle-time data — the per-route cycle-time estimates above are educated guesses, not measured.
- A specific freesound cue search turns up empty for a cue listed as freesound — that cue gets a route re-classification (likely → hand-Foley or hand-composed) and a v1.1 row update.
- `audio-direction.md` v1.2+ adds new cues — every new cue gets a route assignment in this doc as an append.

**This is the path of least resistance from "60+ cue list" → "Tess can fire AD-01..AD-37 against real audio."** It is not the only path.

## Cross-role decisions to log in DECISIONS.md (this PR)

One-line append on commit:

> 2026-05-03 — M2 audio sourcing pipeline scoped: 5 routes (freesound 45% / hand-Foley 26% / hand-composed 23% / procedural 5% / AI-curated 1%), 10-cue M2-w1 first-pass subset locked, R10 placeholder-fallback discipline preserved. Detail: `team/uma-ux/audio-sourcing-pipeline.md`.
