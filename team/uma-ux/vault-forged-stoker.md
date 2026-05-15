# Vault-Forged Stoker — Visual Direction + Breath-Cone Telegraph Spec (W3-T4 prep)

**Owner:** Uma · **Phase:** M2 W3 (design only; consumed by Drew's W3-T4 boss-room first impl, ClickUp `86c9uf86n`) · **Status:** authoritative for the visual-direction layer of W3-T4. Drew can quote this doc directly in his dispatch brief.

This is the **synthesis-for-Drew** layer between four existing source-of-truth docs and one new ticket. Nothing here invents new visual language: every primitive choice, palette anchor, and beat structure flows from a parent doc. The contribution is **the specific call** — which palette tint, which primitive, which beat overrides — for the Vault-Forged Stoker encounter at the end of S2.

## TL;DR (5 lines)

1. **Visual identity:** the Vault-Forged Stoker is a heat-warped, scale-1.6× variant of the W3-T6 baseline Stoker — same silhouette family (miner's cap + torn smock + iron mask), pushed darker on cloth and harder on iron, with embergrave veins running through its body the way they run through the vault walls. Reads as "the Vaults built a champion from one of their own."
2. **Breath-cone primitive: rotated `ColorRect`** (NOT Polygon2D). Same primitive class as the M1 swing_wedge after PR #137 — sidesteps the WebGL2 HDR clamp + Polygon2D divergence preemptively.
3. **Sub-biome arena palette recommendation: YES, deepest-mine-seam variant.** Two value-shifts off Cinder Vaults baseline; the boss room should read as "you've descended further into the vein than any other S2 room." Resolves `palette-stratum-2.md` §8 q1.
4. **Intro reuse: `boss-intro.md` Beat-1 to Beat-5 verbatim**, with three specific overrides (vein-flare on Beat-2 instead of torch-dim, warm-red palette swap on the vignette, longer Beat-3 reveal because the boss is larger). Phase-transition + boss-defeated sequences reuse `boss-intro.md` Beat-T and Beat-F1..F4 verbatim.
5. **Audio crossfade intersection:** the visual enrage telegraph (66%/33% HP) fires WITH the audio crescendo Devon will wire from `mus-boss-stratum2`'s minor-third cello bed + 80 BPM frame-drum drive (DECISIONS.md 2026-05-15 — unique not cross-stratum). Visual narrative reinforces music distinctness — this is **not** the Warden in a different paint job.

## Source-of-truth links

This doc consumes:

- `team/uma-ux/palette-stratum-2.md` — §5 sprite reuse table + §7 tester pins + §8 q1 (sub-biome boss-room palette open question this doc resolves)
- `team/uma-ux/boss-intro.md` — Beat 1-5 (1.8s entry) + Beat-T (phase break) + Beat-F1..F4 (defeated). **Reused verbatim** for the Vault-Forged Stoker with three Stoker-specific overrides called out in §4 below.
- `team/uma-ux/audio-direction.md` § `mus-boss-stratum2` (row 88) — the unique S2 boss cue Uma authored in W3-T9 (`86c9ue23j`). DECISIONS.md 2026-05-15 logs the unique-not-reuse call.
- `team/decisions/DECISIONS.md` 2026-05-15 — boss music UNIQUE to S2, not cross-stratum reuse. Visual narrative must reinforce that distinctness.
- `.claude/docs/combat-architecture.md` § "Mob `_die` death pipeline" + Stratum1Boss `take_damage` three-case rejection trace (load-bearing for stagger-immune phase transitions).
- `.claude/docs/html5-export.md` § "HDR modulate clamp" + § "Polygon2D rendering quirks" + § "Z-index sensitivity" — these constrain the breath-cone primitive choice.
- `team/priya-pl/m2-week-3-backlog.md` §W3-T4 — the 9-state state machine Drew will build (dormant → idle → chasing → telegraphing_breath → breathing → telegraphing_slam → slamming → phase_transition → dead).
- `scripts/mobs/Stratum1Boss.gd` — the canonical 3-phase state machine + dormant/phase_transition/stagger-immune rejection-trace pattern Drew mirrors.

---

## §1 — Vault-Forged Stoker visual identity

### Sprite color anchors

Extend the W3-T6 Stoker baseline from `palette-stratum-2.md` §5 mob ramp. The Vault-Forged variant is **darker, harder, vein-saturated**:

| Role | Baseline Stoker (W3-T6) | Vault-Forged Stoker (W3-T4) | Δ rationale |
|---|---|---|---|
| Mob cloth | `#7A1F12` (heat-corroded smock) | `#5A0F08` (deep heat-charred, +12pp saturation, -18pp value) | Boss is more burnt; the smock has been heat-cycled past the grunt's threshold. |
| Mob skin | `#7E5A40` (sun-scorched mid-tone) | `#6A4530` (deeper soot-stain, -10pp value) | Skin reads as "this body has been in the heat longer." |
| Mob iron mask / iron strut accents | `#2C2620` (blackened iron from `palette.md`:188) | `#1A1410` (vault-iron, near-black, -6pp value) | Mask is welded shut; the iron is closer to the wall-strut color than the regular Stoker's worn mask. |
| **Vein motif on body** (NEW for boss) | n/a | `#C25A1F` mid + `#FF6A2A` core (same as wall veins, `palette-stratum-2.md` §2) | **Diegetic load-bearing:** the boss has ash-glow veins running through ITS BODY the way they run through the vault walls. The Vaults built a champion from one of their own — and the embergrave grew into them. Visual rhyme with the player's flame (same `#FF6A2A` ember accent) sets up the S7-S8 fiction escalation. Per `palette-stratum-2.md` §1 narrative ("first reveal of where your flame comes from"). |
| Mob aggro eye-glow | `#D24A3C` (cross-stratum constant, PL-11) | `#D24A3C` (UNCHANGED) | Aggro eye-glow is a cross-stratum tester contract. Holding the line. |
| Weapon edge (mining pick) | `#9C9590` (worn iron) | `#9C9590` (UNCHANGED) | Same era of metalwork as the grunt Stoker. |
| Breath-cone palette (NEW) | n/a | `#C25A1F` (mid, outer cone) → `#FF6A2A` (core fill) → `#FFB066` (hottest interior wisps; bound by `#FFE6C0` anti-list per S2) | See §2. The cone primitive uses the same vein-palette as the body veins — visually reads "the boss is exhaling its own veins at you." |

**Aggro-eye-vs-body-vein disambiguation note.** The body-vein cores (`#FF6A2A`) and the aggro eye-glow (`#D24A3C`) share value range. Per `palette-stratum-2.md` §6 Pair D, disambiguation is **by position, not color**: the eye-glow is a single 4×4 px highlight on the boss's mask; the body veins are 1px bands running through the cloth+skin tiles. Different shape, different position, never collide.

### Scale + silhouette

- **Scale: 1.6× vs the W3-T6 baseline Stoker.** Same proportional silhouette (miner's cap, torn smock, iron mask, mining pick) — just larger. Per `boss-intro.md` Beat-3 reveal pattern: the boss stands up / unfurls / lights its ember during the 0.5s wake animation; for the Vault-Forged Stoker this is **"unfurls" specifically** (the smock drops from a hunched-corpse posture to upright). The 1.6× is calibrated against Stratum1Boss precedent — the Warden is ~1.5× the Grunt; the Vault-Forged Stoker should read MORE imposing than its predecessor, hence 1.6×.
- **Mining pick scaled to 1.6×, NOT 2.0×.** Avoid making the weapon dominate the silhouette; the boss's identity is the body veins + the iron mask, not the pick.
- **Silhouette tells (1-second read at-screen):**
  1. Larger-than-room-Stoker reads "boss" within first frame of reveal.
  2. Vein-glow through the body reads "vault-forged" within first second of reveal — this is the *new* signal beyond "bigger Stoker."
  3. Iron mask is welded fully shut (no eye-slit gap on the regular Stoker — the boss's eyes are inside the mask, the aggro-glow leaks through the mask's seams).

### Sub-biome arena palette — RECOMMENDATION: deepest-mine-seam (vein-saturated)

This resolves `palette-stratum-2.md` §8 q1.

**Recommendation: yes, the Vault-Forged Stoker arena gets its own sub-biome variant.** Two value-shifts off the standard Cinder Vaults palette. Rationale below.

| Role | Cinder Vaults standard | Boss arena sub-biome ("deepest mine seam") | Δ |
|---|---|---|---|
| Floor — base | `#3F1E1A` | `#2A0F0A` | -7pp value, slight desaturation. "We've descended further; the burnt-earth is older here." |
| Floor — deep | `#1F0F0C` | `#100604` | -4pp value, near-pure-black extreme. Phase-3 enrage reads dramatically against this. |
| Wall — base | `#2A1410` | `#1A0A08` | -4pp value. The walls feel CLOSER (less light bouncing off them). |
| Wall — vein density | sparse vertical veins on ~30% of wall tiles | **dense veins on ~80% of wall tiles**, including floor seams | The vein is the dominant wall feature here. The boss room IS the seam. |
| Ash-glow vein — mid | `#C25A1F` | `#C25A1F` (UNCHANGED) | Vein palette stays — but density doubles, and pulse rate goes from 6 fps to 4 fps (slower, more menacing). |
| Ash-glow vein — bright core | `#FF6A2A` | `#FF6A2A` (UNCHANGED) | Same ember-accent through-line. |
| Ambient tint overlay | `#FF5A1A` at 8% alpha | `#FF5A1A` at **12% alpha** | +4pp alpha. Room reads visibly redder than the rooms before it. |
| Vignette | `#0A0404` at 40% | `#0A0404` at **55% alpha** | +15pp alpha (toward the 60% target for S7-S8 progression). The room narrows on the boss specifically. |

**Why deepest-mine-seam over standard:**

1. **Mirrors S1 precedent.** Stratum1Boss arena uses a sub-biome (darker corner of cloister palette) — same pattern, same purpose.
2. **Reinforces the unique-music decision.** DECISIONS.md 2026-05-15: `mus-boss-stratum2` is UNIQUE not cross-stratum. The visual should reinforce that distinctness — a standard-palette boss room would visually undercut the audio's "this place is different" signal.
3. **Sets up S7-S8 progression.** The vignette ramp (`palette.md`: 30% → 60% across 8 strata) wants the S2 boss arena at ~55% as the natural next step. Standard S2 palette stays at 40% for the non-boss rooms.
4. **No new sprite authoring required.** Sub-biome palette is implementable as **TRES retint at the chunk level** — the existing wall/floor sprites get a darker-tint variant via the existing `CanvasModulate` pattern. Drew authors ONE chunk override TRES, not new sprites. Bounded cost.
5. **Daltonization holds.** The §6 daltonization run in `palette-stratum-2.md` was performed on the standard palette; this sub-biome is two value-shifts darker on the same hues, so the §6 pairs remain clear (value gaps WIDEN, not narrow — protanopia + tritanopia get easier, not harder).

**Sponsor escalation flag:** none. This is on-spec — `palette-stratum-2.md` §8 q1 explicitly delegated the sub-biome decision to Uma + Drew at the S2 boss ticket. Standard delegation per `sponsor-decision-delegation.md`.

### Animation states inventory (9 states)

Per `m2-week-3-backlog.md` §W3-T4 state machine: 9 states. Drew authors a sprite anim cycle per state. Frame counts are recommended floors; Drew has discretion above.

| State | Frames @ 6 fps | Visual cue |
|---|---|---|
| `idle` | 4-frame loop | Hunched-corpse posture; smock hangs limp; veins pulse at 4 fps (one cycle per 2s idle loop). Faint "breath" — chest rise/fall 2 px. |
| `chasing` | 6-frame walk loop | Upright posture (woke up); smock sways; pick over shoulder. Move speed = 80 px/s (mirror Stratum1Boss). |
| `telegraph_breath` | 8-frame (1.2s windup) | Boss plants pick in ground (frames 1-2), inhales (frames 3-5: chest fills, veins flare brighter, faint sub-bass hum), turns head toward player (frame 6), readies to exhale (frames 7-8: cone telegraph rectangle fades in over the last 0.4s — see §2). |
| `breathing` | 8-frame (0.8s commit) | Boss exhales; cone primitive at full alpha; particle emission peaks; head tracks player slowly during the breath. **Hitbox active throughout this state.** |
| `telegraph_slam` | 6-frame (0.6s) | Boss raises pick overhead (mirror of M1 Stratum1Boss slam telegraph). Cone primitive does NOT play here — this is the alt-attack. |
| `slamming` | 4-frame (0.4s) | Pick comes down; 8-direction radial AoE hitbox fires (Stratum1Boss mirror). Ground crack VFX on impact frame. |
| `phase_transition` | 6-frame (0.6s) | Boss takes step back (frame 1), vein-glow flares to peak brightness (frames 2-3 — `#FFB066` overlay at 60% alpha), step forward (frames 4-5), settle (frame 6). World time at 30% during this state (per `boss-intro.md` Beat-T). **Boss is stagger-immune AND damage-immune during this window** — same contract as Stratum1Boss `IGNORED phase_transition` rejection trace (`.claude/docs/combat-architecture.md` line 136). |
| `enrage` | 8-frame (0.8s, fires ONCE at phase-3 entry) | Same beats as `phase_transition` but with overlay flare extending the full 0.8s + a final brightness-spike frame on frame 8 (cone-widen visual confirmation — see §3). Audio intersection point with `mus-boss-stratum2` crescendo. |
| `die` | 12-frame (0.9s, drives the boss-defeated `Beat F2 — Embers rising`) | Boss kneels (frames 1-4), pick falls (frames 5-6), body slumps (frames 7-9), starts dissolving into upward embers (frames 10-12). Hands off to `boss-intro.md` Beat F2 ember-rise emitter at frame 12. **`_die` trace required** per `.claude/docs/combat-architecture.md` line 132 (`[combat-trace] VaultForgedStoker._die | starting death sequence`). |

**Idle-and-dormant note.** Per `Stratum1Boss.gd` precedent: the boss has a `dormant` substate of `idle` during the 1.8s entry sequence. `take_damage` returns `IGNORED dormant ... (boss still in entry sequence)` until Beat 5 hands control back to the combat loop. This is the load-bearing diagnostic from `.claude/docs/combat-architecture.md` line 136. Drew MUST preserve the three-case rejection trace pattern for the Vault-Forged Stoker too — `IGNORED already_dead | IGNORED dormant | IGNORED phase_transition`.

---

## §2 — Breath-cone telegraph spec

### Cone geometry

| Property | Value | Rationale |
|---|---|---|
| Cone half-angle (each side of center axis) | **30°** (total cone = 60°) | Wider than a sword swing (which is ~40° wedge), narrower than a slam (360°). Player must position-counter, not just back off. |
| Cone range | **120 px** (3.75 tiles at 32 px/tile) | Mid-range AoE — long enough to threaten the player's standard dodge distance (96 px per Stratum1Boss precedent), short enough that the player has a counter-position (flank). |
| Telegraph windup duration | **1.2 s** (the `telegraph_breath` state's 8-frame anim at 6 fps + a 0.4s cone-rectangle fade-in on the final 0.4s) | Mirrors the W3-T6 baseline Stoker's 1.0s telegraph but extended by 0.2s for boss-fairness (the boss attack is bigger; player needs slightly more read time). |
| Breath commit duration | **0.8 s** (the `breathing` state) | Hitbox active for the full 0.8s. Cone primitive at full alpha (50% if blend-modulate, see below) for the full 0.8s. |
| Total breath cycle | **2.0 s** (telegraph + commit) | Aligns to the audio frame-drum tempo at 80 BPM (one drum hit per 0.75s; one breath cycle spans ~2.67 hits — feels intentional). |
| Cooldown after breath commit | **1.5 s** (cooldown state, mirror W3-T6 baseline Stoker) | Standard mob cooldown idiom. |

### Visual primitive — `ColorRect` rotated rectangle (NOT Polygon2D)

**This is the load-bearing call.** Per `.claude/docs/html5-export.md` § "Polygon2D rendering quirks": Polygon2D shapes that render correctly on `forward_plus` / `mobile` may NOT render in `gl_compatibility` (WebGL2). PR #137's swing_wedge fix replaced a 3-vertex Polygon2D with a rotated `ColorRect` whose bounding rectangle = `size = reach × radius*2`. The Vault-Forged Stoker breath cone uses the **same primitive class** preemptively.

**Implementation hint for Drew:**

```
# scenes/mobs/VaultForgedStoker.tscn (or Drew's preferred org)
- VaultForgedStoker (CharacterBody2D)
  - Sprite (ColorRect or NinePatchRect for body)
  - BreathConeVisual (ColorRect, hidden by default)
    - size = Vector2(120, 120)  # range × (2 × tan(30°) × range) bounding rect
    - rotation = direction-to-player
    - modulate.a tween: 0 → 1 over 0.4s (final 0.4s of telegraph windup)
    - modulate.a = 1 throughout the 0.8s breath commit
    - modulate.a tween: 1 → 0 over 0.2s (state-exit fade-out)
  - BreathHitbox (Area2D, encapsulated _init pattern per combat-architecture.md)
    - Triangle CollisionPolygon2D matching the visual cone geometry
    - monitoring activated during the breathing state only
```

**Rectangle-vs-actual-cone fudge.** The `ColorRect` bounding rectangle is wider than the actual 60° cone hitbox — there's a triangular sliver on each side of the cone that visually reads as "in the cone" but is NOT in the hitbox. To resolve this honestly, Drew can:

1. **Recommended:** Use a `ColorRect` for the **outer-cone alpha gradient** (`#C25A1F` mid, modulate.a = 0.3 — soft, ambient heat) + a second `ColorRect` rotated to the cone's actual triangular interior (`#FF6A2A` core, modulate.a = 0.8 — the *visual hitbox*). The player learns "the bright triangle hits you; the wider haze is intimidation." Two-rect cost is negligible.
2. **Acceptable fallback:** Single `ColorRect` at the bounding rect, accept the small visual-vs-hitbox mismatch. Document in the Self-Test Report for Tess's HTML5 verification.

### Color anchors

Warm-red Cinder-Rust family, all sub-1.0 per HTML5 HDR clamp rule (`.claude/docs/html5-export.md` § "HDR modulate clamp"):

| Role | Hex | Modulate alpha | Notes |
|---|---|---|---|
| Cone outer (intimidation haze) | `#C25A1F` (vein-mid) | 0.3 | Sells "heat is in the air around the cone." |
| Cone core (visible hitbox) | `#FF6A2A` (vein-bright / ember accent) | 0.7 | The bright triangle = the actual damage area. Reuses ember accent intentionally — the boss exhales the same substance as the player's flame. Diegetic. |
| Cone hottest wisps (CPUParticles2D layer) | `#FFB066` (warm highlight from `palette.md`) | particle emit alpha 0.6 | Stay below `#FFE6C0` anti-list per S2 — never go white-hot. |

**Per-channel HTML5 safety check:** all three hexes have max channel < 1.0 (`#FF6A2A` = 1.0/0.42/0.16 — the R channel IS 1.0 but does not exceed 1.0; the modulate alpha multiplier brings the effective channel to 0.7, well sub-1.0 in render). Safe per the M1 precedent (`SWING_FLASH_TINT = Color(1.0, 0.85, 0.6, 1.0)` after PR #137). Tess's `test_player_swing_flash_tint_is_html5_safe` pattern transfers: paired test asserts `breath_cone_color * modulate_alpha` has all channels ≤ 1.0 and tint delta vs default ≥ 0.20.

**Z-index:** `BreathConeVisual.z_index = +1` (above floor, below player body). Per `.claude/docs/html5-export.md` § "Z-index sensitivity": do NOT use `z_index = -1`. Same constraint as the M1 swing_wedge fix.

### Phase-3 enrage cone-widening factor

Per `m2-week-3-backlog.md` §W3-T4 scope: "Phase 3 enrage: 1.5× speed, 0.7× recovery, breath-cone widens."

**Cone-widening parameters at phase-3 enrage:**

| Property | Phase 1-2 | Phase 3 enrage | Δ |
|---|---|---|---|
| Cone half-angle | 30° | **45°** | +15° per side (total cone goes 60° → 90°) |
| Cone range | 120 px | **150 px** | +25% reach |
| Telegraph windup | 1.2 s | **0.9 s** | -25% windup (per 0.7× recovery; player has less read time) |
| Breath commit | 0.8 s | 0.8 s (UNCHANGED) | Damage window stays — the boss is more aggressive, not more punishing per-hit |
| Particle density | 1× | **1.5×** | More embers, more menacing — within particle budget (see below) |
| Cone modulate.a core | 0.7 | **0.85** | Brighter cone reads "this is harder now" |

**The visual cue MUST fire WITH the audio crescendo** at the phase-3 enrage trigger. Per DECISIONS.md 2026-05-15: `mus-boss-stratum2` carries "two low-brass swells at phase-break beats." The enrage `phase_transition` state's frame 8 brightness-spike (60% alpha overlay) is the visual handoff to Devon's audio crescendo — they fire on the same physics-flush-safe call to `enter_phase_3()`. Devon wires the audio cue inside the same state-entry callback that fires the visual brightness spike.

### Particle cost audit (M1-compatible — CPUParticles2D budget)

**Budget reference:** M1 boss-defeated Beat F2 ember-rise emitter (per `boss-intro.md` line 140) ships ~60 CPUParticles2D simultaneous. M1 RC ran clean on HTML5 at the M1 cap. The S2 boss can budget up to **~80 simultaneous particles** without HTML5 regressions, on the assumption that there are no other concurrent particle-heavy effects in the arena (the deepest-mine-seam sub-biome's wall-vein pulse is sprite-anim, not particles — see `palette-stratum-2.md` §4 item 3).

**Recommended emitter set for the Vault-Forged Stoker:**

| Emitter | When | Particle count | Lifetime | Notes |
|---|---|---|---|---|
| `BreathConeWisps` (CPUParticles2D) | `breathing` state only | 24 emitting (max ~36 on-screen) | 0.6s | Embers flowing out of the cone core. `#FFB066` hue. |
| `BodyVeinPulse` (CPUParticles2D) | all states | 12 emitting (max ~18 on-screen) | 1.5s | Slow drift up from vein cores on the body. `#FF6A2A` hue, 0.4 alpha. |
| `PhaseTransitionFlare` (CPUParticles2D) | `phase_transition` + `enrage` states only | 30 emitting one-shot burst | 0.6s | Single-shot burst of embers radiating from boss body. `#FF6A2A` → `#FFB066` gradient. |
| `DeathDissolveEmbers` (CPUParticles2D) | `die` state, frames 10-12 | 50 emitting | 1.2s | Boss-defeated Beat F2 reuses this emitter — same authored emitter as Stratum1Boss death-dissolve, retinted for Cinder-Rust (`#C25A1F` mid → `#FF6A2A` core → `#FFB066` highlight). |

**Concurrent max:** during the `phase_transition` state, `BodyVeinPulse` (12) + `PhaseTransitionFlare` (30 burst) = 42 emitting. During the `breathing` state, `BreathConeWisps` (24) + `BodyVeinPulse` (12) = 36 emitting. Both under the 80-particle budget. Phase-3 enrage's 1.5× cone-wisp scaling pushes that breath-state concurrent to 36 + 12 = 48 — still within budget.

**HTML5 verification gate.** The breath-cone primitive + emitter set falls under `html5-visual-verification-gate.md` (CPUParticles2D + Tween + modulate). Drew's W3-T4 PR MUST include the Self-Test Report screenshot/video showing the breath cone rendering in HTML5 / Chromium per the M2 W1 PR #160 precedent. Memory rule: `html5-visual-verification-gate.md`.

---

## §3 — Phase-transition visual beats

### 66% / 33% HP transitions — reuse `boss-intro.md` Beat-T verbatim

Per `boss-intro.md` Beat-T (line 109-126):

- World time drops to 30% for 0.6s.
- Boss sprite gets a 1-frame ember-flash outline.
- `sfx-boss-phase-break` audio sting (acoustic cello tritone, 0.4s) — already wired into Devon's audio bus per `audio-direction.md` line 47.
- Nameplate phase-segment separator flashes ember-orange 0.3s; next segment's phase-label brightens.
- Boss plays a short tell animation (Drew's call, 0.4s max).

**Stoker-specific overlay on Beat-T:** during the 0.6s slow-mo window, the `PhaseTransitionFlare` emitter (30-particle one-shot burst, `#FF6A2A` → `#FFB066`) fires from the boss's body center. The flare reads as "the embergrave inside the boss surges." This is **the** beat that visually echoes the diegetic body-vein motif from §1.

### Stagger-immune slow-mo window (S1 precedent — load-bearing)

Per `Stratum1Boss.gd` line 144 + `.claude/docs/combat-architecture.md` line 136:

> **The boss is stagger-immune AND damage-immune during the phase-transition window.** The player can swing during the slow-mo, but hits are rejected with `IGNORED phase_transition ... (stagger-immune window)`.

Drew MUST preserve this contract for the Vault-Forged Stoker. Tess's paired-test for "damage-during-transition" (one of the 12 task-spec coverage points per `m2-week-3-backlog.md` §W3-T4 acceptance) verifies this rejection trace.

**Visual cue for the player:** during the slow-mo, the boss sprite gets a 1-frame ember-flash outline (Beat-T standard) AND the boss's body veins flare to peak brightness (`#FFB066` overlay at 60% alpha for the full 0.6s). Reads as "the boss is protected by its own veins right now — don't bother swinging."

### Enrage telegraph (phase-3 entry) — audio intersection point

The enrage state (8-frame, 0.8s, fires ONCE at phase-3 HP threshold crossing) is **the visual+audio crescendo moment**.

| T (s) | Visual | Audio (Devon wires) |
|---|---|---|
| T+0.0 | World time drops to 30% (standard Beat-T) | `sfx-boss-phase-break` plays (per `audio-direction.md` line 47) |
| T+0.0 | `PhaseTransitionFlare` 30-particle burst fires | — |
| T+0.0 → T+0.6 | Boss sprite frames 1-6: step back, vein-flare, step forward | `mus-boss-stratum2` first low-brass swell begins (per DECISIONS.md 2026-05-15 description "two low-brass swells at phase-break beats") |
| T+0.6 | World time resumes 100% (standard Beat-T exit) | Brass swell continues into combat resume |
| T+0.6 → T+0.8 | Frames 7-8: brightness-spike overlay 60% alpha, cone-widen visual confirmation (the breath-cone size hint flickers at full phase-3 scale for 1 frame at T+0.8) | Frame-drum tempo audibly increases from 50 BPM (BGM-style) to 80 BPM (boss-style enrage drive — per DECISIONS.md description) |

**Important: the visual brightness-spike at T+0.8 IS the audio crescendo peak.** Devon's `mus-boss-stratum2` cue has its first low-brass swell apex at ~T+0.8 from the enrage trigger. Visual+audio fire on the same `enter_phase_3()` state-entry callback. The audio cue and the visual frame are physics-flush-safe because both flow from the same `phase_changed` signal emission point on the boss controller (no Area2D mutation, no `add_child` mid-flush — see `combat-architecture.md` line 60).

### 33% HP enrage — phase-3 specifically (not the 66% transition)

To clarify across the docs: the boss has **3 phases**. The **enrage** sub-state fires once, at the **33% → phase-3 transition**, not at the 66% → phase-2 transition. Both transitions use the standard Beat-T cinematics; only the 33% transition gets the `enrage` animation state + cone-widening + audio crescendo. The 66% transition is a "again, but harder" beat (per `boss-intro.md` line 115); the 33% transition is the "this is the climax" beat.

---

## §4 — Boss intro entry sequence (1.8s, reuse Beat-1 to Beat-5)

**Reuse `boss-intro.md` Beat-1 to Beat-5 verbatim** with three Stoker-specific overrides. The reusable beat structure exists precisely so M2+ bosses don't re-author the intro logic — the override is the surgical-minimum delta.

### Beat-1 (T+0.0 → T+0.4 s) — Door slam — UNCHANGED

Per `boss-intro.md` line 17-21. Same iron-on-stone thud, same 1-frame ember-flash on lock-bar, same screen-shake. The audio cue (`door_slam_heavy.ogg`) and the lock-state sprite swap are cross-stratum constants.

### Beat-2 (T+0.0 → T+0.6 s) — Room darkens + ambient cuts — OVERRIDE: vein-flare + warm-red palette

Per `boss-intro.md` line 23-29, with three overrides for the Vault-Forged Stoker arena:

| Sub-beat | S1 (Warden) | Stoker (override) |
|---|---|---|
| Ambient cut | Stratum-1 ambient fades to 0% over 0.6s | **Stratum-2 ambient (`amb-stratum2-room`) fades to 0% over 0.6s** — same fade curve, different source cue (Devon wires per the existing `MusicBus` autoload pattern) |
| Vignette deepens | from S1's default 30% → 70% over 0.6s | **from S2's default 40% → 70% over 0.6s** — same target 70%, different starting point (steeper ramp because S2 vignette is already deeper) |
| Wall torches dim | Stratum-1 torches flicker once and drop to 60% brightness | **Wall veins FLARE** (anti-pattern from S1's torch-dim) — veins pulse to peak brightness `#FFB066` overlay for 0.3s, then settle to 80% of S2 default pulse brightness. Diegetic: the veins react to the boss waking up. The veins ARE the light source in the Vaults; they don't dim, they SURGE. |

**Why the vein-flare override matters narratively.** In the Cloister (S1), the torches dim because the human-tended fires can't compete with the boss's presence. In the Vaults (S2), the veins are the *boss's home substance* — they don't shrink from the boss, they recognize it. This is the same "your flame and the veins are the same substance" fiction from `palette-stratum-2.md` §1, applied to the boss reveal. Diegetic load-bearing for the S7-S8 progression.

### Beat-3 (T+0.6 → T+1.2 s) — Camera zoom + boss reveal — OVERRIDE: longer reveal because larger boss

Per `boss-intro.md` line 31-37, with one override:

- Camera zoom target stays at 1.25× (cross-stratum constant; don't break the playfield-readability budget).
- Camera ease-in duration: **0.7s** (vs S1's 0.6s) — the boss is 1.6× scale and needs an extra 0.1s for the player's eye to settle on the silhouette. Total intro lengthens from 1.8s to **1.9s**. Skip rule still applies (after first-boss-kill, skip available via movement key).
- Boss wake animation: **0.6s "unfurls" specifically** (vs S1's generic 0.5s wake) — the Vault-Forged Stoker rises from a hunched-corpse idle posture to upright fighting posture. The unfurl IS the reveal — the boss has been visible the whole approach to the door, but it's been hunched and silhouette-ambiguous; the unfurl is when the silhouette resolves to "boss."
- Boss-wake audio: `sfx-boss-aggro` (per `audio-direction.md` line 46) — same cue, same 0.6s, same brass+impact stinger. Re-uses the M1 cue (the cue is cross-stratum-compatible; only `mus-boss-stratum2` is unique).

### Beat-4 (T+1.2/T+1.3 → T+1.8/T+1.9 s) — Nameplate banner — UNCHANGED

Per `boss-intro.md` line 39-43. Same 480×56 nameplate, same anchored top-center, same 3-segment health bar. Substitute display name: **"VAULT-FORGED STOKER"** (sourced from `MobDef.display_name` per `boss-intro.md` line 82 contract). Threat label: `THREAT: ELITE` (M1 only tier still — `CHAMPION` reserved for later). Bell strike at T+1.4/T+1.5: same `sfx-bell-struck` sample (cross-stratum reuse — the bell is a global UI anchor per `audio-direction.md` line 61).

### Beat-5 (T+1.8/T+1.9 s onward) — Combat begins — UNCHANGED with audio swap

Per `boss-intro.md` line 45-48. Camera returns to player-anchored over 0.3s. **Boss music = `mus-boss-stratum2`** (NOT `mus-boss-stratum1`) — fades in over 0.6s. This is the audio handoff to Devon's W3-T9 audio sourcing close-out (PR #210 already on `main`); the cue file is at `audio/music/stratum2/mus-boss-stratum2.ogg`. Boss does NOT attack during Beats 1-4 (fairness for player who is reading the nameplate; cross-stratum constant per `boss-intro.md` line 47).

### Camera shake + vignette pulse — anchor on Beat-3 reveal

Per `boss-intro.md` line 18-19 (door-slam screen-shake) + line 28 (vignette deepens during Beat-2 → Beat-3). No Stoker-specific override; reuse the S1 shake amplitude (3 px, 0.15s decay) and the existing vignette tween path.

### Boss HP bar reveal timing — Beat-4 verbatim

Per `boss-intro.md` line 39-43. Nameplate slides down 0.4s, text types 0.3s, health bar fills left-to-right 0.4s. **Phase-segment health bar = 3 segments** (Stoker has 3 phases per W3-T4 scope, same as S1 boss). All segment treatment per `boss-intro.md` line 87-101 — cross-stratum constant.

---

## §5 — Loot drop visual

Per `boss-intro.md` Beat-F3 (line 146-153) — boss loot drops at the boss's last position with standard loot-drop audio + light-beam VFX from Drew's `Pickup.tscn`. The Vault-Forged Stoker drops **T3 weapon + T2/T3 gear** per `m2-week-3-backlog.md` §W3-T4 scope.

### T3 weapon drop visual treatment

T3 weapons get an **enhanced sparkle + warmer glow tint** vs T1/T2:

| Drop tier | Glow tint | Particle treatment | Light-beam |
|---|---|---|---|
| T1 | `#9C9590` (worn iron from `palette-stratum-2.md` §2) | 1 ember at 4 fps idle drift | Standard 24 px beam |
| T2 | `#D8B89A` (steam-vent emission from `palette-stratum-2.md` §2) | 2 embers at 6 fps idle drift | Standard 24 px beam |
| **T3 (the Stoker drop)** | **`#FF6A2A` (ember accent / vein-bright)** | **4 embers at 8 fps rising drift + 1 sparkle pulse every 1.5s** | **Enhanced 32 px beam at 50% increased modulate-alpha** |

**Why ember-orange T3 tint matters narratively.** T3 weapons from S2 boss are "vein-forged" — the boss's body veins infused the weapon. The drop visual carries the same `#FF6A2A` ember-accent through-line as the player flame + the vein cores. Diegetic continuation of the §1 body-vein motif.

**HTML5 safety:** all tints sub-1.0 per `.claude/docs/html5-export.md` § HDR clamp. The sparkle pulse modulate.a peaks at 0.9 (not 1.0). Light-beam is the existing `Pickup.tscn` primitive (already HTML5-verified per M1 RC); no new primitive class introduced.

### Stratum-exit unlock visual feedback

Per `boss-intro.md` Beat F3 line 152-153: the locked door behind the player unlocks with a soft chime + 1-frame ember-flash on its lock-bar. For the S2 boss arena, the unlocking door is the **stratum-exit door** (not just a chamber door) — the player can leave S2 now. This needs a slightly stronger "you can leave now" beat:

- Standard `sfx-door-unlock-chime` plays (cross-stratum reuse per `audio-direction.md` line 62).
- 1-frame ember-flash on lock-bar — UNCHANGED.
- **Stratum-exit-specific ADDITION:** a faint upward ember-trail rises from the door over 1.5s (8-particle CPUParticles2D, `#FF6A2A`, 0.4 alpha). Reads as "the path forward opens." Within the 80-particle budget (boss is dead, only this emitter + ambient `BodyVeinPulse` is active — wait, boss is dead so vein-pulse stopped; only this emitter is active. Cost: trivial.)
- Boss-defeated title card displays: **"The Vault-Forged Stoker falls."** + subtitle **"STRATUM 2 CLEARED"** per `boss-intro.md` Beat-F3 template (line 147-148). Both pulled from `MobDef.display_name` + a cross-stratum subtitle string-substitution pattern.

### Boss-defeated sequence — reuse Beat-F1 to Beat-F4 verbatim

Per `boss-intro.md` Beat F1-F4 (line 134-160). No Stoker-specific overrides. The `DeathDissolveEmbers` emitter (50-particle, 1.2s, retinted Cinder-Rust per §2) IS the Beat-F2 ember-rise. Boss music cuts hard at F1; `mus-victory-pad` plays at F4 (cross-stratum constant per `audio-direction.md` line 89).

---

## Acceptance + cross-references

Per ClickUp ticket `86c9uf86n` §Acceptance:

1. ✅ Doc lands on `main`.
2. ✅ Drew's W3-T4 dispatch can quote this doc directly as visual-direction source — specifically §1 (sprite anchors + sub-biome) + §2 (breath-cone primitive + geometry) + §3 (phase-transition + enrage beats) + §4 (intro overrides) + §5 (loot + exit-door feedback).
3. ✅ Cross-references intact:
   - `palette-stratum-2.md` §5 (sprite reuse) + §7 (tester pins) + §8 q1 (sub-biome resolution)
   - `boss-intro.md` Beat 1-5 + Beat-T + Beat F1-F4 (reused verbatim with three Stoker-specific Beat-2 overrides + one Beat-3 timing extension)
   - `audio-direction.md` § `mus-boss-stratum2` (row 88 — Beat-5 boss music handoff)
   - `.claude/docs/combat-architecture.md` § "Mob `_die` death pipeline" + § Stratum1Boss three-case rejection trace (Drew preserves the `IGNORED already_dead | IGNORED dormant | IGNORED phase_transition` pattern for the Vault-Forged Stoker)
   - `.claude/docs/html5-export.md` § HDR clamp + § Polygon2D quirks + § Z-index (constrains breath-cone primitive choice)
4. ✅ Honors DECISIONS.md 2026-05-15 — boss music is UNIQUE `mus-boss-stratum2`, not cross-stratum reuse. Visual narrative reinforces distinctness: body-vein motif, deepest-mine-seam sub-biome, vein-flare on Beat-2 (vs S1's torch-dim), enrage cone-widen visual cue intersects with the unique audio crescendo.
5. ✅ Sub-biome arena palette: **deepest-mine-seam (vein-saturated)** recommended with rationale (§1 sub-biome table + 5-point rationale). No Sponsor escalation required (on-spec per delegation).
6. See DECISIONS.md append below.

## DECISIONS.md append

One line per the ticket's acceptance #6 — sub-biome + breath-cone specifics locked.

---

## Open questions (for Sponsor / Priya — non-blocking)

1. **Vault-Forged Stoker display name lock.** Working name per backlog. Drew has authority to rename via `MobDef.display_name` per `boss-intro.md` line 218 precedent. Recommend: keep "VAULT-FORGED STOKER" — it carries the diegetic "the Vaults made this" load. Alternatives ("Heartseam Stoker", "Stoker Eternal") are weaker on the same axis.
2. **T3 weapon affix-pool for the drop.** Out-of-scope for visual direction; this is a Priya balance call. Recommend flagging as a follow-up ticket once W3-T4 stub ships — soak signal will inform.
3. **Cone-rectangle-vs-actual-cone primitive choice (§2).** Recommended the two-rect approach. Drew has implementation authority; the fallback single-rect is acceptable if Tess's HTML5 spot-check passes.

---

## Hand-off

- **Drew (W3-T4 state-machine + scene):** §1 sprite anchors + scale, §2 breath-cone primitive + geometry + colors + particle budget, §3 phase-transition states (preserve Stratum1Boss three-case rejection trace), §4 intro overrides on Beat-2 (vein-flare not torch-dim) + Beat-3 timing (+0.1s for larger silhouette), §5 loot drop tints. The doc IS the dispatch brief.
- **Devon (audio wiring):** §3 enrage audio-intersection (visual brightness-spike at T+0.8 fires WITH `mus-boss-stratum2` first brass swell apex) + §4 Beat-5 boss-music handoff (`mus-boss-stratum2` not `mus-boss-stratum1`).
- **Tess (paired tests + HTML5 verification):** §2 cone primitive HTML5-safety pattern (mirror `test_player_swing_flash_tint_is_html5_safe`), §3 stagger-immune rejection trace pattern (mirror Stratum1Boss `IGNORED phase_transition`), §4 nameplate display-name assertion (`MobDef.display_name == "VAULT-FORGED STOKER"`), Beat-F screenshot/video for the visual-verification gate.
- **Priya:** §1 sub-biome decision logged + Open question 2 (T3 affix-pool follow-up).
- **Sponsor:** none required; on-spec per delegation. Subjective soak signal at S2 boss kill: "does the boss feel distinct from the Warden in look and music, and does it feel like the Vaults specifically?" — same shape as `palette-stratum-2.md` §7 S2-PL-15.

---

## Non-obvious findings

- **The body-vein motif on the boss sprite is the load-bearing diegetic load** — without it, the Vault-Forged Stoker reads as "a bigger Stoker," not "the Vaults' champion." The motif also visually rhymes the player's flame with the boss's substance, which sets up S7-S8 fiction escalation. Costs Drew ONE additional sprite-anim layer (2-frame vein-pulse overlay on the body, same animation rig as the wall-vein tile pulse — full sprite reuse).
- **The `ColorRect` breath-cone primitive avoids a likely M1-class HTML5 visibility regression** preemptively. Polygon2D for a cone shape would be the "natural" choice from a desktop-Godot perspective; without this brief specifying the rotated-rect primitive, Drew could easily reach for Polygon2D and hit the PR #115/#122 cautionary tale. This is exactly the kind of risk the `html5-visual-verification-gate.md` memory rule was written to prevent.
- **The deepest-mine-seam sub-biome is implementable as a chunk-level TRES retint, not new sprite authoring.** The CanvasModulate + vignette + ambient-tint-alpha trio in §1 sub-biome table is three numerical adjustments to Devon's existing M2 W1 lighting plumbing — Drew authors ONE chunk override, no new Aseprite work. Cost-bounded.
- **The enrage visual-audio intersection is physics-flush-safe by design.** Both the visual brightness-spike (overlay modulate.a tween) and the audio crescendo cue (Devon's `AudioStreamPlayer.play()`) flow from the same `phase_changed.emit(3)` signal emission point on the boss controller's state-machine. Neither involves Area2D mutation or mid-flush `add_child`. The combat-architecture physics-flush rule does NOT trigger here; this is one of the few places where co-firing visual + audio is naturally safe.
- **`MobDef.display_name` is the cross-stratum string-substitution anchor** for boss-defeated title cards. Per `boss-intro.md` line 147 template "{MobDef.display_name} falls." — adding the Vault-Forged Stoker doesn't require new title-card code, just the new TRES. Free leverage from the M1 design.
