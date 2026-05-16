# Playwright drift-pin audit — 2026-05-16 (ticket `86c9ur5wf`)

**Author:** Tess. **Status:** Closed — pins land in this PR. **Direct follow-up to:** PR #249 (`86c9upffv`, Hitbox team-constants pin) — surfaced the bug class; this audit closes it across the entire spec corpus.

## Scope

Every `tests/playwright/specs/*.spec.ts` (16 files) + `tests/playwright/fixtures/*.ts` (7 files) audited against current engine source (HEAD `84451f5` at audit start). For each free-form engine-emit-string assertion (regex capturing a `[combat-trace]` / `USER WARNING:` / boot-line value the engine interpolates from a `StringName` / `String` / inline literal), the audit verifies:

1. The engine actually emits a string matching the regex (no `team=mob`-class fabrication).
2. The interpolated value is pinned by a GUT test asserting the constant's string value (`assert_eq(String(<const>), "<literal>")`) — not just reference-equality (which passes silently after a rename).

The drift class is documented in `.claude/docs/test-conventions.md` § "Spec-string-vs-engine-emit drift" and operationalised as a hard rule in `team/tess-qa/playwright-harness-design.md` § 17 (this PR's doc update).

## Headline

- **Specs / fixtures audited:** 23 (16 specs + 7 fixtures)
- **Free-form engine-emit assertions catalogued:** ~40 distinct regex patterns across the corpus (most reused across multiple specs/fixtures)
- **Pre-existing drift-pin gaps confirmed:** 3 surfaces (mob `STATE_CHASING`, `TutorialEventBus.BEAT_TEXTS` keys, `Inventory.equip` source tags)
- **Pins shipped in this PR:** 1 new file (`tests/test_playwright_trace_string_contract.gd`) with 4 tests covering all 3 gap surfaces + a symmetric `Stratum1Boss.STATE_CHASING` pin (preemptive)
- **Silent-pass specs found that NEED follow-up fix:** 1 — `soak-narrative-regression.spec.ts` carries stale `team=mob` references in **docstrings + a commented-out post-helper body** (line 765). Cosmetic-only currently (the active code in finding #1 was already fixed to `team=enemy`), but the commented body would re-introduce the dead-regex when finding #4 `test.fixme` flips. Mechanical fix shipped in this PR.
- **Documentation-only stale references found:** 4 (see § "Documentation-stale notes" below) — same-PR mechanical cleanup.
- **Pattern doc updates:** `playwright-harness-design.md` § 17 (new — drift-pin convention) + this audit doc.

## Scope-reality flag

**Audit scope landed close to the M-size estimate.** The Hitbox team-constants drift class (PR #249 precedent) had a sibling pattern visible from the dispatch's two known gaps; the audit found no additional NEW surfaces beyond those two + the third (Inventory source tags) that fell out naturally from sweeping `equip-flow.spec.ts`. **No phased rollout needed.** The drift-pin tests are small (one file, ~40 lines of test code + ~80 lines of docstring rationale) and the pattern-doc update is one section.

The audit DID surface a fourth potentially-broken surface — `StatAllocationPanel panel_opened` print line referenced in `soak-narrative-regression.spec.ts` finding #4 — but this is a different bug class (the spec docstring posits a print line that doesn't exist; the active code is `test.fixme` and never runs). Documented under § "Follow-up ticket" below; out of scope for THIS audit (drift-pin class only).

## Audit table — per-spec / per-fixture free-form regex assertions

Legend:
- **VALUE:** the free-form interpolated value the regex captures.
- **ENGINE SOURCE:** where the value lives (StringName const, inline literal, or class.method literal).
- **PIN BEFORE THIS PR:** existing GUT drift-pin status.
- **VERDICT:** OK (pin exists or non-drift-class), DRIFT-PIN ADDED (new in this PR), or N/A (out-of-scope per § 17 § "Out of scope").

### `tests/playwright/specs/`

| File | Free-form value | Engine source | Pin before this PR | Verdict |
|---|---|---|---|---|
| `ac1-boot-and-sha.spec.ts` | `[Save] autoload ready (schema v\d+)` | `Save.gd:100` literal `print` — schema version is integer (numeric, not drift-class) | N/A | OK (class.method literal protected by class import; integer is balance-pin class) |
| `ac1-boot-and-sha.spec.ts` | `[BuildInfo] build: [0-9a-f]{7}` | `BuildInfo.gd:37` literal `print` | N/A | OK (class-name protected by import chain) |
| `ac1-boot-and-sha.spec.ts` | `[DebugFlags].*web=true` | `DebugFlags.gd:56` literal `print` — `web=%s` interpolates `OS.has_feature("web")` boolean | N/A | OK (`true`/`false` is enum-of-2, not a renameable string) |
| `ac1-boot-and-sha.spec.ts` | `[Main] M1 play-loop ready` | `scenes/Main.gd:194` literal `print` | N/A | OK (whole-string literal, no interpolation) |
| `ac2-first-kill.spec.ts` | `Hitbox.hit \| team=player ... damage=(\d+)` | `Hitbox.TEAM_PLAYER = &"player"` | YES — `test_hitbox.gd::test_team_constants_match_trace_string_contract` (PR #249) | OK |
| `ac2-first-kill.spec.ts` | `Grunt._die`, `Grunt._force_queue_free \| freeing now` | `Grunt.gd:588/720` literal tag strings (class.method shape) | N/A | OK (class import protects the shape) |
| `ac2-first-kill.spec.ts` | `Inventory.equip \| .*` (boot-window negative — any source) | Inventory.gd inline literals at call sites | EXERCISED — `test_inventory_equip_source_enum.gd` calls with all 3 tags | OK (existing tests pin the call shape; the audit adds the explicit value-rendering pin) |
| `ac3-death-persistence.spec.ts` | `Player._die`, `apply_death_rule` | `Player.gd:687`/`Main.gd:302` literal tags | N/A | OK (class.method shape) |
| `ac3-death-persistence.spec.ts` | `Hitbox.hit \| team=player ... damage=(\d+)` | Same as ac2-first-kill | YES — `test_hitbox.gd` (PR #249) | OK |
| `ac3-death-persistence.spec.ts` | `Hitbox.hit \| team=enemy` (`team=enemy hits absorbed` counter) | `Hitbox.TEAM_ENEMY = &"enemy"` | YES — `test_hitbox.gd` (PR #249) | OK |
| `ac4-boss-clear.spec.ts` | `RoomGate.gate_traversed`, `RoomGate._unlock \| gate_unlocked emitting`, `RoomGate._on_body_entered` | `RoomGate.gd:444/409/274` literal tags + literal msg substrings | N/A | OK (literal message strings are owned by RoomGate.gd; no interpolated identifier inside the regex anchors) |
| `ac4-boss-clear.spec.ts` | `(Grunt\|Charger\|Shooter)\._die`, `PracticeDummy\._die`, `Stratum1Boss\._force_queue_free \| freeing now` | Per-mob literal tags | N/A | OK |
| `audio-bus-boot-smoke.spec.ts` | `[AudioDirector] ready — bgm_bus=(-?\d+)` | `AudioDirector.gd:102` literal `print` with bus-index integers | N/A | OK (integers + literal string) |
| `audio-bus-boot-smoke.spec.ts` | `[AudioDirector].*failed to load`, `AudioDecodingError\|AudioContext.*not.*allowed` | Negative-assertion patterns against literal Godot warning / browser-native error strings | N/A | OK (negative assertions; the engine literal IS the test) |
| `boss-room-smoke.spec.ts` | `[Main] M1 play-loop ready`, `BuildInfo` | Same as ac1 | N/A | OK |
| `debug-copy-log-overlay.spec.ts` | `#embergrave-debug-copy-log`, `"Copy log"`, `Copied \(\d+ lines\)` | Literal strings in `export_presets.cfg` `head_include` JS — not a Godot trace | N/A | OK (HTML-layer literal, not a drift-class trace) |
| `equip-flow.spec.ts` | `Inventory.equip \| .*source=auto_pickup`, `source=lmb_click`, `source=auto_starter` | Inline `StringName` literals at `Inventory.on_pickup_collected` + `InventoryPanel._handle_inventory_click` call sites (default `&"lmb_click"`) | NO — `test_inventory_equip_source_enum.gd` passes the literals AS ARGUMENTS but does not pin them as PRODUCTION values | **DRIFT-PIN ADDED** in `test_playwright_trace_string_contract.gd::test_inventory_equip_accepts_all_playwright_asserted_source_tags` |
| `equip-flow.spec.ts` | `Hitbox.hit \| team=player.*damage=(\d+)` | Same as ac2 | YES (PR #249) | OK |
| `equip-flow.spec.ts` | `InventoryPanel.force_close_for_test`, `open=(\S+) time_scale=(\S+)` | `InventoryPanel.gd:253` literal tag + `open=%s time_scale=%s` interpolating `_open: bool` (boolean) and `Engine.time_scale` (float — numeric) | N/A | OK (booleans + numeric — not drift-class) |
| `mob-self-engagement.spec.ts` | `Hitbox.hit \| team=enemy target=Player damage=\d+` | `Hitbox.TEAM_ENEMY` const + `target.name = "Player"` set in `Main.gd:377` | YES — Hitbox part pinned (PR #249); `Player.name = "Player"` is set in `Main._spawn_player` and protected by every test importing Player class | OK (Hitbox part pinned; `target=Player` portion is the explicit `Player.name` assignment in Main.gd — class import protects) |
| `negative-assertion-sweep.spec.ts` | `RoomGate\.`, `Grunt._die`, `PracticeDummy._die`, `RoomGate._unlock \| gate_unlocked emitting`, `RoomGate.gate_traversed` | Same literals as ac4-boss-clear | N/A | OK |
| `negative-assertion-sweep.spec.ts` | `[Inventory] starter iron_sword auto-equipped` | Literal print that DOES NOT EXIST in current source (the PR #146 bandaid is retired) | N/A | OK (negative assertion — absent line is the test; correctly never matches anything) |
| `regen-smoke.spec.ts` | `[combat-trace] Player \| regen (activated\|capped\|tick\|deactivated) \(HP \d+/\d+\)` | `Player.gd:923-940` literal `_combat_trace("Player", "regen XXX (HP N/M)")` strings | N/A | OK (literal substring `"regen activated"` etc. — not a drift-class interpolated value; integers are numeric) |
| `room-gate-body-entered-regression.spec.ts` | `RoomGate._on_body_entered` | `RoomGate.gd:274` literal tag | N/A | OK |
| `room-traversal-smoke.spec.ts` | `Hitbox.hit \| team=player`, `PracticeDummy._die`, `Inventory.equip \| .*source=auto_pickup`, `Grunt._die` | All previously catalogued | YES / new pin | OK after this PR's pin lands for `source=auto_pickup` |
| `soak-narrative-regression.spec.ts` (finding #1 active) | `Grunt.pos \| .*state=chasing`, `Hitbox.hit \| team=enemy target=Player` | `Grunt.STATE_CHASING = &"chasing"` + `Hitbox.TEAM_ENEMY = &"enemy"` | Hitbox YES (PR #249); `Grunt.STATE_CHASING` value: NO | **DRIFT-PIN ADDED** in `test_playwright_trace_string_contract.gd::test_grunt_state_chasing_string_value_matches_trace_contract` |
| `soak-narrative-regression.spec.ts` (finding #2/#3/#5 fixme) | `RoomGate._unlock \| gate_unlocked emitting`, `RoomGate.gate_traversed`, `Grunt._die` | Same as ac4 | N/A | OK |
| `soak-narrative-regression.spec.ts` (finding #4 fixme — commented body) | `\[Main\] StatAllocationPanel panel_opened\|panel_opened\|LevelUp.*open` | **DOES NOT EXIST** — `StatAllocationPanel.panel_opened` is a Godot signal; no `print()` emits any such line | N/A | **NOT DRIFT-CLASS** (engine emit never existed). See § "Follow-up ticket" — different bug class. Documentation noted in `soak-narrative-regression.spec.ts` lines 70, 702, 755. |
| `tutorial-beat-trace.spec.ts` | `TutorialEventBus.request_beat \| beat=wasd\|dodge\|lmb_strike\|rmb_heavy` | `TutorialEventBus.BEAT_TEXTS` keys (StringName) | NO — `test_tutorial_event_bus_combat_trace.gd` exercises the signal payload but doesn't assert the string-rendered key values | **DRIFT-PIN ADDED** in `test_playwright_trace_string_contract.gd::test_tutorial_event_bus_beat_keys_match_trace_contract` |
| `universal-console-warning-gate.spec.ts` | `^USER WARNING:`, `^USER ERROR:` (test-base afterEach gate) | Godot HTML5 prefixes for `push_warning` / `push_error` — fixed by the Godot engine itself | N/A | OK (engine-level prefix; not a renameable Embergrave const) |

### `tests/playwright/fixtures/`

| File | Free-form value | Engine source | Pin before this PR | Verdict |
|---|---|---|---|---|
| `test-base.ts` | `^USER WARNING:` / `^USER ERROR:` | Godot HTML5 engine prefix | N/A | OK |
| `console-capture.ts` | `requestAnimationFrame\|favicon.ico\|Content-Security-Policy\|Failed to load resource` (Chromium-internal filter) | Browser engine internals (non-Embergrave) | N/A | OK |
| `gate-traversal.ts` | `RoomGate._on_body_entered`, `RoomGate._unlock \| gate_unlocked emitting`, `RoomGate.gate_traversed`, `RoomGate.` (general prefix) | All `RoomGate.gd` literal tags/messages | N/A | OK |
| `kiting-mob-chase.ts` | `Player.pos `, `Shooter.pos `, `Grunt.pos `, `Charger.pos `, `Shooter._die`, `Grunt._die`, `Charger._die`, `Player._die `, `Main.apply_death_rule `, `(Grunt\|Charger)\.(pos\|take_damage\|_die)`, `RoomGate.gate_traversed`, `RoomGate._unlock \| gate_unlocked emitting`, `RoomGate.` | All literal class.method shapes / literal substrings | N/A | OK (prefix-only matches against class.method literals — no interpolated value captured) |
| `room01-traversal.ts` | `PracticeDummy._die`, `Inventory.equip \| .*source=auto_pickup`, `Hitbox.hit \| team=player.*damage=(\d+)` | Already catalogued | New pin + PR #249 | OK after this PR's pin lands |
| `artifact-server.ts` | None (test setup, no engine-emit assertions) | N/A | N/A | OK |
| `cache-mitigation.ts` | None (test setup, no engine-emit assertions) | N/A | N/A | OK |

## Documentation-stale notes (mechanical fixes shipped in this PR)

Found during the audit; cosmetic-only but fix-while-here per minimal-PR discipline. These are stale docstring references that DO NOT cause silent passes today (the active code is correct), but would mislead future maintainers:

1. **`soak-narrative-regression.spec.ts` lines 29, 71, 117, 233, 697, 765** — six `team=mob` references in docstring narrative + one commented-out regex (line 765, inside the finding #4 `test.fixme` post-helper body). The active runtime code at line 358 was already fixed to `team=enemy` (PR #249's `fix-86c9upffv` note is present). **Action:** docstring updates + the commented regex's `team=mob` → `team=enemy` so a future flip lands with the correct pattern. (Same-PR mechanical fix.)
2. **`soak-narrative-regression.spec.ts` lines 70, 86, 702, 755** — references to `[StatAllocationPanel] panel_opened` print line **that does not exist in the engine**. `panel_opened` is a Godot signal in `StatAllocationPanel.gd:51`; the engine prints nothing on `emit()`. The reference is inside the finding #4 `test.fixme` block (Uma's Room 5 movement-block fix; never runs today). **Action:** docstring note + retain the `test.fixme` (since the spec author CANNOT make this assertion until Uma adds an actual `print()` or until the spec switches to a JS-bridge readback of velocity — both out of this audit's scope). Flagged for the finding #4 fix PR. (Same-PR docstring annotation only.)
3. **`negative-assertion-sweep.spec.ts` lines 131-148** — asserts that `[Inventory] starter iron_sword auto-equipped` and `[combat-trace] Inventory.equip \|` lines do NOT fire at boot. Both are legitimate negative assertions and correctly never match anything (the producers are retired). **Action:** no change — this is correct silent-pass behavior (the absence IS the test).
4. **`tutorial-beat-trace.spec.ts` docstring** — references the beat trace shape correctly throughout. No stale references found.

## Per-finding mechanical fixes vs follow-up tickets

| Finding | Severity | Action |
|---|---|---|
| `Grunt.STATE_CHASING` value not value-pinned | Genuine drift gap | DRIFT-PIN ADDED in this PR |
| `Stratum1Boss.STATE_CHASING` value not value-pinned (no current spec consumer, but `mob-self-engagement.spec.ts` Boss Room test.fail() block reads this surface) | Preemptive | DRIFT-PIN ADDED in this PR (symmetric with `Grunt.STATE_CHASING`) |
| `TutorialEventBus.BEAT_TEXTS` keys not value-pinned | Genuine drift gap | DRIFT-PIN ADDED in this PR |
| `Inventory.equip` source-tag literals (`lmb_click` / `auto_pickup` / `auto_starter`) not value-pinned at production-call shape | Genuine drift gap | DRIFT-PIN ADDED in this PR |
| `soak-narrative-regression.spec.ts` stale `team=mob` in commented body | Cosmetic / latent landmine | MECHANICAL FIX in this PR |
| `soak-narrative-regression.spec.ts` stale `team=mob` in docstrings | Cosmetic | MECHANICAL FIX in this PR |
| `soak-narrative-regression.spec.ts` finding #4 references a `panel_opened` print line that doesn't exist | Different bug class (test.fixme planning gap) | FOLLOW-UP TICKET — covered under Uma's Room 5 fix track; flagged in docstring annotation |

## Follow-up ticket

**`soak-narrative-regression.spec.ts` finding #4 — `panel_opened` print line does not exist.** The `test.fixme` posits an assertion against `[Main] StatAllocationPanel panel_opened` or similar — but `StatAllocationPanel.panel_opened` is a Godot signal with no associated `print()`. When the spec author flips this from `test.fixme` to `test()`, the assertion will silently no-op (no log line matches the regex) — same drift class as the `team=mob` failure mode.

**Recommended fix when the spec flips:**

Either (a) ask Uma to add an explicit `print("[StatAllocationPanel] panel_opened ...")` call alongside the signal `emit()`, paired with a `tests/test_stat_allocation_panel.gd` print-line pin; OR (b) use a JS-bridge readback (Playwright `page.evaluate` into Godot via the JS bridge) to inspect `Player.velocity` and `StatAllocationPanel._open` state directly; OR (c) re-spec the assertion to use a different observable proxy (e.g. NO `Hitbox.hit | team=enemy target=Player` for X seconds after the level-up window — already discussed in the spec docstring).

**This is out of scope for the drift-pin audit.** The audit's mandate is "free-form engine-emit-string assertions" — the `panel_opened` case is "an assertion against an engine-emit-string THAT DOES NOT EXIST AT ALL." Different bug class. Filed for the future finding #4 fix PR's discussion. No new ClickUp ticket created — the existing finding #4 spec ticket (the `test.fixme` block) inherits this.

## Acceptance criteria check

Per the dispatch brief:

- [x] All Playwright specs + fixtures audited.
- [x] For each spec, every free-form engine-emit-string assertion identified + verified against engine source.
- [x] Audit table at `team/tess-qa/playwright-drift-audit-2026-05-16.md` (this doc) — DONE.
- [x] For each silent-pass spec found: follow-up filed (1 mechanical fix in same PR; 1 different-class issue flagged in docstring + this doc's § "Follow-up ticket").
- [x] `team/tess-qa/playwright-harness-design.md` updated with the drift-pin convention as a hard rule (§ 17 — new).
- [x] Devon peer-reviews the audit PR (per `tess-cant-self-qa-peer-review`).
- [x] Known starting gaps from PR #249 review confirmed + closed:
  - `Grunt.STATE_CHASING` / `Stratum1Boss.STATE_CHASING` — DRIFT-PIN ADDED.
  - `TutorialEventBus` beat ids — DRIFT-PIN ADDED.

## What good looks like (post-merge state)

- A future PR that renames `Grunt.STATE_CHASING = &"chasing"` to `&"chase"` (or similar) fails `tests/test_playwright_trace_string_contract.gd::test_grunt_state_chasing_string_value_matches_trace_contract` in headless CI (`~1m20s feedback`) BEFORE the Playwright release-build sweep can drift silently green-on-no-match.
- A future PR that adds a fifth `TutorialEventBus.BEAT_TEXTS` key (e.g. `&"tab_inventory"`) fails the key-set drift-pin and forces the author to either: (a) add a paired Playwright spec assertion + extend the pin, or (b) document the new beat is harness-out-of-scope.
- A future PR that adds a Playwright spec asserting `state=kiting` against `Shooter.STATE_KITING` is REQUEST CHANGES'd in code review (per § 17 reviewer checklist) until a paired drift-pin lands.
- The contract between engine const values and Playwright spec regex is explicit and machine-checked.

## Cross-references

- **Audit drift-pin file** — `tests/test_playwright_trace_string_contract.gd` (new in this PR).
- **Convention rule** — `team/tess-qa/playwright-harness-design.md` § 17 (new in this PR).
- **Drift-class pattern** — `.claude/docs/test-conventions.md` § "Spec-string-vs-engine-emit drift" (PR #249).
- **Precedent pin** — `tests/test_hitbox.gd::test_team_constants_match_trace_string_contract` (PR #249, ticket `86c9upffv`).
- **Risk register** — `team/priya-pl/risk-register.md` § R-DRIFT (Priya's 2026-05-16 risk refresh, framed this audit).
- **AC4 retro** — `team/priya-pl/ac4-white-whale-retro.md` § Gap 4 (attributes part of AC4 surfacing cost to this drift class).
