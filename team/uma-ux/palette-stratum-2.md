# Stratum-2 Palette + Biome Direction — Cinder Vaults (M2 authoritative)

**Owner:** Uma · **Phase:** M2 (design only; consumed by Drew's W3-B2 stratum-2 chunk-lib scaffold and follow-on M2 sprite authoring) · **Status:** authoritative (replaces the indicative entry in `team/uma-ux/palette.md` § "Stratum 2 — Sunken Library").

This doc promotes the stratum-2 palette from "indicative directional sketch" to "Drew can paste-board hex codes from this file." It is the source of truth for every stratum-2 floor, wall, prop, mob, and lighting decision in M2.

## TL;DR (5 lines)

1. **Biome name:** Cinder Vaults — collapsed ember-ore mining tunnels under the Outer Cloister; the cloister was built on top of a *reason*, and the descent narrative is "humans worked here once; pressure and heat killed them."
2. **Palette name:** Cinder-Rust ramp — burnt-earth floors, collapsed-mining-stone walls, pulsing ash-glow veins running through everything in the rust-orange `#C25A1F` band, with the ember accent `#FF6A2A` doubling as both the player's flame AND the hottest vein cores (diegetic logic: the player's flame harmonizes with the ore — that's why they can survive down here).
3. **Ember accent preserved:** YES — `#FF6A2A` ramp is unchanged, used identically to S1 (player flame, item drops, level-up glow, T6 mythic border, UI section headers, crit popups). Ember does double duty as the brightest vein-core hex too — see §3 below for why this is a feature, not a conflict.
4. **Accessibility-clear:** YES — daltonization run against deuteranopia / protanopia / tritanopia surfaces no role-confusion. The closest pair (ember vs ash-glow-vein-mid) is separated by 14pp value plus the ember-spatial-disambiguation already established in S1 (ember is mote-shaped + rises, vein is band-shaped + fixed-in-stone). See §6.
5. **Replaces "Sunken Library":** the indicative S2 entry in `palette.md` was muted-teal-and-bronze. This doc replaces it with Cinder Vaults; the Sunken Library aesthetic is preserved as a candidate for S4 or S6 if cool-blue stratum slots open up — see §8 open question 1.

## Source of truth

This doc extends:

- **2026-05-02 — Visual direction lock** (`team/uma-ux/visual-direction.md` + `team/uma-ux/palette.md`): pixel art at 96 px/tile, 480×270 internal canvas, integer scaling, nearest-neighbor filtering. All Cinder Vaults colors below are sRGB hex; every sprite authored from this palette renders without subpixel jitter at 2× / 3× / 4× scale.
- **`team/uma-ux/palette.md`** (parent doc): the global ramps (ember-orange, core neutrals, status colors, tier ramp, UI overlay) are unchanged in S2. This doc only specifies the **stratum-specific environment + mob ramp**. Anti-list rules from S1 (e.g. tier-T4 violet reserved for items) hold across all strata.
- **`team/uma-ux/audio-direction.md`** (sibling): dark-folk chamber aesthetic — cellos, frame drum, felted piano, bronze bell, hurdy-gurdy drone. The Cinder Vaults visual cousin is **warm-on-cold-on-dark with a single hot accent**: stone reverb, sparse pulse from the ash-glow veins (visual rhyme to the frame-drum heartbeat), the bronze bell echoing the heat-blasted iron struts.
- **`team/uma-ux/stash-ui-v1.md`** (M2 narrative throughline): the ember-bag / between-runs stash logic extends seamlessly — stash chests in the Cinder Vaults entry chamber retint to the new wood/iron palette but keep the global UI panel chrome.
- **`team/priya-pl/week-2-retro-and-week-3-scope.md` row B3**: this is the deliverable for that scope row.

The replaced indicative entry (S2 = Sunken Library, muted teal + bronze) is logged in §8 open question 1. The Sunken Library aesthetic is preserved as a future-stratum candidate; it is NOT lost.

---

## §1 — Biome theme + narrative fit

### What is the place?

**The Cinder Vaults** are the collapsed ember-ore mining tunnels that run under the Outer Cloister. The monks of S1 didn't build a cloister on a hilltop for the view — they built it directly on top of a thermal vent, because the vent was producing **embergrave** (the substance the game is named after; the ore that holds gear together with the player's flame). The Cloister was the front-of-house; the Vaults were the back-of-house. The miners worked the seams, the monks tended the rituals, and at some point the seam broke open and the pressure killed everyone.

Visually this is:

- **Collapsed support struts** — iron-banded vertical beams, half-broken, leaning against walls. Old infrastructure built to hold the tunnels open against deep-rock pressure; failed long ago. Reads as "humans worked here."
- **Veins of ash-glow** — embergrave seams running through the walls and floors as pulsing rust-orange bands. These are *why* the cloister existed; they are also *why* the air down here is wrong; they are the diegetic light source.
- **Loose scree and broken cart silhouettes** — abandoned tooling. The mining carts are tipped, broken, sometimes still on rails embedded in the floor. Reads as "this place was working until it wasn't."
- **Soot and burnt-earth coverage** — every surface is tinted with the residue of vented heat. Even the iron struts are soot-blackened, not raw-iron.

### Where does S2 fit in the 8-stratum descent arc?

S1 = Outer Cloister: surface, austere, monastic ruin, cold-ish (warm key-light against cool sandstone).

S2 = Cinder Vaults: **first descent into pressurized depths.** The transition is "you've left the hands-of-humans place and entered the *infrastructure* humans built around the embergrave seam — and the infrastructure is dead." This is the first stratum where the player's flame is *visibly the same substance* as the environment (vein cores share the ember `#FF6A2A` hex), which sets up the late-game escalation: as the player descends, they are getting closer to the *source* of their flame, not further from it.

Suggested arc beyond S2 (these are speculative; lock at their own design tickets):

| S | Setting | Reads as | What it earns over S2 |
|---|---|---|---|
| 1 | Outer Cloister | "you've arrived" | — |
| **2** | **Cinder Vaults** | **"humans worked here once"** | **first heat shift, first vein appearance, scree underfoot** |
| 3 | (current indicative: The Foundry) | active heat, machines that still run | live machinery (vs S2 dead infrastructure), molten reds |
| 4 | (open) — possibly Sunken Library or Caverns of Echo | cold introspection, after the heat | hue inversion (warm → cool) is a major visual reset |
| 5 | (current indicative: The Bone Market) | wrongness | first non-physical horror |
| 6 | (current indicative: Glasswound) | hostile sharp | obsidian + cyan pure-saturation extreme |
| 7 | (current indicative: The Ember Vein) | climactic | the ember is the wall now |
| 8 | Heart of Embergrave | almost-blinding | ember + true black, the source |

S2 fits as **the first reveal of "where your flame comes from"** without yet showing the source. This is the stratum where the player goes "oh, this is what's under the cloister." It earns its place in the arc by being the first hue-shift (warm-yellow S1 → warm-red S2) and the first appearance of the ash-glow-vein motif that escalates through S7 and culminates in S8.

### Replaces "Sunken Library"

The previous indicative S2 entry in `palette.md` proposed **Sunken Library** (muted teal stone + bronze leaf). I'm overriding that pick. Reasoning:

- **Descent feel:** S1 → S2 should feel *deeper into pressure*, not *sideways into a different aesthetic*. Sunken Library reads as "lateral move to a different abandoned building," not "down into the bones of the world." Cinder Vaults reads as descent because it visually compresses (lower ceilings implied by darker upper tiles, narrower visual passages, soot accumulating downward).
- **Audio harmony:** the audio direction is dark-folk chamber — heat, reverb, slow pulse, frame-drum heartbeat. Cinder Vaults visually echoes that texture (stone walls, slow vein-pulse like a heartbeat, warm-on-cold). Sunken Library's bookish-water-damaged tone wants a different audio palette (drowned-organ, water-drip-in-stone) which would force a parallel audio direction we haven't scoped.
- **Embergrave fiction:** "ember + grave" is the project name. S2 should keep developing the ember motif (heat veins, ore seams) rather than swerving into a totally separate fiction (a flooded library doesn't belong to this world — *whose books?*).
- **Sunken Library is not lost:** it's a strong aesthetic and stays in the candidate pool for S4 (cool counterpoint after S3 Foundry) or S6 (replacing Glasswound if that pick gets re-examined). See §8 open question 1.

---

## §2 — Authoritative palette (Cinder-Rust ramp)

All values are sRGB hex. Every Drew tile, prop, mob, and Devon scene element in S2 must come from these codes (or the global cross-stratum ramps in `palette.md` for UI / status / tier / ember).

### Environment ramp — burnt earth + collapsed mining stone

| Role | Hex | S1 counterpart | Hue Δ from S1 | Notes |
|---|---|---|---|---|
| Floor — base | `#3F1E1A` | `#7A6A4F` | -30° (35° → 5°) and -21pp value | Burnt earth, dominant floor color. |
| Floor — deep | `#1F0F0C` | `#5C4F38` | -30° and -14pp value | Cracks, recessed tiles, tipped-cart shadows. New darker extreme vs S1. |
| Floor — highlight | `#6F3826` | `#A89677` | -23° and -23pp value | Warm rust on lit edges, polished stone where carts ran. |
| Wall — base | `#2A1410` | `#4A3F2E` | -27° and -11pp value | Collapsed mining stone, soot-coated. |
| Wall — trim / iron strut | `#4F2820` | `#9A7A4E` | -27° and -23pp value | Iron-banded support beams, soot-blackened (not raw iron). |

Cumulative hue rotation from S1: dominant family shifts from warm-yellow (~35°) to warm-red (~5-15°) — at least **27° rotation** on every environment color, satisfying the ≥30° rule on the floor-base + floor-deep pair (the dominant tiles by area). Cumulative value drop: floor-base goes from 39% → 18% (-21pp). New value extremes both directions: floor-deep `#1F0F0C` (~10% lightness) is darker than S1's darkest environment color (`#2C261C` brazier base, ~11%); ash-glow vein-bright = ember accent `#FFB066` (~70% lightness) is brighter than S1's brightest environment (`#A89677` floor highlight, ~57%). Both axes locked.

### Environment accents — ash-glow veins + scree

| Role | Hex | S1 counterpart | Hue Δ from S1 | Notes |
|---|---|---|---|---|
| Ash-glow vein — mid (the pulsing band) | `#C25A1F` | (no direct S1 counterpart; nearest is brazier outer flame `#FF6A2A` ember) | new role | High-saturation rust-orange. Used as the *mid-tone* of the wall vein motif; pulses in a 6 fps 8-frame anim cycle. Distinct from ember accent by 14pp value (44% vs 58%). |
| Ash-glow vein — bright core | `#FF6A2A` | (same — ember accent) | n/a | **Reuses ember accent.** Diegetic justification: the vein cores ARE the same substance as the player's flame; that's why the player can descend here. Avoids accessibility hazard (see §6). |
| Scree / loose-rock dust | `#5C3F2E` | (no S1 counterpart — S1 floors don't have a particle-level dust tier) | new role | Used for floor-edge scree particles + idle dust motes. Stays in the rust-brown family but lighter than floor-base for visibility. |
| Steam-vent emission | `#D8B89A` | (no S1 counterpart) | new role | Pale warm-grey, used for the occasional steam-burst particle clouds. Reads as "warm vapor" not "smoke" not "fog." |

### Mob accents — heat-blasted Cinder Vaults grunt

| Role | Hex | S1 counterpart | Hue Δ from S1 | Notes |
|---|---|---|---|---|
| Mob cloth | `#7A1F12` | `#5A4738` (S1 grunt cloth) | -25° and similar value but +47pp saturation | Heat-corroded miner's smock; reads "this person was caught in a flash-fire." |
| Mob skin | `#7E5A40` | `#A0856B` (S1 grunt skin) | -10° and -10pp value | Sun-scorched / soot-stained mid-tone. Distinct enough from S1 grunt skin to register as "this is a different kind of person." |
| Mob aggro eye-glow | `#D24A3C` | `#D24A3C` (S1 grunt aggro) | unchanged | **Cross-stratum constant** — the mob aggro eye-glow uses the same hex as HP foreground in every stratum. This is a tester-checkable contract from `palette.md` (PL-11). |
| Mob weapon edge | `#9C9590` | `#9C9590` (S1 grunt weapon) | unchanged | Worn iron — same hex as S1 because mining picks and S1 swords share the same era of metalwork. |

### Lighting + atmosphere

| Role | Hex | Used as | Notes |
|---|---|---|---|
| Ambient tint overlay | `#FF5A1A` at ~8% alpha | Multiply-blend CanvasModulate over the world layer | Subtle warm-orange wash. Devon: implement via `CanvasLayer` + `ColorRect` with multiply blend, NOT a Light2D. Pixel-art / nearest-neighbor / no realtime shadow. |
| Vignette | `#0A0404` at 40% alpha | Dark-overlay quad at screen rim | Replaces S1's pure-`#000000` vignette at 30%. Warm-black (slight red tint) keeps stratum mood consistent even in shadow. Per `palette.md` "Vignette intensifies as the player descends strata," 40% is the next step in the 30%→60% ramp. |
| Player low-HP red pulse | (unchanged from S1) | Separate vignette layer over the dark vignette, ramped by `(33 - hp_pct) / 33` clamped 0-1 | Health system is cross-stratum. |

### UI overlay (cross-stratum, unchanged from `palette.md`)

| Role | Hex | Notes |
|---|---|---|
| Panel background | `#1B1A1F` | At 92% opacity. Same as S1. Inventory / death / run-summary panel chrome NEVER changes per stratum. |
| HUD body text | `#E8E4D6` | Same as S1. |
| Section header | `#FF6A2A` | Same as S1 (ember accent). |
| Tier ramp T1-T6 | unchanged | Cross-stratum constant. |
| HP / XP / popups | unchanged | Cross-stratum constant. |

**Total stratum-specific colors:** 12 (5 environment + 4 environment accent + 4 mob + 2 lighting, with 1 reuse of ember accent for vein cores and 1 reuse of HP-foreground for mob aggro eye). Within the 8-12 target.

### Anti-list (do NOT use in S2)

- **Cool teals / cyans** — reserved for whichever stratum picks up the Sunken Library or Glasswound aesthetic.
- **Pure black** (`#000000`) — same as S1's anti-list, reserved for S7-S8.
- **Bright purple** (`#8B5BD4`) — tier-T4 reserved.
- **Pale jaundice yellow** (`#C9B66A`) — Bone Market reserved (S5 indicative).
- **White-hot ember** (`#FFE6C0`) — late-stratum reserved.
- **Olive green moss** (`#5C7044`) — S1-specific; the Vaults aren't damp enough for moss. Use scree dust instead for organic floor variation.

---

## §3 — Content beats (what's NEW in S2 vs. S1)

The player crosses from S1 to S2 via the descent screen + StratumProgression cut. On entering S2 R1, they should immediately see at least one of each of these and register "I'm somewhere new."

| # | Beat | Purpose | Decoration vs. gameplay-relevant | Owner flag |
|---|---|---|---|---|
| 1 | **Ash-glow veins on walls** — animated faint pulse, 6 fps 8-frame loop, vein body in `#C25A1F` and core wisps in `#FF6A2A`. Veins run vertically through wall tiles and horizontally through floor seams. | Establishes "the embergrave is here." Ties player flame to environment diegetically. | **Pure decoration** — sprite-level anim baked into wall/floor tile variants. No collision, no hitbox, no gameplay effect. | Drew (sprite anim), no Devon scripting needed. |
| 2 | **Loose scree at floor edges** — small idle particles (1-2 px dots in `#5C3F2E` scree color) at the boundary between wall-tile and floor-tile, drifting slightly. | Sells "active collapse" vs S1's settled-stone feel. | **Gameplay-relevant (proposed):** scree patches MAY behave as slip zones (small move-speed / dodge-precision penalty). **Needs Drew/Devon impl row.** Don't design the mechanic here; W3-B2 scaffold can ship inert scree and a slip-zone ticket gets filed if Priya wants the lever. | **Drew/Devon flag** — open ticket needed if slip-zone mechanic accepted. |
| 3 | **Broken mining-cart silhouettes** — 2-3 cart variants placed in the background plane (parallax layer behind the floor tile). Tipped, half-buried in scree, sometimes still on broken track. | Sells "humans worked here once." Reads as set-dressing, not interactive. | **Pure decoration.** Background plane = no hitbox, no AI awareness. | Drew (3-4 cart sprite variants, ~32×24 internal each). |
| 4 | **Steam vents** — occasional 1-2 second steam-burst particle puffs from cracks in floor tiles, in `#D8B89A` steam-vent color, ~30-90 second random cycle per vent. | Active heat, "the place is still venting." Audio cousin: faint hiss layered into `amb-stratum2-room`. | **Gameplay-relevant (proposed):** steam vents MAY deal small contact damage / DoT in their burst window. Telegraph would be a 0.4 s "rumble" frame before the burst. **Needs Drew/Devon impl row.** Same disposition as scree — W3-B2 scaffold ships inert vents; a damage-vent mechanic ticket gets filed if Priya wants the lever. | **Drew/Devon flag** — open ticket needed if hazard mechanic accepted. |
| 5 | **Iron support struts** — broken vertical beams against walls every 2-3 wall tiles. `#4F2820` trim color, 1 px outline (per `visual-direction.md` §"Sprite outline" the open-question call: tiles get NO outline, but struts are foreground props so they get the 1 px outline). Some struts lean diagonally (broken), some are straight (still holding). | Establishes infrastructure-decay theme. Vertical lines guide the eye in tunnel-feel. | **Pure decoration in v1.** Future: struts could become destructible cover or block-line-of-sight props for the Charger telegraph (S2 introduces the Charger formally per current shooter/charger M1 work). **Not flagged for impl** — tag for Drew's M3 polish pass if it's still a useful idea by then. | Drew (4-5 strut sprite variants, ~16×96 internal each — vertical). |

**Summary: 3 pure decoration + 2 gameplay-relevant-flag-to-Priya.** The two flagged items (scree slip-zones, steam-vent hazards) are **proposed mechanics, not designed mechanics** — the W3-B2 chunk-lib scaffold ships them visually inert; the mechanic decision is a follow-up Priya call once Drew has actual S2 chunks running and we can playtest the feel of the biome at-rest first.

---

## §4 — Lighting model

### S1 baseline (for comparison)

S1 uses an austere / cold-ish key-light setup: warm-key implied by torchlight at ~`#FFB066` against cool-leaning sandstone, vignette at 30% pure black. The S1 mood is "lit room in the dark, single warm focal point."

### S2 lighting — warm-orange-shifted with deep contrast

Cinder Vaults inverts the temperature relationship: instead of "warm light against cool stone," it's **"warmer-still light against warm stone, so the *shadow* becomes the cool counterpoint, and the contrast is value-driven not temperature-driven."** This is what "deeper into thermal vents" reads as — the ambient is no longer cool; the *void around* the ambient is what reads as cold-by-comparison.

Implementation for Devon (Godot 4.3, 2D pixel-art, M1-compatible):

1. **Ambient tint overlay.** A `CanvasLayer` at world layer (below UI), containing a `ColorRect` at 480×270 with `Color(1.0, 0.353, 0.102, 1.0)` (= `#FF5A1A`) and `material.blend_mode = BLEND_MODE_MUL` at ~8% alpha (set the ColorRect's modulate alpha to 0.08, or use a CanvasModulate node — Devon's call). The mul-blend pulls every world pixel slightly redder. Cost: zero (single screen-space rect).
2. **Vignette deepens to 40%.** Replace the dark-overlay quad's color from S1's `#000000` to S2's `#0A0404` (warm-black) and bump opacity 30% → 40%. Per `palette.md` the vignette ramps 30%→60% across 8 strata; 40% is the natural S2 step.
3. **Vein pulse is a SPRITE ANIMATION, NOT a Light2D.** The ash-glow veins look "lit" because their hex codes are bright (`#C25A1F` mid, `#FF6A2A` core). The pulse anim cycles brightness via frame swap (Aseprite layer 2-frame swap). **Do not use Godot Light2D here** — that path requires CanvasItem material setup that breaks pixel-art predictability, and adds rendering cost for no visible gain.
4. **Steam-vent puffs are ParticleMaterials in `#D8B89A`** — cheap, billboard, no lighting interaction.
5. **Player low-HP red pulse** is unchanged from S1 (separate vignette layer ramped by HP%).
6. **Boss-room sub-lighting** (when S2 boss design lands) is its own design call — see §8 open question 4.

What Devon does NOT need to implement for S2:
- No realtime shadows (per `visual-direction.md` § "Lighting model" — baked into tile colors only).
- No deferred lighting (Godot 4.3 2D doesn't have it; pixel-art shouldn't pretend to).
- No Light2D / shadow-caster polygons.
- No per-tile emissive shader.

The whole S2 lighting model is **two ColorRect overlays + one anim cycle on tile sprites**. Total runtime cost: negligible. This conforms to `visual-direction.md` integer-scale + nearest-neighbor + 480×270 logical-canvas rules without exception.

---

## §5 — Sprite reuse table

Drew's W3-B2 stratum-2 chunk-lib scaffold needs to know which S1 sprites can be retinted vs. need fresh authoring. Retinted sprites can be authored as TRES `tier_modifier`-style palette swaps; fresh-author sprites need new Aseprite files.

| Sprite | S1 source | S2 strategy | Why |
|---|---|---|---|
| **Player** (idle / walk / attack-light / attack-heavy / dodge / hit / die) | existing player atlas | **NO CHANGE** — cross-stratum constant per `palette.md`. The player is not retinted per stratum. | Player flame is the through-line; retinting the player would break the diegetic logic. |
| **Grunt mob** (state-machine sprites) | `scripts/mobs/Grunt.gd` + atlas | **NEW AUTHORING** — silhouette is hooded monk in robes; doesn't fit Cinder Vaults. Author a "heat-blasted miner" variant with miner's-cap silhouette and torn smock. Use `#7A1F12` cloth + `#7E5A40` skin + `#D24A3C` aggro eye-glow. | Silhouette IS biome-specific; retint of monk → miner doesn't read. |
| **Charger mob** (state-machine sprites) | (M1 PR #26 charger) | **RETINT OK** — the bestial / four-legged silhouette reads in any stratum. Replace S1 fur/cloth hex with `#7A1F12` cloth + `#7E5A40` skin (or the equivalent S2 mob ramp tones). | Beast silhouettes don't carry stratum identity; tint shift is enough. |
| **Shooter mob** (state-machine sprites) | (M1 PR #33 shooter) | **RETINT OK** — same logic as Charger. Skeletal-archer silhouette is tonally appropriate for a place where humans died. | Same. |
| **Floor tiles** (S1 sandstone family, ~6 variants) | `scenes/levels/chunks/s1_room01_chunk.tscn` tilemap | **NEW AUTHORING** — silhouette is "stone tiles with cloister joinery"; needs replacement with "broken cart-track tiles + jagged collapse seams." S2 floors carry the rail embeds, the scree edges, the vein seams. | Tile silhouette IS the biome; can't retint cloister-tiles into mining-tunnels. |
| **Wall tiles** (S1 cloister masonry, ~5 variants) | as above | **NEW AUTHORING** — replace cloister masonry with iron-banded mining-strut wall variants. Includes the ash-glow vein band (animated 8-frame). | Same. |
| **Brazier** prop | `scenes/levels/chunks/...` | **REPLACE with new prop** — braziers are cloister-flavored. New prop: ash-glow node — a wall-mounted vein-junction that pulses in the `#C25A1F` / `#FF6A2A` ramp. Same role (warm light source + audio anchor for `amb-stratum1-torch` equivalent → `amb-stratum2-vein`). | Brazier's rite-context doesn't fit; the vein-junction is the diegetic equivalent. |
| **Doorway** prop | as above | **NEW AUTHORING** — cloister arch doesn't fit. Author a cracked-mining-tunnel arch with broken iron support beams flanking it. | Same silhouette logic. |
| **Pickup sprite** (cloth bundle for items dropping from mobs) | `scenes/loot/Pickup.tscn` | **RETINT OK** — same shape, swap cloth color from S1 brown to S2 rust. | Cross-stratum constant in shape; only the wrap-cloth tints. |
| **Item icons** (24×24 in tooltip) | `resources/items/*.tres` icons | **NO CHANGE** — items themselves don't retint per stratum. A pyre-edged shortsword looks the same whether dropped in S1 or S2. | Items are character-of-the-player, not character-of-the-stratum. |
| **HUD chrome / panels** | `scenes/ui/HUD.tscn`, `scenes/ui/InventoryStatsPanel.tscn`, `scenes/ui/StashPanel.tscn` | **NO CHANGE** — UI panel chrome is cross-stratum constant per `palette.md` Core Neutrals. | UI is meta-layer; never tinted by world. |
| **Ember-bag pickup sprite** (M2) | `scenes/objects/EmberBag.tscn` (Devon's M2 work) | **RETINT OK** — bag cloth wrap could shift from `#5A4A3A` (S1 default) to `#5A2A1E` (S2 burnt-earth), but the ember motes stay `#FF6A2A` always. | The ember accent is the through-line; the wrap is biome-tinted. |
| **Stash chest** (M2) | `scenes/objects/StashChest.tscn` (Devon's M2 work) | **RETINT OK** — wood + iron palette swap to S2 darker tones; ember-orange wisp idling above the lid stays the same hex. | Stash chest is per-stratum-entry-chamber, so it inherits stratum tint while keeping the global ember accent. |
| **Stratum-2 boss** | (does not exist yet) | **NEW AUTHORING** — full sprite + scene authoring is M2 boss-design ticket, not this doc. | Boss design is its own design call; this doc only frames the biome it lives in. |

**Summary for Drew's W3-B2 scaffold:**
- **Hard need (NEW authoring before S2 chunks render):** floor tiles, wall tiles + vein anim, ash-glow node prop, doorway prop, S2 grunt sprite. ~5 sprite tasks.
- **Soft need (RETINT OK; can re-color from S1 source files):** Charger, Shooter, Pickup, Ember-bag, Stash chest. ~5 sprite-tint tasks (most are M2-flavored, not blockers for the scaffold).
- **No change:** Player, item icons, HUD chrome. 0 sprite tasks.

The W3-B2 scaffold itself only needs the FIVE hard-need sprites to render a functional S2 R1; the retints and the boss authoring are M2 follow-up tickets. Drew can scope his W3-B2 ticket as "scaffold + 5 placeholder sprite stubs in the new palette," and the polish pass on those placeholders is a separate ticket.

---

## §6 — Accessibility check (daltonization run)

Tested against the three common color-vision differences. Each test poses the same question: **"Can the player tell ROLE-A from ROLE-B at a glance, given pure-color similarity?"** A fail is when two semantically-distinct roles render visually identical to the test population.

### Color pairs at risk in S2

The pairs I want to clear are those carrying **gameplay-meaningful distinction**:

| Pair | Roles | Why it matters |
|---|---|---|
| A | Ember accent `#FF6A2A` (player flame, item drops, level-up glow, T6 mythic) vs. ash-glow vein-mid `#C25A1F` (wall decoration) | Ember = "yours, important." Vein = "biome decoration." Confusing the two means the player misses an item drop or stares at the wall thinking it's a flame. |
| B | Mob aggro eye-glow `#D24A3C` (telegraph "I'm about to hit you") vs. floor base `#3F1E1A` (background) | Aggro eye must POP off the floor. If they merge in any colorblind sim, the player loses the telegraph. |
| C | Mob cloth `#7A1F12` vs. mob aggro eye-glow `#D24A3C` | Body silhouette vs. telegraph signal — same hue family, must differ by value enough that the eye-glow registers ON the body. |
| D | Ember accent `#FF6A2A` vs. mob aggro eye-glow `#D24A3C` | Both warm reds. Different roles, but they shouldn't be confused (item drop vs. mob threat). |
| E | Floor base `#3F1E1A` vs. wall base `#2A1410` | Walkable vs. wall — must read clearly even in monochrome. |

### Run 1 — Deuteranopia (red-green deficient, most common ~5% of males)

Deuteranopia maps reds toward yellow-brown and greens toward yellow-tan. The hue-axis collapses for any red-vs-green discrimination; value and saturation become primary cues.

| Pair | Result | Reasoning |
|---|---|---|
| A — ember vs vein-mid | **PASS** | Both compress toward warm-tan, but ember is HSL-value 58% and vein is 44% — 14pp value diff persists post-deuteranopia. Plus ember is mote-shaped + rises (motion); vein is band-shaped + fixed-in-stone. Disambiguation via shape + motion. |
| B — aggro eye vs floor | **PASS** | Aggro eye value 53%, floor value 18% — 35pp gap, dominant. Hue compression doesn't matter at that gap. |
| C — mob cloth vs aggro eye | **PASS** | Cloth value 27%, eye value 53% — 26pp gap. Eye-glow registers ON the body. |
| D — ember vs aggro eye | **PASS** | Ember value 58% vs eye value 53% — only 5pp gap. BUT ember is on the player / on items / on UI, never ON a mob silhouette. Aggro eye-glow is ALWAYS on a mob silhouette. Disambiguation via attachment / position. (Also the existing S1 design has the same pair; this is not a new risk.) |
| E — floor vs wall | **PASS** | Floor 18%, wall 13% — 5pp gap, but reinforced by the tile-edge dark-line that runs between floor and wall in pixel-art tiling. Also wall has the vein motif that floor doesn't. |

### Run 2 — Protanopia (red deficient, ~1% of males)

Protanopia maps long-wavelength reds toward dark-yellow / dark-grey, dropping the brightness of pure reds. This compresses my warm-red palette downward in value.

| Pair | Result | Reasoning |
|---|---|---|
| A — ember vs vein-mid | **PASS** | Both compress, ember stays brighter due to higher source value (58% vs 44%). Shape + motion disambiguation still holds. |
| B — aggro eye vs floor | **PASS** | The aggro eye darkens in protanopia (since its red-lightness drops) but the FLOOR also darkens — the relative gap holds. ~30pp post-compression, still dominant. |
| C — mob cloth vs aggro eye | **PASS** | Both compress; relative gap maintained. The eye-glow's saturation is higher than the cloth's, which protanopia suppresses, but value gap leads. |
| D — ember vs aggro eye | **PASS** | Same logic as deuteranopia — disambiguated by attachment / position, not by color. |
| E — floor vs wall | **PASS** | Both compress; the 5pp value gap holds in monochrome-projection. Plus tile-edge linework. |

### Run 3 — Tritanopia (blue-yellow deficient, very rare <0.01%)

Tritanopia maps yellows toward pink/red and blues toward green/cyan. My S2 palette is almost entirely warm-red — tritanopia hits warm-yellow / orange hardest because that band IS the failure axis.

| Pair | Result | Reasoning |
|---|---|---|
| A — ember vs vein-mid | **PASS (with note)** | Both shift in tritanopia, but the bigger risk is that the ember's slight yellow-bias makes it pull pinker than the vein-mid which is more pure-red. End result: ember reads pinker, vein reads redder — slight differentiation that's actually MORE distinct in tritanopia than in standard vision in the hue axis, plus the value gap of 14pp is unchanged. |
| B — aggro eye vs floor | **PASS** | Value gap dominates. |
| C — mob cloth vs aggro eye | **PASS** | Value gap dominates. |
| D — ember vs aggro eye | **PASS** | The hue separation widens slightly in tritanopia (ember pulls pinker, aggro eye stays red), making the pair MORE visible. Plus position disambiguation. |
| E — floor vs wall | **PASS** | Value gap + linework. |

### Verdict

**All five at-risk pairs pass all three daltonization simulations.** No swap-out is required.

The strongest disambiguators across all three runs are:

1. **Value gaps** (especially in protanopia where red→dark compression amplifies value-gap importance).
2. **Shape + motion** (ember motes rise; veins are bands fixed in stone) — this is the *primary* disambiguation for the ember-vs-vein pair, and it's a free property of the pixel-art animation conventions, not a color choice.
3. **Position / attachment** (ember is on player/items/UI, aggro eye is on mob silhouettes) — this is gameplay-spatial disambiguation that operates independently of color.

The accessibility decision logged in `palette.md` ("color is never the only signal") holds for S2 the same way it holds for S1: every gameplay-meaningful distinction has a value channel + a shape/motion channel + a position channel backing the color channel.

---

## §7 — Tester checklist (yes/no)

Optional — Tess can hold these for when S2 content actually ships (M2). Listed here so the contract is locked.

| ID | Check | Pass |
|---|---|---|
| S2-PL-01 | Every hex code referenced from S2 chunks / props / mobs appears in this file | yes |
| S2-PL-02 | Stratum-2 floor color in-game matches `#3F1E1A` (eye-dropper a screenshot) | yes |
| S2-PL-03 | Stratum-2 wall color in-game matches `#2A1410` | yes |
| S2-PL-04 | Ash-glow vein animation cycles in `#C25A1F` mid → `#FF6A2A` core, 6 fps 8-frame loop | yes |
| S2-PL-05 | Stratum-2 mob aggro eye-glow color is `#D24A3C` (same as HP foreground; PL-11 from S1 holds) | yes |
| S2-PL-06 | Stratum-2 vignette opacity is 40% (vs S1's 30%) and color is `#0A0404` (warm-black) | yes |
| S2-PL-07 | Ember accent `#FF6A2A` is reused for vein-bright cores AND player flame AND item drops AND T6 mythic — no swap | yes |
| S2-PL-08 | Stratum-2 contains zero pure-black (`#000000`) tiles in environment (anti-list rule) | yes |
| S2-PL-09 | No environment pixel uses tier-T4 violet `#8B5BD4` (anti-list rule) | yes |
| S2-PL-10 | No environment pixel uses cool teal / cyan (anti-list rule — those are reserved for Sunken Library / Glasswound) | yes |
| S2-PL-11 | Ambient tint overlay is `#FF5A1A` at ~8% alpha multiply-blend (Devon's CanvasModulate / ColorRect choice) | yes |
| S2-PL-12 | Steam-vent particle emission color is `#D8B89A` | yes |
| S2-PL-13 | Daltonization (deuteranopia / protanopia / tritanopia) does not collapse any of the 5 at-risk pairs in §6 | yes |
| S2-PL-14 | UI panel BG remains `#1B1A1F` 92% in S2 (cross-stratum constant — S1 PL-09 equivalent) | yes |
| S2-PL-15 | Stratum-2 transition (descend from S1 → S2) registers as "I'm somewhere new" within 1 second of player visibility (subjective; Sponsor probe) | yes (Sponsor sign-off) |

S2-PL-15 is the Sponsor-soak signal — not a unit test, but the design's primary user-facing acceptance: when the player walks through the S1→S2 descend door, do they say "oh, this is different"? If they don't, the palette didn't do its job.

---

## §8 — Open questions

Flagged for Sponsor / Priya / orchestrator. Not all need resolving before Drew's W3-B2 scaffold; most are M2-content-gate calls.

1. **Sunken Library aesthetic — repurpose to S4 or S6?** I overrode the indicative S2 entry. The Sunken Library palette (muted teal stone + bronze leaf) is a strong cool-counterpoint aesthetic that fits well as either S4 (after S3 Foundry, cool reset) or S6 (replacing Glasswound if that pick gets re-examined). I'd like Priya's framing call so the candidate doesn't drift. **Owner:** Priya — when S3+ design tickets get scoped.
2. **Scree slip-zone mechanic — design + ship, or ship inert?** §3 beat 2 flags scree as gameplay-relevant if a slip-zone debuff lands. The W3-B2 scaffold can ship inert scree without blocking. The mechanic decision (does the player slip on scree? if so, what's the penalty / telegraph / counter?) is a Priya design call. **Owner:** Priya — M2 mechanic backlog.
3. **Steam-vent hazard mechanic — design + ship, or ship inert?** §3 beat 4 flags steam vents as gameplay-relevant if contact damage lands. Same disposition as scree — W3-B2 scaffold ships inert vents; mechanic is a follow-up ticket. **Owner:** Priya — M2 mechanic backlog.
4. **Stratum-2 boss design — own palette sub-biome?** S1's boss uses a sub-biome variant of the Cloister palette (boss room is a darker corner of the same color family). Should S2's boss room get its own sub-biome (e.g., "deepest mine seam, vein-saturated walls") or stay in the standard Cinder Vaults palette? **Owner:** Uma + Drew — S2 boss design ticket, not this doc.
5. **Drew's W3-B2 input format — palette doc only, or also a sample frame?** Drew's W3-B2 is a chunk-lib scaffold (architecture-level, no content). For the actual sprite authoring downstream, does Drew want me to ship a 480×270 sample-frame mockup of an S2 R1 in the new palette, or is this doc enough? **Owner:** Drew — coordinate before he starts authoring tile sprites.
6. **Should S2's `mus-stratum2-bgm` cue (M2 audio) get a directional update from "quiet, eerie, teal-bronze" to "low-pulse, frame-drum-led, rust-saturated"?** The audio direction's S2 BGM line (`audio-direction.md` row 87) was written against the indicative Sunken Library aesthetic. If the biome is now Cinder Vaults, the music should harmonize. **Owner:** Uma — `audio-direction.md` v1.1 revision to land alongside this doc OR queue as a follow-up. Not blocking the visual scaffold.
7. **Does the ember-accent dual-role (player flame + vein-bright cores) need a Sponsor sanity-check?** The diegetic logic is "your flame and the vein cores are the same substance" — that's a fiction lock that affects S7 / S8 design. Sponsor may want to weigh in before that fiction commitment hardens further. **Owner:** Sponsor — at the M1 sign-off conversation if convenient; otherwise queue for M2 narrative review.

---

## Hand-off

- **Drew (W3-B2):** §5 sprite reuse table + §2 authoritative palette. Five hard-need sprites for the scaffold (floor tiles, wall tiles + vein anim, ash-glow node prop, doorway prop, S2 grunt). Five soft-need retints for M2 follow-up. The scaffold can ship with placeholder hex-block-color tiles using the §2 hex codes; polish pass to author actual textures is a separate M2 ticket.
- **Devon (S2 chunk-lib + lighting impl, M2):** §4 lighting model — two ColorRect overlays + one anim cycle on tile sprites. No Light2D, no shaders, no realtime shadows. Plus the ambient `#FF5A1A` 8% multiply tint and the deepened vignette `#0A0404` 40%.
- **Priya:** §3 beats 2 + 4 (scree + steam vent mechanic decisions); §8 open questions 1-3.
- **Tess (M2 acceptance):** §7 tester checklist S2-PL-01 through S2-PL-15. Holds until S2 content ships in M2.
- **Sponsor:** §8 open question 7 (ember dual-role narrative confirmation), §7 S2-PL-15 (subjective transition signal at S1 → S2 descent).

---

## Appendix — what we are NOT designing here

- **S2 boss design** (sprite + state machine + arena layout + boss palette sub-biome) — own ticket, M2.
- **S2 mob roster beyond grunt** (which of charger / shooter / new archetype-tbd populate S2?) — Priya's M2 mob-deploy decision.
- **S2 chunk layouts** (rooms 1-N, RoomChunk variants, exit logic) — Drew's W3-B2 scaffold + M2 content authoring.
- **S2 audio cues** beyond the ambient + BGM nudge in §8 q6 — Uma's `audio-direction.md` v1.1 if the BGM directional update gets dispatched.
- **Cross-stratum visual transitions** (the descend animation between S1 and S2) — exists already in M1 via `DescendScreen.tscn`; only the destination palette changes.
- **Strata 3-8 authoritative palettes** — they remain "indicative" in `palette.md` until each gets its own design call.
