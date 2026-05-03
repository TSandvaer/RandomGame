# Sponsor-Soak Prep Checklist & Per-AC Probe Targets (M1)

**Owner:** Uma · **Phase:** M1 RC sign-off prep (anticipatory; revisable post-Sponsor sign-off) · **Drives:** Sponsor's interactive 30–45 min M1 soak, Tess's bug-triage from soak findings, orchestrator's per-soak surface URL hand-off, Priya's R6 mitigation (Sponsor-found-bugs flood when soak resumes).

This doc is the structured pre-flight + per-AC probe-target guide that turns Sponsor's interactive soak from a "click around and see what breaks" exercise into an efficient diagnostic pass. The motivation: Tess run-024's `m1-bugbash-4484196.md` surfaced **8 bugs in <10 min** once Sponsor knew where to look; the discovery flow could have been faster with a structured "open this, check that, note this" guide. This doc is that guide.

## TL;DR (5 lines)

1. **Time budget:** 30–45 min full soak; 15 min express soak (the 3 most-diagnostic ACs only — see §6) if Sponsor's window is tight.
2. **Output Sponsor produces:** structured per-bug bullet (where / expected / actual / severity-guess) — see §7 template; verbal "clean / bugs / mixed" verdict at end.
3. **Per-AC probes** — for each of the 7 M1 ACs (§5): one canonical reproduction shape, expected-vs-observed-as-stub framing, edge cases worth probing, "feel" questions vague enough to leave to Sponsor's judgment.
4. **Carry-forward probe targets** from `team/tess-qa/html5-rc-audit-591bcc8.md` SP-1..SP-7 + `m1-bugbash-4484196.md` BB-1..BB-8 — top three high-signal: (a) DevTools console silence across the soak, (b) tab-blur during boss intro, (c) save → close tab → reload state survival.
5. **Fidelity-expectation guardrails** — what's NOT in M1 (no tile sprites, no audio, no animations, programmer-art HUD) so Sponsor doesn't spend a soak slot reporting "no sound" as a regression.

---

## Source of truth (what was read to author this)

Per `agent-verify-evidence.md` — every probe target below derives from a direct read this session:

- **`team/tess-qa/html5-rc-audit-591bcc8.md`** (Tess run-018) — SP-1..SP-7 Sponsor probe targets; carry-forward into §8.
- **`team/tess-qa/m1-bugbash-4484196.md`** (Tess run-024) — BB-1..BB-8 bug rows; the "8 bugs in <10 min" episode this checklist is meant to make repeatable. BB-1 (footer reads dev-local) + BB-2 (saved Inventory items dropped) are the two traps every soak should screen for in the first 5 min.
- **`team/priya-pl/mvp-scope.md`** §M1 — the 7 ACs the soak verifies + §"Deliberately stubbed / deferred to M2+" for §3 below.
- **`team/tess-qa/m1-test-plan.md`** §AC1..AC7 — Tess's per-AC test cases; §5 distills these into Sponsor-facing verbal probe shapes (no test-case ID jargon).
- **`team/tess-qa/soak-template.md`** + `soak-2026-05-02.md` — soak-shape template; this doc complements (not duplicates) the soak log itself.

---

## 1. Pre-soak setup (before the stopwatch starts)

Takes ~3 min before Sponsor plays.

### 1.1 — Build artifact download

- [ ] Orchestrator surfaces soak URL: `https://github.com/TSandvaer/RandomGame/actions/runs/<run-id>` + artifact `embergrave-html5-<short-sha>`.
- [ ] Click into the run page → Artifacts → download zip (~8.4 MB). Unzip to a clean directory.
- [ ] Verify zip contains 8 files: `index.html` / `.js` / `.wasm` / `.pck` / `.audio.worklet.js` + 3 PNG icons. All non-zero. If short/empty, stop soak — surface to orchestrator.

### 1.2 — Local serve

HTML5 needs HTTP — `file://` fails cross-origin. Run:

```
cd <unzip-dir>
python -m http.server 8000
```

Open Chrome (or Firefox) at `http://localhost:8000/`. Canvas boots ≤5 s. If 30 s+ black canvas, check DevTools console for fetch errors (most common: python server cwd wrong).

### 1.3 — DevTools console open (F12) — highest-leverage pre-soak action

Open BEFORE canvas boots so boot-time prints are captured.

- [ ] **Boot smoke lines** should appear:
  - `[Save] autoload ready (schema v3)`
  - `[BuildInfo] build: <7-char SHA>` — **MUST NOT read `dev-local`** (BB-1 trap; if it does, the soak is on the wrong build or BB-1 regressed).
  - `[DebugFlags] debug_build=...`
- [ ] **Watch for `push_error` (red lines)** the entire soak. Zero tolerance — every red line is a candidate bug. Note the room/state.
- [ ] **Watch for `push_warning` (yellow)** — these two MUST NOT fire (any firing = bug):
  - `[Save] save_game(0) failed at atomic_write` (OPFS write rejected).
  - `ItemInstance.from_save_dict: unknown item id '<id>'` (BB-2 regressed).
- [ ] **Network 404s** — zero after boot.

### 1.4 — Recording (optional)

If Sponsor wants to share findings post-soak: Win+G → Xbox Game Bar → Capture, OBS, or browser extension. Capture DevTools console alongside canvas to catch error-coincides-with-glitch correlations. §7 verbal template is sufficient if time is tight.

### 1.5 — Stopwatch ready

Start from canvas-boot, not from New Game click. See §4 for time budget.

---

## 2. Known-state primer (so Sponsor recognizes "this is fine")

Two minutes of orientation before the stopwatch starts. Sponsor reads the bullet list, then begins.

- **Build context:** This is M1 — "First Playable." A systems-complete prototype: every M1 system is wired (combat, levelup, gear, save, boss, descend), but **the visible fidelity is programmer-art**. See §3 for the explicit "what's stubbed" list.
- **Death rule (M1-spec, locked in DECISIONS):** A death keeps **character level + spent stat points (V/F/E) + equipped items**. A death wipes **mid-level XP + unequipped stash items + cleared-room progress**. This is a deliberate M1 choice — runs "matter" in the sense that gear+points stick, but a death is a real reset of the run.
- **Quit-relaunch (different from death):** Closing the tab and reopening — or hitting F5 — should restore the **full** state including unequipped stash items and cleared rooms. This is NOT a death; it's a session resume. Verifies AC6.
- **Boss is in this build.** Stratum-1 (8 rooms) → boss room → boss → "Descend" overlay. The descend screen is a placeholder — that's expected (M2 owns the hub-town).
- **Audio is silent.** This is correct, not a bug (BB-8). No SFX, no music. M1 ships silent.

---

## 3. What NOT to expect (fidelity-expectation guardrails)

Before Sponsor reports a "bug," check this list. These are **deliberately stubbed M1** per `mvp-scope.md` §"Deliberately stubbed / deferred to M2+" — not regressions.

| Surface | M1 ships | M2+ delivery |
|---|---|---|
| Tile sprites | Colored squares (programmer-art) | M2 sprite pass + Cinder Vaults palette (S2) |
| Mob sprites | Colored squares with directional triangles | M2 soft-retint sprite work |
| Audio (SFX + music + ambient) | Silent — no `AudioStream*` instances anywhere | M2-w1 first-pass cue batch (10 cues per `audio-sourcing-pipeline.md`) |
| Animations | None — Godot `Tween` modulate flashes only (per `combat-visual-feedback.md`) | M2 sprite-frame animations once art lands |
| HUD styling | Programmer-art (HP bar, XP bar, level label, room counter, build SHA footer) | M3 polish pass |
| Particles / screen shake | Minimum viable per `combat-visual-feedback.md` (6-particle ember burst, 4 px shake on boss death) | M2 polish |
| Story / lore | Title-card paragraph only | M3 narrative pass |
| Settings menu | Volume + fullscreen only (if either is wired) | M2 |
| Controller support | None — keyboard + mouse only | M2 |
| Stash / ember-bag UI | Not in M1 — M1 inventory is the 8x3 grid with no separate stash room | M2 (`stash-ui-v1.md` + save schema v4) |
| Run-summary screen | None — death goes straight to respawn | M2 |

If Sponsor sees one of these "stubbed" things and considers reporting it, **don't burn a bug slot**. The systems are wired; the fidelity is M2+.

---

## 4. Time budget

**Total soak window: 30–45 min uninterrupted.** Stopwatch from canvas-boot.

| Phase | Duration | What happens |
|---|---|---|
| Pre-soak setup (§1) | ~3 min | NOT counted against the stopwatch — finish before start |
| Boot + first-room orientation | 0–2 min | Read banner, look at HUD, glance at console |
| AC2 first-kill (§5.2) | 2–4 min | Walk to grunt, attack until dead, observe XP gain |
| Room clear chain (rooms 1→8) | ~10–15 min | The bulk of the soak — combat + drops + level-ups + room transitions |
| Inventory / stat-allocation probes (§5.7, §5.5) | ~3–5 min | Tab-open, equip swap, allocate stat points |
| Boss room (§5.4) | ~5–8 min | Engage boss, observe 3-phase rhythm, kill or wipe |
| Descend → AC6 quit-relaunch (§5.6) | ~3–5 min | Walk to exit, descend, then F5-reload to verify save |
| Death-rule verification (§5.3) | ~2–4 min | Deliberately die mid-stratum, observe reset |
| Buffer + DevTools console final scan | ~3 min | Scroll up the console, snapshot any red/yellow line |

**Express soak (15 min — Sponsor time-tight):** §6 lists the 3 most-diagnostic ACs to run if the full window isn't available.

---

## 5. Per-AC probe targets

For each of the 7 M1 ACs, the canonical reproduction shape, expected-vs-observed-as-stub, edge cases, and "feel" questions vs. "logical" checks. Sponsor follows the bullet list per AC.

### 5.1 — AC1: Build reachable from a single URL / single zipped exe

**Reproduction shape:** Already exercised by §1 pre-soak. Boot from `localhost:8000`.

**Logical checks:** [ ] Canvas boots ≤5 s cold. [ ] No 404s in DevTools Network. [ ] HUD footer reads `build: <7-char SHA>`, NOT `dev-local` (BB-1 trap).

**"Feel" question:** Did the boot feel snappy or sluggish? (Sluggish = .wasm download bandwidth issue on Sponsor's connection.)

**Edge cases:** Cold vs warm F5 (≤2 s warm); different browser (AC1-T02 cross-check).

### 5.2 — AC2: Cold launch → first mob killed in ≤60 s

**Reproduction shape:** Stopwatch from canvas-boot. Read banner. WASD to nearest grunt (Room01 authors 2 grunts at tiles `(8,5)` and `(11,3)` per `s1_room01.tres`). LMB until HP zero. Stop on death animation.

**Logical checks:**
- [ ] Total ≤60 s (target ≤40 s warm).
- [ ] HP visibly decreases per LMB connect (combat-actually-lands — Devon's `86c9m36zh` fix landed).
- [ ] XP awarded on kill. Loot may drop (Pickup); walk over → auto-collect into Inventory.

**"Feel" question:** Did the attack feel like it landed? Per `combat-visual-feedback.md` v1 expect: ember swing-wedge during attack window, 80 ms white hit-flash on connect, 200 ms scale+fade death tween + 6-particle ember burst. Any cue absent = combat-visual-feedback v1 not yet implemented; flag as bug.

**Edge cases:**
- Heavy attack (RMB) — wider hitbox + 60 ms ember-flash.
- Move-cancel: walk into grunt while attacking — recovery window read?
- **BB-5 — boot banner read:** does it list LMB/RMB/Tab/E? Missing LMB/RMB = BB-5 still open.

### 5.3 — AC3: Death does not lose level or stashed gear

**Reproduction shape:** Deliberately let a grunt kill the player. After respawn, check level, V/F/E, equipped slot, inventory, room counter.

**Logical checks:**
- [ ] Level survives. Spent V/F/E survives. Equipped items survive.
- [ ] Mid-level XP resets to 0. Unequipped stash items wipe. Cleared-room counter resets to Room 1/8. Respawn at Room01 spawn `Vector2(240, 200)`, full HP. *(All correct M1 death-rule per DECISIONS 2026-05-02.)*

**"Feel" question:** Did the death feel fair (grunt deaths = "you whiffed" moments)? If arbitrary, surface for combat tuning.

**Edge cases:**
- Die mid-attack vs mid-dodge — dodge i-frames must apply.
- Die 3× in a row — invariant holds across all 3.
- Die mid-allocation: open StatAllocationPanel with banked points → die before allocating → respawn → points still banked?

### 5.4 — AC4: Stratum-1 boss clear in ≤10 min once gear-appropriate

**Reproduction shape:** From respawn, fight through Rooms 2–7 (BB-3: no perimeter walls, don't walk past edges). Reach Room 8 (boss room). Step on door trigger → 1.8 s entry sequence → boss `wake()`. Engage. 3 phases, boundaries at 67% / 33% HP per `Stratum1Boss.gd`.

**Logical checks:**
- [ ] Entry sequence plays — dormant → wakes (visible state change). Skipping = bug.
- [ ] Phase 2 transition at 67% HP — 0.6 s stagger-immune window. Phase 3 at 33% — enrage (1.5× speed, 0.7× recovery).
- [ ] Boss death → guaranteed T3 sword + T2 vest drop (`boss_drops.tres`). `stratum_exit_unlocked` fires → portal interactable.
- [ ] Clear ≤10 min (target ≤6 min, gear-appropriate = level 4+, T2 weapon).

**"Feel" question:** Does the 3-phase rhythm read as escalation, or as the same fight 3×? Does the entry sequence feel like a moment or dead air?

**Edge cases:**
- **SP-1 carry-forward — tab-blur during boss intro.** Alt-Tab as door triggers. Wait 5+ s. Tab back. Boss `wake()` fires cleanly? Entry sequence double-triggers? Camera stuck?
- Dodge-only stall: 60 s pure dodging. Player survives ≥30 s? (Validates i-frames.)
- Cheese check: walk-out attempts past `RoomGate` (BB-3 — no wall might let you cheese; flag if it works).

### 5.5 — AC5: No hard crashes in 30-min play session

**Reproduction shape:** This is the **soak-meta AC** — verified by the 30-min duration itself. Absence of a crash during §4's time budget is the proof.

**Logical checks (concrete):**
- [ ] Browser tab stays alive across full 30 min. No "Aw, snap" / "Page unresponsive" dialogs.
- [ ] End-of-soak: scroll DevTools console — any `push_error` (red) or `Uncaught (in promise)`?
- [ ] Memory: heap doesn't grow unboundedly (heuristic: >2× post-boot baseline after stable-state is suspicious).

**"Feel" question:** Did the framerate ever drop perceptibly? When? What was on-screen?

**Edge cases (carry-forward SP-2, SP-3):**
- **Alt-tab stress:** Alt-Tab every 90 s. Pause gracefully? Focus regain hangs?
- **Resize stress:** resize window 5–10× during soak. Canvas adapts.
- **SP-3 mid-allocation tab-blur:** StatAllocationPanel open + 1 banked point → allocate 1 → Alt-Tab 30 s → Tab back → allocate 2. Both persist; F5 → both still there.

### 5.6 — AC6: Save survives quit-and-relaunch

**Reproduction shape:** Mid-run with stash items + cleared rooms + spent stat points. Note current level, V/F/E, cleared-room count, equipped items, stash items. F5 the browser tab. Wait for canvas to re-boot. Autoload restore fires on `Save.load_game(0)`. Resume.

**Logical checks (concrete):**
- [ ] Level survives. V/F/E spent points survive. Equipped items survive.
- [ ] **Unequipped stash items survive** (vs. AC3 death — F5 is NOT a death, so stash MUST persist). **BB-2 trap:** if stash empties on F5, BB-2 is not yet fixed.
- [ ] Cleared-room counter survives. Player respawn at Room01 entry OR mid-room — both acceptable for M1.

**"Feel" question:** Did the reload feel seamless or jarring? Black-screen-then-canvas is fine; a 30 s hang is not.

**Edge cases (carry-forward from SP-4):**
- **SP-4 — close tab entirely (not F5) → reopen URL.** Save should still restore.
- **Save during boss entry-sequence:** close tab mid-1.8s entry. Reload. Where does respawn land — Room08 entry or before?
- **DevTools cache wipe:** clear browser data for `localhost:8000` → reload. New Game offered (no Continue) — expected; confirms save lives in OPFS.

### 5.7 — AC7: Two distinct gear drops with visibly different affixes

**Reproduction shape:** Across full stratum-1 clear, observe loot. M1 affix pool: 3 affixes (`swift`/move_speed, `vital`/vigor, `keen`/edge). Tier modifiers: T1=0 / T2=1 / T3=1–2 affixes. Boss guarantees T3 sword + T2 vest; mob drops are tier-varied (~70/25/5 T1/T2/T3).

**Logical checks:**
- [ ] ≥2 inventory items with **different affix lines** (not just different rolls). E.g., one `+8 vigor`, another `+3 edge`.
- [ ] Tab-open Inventory → tooltip shows base stats + affix lines. Legible at M1 UI scale.
- [ ] T1 vs T3 visibly distinguishable (tier label/color).
- [ ] **BB-2 retest:** equip a drop (Tab → click). Stats reflect. F5 → equipped item survives.

**"Feel" question:** Did finding a T2 or T3 drop feel like a moment? (Target: ~9–10 drops / ~2–3 T2 / ~0–1 T3 per stratum clear per `affix-balance-pin.md` §4.)

**Edge cases:**
- T1 (0 affixes) vs T3 (1–2) side by side — visual distinction reads.
- Equip → unequip → re-equip — idempotent (no double-application).
- Equip into occupied slot — previous auto-unequips into stash.

---

## 6. Express soak — 15 min (Sponsor time-tight)

If Sponsor's window is too short for the full 30–45 min, run **just these 3 ACs** — they're the highest-diagnostic-value because each one reveals failure modes in distinct system clusters:

### Top 3 most-diagnostic ACs

1. **AC2 first-kill (combat + XP + loot)** — exercises Player + Grunt + Damage + LootRoller + Pickup + Inventory in one cycle. If AC2 is clean, ~60% of M1 wiring is verified. If AC2 is broken, every other AC is suspect.
2. **AC3 death-rule** — exercises the M1-spec death contract (level survives, mid-XP wipes, stash wipes, equipped survives). The most-diagnostic single AC for "is the autoload save/restore chain wired correctly?" Failure here = the save schema or `Main.apply_death_rule` is broken.
3. **AC6 quit-relaunch (F5 cycle)** — exercises Save.gd OPFS round-trip + autoload restore + stash preservation across session resume. Pairs with AC3 — together they catch BB-2 (saved Inventory items dropped) and BB-1 (build SHA mismatch). The two together are the single highest-value 5-min probe.

The express soak runs §5.2 → §5.3 → §5.6 in sequence (~12 min) plus 3 min of DevTools console scanning. Boss + AC4/AC7 deferred to next soak window.

---

## 7. Sponsor output template

Sponsor's findings need to be structured enough that Tess can triage them quickly into bug rows (using `team/tess-qa/bug-template.md`). Suggested verbal/text format Sponsor produces at end-of-soak:

```
SOAK STATUS: [clean | bugs | mixed]

BUILD: <SHA from HUD footer> (cross-check: matches dispatch ping?)
DURATION: <minutes elapsed, full vs express>
BROWSER: <Chrome / Firefox / Edge>

BUGS:
1. WHERE: <Room01 / boss room / inventory open / etc>
   STATE: <combat / death / save / inventory / boss-intro / etc>
   EXPECTED: <what should have happened, per this checklist or M1 spec>
   ACTUAL: <what did happen — be concrete, not "felt off">
   SEVERITY GUESS: <blocker | major | minor>
   CONSOLE: <any red/yellow line at this moment? paste it>

2. ...

FEEL NOTES (vague-ok):
- <e.g., "boss phase-3 felt rushed compared to phase-1 / phase-2">
- <e.g., "first-room spawn was very close to a grunt — felt too fast">

WHAT FELT GOOD (the asked-for-it side):
- <Sponsor's positive observations — these orient priorities for M2>
```

**Severity guides** (Sponsor doesn't need to be Tess-precise; ballpark is fine):
- **blocker:** "I literally couldn't continue" — game crashed, save corrupted, can't progress past a room.
- **major:** "It worked, but it was clearly broken" — wrong number on screen, missing affordance (BB-4 stat-panel-can't-reopen shape), AC fails-via-workaround.
- **minor:** "Looks rough, but the system works" — programmer-art noise that isn't on the §3 fidelity-expectation list.

`SOAK STATUS: clean` only if zero bugs at any severity. Anything non-empty in BUGS = `bugs` or `mixed` (mixed = some ACs clean, some surfaced bugs).

---

## 8. Carry-forward probe targets from prior audits

These are the high-signal probes Tess called out in `html5-rc-audit-591bcc8.md` SP-1..SP-7 + `m1-bugbash-4484196.md` BB-rows. Sponsor folds them into the per-AC probes above, but they're listed here as a single checklist so they don't get lost between sections.

### Top 3 carry-forwards (highest signal)

1. **DevTools console silence across the full soak** (`html5-rc-audit-591bcc8.md` SP-5). Zero `push_error`. The two legitimate `push_warning` paths (atomic_write, ItemInstance.from_save_dict unknown id) must NOT fire. Why this is highest-signal: R3 retro flagged it. A red line is a free bug — no probe needed beyond "look at the console."
2. **Tab-blur during boss-entry sequence** (SP-1). Alt-Tab away as the boss-room door triggers (1.8 s entry sequence). Tab back after 5 s. Boss must `wake()` cleanly. Why: scene-tree pause behavior on HTML5 differs from native — Godot 4.3 web tab-blur lets SceneTree.process tick at 0 fps; Timer-driven entry sequence is the most fragile surface.
3. **Save → close tab → reload state survival** (SP-4). Close the tab entirely (not F5). Reopen the URL. Continue path → state restored. Why: this is the AC6 canonical reproduction; OPFS / IndexedDB persistence across browser-tab-lifecycle is the single most-likely-to-fail HTML5 surface.

### Full carry-forward list (for completeness)

| ID | Source | One-liner |
|---|---|---|
| SP-1 | html5-rc-audit | Tab-blur during boss-entry 1.8s sequence |
| SP-2 | html5-rc-audit | Inventory open + tab-blur + tab-return + verify time-scale=1.0 on close |
| SP-3 | html5-rc-audit | Mid-allocation tab-blur on StatAllocationPanel + persistence check |
| SP-4 | html5-rc-audit | Quit-relaunch via close-tab (not just F5) |
| SP-5 | html5-rc-audit | DevTools console silence — zero push_error |
| SP-6 | html5-rc-audit | Fast-XP chord (Ctrl+Shift+X) browser-claim test (dev build only) |
| SP-7 | html5-rc-audit | AZERTY/Dvorak smoke (deferred — no non-QWERTY testers in M1 loop) |
| BB-1 | m1-bugbash | Footer reads `dev-local` instead of SHA — pre-soak smoke (§1.3) |
| BB-2 | m1-bugbash | Saved Inventory items dropped on reload — AC6 / AC7 probe |
| BB-3 | m1-bugbash | Walking off room edges (no perimeter walls in M1) — AC2/AC4 edge probe |
| BB-4 | m1-bugbash | StatAllocationPanel can't be reopened mid-bank (no P-key) — AC5 probe |
| BB-5 | m1-bugbash | Boot banner missing LMB/RMB attack bindings — AC2 boot read |
| BB-6 | m1-bugbash | Stacked panel close-order leaks time_scale=0.10 — minor |
| BB-7 | m1-bugbash | Player spawn ~32 px from grunt in Room01 — minor |
| BB-8 | m1-bugbash | Build is silent (no audio) — expected M1 state, not a bug |

Note: items already filed as ClickUp tickets (`86c9m390b` / `86c9m3911` / `86c9m393a` / `86c9m395d` / `86c9m3969`) are status-tracked separately. Sponsor doesn't need to re-file; just confirm whether each is fixed or still open in this RC.

---

## 9. Open questions (parking lot)

1. **Express soak ordering.** §6 picks AC2 → AC3 → AC6 (most surface area). If Sponsor prefers boss-first, swap.
2. **Recording vs. text.** §1.4 optional. If verbal text is faster, skip the recording.
3. **Browser choice.** Chrome is team default; if Sponsor's primary is Firefox/Edge, soak there.
4. **Soak frequency.** Not every fix-RC warrants a full re-soak (e.g., one-line copy fix). Orchestrator + Tess decide.

---

## Caveat — this checklist is evergreen

§1 pre-soak setup, §3 fidelity guardrails, §7 output template, §8 carry-forward discipline are reusable across M2/M3 RC soaks. §5 per-AC probes ARE M1-specific; the §5 shape (canonical repro + logical checks + feel question + edge cases) ports directly to M2 ACs once `m2-acceptance-plan-week-1.md` graduates to M2 RC sign-off plan.

Revisable triggers: Sponsor's first soak against this checklist surfaces §1/§7 friction (revise in-place); a new bug class isn't covered by §5/§8 (append new probe row); M2 RC soak begins (swap §5 for M2 ACs).
