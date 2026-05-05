# Sponsor-Soak Prep Checklist v2 — Post-fix-wave Re-soak (M1)

**Owner:** Uma · **Phase:** M1 RC sign-off — post-BB-fix-wave re-soak (anticipatory; revisable post-Sponsor sign-off) · **Drives:** Sponsor's interactive 30–45 min M1 re-soak after the BB-1/BB-3/BB-5/(BB-4) fix wave lands, Tess's bug-triage from re-soak findings, orchestrator's per-soak surface URL hand-off, Priya's R6 mitigation discipline.

This is **v2** of `team/uma-ux/sponsor-soak-checklist.md` (run-010, merged at `d0e7258`). v2 inherits v1's structure (TL;DR → §1 pre-soak → §2 known-state → §3 fidelity guardrails → §4 time budget → §5 per-AC probes → §6 express soak → §7 output template → §8 carry-forward → §9 open questions). The deltas are localized to (a) NEW §0 "Post-fix-wave deltas" calling out user-perceptible changes Sponsor should look for vs. the run-024 RC, (b) refreshed §8 carry-forward list with the BB-1/BB-3/BB-5 rows resolved-or-pending and a new BB-3-followup probe (LevelAssembler regression — boss arena was previously empty), (c) two new product-vs-component probe shapes folded into the per-AC checks per the new section in `team/TESTING_BAR.md` (PR #127), and (d) refreshed appendix capturing micro-copy questions Uma raised in PR #128.

> **Wave-merge caveat — read before running this checklist.** Every §0 delta below is **subject to merge of #128 (BB-5) / #129 (BB-3) / (next BB-4 PR)**. PR #125 (BB-1 SHA stamp) is already merged. As of v2 draft time, #128 + #129 are open and awaiting Tess sign-off. **Do NOT run this checklist against an RC built from a SHA that pre-dates the wave merge** — fall back to v1, the deltas will read as false positives. Confirm the RC build SHA against `gh pr view` merge commits before starting the soak.

---

## TL;DR (5 lines, v2)

1. **Time budget unchanged from v1:** 30–45 min full re-soak; 15 min express. Express ordering still AC2 → AC3 → AC6 (most-diagnostic surface area).
2. **Output Sponsor produces unchanged from v1:** §7 per-bug bullet template + verbal "clean / bugs / mixed" verdict.
3. **NEW post-fix-wave deltas (§0):** footer reads `<7-char SHA>` (not `dev-local`); rooms have walls + player can't walk into void; boot banner is a 7-line full-control reminder including `LMB to attack` + `RMB to heavy attack`. **The re-soak's first 5 min should explicitly screen for these three positives** — confirm the wave actually did what it claims. If any of the three regress, the wave didn't land cleanly and the re-soak is on the wrong build.
4. **Carry-forward shrinks (§8):** BB-1 / BB-3 / BB-5 rows expected resolved this wave; BB-2 + BB-4 + BB-6/BB-7 carry forward as before; one NEW probe added — Drew's LevelAssembler regression (chunk_def.scene_path was never being loaded so authored boss-room geometry was orphan; #129 fixes both walls AND the assembler bug → verify boss arena now has floor + walls Drew claims).
5. **New product-vs-component discipline (§5/§7):** if Sponsor finds a "feature works in test but not in product" gap (e.g. paired GUT test green + soak surface broken), capture as a P0 bug per `team/TESTING_BAR.md` § "Product completeness ≠ component completeness". This was the M1 Main.tscn-stub miss class — don't re-learn it.

---

## 0. Post-fix-wave deltas (NEW — what Sponsor should now see vs. didn't before)

**This is the new section in v2.** Sponsor reads §0 BEFORE starting the stopwatch and uses it as a positive-signal screen — confirming each delta in the first 5 min validates the wave actually landed. If a delta is missing, stop the soak and ping orchestrator to confirm RC build SHA.

### 0.1 — Footer SHA stamp (was: `build: dev-local`)

- **Source PR:** #125 — `fix(build): ship build_info.txt inside HTML5 export bundle (BB-1)` — **merged** (commit on main).
- **What changed:** `export_presets.cfg` gained `include_filter="build_info.txt"` on every preset (HTML5 / Windows / Linux / macOS). `build_info.txt` now ships inside `index.pck` so `BuildInfo._resolve_sha()` resolves to the CI-stamped short SHA at runtime instead of falling through to `FALLBACK_SHA = "dev-local"`. `release-github.yml` gained a regression-gate step that fails the workflow if either the SHA bytes or the `build_info.txt` filename are missing from the post-export `.pck`.
- **What Sponsor should see:** HUD bottom-left footer reads `build: <7-char SHA>` (e.g. `build: 4484196`). The SHA should match the merge commit of the wave's tip on main — orchestrator surfaces the expected SHA in the dispatch ping.
- **What Sponsor should NOT see:** `build: dev-local`. If the footer reads `dev-local` in this RC, **the re-soak is on the wrong build artifact** (downloaded the run-024 zip by mistake, or the export workflow regressed). Stop the soak and re-ping orchestrator.
- **Probe time:** ~3 sec, first frame after canvas boot.

### 0.2 — Room boundary walls + boss arena geometry (was: walk-into-void)

- **Source PR:** #129 — `fix(levels): room boundary collision walls (BB-3)` — **OPEN, awaiting Tess sign-off / orchestrator merge**.
- **What changed (per PR body, verified-against-source by direct read this run):** Two compounding fixes. (a) `s1_room01_chunk.tscn` previously only carried N/S walls; the chunk gains east + west walls (32×256 verticals) so rooms 01..08 get full 4-edge coverage. (b) `Stratum1BossRoom.tscn` previously had **zero** walls; it gains all four perimeter walls (480×270 arena, south wall positioned to leave the door trigger reachable from y=242..258 and the stratum-exit portal at y=30 reachable). (c) `LevelAssembler.assemble_single` previously never loaded `chunk_def.scene_path` — authored chunk geometry never reached the running scene tree. **This is a separate bug, more severe than BB-3 itself**: the M1 RC may have been shipping the boss room as an EMPTY arena even where walls were authored. The fix loads + parents the chunk scene under the assembly root.
- **What Sponsor should see:**
  - Walking down/right past Room01's edge → player stops at the wall, doesn't drift into untextured void.
  - Walking into the boss room — the arena now has visible floor + 4 perimeter walls (Drew's fix to the assembler should make authored geometry reach the runtime tree). v1's note said "BB-3 — no perimeter walls" but the regression is wider: probe whether the boss arena had ANY authored content visible before the fix. (If it did and v1 understated, log that as a documentation correction; if it didn't, the assembler regression was masking the BB-3 symptom — both fixes were needed.)
- **What Sponsor should NOT see:** Player drift past room edges. Untextured floor in boss arena. `RoomGate` triggers firing without player visibly being inside the bounded room.
- **Probe time:** ~30 sec across Room01 cardinal-edge walks + ~15 sec boss-arena visual confirmation (entry sequence's 1.8s gives a free visual moment).
- **Caveat — subject to merge.** If #129 has not merged at re-soak time, fall back to v1 §5.4 BB-3 edge probe (walking off Room01 edge is still expected behavior on a pre-merge build).

### 0.3 — Full 7-line boot banner including LMB/RMB (was: WASD/Shift/Space only, ~28% of bindings missing)

- **Source PR:** #128 — `fix(ui): add LMB/RMB to boot banner — full control reminder (BB-5)` — **OPEN, awaiting Tess sign-off / orchestrator merge**.
- **What changed (per PR body):** New `BootBanner` Label widget at bottom-center of HUD. 7 verb-lines covering every input action in `project.godot` §[input]:
  ```
  WASD to move
  Shift to sprint
  Space to dodge
  LMB to attack
  RMB to heavy attack
  Tab for inventory
  P to allocate stats
  ```
  Visual style matches existing HUD widgets — parchment-bone Color(0.91, 0.89, 0.84, 0.6), font-size 12, mouse-filter IGNORE so LMB/RMB clicks reach the play area.
- **What Sponsor should see:** A bottom-centered 7-line text widget appears at canvas-boot, including the LMB and RMB attack bindings. Banner stays visible at least through the title-screen → first-room transition.
- **What Sponsor should NOT see:** A 5-line banner missing LMB/RMB (= BB-5 regressed). A banner that blocks LMB/RMB clicks reaching the play area (= mouse_filter regression). A banner that overlaps existing HUD widgets (HP bar / XP bar / level label / room counter / build SHA footer / [+N STAT] pip).
- **Probe time:** ~5 sec — read banner during the boot transition.
- **Caveat — subject to merge.** If #128 has not merged at re-soak time, banner will be in its pre-fix state — fall back to v1's §5.2 BB-5 probe ("does it list LMB/RMB?"). The "feel" question for v1 was a major-severity miss; for v2 it's a positive screen.

### 0.4 — Pending: BB-4 (StatAllocationPanel can't be reopened, no P-key handler)

- **Source PR:** TBD — next in fix wave. ClickUp `86c9m395d` (BB-4 from m1-bugbash).
- **What's expected to change:** A `KEY_P` (or new `toggle_stats` action) handler in `StatAllocationPanel._unhandled_input` that opens the panel when `_open == false` AND `PlayerStats.get_unspent_points() > 0`. Closes the loop with v2 §0.3's `P to allocate stats` banner line (which is forward-compat copy added in #128 ahead of the BB-4 fix).
- **What Sponsor should see (post-merge of next BB-4 PR):** Pressing P on a banked-points state reopens the StatAllocationPanel; allocate the point; close; press P again with `unspent_points == 0` is a no-op.
- **What Sponsor should NOT see:** Banked points stuck unspendable until next level-up (= BB-4 regressed). Banner copy `P to allocate stats` falsely promising a binding that doesn't work (= BB-4 fix didn't land but #128 did → user-facing inconsistency, file as a P0).
- **Caveat — subject to merge.** If the BB-4 PR has not merged at re-soak time, the banner copy `P to allocate stats` is forward-compat advertising a binding the runtime doesn't honor. **This is a soak-blocker** if #128 merges without BB-4 — Sponsor will read the banner, press P, get nothing, and reasonably file as a UI bug. Orchestrator should bundle #128 + BB-4 PR merge or hold #128 until BB-4 lands.
- **Probe time (when BB-4 lands):** ~30 sec — gain XP, level up, close panel with Esc, press P, allocate.

---

## 1. Pre-soak setup (before the stopwatch starts)

**Inherits v1 §1 unchanged in shape; v2 deltas inline:**

### 1.1 — Build artifact download

- [ ] Orchestrator surfaces soak URL: `https://github.com/TSandvaer/RandomGame/actions/runs/<run-id>` + artifact `embergrave-html5-<short-sha>`.
- [ ] **NEW v2 — confirm the SHA matches the wave merge commit.** Pre-wave SHA `4484196` is the run-024 build (the build-bash baseline); a clean post-wave RC will have a SHA AFTER the merges of #125 + #128 + #129 + (BB-4 PR). Orchestrator pings the expected SHA; Sponsor cross-checks the artifact name.
- [ ] Click into the run page → Artifacts → download zip (~8.4 MB). Unzip to a clean directory.
- [ ] Verify zip contains 8 files: `index.html` / `.js` / `.wasm` / `.pck` / `.audio.worklet.js` + 3 PNG icons. All non-zero. If short/empty, stop soak — surface to orchestrator.

### 1.2 — Local serve

Unchanged from v1: `python -m http.server 8000` from unzip dir, Chrome at `http://localhost:8000/`. Canvas boots ≤5 s.

### 1.3 — DevTools console open (F12) — highest-leverage pre-soak action

Open BEFORE canvas boots so boot-time prints are captured.

- [ ] **Boot smoke lines** should appear:
  - `[Save] autoload ready (schema v3)` (or v4 if M2 schema landed; M1 is v3).
  - `[BuildInfo] build: <7-char SHA>` — **MUST NOT read `dev-local`** (BB-1 trap; v2 §0.1 expects this resolved).
  - `[DebugFlags] debug_build=...`
- [ ] **Watch for `push_error` (red lines)** the entire soak. Zero tolerance — every red line is a candidate bug. Note the room/state.
- [ ] **Watch for `push_warning` (yellow)** — these MUST NOT fire (any firing = bug):
  - `[Save] save_game(0) failed at atomic_write` (OPFS write rejected).
  - `ItemInstance.from_save_dict: unknown item id '<id>'` (BB-2 regressed).
- [ ] **NEW v2 — watch for the LevelAssembler trace.** Per #129 PR body, the assembler now loads `chunk_def.scene_path`. If a `[LevelAssembler] failed to load scene_path` warning fires, the regression-fix didn't take. Note the room and surface to Tess.
- [ ] **Network 404s** — zero after boot.

### 1.4 — Recording (optional)

Unchanged from v1.

### 1.5 — Stopwatch ready

Unchanged from v1 — start from canvas-boot.

---

## 2. Known-state primer (so Sponsor recognizes "this is fine")

**Inherits v1 §2 unchanged.** Death rule, quit-relaunch difference, boss-in-build, audio-silent-by-design.

**v2 ADDITION:** Sponsor expects to see the §0 deltas as positives in the first 5 min. If any §0 item regresses, the wave landed incompletely — surface to orchestrator before continuing.

---

## 3. What NOT to expect (fidelity-expectation guardrails)

**Inherits v1 §3 unchanged** — programmer-art tile sprites, no audio (BB-8), no animations beyond Tween modulate flashes, programmer-art HUD, no controller, no stash room (M2), no run-summary screen (M2). Don't burn a bug slot on §3 items.

---

## 4. Time budget

**Inherits v1 §4 unchanged.** 30–45 min full / 15 min express. Stopwatch from canvas-boot.

**v2 NOTE:** §0 positive-screen costs ~5 min within the boot/first-room phase but is high-leverage — it confirms the wave actually landed before Sponsor sinks 25+ min into combat / boss / save probes that may be building on a bad foundation.

---

## 5. Per-AC probe targets (v2 deltas inline)

**Inherits v1 §5.1..§5.7 structure.** Deltas:

### 5.1 — AC1: Build reachable from a single URL / single zipped exe

**Logical checks (v2 update):**
- [ ] Canvas boots ≤5 s cold.
- [ ] No 404s in DevTools Network.
- [ ] **HUD footer reads `build: <7-char SHA>` matching the dispatch-pinged wave merge SHA** — was BB-1 trap in v1 ("MUST NOT be `dev-local`"); v2 promotes it to a positive identity check. If the footer matches the wave SHA, BB-1 is fixed. If it reads `dev-local`, the wave didn't land OR the artifact is wrong build OR `include_filter` regressed in `export_presets.cfg`.
- [ ] **Product-vs-component check (NEW per `TESTING_BAR.md` PR #127):** the SHA visible in the player-facing surface (HUD footer) is the truth — not the SHA on the workflow run. If a CI run's metadata says one SHA but the in-game footer says another, the export-pipeline regressed even if CI was green. Capture as P0.

### 5.2 — AC2: Cold launch → first mob killed in ≤60 s

**Edge cases (v2 update):**
- Heavy attack (RMB) — wider hitbox + 60 ms ember-flash.
- Move-cancel: walk into grunt while attacking — recovery window read?
- ~~**BB-5 — boot banner read:** does it list LMB/RMB/Tab/E? Missing LMB/RMB = BB-5 still open.~~ → **REPLACED in v2:** "Boot banner is the full 7-line widget per §0.3. Confirm `LMB to attack` + `RMB to heavy attack` are visible. If not, BB-5 regressed (or #128 did not merge — confirm SHA)."
- **NEW v2 — does Sponsor try the binding listed on the banner?** If the banner says `LMB to attack` and LMB does not produce an attack, that's a regression of Devon's combat fix (`86c9m36zh` / PR #109) — escalate before continuing.
- **NEW v2 — product-vs-component:** banner copy must match what the runtime input map honors. If banner advertises `P to allocate stats` but BB-4 hasn't landed yet (no P-key handler), capture as a P0 mismatch (per §0.4 caveat).

### 5.3 — AC3: Death does not lose level or stashed gear

**Inherits v1 §5.3 unchanged.** Death rule (level + V/F/E + equipped survives; mid-XP + stash + room counter resets).

**v2 ADDITION — edge case:** Walk past room edge BEFORE engaging the grunt. Should now hit a wall (per §0.2). If the player escapes the bounded play area pre-death, room-cleared logic and `Player.player_died` may behave unexpectedly (integration probe — flag any oddity).

### 5.4 — AC4: Stratum-1 boss clear in ≤10 min once gear-appropriate

**Edge cases (v2 update):**
- **SP-1 carry-forward — tab-blur during boss intro** (unchanged from v1).
- **Dodge-only stall** — unchanged from v1.
- ~~**Cheese check: walk-out attempts past `RoomGate` (BB-3 — no wall might let you cheese; flag if it works).**~~ → **REPLACED in v2:** "Cheese check: with #129 merged, walk-out attempts past room boundaries should now be physically blocked. If the player can still walk past a perimeter wall, BB-3 regressed for that specific room — note which room."
- **NEW v2 — boss arena visual confirmation.** Per #129, the assembler regression may have been shipping the boss room as an empty arena. Sponsor confirms the arena has visible floor geometry + 4 perimeter walls + boss + door trigger. If the arena is empty, the assembler regression-fix didn't take.
- **NEW v2 — boss room door trigger reachability.** PR #129 explicitly preserves the door trigger crossable from `Vector2(240, 200)` spawn (south wall starts at y≥258 to leave y=242..258 reachable). Confirm boss room loads on door cross. If wall placement breaks the trigger, the fix-for-walls regressed the room-entry contract.
- **NEW v2 — product-vs-component:** if `tests/test_room_boundary_walls.gd` (paired test from PR #129) is green in CI but a perimeter wall is visibly absent in-soak, the test is asserting on a different surface than the player drives — capture as P0 product-vs-component miss.

### 5.5 — AC5: No hard crashes in 30-min play session

**Inherits v1 §5.5 unchanged.** Soak-meta AC. Alt-tab stress + resize stress + SP-3 mid-allocation tab-blur.

**v2 ADDITION:** scroll DevTools console for `[LevelAssembler]` warnings (§1.3). If the assembler is failing to load chunk_def.scene_path silently, it'll show up here.

### 5.6 — AC6: Save survives quit-and-relaunch

**Inherits v1 §5.6 unchanged.** F5 + close-tab + DevTools cache wipe edge cases.

**v2 ADDITION — product-vs-component edge case:** PR #118 (BB-2 fix) introduced `ContentRegistry` autoload that scans `res://resources/items/*.tres` + affixes. If a saved inventory item references an item_id whose `.tres` was removed since the save (M2-onset content cleanup risk), the resolver returns null and the item silently drops. Sponsor probes by saving an inventory state and reloading — the AC6 contract holds. If the contract breaks, the bug is no longer "no-op resolvers" (BB-2's original cause) but a content-registry-vs-save-id divergence — file as a separate ticket.

### 5.7 — AC7: Two distinct gear drops with visibly different affixes

**Inherits v1 §5.7 unchanged.** Affix line distinction + tooltip legibility + tier visual + BB-2 retest.

---

## 6. Express soak — 15 min (Sponsor time-tight)

**Inherits v1 §6 unchanged in selection (AC2 → AC3 → AC6).** v2 ADDITION: the §0 positive-screen (~5 min) precedes the express path. So an "express+screen" run is ~17 min, an "express only" (skip §0) is 12 min — choose based on Sponsor's confidence in the wave SHA.

If Sponsor opts for express-only: trust the orchestrator's wave-SHA ping, skip §0, run AC2 → AC3 → AC6 + 3 min DevTools console scan. 12 min total.

---

## 7. Sponsor output template

**Inherits v1 §7 unchanged.** Per-bug template + feel-notes + what-felt-good.

**v2 ADDITION — new bug-row category for product-vs-component:**

```
PRODUCT-VS-COMPONENT MISS (a new severity tag):
- WHERE: <feature surface>
- TEST CLAIM: <which paired test or CI step claims green>
- SOAK OBSERVATION: <what's actually broken in the runtime / artifact>
- HYPOTHESIS: <why test green + soak red — usually "test exercises a different surface than the player's path">
- SEVERITY: P0 (per `TESTING_BAR.md` § "Product completeness ≠ component completeness" — these are gating)
```

Per `team/TESTING_BAR.md` PR #127, the product-vs-component class is M1's most-painful bug class (the Main.tscn-stub miss being the canonical example). v2 makes this a first-class soak-output category so Tess can triage and so future RCs proactively close the integration gap.

---

## 8. Carry-forward probe targets (v2 refresh)

### Top 3 carry-forwards (highest signal — v2 update)

1. **DevTools console silence across the full soak** (`html5-rc-audit-591bcc8.md` SP-5). Unchanged from v1 — zero `push_error`. The two legitimate `push_warning` paths (atomic_write, ItemInstance.from_save_dict unknown id) must NOT fire. **NEW v2:** also watch for `[LevelAssembler] failed to load scene_path` (per §1.3).
2. **Tab-blur during boss-entry sequence** (SP-1). Unchanged from v1.
3. **Save → close tab → reload state survival** (SP-4). Unchanged from v1.

### Full carry-forward list (v2 — refreshed)

| ID | Source | Status (this wave) | One-liner |
|---|---|---|---|
| SP-1 | html5-rc-audit | open / probe-as-before | Tab-blur during boss-entry 1.8s sequence |
| SP-2 | html5-rc-audit | open / probe-as-before | Inventory open + tab-blur + tab-return + verify time-scale=1.0 on close |
| SP-3 | html5-rc-audit | open / probe-as-before | Mid-allocation tab-blur on StatAllocationPanel + persistence check |
| SP-4 | html5-rc-audit | open / probe-as-before | Quit-relaunch via close-tab (not just F5) |
| SP-5 | html5-rc-audit | open / probe-as-before (+ assembler trace) | DevTools console silence — zero push_error |
| SP-6 | html5-rc-audit | open / probe-as-before | Fast-XP chord (Ctrl+Shift+X) browser-claim test (dev build only) |
| SP-7 | html5-rc-audit | deferred to M2 | AZERTY/Dvorak smoke (deferred — no non-QWERTY testers in M1 loop) |
| BB-1 | m1-bugbash | **RESOLVED** (#125 merged) | Footer reads `dev-local` → expect SHA stamp; positive-screen now §0.1 |
| BB-2 | m1-bugbash | RESOLVED in PR #118 (run 015) | Saved Inventory items dropped — re-verify per AC6/AC7 |
| BB-3 | m1-bugbash | **RESOLVED pending #129 merge** | Walking off room edges → expect walls; positive-screen now §0.2 |
| BB-3-followup | NEW (this wave) | RESOLVED pending #129 merge | LevelAssembler regression (`assemble_single` was not loading `chunk_def.scene_path`); boss arena should now have authored geometry |
| BB-4 | m1-bugbash | **OPEN — pending next PR** | StatAllocationPanel can't be reopened mid-bank — banner copy in #128 forward-advertises P-binding; merge order matters (§0.4) |
| BB-5 | m1-bugbash | **RESOLVED pending #128 merge** | Boot banner missing LMB/RMB → expect 7-line widget; positive-screen now §0.3 |
| BB-6 | m1-bugbash | open / probe-as-before | Stacked panel close-order leaks time_scale=0.10 — minor |
| BB-7 | m1-bugbash | open / probe-as-before | Player spawn ~32 px from grunt in Room01 — minor |
| BB-8 | m1-bugbash | expected M1 state | Build is silent (no audio) — expected, NOT a bug |

**Net:** v1 listed 14 active probes; v2 has 11 active + 3 resolved-pending-merge + 1 NEW (BB-3-followup) + 1 already-resolved (BB-2). The wave shrinks the carry-forward by 4 rows.

### NEW v2 probe — BB-3-followup (LevelAssembler regression)

- **Why this is its own row, not folded into BB-3:** BB-3 in run-024 was framed as "walls aren't authored." PR #129's diagnosis revealed two compounding bugs — the walls were partially-authored (Room01 chunk had N/S only; boss room had zero) AND `LevelAssembler.assemble_single` never loaded `chunk_def.scene_path` so even fully-authored walls would have been orphaned. The assembler-load bug is more severe in the abstract (any future authored chunk geometry would have been silently dropped) but symptomatically overlapping with BB-3.
- **Probe shape:** Visual confirmation in §5.4 — boss arena has floor + 4 walls + door trigger reachable + stratum exit portal at y=30 reachable. Console silence on `[LevelAssembler]` warnings (§1.3).
- **Why this is a product-vs-component poster-child:** the bug shipped because authored `.tscn` geometry (component-complete) was never instantiated by the assembler at runtime (product-incomplete). Exactly the class `TESTING_BAR.md` PR #127 § "Product completeness ≠ component completeness" warns about.

---

## 9. Open questions (parking lot — v2 update)

**v2 inherits v1's 4 open questions** + appends questions Uma raised in PR #128's Self-Test Report comment that are still open at v2 draft time:

### Carried from v1

1. **Express soak ordering.** §6 picks AC2 → AC3 → AC6 (most surface area). If Sponsor prefers boss-first, swap.
2. **Recording vs. text.** §1.4 optional. If verbal text is faster, skip the recording.
3. **Browser choice.** Chrome is team default; if Sponsor's primary is Firefox/Edge, soak there.
4. **Soak frequency.** Not every fix-RC warrants a full re-soak (e.g., one-line copy fix). Orchestrator + Tess decide.

### NEW in v2 — micro-copy questions raised in PR #128 (Uma → Tess + orchestrator)

5. **Banner copy: `RMB to heavy attack` (current) vs `RMB to heavy-attack` (Tess BB-5 ¶135 expected, hyphenated) vs `RMB heavy attack` (drop the "to" for verb-pattern variation).**
   - **Uma's lean:** unhyphenated `RMB to heavy attack` (current) — matches the structural parallelism of the other 6 lines (`Shift to sprint`, `Space to dodge`, `LMB to attack`, etc.). At font-size 12 the hyphen reads as visual noise.
   - **Status:** OPEN. Tess can override in PR #128 review or in a v2-revision tick.

6. **Banner copy: `P to allocate stats` — forward-compat with BB-4 fix.**
   - **Uma's read:** added per BB-4's `StatAllocationPanel.gd:254` HUD-pip docstring claim ("the player presses P"). The banner copy is forward-compat with the BB-4 fix landing.
   - **Risk surfaced in §0.4:** if PR #128 merges before BB-4, Sponsor will read `P to allocate stats` and try the binding — pressing P will be a no-op until BB-4 lands. **Recommendation: orchestrator merges #128 + BB-4 PR together, OR holds #128 until BB-4 lands.** The third option ("merge #128 alone, accept the inconsistency for one wave") is the worst — guarantees a soak-found bug that Sponsor will reasonably file.
   - **Status:** OPEN — orchestrator's call.

7. **Banner copy: `Tab for inventory` (current) vs `Tab to open inventory` (longer parallel).**
   - **Uma's lean:** `Tab for inventory` (current) — shorter, visual rhythm matches the `<key> to <verb>` pattern but uses `for` because Tab is a stateful toggle (not just an open). Inventory has no separate close-key (Tab again closes), so "to open" is incomplete.
   - **Status:** OPEN. Micro-copy nit; resolvable in PR #128 review.

8. **NEW from this v2 work — should v2 ship a `pre-soak SHA-confirmation` checkbox row in §1.1?**
   - **Uma's lean:** YES, because v2's value proposition relies on being on the post-wave SHA. Sponsor confidence + dispatch-ping match = delta valid.
   - **Status:** RESOLVED in this PR — added to §1.1 as the new "NEW v2" line.

### NEW in v2 — wave-merge orchestration questions

9. **What's the orchestrator's policy for re-soaking after partial wave merge?** If #128 merges but #129 doesn't, does the re-soak run vs. the partial-wave RC (validating BB-5 only) or wait for the full wave? Today's dispatch implicitly answers "wait for the full wave" but the policy is undocumented.
   - **Uma's lean:** wait for the full wave before pinging Sponsor. A partial-wave re-soak burns Sponsor budget on a checklist where 2/3 of §0 is "still pre-fix"; better to defer.
   - **Status:** OPEN — orchestrator's call.

10. **Should v2 (this doc) replace v1 in `team/uma-ux/`, or co-exist as a wave-specific revision?**
    - **Uma's lean:** co-exist — v1 is wave-baseline, v2 is post-wave-1 revision. Future waves get v3, v4, etc. The §0 deltas section is wave-local, but §1..§9 of v2 are still ~95% v1 (inherited unchanged). Co-existence preserves the historical trail of which deltas landed when. If filesystem clutter becomes a concern (10+ wave docs), fold older deltas into a `team/uma-ux/sponsor-soak-history.md` and keep one `sponsor-soak-checklist.md` rolling-current at the top.
    - **Status:** RESOLVED in this PR — co-existence chosen. v1 stays at `sponsor-soak-checklist.md`; v2 ships at `sponsor-soak-checklist-v2.md`.

---

## Caveat — this checklist is wave-revision-aware

The v1 caveat ("§1 / §3 / §7 / §8 are reusable across M2/M3 RC soaks; §5 per-AC probes are M1-specific") still holds for v2. **NEW caveat for v2:** §0 (post-fix-wave deltas) is wave-LOCAL — it expires the moment the next wave merges and §0 must be rewritten with that wave's positive-signal screen. The v2 doc's expected lifetime is one re-soak.

**v3 trigger:** next bug-bash wave merges (e.g. post-BB-4 fix wave, or any subsequent fix run). v3 rewrites §0; §1..§9 inherit.

**Revisable triggers:**
- Sponsor's first re-soak against this checklist surfaces §1/§7 friction (revise in-place).
- A new bug class isn't covered by §5/§8 (append new probe row).
- Wave-merge-policy gets documented (resolves Q9; can drop the "subject to merge" caveat from §0 once policy answers it).
- M2 RC soak begins (swap §5 for M2 ACs).
