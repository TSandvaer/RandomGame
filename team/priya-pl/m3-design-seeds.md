# M3 Design Seeds — Multi-Character / Hub-Town / Persistent Meta / Character-Art Pass

**Owner:** Priya · **Phase:** M2 W3 (design seeds; not design lock) · **Ticket:** `86c9uepzm` (W3-T12) · **Status:** v1.0 — Sponsor-input pending.

This doc is the **M3 framing scratch-pad** authored in M2 Week 3. It promotes the speculative `mvp-scope.md §M3` paragraph into four scoped sections that future M3 dispatches will draw from. **It is design seeds, not design lock.** Each section ends with a Sponsor-input items list — the recommended-call shape (per `sponsor-decision-delegation` memory) Priya proposes, and the call-outs that need Sponsor sign-off before any M3 ticket dispatches.

The fourth section — **character-art pass** — was **Sponsor-promoted on 2026-05-15** during the M2 RC soak ("when is it going to change from squares fighting squares to actual graphic?"). The original W2-T12 / W3-T12 scope was three sections (multi-character, hub-town, persistent meta-progression); §4 joins them as a co-equal heavyweight section. Sponsor's framing has lifted it from "M3 someday" to "Sponsor wants a costed roadmap before committing."

## TL;DR (5-line summary)

1. **Multi-character (§1):** save-slot expansion is M3 scope. Recommend 3 slots with shared stash (Diablo-II shape, not Hades single-character). Save-schema v5 implication: top-level `characters[]` array, `meta.shared_stash`. Class divergence is M3-deferrable to M4.
2. **Hub-town (§2):** stash-room evolves into a discoverable single-screen town with 2-3 NPCs (vendor, anvil/reroll, lore-giver). Anchor point between runs; no in-run access. Reuses `palette-stratum-2.md` soft-retint pattern for biome.
3. **Persistent meta (§3):** **Hades** (between-run currency + Heat) ∪ **Diablo II** (gear stash + character ladder) ∪ **Crystal Project** (low-fi exploration permanence). Recommend ember-shard currency from stratum kills, spent at the hub-town anvil for affix rerolls. NG+ Paragon track per `mvp-scope.md §M3` lifts here.
4. **Character-art pass (§4, Sponsor-promoted):** current "squares fighting squares" is mechanically sound but reads as placeholder. Recommend **32-bit pixel-art primary path** (Crystal Project / Octopath density) + **AI-generated-then-cleaned fallback**. **Cost-bracket NOT defensible without external estimate** — recommend Sponsor commissions ballpark from 2-3 pixel-art artists. Milestone-shape recommendation: **parallel track in M3** (not its own milestone) with stratum-by-stratum incremental ship + hex-block fallback safety net.
5. **Sponsor-input summary:** 11 sponsor-decision items across the four sections; 6 of those are big-shape calls (multi-slot count, hub-town size, NG+ vs Paragon vs both, art-pass milestone shape, art-pass primary style, art-pass external-estimate green-light). Five are smaller defaults the orchestrator can route if Sponsor signs the big shapes.

---

## Source of truth

This doc extends:

- **`team/priya-pl/mvp-scope.md` §M3** (frozen 2026-05-02) — the canonical M3 paragraph: "All 8 strata, T1–T6 gear, full affix pool (~40 affixes), crafting/reroll bench, bounty quest system, NG+ Paragon track, all bosses, all 12 mob archetypes, full music score, lore text completed." Multi-character, hub-town, and persistent meta were **not in v1** — they are M3-scope additions surfaced by `m2-week-3-backlog.md §W3-T12`. The character-art pass is a 2026-05-15 Sponsor promotion.
- **`team/uma-ux/stash-ui-v1.md`** — stash-room is the M2 surface that §2 hub-town evolves from. `stash-ui-v1.md §7 q4` ("Hub town / non-combat zone in M3+ — does the stash room generalize into a town hub, or stay a per-stratum chamber?") is the open question §2 answers.
- **`team/devon-dev/save-schema-v4-plan.md`** — current v4 save-schema shape. §1 multi-character + §3 meta-progression both imply v5 (and possibly v6) bumps. v4's additive-only rule (`§4.1`) constrains the v5 shape.
- **`team/uma-ux/palette.md`** + **`team/uma-ux/palette-stratum-2.md`** — palette doctrine. §4 character-art-pass aligns with the cross-stratum ember through-line and the soft-retint pattern W3-T3 establishes.
- **`team/decisions/DECISIONS.md` 2026-05-02 — M1 death rule** ("M2 introduces stash UI + ember-bag; M3+ may revisit"). §3 meta-progression decides what additionally persists in M3.
- **2026-05-15 Sponsor M2 RC soak observation:** "when is it going to change from squares fighting squares to actual graphic?" — the empirical trigger for §4. Tess's `m2-week-2-retro.md` Pattern 5 (HTML5 default-font tofu) is a related "the art surface matters" precedent.

The replaced indicative `mvp-scope.md §M3` paragraph stays in force as the **content-scope contract** (8 strata, T1-T6, ~40 affixes, NG+, etc.); this doc adds the four orthogonal M3 design axes (multi-character / hub-town / persistent-meta / art-pass) the paragraph didn't anticipate.

---

## §1 — Multi-character

### Shape

Multi-character means the save file holds **N character slots**, each with their own level / XP / stats / equipped / inventory / ember-bags, sharing a **single stash pool** across the slots. The player picks a slot at title-screen → New Game; subsequent loads pick the slot to resume.

This is the **Diablo II shape**, not the Hades / Crystal Project shape (those are single-character — Hades by design, Crystal Project by content-scope). Diablo II's shared stash + character-ladder is the durable pattern; Path of Exile inherits it; Diablo IV inherits it; Last Epoch inherits it. **The shape is well-validated in the ARPG genre.**

### Recommend — 3 slots with shared stash

**Slot count:** **3** (Diablo-II-baseline; Path of Exile's first-decade default was 4-8). Three is enough for the player to maintain a "main + alt + experiment" psychology without slot-management becoming a UI burden. Six is overkill for M3; one is too few once the player wants to try a different build mid-soak. **Sponsor-input item:** could go 2 (tighter) or 4-6 (looser) — design defaults to 3.

**Shared stash across slots:** **YES.** The stash is a **player-account-scoped** pool, not a per-character pool. This is the value of multi-character at all — your main character finds a great drop that's wrong for them; your alt character benefits. Per-character-scoped stashes are a known mistake (Diablo II's early-1.x patches had it; was changed because nobody used alts).

**Per-character ember-bag continuity:** ember-bags from one character do NOT carry to another. They're per-character mortal stakes; if your main character dies in S3 and you load your alt, the bag waits. This honors the `stash-ui-v1.md` ember-bag pattern.

**Class divergence:** Recommend **deferred to M4** — M3 ships three slots of the same "warrior with edge-stat focus" class. Diablo II shipped its three slots as three classes (Barbarian / Necromancer / Amazon at launch); Path of Exile shipped 6+; Hades shipped 1. Embergrave's M3 scope at `mvp-scope.md §M3` is already content-heavy (8 strata + ~40 affixes + crafting + bounties + NG+); **adding 3 classes** in M3 doubles the balance burden and the QA matrix. **Sponsor-input item:** Sponsor may want class divergence to be the M3-headline feature (e.g., a magic-edge class + a defense-focused class). Recommend Sponsor sign off if they want this; default is "three slots = three save files of the same class shape."

**Starting-inventory variance:** **NO** — every slot starts identically (no class, no starter weapon, fistless cold-boot per `Inventory` rules). If class divergence comes in (M4), the starter-inventory shape per class would be a parallel design call.

### Save-schema implications (v5)

Current v4 (per `save-schema-v4-plan.md`) has `data.character` as a single Dictionary, with `data.equipped` at root. v5 needs:

```
data:
  characters:
    [
      {
        slot_index: 0,
        name: String,
        level / xp / stats / ...  (all current character keys)
        equipped: Dictionary   (moves from root → per-character)
        ember_bags: Dictionary (already under character. per v4)
        stash_ui_state: Dictionary
      },
      { slot_index: 1, ... },
      { slot_index: 2, ... }
    ]
  active_slot: int             (which character is currently being played)
  shared_stash: Array          (the ex-character.stash, lifted to root, shared across slots)
  meta:
    runs_completed: int        (cross-character aggregate?)
    deepest_stratum: int       (cross-character — "the player went here")
    total_playtime_sec: float
```

Three structural changes from v4:

1. **`character` → `characters: Array`** — non-additive (type change). Migration v4 → v5 wraps the existing `data.character` into `data.characters[0]` with `slot_index: 0`. v3 → v4 was additive-only (`save-schema-v4-plan.md §4.1` rule); **v5 violates the additive rule for the first time.** This is the schema-bump where Devon will need to commit to the v5-bump-with-migration-cost pattern.
2. **`equipped` lifts from root → `characters[N].equipped`** — same migration step.
3. **`character.stash` lifts from per-character → root `shared_stash`** — the v4 `character.stash` becomes the shared pool. Migration: `data.shared_stash = data.character.stash` (i.e., the single existing character's stash becomes the shared pool; subsequent slots start empty). Item-id collisions don't exist (stash items have UIDs).

**Open question for Devon:** Should v5 keep `data.character` as a compat shadow (Diablo II's "legacy char1" pattern) or fully remove it? `save-schema-v4-plan.md §4.1` rule 3 ("never delete a field while any version-N reader exists") would keep it as `data.characters[0]` AND as `data.character` (pointer-style). Recommend pointer-shadow for one schema generation, then delete at v6. **Sponsor-input item (technical):** Devon-call, not Sponsor-call; flag here so the v5 dispatch brief includes it.

### Caveat — design seed, not design lock

The 3-slot count, shared-stash YES, class-divergence NO calls are recommendations grounded in genre precedent. They will likely survive Sponsor sign-off; if Sponsor wants different shapes (e.g., 1 slot or 6 slots, or class-divergent M3) the §1 spec adjusts without invalidating §2/§3/§4. The save-schema implications change ONLY if slot count or stash-sharing changes (class divergence does NOT touch save shape — it touches content TRES files).

### Sponsor-input items (§1)

1. **Slot count: 3 vs alternative** — default is 3 (Diablo-II baseline). Sponsor may want 1 (Hades-style single-protagonist) or 6+ (PoE-style). **Recommended:** 3.
2. **Class divergence in M3 vs M4** — default is M4 (3 slots = 3 saves of one class). Sponsor may want M3 to be the headline class-divergence milestone. **Recommended:** M4 (M3 is already content-heavy; class divergence is its own headline).
3. **Shared stash across slots: YES/NO** — default is YES (Diablo-II / PoE / D4 standard). **Recommended:** YES.

---

## §2 — Hub-town

### Shape

The hub-town is the **between-runs venue**: where the player loads their character, manages their stash, talks to NPCs, and chooses which stratum to descend into. In M2, the stash-room is a single chamber at every stratum's entry (`stash-ui-v1.md §1`). In M3, the stash-room **evolves into a town**: still single-screen / single-chamber-feel, but with NPC pawns, vendor surfaces, and biome-decoration that reads as "civilization, post-disaster."

The `stash-ui-v1.md §7 q4` open question ("does the stash room generalize into a town hub, or stay a per-stratum chamber?") is answered here as **generalize into one hub-town at the surface (S1 entry), with stratum-specific stash chambers preserved as auxiliary venues** (so a player descending to S2 still has stash access at S2-entry, but the canonical M3 venue is the surface hub).

### Recommend — single-screen hub-town with 3 NPCs

**Visual shape:** 480×270 internal canvas (matches `visual-direction.md`). Outer Cloister palette (S1 hex codes from `palette.md`) — the hub-town is **the Outer Cloister but populated**: monks tending braziers, an anvil station, a vendor pawn. Same tile language as S1 R1 (sandstone floor, cloister masonry walls); same ember-orange accents. Reuses sprite-reuse pattern from `palette-stratum-2.md §5` — most of the hub-town renders via S1 tiles and the existing brazier sprite; new authoring is the 3 NPC pawns + the anvil prop + the vendor stall prop.

**Three NPC anchors:**

1. **Vendor** — sells gear at fixed prices, buys excess. Diablo II "Charsi-style." Inventory rotates per-run (semi-random, tier-weighted by `meta.deepest_stratum`). NPCs is the hub-town's **economy sink** — gives ember-shard currency (from §3 meta) a place to go.
2. **Anvil / reroll bench** — affix rerolling. Per `mvp-scope.md §M3` "crafting/reroll bench" is M3 scope. The anvil is its physical surface. Costs ember-shard currency (sink #2). UI per `inventory-stats-panel.md` cell rendering; opens a focused modal showing the item being rerolled + current vs proposed affixes.
3. **Lore-giver / quest-poster** — bounty quest hand-out. Per `mvp-scope.md §M3` "bounty quest system" is M3 scope. The lore-giver is the bounty-board. NPCs gives the player a per-run task (e.g., "kill 3 Stratum 2 Stokers"); completion rewards ember-shards + lore-text snippets. Lore deepens M3's narrative spine without forcing in-stratum cutscenes.

**No combat in hub-town.** Same `stash-ui-v1.md §1` rule: `Engine.time_scale = 1.0`, no mobs, no hazards, ambient music at the menu-pad volume. Vignette at 20%.

**Descent point:** a stratum-selection portal at the south edge of the hub-town (replaces the M2 "Down to descend" door). Player walks up to the portal, gets a stratum picker (S1, S2, ... up to `meta.deepest_stratum`), confirms, descends. M3 lifts the per-stratum descent into a single hub-anchored UI surface.

**Per-stratum stash chambers preserved:** at S2 / S3 / etc. entry, the stash chamber from M2 still exists — same chest, same B-key, same 12×6 grid. The hub-town's stash is the **same shared pool** (see §1 shared-stash). Two affordances on the same data is the right trade-off — the hub-town is the canonical, but mid-descend stash access at S2/S3 entry is still valuable for resupplying.

### Recommend — town as run-anchor between stratum runs

The hub-town becomes the **psychological run-anchor**. M2's flow is "die → respawn → walk through stash chamber → descend." M3's flow is "die → respawn → load into hub-town → talk to NPCs → spend currency → check stash → confirm descent → choose stratum → descend." The hub-town is where the player **lives between runs**; the strata are where they **work**.

This is the Hades / Last Epoch / Diablo III shape. It is **not** the Crystal Project shape (Crystal Project has no central hub; the player is always exploring the open map). The hub-town shape matches Embergrave's roguelite-but-with-character-persistence framing (per `mvp-scope.md §M1` death rule + §M2 ember-bag pattern).

### Save-schema implications

Minor:
- `data.meta.hub_town_seen` — bool, first-visit hint-strip gate. Additive to v4/v5.
- `data.meta.deepest_stratum` — already in v4. Drives the stratum-selection portal's available options.
- Vendor inventory is **not persisted** — regenerated per-run from `meta.deepest_stratum` + RNG. Cheap, no schema impact.

Bigger:
- Bounty quest state — `data.active_bounty: { quest_id, target, progress }`. Additive. Per-character (so part of `characters[N]` in v5).
- Ember-shard currency — `data.characters[N].ember_shards: int`. Additive.

None of these are non-additive; v5's structural changes (§1) absorb them.

### Sponsor-input items (§2)

4. **Hub-town size: single-screen OR scrollable / multi-room?** Default is single-screen (matches `visual-direction.md` 480×270 logical canvas + zero-scrolling-UI rule). Sponsor may want a Hades-scale "House of Hades" with multiple sub-rooms (forge, lounge, training-yard). **Recommended:** single-screen for M3.0; multi-room is M4+ polish.
5. **NPC count: 3 vs more?** Default is 3 (vendor / anvil / bounty). **Recommended:** 3.
6. **Hub-town visual: Outer Cloister evolution OR new biome?** Default is "Outer Cloister populated" (cheap content; reuses S1 sprites). Sponsor may want the hub-town to feel **distinct** from S1 (e.g., a surface-village above the cloister). **Recommended:** evolution for cost; new biome is M4 polish.

---

## §3 — Persistent meta-progression

### Shape — Hades / Diablo II / Crystal Project hybrid

Persistent meta-progression is **what survives between runs** beyond the M1 baseline (character level + XP + equipped). The M2 stash + ember-bag is the first meta layer. M3 adds three more:

1. **Currency persistence (Hades-style)** — kills drop **ember-shards** (a soft currency, not gold). Shards persist on the character (not the run); spent at hub-town NPCs (vendor / anvil / bounty refresh). Hades's "darkness" + "obols" are the reference.
2. **Stash + character ladder (Diablo II-style)** — gear stash (M2 v4) plus character-level persistence (M1 contract) plus NG+ Paragon track (`mvp-scope.md §M3`). The Diablo II "I have characters of level X / Y / Z and a shared stash" psychology is the durable shape.
3. **Low-fi exploration permanence (Crystal Project-style)** — `meta.deepest_stratum` (already v3+) gates the stratum-selection portal at the hub-town. Players who've reached S5 can re-descend to S1 for grinding, but new characters start at S1 even if `meta.deepest_stratum=8`. Per-character vs per-account-meta distinction: **per-character** for level/XP/equipped; **per-account** for `deepest_stratum` (so an alt benefits from the main's exploration but still has to grind their own levels).

The hybrid is **deliberate**: Hades's between-run currency + Diablo II's gear and character ladder + Crystal Project's "you've been here" exploration meter. None of the three games has all three; Embergrave's M3 is the first to combine them in this configuration. The risk is that the three meta-layers fragment the player's attention; the recommended mitigation is to make the **hub-town UI** the single surface that surfaces all three (currency display, stash, ladder).

### What persists across runs vs what resets

Per-character (carries across runs of the same character):
- Level, XP, stat allocations (M1 contract)
- Equipped items (M1 contract)
- Inventory ember-bags (M2 v4)
- **NEW M3:** ember-shard currency
- **NEW M3:** active bounty quest
- **NEW M3:** Paragon points (per `mvp-scope.md §M3` NG+ track)

Per-account (shared across all characters):
- Stash (M2 v4 → M3 v5 shared)
- `meta.deepest_stratum`, `meta.runs_completed`, `meta.total_playtime_sec` (v3+)
- **NEW M3:** `meta.hub_town_seen` (first-visit gate)
- **NEW M3:** `meta.lore_unlocked: Array[String]` (bounty / boss-kill lore snippets — once any character has unlocked them, all characters have read them)

Reset on each new run (within-character):
- HP / position / room state
- Active mob roster (re-rolled per descent)
- Run-progress XP gain (folds into character XP at run-end)
- Active loot drops in-world (`Pickup` entities)

### Recommend — ember-shard currency as the M3 economy primitive

**Ember-shards** drop from kills. Soft currency: **40-60 shards per stratum** at S1 (scales by `deepest_stratum`), spent at hub-town NPCs at fixed prices:

- **Vendor:** T1 weapon = 30 shards, T2 = 80, T3 = 200 (rough scale; balance pass per `affix-balance-pin.md` shape)
- **Anvil reroll:** 50-150 shards per reroll (escalating cost per reroll within the same run)
- **Bounty refresh:** 25 shards to swap the current bounty for a new one

Why ember-shards over gold:
- **Diegetic continuity** — the ember-shard is **the same substance as the player's flame** (per `palette.md` ember-accent through-line). Diablo II's gold breaks diegetic; Hades's darkness doesn't. Embergrave should match Hades here.
- **No "gold-find" affix bloat** — gold-find affixes are a Diablo I/II misstep that PoE inherited and regretted. Ember-shard drops are flat (per-kill scale by stratum), no affix interaction.

### Recommend — NG+ Paragon track AS the meta progression cap

Per `mvp-scope.md §M3` "NG+ Paragon track" is M3 scope. The Paragon track is **the post-level-30 progression** — after the character hits level 30 (M3 cap; M1 was level 5, M2 will likely be level 15), each subsequent XP-bar fills a single Paragon point (Diablo III Paragon shape, not Diablo II's per-character-skill). Paragon points spend at the anvil for **persistent small buffs**: +1% damage / +1% HP / +1% pickup radius / etc.

**Cap of 100 Paragon points** in M3 (so the player can reach Paragon 100 in a long playthrough; reaching Paragon 100 takes ~10x the time to reach level 30, intentionally). Beyond Paragon 100 is M4 / endgame.

### Save-schema implications (v5 + v6 ladder)

- v5 (driven by §1 multi-character): `data.characters[N].ember_shards`, `data.characters[N].active_bounty`, `data.characters[N].paragon_points`, `data.characters[N].paragon_spent: Dictionary[String, int]`. All additive within the v5 multi-character structure.
- v6 (driven by §3 if and only if M4 wants class divergence): would add `data.characters[N].class_id: StringName` and class-specific Paragon trees. Defer to M4 dispatch.

### Sponsor-input items (§3)

7. **NG+ Paragon track: per `mvp-scope.md §M3` OR re-evaluate?** Default is "ship as written." Sponsor may want to swap Paragon for a different meta-cap (e.g., Crystal Project's "every job leveled" non-power-creep shape — would let the player feel persistent achievement without a stat-creep treadmill). **Recommended:** ship Paragon as v1; Sponsor swap if playtest signals.
8. **Ember-shards as the M3 currency: YES/NO?** Default is YES (diegetic + Hades-precedent). Alternative is gold (Diablo II-precedent). **Recommended:** ember-shards.
9. **Bounty quest system in M3 OR defer to M4?** Default is M3 (per `mvp-scope.md §M3`). Sponsor may want to cut to fit timeline. **Recommended:** ship in M3 as the lore-narrative anchor; tight scope is "one quest active at a time, 5-8 quest archetypes."

---

## §4 — Character-art pass (Sponsor-promoted 2026-05-15)

### Shape — current state ("squares fighting squares")

**This section was promoted from "M3 someday" to "Sponsor-visible roadmap material" on 2026-05-15** when Sponsor asked during M2 RC soak: *"when is it going to change from squares fighting squares to actual graphic?"*

The framing is **correct and honest:** Embergrave's current visual presentation is colored `Sprite2D` blocks at room scale. The mobs (Grunt, Charger, Shooter, PracticeDummy, Stoker, Stratum1Boss) and the Player are each a single ColorRect / Sprite2D node with a per-mob rest-color hex (`Grunt: #8C2E37` red-brown; `Charger: #C76A2D` orange; `Shooter: #527FC8` blue; `Stratum1Boss: #7A1F29` deep red — from `.claude/docs/combat-architecture.md` § "Mob hit-flash"). **They register as "sprites" mechanically** (per Godot, they are `Sprite2D` / `CharacterBody2D` with `CollisionShape2D` children that participate in the physics + combat systems) **but they read as squares visually** because they are flat-color rectangles with no internal art.

Sponsor's framing absorbed: the game is mechanically near-complete for M2 / pre-M3 ramp, but its **visual presentation lags the systemic depth.** The mob hit-flash works; the death-tween works; the swing-wedge ColorRect works; the inventory equip-flow works; the AC4 Room 05 balance pass works. But every entity on screen is a flat rectangle, and that gap between "the systems are good" and "the screen looks placeholder" is what Sponsor surfaced.

**This is normal for indie-pixel-RPG mid-development.** Crystal Project shipped its M1-equivalent with hex-block stand-ins for weeks. Hyper Light Drifter shipped its alpha with placeholder pixel-art. The art-pass is a known late-development heavy-lift; **Sponsor is asking when, not whether.**

### Style options (recommend ONE primary + ONE fallback)

**Recommended primary: 32-bit pixel-art (Crystal Project / Octopath Traveler density)**

- **Pixel density:** 32-pixel tall character sprites (matches the 96 px/tile environment baseline per `visual-direction.md` — characters are ~1/3 tile height for top-down ARPG readability).
- **Reference anchors:**
  - **Crystal Project** (the most-shipped reference; the same single-dev pixel-art density Embergrave should aim for)
  - **Octopath Traveler** (HD-2D — pixel sprites over 3D environments; Embergrave is pure 2D, but the sprite density / animation crispness is the bar)
  - **Stardew Valley** (16-bit denser; one step below the 32-bit recommendation, but Eric Barone's solo-dev shipped-art-bar is the budget reference)
  - **Hyper Light Drifter** (animation-quality reference for combat readability)
- **Why 32-bit over 16-bit:** Crystal Project's density is the **shipped indie precedent**; 32-bit reads as "modern indie" not "retro indie" — the player doesn't think "this game is intentionally retro" at 32-bit, they think "this game has art." 16-bit (Stardew-density) reads as a **stylistic choice** that has to be earned; Embergrave's tone (dark-folk chamber audio per `audio-direction.md`, descent-narrative tonal weight) wants the higher-density bar. 8-bit (Crystal Project's Steam-page-screenshot-bait predecessors) is too retro for the project's tonal targets.
- **Why NOT hand-drawn (full art per mob):** hand-drawn 2D (Hollow Knight / Dead Cells) is ~3-10x the per-asset cost of pixel-art and breaks the existing tile-art tooling chain (Aseprite). Embergrave's environment is already pixel-art per `palette-stratum-2.md` + `visual-direction.md` lock; character art must match.
- **Why NOT photographic-ref / 3D-rendered-to-2D:** wrong tonal register; cost-prohibitive at indie scale; breaks the chunk-lib + tile-pixel-art tooling.

**Recommended fallback: AI-generated-then-cleaned (32-bit pixel-art) — if commission budget can't land or art schedule can't meet M3 ship**

- **Process:** Stable Diffusion / SDXL with pixel-art LoRA → ~32-bit candidate sprites per state (idle / walk / attack-telegraph / attack / hit-react / die) → manual Aseprite cleanup (fix anatomical breaks, lock palette to `palette.md` hex codes, align silhouettes) → ship.
- **Why this is a valid fallback:** the cleanup cost is ~10-20% of fresh-authoring cost; the AI provides shape candidates the artist would otherwise have to sketch. Indie precedent is mixed (some games ship pure AI, some refuse, some hybrid); the hybrid path is technically defensible and Sponsor-disclosable. **Important:** the cleanup pass is not optional — pure AI-output ships with obvious tells (extra fingers, palette drift, frame inconsistency) that break visual coherence.
- **Why FALLBACK not PRIMARY:** the primary path (commissioned pixel-art) produces a coherent visual identity that an AI-cleanup hybrid struggles to match. Use AI-cleanup only if commission budget / timeline forces it.

**Rejected: hand-drawn full art** (cost; tooling mismatch); **photographic-ref** (tone mismatch); **3D-rendered-to-2D** (cost; tooling mismatch). Documented for completeness.

### Cost-and-time bracket — NOT defensibly estimable; route to Sponsor for external estimate

**Per the brief's instruction:** "IF you can't defensibly estimate the cost-bracket, say so and route to 'Sponsor input: commission an external estimate from 2-3 pixel-art artists.' Don't manufacture numbers."

**I cannot defensibly estimate the cost bracket.** Reasoning:

- **Total cells estimate (rough math):** Mobs in M3 scope: ~6 distinct mob archetypes (Grunt, Charger, Shooter, PracticeDummy, Stratum1Boss, Vault-Forged Stoker — with Stoker as S2 retint of Grunt per `palette-stratum-2.md §5`, so 5 truly-new sprites if we count Stoker as a retint, 6 if not). Each mob × required anim states (idle, walk, attack-telegraph, attack, hit-react, die = 6 states) × frames per state (~4 average) × directions (4 cardinal for top-down ARPG; 8 if diagonals are needed) = **96 to 192 cells per mob.** Plus the Player (≥192 cells; player has more anim states than mobs). Plus the 3 hub-town NPCs (≥96 cells each, less anim depth). Plus pickup sprites (Pickup, Stash chest, Ember-bag — these per `palette-stratum-2.md §5` retint OK from existing sprites, so cost is tinting not authoring).
- **Estimated total cell count (M3 scope):** ~**1,000–1,500 cells** for full character + NPC art across S1+S2 (8 strata is M3 scope but per-stratum mob retint applies). Doubled if 8-directional, halved if 4-directional and lots of retint.
- **Per-cell authoring cost (rough industry brackets):** $30-80 per cell at mid-quality commissioning; $100-200 at premium / portfolio-tier artists. **Hours:** ~30-60 minutes per cell at mid-quality.
- **Naive multiplication:** 1,000 cells × $50 = $50,000 (mid). 1,500 cells × $100 = $150,000 (premium). **These numbers are not defensible** — they're based on per-cell rates I cannot verify from current market data, and the rates I'm working from are 2-3 years stale.

**Why I can't defensibly estimate:**
1. Per-cell pixel-art commissioning rates are not publicly indexed; rates vary 4-10x by artist seniority + portfolio + region.
2. Embergrave's tonal-specificity (dark-folk-chamber, descent-narrative, ember through-line per `palette.md`) requires artists with **specific stylistic alignment**; that constrains the artist pool, which inflates rates.
3. The "cleanup + alignment pass" cost (lock palette, align silhouette to hex codes, frame-consistent anim) is **artist-dependent** — it ranges from "included in per-cell rate" to "+30% on the per-cell rate" depending on artist.

**Recommendation: Sponsor commissions an external estimate from 2-3 pixel-art artists / studios** with the following brief:
- Top-down ARPG, ~32-pixel character sprites, palette locked to Embergrave's hex codes (provide `palette.md` + `palette-stratum-2.md`).
- Anim states per mob: idle (4f), walk (8f), attack-telegraph (4f), attack (6f), hit-react (3f), die (8f). 4-directional cardinal.
- Mob roster: 6 archetypes (Grunt, Charger, Shooter, PracticeDummy, Stoker, Stratum1Boss; Stoker is a retint of Grunt). Plus Player. Plus 3 hub-town NPCs. Plus pickup / chest / ember-bag (retint pass).
- Per-stratum retint variants (S1, S2, S3, ..., S8) at +10-20% of the base authoring cost per stratum.
- Aseprite-compatible source files required.
- Timeline: 8-16 weeks for the full M3 set; segment-able by stratum.

Three competing quotes give Sponsor a defensible cost-bracket and time-bracket to commit against. **This is the right answer; manufactured numbers from me are the wrong answer.**

### Asset pipeline — Aseprite + soft-retint extension of W3-T3

The pipeline already established by W3-T3 (`m2-week-3-backlog.md`, Drew's stratum-2 sprite soft-retint pass) is **the right backbone for the M3 art-pass.** The pipeline:

1. **Aseprite source files** committed under `assets/sprites/<mob>/source.aseprite`. The `.aseprite` file is the single source of truth — never edit the exported PNG.
2. **Exported PNGs** at `assets/sprites/<mob>/<state>.png`, generated from Aseprite via the export-as-sheet command. PR-time hook: any `.aseprite` edit MUST have a paired `.png` re-export commit (or CI fails on stale-export detection).
3. **Per-stratum retint variants** via Aseprite's palette-swap feature. The S2 soft-retint pattern (W3-T3) is the canonical example: the same Aseprite source authors S1 + S2 + S3 + ... variants by swapping the palette layer.
4. **Per-stratum palette files** at `assets/palettes/<stratum>.aseprite`. Match the `palette.md` / `palette-stratum-N.md` doctrine hex codes; never invent new hexes in Aseprite without a doc update.
5. **Animation frame contract:** 6 anim states × ~4 frames each × 4 directions × ~6 mob archetypes = ~576 cells base. Per-stratum retint multiplier (8 strata × ~50% retint) adds another ~2,000 cells. The W3-T3 pattern proves this scales.

**Crystal Project's pipeline reference:** Crystal Project shipped solo-developer with 7+ strata of art + 60+ mobs via an Aseprite + palette-swap pipeline very similar to this. Embergrave's pipeline is **the same shape**, just at smaller scale. This is reassuring — the pipeline is proven; the scope is the lever.

**Integration with the existing combat-architecture:**
- Mob `Sprite` children (per `.claude/docs/combat-architecture.md` § "Mob hit-flash") get their `texture` swapped from ColorRect → `Sprite2D` with the Aseprite-exported PNG. The hit-flash tween logic doesn't change (still tweens the `Sprite.color` modulate property).
- Each mob's `_play_hit_flash` rest-color hex (e.g. Grunt `#8C2E37`) becomes the **modulate-cascade** applied to the new sprite at idle. The hit-flash tween still tweens the modulate channel toward `Color(1, 1, 1, 1)` (white) and back — the white-flash effect renders against the actual sprite, not a flat rectangle.
- The mob's `CharacterBody2D` + `CollisionShape2D` + `MOTION_MODE_FLOATING` (per `combat-architecture.md` § "CharacterBody2D motion_mode rule") logic is unchanged. The visual swap is **only the Sprite child**; everything else is preserved.

**Cost of the integration swap (per mob):** ~1-2 dev-hours per mob to swap ColorRect → Sprite2D + texture-load + paired-test update. This is **separate from the per-cell authoring cost** — it's the engineering-side cost of consuming the art. 6 mobs × 2 hours = ~12 dev-hours total. **This is the manageable number.** The art-authoring cost is the unbounded one.

### Dependency on M2 RC sign-off

**Recommend: run M3 seed in parallel with M2 RC soak. Defer M3-implementation start until M2 RC signs off.**

Reasoning:
- The §4 design doc (this document) is **paper work** — no engine changes, no save-schema bumps, no integration-test surface. Can be authored in parallel to Sponsor's M2 RC soak (it has been — this PR is the deliverable).
- Sponsor's external-estimate commission (see §4 cost-bracket above) can also run in parallel — Sponsor talks to artists while Tess + Sponsor finish the M2 RC soak. **Lead time on a 3-artist estimate is ~2-3 weeks** assuming standard reply cadences; that lead time alone justifies parallel-scheduling.
- **M3-implementation start (the actual sprite authoring + engine swap)** should defer until M2 RC signs off. Three reasons:
  1. M2 RC may surface late-stage M2 bugs that need fix-forward dispatches (`m2-week-3-backlog.md §W3-T10` Half B is the absorber). Don't double-dispatch on M3 art while M2 RC is fragile.
  2. The art-pass benefits from a **mechanically-frozen** target. If M3 sprites are authored for a Grunt with 12 HP / 1 dmg / 60 px speed, and then M2's late-balance moves Grunt to 8 HP / 2 dmg / 90 px speed, the anim-frame timing budgets (windup / recovery) may need retiming. Lock the mechanical surface first.
  3. M2 RC is the **release-candidate that ships first as the public/Sponsor-soak playable.** It must not slip due to M3 art-pass attention drain. Sponsor sign-off on M2 RC is the gate.
- **Parallel work pre-M2-RC-signoff:** Sponsor commissions estimates, Sponsor + Priya pick the primary path (commissioned vs AI-hybrid), Sponsor signs off the cost-bracket. **Post-M2-RC-signoff:** dispatch the first stratum's art-pass as M3.0.

### Risks — pixel-art-RPG-slip is the historical indie killer

**The risk is real and well-documented.** Indie pixel-art RPGs slip on art-authoring more than any other category. References:

- **Star Citizen** (different genre, same pattern at 1000x scale) — sprite/asset-authoring slipped years.
- **Cyberpunk 2077** (different scale, similar art-vs-systems gap) — shipped with placeholder art on background NPCs that became the meme.
- **Many sub-1k-Steam-wishlist indies** (anonymized) — shipped systems-complete to playtesters but never made it to public release because the art-pass exceeded budget.
- **Counter-example: Crystal Project** — single-dev, proved the pipeline + pacing works. The reference Embergrave is matching.
- **Counter-example: Hyper Light Drifter** — slipped art (Drifter took 3 years from Kickstarter), but shipped, and the art-pass became the marketing.

**Mitigation strategies (recommend ALL three):**

1. **Asset-budget gate.** Sponsor commits a hard $-budget AND a hard time-budget at M3.0 dispatch. If either bracket exceeds 1.2x by mid-M3, the milestone re-scopes (see #2 mitigation). The bracket is set by Sponsor after the external estimate (cost-bracket above).
2. **Scope-down option pre-committed.** If art slips, the milestone falls back to **"ship 1 stratum's worth of sprites + hex-block fallback for S2-S8."** Player sees S1 with art, S2-S8 with the current placeholder squares. Adventure-game precedent: ship the visual-polish stratum as a vertical-slice; the rest follows in M3.1 / M3.2. This is the **degraded-but-shippable** floor for the art-pass.
3. **Commission-vs-internal trade-off.** Commissioned art is faster and higher-quality, but more expensive and Sponsor-budgeted. Internal authoring (Sponsor or contracted-solo-artist) is cheaper and slower. **Sponsor decides which side of the trade**; this doc recommends commission for M3 (the time-budget mitigation is more important than the dollar-budget at this scale).

**The hex-block fallback is the safety net.** The current placeholder sprites are mechanically complete; they will continue to work indefinitely. **Embergrave does NOT need character art to ship M3.0** — the mechanical content (8 strata, full mob roster, hub-town, multi-character, NG+ Paragon, bounty quests, persistent meta) is the M3 headline. The art-pass is the polish. If the art slips, the polish slips; M3 ships with a stratum or two of art-pass-complete and the rest in hex-block. Re-evaluate at M3.1.

### Milestone shape — recommend "parallel track in M3" not "M3.0 = character-art"

**Two options the brief calls out:**

- **Option A: M3.0 = character-art own milestone.** All M3 stops at "art-pass complete." Multi-character / hub-town / meta-progression / NG+ defer to M3.1+.
- **Option B: parallel track in M3.** Character-art-pass ships incrementally alongside multi-character + hub-town + meta-progression. M3 has 4 parallel tracks.

**Recommend Option B (parallel track).** Reasoning:

- **Throughput:** the team has demonstrated 22 PRs / week in M2 W2 across 5 named-agent lanes (per `m2-week-2-retro.md`). Drew handles sprite authoring + level work; Uma handles visual-direction + audio; Devon handles engine + save-schema; Tess handles QA + paired tests; Priya handles planning. Sequencing art-pass as M3.0 leaves Devon + Tess + Uma + Priya idle while Drew + the commissioned-artist (or AI-cleanup loop) works alone. **Parallel-track keeps everyone shipping.**
- **Mechanical-vs-visual split:** the multi-character / hub-town / meta-progression work touches engine + save-schema + UI surfaces that DON'T depend on the art-pass. Devon's v5 save-schema migration is independent. Uma's hub-town visual-direction is independent (it'll soft-retint S1 sprites anyway). Tess's M3 acceptance plan is independent. **Lock-step sequencing forces dependencies that don't exist.**
- **Risk diversification:** if the art-pass slips (per "Risks" above), the mechanical M3 content can still ship. Option A makes the art-slip the milestone-slip; Option B isolates the slip.
- **Sponsor visibility:** Option B lets Sponsor see incremental art-pass shipping per stratum, alongside mechanical progress per dispatch. Option A presents a single big-bang art-pass demo at the end of M3.0 with no mechanical updates for weeks/months. Sponsor's M2 RC question ("when do we get art?") suggests they want **visible incremental progress**, not a single demo. Option B serves that better.

**The parallel-track shape (Option B):**

- **Track 1 (Drew + commissioned-artist):** stratum-by-stratum sprite authoring. Ships in waves: S1 sprites → S2 sprites → S3 sprites → ... . Each wave a separate PR / dispatch.
- **Track 2 (Devon + Tess):** multi-character + save-schema v5 + hub-town save-state. Ships per the `mvp-scope.md §M3` original scope.
- **Track 3 (Uma + Drew):** hub-town visual + NPC sprite authoring. Anchors at the surface (Outer Cloister palette).
- **Track 4 (Priya):** M3 design seeds (this doc) + M3 backlog dispatches + Sponsor-input shepherding.

**Counter-argument for Option A:** if Sponsor wants the art-pass to be the **flag-planting feature** for M3 ("Embergrave M3 is the art-pass milestone"), Option A is the marketing-friendly framing. **Recommended:** Option B, but Sponsor sign-off on this is the load-bearing call.

### Sponsor-input items (§4)

10. **Primary style: 32-bit pixel-art commissioned OR AI-cleanup hybrid OR something else?** Default is 32-bit pixel-art commissioned (Crystal Project density). **Recommended:** commissioned, with AI-cleanup hybrid as documented fallback.
11. **External cost-bracket estimate: Sponsor commissions 2-3 artists for estimates BEFORE M3 dispatch?** Default is YES (the cost-bracket is not defensibly internally-estimable). **Recommended:** YES; lead-time ~2-3 weeks; run in parallel with M2 RC soak.
12. **Milestone shape: own milestone (M3.0 = art-pass) OR parallel track in M3?** Default is parallel track. **Recommended:** parallel track. (Counter-default: own milestone if Sponsor wants the art-pass as the M3 flag-planting feature.)
13. **Scope-down floor: 1-stratum-worth + hex-block fallback for S2-S8 IF art slips?** Default is YES. **Recommended:** YES as the pre-committed slip-mitigation.
14. **Art-pass dependency on M2 RC sign-off: parallel design (this doc) OK; implementation defers until M2 RC signs off?** Default is YES. **Recommended:** YES.
15. **Asset pipeline: Aseprite + soft-retint extension of W3-T3 OR something different?** Default is YES (W3-T3 extension). **Recommended:** YES — pipeline is proven; extending is cheap.

---

## Caveat — design seeds, not design lock

**Every section above is a recommendation, not a commitment.** Sponsor signs off the big shapes (per `sponsor-decision-delegation` memory):

- Slot count and class-divergence-timing (§1)
- Hub-town size + NPC count + visual approach (§2)
- NG+ Paragon vs alternative; currency primitive; bounty system inclusion (§3)
- Art-pass style; external estimate go/no-go; milestone shape; cost-bracket commitment; pipeline (§4)

The mechanical / pipeline / save-schema details are **Priya/Devon recommendations grounded in genre precedent and existing project doctrine** — they will likely survive Sponsor sign-off, but they're not binding until M3 dispatch picks them up.

**This doc is the input to M3 dispatch, not the output.** When M3 starts (post-M2-RC-sign-off), the orchestrator dispatches per-section work to the team based on the Sponsor sign-off shape captured here. If Sponsor's sign-off diverges from this doc's recommendations, the divergence is logged in a v1.1 amendment + DECISIONS.md entry.

---

## Sponsor-input items summary (master list across §§1-4)

Compiled from each section's Sponsor-input list. **Big-shape items (6)** require Sponsor sign-off before any M3 dispatch starts. **Smaller defaults (9)** the orchestrator can route per Priya's recommendation if Sponsor signs the big shapes.

### Big shapes (6) — Sponsor must explicitly sign off

1. **§1.1 Slot count: 3 (default) vs 1 vs 6+.** Recommended: 3.
2. **§2.4 Hub-town size: single-screen (default) vs multi-room.** Recommended: single-screen for M3.0.
3. **§3.7 NG+ Paragon track per `mvp-scope.md §M3` (default) vs re-evaluate.** Recommended: ship Paragon as v1.
4. **§4.10 Primary art style: 32-bit pixel-art commissioned (default) vs AI-hybrid vs other.** Recommended: commissioned.
5. **§4.11 External cost-bracket estimate from 2-3 pixel-art artists (default YES).** Recommended: YES. **Time-critical:** lead-time ~2-3 weeks.
6. **§4.12 Art-pass milestone shape: parallel track (default) vs M3.0 own milestone.** Recommended: parallel track.

### Smaller defaults (9) — Priya recommends; Sponsor confirms or redirects

7. **§1.2 Class divergence in M3 (default NO; defer to M4).** Recommended: M4.
8. **§1.3 Shared stash across slots (default YES).** Recommended: YES.
9. **§2.5 NPC count: 3 (default) vs more.** Recommended: 3.
10. **§2.6 Hub-town visual: Outer Cloister evolution (default) vs new biome.** Recommended: evolution.
11. **§3.8 Ember-shards as M3 currency (default YES).** Recommended: YES.
12. **§3.9 Bounty quest system in M3 (default) vs defer to M4.** Recommended: ship in M3.
13. **§4.13 Scope-down floor: 1-stratum art + hex-block fallback (default YES).** Recommended: YES.
14. **§4.14 Art-pass design parallel with M2 RC soak; impl defers post-sign-off (default YES).** Recommended: YES.
15. **§4.15 Asset pipeline: Aseprite + soft-retint extension of W3-T3 (default YES).** Recommended: YES.

---

## Cross-references

- `team/priya-pl/mvp-scope.md` §M3 — original M3 content paragraph (v1-frozen 2026-05-02). This doc adds orthogonal axes; mvp-scope.md remains the content-scope contract.
- `team/uma-ux/stash-ui-v1.md` — M2 stash-room pattern that §2 hub-town evolves from. `stash-ui-v1.md §7 q4` is the open question §2 answers.
- `team/devon-dev/save-schema-v4-plan.md` — v4 schema. §1 + §3 imply v5 (and possibly v6); v5 violates v4's additive-only rule for the first time.
- `team/uma-ux/palette.md` — global palette + S1 authoritative + indicative S3-S8. Cross-stratum ember through-line is the §4 art-pass binding.
- `team/uma-ux/palette-stratum-2.md` — S2 authoritative + soft-retint pattern. §4 art-pass extends this pipeline.
- `team/priya-pl/m2-week-3-backlog.md §W3-T12` — the source ticket; this doc is the deliverable.
- `team/priya-pl/m2-week-2-retro.md` — W2 retro; Pattern 5 (HTML5 default-font tofu) is a related "art surface matters" precedent.
- `.claude/docs/combat-architecture.md` § "Mob hit-flash" — integration surface §4 art-pass must preserve.
- `team/decisions/DECISIONS.md` 2026-05-15 — one-line append noting Sponsor-promoted §4 (filed alongside this PR).

---

## Hand-off

- **Sponsor:** the 6 big-shape items above. Recommended action: read the doc, sign off on the 6 big shapes (or redirect), greenlight the external cost-bracket estimate (§4.11) as the **first M3 action** so the 2-3-week artist-quote lead-time runs in parallel with M2 RC soak.
- **Priya:** absorb Sponsor sign-off; revise this doc to v1.1 with the locked shapes; file M3 backlog tickets per the parallel-track shape.
- **Devon:** future v5 save-schema migration (§1 + §3 implications). No action now; M3 dispatch ticket will land post-M2-RC-sign-off.
- **Drew:** future stratum-by-stratum sprite authoring (§4 art-pass parallel track). No action now; gate is Sponsor sign-off on §4.10 (primary style) + §4.11 (external estimate landed).
- **Uma:** future hub-town visual direction (§2) + NPC sprite-direction assist (§4). No action now; M3 dispatch.
- **Tess:** future M3 acceptance plan (multi-section). No action now; mirrors `m2-acceptance-plan-week-3.md` pattern.

---

## Appendix — what we are NOT designing here

- M3 content roster (which mob archetypes for S3-S8, which boss design per stratum) — separate per-stratum design tickets when M3 ramps.
- M4 / M5 / endgame meta (Paragon 100+, late-game NG+ Paragon mods, late-game class divergence). Documented as M3 scope-out.
- Audio direction for M3 (`audio-direction.md` v1.1+; M3 strata get their own audio cousins per `palette.md`). Uma's lane; separate dispatch.
- The actual sprite art (this is a scoping doc, not an art-direction doc; the art-direction doc is the deliverable of the external commission).
- The exact dollar / hour numbers for the cost-bracket (routed to Sponsor's external estimate per §4.11).
- Marketing / itch.io / Steam-page implications of the M3 milestone shape (Sponsor + Priya call, post-M3 dispatch).

---

## Non-obvious findings

1. **The §4 character-art-pass cost-bracket is genuinely not defensibly estimable internally.** Industry per-cell rates vary 4-10x by artist seniority, and the cleanup-pass cost is artist-dependent. Manufactured numbers would be worse than no numbers — Sponsor's external estimate is the right answer. This contradicts the natural orchestrator instinct to "always provide a number" — the better answer is "I don't know, here's how to find out."
2. **v5 save-schema migration violates v4's additive-only rule.** Per `save-schema-v4-plan.md §4.1` rule 1 ("Never rename a field. A rename is two operations [delete old + add new] and breaks every consumer"), the `data.character` → `data.characters[]` move is a type-change and a rename. This is the **first non-additive schema bump** the project will face. Devon needs to absorb this when v5 dispatches, with explicit migration-cost commitment.
3. **Parallel-track Option B for art-pass is throughput-optimal but Sponsor-marketing-suboptimal.** The team can ship more total work in parallel-track shape, but Sponsor may want the art-pass as the M3 flag-planting feature — that's an "own-milestone" framing that costs throughput but earns marketing legibility. The trade-off is Sponsor's call, not Priya's.
4. **The hex-block fallback is genuinely shippable.** Embergrave M3 can ship without character art and still be a complete game mechanically. This is the safety net — if the art-pass slips, the game still works. **This is unusual** for indie RPGs; most projects can't ship in placeholder state. Embergrave's clean "Sprite-color tween hit-flash + ColorRect swing-wedge + ColorRect death-tween" combat-visuals architecture (per `.claude/docs/combat-architecture.md`) is what enables this — the systems were authored against the placeholder, not against final art, so the placeholder remains valid forever.
5. **The "squares fighting squares" framing has Sponsor-acceptance precedent.** Sponsor said the phrase neutrally during M2 RC soak, not as a complaint — implying acceptance that the placeholder state is fine for now. The Sponsor-promoted §4 is asking **"when"**, not **"this is wrong"**. The recommendation framing should match: "here's a costed roadmap from current to art-pass-complete", not "we're fixing a broken thing."
6. **Crystal Project as primary reference is load-bearing.** It is the only single-dev shipped-precedent at Embergrave's scope (pixel-art density + content scope + commercial release). Hades is too-big-budget; Stardew Valley is too-large-scope; Hyper Light Drifter is too-art-focused. Crystal Project's pipeline is the one most-directly transferable to Embergrave's situation, and the 32-bit density recommendation is grounded in Crystal Project's shipped state.
