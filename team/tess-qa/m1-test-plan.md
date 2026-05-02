# M1 Acceptance Test Plan — Embergrave

Owner: Tess (QA). Verifies the **7 acceptance criteria** from `team/priya-pl/mvp-scope.md`. This is the gate the M1 build must pass before Sponsor playtest.

**Binding context:** `team/TESTING_BAR.md` (Sponsor's "no debugging" directive). Tess is the **only** role that flips feature ClickUp tasks from `ready for qa test` → `complete`. Devs do not self-sign. If Sponsor finds a bug at sign-off, the team has failed its bar.

## Scope

- **In scope:** All 7 M1 acceptance criteria, regression sweep, per-feature edge-case probes, and the deliberately stubbed M1 surfaces (1 stratum, 3 mob archetypes by build time, weapon + armor only, T1–T3, level cap 5, JSON save).
- **Out of scope:** Anything tagged M2+ in `mvp-scope.md` (off-hand/trinket/relic slots, crafting, audio score, controller, story text, settings beyond volume + fullscreen).
- **Test methodology:** Manual exploratory + scripted manual cases below + automated GUT unit/integration tests — see `automated-smoke-plan.md`. Per-feature edge-case probes (≥3 per feature) — see "Edge-case probe matrix" below. One soak session per release candidate — see soak-template.

## Inventory targets (per `TESTING_BAR.md`)

| Layer                             | Target for M1 sign-off              | Tracked in                           |
|-----------------------------------|--------------------------------------|---------------------------------------|
| Unit tests (GUT)                  | ~20–30                               | `automated-smoke-plan.md`             |
| Integration tests (GUT scene)     | ~10–15                               | `automated-smoke-plan.md`             |
| Manual cases (this doc)           | ~30–50 across 7 ACs + regression     | "Test cases" + "Regression sweep"     |
| CI green                          | Every push                           | GitHub Actions workflow                |
| Soak sessions                     | ≥1 per release candidate             | `team/tess-qa/soak-<date>.md`          |
| Edge-case probes                  | ≥3 per feature shipped               | "Edge-case probe matrix" below         |

## Severity definitions (per `TESTING_BAR.md`)

| Severity   | Definition                                                                                                   | M1 ship?                | Action                                          |
|------------|--------------------------------------------------------------------------------------------------------------|-------------------------|-------------------------------------------------|
| `blocker`  | M1 cannot ship. Acceptance criterion fails OR build unplayable / unrecoverable / corrupts saves.             | No.                     | Stop M1 sign-off. PL + Devon paged.             |
| `major`    | M1 ships impaired. Real defect, AC passes via workaround, or affects only one platform. Must fix in M2.       | Yes, fix M2.            | Logged as M2 ClickUp task before sign-off.      |
| `minor`    | M1 ships. Cosmetic / copy / low-frequency edge case. Fix when convenient.                                     | Yes.                    | Backlog tag. No release-blocker triage.         |

**Sponsor sign-off gate (orchestrator-enforced):** zero `blocker` AND zero `major` open against M1 before any Sponsor ping.

A criterion **passes** only when every test in its block reads `pass` and no `blocker` is open against it. A single `blocker` against a criterion fails M1 sign-off.

## Build identification

Every test run records: build artifact (HTML5 zip filename or Windows exe), git SHA, target environment (browser+OS or native), tester, date. Builds without a SHA are rejected — Devon's CI pipeline must stamp it.

## Per-feature sign-off flow (Tess-only gate)

Per `TESTING_BAR.md`, every feature ClickUp task transitions:

`to do` → `in progress` → `ready for qa test` → **(Tess)** → `complete`

When a feature is in `ready for qa test`, Tess runs:

1. The acceptance test from this plan if the feature touches an AC.
2. The matching unit/integration test in GUT (must already be authored and green in CI).
3. The **edge-case probe matrix** below — minimum 3 probes per feature.
4. A 5-min freeplay using the feature in normal flow.

Outcome: either flip to `complete`, or bounce back with a `bug(...)` ClickUp task tagged severity. The dev does **not** flip the task themselves — the transition is Tess-only.

## Edge-case probe matrix (≥3 per feature, per TESTING_BAR.md)

For every feature that lands in `ready for qa test`, Tess runs at least 3 of these probes — picking the ones most relevant to the feature's surface. Pick from the menu; document which probes ran in the ClickUp task.

| Probe ID  | Probe                          | What to do                                                                                          | Catches                                       |
|-----------|--------------------------------|-----------------------------------------------------------------------------------------------------|------------------------------------------------|
| `EP-RAPID`| Rapid input                    | Mash the feature's input as fast as possible (LMB spam, attack-during-attack, dodge-during-dodge).  | Frame-skip glitches, double-fires, queue overflows. |
| `EP-INTR` | Mid-action interrupt           | Trigger the feature, then interrupt it with another action mid-animation (attack mid-dodge, equip mid-attack, quit mid-save). | Animation/state-machine race conditions.       |
| `EP-RT`   | Save/load round-trip           | Save while the feature is active, reload, verify the feature's state survives correctly.            | Save schema gaps, run-vs-persistent confusion. |
| `EP-BLUR` | Tab-blur / focus loss (HTML5)  | Alt-tab away mid-action, return after 5–30s, verify state is sane.                                  | Suspended-physics bugs, lost timers.           |
| `EP-EDGE` | Geometry/range edge            | Trigger at extreme positions (room corner, against wall, max range, off-screen).                    | Collision corner cases.                        |
| `EP-DUP`  | Duplicate trigger              | Trigger the feature twice on the same target / same frame / same tick.                              | Double-pickup, double-damage, ID collisions.   |
| `EP-OOO`  | Out-of-order sequence          | Run the feature's prereq steps in the wrong order (open inventory before any drop, equip an empty slot, level-up at cap). | Missing guards.                              |
| `EP-MEM`  | Memory pressure                | Run the feature 50+ times in a session, watch tab memory in DevTools.                               | Resource leaks, signal-listener leaks.         |

**Rule:** If a probe finds a defect, file a `bug(...)` task with severity. If the probe finds nothing, note "EP-X clean" in the ClickUp `ready for qa test` → `complete` transition comment. Empty probe runs still count.

## Soak session

Each release candidate (any build candidate for Sponsor sign-off) gets at least one **30-minute uninterrupted soak**, performed by Tess. Documented in `team/tess-qa/soak-<YYYY-MM-DD>.md` using the soak template. Findings get filed as bugs with severity. A release candidate is not ready for Sponsor until at least one clean (zero-blocker, zero-major-found) soak.

## Test cases

Columns: **ID** · **Setup** · **Action** · **Expected** · **Result** · **Severity (if fail)**.

`Result` values: `pass` / `fail` / `blocked` / `n/a`.

---

### AC1 — Build is reachable from a single URL or a single zipped exe

| ID            | Setup | Action | Expected | Result | Severity |
|---------------|-------|--------|----------|--------|----------|
| `M1-AC1-T01`  | Fresh browser profile, no prior visits. Sponsor's itch.io URL provided by Devon. | Paste URL into Chrome address bar, press Enter. | itch.io page loads in ≤5s; "Play in browser" button visible; clicking it boots the game canvas with no console errors. | | |
| `M1-AC1-T02`  | Same URL. | Open in Firefox (latest stable). | Same as T01. | | |
| `M1-AC1-T03`  | itch.io page loaded. | Click the Windows download link, save zip, extract, double-click the `.exe`. | Zip contains exactly one exe + Godot pck (no orphan source files); exe launches to title screen with no missing-DLL prompts. | | |
| `M1-AC1-T04`  | URL only — no extra credentials, no extra steps. | Confirm Sponsor receives **one** URL via email, no passwords, no install instructions. | URL is self-sufficient; no auth wall blocks Sponsor; itch.io visibility is set to "private — anyone with the link". | | |
| `M1-AC1-T05`  | Devon's CI build artifact page. | Verify the HTML5 zip and Windows zip are produced by the same git SHA. | Both artifacts in the same CI run, same SHA stamp visible in main menu / about screen. | | |

---

### AC2 — From cold launch to first mob killed: ≤ 60 seconds

| ID            | Setup | Action | Expected | Result | Severity |
|---------------|-------|--------|----------|--------|----------|
| `M1-AC2-T01`  | Cold browser tab (no cache from this game). HTML5 build URL ready. Stopwatch ready. | Start stopwatch the moment Enter is pressed on the URL. Click `New Game` as soon as title screen appears. Sprint to nearest mob. Light-attack until it dies. Stop stopwatch on death animation finish. | Total elapsed ≤60s. Title screen interactive in ≤15s after URL load. | | |
| `M1-AC2-T02`  | Repeat T01 with cache warm (second launch). | Same. | ≤60s easily; expected ≤40s warm. | | |
| `M1-AC2-T03`  | Windows native build, cold launch. | Same. | ≤60s. Native should be faster than HTML5 cold. | | |
| `M1-AC2-T04`  | Throttled connection — Chrome DevTools "Fast 3G" preset. HTML5 URL. | Cold launch, time to first kill. | ≤60s on Fast 3G. If failing, log as `major` — Sponsor's connection is unknown but reasonable. (Build size budget: HTML5 zip ≤25 MB unpacked, ~10 MB compressed, target.) | | |
| `M1-AC2-T05`  | HTML5 build, cold launch. | Time each segment: URL → playable canvas, title → in-game, in-game → first mob in sight, first hit → kill. Record splits. | All splits sum ≤60s. **Splits are diagnostic** — failing T01 means we know which split to fix. | | |

---

### AC3 — A death does not lose character level or stashed gear

| ID            | Setup | Action | Expected | Result | Severity |
|---------------|-------|--------|----------|--------|----------|
| `M1-AC3-T01`  | Fresh save. Play until character is **level 3** with at least 2 items in stash (one weapon, one armor). Note exact level, XP %, equipped gear, and stash contents. | Walk into mobs. Die. | Death screen appears. Character level still 3. Stash contents intact. Equipped gear intact. XP into level 3 may reset to 0 (run-XP loss is acceptable; **level loss is not**). | | |
| `M1-AC3-T02`  | Continue from T01 death. | Click "Restart Run". | New stratum-1 run starts with same character level, same stat-point allocations, same stash and equipped gear as before death. | | |
| `M1-AC3-T03`  | Inspect the JSON save file in `user://` (HTML5: IndexedDB; native: `%APPDATA%/Godot/app_userdata/Embergrave/`). | Open save in a text editor. | One save record per character. `level` field unchanged across the death. `stash` array unchanged. `equipped` map unchanged. No "session" or "run" data leaks into the persistent block. | | |
| `M1-AC3-T04`  | Edge case: die **during** a stratum exit / mid-save. | Force a death within ≤1s of triggering save (have Devon expose a debug command or use a known-slow save in HTML5). | Save is not corrupted. Character level + stash intact on relaunch. (If save is mid-write at death, last-known-good save must be readable.) | | |
| `M1-AC3-T05`  | Multiple deaths in a row: die 5 times in stratum 1. | Each death → restart → die again. | Level + stash invariant across all 5. No drift, no duplicate item IDs, no "ghost" gear in stash. | | |

---

### AC4 — Player can clear stratum 1 boss in under 10 minutes once gear-appropriate

"Gear-appropriate" = character level 4–5, at least T2 weapon equipped, full HP entering the room. Tess defines this baseline; Devon's combat tuning targets it.

| ID            | Setup | Action | Expected | Result | Severity |
|---------------|-------|--------|----------|--------|----------|
| `M1-AC4-T01`  | Fresh character, play through stratum 1 normally to the boss room. Stopwatch starts on boss-room entry, stops on boss death animation. Character is level 4+, T2 weapon equipped. | Engage boss; play to clear or wipe. | Boss cleared in ≤10 min. **Target** is ≤6 min for an experienced player; 10 min is the outer bound. | | |
| `M1-AC4-T02`  | Same as T01 but at the **floor** of "gear-appropriate": level 4, T1 weapon. | Engage boss. | Either: clear in ≤10 min, OR wipe with the boss reaching ≤30% HP (within 1–2 attempts of clear). Total cumulative time ≤10 min across attempts. | | |
| `M1-AC4-T03`  | Same as T01 but **over-leveled**: level 5, T3 weapon, full stat points spent into Edge. | Engage boss. | Clear in ≤4 min — proves there's no DPS wall the player can't cross with reasonable gear. | | |
| `M1-AC4-T04`  | Boss room, deliberate stalling: dodge-only for 60s without attacking. | Walk in, dodge-roll only, no attacks. | Boss does not auto-kill; player can survive ≥30s of pure dodging if positioned reasonably. (Validates i-frame timing and arena size.) | | |
| `M1-AC4-T05`  | Boss room, deliberate cheese check. | Look for unintended invulnerable spots, geometry exploits, knock-out-of-arena bugs. | No exploit allows trivializing the boss. If found, log as `major` (stratum-1 boss is the M1 climax). | | |

---

### AC5 — No hard crashes in a 30-minute play session

A "hard crash" = browser tab closed by the engine, native exe terminated, or GDScript fatal error halting the main loop. Frame drops, recoverable in-game errors (a spell that fails silently), and console warnings are not crashes.

| ID            | Setup | Action | Expected | Result | Severity |
|---------------|-------|--------|----------|--------|----------|
| `M1-AC5-T01`  | Cold-launched HTML5 build in Chrome. Browser DevTools console open and recording. Stopwatch. | Play continuously for 30 minutes. Mix: stratum 1 runs, deaths, restarts, inventory open/close, save-on-quit-but-don't-quit (force a save tick), stratum boss attempts. | Zero hard crashes. Browser tab stays alive. Console may show warnings but no uncaught exceptions in user code paths. | | |
| `M1-AC5-T02`  | Same on Firefox. | Same 30-min playthrough. | Same. | | |
| `M1-AC5-T03`  | Windows native build. | Same 30-min playthrough. | No exe termination. No "Godot has stopped responding" dialog. | | |
| `M1-AC5-T04`  | HTML5 build, **alt-tab stress**: alt-tab away every 90s for 30 min. | Play normally between alt-tabs. | No crash on focus regain. Game pauses or continues gracefully (whichever Devon chose — log decision in `DECISIONS.md`). | | |
| `M1-AC5-T05`  | HTML5 build, **resize stress**: resize browser window 10× during the session. | Resize between portrait-ish and landscape-ish, narrow and wide. | No crash. Canvas adapts (or letterboxes — either is acceptable for M1). | | |
| `M1-AC5-T06`  | HTML5 build, **memory leak watch**: 30 min on the same tab, 50+ mob kills, 10+ deaths, 20+ inventory opens. Monitor browser tab memory in DevTools. | Same as T01 with memory profiling. | Memory rises but plateaus; no unbounded growth (heuristic: >2× start memory after stable-state is suspicious). | | |

---

### AC6 — Save survives a quit-and-relaunch cycle

| ID            | Setup | Action | Expected | Result | Severity |
|---------------|-------|--------|----------|--------|----------|
| `M1-AC6-T01`  | Fresh save. Play until character is level 2 with one stash item. Open inventory, equip the item, close inventory. Spend a stat point. | Quit via main menu's Quit option. Relaunch. Click Continue. | Character level 2, stat point spent, item still equipped, stash empty (item is equipped, not stashed). All exact. | | |
| `M1-AC6-T02`  | Repeat T01 but **on stratum exit save** (per M1 spec: auto-save fires on stratum exit). | Walk to stratum-1 exit → boss room transition → save tick. Quit to OS. Relaunch. | Continue resumes at the post-save state, no progress lost. | | |
| `M1-AC6-T03`  | HTML5 build, **close tab** instead of menu Quit. | Mid-game, ctrl+W (or close tab button). Reopen URL. Click Continue. | Save covers the most recent save tick — last stratum exit OR an explicit save (not the moment of tab-close). Acceptable to lose run progress; **not** acceptable to lose persistent character data. | | |
| `M1-AC6-T04`  | Native build, **kill via task manager** mid-run. | Task-manager-end the process. Relaunch exe. Continue. | Same as T03: persistent char data intact; run progress may be lost. | | |
| `M1-AC6-T05`  | HTML5 build, **clear cache and revisit URL** (simulates IndexedDB wipe). | Clear browser data for the itch.io domain. Reload the game URL. | Game offers New Game (no Continue). This is **expected behavior** — verifies save lives in the right place and doesn't unexpectedly persist somewhere else. | | |
| `M1-AC6-T06`  | Two characters in same save slot (if M1 supports multi-character — clarify with Devon; M1 spec implies single character). | Save A, switch to character B (if possible), save, relaunch. | Either: M1 is single-character (all of T06 is `n/a`), OR both saves load distinctly. | | |

---

### AC7 — Two distinct gear drops with visibly different affixes are findable in stratum 1

| ID            | Setup | Action | Expected | Result | Severity |
|---------------|-------|--------|----------|--------|----------|
| `M1-AC7-T01`  | Fresh character. Clear stratum 1 fully (8 rooms, all mobs, boss). Open inventory at the end. | Inspect every gear drop received over the run. | At least 2 gear items in inventory whose **affix lines differ** — not just stat rolls, but actually different affixes from the 3-affix M1 pool. (E.g. one has `+8% crit`, another has `+12 max HP`.) | | |
| `M1-AC7-T02`  | Repeat T01 across **5 separate runs**. | Aggregate: across 5 runs, count distinct affixes seen. | Across 5 runs, all 3 M1 affixes have appeared at least once. (Validates the drop pool isn't biased to one affix.) | | |
| `M1-AC7-T03`  | Stratum 1, one full clear. | Inspect the gear's tooltip / inventory display. | Affix text is **legible** at the M1 UI scale (Uma's mockup). Different affixes are visibly distinct (color, position, or label) — not all rendered identically. | | |
| `M1-AC7-T04`  | Drop a T1 vs a T3 weapon side by side in inventory. | Compare. | Tier is visually distinguishable (Worn vs Fine — color or label per tech-stack tier table). | | |
| `M1-AC7-T05`  | Equip a gear with affix `+12 max HP` (or whichever HP affix is in the pool). Note current max HP. Equip a gear without that affix. | Equip → check HP → swap → check HP. | Max HP value updates to reflect the affix. Affixes are functional, not just cosmetic. | | |

---

## Regression sweep

Every release-tagged build (any build that goes to Sponsor or to itch.io main page) re-runs this **shorter** suite. Goal: ≤30 minutes per pass so it actually happens.

| ID              | What                                                                              | Why                                                                               |
|-----------------|-----------------------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| `REG-BOOT`      | `M1-AC1-T01` + `M1-AC1-T03` (HTML5 + Windows boot to title).                      | Build pipeline broke is the #1 risk on small teams.                                |
| `M1-AC2-T01`    | Cold-launch to first kill, HTML5.                                                  | Catches asset-import slowdowns and main-menu regressions.                          |
| `M1-AC3-T01`    | Death keeps level + stash, single character.                                       | The save schema's the most fragile shared surface; regress here often.             |
| `M1-AC6-T01`    | Quit-and-relaunch, single character.                                               | Same reason as AC3.                                                                |
| `REG-COMBAT`    | Move + dodge + light + heavy attack in any room. Verify dodge i-frames work.       | Movement + combat are the moment-to-moment feel; we notice within seconds.          |
| `REG-INV`       | Open inventory, equip an item, see stat update, unequip.                           | Inventory's 3 sub-systems (UI, equip slot logic, stat propagation) regress easily.  |
| `REG-MOB`       | Encounter all 3 mob archetypes (grunt, shooter, charger), confirm each behaves.    | Each archetype has unique AI; one breaking is invisible until tested.               |
| `M1-AC7-T01`    | One full stratum-1 clear, ≥2 distinct affixes drop.                                 | Loot RNG is the easiest place for a "looks fine but actually broken" regression.    |
| `REG-NOERROR`   | 5-min play with browser console open. No uncaught exceptions.                       | Cheapest catch for silent regressions — read console while playing.                  |

**Regression run cadence:**

- Every build pushed to itch.io: full sweep above.
- Every PR merged into `main` (post-week-1 once branches exist): `REG-BOOT` + `REG-NOERROR` minimum, run by CI smoke + manual eye-check.
- Before Sponsor playtest: full M1 acceptance suite (all 7 ACs) + this regression sweep + an exploratory 30-min freeplay.

## Exit criteria for M1 Sponsor sign-off

All 7 ACs read `pass`. Zero `blocker` severity bugs open. Regression sweep clean. Exploratory 30-min freeplay produced no crash, no save corruption, no progress loss. Tess signs off in `team/STATE.md` Sponsor sign-off queue with build SHA + date.

## Notes for Devon & Drew (testability hooks needed)

For Tess to actually run these tests effectively, the build must expose:

1. **Build SHA visible in the main menu** (a small "build: abcdef1" footer is fine). AC1, all regression runs.
2. **A debug-only "fast-XP" toggle** — gated behind a hidden key combo, not shipped to Sponsor — so Tess can reach level 4–5 in <2 min for AC4/AC7 testing.
3. **Save file location documented** in a one-liner README inside the user data dir. AC3-T03, AC6.
4. **Stable mob spawn seed in test mode** so AC4 setup isn't 30 min of grinding to retry.
5. **A console output mode for HTML5 builds** that surfaces uncaught GDScript errors to the browser console (Godot's default does this; verify it's not stripped from release).

Tess will request these from Devon as ClickUp `chore(test-hooks)` tasks.
