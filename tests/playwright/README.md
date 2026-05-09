# Embergrave Playwright E2E Harness

**Owner:** Tess (QA) | **Status:** M2 W1 expanded (AC2 + AC3 + AC4 + equip-flow + negative-assertion sweep) | **Phase:** M2 W1

End-to-end test harness for the Embergrave HTML5 build. Runs the actual artifact in Chromium, reads real `[combat-trace]` console output, and drives real DOM input events on the game canvas.

## Why this exists

Three M1 RC integration regressions reached Sponsor's manual soak before being caught:
- PR #115/#122 — white-on-white tween; GUT asserted `tween_valid=true` but pixels didn't change in real Chrome
- PR #145 — stub-Node test silently skipped `Player.equip_item`; integration broke; Sponsor saw `damage=1`
- PR #146 — boot-order clobber seeded iron_sword then wiped it three lines later; boot prints lied

This harness catches all three classes. See `team/tess-qa/playwright-harness-design.md` for the full design rationale.

---

## Quick start

### Requirements

- **Node.js 20+** (also powers the artifact HTTP server — no Python required)
- **Embergrave HTML5 artifact** — download from the GitHub Actions release-build run

### Install

```bash
cd tests/playwright
npm install
npx playwright install chromium
```

### Run (local)

```bash
# 1. Download the artifact zip from GitHub Actions
#    e.g. https://github.com/TSandvaer/RandomGame/actions/runs/25596999719
# 2. Unzip once to get the HTML5 directory:
unzip embergrave-html5-356086a-manual.zip -d ./html5-build
# 3. Run the harness:
RELEASE_BUILD_ARTIFACT_PATH=./html5-build npm test
```

### Run in headed mode (local debugging)

```bash
RELEASE_BUILD_ARTIFACT_PATH=./html5-build HEADED=1 npm test
```

### Run with UI explorer

```bash
RELEASE_BUILD_ARTIFACT_PATH=./html5-build npm run test:ui
```

---

## Specs

### `ac1-boot-and-sha.spec.ts`

**Test name:** `AC1 — build boots cleanly and HUD shows correct SHA`

**What it checks:**
- Build loads in Chromium without `console.error` lines during boot
- `[BuildInfo] build: <7-char sha>` console line present and matches artifact name
- `[Save] autoload ready (schema vN)` confirms save system wired
- `[DebugFlags] ... web=true` confirms HTML5 runtime mode active
- `[Main] M1 play-loop ready — Room 01 loaded, autoloads wired` confirms full boot
- Zero 404 network requests (favicon.ico exempt — Chrome auto-requests, not a Godot file)

**Why the boot sentinel is `[Main] M1 play-loop ready`:** This is the last `print()` in `Main._ready()` (scenes/Main.gd:147), confirming the full autoload chain completed. The design doc referenced `[Inventory] starter iron_sword auto-equipped` but that line does not exist in the codebase.

---

### `regen-smoke.spec.ts`

**Test name:** `regen smoke — out-of-combat HP regen activates after 3.0s`

**What it checks:**
- After 3.0s of idle (no damage, no attacks), regen activates
- `[combat-trace] Player | regen activated (HP N/M)` console line appears
- HP rises over 5s window (regen tick lines visible)
- After an attack, `[combat-trace] Player | regen deactivated` appears (timer reset)
- No `console.error` during the sequence

**Regen trace lines** (from `scripts/player/Player.gd:_set_regenerating()`):
```
[combat-trace] Player | regen activated (HP N/M)
[combat-trace] Player | regen tick (HP N/M)
[combat-trace] Player | regen deactivated (HP N/M)
[combat-trace] Player | regen capped (HP N/M)
```

**Note:** `[combat-trace]` lines only appear in HTML5 builds (`OS.has_feature("web") == true`). They will NOT appear in headless GUT test output.

---

### `room-traversal-smoke.spec.ts`

**Test name:** `room traversal smoke — Room 1 clear-and-walk advances to Room 2`

**What it checks:**
- Canvas focus works for keyboard/mouse events
- Combat produces `[combat-trace] Hitbox.hit | team=player target=Grunt damage=6` (iron_sword + rebalance)
- `[combat-trace] Grunt._die | starting death sequence` confirms death pipeline
- Walk south through door trigger after clear → Room 2 evidence observed
- Room counter advances after door-walk (NOT immediately on kill — Position B gate)
- No `console.error` during traversal

**Known gap (skeleton):** Room transition detection relies on console-trace evidence and attack attempts in Room 2. The Godot CanvasLayer HUD (`STRATUM 1 · ROOM 2/8`) is not DOM-addressable by Playwright — pixel-diff or a Godot JS bridge endpoint would be needed for exact HUD assertion. Deferred to follow-up.

---

### `ac2-first-kill.spec.ts` (M2 W1 expansion)

**Test name:** `AC2 — cold launch first kill in ≤60 s with weapon-scaled damage`

**What it checks:**
- Boot completes; iron_sword auto-equipped (boot integration line present)
- First grunt dies within 60s of `[Main] M1 play-loop ready`
- Hits at weapon-scaled damage (>=2; iron_sword=6, NOT fistless damage=1)
- Death pipeline runs to completion (`Grunt._force_queue_free | freeing now`)
- No `USER ERROR: Can't change this state while flushing queries` panic
- No Godot push_error during the entire run

**Why this exists:** PR #145 + #146 regression class (fistless start; integration broke despite headless tests passing).

---

### `ac3-death-persistence.spec.ts` (M2 W1 expansion)

**Test name:** `AC3 — death preserves level + V/F/E + equipped weapon`

**What it checks:**
- Player walks into grunt attack zone (no swinging) → HP=0 after ~17-30s
- Main._on_player_died → apply_death_rule respawns at Room 01 with HP refilled
- Post-respawn first hit STILL reads damage=6 (proves equipped iron_sword survived `apply_death_rule`)
- Death triggers in-game respawn, NOT engine reboot (`[Main] M1 play-loop ready` fires exactly once)

**Why this exists:** PR #146 regression class — the boot-order clobber that wiped the equipped iron_sword. The same shape can re-emerge if `apply_death_rule` ever calls `Inventory.reset()` instead of `clear_unequipped()`.

---

### `ac4-boss-clear.spec.ts` (M2 W1 expansion — currently `test.fail()`)

**Test name:** `AC4 — Stratum-1 boss reach + clear (P0 86c9q96fv + 86c9q96ht open)`

**Status:** `test.fail()` — annotated to expect failure because two open P0 bugs (`86c9q96fv` boss damage, `86c9q96ht` boss attack) make the boss currently un-killable. When the Devon/Drew fixes land, this spec flips green and the `test.fail()` annotation should be replaced with `test()`.

**What it checks (when fixed):**
- Drive Rooms 1-7, killing all mobs and walking through each gate
- Enter Boss Room (Room 8 in BOSS_ROOM_INDEX), wait 1.8s entry sequence
- Attack boss until `[combat-trace] Stratum1Boss._force_queue_free | freeing now`
- Per-room negative-assertion: `gate_traversed` does NOT fire within 100ms of `gate_unlocked` (PR #155 regression guard)
- Total 21 pre-boss mob deaths + 1 boss death

**Diagnostic-build env-var hook (proposed; NOT implemented in this PR):**
If the boss has unreasonable HP for harness time-budget after the P0 fixes land, the orchestrator may approve adding to `scripts/mobs/Stratum1Boss.gd`:

```
# In _ready (after _apply_mob_def call):
if OS.has_feature("web") and OS.has_environment("EMBERGRAVE_DIAG_BOSS_HP"):
    var diag_hp := OS.get_environment("EMBERGRAVE_DIAG_BOSS_HP").to_int()
    if diag_hp > 0:
        hp_max = diag_hp
        hp_current = diag_hp
        print("[Stratum1Boss] DIAG override hp_max=%d" % diag_hp)
```

Until orchestrator approves the game-script change, the spec runs at production HP with a 4-min boss budget (well under the AC ceiling of 10 min).

---

### `equip-flow.spec.ts` (M2 W1 expansion)

**Test name:** `equip flow — equipped weapon survives F5 reload`

**What it checks:**
- Cold boot: iron_sword auto-equipped; first hit reads damage=6
- F5 reload (page.reload) → Save autoload restores
- Post-reload: a fresh swing STILL produces damage=6 hits (proves Inventory._equipped["weapon"] AND Player._equipped_weapon both restored — the dual-surface invariant)

**Known coverage gap:** The harness cannot exercise the **in-game equip-via-LMB-click** path (open P0 86c9q96m8 — "equipping an item makes equipped slot disappear, can't re-equip") because the Tab inventory panel renders on a Godot CanvasLayer, not DOM-addressable from Playwright. The save-survival-roundtrip is the tractable half. When 86c9q96m8 is fixed and a `[combat-trace] Inventory.equip` console line is added (recommended follow-up), this spec can extend to the click-equip flow.

**Filtered known warning:** m1-rc-1 emits a benign `USER WARNING: ItemInstance.from_save_dict: unknown item id 'iron_sword'` during save-restore. The spec ignores this specific warning (the player surface still ends up correct via `equip_starter_weapon_if_needed` post-restore). Filing a sibling ticket for the warning itself is the right move.

---

### `negative-assertion-sweep.spec.ts` (M2 W1 expansion)

**Test names:**
- `Test 1: boot-ready trace fires exactly once per page lifecycle`
- `Test 2: Room 01 emits zero RoomGate traces (no gate baseline)`
- `Test 3: gate_traversed never precedes gate_unlocked (causality invariant)`

**What they check:** Per `.claude/docs/combat-architecture.md` § "State-change signals vs. progression triggers" — that state-change signals do NOT short-circuit to progression triggers (PR #155 cautionary tale).

- **Test 1:** `[Main] M1 play-loop ready` fires exactly once; `[Inventory] starter iron_sword auto-equipped` fires at most once (PR #146 regression guard).
- **Test 2:** Stratum1Room01 has no RoomGate per Main.gd:381; ZERO `[combat-trace] RoomGate.*` traces should fire during Room 01 combat.
- **Test 3:** Static causality invariant: every `gate_traversed` line in the trace stream must have a preceding `gate_unlocked emitting` line. Within a same-tick window (200ms), `gate_traversed` must NOT chain auto-emit from `gate_unlocked`.

**Known gap (Shooter STATE_POST_FIRE_RECOVERY):** Per `combat-architecture.md`, "absence of state X means Y" is the anti-pattern this sweep targets. The current Shooter code does NOT emit an explicit `[combat-trace] Shooter.set_state | post_fire_recovery (entered)` line — only a `_process_post_fire | closing gap...` line that recurs while in that state. Adding the explicit ledger trace is a recommended follow-up for Drew/Devon; once that lands, a fourth test in this spec can assert the trace fires when expected.

---

## Fixtures

### `artifact-server.ts`

Playwright `globalSetup` — reads `RELEASE_BUILD_ARTIFACT_PATH`, spawns `python -m http.server 0` (ephemeral port), writes `PLAYWRIGHT_BASE_URL` to environment. Tears down on exit.

### `console-capture.ts`

Wraps `page.on("console", ...)`. Provides:
- `capture.attach()` — start capturing (call before `page.goto()`)
- `capture.waitForLine(pattern, timeoutMs)` — wait for matching console line
- `capture.getLines()` — all captured lines
- `capture.clearLines()` — reset buffer
- `capture.findFirstError()` — first `console.error` (Godot `push_error`)
- `capture.dump()` — full text dump for CI artifacts

### `cache-mitigation.ts`

Chromium launch options and context options that bypass the Godot service-worker cache trap. See `.claude/docs/html5-export.md` § "Service-worker cache trap".

Key mitigations:
1. `serviceWorkers: "block"` — blocks SW registration entirely at context level
2. `--disable-cache` — disables HTTP disk cache
3. `--disable-application-cache` — disables legacy AppCache

---

## CI integration

The harness runs via `.github/workflows/playwright-e2e.yml`:
- **Primary trigger:** after `Release to GitHub (M1 RC build)` completes successfully on `main`
- **Manual trigger:** `workflow_dispatch` with optional `artifact_run_id`
- **Artifacts on failure:** `playwright-report-<run_id>` (HTML report) + `playwright-test-results-<run_id>`

---

## Known gaps (follow-up PRs)

| Gap | Status |
|---|---|
| AC2 cold first-kill in 60s | **Landed (M2 W1)** — `ac2-first-kill.spec.ts` |
| AC3 death preservation | **Landed (M2 W1)** — `ac3-death-persistence.spec.ts` |
| AC4 boss clear | **Landed as `test.fail()` (M2 W1)** — `ac4-boss-clear.spec.ts`. Flips green when P0 86c9q96fv + 86c9q96ht close |
| Equip flow (save-survival) | **Landed (M2 W1)** — `equip-flow.spec.ts` |
| Negative-assertion sweep | **Landed (M2 W1)** — `negative-assertion-sweep.spec.ts` |
| AC5 full 30-min console silence | Follow-up |
| AC6 F5 / close-tab quit-relaunch | Follow-up (note: equip-flow already exercises F5 path) |
| AC7 gear drops with affixes | Deferred (RNG-seed injection design needed) |
| Equip-via-LMB-click (UI flow for P0 86c9q96m8) | Deferred — Godot CanvasLayer not DOM-addressable. Needs Godot JS bridge or `[combat-trace] Inventory.equip` console line addition |
| Shooter STATE_POST_FIRE_RECOVERY ledger trace | Follow-up — Drew/Devon to add `[combat-trace] Shooter.set_state \| post_fire_recovery (entered)` line |
| Exact HUD room counter assertion | Needs Godot JS bridge or pixel-diff (Tier 3 deferred) |
| Canvas-focus reliability on different viewports | Verify in CI; may need `page.locator('canvas').focus()` before input events |

---

## Environment variables

| Var | Required | Description |
|---|---|---|
| `RELEASE_BUILD_ARTIFACT_PATH` | **Yes** | Path to the unzipped HTML5 directory (`index.html` must be inside) |
| `HEADED` | No | Set to `1` to run Chromium in headed mode (local debugging) |
| `PLAYWRIGHT_BASE_URL` | No | Override base URL (default: set by artifact-server from ephemeral port) |
| `CI` | No | Set by GitHub Actions; enables retries and forbids `test.only` |
| `EMBERGRAVE_DIAG_BOSS_HP` | No | **Proposed (NOT yet implemented in game scripts)** — would let `ac4-boss-clear.spec.ts` nerf the boss for harness time-budget. Requires orchestrator approval before adding the corresponding `Stratum1Boss.gd` hook. See `ac4-boss-clear.spec.ts` header for the proposed diff. |
