# Character & Monster Art-Direction Investigation — Embergrave

**Owner:** Uma · **Phase:** M3 (bestiary design language; informs the PixelLab regeneration roadmap) · **Authority:** Sponsor-requested investigation ("what monsters, mobs, and player style would be best AND popular, while matching the game's style and lore"). The **player identity is Sponsor-LOCKED this session** — this doc designs the bestiary to *contrast* that hero, it does not redesign him.

This is a design doc only. No code, no asset generation. PixelLab generation is orchestrator-session-only (`.claude/docs/pixellab-pipeline.md §"Execution context"`) — the orchestrator runs the gens; this doc is the design Sponsor + orchestrator quote from when they do.

**Reads from:** `visual-direction.md` (8-stratum hue/saturation/ember table, VD-13 1px-outline rule), `palette.md` + `palette-stratum-2.md` (per-stratum doctrine hexes + the already-authored S2 mob archetypes), `world-map-direction.md` (cloister = record-keeping order; descent narrative), `player-journey.md` ("the flame remembers" / "find it" / ember-dissolve death), `.claude/docs/pixellab-pipeline.md` (production recipe), `.claude/docs/html5-export.md` (primitive discipline), `.claude/docs/combat-architecture.md` (AnimatedSprite2D state-anim wiring + gameplay roles).

---

## §0 — TL;DR (the thesis in five lines)

1. **Tonal anchor:** *The player is a small humble human descending into places full of things that used to be people.* A bald, poor, weaponless cloister monk who has **not yet found the flame** — against bestiaries that are each stratum's own corrupted dead.
2. **The bestiary principle — "the monsters ARE the place's dead."** Every stratum's creatures are the corrupted remains of who lived/worked/died there. This is simultaneously on-lore (extends "the monks are gone but the room hasn't noticed") and the most proven-popular monster-design grammar in the genre (Hollow Knight infected / Dark Souls hollows / Blasphemous penitents).
3. **Four craft rules for the popular feel:** silhouette-first (readable at 32-48 px), one memorable hook per creature, restraint-on-characters / density-on-environments (Toppi), and **an ember SOMEWHERE on every creature** (eye, crack, coal) tying the whole bestiary to the flame the player seeks.
4. **The recast-roster table (§3) is the priority deliverable** — it re-frames the existing S1 sprites (grunt/charger/shooter/stoker/practice_dummy/Stratum1Boss) and the S2 archetypes under the "place's dead" lore, keeping every gameplay role intact, so the PixelLab regeneration has a unified fiction to author against.
5. **PixelLab production:** pilot-first rollout (player rig → S1 mobs → S1 boss → S2+), v3-highest-quality for hero + named mobs, standard for crowd variants, low top-down view to match the existing 68 px rig.

---

## §1 — Locked player identity + the contrast thesis

### §1.1 The hero (Sponsor-LOCKED — do NOT redesign)

The player is **a humble, poor cloister monk** — concretely:

- **Bald.** Pale-white-skinned. **Blue-eyed.** (Reference concept: `assets/sprites/player/_concepts/monk_south.png` — read into this doc; the existing south idle at `assets/sprites/player/idle_s.png`.)
- **Worn / frayed / patched homespun hooded robe** with a **rope belt**. Cowl can be up or pushed back; the face reads.
- **NO armor. NO weapon at base. NO ember-glow on his body.** He is a man who has **not yet found the flame** — the title stinger's "Find it" (`player-journey.md` Beat 3) is literal. The fistless-by-design combat start (`combat-architecture.md` § "Damage routing — `FIST_DAMAGE = 1` when `weapon == null`") is the mechanical expression of "he descends with nothing."
- **Gear visibly changes his look when equipped** — tiered look-swaps: rags → light → medium → heavy, plus a weapon-in-hand layer. This is the **visible-equipment approach**; this doc only names it as the direction (full layer spec is a separate ticket). The diegetic arc is: a man who starts with nothing and is re-clothed/re-armed by what the dead leave behind.

**The player is doctrine-EXEMPT** (`pixellab-pipeline.md §"Doctrine-lock is per-character"` + `palette-stratum-2.md §5` "Player … NO CHANGE — cross-stratum constant"). His blue eyes + homespun palette are the through-line; they are **never** retinted to a stratum doctrine. Running the player through the S1 doctrine-lock pipeline is a known error that erases the blue eyes (the documented PR-precedent in the pipeline doc).

### §1.2 The contrast thesis

**Humble living human vs. the place's exalted dead.** Every design tension in the bestiary is this single axis:

| The player | The monsters |
|---|---|
| Small, plain silhouette | Larger / heavier / wronger silhouettes |
| Homespun rags, no glow on the body | Each carries an ember they cannot put out (eye/crack/coal) |
| Has NOT found the flame | Were CONSUMED by the flame (that's what corrupted them) |
| A man | Things that *used to be* people |
| Alive, descending | Dead, but the room hasn't noticed |

The player's lack of ember-glow is **load-bearing for the whole bestiary**: because the hero's body is the only warm-light-free humanoid on screen, *every* mob's ember tell reads instantly as "not-you / corrupted." The monsters glow; you don't — yet. The flame you're descending to find is the same substance that hollowed out everything trying to kill you (`palette.md` § "Ember accent preservation — global lock": the player's flame is the same substance as the embergrave seam at the world's core). When the player finally equips ember-tier gear (T6 Mythic `#FF6A2A`, `palette.md`), he begins to carry the same light the dead carry — an intentional, earned, late-game tonal rhyme.

---

## §2 — The monster-design LANGUAGE

### §2.1 The principle — "the monsters ARE the place's dead"

**Every stratum's creatures are the corrupted remains of whoever lived, worked, or was buried there.** Not generic fantasy fauna; not a roaming monster-manual. The bestiary is *site-specific necrology*.

This is pressure-tested against both axes the Sponsor asked about:

**On-lore (matches Embergrave's established fiction):**
- The cloister is a **record-keeping order** (`world-map-direction.md §1`); the descent narrative is "the monks are gone but the room hasn't noticed" / "this is what was here before humans" (`palette.md` S3 entry). The bestiary *is* that narrative made flesh — each floor's enemies are its former inhabitants.
- It's already how the locked strata read: S2 hostiles are explicitly "what the scholars became" (`palette-stratum-2.md §1.5`); S5 cultists are "what S1's monks turned into" (`palette.md` S5). This doc **promotes that latent pattern to the project's stated bestiary doctrine** and back-applies it to S1.

**Proven-popular (the genre's most-memorable monster design):**
- *Hollow Knight* — the Infected: every bug is a citizen of Hallownest, corrupted by the same plague the player is investigating. *Dark Souls* — Hollows: every enemy is a person who lost their humanity to the same curse the player carries. *Blasphemous* — Penitents: every monster is a worshipper warped by the same guilt-faith the player practices. These are widely cited as the most memorable bestiaries in the genre **precisely because the monsters share the player's predicament.** Embergrave's "the dead were consumed by the flame you seek" is the same engine.

The principle gives every future stratum a **free creative constraint** that generates roster + reads as intentional: "who worked here, and what did the heat/pressure/depth do to them?"

### §2.2 The four craft rules (the "popular" feel)

1. **Silhouette-first.** Every creature must be identifiable by black-shape alone at game scale (32-48 px on the 68 px PixelLab rig at `char_scale ≈ 0.6`; `pixellab-pipeline.md` "project humanoid mob scale `size=48`"). The player reads *threat type* from silhouette before any color resolves. Mignola/Toppi black-shadow logic (`visual-direction.md` reference shelf). Test: squint at the sprite — if grunt/charger/shooter aren't three distinct shapes, it fails.
2. **ONE memorable hook per creature.** Each mob gets exactly one signature feature that the player remembers and names ("the lantern guy," "the bone-arms one," "the one that charges"). Not three cool details — ONE, big enough to read at silhouette distance. PixelLab honors the *first* noun in a prompt as the silhouette (`pixellab-pipeline.md` "first noun dominates the silhouette") — so the hook is also the production lever.
3. **Restraint on characters / density on environments (Toppi).** Characters are clean, bold, few-color silhouettes — they must read in motion against busy ground. Environments carry the dense detail. This is the `visual-direction.md` "Sergio Toppi — dense detail in tilesets; restraint in characters" anti-reference made into a mob rule. Crowd mobs especially: a room of 4 grunts needs 4 clean shapes, not 4 busy ones.
4. **An ember SOMEWHERE on every creature.** Every hostile carries one ember tell — a glowing eye, a body-crack, a fused coal, a lantern-core. This is the bestiary's through-line and ties every monster to the flame the player seeks. The mechanical anchor already exists: **aggro eye-glow `#D24A3C`** is the cross-stratum constant on every mob (`palette.md` PL-11) — same hex as player HP-foreground, so "the mob's eyes go red" = "this color of damage is coming." The ember tell at rest can be dimmer/other-placed; the `#D24A3C` aggro flare is the universal combat cue.

### §2.3 The ember through-line (where the ember lives, per craft-rule 4)

The ember accent (`#FF6A2A` + its ramp) is the project's diegetic spine (`palette.md` global lock). On creatures it appears as:

- **Aggro eye-glow `#D24A3C`** — universal, every mob, every stratum (the combat-cue ember; PL-11).
- **A rest-state ember tell** — placed per-creature so it reads at silhouette: a fused coal in the chest-crack, a lantern-core, a glowing seam down a limb, an ember weld where machinery met flesh. This is the "one memorable hook" for many creatures.
- **Disambiguation discipline** (from `palette.md` S2/S4/S6 ember-role notes): on warm strata where the environment is *also* ember-orange (S4 molten channels, S6 magma roots), the **mob ember stays attached-to-silhouette + pulses** while environmental ember is band-shaped/fixed. Shape + motion + attachment separate "mob ember" from "world ember" even when the hex collides. This is already a locked rule for the environment; it extends verbatim to creatures.

### §2.4 The VD-13 1-pixel outline (locked)

**Every player and humanoid/creature mob carries a 1-pixel dark outline** (`visual-direction.md` VD-13: "yes for player and humanoid mobs (clarity over silhouette), no for environmental tiles"). This is the silhouette-first rule's enforcement mechanism — the outline guarantees the creature breaks off the background even when its body color is close to the floor (the recurring accessibility risk in `palette.md` S3/S5/S7 "mob cloth vs floor" pairs is solved primarily by outline + motion). The outline hex is the stratum's darkest doctrine value (e.g. S2 outline; `pixellab-pipeline.md §4` luminance-band "outline" role). PixelLab prompt token: "bold 1-pixel dark outline" (already in the S2 seeds).

### §2.5 Per-stratum palette binding

Every creature is authored to its stratum's doctrine palette (`palette.md` per-stratum ramps + `palette-stratum-2.md` for S2), with **two cross-stratum constants that never retint**: the aggro eye-glow `#D24A3C` (PL-11) and the ember accent `#FF6A2A` (global lock). The player is the third never-retint constant (doctrine-exempt). Everything else — cloth, skin, metal, bone — takes the stratum's hex family. This is what makes a retinted silhouette read as "the same kind of dead, deeper down" (S3 drowned-monk = S1 grunt silhouette, teal-soaked).

---

## §3 — Existing-roster recast (THE PRIORITY — regenerate these FIRST)

These are the sprites that already exist (`assets/sprites/`) and that the PixelLab regeneration touches first. The recast keeps **every gameplay role intact** (grunt = melee, charger = rush, shooter = ranged, etc.) and re-frames each under the "place's dead" lore so the regeneration authors against one fiction.

**S1 framing (NEW — this doc establishes it):** Stratum 1 is the **Outer Cloister**, and its monsters are **the monks who never left** — penitents who fused themselves to the cloister's rituals rather than flee, ossuary-things assembled from the order's own dead, brazier/candle wardens still tending fires for a congregation that's centuries gone. This back-applies the "place's dead" doctrine (already explicit for S2-S8) to S1, which currently has no unified bestiary fiction.

### §3.1 Recast table — S1 roster

| Sprite (role) | What it IS (recast lore) | ONE silhouette hook | Ember placement | PixelLab description seed (1-line) |
|---|---|---|---|---|
| **grunt** (melee) | A **cloister penitent** — a monk who knelt to the ritual until the ritual took him; still shuffles the rounds, still swings the censer-blade at intruders. The order's foot-rank dead. | Deep cowl + a short censer-blade (a thurible-on-a-chain reforged as a weapon); hunched penitent stoop. | Two glowing `#D24A3C` eyes inside the cowl-shadow (rest = dim coal-red; aggro = bright). | hooded cloister penitent with two bright glowing #D24A3C red eyes inside the hood, tattered brown #5A4738 monk robe with rope belt, short censer-blade in one hand, hunched penitent stoop, dark fantasy, bold 1-pixel dark outline, readable at 32px |
| **charger** (rush) | An **ossuary-thing** — a four-limbed scramble assembled from cloister-dead, lunging on all fours; the order buried its dead in the walls and something walked back out. | Quadrupedal bone-scramble silhouette (the ONLY non-upright S1 shape — instant read as "the fast one"). | A fused ember-coal lodged in the ribcage-cavity, glowing through the bone; eyes `#D24A3C` on the charge. | four-legged ossuary creature scrambling on bone limbs with a glowing ember-coal #FF6A2A lodged in its ribcage, skull-fragment head with #D24A3C red eye-glow, bone-grey #9C9590 and tattered #5A4738 cloth, dark fantasy, bold 1-pixel dark outline, readable at 32px |
| **shooter** (ranged) | A **brazier-warden** — a robed monk fused to a hand-brazier, still tending fire for an empty cloister; flings ember-cinders at intruders. The dead who kept the lights on. | A hand-brazier / fire-bowl fused to one arm (the ranged-tell — light-source change is the telegraph, like the S2 Scholar's lantern). Compact, hunched. | The brazier-bowl core glows `#FFB066`→`#FF6A2A`; eyes `#D24A3C`. The brazier IS the rest-state ember tell. | hunched robed brazier-warden with a glowing ember #FF6A2A fire-bowl fused to one forearm, deep hood with two #D24A3C red eyes, scorched #5A4738 robe, throwing-cinder pose, dark fantasy, bold 1-pixel dark outline, readable at 32px |
| **stoker** (current M3-ship = grunt-retint; melee) | **A cloister-novice who descended too deep** — the fiction already locked in `palette-stratum-2.md §5` for the Stoker's M3 grunt-retint ship-state. He went down toward the forge-heat and the heat kept him. A penitent one stratum further gone. | (M3 phase-1: shares grunt hooded silhouette, retinted.) Phase-2 doctrine: miner's-cap + torn smock silhouette (deferred per DECISIONS.md 2026-05-18). | Heat-corroded cloth `#7A1F12`; sun-scorched skin `#7E5A40`; eyes `#D24A3C`. A glowing ember-weld at the collar where the heat fused the robe to the skin (phase-2 hook). | (M3 ship) retint of grunt seed to S2 mob ramp: heat-corroded #7A1F12 robe, sun-scorched #7E5A40 skin, #D24A3C eyes — per palette-stratum-2.md §5 Grunt-mob row. Phase-2 reauthor = miner's-cap silhouette. |
| **practice_dummy** (tutorial, non-hostile) | A **straw-and-cloth cloister effigy** — the order's training figure, propped in the first chamber; the one "dead" thing in S1 that was never alive. Pure onboarding prop (`player-journey.md` Beat 4-5: poofs to ember-dust on the third strike). | A slumped scarecrow-on-a-post; obviously inert (no eyes, no menace) — its *lack* of an ember tell is the read: "this one is safe." | **Intentionally NONE at rest** — the dummy is the one creature with no ember, marking it as not-truly-dead/not-hostile. On its ember-poof death it dissolves into `#FF6A2A` dust (the death VFX, not a creature tell). | straw-and-cloth training effigy slumped on a wooden post, burlap sack head with stitched seam, no eyes, tattered #5A4738 cloth, cloister practice dummy, dark fantasy, bold 1-pixel dark outline, readable at 32px |
| **boss / Stratum1Boss** (boss) | **The Warden of the Cloister** — the order's last guardian, the one tasked with keeping intruders from the descent, still at his post centuries after the order died. Bigger, heavier, deliberate. Already authored at `size=56` (80×80 boss scale). | Hulking warden silhouette — heavy iron + a deep ritual surcoat; a great two-handed weapon (slam telegraph `draw_arc` per PR #291). The mass IS the hook. | Warden-red surcoat `#7A1F29`; eyes `#D24A3C`; a banked ember glowing through the seams of his iron where the heat got in. | (existing) hulking armored cloister warden, deep red #7A1F29 ritual surcoat over heavy iron plate, two #D24A3C glowing eyes, ember #FF6A2A glow through armor seams, two-handed weapon, dark fantasy boss, bold 1-pixel dark outline, readable at 56px |

**NPCs (npc_anvil_keeper / npc_bounty_poster / npc_vendor):** these are the **living monks of the hub-town cloister** — the record-keeping order's survivors who tend the anvil, post the bounties, and trade (`world-map-direction.md §1`). They are the contrast-control: clean, calm, ember-FREE humanoids (like the player), proving the bestiary's "ember = corrupted" grammar by counter-example. They are doctrine-warm (parchment hood + warm bronze per the pipeline doc's NPC default) but carry NO aggro-glow. **No recast needed — they are already correctly "the living dead-keepers."** Keep them ember-free; that's load-bearing.

### §3.2 Recast table — S2 archetypes (already authored in `palette-stratum-2.md §5.5`)

The S2 named mobs are **already richly specced** in `palette-stratum-2.md §5.5` (silhouette + animation states + ember placement + PixelLab seeds). This doc does NOT re-spec them — it confirms they already follow the "place's dead" doctrine and cross-references. S2 = **Cinder Vaults**, hostiles are "what the scholars became" (`palette-stratum-2.md §1.5`).

| Sprite (role) | What it IS (recast lore — already locked) | ONE silhouette hook | Ember placement | Source of truth |
|---|---|---|---|---|
| **SunkenScholar** (ranged caster) | A scholar who came to read the embergrave seams and never came back; robe heat-scorched, lantern-staff fused to one hand. "Scholars drowned in their own archive." | Tall thin robed silhouette with a **brass lantern-staff** held high (the light-source-change telegraph). | Lantern-core `#FF6A2A`; eyes `#D24A3C` (brighter than the lantern on aggro). | `palette-stratum-2.md §5.5` Sunken-Scholar — full spec + seed. |
| **BoneCatalyst** (melee bruiser) | A scholar who tried to *understand* the seam instead of study it and became their own reliquary — bone-fetish forearms made of other scholars' bones. | Hunched bruiser with **both forearms wrapped in bound bone** + brass skull-mask (channel-wind-up double-arm-cross telegraph). | Brass mask eye-holes `#D24A3C`; (rest-ember in the channel-pose flare). | `palette-stratum-2.md §5.5` Bone-Catalyst — full spec + seed. |
| **ArchiveSentinel** (S2 boss) | The order's **last construct-guardian**, built to protect the books, still doing its job centuries after there's anything left to protect. (Merged PR #374; phase-1 cast-bolt visual added PR #380.) | Construct-guardian mass (not a corrupted human — a *thing the dead built*); the contrast within S2. | Per `palette-stratum-2.md §5.5` Archive-Sentinel entry + the `ArchiveSentinelCastBolt` cosmetic (`combat-architecture.md` § "Invisible-attack bug class"). | `palette-stratum-2.md §5.5` Archive Sentinel; `combat-architecture.md`. |

---

## §4 — Forward bestiary sketch (S2-S8 families, LIGHT)

2-3 creature concepts per stratum — **name + hook only**, anchored to the `visual-direction.md` 8-stratum hue/saturation/ember table + `palette.md` per-stratum entries. Not full design; these are seeds for future per-stratum design tickets (each stratum gets its own, modeled on `palette-stratum-2.md §5.5`). Every concept obeys: place's-dead lore + one hook + an ember tell + VD-13 outline.

| S | Biome (who died here) | Creature concepts (name — hook) |
|---|---|---|
| **2** | Cinder Vaults — scholars who read the seam | *(authored — §3.2)* Sunken-Scholar (lantern-staff) · Bone-Catalyst (bone forearms) · Archive Sentinel (construct guardian). |
| **3** | Drowned Reliquary — the pre-cloister dead, buried before the order, now flooded (`palette.md` S3) | **Drowned Penitent** — the S1 grunt silhouette returns, *soaked* (teal-retint OK per `palette.md` S3 sprite-reuse) — bloated robe, water-logged stoop · **Reliquary-Drifter** — a half-submerged ossuary-thing trailing grave-silt, drifting not walking · **Tarnished Bell-Keeper** — a ranged caster who rings a cracked bronze relic-bell (sonic ember-pulse; bell-glow `#FF6A2A` reflected double in the standing water). Ember: a single warm hot-spot in the cold teal, doubled in the floor-reflection. |
| **4** | Hollow Foundry — the machines' tenders, slagged into the works (`palette.md` S4) | **Slag-Stoker** — a forge-worker fused waist-deep into a still-pumping bellows-machine, dragging the machine as he moves (the half-man-half-mechanism hook) · **Channel-Wader** — a thing that walks the molten channels, ember-camouflaged, only its `#D24A3C` eyes betraying it against the amber (the S4 "ember blends in" hazard made into a stealth-creature) · **Bellows-Hauler** — heavy melee, an arm replaced by a riveted iron piston. Ember: an open forge-grate glowing in the chest where the man met the machine. |
| **5** | Bonemeal Reach — the cult of monks who tried to commune with the wrongness (`palette.md` S5: "what S1's monks turned into") | **Reach-Cultist** — S1 grunt silhouette again (retint OK per `palette.md` S5; diegetic: literally former-S1-monks), chartreuse-sick cloth, chitin growths · **Marrow-Sigil Acolyte** — ranged; carves a glowing `#7438AC` sigil mid-air before casting (sigil-violet telegraph) · **Chitin-Husk** — a bruiser wearing the biome (chitin-armor `#7A6F4D` = the bone-vein hex; "the cultists wear the biome"). Ember: the `#FF6A2A` reads as *clean fire against unclean ground* — purifying contrast (S5 maximizes ember legibility). |
| **6** | Magmaroot Hollows — things that reached the source-system and were claimed by it (`palette.md` S6) | **Magmaroot Beast** — NEW quadruped (charger's larger magma-cousin per `palette.md` S6 sprite-reuse); molten-skin `#E04D14`, bleeds ember-light · **Root-Welded Thrall** — a humanoid fused into a root-vein trunk, half-rooted-in-place, lashing out (the "partly the substance" hook) · **Ember-Bleeder** — fast melee that leaves a fading ember-trail. Ember: kindred-but-DOMINANT — these mobs *bleed* ember; disambiguate from environmental vein-cores by silhouette-attachment + pulse (S6 ember-spatial rules). |
| **7** | Ash Cathedral — those who crystallized against the shell, dangerous-beautiful (`palette.md` S7) | **Glassbearer** — spatially-camouflaged against obsidian until it moves (cool-blue cloth `#1A2530` ≈ wall; the glass-rim `#5C7A88` + `#D24A3C` eyes break it off the dark) · **Shard-Caster** — ranged; flings cyan-glass `#35C2D0` shards · **Cathedral Acolyte** — slow processional melee. Ember: the `#D24A3C` aggro-eye is the *brightest warm pixel on screen* in this near-monochrome cool field — this stratum showcases why the cross-stratum aggro contract matters (max mob legibility). |
| **8** | Heart of Embergrave — what the source makes of anything that reaches it (`palette.md` S8) | **Source-Charred** — near-black-charred humanoid `#1A0606`, full-saturation ember-bleed `#FF6A2A` (mobs at the source ARE the substance) · **Seam-Born** — a thing that detaches from the ember-cracked wall and re-forms · **the Final Boss** — its OWN design ticket; the ONE creature whose eye-glow overrides to white-hot `#FFE6C0` (`palette.md` S8 boss-final override). Ember: *the ember IS the world* — the player's flame and the environment are revealed to be the same substance; the bestiary's through-line pays off as the player and the dead finally share one light. |

**Sprite-reuse leverage** (from `palette.md` per-stratum hints, surfaced for the production roadmap): the **hooded-penitent silhouette** (grunt) returns retinted at S3 (drowned), S5 (cultist) — so the grunt rig is the single most-reused humanoid base. The **charger quadruped** retints/reauthors at S6 (magma-beast). The **shooter/caster** archetype recurs every stratum with a stratum-specific light-source-change telegraph (brazier → lantern → bell → sigil → shard). This means the **pilot S1 rigs (§6) are the templates the whole arc rotates from** — a strong argument for getting them right first.

---

## §5 — The "popular / appeal" rationale (reference-shelf citations)

Why "the monsters are the place's dead" + the four craft rules produce a bestiary players remember and like — grounded in `visual-direction.md`'s reference shelf:

- **Hollow Knight / Dark Souls / Blasphemous** (the principle's proof): the genre's most-praised bestiaries all share the player's predicament with the monsters. Corruption-of-the-familiar > novelty-monster-zoo. Embergrave's "the dead were consumed by the flame you seek" is the same well-validated engine, and it's *already* how the strata read — this doc just makes it doctrine.
- **Hyper Light Drifter** (`visual-direction.md`): saturated accent on a desaturated ground; single warm light source. The ember-tell-on-every-creature is the literal application — each mob is "the warm accent" against its stratum's desaturated field, peaking at S7 (the most-cinematic single-warm-on-cold).
- **Sergio Toppi + Mike Mignola** (`visual-direction.md`): restraint-on-characters / density-on-environments (craft rule 3) and black-shadow + warm-accent illustration logic (the ember tell + 1px outline). This is *why* the silhouette-first rule isn't just functional — it's the project's stated illustration aesthetic.
- **Dark Souls 1 environment art** (`visual-direction.md` "vertical decay; deeper = older = angrier"): the descent-narrative + "the place's dead get older/stranger as you go down" — the bestiary's per-stratum escalation rides the same instinct.
- **Anti-references honored** (`visual-direction.md`): NOT glossy 3D-prerender (Diablo III), NOT cute pixel (Stardew), NOT heavy-outline cel-shade (Cuphead). Our creatures are dark-fantasy, bold-but-not-cartoony, one-pixel-outline-not-thick. The "popular" we're chasing is *Hollow Knight / Blasphemous memorable-dread*, not *mascot-cute* and not *AAA-photoreal*.
- **Production-popularity (the team-scale argument, `visual-direction.md`):** a 2-dev part-time team. The "place's dead" doctrine + heavy silhouette-reuse (grunt rig → 3 strata) is what makes a memorable 8-stratum bestiary *authorable at all*. Crystal Project is the cited proof a small team can hand-author a beautiful multi-region crawler — and it did it on disciplined reuse, exactly this plan.

---

## §6 — PixelLab production recipe

Per `.claude/docs/pixellab-pipeline.md` (orchestrator-session-only; the orchestrator runs gens, this doc is the design).

### §6.1 Mode / size / view

- **View:** **low top-down** to match the existing 68 px rig (the player + S1 mobs were authored this way; `pixellab-pipeline.md` "low top-down view"). All regeneration matches it for roster consistency.
- **Size (match the existing roster, NOT a literal px-count in this doc — `pixellab-pipeline.md` "Project roster scale doctrine"):**
  - Humanoid mobs (grunt / charger / shooter / stoker / practice_dummy / SunkenScholar / BoneCatalyst) → **`size=48`** (→ 68×68 canvas).
  - Bosses (Stratum1Boss / ArchiveSentinel) → **`size=56`** (→ 80×80 canvas).
  - Player → **`size=48`** (match existing rig).
  - **Before any `create_character`:** confirm the canvas size of the closest existing analog in the PixelLab account and match (the documented Sunken-Scholar `size=32` miscall is the cautionary tale — "32 px standing height" in a doc is the dimension FLOOR, not the target).
- **Quality mode:**
  - **v3 highest-quality, 8-direction** for the **hero + every named mob** (player, grunt, charger, shooter, Stratum1Boss, SunkenScholar, BoneCatalyst, ArchiveSentinel, and each future stratum's named creatures). These are the memorable silhouettes; they deserve the gen budget. (Standard `create_character` is the default cost; reserve pro/custom for boss-tier per `pixellab-pipeline.md` cost model + Sponsor approval >40 gens.)
  - **Standard** for **crowd variants** (palette-retint swarm mobs, the Stoker-as-grunt-retint M3 ship, the "same silhouette deeper down" reuse cases) — these ride doctrine-lock retints (`pixellab-pipeline.md` Strategy 4 luminance-band) off an already-authored base, not fresh hero-quality gens.

### §6.2 Doctrine-lock approach (per `pixellab-pipeline.md`)

- **Fresh hero-quality gen → first doctrine-lock:** Strategy 3 (per-slot nearest-neighbor + manual character-beat overrides). Always manually verify the **two never-retint beats survive**: aggro eye-glow `#D24A3C` and the ember tell `#FF6A2A` (the pipeline doc's worked examples are exactly these — don't let Euclidean NN route the red eye into cloth-brown).
- **Doctrine-locked sprite → retint to sibling stratum** (grunt → S3-drowned, grunt → S5-cultist, etc.): Strategy 4 (luminance-band role routing + character-beat HSV overrides). This is the validated cross-stratum path (`bake_stoker_palette.py` precedent).
- **Player → NO doctrine-lock, ever.** Doctrine-EXEMPT; ship PixelLab-raw (blue eyes + homespun palette intact). The single most-important exemption to honor — running him through S1 doctrine-lock is the documented blue-eye-erasure error.
- **Prompt discipline:** lead with the ONE hook as the first noun (silhouette dominance); demote the hood/obscuring constraints to setting context (eyes-first per the Grunt-v1→v2 lesson); doctrine skin/body hex in-prompt land reliably, accent hexes don't (post-process the ember/eye accents).

### §6.3 Pilot-first rollout (the recommended order)

The bestiary's silhouette-reuse (§4) means the S1 rigs are templates for the whole arc. Get them right before scaling:

1. **Player rig FIRST** — the locked hero (bald/pale/blue-eyed/homespun, doctrine-exempt). He's the tonal anchor + the contrast control + the equipment-layer base. Validate the 8-dir + walk/attack/dodge/hit/die set against the existing `idle_s.png` + concept before anything else. *(Note: PixelLab template animations can flip facing / swap hand-objects mid-cycle — per `pixellab-pipeline.md`; the weaponless base helps, and the weapon-in-hand layer is separate, which sidesteps the hand-swap trap.)*
2. **S1 mobs** — grunt → charger → shooter (the three must read as three distinct silhouettes; this is the silhouette-first acceptance gate). Then the practice_dummy (cheapest; non-hostile prop).
3. **S1 boss** — Stratum1Boss (Warden) at `size=56`; mass-silhouette + slam telegraph already wired (`combat-architecture.md` PR #291).
4. **S2+** — SunkenScholar / BoneCatalyst (seeds locked in `palette-stratum-2.md §5.5`) → ArchiveSentinel polish → forward strata (§4 seeds → per-stratum design tickets).

Each pilot stage is a **Sponsor-judge-in-context gate** (per `judge-first-of-class-art-in-context` — first-of-class art judged rendered IN-GAME at game zoom, never isolated swatches). The player rig + first three S1 mobs especially: Sponsor soaks them in a room, not as a sprite sheet.

---

## §7 — Sponsor-decision surface

The calls Sponsor should veto or approve. Everything above is authored against the recommended shape; these are the redirect windows.

1. **The bestiary doctrine: "the monsters ARE the place's dead."** RECOMMEND APPROVE — it's on-lore (already how S2-S8 read), proven-popular (Hollow Knight/Souls/Blasphemous), and a free roster-generator for every future stratum. Sponsor veto would mean a different bestiary organizing principle (generic fantasy fauna / a roaming monster-manual) — not recommended.
2. **The S1 recast fiction** — grunt = cloister penitent, charger = ossuary-thing, shooter = brazier-warden, boss = the Warden. RECOMMEND APPROVE. This is the only *new* lore in the doc (S2-S8 already locked). Sponsor can redirect any of the four hooks; they're independent.
3. **Ember-on-every-creature (craft rule 4) + ember-FREE player + ember-FREE hub NPCs.** RECOMMEND APPROVE — the load-bearing contrast (corrupted dead glow; the living don't, yet). Sponsor veto here would weaken the whole contrast thesis.
4. **The forward S2-S8 family seeds (§4)** — light sketches only. Sponsor can approve as a direction or flag any stratum's concepts for redirect when that stratum's design ticket lands. Low-stakes (not buildable yet).
5. **PixelLab budget shape:** v3-highest-quality 8-dir for ~11 named creatures (hero + 10 named mobs across S1-S2) + standard retints for crowd/reuse. RECOMMEND APPROVE the pilot-first order; Sponsor controls the gen spend at dispatch time (orchestrator runs the gens). Any single call >40 gens (pro/custom) returns to Sponsor per the cost-model rule.
6. **Player visible-equipment approach** (rags→light→medium→heavy + weapon layer). RECOMMEND APPROVE as the DIRECTION; the full layer spec is a separate ticket. Sponsor confirms the tiered-look-swap intent so the player rig (pilot step 1) is authored with layer-separation in mind (weaponless + bald base, gear as overlays).

---

## Cross-references

- `team/uma-ux/visual-direction.md` — 8-stratum hue/sat/ember table; VD-13 1px-outline; reference shelf; animation-feel cadences.
- `team/uma-ux/palette.md` — per-stratum doctrine ramps; ember global-lock; aggro-glow PL-11; S3/S5 "former-monks" lore; sprite-reuse hints.
- `team/uma-ux/palette-stratum-2.md §1.5 + §5 + §5.5` — S2 "what the scholars became"; sprite-reuse table; Sunken-Scholar / Bone-Catalyst / Archive-Sentinel full specs + PixelLab seeds (this doc does NOT re-spec them).
- `team/uma-ux/world-map-direction.md §1` — cloister = record-keeping order; descent narrative; hub-NPC framing.
- `team/uma-ux/player-journey.md` — "the flame remembers" / "Find it"; ember-dissolve death; fistless start; tutorial-dummy beats.
- `.claude/docs/pixellab-pipeline.md` — execution context (orch-only); roster-scale doctrine; doctrine-lock strategies 3/4; prompt-literalism; canvas-size trap; cost model.
- `.claude/docs/html5-export.md` — HDR-clamp (sub-1.0 channels); Polygon2D rule (ColorRect for sweeps/cones, not Polygon2D); default-font glyph rule; visual-verification gate.
- `.claude/docs/combat-architecture.md` — AnimatedSprite2D state-anim wiring (M3W-1 PR #271 3-branch resolver + `HIT_FLASH_TINT`); gameplay roles; invisible-attack-bug class (every attack needs a visual).
- Memory `judge-first-of-class-art-in-context` — first-of-class art judged rendered in-context at game zoom.

---

## Non-obvious findings

1. **The player's LACK of ember is the bestiary's keystone, not a player-only detail.** Because the hero is the only warm-light-free humanoid on screen, every mob's ember tell reads instantly as "corrupted / not-you." Designing the bestiary's ember-through-line and the player's no-glow are the *same* decision — they must be approved together (§7 item 3).
2. **S1 had no unified bestiary fiction until this doc.** S2-S8 all read as "the place's dead" already (explicit in `palette.md`/`palette-stratum-2.md`), but S1's grunt/charger/shooter were authored as generic dark-fantasy mobs. The recast (§3.1) retroactively makes them the cloister's penitent/ossuary/warden dead — closing the lore gap so the whole 8-stratum bestiary shares one principle.
3. **The grunt (hooded-penitent) rig is the single highest-leverage sprite in the project.** It retints to S3 (drowned monk) and S5 (cultist) and is the silhouette-template the caster/charger archetypes echo. Getting the S1 pilot rigs right (§6.3) pays off across at least 3 strata — the strongest production argument for pilot-first.
4. **The hub NPCs are a deliberate ember-free CONTROL, not just flavor.** Keeping anvil-keeper/bounty-poster/vendor glow-free is what proves the "ember = corrupted dead" grammar by counter-example. A future art pass must NOT add aggro-glow or ember tells to them — that would break the visual thesis.
5. **The S2 archetypes were already authored to this doctrine before the doctrine was stated.** `palette-stratum-2.md §5.5` independently arrived at "lantern-core ember + `#D24A3C` eyes + place's-dead fiction" for Sunken-Scholar/Bone-Catalyst. This doc's contribution is naming the pattern and back-applying it to S1 — evidence the doctrine is the project's natural grain, not an imposition.
</content>
</invoke>
