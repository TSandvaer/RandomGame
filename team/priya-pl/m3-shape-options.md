# M3 Shape Options — Three Alternatives + Recommendation

**Owner:** Priya · **Authored:** 2026-05-16 · **Status:** Sponsor-input pending — pick a shape before any M3 W1 dispatch · **Companion to:** `m3-design-seeds.md` (the content-track detail), `mvp-scope.md §M3` (the indicative scope paragraph).

This doc is **NOT a redo of `m3-design-seeds.md`.** That doc details the **content-track shape** (multi-character / hub-town / persistent-meta / character-art-pass — `m3-design-seeds.md` v1.0). This doc asks the **prior strategic question:** which M3 shape ships first?

**Once M2 W3 RC ships, the next-milestone shape is undecided.** The content-track is the default-recommendation but not the only viable shape. Sponsor needs the question framed as a choice with tradeoffs, not as a single locked roadmap. Per `sponsor-decision-delegation` memory, Sponsor follows orchestrator-recommended calls ~99% of the time — but the 1% pushbacks tend to land on high-leverage strategic shape questions exactly like this one. **Surface the question; do not pre-decide it.**

## TL;DR

Three alternative M3 shapes, all viable, materially different in what they ship and what they prove:

- **Shape A — Content track (default).** Multi-character + hub-town + persistent-meta + character-art-pass. Matches `mvp-scope.md §M3` original framing + Sponsor's 2026-05-15 art-pass promotion. **Recommended.**
- **Shape B — Boss-rush / depth track.** All 8 strata's boss rooms first; full stratum content trails. Front-loads the climax-moment density; thin connective tissue.
- **Shape C — Narrative arc track.** Lore + characters + story-beats first; mechanics frozen at M2 baseline. Differentiation play.

**Leading recommendation:** **Shape A.** Reasoning at §5. The leading tradeoff is that Shape A is the **safest and most-aligned with existing project doctrine**, but Shape B/C would be the **more-differentiated outcome** if the project's strategic concern were "Embergrave needs to feel different from Crystal Project / Diablo II clones" rather than "Embergrave needs more content to be played longer."

**Sponsor input pending:** which of Shape A / B / C is M3's headline? (Or hybrid — see §6.)

---

## Shape A — Content track (DEFAULT, RECOMMENDED)

**What it ships in M3.0:**

- 8 strata of explorable content (S1 ✓ M1; S2 partial M2; S3-S8 new in M3).
- Multi-character save-slots (Diablo II shape — 3 slots + shared stash).
- Single-screen hub-town with 3 NPCs (vendor / anvil / bounty-poster).
- Persistent meta-progression: ember-shard currency + NG+ Paragon track + bounty quest system.
- Character-art-pass parallel track (commissioned pixel-art, stratum-by-stratum).
- T1-T6 full gear tier expansion + ~40-affix pool + crafting/reroll bench.

**What it does NOT ship:** novel mechanical surfaces (no new weapon types, no off-hand/trinket/relic slots, no class divergence — those are M4). Character-art-pass may slip to M3.1 per `m3-design-seeds.md §4` scope-down floor.

**One paragraph:** This is the **default M3 shape** that `mvp-scope.md §M3` was authored against in M1 + the four sections of `m3-design-seeds.md` (multi-character / hub-town / meta / art-pass) elaborate. It is the **most parallelizable** shape — the team has demonstrated 22 PRs/week capacity across 5 lanes in M2 W2; Shape A keeps all 5 lanes loaded (Drew on content + sprite-pass; Uma on hub-town visual + audio; Devon on save-schema v5 + engine; Tess on QA + paired tests; Priya on planning + design-seeds). The art-pass parallel-track per `m3-design-seeds.md §4` is the deliverable that materially answers Sponsor's 2026-05-15 "squares fighting squares" question. **Risk profile:** known and managed — the art-pass slip-risk is real (industry pattern; see `m3-design-seeds.md §4 Risks`) but the scope-down floor (1-stratum art + hex-block fallback for S2-S8) is pre-committed.

**Leading tradeoff:** content-track is the SAFE shape — it extends what M1/M2 already proved (combat loop + dungeon-descent + gear-and-affix). It does NOT differentiate Embergrave from Crystal Project / Diablo II / Last Epoch peers in the genre. If the project's strategic concern is "do we have a hit" rather than "do we have a finished game," Shape A is the wrong shape — it ships more of the same.

**Why default + recommended:** `mvp-scope.md §M3` is v1-frozen at this shape; Sponsor signed off the original M1+M2 sequence; the team-throughput model is calibrated to multi-lane content + system work; the 5 named-agent roles map cleanly onto Shape A tracks. Picking against this shape is a strategic pivot, not a sequencing tweak — Sponsor should pick against it deliberately.

---

## Shape B — Boss-rush / depth track

**What it ships in M3.0:**

- All 8 strata's boss rooms authored + their unique mechanics (S1 Warden ✓ M1; S2 Vault-Forged Stoker ✓ scoped M2 W3-T4; S3-S8 new).
- 8 unique boss state-machines, unique-mechanic-per-boss (breath cone / ground-slam / parry-window / etc.).
- Connective stratum content stays **placeholder** — S3-S8 rooms ship as 1-3 transition rooms each, then immediately a boss room. Mobs stay the M2 roster (Grunt / Charger / Shooter / Stoker). No new mob archetypes.
- No multi-character, no hub-town, no persistent-meta beyond M2 baseline. No character-art-pass (rectangles continue).
- "Boss rush mode" surface — title-screen menu option to skip-to-boss, fight all 8 bosses back-to-back with a shared HP pool.

**What it does NOT ship:** content depth (S3-S8 are bones-only); the persistent-meta/multi-character/art-pass features.

**One paragraph:** This is the **climax-density** shape. M2's Stratum-1 boss is the most differentiated mechanical content the project has shipped — phase transitions, segments-lie-about-HP, entry-sequence cinematic, stagger-immune window, unique loot. Shape B doubles down on that as M3's identity: 8 unique boss-fights as the deliverable. The "rest of the game" (connective rooms + non-boss mobs + meta-progression) stays at M2 baseline; M3 is the "boss rush" milestone. Reference anchors: **Cuphead** (shipped boss-rush-first; connective mechanics minimal); **Furi** (pure boss-rush, no exploration); **Dark Souls 3 + DLCs** (boss density is the differentiator).

**Leading tradeoff:** Shape B trades **breadth** (lots of dungeon to explore) for **density** (every encounter matters). It changes Embergrave's genre-positioning — from "ARPG dungeon crawler" to "boss-rush ARPG." Some players LOVE that genre (Cuphead's audience, Hades's audience). Other players (Diablo II's audience, Crystal Project's audience) will bounce off: they came for exploration + farming, not for boss-after-boss. **Risk profile:** higher than Shape A — the genre-position pivot is a strategic call, not a content call. If Sponsor's target audience is the Diablo II crowd, Shape B is the wrong bet.

**Why NOT recommended (but valid):** the project's stated genre positioning (per `game-concept.md` + `mvp-scope.md`) is the Diablo II / Crystal Project / Hades hybrid. Shape B leans hard into the Hades half of that hybrid and away from the Diablo II half. It's a strategic narrowing; defensible if Sponsor wants the project to be **distinctive** in genre rather than **complete** in scope.

---

## Shape C — Narrative arc track

**What it ships in M3.0:**

- Lore system: NPC dialog at hub-town, lore-snippets unlocked on boss-kills + bounty completions, a written backstory anchor for each of the 8 strata.
- Narrative arc: a multi-stratum story spine (Sponsor-input on shape — descent-narrative, lost-faction, returning-character, etc.) that surfaces through gameplay environments + NPC dialog.
- Character-art-pass for the Player + 3 hub-town NPCs ONLY (mobs stay rectangles). Hand-drawn portrait art for dialog (separate from sprite-art — small set, tractable cost).
- Single-screen hub-town with 3 NPCs (same shape as Shape A's hub) — but the NPCs are LORE characters first, vendor/anvil/bounty second.
- Mechanics: frozen at M2 RC baseline. No new mobs, no new bosses (use Vault-Forged Stoker as S2 boss; punt S3-S8 mechanics). No multi-character, no NG+ Paragon, no T4-T6 gear tier.
- Bounty quest system shipped as the **narrative-driver** (not the economy-driver) — quests deliver story beats; rewards are lore + cosmetics, not gear-power.

**What it does NOT ship:** mechanical content expansion (8 strata stays at boss-only authoring; mob roster stays M2-sized); the multi-character / persistent-meta / T4-T6 gear-pass features.

**One paragraph:** This is the **differentiation** shape. Embergrave's tonal identity (dark-folk-chamber audio per `audio-direction.md`; ember-descent palette per `palette.md`; stratum-name imagery like "Outer Cloister" / "Cinder Vaults") is already pointing at a narrative spine — Shape C ships that spine as M3's identity. References: **Hades** (where the narrative IS the meta-progression — Zagreus's dialog accumulates run-over-run, NPC relationships evolve, the story is the long-game pull); **Disco Elysium** (narrative-density-as-genre); **Crystal Project** (counter-example — explicitly low-narrative; Embergrave deliberately picks the OTHER side of that tradeoff). The team-shape: Uma's lane expands (writing + NPC visual + portrait-art curation); Drew's lane shrinks (no new mob authoring); Devon's lane is engine + lore-unlock state-machine.

**Leading tradeoff:** Shape C trades **mechanical depth** (you don't get T4-T6 affixes / multi-character / 8-strata content) for **narrative depth** (you get a story spine that 22 PRs of mechanical work won't deliver). It bets on Embergrave's **tonal identity** carrying the player; if the tonal identity isn't compelling enough on its own, Shape C is the most-likely-to-disappoint shape. **Risk profile:** highest team-skill-mismatch — the team has shipped 200+ PRs of mechanical / systems work; the project has shipped ~0 PRs of narrative-design work. Uma's lane has design-spec depth but no narrative-writing portfolio. Shape C requires hiring or commissioning narrative talent — a budget call.

**Why NOT recommended (but valid):** team-skill-mismatch is the load-bearing concern. Even with great narrative writing, the mechanical-frozen-at-M2 surface limits what story moments can land — "you slay a boss, then read a lore note" doesn't carry the narrative weight that "you slay a boss, the world changes" would. Shape C wants more mechanical-narrative coupling than the team can ship in one milestone.

---

## §5 — Leading recommendation: Shape A (content track)

**Reasoning, in order of weight:**

1. **Alignment with v1-frozen `mvp-scope.md §M3`.** The original M3 paragraph is content-track shaped. Sponsor signed off the M1+M2 sequence against that paragraph. Picking Shape A is the **default-honored path**; picking B or C is a strategic pivot.
2. **Team-throughput model.** The 5 named-agent roles map cleanly onto Shape A's four tracks (content/visual/engine/QA). Shape B narrows the team (Drew + Uma + Tess; Devon underloaded on save-schema-v5 since Shape B doesn't need it). Shape C team-skill-mismatches (no narrative-writing portfolio).
3. **Answers Sponsor's 2026-05-15 art-pass question directly.** Sponsor surfaced "squares fighting squares" as a roadmap question during M2 RC soak. Shape A includes the character-art-pass parallel track as `m3-design-seeds.md §4`. Shape B punts the art-pass; Shape C ships it only for Player + 3 NPCs (mobs stay rectangles, doesn't answer the question).
4. **Risk profile is managed.** Shape A's biggest risk (art-pass slip) has a documented mitigation (`m3-design-seeds.md §4` scope-down floor — 1-stratum + hex-block fallback). Shape B's biggest risk (genre-position pivot) is unmitigatable mid-milestone. Shape C's biggest risk (team-skill-mismatch) is unmitigatable without hiring.

**The leading tradeoff against Shape A:** Shape A ships **more of what's been shipped**. If Sponsor's strategic concern is "does Embergrave feel different from the genre," Shape A is the wrong shape — it deepens but doesn't differentiate. Shape B (boss-rush identity) and Shape C (narrative identity) both differentiate; Shape A doesn't.

**Honest framing:** Shape A is the safe + recommended pick **if** the project's strategic question is "ship a complete game." It is the wrong pick **if** the project's strategic question is "ship a distinctive game." Sponsor signals the strategic question; recommendation follows.

---

## §6 — Hybrid possibilities (Sponsor-input optional)

If Sponsor wants to pick Shape A as the headline but blend in Shape B or C elements:

- **Shape A + Shape B's boss-rush mode.** Ship full content track AS the M3.0 headline; add a small "boss rush mode" title-screen option that unlocks at NG+ entry. ~1-2 dev ticks; Drew + Devon co-author. **Lightweight differentiator** that costs little but ships Shape B's flag-feature.
- **Shape A + Shape C's lore snippets.** Ship full content track; layer in NPC dialog + lore-snippet-on-boss-kill collectibles. ~2-3 dev ticks; Uma authors lore copy; Devon ships unlock state. **Tonal differentiator** that costs little but ships Shape C's flag-feature.
- **Shape A + both hybrids.** Recommended if Sponsor wants Shape A as the headline AND wants to ship distinguishing features. ~3-5 dev ticks total across M3. Doable.

The hybrid shape is **default-recommendable** if Sponsor signs Shape A as the headline and wants light differentiation. The orchestrator can route this without further Sponsor sign-off — the hybrid ships within Shape A's scope ceiling.

---

## §7 — Sponsor-input question summary

**Single load-bearing question:** Which of Shape A / B / C is M3's headline?

- **Shape A — Content track.** Recommended. `mvp-scope.md §M3` default. Answers art-pass question directly. Safest.
- **Shape B — Boss-rush / depth track.** Distinctive genre pivot. Higher risk; higher differentiation.
- **Shape C — Narrative arc track.** Differentiation play. Highest team-skill-mismatch risk.

**Secondary:** If Shape A, does Sponsor want hybrid additions (boss-rush mode flag-feature, lore-snippet system, both)? Default is no hybrid; recommend "Shape A + lore snippets" as the lowest-cost differentiator if Sponsor signals "want more distinctive feel."

**Tertiary (Shape A only):** confirm `m3-design-seeds.md §4` art-pass primary path (commissioned pixel-art) + external-estimate go-ahead. `m3-design-seeds.md` has 15 Sponsor-input items elaborating this — 6 big-shape, 9 smaller defaults. Sponsor signs off the 6 big-shape items at M2 RC sign-off conversation; Priya routes the 9 smaller defaults per recommendations after that.

---

## Caveat — design seeds, not design lock

These three shapes are recommendations grounded in genre precedent + existing project doctrine. Sponsor may pick a fourth shape entirely (e.g., "ship M2 polish-only as M3.0 — no new content, just refine"); if so, this doc updates with a v1.1 amendment + DECISIONS.md entry. **The point of this doc is to give Sponsor a structured choice, not to lock the choice.** The shape decision drives M3 W1 backlog dispatch; until shape locks, M3-implementation work cannot dispatch.

The existing `m3-design-seeds.md` (v1.0, in main) details Shape A's content-track elaboration. If Sponsor picks Shape B or C, that doc moves to "deferred to M4" framing and a parallel `m3-design-seeds-shape-<B|C>.md` authors the picked shape's detail.
