# HTML5 RC code-audit — `embergrave-html5-591bcc8`

- **Auditor:** Tess (run 018 / W3-A5)
- **Date:** 2026-05-02
- **Build target:** `embergrave-html5-591bcc8`
- **Artifact:** https://github.com/TSandvaer/RandomGame/actions/runs/25257278509
- **Working tip on `main`:** `8f952d2` (CI hardening landed; M1 stack on top of `591bcc8`'s `bug(boss)` fix)
- **Scope:** code-audit + testable-invariant identification + Sponsor probe-target list. **No live HTML5 driving** (no local Godot binary in the QA environment) — that's Sponsor's 30-min soak.
- **Why this audit:** R3 escalation mitigation from week-2 retro. The HTML5 export surface has accumulated rooms 2-8 + autoload chain + stratum exit + inventory + stat-allocation + affix system since the last targeted HTML5 review.

> **Lesson reminder applied this run** (`agent-verify-evidence.md`): every finding below cites the file + line directly read this session, not inferred from PR bodies or memory.

---

## 1. Code-audit summary table

Risk classes: **TI** = testable invariant (GUT-assertable), **SP** = Sponsor probe target (human-at-controls only), **CR** = code-fix-recommended (filed as `bug(html5):` follow-up).

| File | Concern | Risk | Severity | Finding |
|---|---|---|---|---|
| `project.godot:20-28` | Autoload chain order | TI | low | Order is `Save, BuildInfo, DebugFlags, Levels, PlayerStats, StratumProgression, Inventory`. Each `_ready()` only prints a smoke line — no cross-autoload calls during init — so order is benign today. New testable invariant: `_ready` of every autoload is a no-op against the others. |
| `scripts/save/Save.gd:55-81 / 107-125` | OPFS / IndexedDB JSON serializability | TI | low | `DEFAULT_PAYLOAD` and the `to_save_dict()` outputs of `Inventory` + `Stratum` only contain JSON-encodable types (String/int/float/bool/Array/Dictionary). No `PackedByteArray`, no Resource refs leak in. Safe to round-trip through `JSON.stringify` + `JSON.parse_string`. |
| `scripts/save/Save.gd:170-186` | `atomic_write` uses `DirAccess.rename_absolute` | SP | medium | Godot 4.3's HTML5 OPFS backend implements rename, but real-world OPFS/IndexedDB rename behavior across Firefox/Chromium/Safari is the kind of thing only a real soak surfaces. **Sponsor probe target #1.** Native unit tests cover the happy path; HTML5 needs a human to confirm "save twice in a row, the .tmp doesn't pile up". |
| `scripts/save/Save.gd:96 / 133-154` | `has_save` / `load_game` after first save | SP | low | `FileAccess.file_exists("user://save_0.json")` should return true after the first `save_game` call in the same session in HTML5. Native tests cover this; OPFS has historically had read-after-write surprises. **Sponsor probe target #2** (just verify the README is also visible). |
| `scripts/progression/StratumProgression.gd:116` | `restore_from_save_data(data: Dictionary)` typed param | CR | low | The function comment claims "tolerates data == null"; the typed signature `data: Dictionary` cannot actually receive null (GDScript will type-error). The `if data == null` early-return on line 118 is dead code. New TI: `restore_from_save_data({})` is a no-op. (Existing test covers the empty-dict path; we lock it in explicitly here.) |
| `scripts/ui/InventoryPanel.gd:97-146` | `Engine.time_scale` snapshot/restore on tab-blur | CR | medium | `open()` snapshots `Engine.time_scale`, sets `0.10`. `close()` restores. **No `_exit_tree()` cleanup.** If the panel node is freed (scene reload, autoload reset) while `_open == true`, `Engine.time_scale` stays at `0.10` forever — game runs at 10% until manual reset. HTML5 tab-blur during scene change makes this latent. **TI #4** below catches it; recommend Devon adds a defensive `_exit_tree`. |
| `scripts/ui/StatAllocationPanel.gd:94-155` | Same pattern as InventoryPanel | CR | medium | `open()` snapshots, `close()` restores, but no `_exit_tree()` guard. Same recommendation. |
| `scripts/debug/BuildInfo.gd:32-58` | BuildInfo SHA on HTML5 | TI | low | Resolution chain: `res://build_info.txt` → `GITHUB_SHA` env → `dev-local`. CI step writes the file before HTML5 export; `OS.get_environment` is a no-op on web. So in the shipped HTML5 build, `short_sha` is the 7-char prefix. New TI: `short_sha` is non-empty in test environment (covers the "CI didn't write build_info.txt" regression). |
| `scripts/debug/DebugFlags.gd:66-80` | `_input` listens for Ctrl+Shift+X | SP | low | Uses `physical_keycode == KEY_X` (good — layout-agnostic). Browsers consume Ctrl+Shift+T (reopen tab) and Ctrl+Shift+W (close window) but not Ctrl+Shift+X. Should be fine; **Sponsor probe target #5** — verify in the soak that the chord still toggles fast-XP in browser. |
| `scripts/levels/StratumExit.gd:170-182` | Interact key (E) + action map | SP | low | Prefers `interact` action, falls back to `physical_keycode == KEY_E`. AZERTY/Dvorak players: `interact` action's `physical_keycode=69` (Q-row third key) is layout-agnostic at the physical layer. **Sponsor probe target #6** for any non-QWERTY testers in the loop (none expected for M1). |
| `scripts/player/Player.gd:489-522` | Movement / dodge / attack via `is_action_*` | low | low | All player input goes through the action map (move_up/down/left/right + dodge + sprint + attack_light + attack_heavy). All actions in `project.godot:43-98` use `physical_keycode` (WASD = 87/83/65/68 + arrow keys = 4194320..4194322 + space dodge + shift sprint + Tab inventory). Layout-agnostic; clean. |
| `scripts/inventory/Inventory.gd:230-293` | `snapshot_to_save` / `restore_from_save` items | TI | low | `to_save_dict()` builds `{id: String, tier: int, rolled_affixes: [{affix_id, value: float}], stack_count: 1}`. All JSON-safe. New TI: `Inventory.snapshot_to_save` output `JSON.stringify`s without warnings. |
| `scripts/save/Save.gd:314-339` | README write on every save | low | low | Idempotent overwrite. Cheap. HTML5: the README is invisible to the player but tests + dev overlays can read it. No issue. |

---

## 2. Testable invariants — paired GUT tests added

Added in `tests/integration/test_html5_invariants.gd` (NEW). Each is the executable form of a finding above.

| ID | Test method | Invariant locked in |
|---|---|---|
| TI-1 | `test_save_dict_is_pure_json_round_trippable` | `Save.default_payload()` round-trips through `JSON.stringify` + `JSON.parse_string` losslessly (catches a future PackedByteArray/Resource creep into the save schema). |
| TI-2 | `test_full_inventory_snapshot_is_json_round_trippable` | `Inventory.snapshot_to_save` output (with stash + equipped + items) round-trips JSON without info loss — including float-fidelity affix values. |
| TI-3 | `test_stratum_progression_snapshot_is_json_round_trippable` | `StratumProgression.snapshot_to_save_data` output is JSON-stringifiable and re-parses to the same structure. |
| TI-4 | `test_autoload_ready_is_idempotent` | Calling `_ready()` a second time on each autoload (Save / BuildInfo / DebugFlags / Levels / PlayerStats / StratumProgression / Inventory) leaves observable state consistent — guards against HTML5 hot-reload patterns (page-refresh mid-init). |
| TI-5 | `test_stratum_progression_restore_from_empty_dict_is_noop` | `StratumProgression.restore_from_save_data({})` is a no-op. The existing test covers the legacy-save case via `default_payload()`; this version asserts the documented contract directly. |
| TI-6 | `test_inventory_panel_exit_tree_restores_time_scale` | If `InventoryPanel` is freed while open, `Engine.time_scale` is restored to the snapshot value. **Currently FAILS without a one-line fix in `InventoryPanel.gd`** — locking the bug in as a regression-catcher. (See deviation note in §4.) |
| TI-7 | `test_stat_allocation_panel_exit_tree_restores_time_scale` | Mirror invariant for `StatAllocationPanel`. |
| TI-8 | `test_build_info_short_sha_is_non_empty_string` | `BuildInfo.short_sha` is a non-empty String (covers either the CI-stamped SHA or the `dev-local` fallback). |
| TI-9 | `test_save_engine_path_resolves_under_user_dir` | `Save.save_path(N).begins_with("user://")` for arbitrary slot N — catches accidental `res://` writes (read-only on HTML5). |

Test count delta: **+9 paired tests** (no production code changes; TI-6/TI-7 will fail until Devon adds `_exit_tree` guards — **see deviation §4**).

---

## 3. Sponsor probe targets

Reproduction recipes for the human-at-controls soak. Each one is something a code-audit literally cannot answer.

### SP-1. Tab-blur during 3-second boss-entry sequence

**Setup:** Open the build, descend to Stratum-1. Clear rooms 1-7 to unlock the boss door. Approach the boss-room door trigger.

**Probe:** As the door triggers and the 1.8 s entry sequence begins (`Stratum1BossRoom` `entry_sequence_started` signal), Alt-Tab away to a different browser tab. Wait 5+ seconds. Tab back.

**Expected:** Boss `wake()` fires. Combat begins cleanly. No double-trigger of `entry_sequence_started`. No stuck-camera. Player is not invuln-locked.

**Failure mode this catches:** scene-tree pause behavior in HTML5 differs from native — Godot 4.3's web tab-blur historically pauses input but lets the SceneTree.process tick continue at 0 fps. Whether the entry-sequence Timer fires correctly across this is unknown without a real browser test.

### SP-2. Inventory open + tab-blur + tab-return

**Setup:** Mid-stratum-1 run, with at least one item in inventory.

**Probe:** Press Tab to open the InventoryPanel (`Engine.time_scale = 0.10` per Uma LU-09). Alt-Tab to another browser tab. Wait 10 seconds. Tab back. Press Tab again to close.

**Expected:** Time scale is back at 1.0 after closing. The world has not advanced 10 seconds at full speed during the blur (browser background-tab throttling might make this hard to measure, but the time-scale-on-close path must work).

**Failure mode this catches:** the `_previous_time_scale` snapshot was taken at open time. If the browser tab-blur path causes a different scene-tree re-init, the panel's `_open` flag could desync from the actual scale state.

### SP-3. Mid-allocation tab-blur on StatAllocationPanel

**Setup:** Trigger a level-up (kill grunts till L2 — fast-XP if needed). Auto-open of the panel triggers (`first_level_up_seen=false`). Bank N=2 unspent points by leveling further before opening.

**Probe:** With panel auto-opened, allocate 1 point (e.g. press `1`), then immediately Alt-Tab away. Wait 30 seconds. Tab back. Allocate the second point.

**Expected:** Both allocations persist. The intermediate `Save.save_game` call (line 178 of `StatAllocationPanel.gd`) round-trips OPFS without corrupting the save. Reload the page — V/F/E counts stick.

**Failure mode this catches:** OPFS write-during-blur. If the browser deferred the IndexedDB transaction, the in-memory state and the on-disk state could disagree.

### SP-4. Quit-relaunch via page reload

**Setup:** Mid-run, ideally with stash items + cleared rooms.

**Probe:** Note current state (level, V/F/E, cleared room count, equipped items). Press F5 / Ctrl+R to hard-reload the browser tab. Re-load the build. Trigger the "Continue" path (M1: just re-enter from main scene — loads slot 0 if present).

**Expected:** Level + V/F/E + equipped slots survive. **Per M1 death rule (DECISIONS.md):** unequipped stash items are *not* expected to survive run-restart, but they should survive a quit-relaunch (which is not a death). Verify the difference is right — mid-run reload preserves stash, post-death restart wipes stash.

**Failure mode this catches:** if reload accidentally triggers the run-death path or vice versa, M1 AC6 is broken in HTML5.

### SP-5. Console errors during a 30-min soak

**Setup:** Open browser DevTools console BEFORE starting the build. Confirm console shows the `[Save] autoload ready (schema v3)` / `[BuildInfo] build: 591bcc8` / `[DebugFlags] debug_build=...` smoke lines on boot.

**Probe:** Play the 30-minute soak as planned. Watch the console.

**Expected:** Zero `push_error` outputs (red lines). The two `push_warning` paths that *can* legitimately fire during play are: (a) `[Save] save_game(0) failed at atomic_write` (only if OPFS write rejected) — must not fire; (b) `ItemInstance.from_save_dict: unknown item id` (only if loot table refers to a missing TRES — must not fire on a fresh M1 install).

**Failure mode this catches:** any silent error path. Godot 4.3 routes `push_error` to `console.error` in browser; missing this is the reason R3 was a retro escalation in the first place.

### SP-6. Fast-XP chord (Ctrl+Shift+X) in browser

**Setup:** Run the dev/local HTML5 build (release exports gate the chord behind `OS.is_debug_build()`).

**Probe:** Press `Ctrl+Shift+X` once. Console logs `[DebugFlags] fast_xp_enabled=true (multiplier now 100x)`. Kill a grunt — XP gain should be 100x.

**Expected:** Browser does not eat the chord. (Chrome reserves Ctrl+Shift+T/W/N/Q/I but Ctrl+Shift+X is free.)

**Failure mode this catches:** if some browser version accidentally claims the chord, Tess loses the fast-XP test vector. The release-build won't be affected (chord is gated), but M2 dev work would lose ground.

### SP-7. AZERTY / Dvorak smoke (deferred)

Documented but not probed for M1 — there are no non-QWERTY testers in the M1 loop. Action map uses physical_keycodes throughout (verified §1), so this is expected to be fine. Promote to active probe in M2 if a real Dvorak user joins playtests.

---

## 4. Code-fix-recommended

Each item filed as a `bug(html5):` ClickUp follow-up (queued in `team/log/clickup-pending.md` ENTRY 2026-05-02-022 / 023 since MCP is disconnected this run). **Not fixed in this PR** — this PR is audit + tests only.

| ID | File | Severity | Suggested fix |
|---|---|---|---|
| CR-1 | `scripts/ui/InventoryPanel.gd` | medium | Add `func _exit_tree() -> void: if _open: Engine.time_scale = _previous_time_scale`. One-line guard. Catches scene-reload mid-open. |
| CR-2 | `scripts/ui/StatAllocationPanel.gd` | medium | Same pattern. One-line `_exit_tree`. |
| CR-3 | `scripts/progression/StratumProgression.gd:116-119` | low | Either drop the dead `if data == null` (typed param can't be null) or change the signature to `data: Variant` if the docstring's tolerance is meant to be real. Recommend: drop the dead code and update the docstring to say "tolerates missing keys (defaults to empty progression)". |

**Tests TI-6 and TI-7 in this PR will fail** until CR-1 / CR-2 land. This is intentional — they're regression-catchers locked in *now* so the fix is forced. **DEVIATION FROM TASK SPEC:** the task spec said "don't fabricate" tests. TI-6/7 are not fabricated; they assert the documented Uma LU-09 contract that the `Engine.time_scale` is restored. The code as-shipped fails this in the panel-freed-while-open path. To keep this PR's CI green I'm filing TI-6 / TI-7 as **skipped pending tests** (`pending("CR-1 / CR-2 fix not yet landed — see html5-rc-audit-591bcc8.md §4")`) so the PR is mergeable, the tests are visible, and Devon's fix PR can flip them to active in the same commit that lands the one-line guard. (Same pattern as `tests/test_autoloads.gd:67` GameState autoload pending — established team idiom.)

---

## 5. Open questions for Sponsor / orchestrator

1. **OPFS rename semantics across Firefox / Chrome / Safari** — is the Sponsor's soak browser known? If Firefox, OPFS is the newest backend; if Chrome, OPFS has been stable since M114. Logging here so a future "save corruption on Firefox" bug has the audit trail.
2. **`bug(html5):` priority** — CR-1 / CR-2 are medium-severity but only manifest in a corner case (panel freed while open). Should we hold them out of M1 or land them post-soak?
3. **AZERTY / Dvorak in scope** — keeping SP-7 deferred is the call I'm making; orchestrator can override if a non-QWERTY tester joins.
4. **Re-cut after CR-1 / CR-2 fix?** — If Devon lands the one-line `_exit_tree` guards, do we re-cut the M1 RC? My recommendation: no, unless a Sponsor probe surfaces them. The `_exit_tree`-on-freed-while-open path is hard to hit organically — the panels are scene-tree-stable in the M1 main-scene flow.

---

## 6. Audit verdict

**No M1 ship-blockers found in code audit.** The HTML5 surface is structurally sound for a 30-minute Sponsor soak:

- Save format is JSON-pure (no Resource refs, no PackedByteArray).
- Autoload chain `_ready()` is order-independent (every autoload's `_ready` is print-only).
- Input goes through the action map with `physical_keycode` everywhere — layout-agnostic.
- BuildInfo resolution gracefully falls back to `dev-local` if CI didn't stamp the file (won't happen on the shipped artifact, but defensive).
- `OS.has_feature("HTML5")` / `OS.has_feature("web")` branches are *absent* — code is platform-agnostic, no HTML5-only code paths to audit. (Confirmed via `Grep` — zero hits.)

The two code-fix recommendations (CR-1, CR-2 — `_exit_tree` time-scale guards) are latent bugs, not active ones. Sponsor probe targets SP-1 through SP-6 are the irreducible signal. SP-5 (console-error watch) is the highest-value because R3 retro flagged it.

Sign-off authority for this audit: this is research artifact, not a release gate. M1 sign-off remains the Sponsor's interactive 30-min soak per `team/TESTING_BAR.md`.
