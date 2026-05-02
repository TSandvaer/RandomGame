# Game Concept — Embergrave

## v1 — frozen 2026-05-02

This document is **v1-frozen** as of end-of-week-1. Content below is the canonical M1 design contract. Any change after this date must:

1. Land in a `## Changes` section appended to the bottom of this doc, with date + rationale + `Decided by`.
2. Not silently edit the v1 content above.

Rationale per `team/DECISIONS.md` (2026-05-01 game-concept entry): the team needs a fixed contract during M1 build so Drew's content authoring, Devon's engine work, and Tess's acceptance plan stay aligned.

---

## At a glance

- **Working title:** Embergrave
- **Genre / sub-genre:** Adventurous action-RPG, top-down 2D dungeon crawler with light roguelite framing (run-based descent, persistent character & gear).
- **Target platforms:** Desktop (Windows, macOS, Linux) and Web (HTML5 export). v1 ships browser-playable on itch.io; desktop builds for Steam playtest later.
- **Target audience:** Players 14+ who like *Hades*, *Tunic*, *Crystal Project*, *Diablo*-lite. Single-player. Sessions of 15–45 minutes.

## Core fantasy

You are a wandering Ember-Knight searching the buried city of Embergrave for the lost flame of your order. The city is a vertical descent — eight strata, each older and angrier than the last. The deeper you go, the more powerful the relics you recover and the meaner the things that want to keep them. You are the underdog who gets stronger every run.

## Core gameplay loop

- **Every minute:** Move through hand-crafted-feeling rooms (procedurally arranged from authored chunks), engage 1–4 mobs at a time with dodge-roll + light attack + heavy attack + one equipped relic ability, pick up gold/gear/echoes that drop on kill.
- **Every session (15–45 min):** Descend a stratum, fight a mid-boss, choose one of three relic upgrades at the shrine, hit the stratum boss, either die (lose the run, keep level XP and stash gear), or take the elevator one stratum deeper.
- **Every week:** Push the deepest-stratum-reached counter, complete bounty quests (kill X of mob Y with gear tier Z), unlock new starting kits and harder NG+ modifiers.

## Leveling & gear progression

Two parallel ladders, both visible to the player at all times.

**Character level (1–30):**
- XP from mob kills and quest turn-ins.
- Each level: +1 stat point (Vigor / Focus / Edge), unlocks gear-tier eligibility every 3 levels.
- Soft cap at 30 for v1; NG+ adds Paragon points (cosmetic-affecting passives) post-30.

**Gear tiers (T1–T6):**
| Tier | Color  | Found at strata | Stats roll  | Affixes |
|------|--------|-----------------|-------------|---------|
| T1   | Worn   | 1–2             | low         | 0       |
| T2   | Common | 1–3             | low–mid     | 1       |
| T3   | Fine   | 2–4             | mid         | 1–2     |
| T4   | Rare   | 3–6             | mid–high    | 2–3     |
| T5   | Heroic | 5–7             | high        | 3       |
| T6   | Mythic | 7–8 (boss only) | max + unique| 3 + set |

Gear slots: weapon, off-hand, armor, trinket, relic (active ability). Affixes are rolled (Diablo-style): `+8% crit`, `+12 max HP`, `chain lightning on hit`, etc. Crafting (M3) lets you reroll one affix per item.

**Combat scaling:** Mob HP and damage scale with stratum, not character level — so out-leveling content matters. Boss DPS check at strata 4 and 8 forces gear upgrades, not just XP grinding.

**"Further in the game" =** reaching a deeper stratum than last time. The run summary screen shows depth-reached / personal-best, like a roguelite, but persistent character+gear blunts the punishment of death.

## Why this will be popular

- **Reference points:** *Hades* (run loop & feel), *Diablo II* (gear affix joy), *Tunic* (mystery & vibe), *Crystal Project* (small-team scope proof), *Vampire Survivors* (proof that 2D crunchy combat scales).
- **Differentiator:** The "two ladders both matter" design. Pure roguelites lose lapsed players (no persistence). Pure ARPGs over-reward grinding. Embergrave keeps run-based dopamine *and* the satisfaction of an item that's yours forever.
- **Hook for TikTok / streams:** Big affix rolls, deepest-reached leaderboard, distinct boss silhouettes per stratum. Cheap to clip.

## Out of scope for v1

- Multiplayer (single-player only; no co-op, no PvP, no leaderboards beyond local).
- Crafting system (M3, not M1).
- Voice acting (text only).
- Procedural narrative — story is hand-written and short (~30 min of lore text total).
- Mobile builds — desktop+web only.
- Mod support, Steam Workshop, achievements (post-v1).
- Monetization — free or pay-once, no IAP, no live service. Decision deferred until post-M3.
