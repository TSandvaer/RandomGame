# The Journey Arc — Milestone Roadmap Proposal

**Status:** PLANNING PROPOSAL — no ClickUp tickets created. This is a roadmap for the Sponsor to **shape, sequence, and prioritize**, not a committed plan. Milestone sizing is deliberately honest about scale (this is a large, multi-month arc); the Sponsor decides what ships, in what order, and where the line falls between "now" and "later."

**Author:** Priya (PL) · **Date:** 2026-06-07 · **Branch:** `priya/journey-arc-roadmap`

**Source of the vision (Sponsor, 2026-06-07 — captured this session):**
- *"The cloister is just the STARTING POINT of the journey. You proceed OUT of the cloister into the world, onto new adventures — to become MORE than a simple monk."*
- World content pillars: **landscapes, villages, dungeons, caves, castles, ruins** (and more) — a wide, varied, big/endless world.
- Feel: entering a world that's already ALIVE (NPCs, animals, vegetation, enemies, treasures), a JOURNEY through a mystical, wondrous world.

**Relationship to prior docs.** This elevates §3.5 ("the living-world / journey arc") of `team/priya-pl/s1-cloister-yard-scope.md` from *S1 context* into a *full-game milestone arc*. It sits above the M3 Tier 3 sequencing (`team/priya-pl/post-wave3-sequencing.md` v1.1) and the locked Diablo-shape directive (`[[m3-diablo-shape-directive]]`), reframing them as **the first leg of a much longer journey**. It does not re-decide anything those docs locked.

---

## 0. The arc in one paragraph

You begin as a monk in the **Outer Cloister** (S1 — in progress: assembler retrofit PR #421 merged; cobble-yard art + content in flight). You walk OUT of the cloister into a living world and travel through a sequence of varied locales — **wilderness landscapes, villages, dungeons, caves, castles, ruins** — each a biome with its own art, mobs, NPCs, and discoveries, growing from "a simple monk" into something more along the way. The world should feel **big, alive, and continuous** — entered, not loaded; journeyed through, not menu-selected. The good news: the **structural machinery for this already exists and ships today** — continuous-scroll camera, procgen FloorAssembler (now wired into S1 via PR #421), dialogue/NPC, combat, and quest systems are all live. The arc is therefore mostly **content + biome authoring on a proven foundation**, plus a focused set of genuinely-new *world-aliveness* systems (ambient animals, discoverable treasures, layered landscapes/vistas, character progression). The honest scale is **multi-month, multi-milestone** — this doc proposes how to slice it.

---

## 1. The arc, sequenced

The journey is a chain of **biome locales**, each reusing the same structural foundation (camera + assembler + combat + dialogue + quests) with new art, mobs, NPCs, and content. Rough sizing below is **per-biome calendar effort once the foundation + the first new biome are proven** — the first journey-out biome carries extra cost because it establishes the "leave the cloister, enter a new biome" pattern that every subsequent biome reuses.

| Leg | Locale | What it is | New-work driver | Rough size |
|---|---|---|---|---|
| **0** | **Outer Cloister (S1)** | The starting point. Open traversable cloister yard, monk's home. | *In progress* — cobble-yard art + first-slice content (see s1-cloister-yard-scope.md). | (in flight) |
| **1** | **The Way Out / first wilderness landscape** | The first step OUT — open countryside / wilderness biome connecting the cloister to the wider world. Establishes the "exit one biome, enter the next" seam + the first NON-cloister art set. | New biome art set; biome-transition seam; first ambient-life pass. **Pattern-setter** for all later biomes. | **L–XL** |
| **2** | **Village** | First settlement — NPCs, shops/services, a social hub. Leans hardest on the dialogue/NPC system + (new) commerce/services. | New biome art; NPC density; services layer (shop/rest/quest-board). | **L** |
| **3** | **Dungeon** | First enclosed dungeon — denser combat, loot, a contained "delve" beat. Closest in shape to existing S1/S2 stratum work. | New biome art; loot/treasure layer; combat density tuning. | **M–L** |
| **4** | **Caves** | Subterranean biome — tighter traversal, darkness/lighting feel, ambient-creature variety. | New biome art; lighting/atmosphere; new mob set. | **M–L** |
| **5** | **Castle** | A larger built structure — multi-area, set-piece encounters, narrative weight. | New biome art; larger set-piece authoring; likely a boss/elite beat. | **L** |
| **6** | **Ruins** | Ancient/mystical ruins — the "wondrous" feel concentrated; exploration-reward + lore. | New biome art; exploration-treasure density; mystical VFX/audio. | **L** |
| **+** | **"and more"** | The Sponsor named these as *examples*, not a closed list. The arc is open-ended by design. | Each additional biome ≈ one of the above once the pattern is set. | (per-biome) |

**Honest framing on total scale.** This is a **content-driven, multi-month arc** — on the order of the `[[m3-diablo-shape-directive]]` "~10–14 month middle-to-ship" envelope, NOT a sprint. Each biome is roughly an M3-Tier-3-stratum's worth of content effort (art + mobs + NPCs + quests + nav-gating + soak), and there are six-plus of them. The leverage point — and the reason this is tractable at all — is that **the systems are done**; what remains is *authoring biomes into proven systems* + a bounded set of new aliveness systems (§2). The roadmap's job is to make sure we never re-architect when we could author.

**Ordering note (Sponsor's to set).** The locale order above (wilderness → village → dungeon → caves → castle → ruins) is a *suggested* journey progression — gentle-open first, then a social beat, then escalating danger/depth. The Sponsor may reorder freely; the dependency that matters is **Leg 1 first** (it sets the biome-transition pattern), after which legs are largely independent and could even be resequenced by what art/feel the Sponsor wants to prove next.

---

## 2. What exists vs what's new

The single most important planning fact: **the hard structural systems are already shipped.** The arc is mostly content on top of them, plus a focused set of new *world-aliveness* systems.

### ✅ Exists today — reused per-biome, no new system work

| System | Status | Where it lives | How the arc reuses it |
|---|---|---|---|
| **Continuous-scroll camera** | ✅ Live | `CameraDirector.follow_target` + `set_world_bounds` (`.claude/docs/camera-scroll.md`) | Every biome scrolls across a wider-than-screen world via the same API. Already engaged on every S1 room load + S2 zone load. |
| **Procgen FloorAssembler** | ✅ Live, now with **S1 + S2 consumers** | `assemble_floor(zone_def, seed) → AssembledFloor` (`.claude/docs/procgen-pipeline.md`); S2 via `_load_s2_zone` (PR #391), **S1 via `_load_s1_zone` (PR #421, soak-gated)** | Each biome = a stratum's worth of ZoneDefs + chunks fed to the same assembler. The "big/endless" feel is structurally the multi-chunk `bounding_box_px` → camera path. |
| **Combat runtime** | ✅ Live | `.claude/docs/combat-architecture.md`; Grunt/Charger/Shooter rigged with PixelLab art | New biomes get new mob *art + tuning*, not a new combat engine. |
| **Dialogue / NPC system** | ✅ Live | DialogueController + DialogueTreeDef (`.claude/docs/dialogue-system.md`) | Villages + per-biome NPCs author new dialogue trees into the existing system. |
| **Quest / exploration system** | ✅ Live | QuestActionRouter + QuestDef/QuestState (`.claude/docs/quest-system.md`); bounty round-trip persisted | Per-biome quests bind to zones (geography), exactly the Diablo-shape model. New content, not new system. |
| **Save / world-seed** | ✅ Live (schema v5) | `Character.world_seed` round-trips (`.claude/docs/save-architecture.md`) | Per-character randomized biomes come "for free" once each biome derives seeds via the standard cascade. |
| **Audio (5-bus + Director)** | ✅ Live | `.claude/docs/audio-architecture.md`; S1→S2 entry triggers, boss crossfade | Each biome authors BGM/ambient into the existing crossfade pattern. |

### 🔴 Genuinely new — these are real systems work, not just content

| New pillar | Why it's new | Rough size | Notes |
|---|---|---|---|
| **Per-biome art sets** | Each locale (wilderness/village/dungeon/cave/castle/ruins) needs its own floor/wall/prop/mob/NPC art via the PixelLab pipeline. This is *content*, but it's the dominant cost line of the whole arc. | **Recurring L per biome** | Not a system — but the largest aggregate effort. Orch-driven PixelLab generation + Drew integration, per the established S1 shape. |
| **Biome-transition seam** | "Walk OUT of the cloister INTO the next biome" — a clean handoff between strata/biomes that *feels* like travel, not a level-load. S1→S2 has a descent portal today; a *lateral* "journey onward" seam is new design. | **M (once); reused after** | Establish in Leg 1; reuse for all later legs. |
| **Ambient animals / fauna** | Birds, critters, ambient creatures that make a world feel alive. No system today. Needs a lightweight ambient-actor system + per-biome creature art. | **M (system) + S per biome (art)** | The cheapest *aliveness* win per effort — recommend early. |
| **Discoverable world treasures** | Pickup/Inventory mechanics exist, but *discoverable* world treasure (chests, hidden caches, reward-for-exploration) is a new content + placement + reward-surfacing layer. | **M (system) + S per biome (placement)** | Ties into the quest/reward pipeline; pairs naturally with the dungeon/ruins legs. |
| **Layered landscapes / vistas / distance** | The world is a flat top-down floor today — no parallax, backdrop, or depth cue. "Landscapes, distances" implies a sense of a world extending to a horizon. Materially new rendering work (parallax/backdrop layers under `gl_compatibility`). | **L–XL** | **The biggest new pillar** and the riskiest (HTML5 renderer surface). Recommend deferring until the journey *structure* is proven; it's a feel-multiplier, not a blocker. |
| **Character progression ("monk → more")** | The Sponsor's "become MORE than a simple monk" — a progression arc (stats/abilities/class growth) that makes the journey feel like growth, not just traversal. XP/reward payloads exist on QuestDef; a *progression system* that consumes them is new. | **L** | See §5 open question — where this slots is a real strategic fork. Could be a thin per-biome power-gain or a full ability/skill system. |
| **"Mystical / wondrous" feel** | Cross-cutting art + audio + lighting direction, not a discrete system — but the ruins/caves legs lean on it, and deeper VFX/lighting is new work. | **Cross-cutting** | Uma carries this through every biome; deeper lighting/VFX systems are their own optional lift. |

---

## 3. Structural enablers — why this is tractable

**The procgen-assembler + continuous-scroll path is the foundation that makes a multi-biome world tractable** — and as of PR #421 it now reaches S1, not just S2. This is the load-bearing structural fact of the whole roadmap.

### What generalizes from the S1 retrofit to every future biome

PR #421 (`_load_s1_zone`, soak-gated) and PR #391 (`_load_s2_zone`) together establish the **reusable biome-boot pattern**:

1. **The biome-boot shape is now a proven, copyable template.** Both S1 and S2 boot through `assemble_floor` via near-identical `_load_<stratum>_zone` paths that share render helpers (via the `wire_combat` flag + container param introduced in #421). A new biome is "another `_load_<biome>_zone` that iterates its ZoneDefs and feeds `bounding_box_px` to the camera" — not net-new architecture. The asymmetry that existed before #421 (S2 assembler-driven, S1 static) is closed; the pattern is now symmetric and replicable.
2. **The camera consumes `bounding_box_px` generically.** `_engage_camera_for_room()` is biome-agnostic — it follows the player and clamps to whatever bounds the assembled floor reports. Every biome's "scroll across a big world" comes free from this.
3. **Seed-cascade gives per-character variation per biome for free.** `derive_stratum_seed` → `derive_zone_seed` is biome-agnostic; each new biome gets its own stratum id and inherits deterministic per-character randomization (the Diablo Commitment 5) with zero new seed code.
4. **Port-mating discipline + navigability gating are established practices.** The chunk-mating model + the grunt-radius-expanded BFS nav gate (the #417 wedge lesson) are reusable acceptance gates for every biome's traversal.
5. **The soak-gated additive retrofit pattern de-risks every cut-over.** #421 added the assembler path behind `?s1_assembler=1` without disturbing the default boot — a template for shipping risky biome plumbing *additively* and cutting over only when content is ready.

### The two known structural gaps that every biome inherits (NOT new per biome — fix once)

Both S1 and S2 currently share two deliberate skeleton gaps (`.claude/docs/procgen-pipeline.md`):

- **`AssembledFloor.mob_spawns` has no runtime consumer yet** — the assembler populates spawns correctly, but the render path doesn't yet instantiate mobs from them. **Fix once in the shared render helper → every biome benefits.**
- **No chunk-clear gate** — zones auto-advance with no `_chunks_remaining == 0` guard. **Fix once → every biome gets room-by-room progression.**

These are the **highest-leverage early systems tickets** in the whole arc: they're shared by S1 + S2 today and by every future biome, so fixing them once unblocks the "play through a populated biome room-by-room" experience everywhere. They belong in the *next* milestone, before biome content scales.

### The one structural unknown the biggest-new-pillar depends on

**Layered landscapes/vistas/distance** is the one pillar with NO existing structural enabler — the world is a flat top-down floor with no parallax/depth layer. This is why §2 sizes it L–XL and §5 recommends deferring it: it's the only pillar that requires net-new *rendering* architecture (and carries HTML5/`gl_compatibility` risk), versus the rest of the arc which composes proven systems.

---

## 4. Milestone grouping proposal

Grouped for the Sponsor to **prioritize and sequence**. Each milestone is a coherent shippable/soakable increment. Sizes are rough calendar bands, honest about scale.

| Milestone | Theme | Contents | Rough size | Gating decision |
|---|---|---|---|---|
| **M-next** | **Finish S1 cloister-yard** | Complete the in-flight cloister-yard: cobble+moss+dirt floor, wall rescale, sparse decoration, first yard slice on the assembler path, navigability gate, chunk-extension toward "endless." (= the s1-cloister-yard-scope.md T0–T7 workstream.) | **Current milestone** | Already in flight; finishes the *starting point*. |
| **M-foundation** | **Make biomes playable end-to-end (fix-once enablers)** | Close the two shared skeleton gaps (`mob_spawns` runtime consumer + chunk-clear gate) so any assembled biome plays room-by-room with real combat. Establish the **biome-transition seam** + the **ambient-animals system** (cheapest aliveness win). This is the "the foundation is now content-ready for ANY biome" milestone. | **M–L** | Highest leverage — do before scaling biome content. |
| **M-journey-1** | **The Way Out — first journey-out biome (wilderness landscape)** | The first step OUT of the cloister: the first non-cloister biome, the pattern-setter for all later biomes. New art set, mobs, NPCs, first exploration quests, ambient life. Proves "leave one biome, enter the next, the world is alive." | **L–XL** | The make-or-break feel proof. Sponsor soaks the "journey" read here. |
| **M-progression** | **Monk → more (character progression)** | The progression system that makes the journey feel like growth. Could ship thin (per-biome power-gain) or full (ability/skill tree). **Where this slots is a strategic fork — see §5 Q2.** | **L** | Could fold into M-journey-1 (thin) or be its own milestone (full). |
| **M-biomes-A** | **Village + Dungeon** | Two more biomes. Village leans on dialogue/NPC + a new services/commerce layer; dungeon leans on combat density + the discoverable-treasures system (built here). | **L–XL** | Per-biome content scaling begins. |
| **M-biomes-B** | **Caves + Castle** | Two more biomes. Caves introduce lighting/atmosphere feel; castle introduces larger set-piece + likely a boss/elite beat. | **L–XL** | Continues the chain. |
| **M-biomes-C** | **Ruins + "and more"** | The mystical/wondrous payoff biome (ruins) + the open-ended additional biomes the Sponsor named as "and more." Exploration-treasure density peaks here. | **L+** (open-ended) | The arc is open by design — this milestone is "as long as the journey wants to be." |
| **M-vistas** | **Layered landscapes / vistas / distance** | The biggest new *rendering* pillar — parallax/backdrop/depth so the world reads as extending to a horizon. Deferrable; a feel-multiplier applied across biomes once the journey structure is proven. | **L–XL** | **Defer-recommended.** High new-architecture cost + HTML5 risk; not a blocker for the journey to *exist*. Sponsor decides whether/when. |

**Why this grouping.** It front-loads the **highest-leverage shared work** (M-foundation: fix-once enablers + cheapest aliveness + transition seam) *before* biome content scales, then proves the journey feel on **one** biome (M-journey-1) before committing to the full biome chain. Progression and vistas are pulled out as their own milestones because they're the two genuine strategic forks (§5) — the Sponsor may want progression earlier (it's core to "become more") and vistas later (it's the riskiest new system). Biomes-A/B/C are deliberately coarse: once the pattern is proven, biome cadence is a content-throughput question the Sponsor sequences by what feel they want next.

---

## 5. Risks + open strategic questions

### Open strategic questions (Sponsor decides — NOT pre-decided here)

1. **Biome order + scope.** Is the suggested order (wilderness → village → dungeon → caves → castle → ruins) right, or does the Sponsor want a different journey shape? And is each biome a *full stratum's worth* of content, or lighter "passage" biomes between bigger set-piece ones? (Recommend: Leg 1 first as the pattern-setter; reorder the rest freely; mix heavy + light biomes so the journey has rhythm.)
2. **Where does character progression ("monk → more") slot — and how deep?** Three shapes: (a) **thin** — small per-biome power gains folded into M-journey-1, cheapest, makes the journey feel like growth without a big system; (b) **full** — a real ability/skill/class system as its own M-progression milestone, higher cost, deeper RPG feel; (c) **deferred** — ship the journey first, add progression once biomes prove out. (Recommend: at least (a) early — "become more" is core to the Sponsor's framing, so *some* growth should be felt by the first journey-out biome; reserve (b) full system for when the Sponsor wants the RPG depth.)
3. **How "endless" / how big?** Same fork as the S1 scope doc, now at full-arc scale: is the world a **finite-but-large** chain of authored+procedural biomes that *reads* endless (long traversal, off-screen continuation, no hard edges), or **truly-unbounded** streaming/infinite generation? (Recommend: finite-large-that-reads-endless — it satisfies the "big, journeying" feel at a fraction of the systems cost; reserve true-infinite for far later, if ever.)
4. **When (if ever) do the landscapes/vistas/distance pillar?** It's the biggest new *rendering* lift and the only pillar with no existing structural enabler + real HTML5 risk. Defer to M-vistas (recommended), pull earlier as a feel-priority, or descope to "no parallax, the top-down floor is the world"? (Recommend: defer — prove the journey structure first; vistas are a feel-multiplier, not a blocker.)
5. **How much aliveness in the first journey biome?** Ambient animals + discoverable treasures are new systems. Do they ship in M-foundation/M-journey-1 (so the first journey biome already feels alive), or layer in later? (Recommend: ambient animals early — cheapest aliveness-per-effort; treasures with the dungeon leg where they pay off most.)

### Risks

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| **R-ARC-1** | **Scope is genuinely milestone-stacking-large.** Six-plus biomes, each ≈ a stratum of content, plus new aliveness systems = a multi-month-to-year arc. Underselling it sets false expectations. | **High** | This doc states the scale honestly (§1, §4). The Sponsor sequences; we ship one biome at a time and soak the journey feel before committing the full chain. Don't author all biomes before proving Leg 1. |
| **R-ARC-2** | **Per-biome art is the dominant recurring cost** and orch-only (PixelLab MCP). Art throughput, not engine work, is the real pacing constraint. | **High/Med** | Treat biome art as the critical path; build the asset pipeline cadence (per `[[sub-agent-mcp-tool-surface-scope]]` — orch generates, Drew integrates). Sequence biomes by art readiness. |
| **R-ARC-3** | **The two shared skeleton gaps (`mob_spawns` + chunk-clear) block "playable biome" everywhere** until fixed. Scaling biome content before fixing them yields beautiful empty walkthroughs. | **Med/High** | M-foundation fixes them ONCE in the shared render helper before biome content scales. They're the highest-leverage early tickets. |
| **R-ARC-4** | **Landscapes/vistas/distance is net-new rendering with HTML5/`gl_compatibility` risk** (parallax/z-index under WebGL2 — the same risk class as the chunk-seam concerns in `.claude/docs/camera-scroll.md`). | **Med/High** | Defer (M-vistas); when it lands, mandatory HTML5 visual-verification gate + author self-soak. Don't let it block the journey existing. |
| **R-ARC-5** | **Character progression is under-specified** — "become more" spans a one-liner power-gain to a full skill system. Ambiguity here can balloon or under-deliver on a core Sponsor framing. | **Med/High** | §5 Q2 forces the Sponsor to pick depth (thin/full/deferred) before M-progression is scoped. Recommend at least thin growth felt by the first journey biome. |
| **R-ARC-6** | **Biome-transition seam ("walk OUT into the next biome") is new design** and sets the journey-feel tone. If it reads like a level-load, the "journey" promise breaks. | **Med** | Establish it deliberately in M-foundation/M-journey-1 with a Sponsor feel-soak; reuse the proven seam for all later legs. |
| **R-ARC-7** | **"Endless/big" tempts toward truly-unbounded streaming** — a milestone-sized systems lift that the *feel* likely doesn't require. | **High** | §5 Q3 bounds it before any biome is built to "infinite." Default-recommend finite-large-that-reads-endless. |

---

## 6. DECISIONS.md draft entry (NOT yet appended — for the next Monday batch)

> **Decision draft (2026-06-07):** The game is framed as a **journey arc** — the Outer Cloister (S1) is the *starting point*, from which the player travels OUT through a chain of varied biome locales (wilderness/landscapes → village → dungeon → caves → castle → ruins, "and more"), growing from a simple monk into more along the way, in a world that feels big, alive (NPCs, animals, vegetation, enemies, treasures), and continuous. The arc is **content-on-a-proven-foundation**: continuous-scroll camera, procgen FloorAssembler (now wired into S1 via PR #421 as well as S2), combat, dialogue/NPC, quest, save/world-seed, and audio systems are all shipped; the biome-boot pattern (`_load_<stratum>_zone` + shared render helpers) generalizes per-biome. **Genuinely-new work** is bounded to: per-biome art (dominant recurring cost), ambient-animals, discoverable-treasures, layered-landscapes/vistas (biggest new rendering pillar — deferrable), character-progression ("monk→more"), and the biome-transition seam. **Proposed milestone grouping:** M-next (finish S1 yard) → M-foundation (fix the two shared skeleton gaps + transition seam + ambient animals) → M-journey-1 (first journey-out biome, the pattern-setter) → M-progression → M-biomes-A/B/C (village/dungeon/caves/castle/ruins) → M-vistas (deferred). **Honest scale:** multi-month-to-year, within the `[[m3-diablo-shape-directive]]` ~10–14mo envelope. **Open (Sponsor strategic, NOT settled):** biome order/scope; progression depth + placement; "how endless/big"; vistas timing; aliveness-in-first-biome. **Foundation:** Sponsor journey vision 2026-06-07 (this session); elevates §3.5 of `s1-cloister-yard-scope.md`; sits atop `[[m3-diablo-shape-directive]]` + `post-wave3-sequencing.md`.

---

## 7. What happens next (process)

1. Orchestrator surfaces this roadmap + the §5 strategic questions to the Sponsor for sequencing/prioritization.
2. On Sponsor direction: the milestone grouping (§4) becomes the backbone for per-milestone backlogs; the immediate S1 cloister-yard workstream (s1-cloister-yard-scope.md) continues unchanged as M-next.
3. The DECISIONS draft (§6) lands in the next Monday Priya batch — NOT appended now.
4. This is a **roadmap proposal, not a committed plan** — nothing here creates tickets or locks scope until the Sponsor shapes it.
