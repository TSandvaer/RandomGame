# MVP Scope — Embergrave

## M1 — First Playable (Sponsor sign-off candidate #1)

The smallest build that proves the core loop is fun. Sponsor plays it; we either keep going or pivot.

### What the player can do in M1

- Launch the game in a browser (itch.io HTML5) or download a Windows build.
- See a title screen → New Game → drop into stratum 1.
- Move (WASD/arrows), dodge-roll (space), light attack (LMB), heavy attack (RMB).
- Fight 3 mob archetypes (melee grunt, ranged shooter, charger).
- Take damage, take hits with i-frames during dodge, die, see a death screen, restart run.
- Gain XP from kills, level up (1 → 5 cap in M1), spend stat points (Vigor / Focus / Edge).
- Pick up gear drops (weapon + armor only in M1; T1–T3 tiers; 3 affixes total in pool).
- Open a tab-key inventory, equip/unequip gear, see stats update.
- Clear stratum 1 (8 rooms, hand-arranged from 4 chunks), face the stratum-1 boss, win → see "Descend" screen → reset run with character level + stash kept (death also keeps these).
- Save automatically on stratum exit and on quit. Reload the same character on next launch.

### Deliberately stubbed / deferred to M2+

- Stratum 2–8 (only stratum 1 is playable in M1).
- Off-hand, trinket, relic gear slots (weapon + armor only).
- Crafting / affix rerolling.
- Audio: placeholder SFX only, one looping ambient track.
- Story / lore text — title-card paragraph only.
- Quests / bounties.
- Settings menu beyond volume + fullscreen.
- Controller support (keyboard + mouse only).
- Visual juice (screen shake, hit-stop, particles) — minimum viable only.

### Acceptance criteria (Sponsor tests these)

1. Build is reachable from a single URL or a single zipped exe.
2. From cold launch to first mob killed: ≤ 60 seconds.
3. A death does not lose character level or stashed gear.
4. Player can clear stratum 1 boss in under 10 minutes once gear-appropriate.
5. No hard crashes in a 30-minute play session.
6. Save survives a quit-and-relaunch cycle.
7. Two distinct gear drops with visibly different affixes are findable in stratum 1.

### Time estimate

In orchestrator heartbeat ticks (~20 min each), assuming the team works async across ticks:

- **M1 estimate: ~80–100 ticks of active orchestration** (~27–33 hours of active dispatch over the calendar weeks of part-time work).
- Week-1 budget: ~30 ticks (scaffold, core movement, one mob, save loop).
- Week-2 budget: ~30 ticks (combat depth, gear drops, inventory, level-up).
- Week-3 budget: ~20 ticks (stratum-1 boss, polish pass, itch.io build pipeline).
- Week-4 budget: ~10–20 ticks buffer + Tess's full pass + Sponsor playtest cycle.

## M2 — Vertical Slice (paragraph)

Strata 1–3 playable end-to-end, all 5 gear slots active, T1–T4 gear, one relic ability per slot (4 total), 6 mob archetypes plus 3 stratum bosses, basic audio score (3 tracks), settings menu, controller support, run-summary screen with depth-reached / personal-best. Sponsor playtest #2. Time estimate: ~60 ticks beyond M1.

## M3 — Content Complete (paragraph)

All 8 strata, T1–T6 gear, full affix pool (~40 affixes), crafting/reroll bench, bounty quest system, NG+ Paragon track, all bosses, all 12 mob archetypes, full music score, lore text completed. itch.io public release + Steam playtest application. Sponsor playtest #3 = ship sign-off. Time estimate: ~120 ticks beyond M2.
