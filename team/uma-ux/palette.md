# Palette — Embergrave (M1 + 8-stratum forward plan)

**Owner:** Uma · **Phase:** M1 (stratum 1 authoritative; **stratum 2 authoritative — see `team/uma-ux/palette-stratum-2.md`**; strata 3–8 indicative refined).

A palette is only useful if every other role can paste a hex code without picking. This doc is that paste-board. All values are sRGB hex.

## Ember-orange — the through-line

| Use                       | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Ember accent (primary)    | `#FF6A2A` | The brand. UI accent, level-up glow, item drops, player flame. |
| Ember accent (mid)        | `#E04D14` | Hover/pressed state of ember UI.       |
| Ember accent (deep)       | `#A02E08` | Border / drop-shadow of ember UI.      |
| Ember light (highlight)   | `#FFB066` | Particle highlights, tiny pip flashes. |

The ember-orange ramp is constant across **all 8 strata**. It is the player's flame and never changes.

## Core neutrals (UI, fonts, panel chrome)

| Use                       | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Panel background          | `#1B1A1F` | At 92% opacity for inventory/death/run summary panels. |
| Panel border              | `#2F2A33` | 1 px rim under top ember-bar.          |
| HUD body text             | `#E8E4D6` | Off-white, 14 px default.              |
| HUD caption / hint        | `#B8AC8E` | Muted parchment, for hint copy.        |
| HUD disabled              | `#605C50` | Locked M2 stub slots, etc.             |
| Section header            | `#FF6A2A` | Small caps; ember.                     |
| Cell empty border         | `#3A3540` | At 40% opacity for empty inventory cells. |
| Cell hover border         | `#FF6A2A` | Ember at 100%.                         |
| Vignette                  | `#000000` | Dark overlay, 30% (S1) → 60% (S8).     |

## Status / state colors

| State                     | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| HP foreground             | `#D24A3C` | Warm red.                              |
| HP ghost (delayed damage) | `#F0A89B` | Pale red.                              |
| HP background empty       | `#2A262C` | Dark slate.                            |
| XP foreground             | `#E0B040` | Gold.                                  |
| Mob HP foreground         | `#7A2A26` | Dark red.                              |
| Mob HP background         | `#3A1614` | Deeper dark red.                       |
| Damage to mob (popup)     | `#FFFFFF` | Pure white.                            |
| Damage to player (popup)  | `#D24A3C` | Warm red.                              |
| Crit popup                | `#FF6A2A` | Ember.                                 |
| XP popup                  | `#E0B040` | Gold.                                  |
| Heal popup (M2+)          | `#7AC773` | Soft green; reserved.                  |

## Gear-tier ramp (used as borders, tier-strip, item-name in tooltip)

| Tier | Display name | Hex       | Notes                                |
|------|--------------|-----------|--------------------------------------|
| T1   | Worn         | `#C9C2B2` | Bone white.                          |
| T2   | Common       | `#B58657` | Warm bronze.                         |
| T3   | Fine         | `#5A8FB8` | Cold steel-blue.                     |
| T4   | Rare         | `#8B5BD4` | Royal violet.                        |
| T5   | Heroic       | `#E0B040` | Gold (same hex as XP — intentional: heroic gear feels XP-flavored). |
| T6   | Mythic       | `#FF6A2A` | Ember-orange — the highest tier matches the player's flame. |

These six are also used in the gear-drop **light-beam** particle when an item lands on the ground.

---

## Stratum 1 — Outer Cloister (M1 authoritative)

The only stratum that ships in M1. Every Drew tile and Devon prop must come from these hex codes.

### Environment ramp — sandstone

| Role                      | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Floor — base              | `#7A6A4F` | Warm sandstone.                        |
| Floor — deep              | `#5C4F38` | Cracks, recessed tiles.                |
| Floor — highlight         | `#A89677` | Lit edges, polished stones.            |
| Wall — base               | `#4A3F2E` | Heavy cloister stone.                  |
| Wall — moss accent        | `#5C7044` | Olive green moss; sparse use.          |
| Trim / pillar             | `#9A7A4E` | Bronzed trim around door arches.       |

### Environment accents — parchment + warm light

| Role                      | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Parchment / paper         | `#D7C68F` | Banners, scattered scrolls.            |
| Brazier flame core        | `#FFB066` | Inner flame.                           |
| Brazier flame outer       | `#FF6A2A` | Outer flame, sparks.                   |
| Brazier base              | `#2C261C` | Iron + soot.                           |
| Doorway ember-glow        | `#FF6A2A` | At 60% opacity, soft falloff.          |

### Mob accents — Stratum 1 grunt

| Role                      | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Grunt cloth               | `#5A4738` | Tattered brown.                        |
| Grunt skin                | `#A0856B` | Wash-out mid tone.                     |
| Grunt aggro eye-glow      | `#D24A3C` | Same as HP foreground.                 |
| Grunt weapon edge         | `#9C9590` | Worn iron.                             |

The aggro-eye-glow color is the **only** color a grunt has in common with the player-damage system. This is on purpose — when a mob's eyes go red, you know you're about to take that color of damage.

### Stratum 1 — anti-list (do NOT use in S1)

- Pure black (`#000000`) — too contrasty, breaks the "warm cloister" mood. Reserved for stratum 7-8.
- Cyan / turquoise — wrong stratum (those are S3 cool-teal + S7 cyan-glass per the indicative-refined arc).
- Bright purple — reserved for T4+ rare drops (sigil-violet `#7438AC` is reserved for S5 environment use only — distinct hex from tier-T4 `#8B5BD4`).
- White-hot ember (`#FFE6C0`) — reserved for S8 (the source).

---

## Stratum 2 — Cinder Vaults (M2 authoritative — see sibling doc)

**The full authoritative S2 palette + biome direction lives in `team/uma-ux/palette-stratum-2.md`** (PR #86, merged at `3e2f4e9`). That doc is the paste-board for every Drew tile, Devon prop, and mob in S2; this section is a stub that exists so the indicative-S3-S8 hue-rotation table below has a locked S2 anchor to rotate from.

Five-line summary (full detail in `palette-stratum-2.md`):

- **Biome:** Cinder Vaults — collapsed ember-ore mining tunnels under the Outer Cloister. Descent narrative: "humans worked here once; pressure and heat killed them."
- **Hue family:** warm-red (~5–15°) — rotated -30° from S1's warm-yellow (~35°) on every environment color.
- **Floor base:** `#3F1E1A` burnt earth · **Wall base:** `#2A1410` collapsed mining stone · **Vein mid:** `#C25A1F` ash-glow band (6 fps 8-frame pulse) · **Vein bright core:** `#FF6A2A` (reuses ember accent — diegetic: vein cores ARE the same substance as the player's flame).
- **Ember accent preserved:** YES, used identically to S1.
- **Daltonization-clear** against deuteranopia / protanopia / tritanopia.

---

## Strata 3–8 — directional palettes (indicative refined, not authoritative)

These are not buildable yet; they exist so M1+M2 don't accidentally use a color the team needs to differentiate later. Each stratum becomes authoritative when its content authoring starts in M3+ (own design ticket per stratum, modeled on `palette-stratum-2.md`). Until then this section locks: **biome name** + **hex codes** + **hue rotation from prior** + **ember-accent role** + **accessibility forecast** + **audio cousin** + **sprite-reuse hint**.

The descent narrative is **vertical journey through pressure / heat / depth / origin**, not a straight hue-line. The arc cycles through hue space — warm → red → cool reset → amber industrial → sickly organic → magma → cyan-on-black → ember-on-black — because a real descent has thermal layers (heat-zone, water-table, magma-shell, etc.), not a monotone fade.

### Hue rotation table (cumulative from S1 baseline ~35° warm-yellow)

Each adjacent step is **≥30° rotation** on the dominant environment-floor color from its predecessor. Cumulative direction is non-monotonic (the arc cycles).

| S | Biome (tentative)         | Dominant hue family        | Floor-base hex (indicative) | Hue Δ from prior | Notes                             |
|---|---------------------------|----------------------------|-----------------------------|------------------|-----------------------------------|
| 1 | Outer Cloister [LOCKED]   | warm sandstone (~35°)      | `#7A6A4F`                   | —                | M1 baseline                        |
| 2 | Cinder Vaults [LOCKED]    | warm red (~5–15°)          | `#3F1E1A`                   | -30° from S1     | M2 authoritative (`palette-stratum-2.md`) |
| 3 | Drowned Reliquary         | cool teal-blue (~195°)     | `#1F3438`                   | +190° from S2    | First cool reset — flooded crypt; hue inversion is a major visual reset (warm → cool). |
| 4 | Hollow Foundry            | amber industrial (~30°)    | `#2E2218`                   | -165° from S3    | Back to warm, lower value: industrial-heat-still-running, machines in the dark. |
| 5 | Bonemeal Reach            | sickly chartreuse (~80°)   | `#3A3A20`                   | +50° from S4     | First non-physical horror — wrongness via off-yellow + violet sigil. |
| 6 | Magmaroot Hollows         | magma red-orange (~12°)    | `#3A1208`                   | -68° from S5     | Root-sea / liquid-magma cavern; saturation rises sharply. |
| 7 | Ash Cathedral             | cyan-glass on black (~185°)| `#0F1418`                   | +173° from S6    | Hostile sharp; obsidian + cyan-glass; final cool counterpoint before the core. |
| 8 | Heart of Embergrave [LOCKED diegetically] | ember + true black (~10°) | `#0A0606`     | -175° from S7    | Almost-blinding; the source. |

Every adjacent pair satisfies ≥30°. The biggest hue cycles (S2→S3, S3→S4, S5→S6, S6→S7, S7→S8) are intentional thermal transitions ("you crossed a water table" / "you fell through a magma shell"). The pattern is rhythmic, not random — each cool stratum is followed by a warmer one, so the arc reads as **pulse, not drift**.

### Ember accent preservation — global lock

`#FF6A2A` ember accent (and its full ramp `#FFB066` → `#FF6A2A` → `#E04D14` → `#A02E08`) **stays identical across all 8 strata**. This is the project's diegetic through-line: the player's flame is the same substance as the embergrave seam at the world's core. As the player descends, the ember reads against ever-darker, ever-stranger biomes; what shifts is its *role in the scene composition*, not its hex code. Each stratum below documents how its biome reframes the ember.

The ember's brightness-on-page rises as strata darken (S1 floor brightness ~50% → S8 floor brightness ~5%), so the same hex reads progressively more luminous against the descending background. By S7-S8 the ember is the brightest pixel on screen by a wide margin — that's the climactic feel, accomplished by darkening *everything else*, not by changing the ember.

### Stratum 3 — Drowned Reliquary

**Reads as:** the cold introspection after the heat. The mining tunnels hit a water table; the seam that S2 was working through ran into groundwater, and below S2 the Vaults flood. This is the first stratum where the player is wading — water at ankle height, dripping from above, pooled in the recessed tiles. Sunken stone reliquaries (the pre-cloister monks buried their dead here, before the cloister was built) sit half-submerged, lichen-covered. The descent narrative beat is: "you've passed through the human industry layer; this is what was here before humans."

**Hue family:** cool teal-blue (~195°). Saturation low-mid; value runs darker than S1, comparable to S2.

- Floor — base: `#1F3438` waterlogged teal stone
- Floor — deep: `#0F1F22` submerged recess
- Wall — base: `#162328` flooded reliquary stone
- Accent — water surface highlight: `#5C8590` pale teal (catches the ember and warps it into a rippling reflection)
- Accent — moss / lichen: `#3F5040` dim aquatic green (NOT the S1 olive `#5C7044` — slightly bluer, slightly damper; differentiable by 12pp hue shift)
- Accent — bronze relic-leaf: `#7C5A30` (the Sunken Library aesthetic from the original indicative S2 entry survives here as bronze grave-goods inlay; weathered, oxidized darker than S2's `#A88E5E`)
- Mob accent — drowned cloth: `#2A4548` muted teal-grey
- Mob accent — pallid skin: `#7A8A88` waterlogged
- Mob aggro eye-glow: `#D24A3C` (cross-stratum constant, per PL-11)

**Ember role:** *submerged glow, reflected double.* The ember accent reads as a warm hot-spot against the cold teal — the player's flame casts orange ripples across the standing-water floor surfaces, doubling the ember's visual presence (real flame + reflection) and making the player feel like a moving lantern in a cave. The vein-core motif from S2 is GONE here (no embergrave seam runs through this stratum — the water severed it); the ember exists here only in the player + items + UI + drops, which makes the contrast sharpest and the ember its-most-valuable-resource.

**Accessibility forecast:** the close hue-pair to clear is **water-surface highlight `#5C8590` vs. mob pallid skin `#7A8A88`** — both pale teal, only ~6pp value gap and ~5° hue gap. **Pre-emptive disambiguator:** mobs always have a 1px dark outline (per `visual-direction.md` VD-13) and silhouette + motion (mobs walk, water surface ripples in place); the cloth `#2A4548` provides the dominant body-mass color, with the pallid skin only on hands+face. Daltonization risk specifically in tritanopia (blue-yellow axis collapse) — recommend a 4pp value bump on mob skin to `#869694` if S3 audit fails first try.

**Audio cousin:** submerged cello drone + occasional water-drip percussion + felted-piano single notes; the bronze bell is rarely struck here (the S3 reliquary bells are tarnished underwater, audio cousin = struck-but-muffled bell). Pairs with `audio-direction.md` dark-folk chamber by being **the most-restrained stratum musically** — water absorbs sound; the mix should feel airless.

**Sprite-reuse hint:** S1 sandstone tiles **cannot retint** to teal-stone (silhouette is wrong — the cloister joinery doesn't match flooded reliquary architecture); needs **NEW authoring**. S2 wall struts can be retinted as submerged stone columns (silhouette is similar; just shift `#4F2820` → `#162328`). Mobs: the S1 hooded-monk grunt silhouette **retints OK** here (drowned monks read as the same human silhouette, soaked) — first stratum since S1 where the hooded silhouette returns. Charger/Shooter retint OK.

### Stratum 4 — Hollow Foundry

**Reads as:** "industrial menace" — the original indicative S3 description. **Replaces the indicative "Foundry" S3 entry with a deeper-down setting:** below the flooded reliquary level, the rock dries out and the *machinery* begins. This is not the dead-infrastructure of S2 (Cinder Vaults); this is **machines that are still running, with no operators**. Ancient ember-driven forges that the pre-cloister civilization built directly into the rock; the bellows still pump; the molten channels still glow. Nobody is here to tend them. The descent narrative beat is: "you've gone beneath the humans, beneath the dead industry, and found something *older* that still works."

**Hue family:** amber industrial (~30°), low-value (deep). Saturation mid-high in the accent band.

- Floor — base: `#2E2218` dark forge soot
- Floor — channel-glow lit: `#5A3818` warm amber where molten channels light the floor
- Wall — base: `#1A1410` deep iron-shadow
- Wall — riveted iron plating: `#3F362C` warm-grey iron
- Accent — molten channel core: `#FF8B2A` amber-hot (one shade warmer than ember; reads as *industrial heat*, not player flame — see ember-role note)
- Accent — bellow-leather: `#5C3F2A` weathered tan
- Mob accent — Stoker (priya M2 backlog T6) cloth: `#5A2A18` heat-corroded smock
- Mob accent — Stoker iron mask: `#2C2620` blackened iron
- Mob aggro eye-glow: `#D24A3C` (cross-stratum constant)

**Ember role:** *kindred warmth, almost-camouflage.* The ember `#FF6A2A` reads as *one of many warm-orange light sources* in S4 — the molten channels (`#FF8B2A`) and the player flame (`#FF6A2A`) are 5° apart on the hue wheel. This is the FIRST stratum where the ember "blends in" with the environment. The diegetic logic: the ancient forge ran on the same substance the player is. The compositional logic: the player's flame stops being the brightest thing on screen — the molten channels are. This is unsettling on purpose ("the monsters down here are made of *what you're made of*") and sets up the S5 revulsion-pivot. **Disambiguator (critical):** ember stays mote-shaped + rises + attached-to-player/items/UI; molten channels are band-shaped + horizontal + fixed-in-floor. Same shape/motion/position rules that disambiguate ember from S2 ash-glow vein.

**Accessibility forecast:** the danger pair is **ember `#FF6A2A` vs. molten channel `#FF8B2A`** (5° hue gap, 13pp value gap). In all three daltonization sims this collapses partially in the hue axis — pass relies entirely on shape/motion/position. **Pre-emptive disambiguator:** the molten-channel sprite is a 4-frame slow-pulse anim flowing horizontally along floor seams; never appears as a discrete mote; never lifts above ground plane. **Recommended audit-pass insurance:** add a faint cyan rim-light `#5A8FB8` (matches T3 fine-tier) to player flame in S4 only — a 1-pixel cool counter-tone keeps the player ember readable against amber background. This is a stratum-specific player-shader tweak, not a hex change. **Pair-B risk:** Stoker cloth `#5A2A18` vs. floor base `#2E2218` (close warm-browns, 11pp value gap) — disambiguated by mob silhouette + outline + motion. Pass.

**Audio cousin:** frame-drum mechanical-pulse (the bellows' rhythm — the loudest, most-foregrounded percussion of any stratum), sustained low-cello drone, the bronze bell strikes harder here (struck-as-anvil in the audio mix, syncing to the bellow rhythm). Hurdy-gurdy drone returns from the dark-folk-chamber palette as the *machinery sound*. **Pairs with `audio-direction.md`** by leveraging the percussion-louder column without breaking the dark-folk-chamber discipline.

**Sprite-reuse hint:** S1 tiles **cannot retint** (cloister joinery is the wrong shape for forge-channel floors); **NEW authoring** for floor + wall + molten-channel tile anim. S2 iron struts **retint OK** as forge-frame iron-plating (similar silhouette, value bump). Mobs: Stoker is **NEW authoring** per Priya's M2 T6 ticket (already-scoped). Player: no change.

### Stratum 5 — Bonemeal Reach

**Reads as:** the wrongness layer — the original indicative S5 description. Beneath the working machinery is something organic and *off*. The rock here is shot through with veins of pale chitin and bone-marrow paste; the air is wrong in a way the player can't name; sigils carved into walls do not match any human script. This is the first stratum where the *biome itself is alive* — the floor flexes faintly under the player's feet, the walls have a respiratory pulse. The descent narrative beat is: "you've gone beneath the machines, beneath the dead, and found a place where the rock is meat."

**Hue family:** sickly chartreuse (~80°) with violet (~280°) sigil accents. Saturation mid-high; value mid (the brightest of the deep strata, intentionally — the wrongness reads as "lit by something you can't see").

- Floor — base: `#3A3A20` sickly olive-tan
- Floor — bone-vein: `#7A6F4D` (preserved from the original indicative entry — the jaundice-yellow vein reads *as* bone-meal)
- Wall — base: `#2A2820` bruised dim plum-tan
- Wall — chitin patch: `#4A3D40` desaturated plum (preserved from original indicative)
- Accent — jaundice highlight: `#C9B66A` (preserved from original indicative S5; this exact hex is the visual cue *for wrongness*)
- Accent — sigil violet: `#7438AC` (preserved from original indicative; reserved-violet — note this is DIFFERENT from tier-T4 `#8B5BD4`; saturation higher, value lower; diegetic-violet vs. tier-violet are deliberately separate hexes — see anti-list)
- Accent — bone-marrow paste (rare prop): `#D8C8A0` pale near-bone
- Mob accent — Reach-cultist cloth: `#5A4A3A` (re-uses S1 grunt cloth hex; the cult is *what S1's monks turned into* — diegetic continuity)
- Mob accent — chitin armor: `#7A6F4D` (matches bone-vein hex; the cultists wear the biome)
- Mob aggro eye-glow: `#D24A3C` (cross-stratum constant)

**Ember role:** *purifying contrast, anti-toxin.* The ember `#FF6A2A` is a strong warm hue against the sickly chartreuse environment — they're hue-axis opposites (~80° vs ~10°, ~70° gap), the highest hue-contrast pairing in the entire 8-stratum arc. The ember reads here as *clean fire against unclean ground*, the player's most-protective resource. Diegetic: the ember is what keeps the wrongness off the player. This stratum compositionally **maximizes ember legibility** — the ember is both the focal point and the ideological counter-claim of the scene. Item drops in S5 feel especially valuable for this reason.

**Accessibility forecast:** the audit-risk pair is **bone-vein `#7A6F4D` vs. chitin armor `#7A6F4D`** — they intentionally share a hex (diegetic: the cultists wear the biome), but they MUST differentiate as gameplay roles (background vs. mob). **Pre-emptive disambiguator (critical):** mob outline + animation (cultists move; bone-vein is static) + position (mobs are at character-height on the floor plane; bone-vein runs through wall + floor texture). The shared hex is a *style choice*, not an accessibility hazard — every player perceives the role difference via motion + outline + spatial position, regardless of color vision. **Pair-B risk:** sigil-violet `#7438AC` vs. tier-T4 `#8B5BD4` — both purples; 23° hue gap, 25pp saturation gap. Add to `palette.md` anti-list explicitly: **tier-T4 violet remains items-only**; sigil-violet is environment-only; never use the same hex for both. Confirmed: S5's `#7438AC` is in the anti-list as "do NOT use for tier borders" already in spirit — formalize when S5 becomes authoritative.

**Audio cousin:** felted-piano single-notes + bowed-cello high-register dissonance + frame-drum heartbeat that's slightly off-tempo (the wrongness audio analogue — if S2's heartbeat is a rhythm, S5's is a *misfiring* rhythm). The hurdy-gurdy drone is replaced here with a *de-tuned hurdy-gurdy* — quarter-tone-flat, deliberately-uncomfortable. Bronze bell muted. **Pairs with `audio-direction.md`** by using the chamber-instruments *wrong* — not by adding new instruments.

**Sprite-reuse hint:** S1 grunt sprite **retints OK** as Reach-cultist (the diegetic logic IS that they're former-S1-monks; same silhouette is desired). Charger/Shooter retint OK with chartreuse-tinted cloth. Floor + wall tiles: **NEW authoring** (the wrongness is silhouette-conveyed — the tiles need flex / breath / sigil-relief that doesn't exist on any S1/S2 tile). Bone-vein and chitin-patch are **NEW prop sprites** authored as wall-overlay decorations.

### Stratum 6 — Magmaroot Hollows

**Reads as:** the climactic descent layer — replaces the indicative "Glasswound" S6 (which moves to S7 with refinement; see S7). Below the bone-meat is **liquid rock**: a magma cavern threaded by root-like ember-veins thicker than tree-trunks. The "embergrave" name pays off here: this is where the player can SEE the network they've been descending through, the great branching root-system of seams that the S2 mining tunnels were tapping the surface of. The descent narrative beat is: "you have arrived at the *system* of the embergrave; the next stratum is its surface, the one after is its core."

**Hue family:** magma red-orange (~12°), high saturation, deep value. Saturation rises sharply vs. S5; this is the saturation-peak stratum.

- Floor — base: `#3A1208` charred magma-rock
- Floor — magma-pool surface: `#FF4818` near-pure magma red-orange (active surface; not walkable except via crossings)
- Floor — magma-pool depth: `#A02808` darker magma layer
- Wall — base: `#1F0A06` near-black with red bias
- Wall — root-vein body: `#8B2812` deep ember-root (the veins from S2 are now *trunks*; same diegetic substance, vastly thicker)
- Accent — root-vein bright core: `#FF6A2A` (reuses ember accent — same diegetic logic as S2 vein-cores, scaled up)
- Accent — heat-haze tint overlay: `#FF3812` at 10% multiply (deeper than S2's `#FF5A1A` 8%)
- Mob accent — Magmaroot creature cloth/hide: `#7A1208` deep magma-stained
- Mob accent — molten-skin glow: `#E04D14` ember-mid (mobs *bleed* ember-light here — they are partly the substance)
- Mob aggro eye-glow: `#D24A3C` (cross-stratum constant)

**Ember role:** *kindred but DOMINANT — the player's flame is now ONE of the seam-core hexes among many.* The ember `#FF6A2A` appears in: (a) the player flame, (b) the root-vein bright cores, (c) item drops, (d) mob bleed-glow (slightly hue-shifted to `#E04D14`). This is the inverse of S5's "purifying contrast" — here the ember is **environmental** as much as personal. Diegetically: the player has reached the source-system. The vignette is at 50% (per the `palette.md` 30%→60% ramp; S6 = 50%) which lets the saturated-warm midtones dominate the image. **The ember-spatial-disambiguation rules from S2 hold here harder than ever** — ember is mote/rises/attached-to-player; vein cores are band/fixed; mob bleed-glow is silhouette-shaped + attached-to-mob. Three distinct shape/position roles for visually-similar hex codes.

**Accessibility forecast:** S6 has the **most at-risk warm-on-warm pairs of any stratum.** Critical pairs:
1. ember `#FF6A2A` (player) vs. root-vein core `#FF6A2A` (environment) — IDENTICAL hex; disambiguated solely by shape + motion + attachment (per S2 §6).
2. magma-pool surface `#FF4818` vs. ember `#FF6A2A` — 6° hue, 8pp value. **At-risk in deuteranopia.** Disambiguator: magma-pool is a horizontal floor-plane area covering >1 tile; ember is mote-sized (≤8 px). Spatial-scale separates them.
3. mob molten-skin `#E04D14` vs. mob aggro eye `#D24A3C` — 9° hue, 7pp value. Both ON the mob silhouette. **At-risk in protanopia.** Disambiguator: aggro eye-glow is a 1-frame pulse + has the `D24A3C` HP-foreground hex (the cross-stratum aggro contract); molten-skin is sustained ambient mob-body lighting.

**Recommended pre-emptive measures (for when S6 audit lands):**
- Magma-pool surface gets a 1-frame-per-second bubble-particle anim in `#FFB066` highlights — adds motion + value-flicker that protanopia/deuteranopia readily see.
- Aggro eye-glow gains a 2-frame "pulse outward" anim specifically in S6 (other strata have a 1-frame static glow) — the *animation* becomes the telegraph signal, color secondary.
- Verify in tritanopia that the pair `#8B2812` root-vein body vs. `#7A1208` mob cloth (close warm-reds) doesn't collapse — likely needs a 6pp saturation differentiator. Logged as audit-risk to verify in S6 design ticket.

This stratum will REQUIRE the most-rigorous daltonization audit of any in the game. Surface this in the S6 design dispatch.

**Audio cousin:** sustained dual-cello drone (lower than S2/S4) + frame-drum *strike, no rhythm* (irregular tectonic punches) + occasional warm-horn (alphorn / low trombone) low-register sustained note (the warm-horn returns from the M1 boss-kill cue palette as the *sound of the source*). Bronze bell struck heavily here, 4–6 second tails. **Pairs with `audio-direction.md`** by leaning into the warm-horn tonal column that's so far been reserved for boss-kill flourishes — S6 is where the *world* is climactic, not just a fight.

**Sprite-reuse hint:** S2 root-vein wall-band anim is the **direct precursor** of S6 root-trunk wall sprite (same anim concept, scaled +200% larger; same hex codes). **Authoring leverage:** ship S6 walls as 3× scale of S2 vein anim with body-fill added. Floor: **NEW authoring** required for magma-pool surface (active anim) + crossings. Mobs: Magmaroot creature is **NEW authoring** (silhouette is a quadrupedal magma-quadrupedal that's never appeared); Charger could retint here as the magma-quadrupedal's smaller cousin. Player flame: no change (ember accent is unchanged).

### Stratum 7 — Ash Cathedral

**Reads as:** the final cool-counterpoint before the core — refined from the indicative "Glasswound" entry, repurposed deeper. Above the magma layer of S6, the heat *vents upward* and crystallizes against the underside of the embergrave's outer shell, building cathedral-scale structures of black volcanic glass and pale ash. This is a **vast vertical chamber** (the largest spatial-feel of any stratum), with the player navigating spires and obsidian buttresses. Hostile sharp; dangerous-beautiful. The descent narrative beat is: "you've punched through the magma roots; you're inside the structural shell of the embergrave itself; one more layer down is its core."

**Hue family:** cyan-glass on near-black (~185° accent against ~210° dark blue base). Highest contrast of any stratum (white-on-black-feel). Saturation extreme on accent, near-zero on field.

- Floor — base: `#0F1418` near-black with cool-blue bias (NOT pure black — that's reserved for S8)
- Floor — obsidian shard: `#161820` slightly lighter dark
- Wall — base: `#0A0E14` darker still
- Wall — ash-pale rim: `#3F4850` cool-grey-pale (where ash settles on horizontal surfaces)
- Accent — cyan-glass body: `#35C2D0` (preserved from original indicative — this is exactly the right hex for "cold cyan against true black")
- Accent — pale-cyan glass-shard: `#9CE3EA` (preserved from original indicative)
- Mob accent — Glassbearer cloth: `#1A2530` deep cool-blue (mobs are spatially camouflaged; reads as *part of the cathedral architecture* until they move)
- Mob accent — glass-rimmed body: `#5C7A88` cool-pale (the rimming reads as cold-light reflecting off polished obsidian)
- Mob aggro eye-glow: `#D24A3C` (cross-stratum constant — the warm red of the aggro eye is the **brightest non-ember warm** in this stratum, making mob telegraphing maximally legible against a near-monochrome cool field; this stratum showcases why the cross-stratum aggro contract matters)

**Ember role:** *single warm focal-point against monochrome cold — the most-cinematic ember-role of the arc.* The S7 environment has near-zero warm pixels. The ember `#FF6A2A` is the *only* warm hue on screen 95% of the time — it's the player, it's the items, it's the aggro telegraph. This is the stratum where the diegetic claim "the ember is the one warm thing in the deep" is most-literally true. Compositionally, S7 most-resembles **classic Hyper Light Drifter / Mike Mignola illustration logic** — saturated accent on a desaturated ground; single light source. The vignette is at 55% (per the 30%→60% ramp).

**Accessibility forecast:** S7 is the EASIEST stratum to clear for daltonization — pure cool field + pure warm accent has near-perfect value separation across all three deficiencies. Ember `#FF6A2A` (value 58%) vs. cyan-glass `#35C2D0` (value 51%) — close in value but opposite in hue, *and* the hue-axis collapse mostly affects red-green discrimination, not warm-vs-cool-temperature. **One audit-risk pair:** Glassbearer cloth `#1A2530` vs. wall-base `#0A0E14` — 9pp value gap, both very dark cool. **Pre-emptive disambiguator:** mob silhouette + 1px-dark outline (per VD-13) + walking motion + the glass-rimmed `#5C7A88` accent on mob body provides a high-value rim that breaks them off the wall. Pass.

**Audio cousin:** sustained cello drone + struck bronze bell with extremely-long reverb tail (the cathedral's literal acoustic) + sparse felted-piano + occasional sung-tone (the closest the audio direction gets to "voice" without breaking the no-synth/no-orchestral rule — a single hummed note from a voice timbre, hand-Foley'd; deferred to M3 unless cheap). The frame drum is silent here. **Pairs with `audio-direction.md`** by being **the most-spacious mix of any stratum** — the room reverb does the work the percussion does elsewhere.

**Sprite-reuse hint:** S2's iron struts and S6's root-veins do NOT retint to obsidian buttresses — silhouette is wholly different (jagged crystalline shards vs. cylindrical/banded). **NEW authoring** required for floor + wall + glass-buttress prop. Mobs: Glassbearer is **NEW authoring**. Charger could retint as a "glass-skinned" variant if the silhouette feels right — Drew's call when S7 lands. Player flame: no change.

### Stratum 8 — Heart of Embergrave (diegetically locked)

**Reads as:** the source. The core of the embergrave itself. The player has descended through cloister, mining tunnels, flooded reliquary, hollow forge, sickly bone-reach, magma-roots, ash-cathedral — and now stands inside the **chamber of the seam-source**: a near-spherical void where pure-white-hot ember-substance flows on near-true-black surfaces. The descent narrative *concludes* here. The biome is locked diegetically (this MUST be the source-of-the-ember reveal); the visual treatment of the chamber is the only design lever.

**Hue family:** ember on true black. Maximum value extremes (`#000000` to `#FFE6C0`). Saturation extreme on ember, zero on field.

- Floor — base: `#0A0606` near-black with 0.5pp red bias (NOT `#000000` — keep one ember-flicker hint)
- Floor — pure void: `#000000` true black (the only stratum where pure-black is permitted; reserved use)
- Wall — base: `#000000` true black
- Wall — ember-cracked seam: `#A02E08` ember-deep at the seam, `#FF6A2A` at seam-core
- Accent — white-hot ember (ember-source-luminance): `#FFE6C0` near-white (preserved from original indicative — this is THE climactic hex; appears nowhere else in the 8 strata)
- Accent — ember-mid: `#FFB066` (ember-light highlight)
- Accent — saturated ember: `#FF6A2A` (the constant)
- Mob accent — boss-rank mob cloth: `#1A0606` near-black-charred (M3 boss design when it lands)
- Mob accent — boss-rank ember-bleed: `#FF6A2A` (mobs at the source ARE made of the substance — full-saturation)
- Mob aggro eye-glow: `#D24A3C` (cross-stratum constant; in this monochrome-extreme field the warm-red of the aggro eye is **somewhere between** the ember and the floor — more disambiguated than ever)
- Boss-final eye-glow (override): `#FFE6C0` (white-hot — this is the ONE stratum-specific deviation from the cross-stratum aggro contract, reserved for the final-boss reveal moment; NOT for normal mobs)

**Ember role:** *the ember IS the world.* The player flame is no longer "the bright thing in the dark" — the world itself is now ember-lit. The ember accent's role completes its 8-stratum arc: from S1 brazier-flame-among-warm-stone (one warm thing among many warm things), to S7 cinematic-single-warm-on-cold (one warm thing among zero), to S8 ember-everywhere (the player and the world are revealed to be the same substance). This is the meaning the project name "Embergrave" pays off. Vignette at 60% (the ramp's terminal value).

**Accessibility forecast:** the value extremes (`#000000` ↔ `#FFE6C0`) make S8 trivially-clear in every daltonization sim — pure value contrast carries the entire visual language. **The one risk:** the boss-final eye-glow `#FFE6C0` vs. the white-hot ember `#FFE6C0` (same hex). Disambiguator: the boss-final eye-glow is on the boss silhouette + animated as a 4-frame pulse; the white-hot ember is environmental + sustained. Same shape/motion/position rules, terminal application. **Recommended pre-emptive measure:** the boss-final reveal sequence gets a pre-roll of 0.6s where ONLY the boss eyes glow `#FFE6C0` against `#000000` field (white-hot ember is suppressed in the seam during this beat) — establishes the eye-glow as a discrete signal before the field-ember returns. Choreographic disambiguator, not a hex change.

**Audio cousin:** the audio direction's **terminal aesthetic**: sustained warm-horn + bronze-bell-struck-with-extreme-tail + dual-cello drone in the lowest register the chamber-ensemble can produce. This is the closest to *cinematic* the audio direction gets, while staying inside dark-folk-chamber discipline. The frame-drum returns *only at the boss-fight*, with the heaviest strike of the whole soundtrack. The S8 ambient is *near silent* — the ember has no sound; the boss-fight will provide all the audio motion.

**Sprite-reuse hint:** essentially **NEW authoring across the board** — S8 has no S1/S2 silhouette analogues. Floor + wall + ember-seam decoration + final-boss arena are all bespoke. **Reuse opportunities:** the S6 root-vein anim is the *spec-precursor* for the S8 seam-cracks (same animation concept, but S8 cracks are sparser, more-deliberate, with a higher-saturation core hex `#FFE6C0` that doesn't exist in S6). The ember mote-particle shader from the player flame is reused identically (the player flame visually merges with the environment in S8 — that's the diegetic point). Final boss is its own design ticket; **biome-only design here**.

---

## Anti-list across S3–S8 (cumulative, for cross-stratum hex collisions)

When each stratum becomes authoritative, the per-stratum anti-list (modeled on `palette-stratum-2.md` §2 anti-list) needs these rules:

- **Tier-T4 violet `#8B5BD4`** — items only, every stratum. Never an environment color. (Particularly relevant in S5 where `#7438AC` sigil-violet is close-but-deliberately-different.)
- **White-hot ember `#FFE6C0`** — S8 only. Never appears in S1–S7. (S7 *almost* uses pale-cyan `#9CE3EA` as a near-white, but that's cool, not ember-luminance.)
- **Pure black `#000000`** — S7-S8 only. S1–S6 use deep-but-not-pure dark hexes (S6 floor `#1F0A06`, S7 floor `#0F1418`).
- **Ember accent `#FF6A2A`** — global through-line, never stratum-shifted. Never used as an environment color except as **vein-core / seam-core** at S2/S6/S8 (diegetic dual-role; spatial-disambiguation rules in §6 of `palette-stratum-2.md` apply).
- **Cross-stratum aggro eye-glow `#D24A3C`** — same hex on every mob in every stratum (PL-11). The S8 final-boss `#FFE6C0` override is the ONE exception.
- **HP-foreground `#D24A3C`, XP-gold `#E0B040`, panel-background `#1B1A1F`** — global UI hexes, never stratum-shifted.

## Cumulative ember-saturation arc (for compositional readers)

This documents the *role* the ember plays per stratum, summarized:

| S | Ember role                                         | Brightest non-ember pixel band |
|---|----------------------------------------------------|---------------------------------|
| 1 | Warm focal point among warm field (brazier-among-stone) | Floor highlight `#A89677`       |
| 2 | Warm focal point + diegetic vein cores (one of many warm things) | Vein mid `#C25A1F`         |
| 3 | Submerged glow + reflected double (singular warm against cold) | Water highlight `#5C8590`   |
| 4 | Kindred warmth, almost-camouflage (one warm among amber many) | Molten channel `#FF8B2A`   |
| 5 | Purifying contrast (singular clean warm against sickly chartreuse) | Jaundice highlight `#C9B66A` |
| 6 | Kindred but dominant (ember everywhere; root cores share the hex) | Magma-pool `#FF4818`     |
| 7 | Single warm focal-point on cold monochrome (the most-cinematic) | Pale-cyan glass `#9CE3EA`  |
| 8 | The world IS ember (player flame and environment merged) | White-hot ember `#FFE6C0`     |

The ember-saturation arc reads as: **focal → diegetic-shared → reflected → camouflaged → purifying → dominant → singular → universal.** This is the descent narrative encoded in compositional roles, not in hex codes.

---

## Color-blind & low-vision considerations

- **Tier rendering** never uses red-vs-green to differentiate. T1 bone-white, T2 bronze, T3 steel-blue gives high contrast for protan/deutan/tritan vision.
- **HP-loss feedback** is multi-channel: color (red), shape change (bar shrinks), motion (ghost-layer drain), audio (heart-thump < 33%), vignette (red pulse < 33%). A player who can't see red still gets the message.
- **Affixes in tooltip** use ember-orange (`#FF6A2A`), which is the most-saturated color in the palette and remains distinguishable across the three common color-blindness types.
- **Critical hits** use ember-orange + a `!` glyph. Color is not the only signal.
- **Settings menu (M2)** will offer a high-contrast UI mode that swaps panel background to `#000000` and bumps body text to pure white. M1 is dark-but-readable.

---

## Tester checklist (yes/no)

| ID    | Check                                                                                              | Pass criterion (yes/no) |
|-------|----------------------------------------------------------------------------------------------------|-------------------------|
| PL-01 | Every hex code referenced from `hud.md` appears in this file                                      | yes                     |
| PL-02 | Every hex code referenced from `inventory-stats-panel.md` appears in this file                    | yes                     |
| PL-03 | Stratum 1 floor color in-game matches `#7A6A4F` (eye-dropper a screenshot)                        | yes                     |
| PL-04 | Tier T1 border color in-game matches `#C9C2B2`                                                    | yes                     |
| PL-05 | Tier T6 border color in-game matches `#FF6A2A`                                                    | yes                     |
| PL-06 | HUD HP foreground color in-game matches `#D24A3C`                                                 | yes                     |
| PL-07 | XP popup color in-game matches `#E0B040`                                                          | yes                     |
| PL-08 | Crit popup color in-game matches `#FF6A2A` and includes a `!` glyph                               | yes                     |
| PL-09 | Stratum 1 contains zero pure-black (`#000000`) tiles in environment                               | yes                     |
| PL-10 | No environment pixel uses tier-T4 violet (`#8B5BD4`) — reserved for items only                    | yes                     |
| PL-11 | Mob aggro eye-glow color is the same `#D24A3C` as player HP foreground                            | yes                     |
| PL-12 | HP-loss feedback uses at least 4 channels (color, shape, motion, audio, vignette)                 | yes (audio in M1 stub OK)|
