# Visible-Equipment System — Design Spec

**Owner:** Uma · **Phase:** M3 (post-S1-mob-regen) · **Status:** READY-TO-BUILD ticket (not now-build — implementation sequences AFTER the S1 mob regeneration; the player rig pilot is step 1 of that regen per `character-monster-direction.md §6.3`). · **Authority:** Sponsor-requested this session — "the player's look must visibly change as he equips gear (armor tiers) and weapons, and he should swing when armed vs punch when unarmed."

**Design doc only.** No code, no asset generation. PixelLab generation is orchestrator-session-only (`pixellab-pipeline.md §"Execution context"`); §5 below is the gen recipe the orchestrator quotes from, the game-side wiring in §7 is a contract Drew/Devon implement, not code authored here.

**Reads from:** `character-monster-direction.md §1.1` (gear-changes-look direction + "re-armed by what the dead leave behind" lore + §3.1 recast), `player-journey.md` (T1 bone-white / T2 warm-bronze / T3 cold-steel-blue tier-color beam, Beats 8-9 loot+equip), `palette.md` (player doctrine-exemption, ember through-line), `.claude/docs/combat-architecture.md` (FIST_DAMAGE=1 fistless path, AnimatedSprite2D 3-branch resolver, `_resolve_anim_dir` octant selection, `equipped_weapon_changed` swap seam), `.claude/docs/pixellab-pipeline.md` (`create_character_state` for armed/clothed variants, animate template families, canvas-size trap, cost model), `.claude/docs/html5-export.md` (HDR clamp sub-1.0, Polygon2D→ColorRect rule, z-index tie-break rule), `scripts/content/ItemDef.gd` (live `Slot`/`Tier` enums — there is NO `weapon_class` field today; see §2).

---

## §0 — Tonal anchor (the feel, first)

> **A man who descends with nothing, and is re-clothed and re-armed by what the dead leave behind.**

The visible-equipment system is the diegetic spine of the player's whole arc (`character-monster-direction.md §1.2`). The hero starts as a bald, ragged, **weaponless** cloister monk who has not yet found the flame — `FIST_DAMAGE = 1`, throwing bare-fist jabs, the only warm-light-free humanoid on screen. Every piece of gear he equips is **scavenged off the corrupted dead** (the grunt's censer-blade, the Warden's two-hander — §6). So the look-change is not a stat-screen cosmetic; it is the player watching himself become *less helpless* and, by late-game ember-tier, beginning to carry the same light the dead carry (`character-monster-direction.md §1.2` "earned, late-game tonal rhyme").

Two feel-beats this system must deliver, in priority order:

1. **Punch → swing is the felt one.** The very first weapon pickup must change *how he attacks* — bare-fist jab/cross becomes a weapon arc. This is the moment "I found a weapon" reads in the body, not just the inventory grid. If the swing doesn't feel different from the punch, the whole system has failed its primary brief regardless of how clean the overlay sprite is.
2. **Rags → armor is the seen one.** As armor tier climbs, his body silhouette thickens rags → light → medium → heavy. This is the slower, cumulative "I am becoming equipped" read — visible at a glance across a run.

Decoration beats that don't serve those two reads get cut.

---

## §1 — System overview: the 3-layer model

The player sprite is composed of **three independently-swapped layers**, drawn back-to-front:

```
  ┌─────────────────────────────────────────────────────────────┐
  │  PLAYER (CharacterBody2D)                                    │
  │                                                             │
  │   z=0   [ LAYER 1 — BODY RIG ]   AnimatedSprite2D "Sprite"  │
  │         the monk's body. Carries ALL motion: idle / walk /  │
  │         the ATTACK animation (punch OR swing), dodge / hit  │
  │         / die. Swapped by ARMOR TIER (rags→light→med→heavy) │
  │         AND selected by WEAPON-CLASS attack-set (fist vs    │
  │         1H-melee swing). 8-direction.                       │
  │                                                             │
  │   z=1   [ LAYER 2 — WEAPON OVERLAY ]  Sprite2D "WeaponHand" │
  │         ONE small sprite per individual weapon, pinned to   │
  │         a per-direction HAND-ANCHOR on the body, drawn over │
  │         the body, riding the swing. 10 swords = 1 swing rig │
  │         + 10 cheap overlay sprites. Hidden when unarmed.    │
  │                                                             │
  │  (z=1) [ existing swing_wedge ColorRect — UNCHANGED ]       │
  │         the arc cue; separate node, separate rotation.      │
  └─────────────────────────────────────────────────────────────┘
```

**Why three layers, not one:**

- **Body-rig by armor tier** gives the "seen" read (§0 beat 2) — a heavy-armor body is a different silhouette.
- **Body-rig attack-SET by weapon class** gives the "felt" read (§0 beat 1) — the fist-set vs the 1H-swing-set are different body animations. The body must know "am I punching or swinging" because the arm motion differs; this is the **weapon CLASS** distinction, not the individual weapon.
- **Weapon overlay per individual weapon** keeps the combinatorics flat. We rig **by class** (a small fixed set of swing bodies) and skin **by weapon** (one cheap pinned sprite each). 10 swords share 1 swing body + 10 overlays — NOT 10 full body rigs. This is the load-bearing economy decision; it is what makes a growing weapon roster affordable for a 2-dev team.

**Combinatorics check.** Body rigs = `armor_tiers (4) × weapon_classes (2 for M3)` attack-sets, but non-attack states (idle/walk/dodge/hit/die) do NOT vary by weapon class — only the *attack* animation does. So the actual body-gen surface is `4 armor bodies × {shared idle/walk/dodge/hit/die} + 4 armor bodies × 2 attack-sets`. Weapon overlays = `N individual weapons × 8 directions × swing-frame-count`, each a small pinned sprite. See §2 frame budget + §5 gen recipe for the real numbers and a phased cut (§8 lets Sponsor shrink M3 scope to armor-tier-on-rags + fist/1H only).

---

## §2 — Weapon classes the game needs

**Schema reality check (load-bearing — flag to Drew up front).** `scripts/content/ItemDef.gd` today has `enum Slot { WEAPON, ARMOR, OFF_HAND, TRINKET, RELIC }` and `enum Tier { T1..T6 }` — there is **NO `weapon_class` field**. `iron_sword.tres` is `slot=WEAPON tier=T1` with no class tag. So "weapon class" is a **net-new additive field** Drew adds to `ItemDef` (`enum WeaponClass { FIST, ONE_HAND_MELEE, TWO_HAND_MELEE, STAFF, RANGED }`, default `ONE_HAND_MELEE` for back-compat so `iron_sword` reads as 1H without a `.tres` edit). `FIST` is the implicit class when `_equipped_weapon == null` — it never needs a `.tres`, it is the `weapon == null` branch already in `Damage.compute_player_damage` (`combat-architecture.md` Damage routing). This is a small, mechanical schema add — but it MUST land before the body-rig attack-SET selection in §7 can switch on class.

### M3 ships TWO classes

| Class | When | Body attack-SET needed | Frame budget (per direction) | Overlay? |
|---|---|---|---|---|
| **FIST** (unarmed) | `_equipped_weapon == null` | **Done** — the existing `attack_light` (lead-jab) + `attack_heavy` (cross-punch) sets in `assets/sprites/player/_pixellab_anims/` (3-frame light, 6-frame heavy, confirmed on disk). | light 3f / heavy 6f | **No** — bare hands, no overlay node shown |
| **ONE_HAND_MELEE** | any 1H weapon equipped (`iron_sword`, the grunt's censer-blade, etc.) | **NEW** — a 1-hand horizontal/diagonal **swing** set: `attack_light_1h` (quick slash) + `attack_heavy_1h` (committed overhead/wide swing). The body's weapon-arm sweeps; the off-arm trails. | light ~4f / heavy ~6f | **Yes** — weapon overlay pinned to hand-anchor (§3), rides the swing |

**Why the attack-set must be a NEW body animation, not "fist body + sword overlay on top."** A punch and a sword-swing are *different arm motions* — the cross-punch retracts to the chest; the swing arcs across the body. Overlaying a sword on the punch body produces a sword that jabs forward like a fist, which reads wrong (Sponsor will catch it). The body has to actually swing. That is why ONE_HAND_MELEE needs its own attack-set on each armor body, while idle/walk/dodge/hit/die are shared across both classes (no arm-motion divergence at rest/locomotion).

### Forward classes (NOT M3 — note only, so the rig generalizes)

| Class | Forward stratum hook | Body attack-SET (future gen) | Overlay shape |
|---|---|---|---|
| **TWO_HAND_MELEE** | the Warden's two-hander (§6); S1-boss drop | two-hand overhead slam — both arms committed, wider wind-up | larger overlay, pinned across BOTH hands (two anchors or a single wide sprite spanning the grip) |
| **STAFF** | S2 SunkenScholar's lantern-staff lineage; a caster/strike hybrid | staff-thrust / sweep | long thin overlay, pinned at grip-hand, tip extends past body |
| **RANGED** | a future bow/sling | draw-and-loose (no melee arc) | bow overlay + the loosed projectile is a separate combat node, not part of this layer |

The 3-layer model carries all four forward classes without re-architecture: each new class = one new body attack-SET per armor tier (gen cost) + a per-weapon overlay convention (cheap). The hand-anchor table (§3) is authored 8-direction once and reused by every class — that is the forward-proofing payoff.

---

## §3 — HAND-ANCHOR convention (the load-bearing technical contract)

This is the single most important contract for Drew/Devon. The weapon overlay sprite must pin to the body's weapon-hand and ride the swing across all 8 directions and across every swing frame. Two viable mechanisms; **recommend Mechanism A (Marker2D-per-direction-frame baked into the SpriteFrames-sibling table) for fidelity, with Mechanism B (per-direction static anchor) as the M3 simplification.**

### Mechanism A — per-frame hand-anchor table (RECOMMENDED for swing fidelity)

The weapon hand moves *within* a swing (that's the whole point of a swing). So the anchor is ideally **per-direction × per-frame**: a small data table mapping `(weapon_class, direction, frame_index) → {offset: Vector2, rotation: float, z_relative: int}`. The overlay `Sprite2D "WeaponHand"` reads the current body anim's `(dir, frame)` each frame and sets its `position = anchor.offset`, `rotation = anchor.rotation`, and front/behind-body ordering via `z_relative`.

- **`offset`** — local pixel position of the grip relative to the Player origin, per frame. This is what makes the sword *travel* with the hand through the arc.
- **`rotation`** — the weapon's angle that frame, so the blade tilts through the swing (wind-up → strike → recovery), not a rigid stick.
- **`z_relative`** — `+1` (over body) for most frames, but a swing that passes *behind* the torso on the wind-up frame needs `-1` for that frame so the weapon disappears behind the body correctly. **This z-flip is HTML5-load-bearing:** per `html5-export.md` z-index tie-break rule, two nodes at equal z have renderer-dependent draw order under `gl_compatibility` — so the over/behind decision must be an EXPLICIT `z_index` set per frame, never left to draw-order tie-break. Default the overlay to `z_index = 1` (over body at z=0); the rig author sets `z_index = -1` only on the specific behind-body wind-up frames.

**Authoring source:** the anchor table is produced WHEN the 1H swing body is generated — the rig author eyeballs the grip-pixel on each frame of each direction and records offset/rotation. Store as a `.tres` Resource (`WeaponAnchorTable`) keyed `[class][dir][frame]`, sibling to the SpriteFrames `.tres`. This is hand-authored data, ~`8 dirs × ~6 frames = 48 entries` per class — tedious but one-time, and it is what separates "sword glued to a swinging body" from "sword floating near a swinging body."

### Mechanism B — per-direction static anchor (M3 SIMPLIFICATION, acceptable)

If per-frame authoring is too heavy for the M3 pilot, collapse to **one anchor per direction** (8 entries per class): the overlay pins to a fixed grip-point per facing and the body animation's own hand carries the read while the overlay stays at a representative mid-swing position. The weapon won't perfectly track the hand mid-arc, but at 48-68px game scale with a ~4-6 frame swing playing in ~0.1s, the eye reads "armed swing" fine. **This is the recommended M3 cut if the per-frame table balloons the schedule** — ship B, upgrade to A per-weapon-class later if Sponsor's soak says the weapon "detaches" mid-swing.

**Decision for Sponsor (§8):** A (per-frame, higher fidelity, more authoring) vs B (per-direction, faster, slight mid-swing detach). Recommend **B for the M3 pilot, A as a fast-follow** if the detach reads.

### Anchor convention rules (both mechanisms)

- **8-direction parity with the body.** The anchor table's directions MUST match the body rig's octant keys (`_resolve_anim_dir` returns octants `n/ne/e/se/s/sw/w/nw` per `combat-architecture.md`). Same key set; no separate direction model.
- **Anchor is in Player-local space, applied AFTER the body's per-direction frame is selected** — the overlay is a sibling child of Player (not a child of the AnimatedSprite2D), so it shares Player's transform but is positioned independently per the table.
- **Sprite-node rotation stays the body's job; the overlay's rotation is the anchor's job.** Per `combat-architecture.md` PR #274 rule, the *body* AnimatedSprite2D's `.rotation` stays 0 (directional frames carry orientation). The *weapon overlay* DOES rotate — that's the anchor's `rotation` field — because the overlay is a single sprite, not a directional frame set. Do not conflate the two: body rotation = 0 always; overlay rotation = per-anchor.

---

## §4 — Armor-tier looks

**Recommend 4 body looks: rags (base) + 3 tiers**, mapped to the existing `ItemDef.Tier` enum and the `player-journey.md` tier-colors.

| Body look | Trigger (equipped ARMOR-slot tier) | Visual distinction | Tier-color tie (`player-journey.md` Beat 8 beam) |
|---|---|---|---|
| **Rags (base)** | no armor equipped — the locked monk | frayed/patched homespun hooded robe, rope belt, thin silhouette. The §0 starting state. | n/a (the un-equipped man) |
| **Light** | armor `tier = T1` (e.g. `leather_vest`, bone-white beam) | leather/cloth over the rags — pauldron hint, bracers; silhouette slightly bulked at shoulders. Bone-white / pale leather accents. | T1 = **bone white** |
| **Medium** | armor `tier = T2` (warm-bronze beam) | mailed/scaled torso, heavier shoulders, visible greaves; clearly armored but mobile. Warm-bronze metal accents. | T2 = **warm bronze** |
| **Heavy** | armor `tier = T3` (cold-steel-blue beam) | plated silhouette — broad pauldrons, full cuirass, the heaviest read. Cold-steel-blue metal accents. | T3 = **cold steel-blue** |

(T4-T6 exist in the `Tier` enum but M1/M3 ship T1-T3 per `ItemDef.gd` comment + `player-journey.md`. T4-T6 armor looks are a forward note: either reuse Heavy with richer accent palettes or author new looks per-tier when those ship. Not M3.)

### Full body-swap, NOT overlay (RECOMMENDED for armor)

**Armor tiers are FULL body-sprite swaps, not additive overlays.** Reasons:

1. **Silhouette is the whole point.** Heavy armor must change the body's outline (broad pauldrons, bulked torso). An overlay-on-rags can't widen the silhouette convincingly — it reads as "rags with stuff stuck on." A full body re-gen per tier gives a true silhouette change (§0 beat 2).
2. **The 1px outline (VD-13) must follow the new silhouette.** `character-monster-direction.md §2.4` locks a 1-pixel dark outline on the player. An overlay approach leaves the rags' outline showing through; a full swap re-outlines the armored shape cleanly.
3. **Production is affordable via `create_character_state`** (§5) — each armor tier is a `create_character_state` edit off the base monk, applied across all 8 rotations + re-animated, NOT a from-scratch character. So "full body swap" does not mean "4× the hero-gen cost."

**Contrast with the weapon layer, which IS an overlay** — the asymmetry is deliberate: armor changes the *body* (full swap, silhouette read), weapons ride *on* the body (overlay, combinatoric economy). Different layers, different strategies, for different reasons.

### Doctrine-exemption — the player stays his own palette

**The player is doctrine-EXEMPT across ALL armor tiers** (`palette.md` / `pixellab-pipeline.md §"Doctrine-lock is per-character"` / `character-monster-direction.md §1.1`). The armored bodies are **never** run through the S1/S2 doctrine-lock pipeline — his bald head, pale skin, and **blue eyes** survive every tier. Armor accent colors (bone-white / warm-bronze / cold-steel-blue) come from the **tier-color** convention (`player-journey.md`), NOT from a stratum doctrine ramp. The blue-eye-erasure error documented in `pixellab-pipeline.md` is the cautionary tale — every armor-tier body must be visually verified to keep the blue eyes after gen. The player's only ember tie is the *earned* late-game ember-tier gear (`character-monster-direction.md §1.2`), not a doctrine retint.

---

## §5 — PixelLab production recipe

Per `pixellab-pipeline.md` (orchestrator-session-only; the orchestrator runs these gens, Sponsor judges in-context). All player gens: **low top-down view, `size=48` (→68×68 canvas), 8-direction**, matching the existing rig (`character-monster-direction.md §6.1`). **Confirm the base monk's canvas size in the PixelLab account before any call** — the documented `size=32` Sunken-Scholar miscall is the trap; `size=48` matches the existing player rig.

### §5.1 Layer-by-layer gen approach

**LAYER 1 — Body rigs (armor tiers + the 1H attack-set):**

- **Rags base body — DONE.** The locked monk rig already exists (`assets/sprites/player/_pixellab_anims/` has rotations + `attack_light`/`attack_heavy` (fist) + `die` etc.). This is the doctrine-exempt base; do NOT re-gen, do NOT doctrine-lock.
- **Armor-tier bodies (Light / Medium / Heavy) — `create_character_state` on the base monk.** One variant edit per tier, e.g. `edit_description="add layered leather armor over the homespun robe, bracers and shoulder pads, keep bald head and blue eyes"` (Light), `"...mail and scaled torso, heavier shoulders, warm bronze metal"` (Medium), `"...full steel plate cuirass and broad pauldrons, cold steel-blue metal, keep bald head and blue eyes"` (Heavy). `create_character_state` applies the edit consistently across all 8 rotations for ~1 gen-equivalent and **keeps the source identity** (bald/blue-eyed) — exactly the tool for "same man, more armor." Caveat (`pixellab-pipeline.md`): variants produce a *simpler/flatter* palette than fresh gens and must be verified per-direction for the blue eyes surviving. Returns a NEW `character_id` per tier.
- **The 1H-melee attack-SET (swing) — `animate_character` template on EACH body** (rags + 3 armor tiers). Template family: try **`slashing`** first (the natural 1H sword arc), fall back to `sword-slash` / `attack` / `melee` families per the `pixellab-pipeline.md` template-trial discipline. Generate `attack_light_1h` (quick slash, ~4f) and `attack_heavy_1h` (committed swing, ~6f). **Per-direction inspection is mandatory** — `pixellab-pipeline.md` documents templates flipping facing mid-cycle AND the per-direction motion-semantics drift (the `surprise-uppercut` south-sway finding); inspect all 8 directions of each swing before shipping, reroll bad directions individually (1 gen each) or direction-borrow.
  - **The fist attack-set is already done** (existing `attack_light`/`attack_heavy`) — the swing set is the NEW gen here.
  - **Hand-swap trap is SIDESTEPPED by the overlay architecture** (`pixellab-pipeline.md` "Hand-object continuity is NOT preserved"): we generate the swing body **weaponless** (no sword in the prompt) and add the weapon as the §3 overlay. So PixelLab's hand-swap-across-frames bug is irrelevant — there's no held weapon in the body gen to swap. This is a *direct architectural win* of the 3-layer model; call it out in the gen brief.

**LAYER 2 — Weapon overlay sprites (per individual weapon):**

- **Small, hand-scale single sprites.** Each weapon = one small PNG (a sword ~16-24px long), NOT a character. Two viable sources:
  - **`create_map_object` / a small `create_character` of just the object** for a clean isolated weapon sprite, then crop to the blade bounding box. For M3's first weapon (the censer-blade) one gen suffices.
  - **Hand-paint via pixel-mcp** (`draw_rectangle` 1×1 discipline) for a ~16px sword — at this scale a hand-authored overlay is fast and gives exact control of the grip-pixel (which the §3 anchor table needs to align to). **Recommend hand-paint for the M3 pilot weapons** — cheaper than a gen and the grip-alignment is exact.
- The overlay does NOT need 8 separate sprites if it's a simple straight blade — one sprite rotated per the anchor's `rotation` field covers all directions. A weapon with a distinct profile (axe, lantern-staff) may want a few orientation variants; M3's 1H sword is one rotatable sprite.

**LAYER 2 doctrine note:** weapon overlays scavenged off doctrine-locked mobs (the grunt's censer-blade) MAY carry that mob's palette OR be authored to the weapon's own metal/ember tones. The player is exempt but his *scavenged weapons* are diegetically the dead's — a faint S1-doctrine tint on the censer-blade is on-lore (it WAS the grunt's). Low-stakes; ship the hand-paint at the weapon's natural tones, Sponsor adjusts in soak.

### §5.2 Cost estimate (rough, per `pixellab-pipeline.md` cost model)

| Item | Gen cost |
|---|---|
| Rags base body | 0 (exists) |
| 3 armor-tier body variants (`create_character_state` × 3) | ~3-24 (variants may bill per-direction ~8 each per the cost-model caveat — budget the high end ~24) |
| 1H swing attack-set: `attack_light_1h` + `attack_heavy_1h` × 4 bodies (rags + 3 armor) × 8 dir | 2 anims × 4 bodies × ~8 dir = ~64 gens (template, ~1 gen/direction) + reroll headroom |
| Weapon overlays (hand-paint) | 0 gens (pixel-mcp) |
| **M3 total** | **~70-90 gens** (well within Tier 2's 5000/mo; comfortable headroom for rerolls) |

**The 1H swing set across 4 bodies is the cost driver.** §8 Sponsor-cut option: ship the swing set on **rags + Heavy only** (2 bodies, ~32 gens) for the M3 pilot — the player typically has *some* armor by the time he has a weapon, and rags+Heavy brackets the range; Light/Medium swing sets fast-follow. Recommend full 4-body only if Sponsor wants every tier swinging from the pilot.

### §5.3 Pilot order

1. **Schema + wiring stub first** (Drew, §7) — `WeaponClass` field + the body-rig attack-SET selection switch + overlay node + anchor table read. Gen-independent; can land before any new art.
2. **1H swing attack-set on the RAGS body** (the cheapest body, already the base) + **the censer-blade overlay** (hand-paint) + **its anchor table** (§3, Mechanism B / per-direction). This is the **minimum vertical slice** that proves "punch → swing + visible weapon." Sponsor soaks THIS first, in-room, at game zoom (`judge-first-of-class-art-in-context`).
3. **Armor-tier bodies** (Light → Medium → Heavy via `create_character_state`) + their swing sets. Each tier is a Sponsor judge-in-context gate.
4. **Forward classes** (2H/staff/ranged) — separate tickets when those weapons ship.

**Pilot acceptance gate:** step 2's slice — equip the censer-blade, watch the punch become a swing with the blade riding the hand — is the go/no-go for the whole system. If the swing reads and the blade tracks, scale to armor tiers. If the blade detaches mid-swing, decide Mechanism A vs B (§3) before scaling.

---

## §6 — Lore tie-in: the re-arming arc

The first weapons the player finds **ARE the corrupted dead's own** (`character-monster-direction.md §1.1` "re-armed by what the dead leave behind" + §3.1 recast):

- **The grunt's censer-blade** — the cloister penitent (§3.1 recast: grunt = a monk who fused to the ritual) carries "a short censer-blade (a thurible-on-a-chain reforged as a weapon)." This is the **first weapon the player picks up** (`player-journey.md` Beat 8 first-kill loot drop) and therefore the **M3 pilot overlay sprite** (§5.3 step 2). The man who descended with nothing takes the dead penitent's weapon — the re-arming arc's first beat, made literal.
- **The Warden's two-hander** — the Stratum1Boss (§3.1 recast: the Warden of the Cloister) wields "a great two-handed weapon (slam telegraph `draw_arc`)." When that drops, it's the first TWO_HAND_MELEE weapon — a forward-class hook (§2), the boss-kill reward that changes the player's whole attack profile. Not M3, but the rig generalizes to carry it.

**The arc, stated:** rags + fists → the penitent's censer-blade (first 1H) → leather off the early dead (Light armor) → bronze, steel (Medium/Heavy) → the Warden's two-hander → eventually ember-tier gear that makes him carry the same light the dead carried (`character-monster-direction.md §1.2`). Every visible-equipment swap is a beat in "a man re-clothed and re-armed by the dead." The system is the arc's delivery mechanism.

---

## §7 — Game-side wiring notes (contract for Drew/Devon — NOT implementing here)

The implementation contract. Cross-ref `combat-architecture.md §"Sprite-node topology"` (M3W-1 3-branch resolver, `_resolve_anim_dir`, PR #274 rotation rule) — this system extends that wiring, it does not replace it.

1. **`WeaponClass` schema add (Drew, prerequisite).** Add `enum WeaponClass { FIST, ONE_HAND_MELEE, TWO_HAND_MELEE, STAFF, RANGED }` + `@export var weapon_class: WeaponClass = WeaponClass.ONE_HAND_MELEE` to `ItemDef.gd`. Default `ONE_HAND_MELEE` so `iron_sword.tres` reads as 1H with no `.tres` edit. `FIST` is the implicit class when `_equipped_weapon == null` (the existing `weapon == null` / `FIST_DAMAGE` branch). Paired GUT: `iron_sword` resolves `ONE_HAND_MELEE`; null weapon resolves `FIST`.

2. **Body-rig attack-SET selection by weapon class.** Extend the existing `_resolve_anim_dir` / anim-name path (`combat-architecture.md` PR #274). The attack-state anim name gains a class suffix: `attack_light` / `attack_heavy` for FIST (existing), `attack_light_1h` / `attack_heavy_1h` for ONE_HAND_MELEE. A `_resolve_attack_set()` reads `get_equipped_weapon()` → its `weapon_class` → returns the anim-name prefix. **idle/walk/dodge/hit/die are NOT class-suffixed** — they're shared (§2). Pin with a test: equip 1H → attack plays `attack_light_1h_<dir>`; unequip → plays `attack_light_<dir>`.

3. **AnimatedSprite2D layering + z-order.** The body is the existing `Sprite` AnimatedSprite2D (z=0, node name preserved per the M3W-1 contract — every `get_node("Sprite")` resolver keeps working). The weapon overlay is a NEW sibling `Sprite2D` named `WeaponHand`, child of Player (NOT child of `Sprite`), default `z_index = 1` (over body). The §3 anchor sets its per-frame `position`/`rotation`/`z_index`. **HTML5 z-tie-break rule (`html5-export.md`):** never rely on draw-order tie-break for over/behind-body — the behind-body wind-up frames set `z_index = -1` EXPLICITLY.

4. **Swap-on-equip.** The existing `equipped_weapon_changed(new_weapon)` signal (`Player.gd:79`) is the swap seam — already emitted on every equip/unequip (`Player.gd:683/723/829`). Wire a `_on_equipped_weapon_changed(weapon)` slot that: (a) shows/hides `WeaponHand` (`weapon == null` → hide), (b) sets the overlay sprite + its anchor table to the weapon's class/id, (c) the attack-set selection (#2) picks up the new class on the next attack automatically. Armor swap rides a parallel armor-slot signal (Devon: confirm the armor-slot equip emits an equivalent `equipped_armor_changed` or extend the equip path — `_equipped[&"weapon"]` has a sibling armor entry; the body-look swap reads the ARMOR tier, the attack-set reads the WEAPON class — two independent reads).

5. **Body-look (armor-tier) swap.** On armor equip/unequip, swap the body AnimatedSprite2D's `SpriteFrames` resource to the tier's body (`rags` / `light` / `medium` / `heavy`). Because all four bodies share the same anim-key shape (`<state>_<dir>`, plus the `_1h` attack variants), the swap is a `SpriteFrames` resource pointer change + replay current state — no per-tier code branching. Keep the node name `Sprite`. The hit-flash 3-branch resolver (`combat-architecture.md` M3W-1) routes AnimatedSprite2D through `.modulate` — unchanged across tiers; verify the resolver re-resolves `_hit_flash_target` if the SpriteFrames swaps mid-life (it caches on first hit — a tier swap mid-combat must invalidate that cache OR the resolver must re-read; flag to Drew as an edge test).

6. **HTML5 visual-verification gate applies** (`html5-export.md`): AnimatedSprite2D + modulate + the overlay z-ordering all hit WebGL2 quirks. Author-self-soak the swing + overlay + tier-swap in HTML5 before Self-Test Report; sub-1.0 channels on any tint; the overlay z-flip is exactly the kind of `gl_compatibility` draw-order divergence the gate exists for. Per-surface escape-clause if author can't run a browser (route the overlay-z behavior to pre-merge Sponsor soak with explicit probe targets).

**The swing-wedge ColorRect stays UNCHANGED** — it's the separate arc cue (`combat-architecture.md`), its own node, its own rotation, ColorRect-not-Polygon2D per the PR #137 rule. Do not conflate the weapon overlay (rides the hand) with the swing wedge (the arc telegraph). Both are z=1, both visible during a swing, but they are different nodes with different jobs.

---

## §8 — Sponsor-decision surface

The calls to veto/approve. Everything above is authored against the recommended shape; these are the redirect windows.

1. **Weapon-class list for M3: FIST + ONE_HAND_MELEE.** RECOMMEND APPROVE — covers the entire M3 weapon roster (`iron_sword`, the censer-blade) plus the locked fist base. 2H/staff/ranged are forward notes the rig already generalizes to. Sponsor could add 2H to M3 if the Warden-drop should change attack profile at S1-boss kill — adds ~1 attack-set gen surface per armor body.
2. **Armor-tier count: rags + 3 tiers (4 body looks), mapped to T1/T2/T3.** RECOMMEND APPROVE — matches the `Tier` enum + `player-journey.md` tier-colors. Sponsor could cut to rags + 2 (light/heavy) for the pilot, or extend to T4-T6 looks (not M3).
3. **Armor = full body-swap; weapon = overlay.** RECOMMEND APPROVE the asymmetry (§4 rationale: armor needs silhouette change → full swap; weapons need combinatoric economy → overlay). Sponsor veto on full-swap would mean armor-as-overlay (cheaper gen, weaker silhouette read) — not recommended, loses §0 beat 2.
4. **Hand-anchor mechanism: B (per-direction static) for the M3 pilot, A (per-frame) as fast-follow.** RECOMMEND. Sponsor could mandate A from the start (higher fidelity, more authoring) if mid-swing weapon-tracking is a must-have for the pilot soak.
5. **Pilot scope: the §5.3 step-2 vertical slice first** (1H swing on rags body + censer-blade overlay + per-direction anchor), Sponsor-soaked in-room before scaling to armor tiers. RECOMMEND APPROVE — it's the go/no-go gate for the whole system at minimum gen cost (~32-40 gens). Sponsor could request all 4 armor bodies swinging from the first soak (~70-90 gens).
6. **Player stays doctrine-EXEMPT across all armor tiers** (blue eyes + own palette survive every tier; armor accents from tier-colors, not stratum doctrine). RECOMMEND APPROVE — load-bearing per the locked player identity; veto here contradicts the Sponsor-locked hero.

---

## Cross-references

- `team/uma-ux/character-monster-direction.md §1.1 / §1.2 / §3.1` — locked player identity, contrast thesis, "re-armed by the dead" direction, grunt-censer-blade + Warden-two-hander recast.
- `team/uma-ux/player-journey.md` Beats 8-9 — first-kill loot drop, tier-color beam (T1 bone-white / T2 warm-bronze / T3 cold-steel-blue), equip flow.
- `team/uma-ux/palette.md` — player doctrine-exemption, ember through-line (earned late-game), aggro-glow constant.
- `.claude/docs/combat-architecture.md` — `FIST_DAMAGE` fistless path; M3W-1 AnimatedSprite2D 3-branch hit-flash resolver; `_resolve_anim_dir` octant selection; PR #274 body-rotation-stays-0 rule; `equipped_weapon_changed` swap seam.
- `.claude/docs/pixellab-pipeline.md` — `create_character_state` for armor-tier variants; `slashing`/template families for the swing set; canvas-size trap (size=48); hand-swap trap (sidestepped by weaponless-body + overlay); doctrine-exemption rule; cost model.
- `.claude/docs/html5-export.md` — HDR clamp (sub-1.0 channels); z-index tie-break rule (explicit z per overlay frame, never draw-order); visual-verification gate + per-surface escape clause.
- `scripts/content/ItemDef.gd` — live `Slot` / `Tier` enums; `weapon_class` is NET-NEW (§2).
- `scripts/player/Player.gd` — `_equipped_weapon: ItemDef`, `get_equipped_weapon()`, `equipped_weapon_changed` (lines 79/668/683/723/829) — the swap seams.
- Memory `judge-first-of-class-art-in-context` — pilot stages judged rendered in-room at game zoom, never isolated swatches.
</content>
</invoke>
