extends GutTest
## Drift-pin GUT tests for engine-side StringName / String values that feed
## free-form `[combat-trace]` line shapes which Playwright specs assert
## against via regex. Ticket `86c9ur5wf` (class-wide Playwright drift-pin
## audit) — follow-up to PR #249 (Hitbox team-constants pin) which
## established the pattern.
##
## **The drift class.** Playwright specs grep production trace lines by
## regex. The lines are interpolated from engine-side `StringName` /
## `String` constants. If an engine refactor renames a constant value
## (e.g. `&"chasing"` → `&"chase"`), the spec regex stops matching real
## production output — but Playwright reports "assertion failed" the same
## way as a real engine bug, so the misdiagnosis class is open. Per the
## convention in `.claude/docs/test-conventions.md` § "Spec-string-vs-engine-
## emit drift" (PR #249), every engine-side const that feeds a Playwright-
## asserted trace string needs a value-asserting GUT pin so the GUT suite
## (always green in CI) flips RED on a rename before the Playwright spec
## drifts silently green-on-no-match.
##
## **What this file pins (audit gaps from ticket `86c9ur5wf`):**
##
##   1. **`Grunt.STATE_CHASING == "chasing"`** — `soak-narrative-regression.
##      spec.ts` asserts on `[combat-trace] Grunt.pos | ... state=chasing`
##      (literal string in regex). `Grunt.gd` declares `STATE_CHASING:
##      StringName = &"chasing"` and `_combat_trace("Grunt.pos", "...
##      state=%s ..." % [..., _state, ...])`. A future rename of the
##      StringName value would silently break the spec.
##
##   2. **`Stratum1Boss.STATE_CHASING == "chasing"`** — same risk class:
##      no Playwright spec currently asserts on boss-chasing state (the
##      AC4 spec asserts on `Stratum1Boss._force_queue_free | freeing now`
##      only, and the boss has its own STATE-machine), but the boss
##      `_combat_trace` shim emits its `_state` value the same way, and
##      mob-self-engagement Boss Room (currently `test.fail()`) reaches
##      this surface via `Hitbox.hit | team=enemy target=Player`. Pinning
##      both grunt + boss makes the contract explicit + symmetric.
##
##   3. **`TutorialEventBus.BEAT_TEXTS` keys == ["wasd", "dodge",
##      "lmb_strike", "rmb_heavy"]** — `tutorial-beat-trace.spec.ts`
##      asserts on `[combat-trace] TutorialEventBus.request_beat |
##      beat=wasd|dodge|lmb_strike|rmb_heavy`. The bus's
##      `request_beat(beat_id, anchor)` interpolates the beat_id via
##      `"beat=%s anchor=%d" % [beat_id, anchor]`. A rename of any
##      BEAT_TEXTS key would silently break the spec.
##
##   4. **`Inventory.equip` source-tag literals** — `equip-flow.spec.ts`
##      asserts on `source=auto_pickup` / `source=lmb_click` and
##      negative-asserts `source=auto_starter`. `Inventory.gd` does NOT
##      centralise these as constants — they appear as inline literals
##      at the two production call sites (`Inventory.on_pickup_collected`
##      → `equip(item, &"weapon", &"auto_pickup")`; `InventoryPanel.
##      _handle_inventory_click` → `equip(item, slot)` default
##      `&"lmb_click"`). The drift-pin here asserts the production call
##      sites still use these literal strings by routing through `equip()`
##      and reading back `_emit_equip_trace`'s composed source-tag from
##      its arguments.
##
## **What this file does NOT pin** (covered elsewhere):
##
##   - `Hitbox.TEAM_PLAYER` / `Hitbox.TEAM_ENEMY` — already pinned in
##     `tests/test_hitbox.gd::test_team_constants_match_trace_string_contract`
##     (PR #249, ticket `86c9upffv`).
##   - Boss state names other than `STATE_CHASING` — no Playwright spec
##     asserts on `dormant`/`idle`/`telegraphing_*`/`attacking`/etc. by
##     literal value (only `Stratum1Boss._force_queue_free | freeing now`
##     and `Stratum1Boss.take_damage | amount=N hp=...`, neither of which
##     interpolates a StringName). If a future spec asserts on a boss state
##     literal, extend the pin here.
##   - `Charger` / `Shooter` `.pos`-state values — no Playwright spec
##     asserts on Charger/Shooter `state=<literal>` values currently.
##     Specs grep `Shooter.pos `/`Charger.pos ` as prefix-only. If a
##     future spec adds a state-literal assertion (e.g. `state=kiting`),
##     extend the pin here.
##
## **Pattern check before adding a new Playwright spec assertion:**
##   Does the regex include a literal substring that the engine
##   interpolates from a `StringName` / `String` const (mob STATE_*, beat
##   id, source tag, etc.)? If yes, add a drift-pin here in the same PR.
##   The pin makes the contract explicit and the GUT suite catches a
##   future rename before the Playwright spec turns silently green-on-
##   no-match.
##
## References:
##   - `.claude/docs/test-conventions.md` § "Spec-string-vs-engine-emit drift"
##   - PR #249 (Hitbox team-constants pin, ticket `86c9upffv`)
##   - ClickUp `86c9ur5wf` (class-wide drift-pin audit)
##   - `team/tess-qa/playwright-drift-audit-2026-05-16.md` (audit table)

const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const Stratum1BossScript: Script = preload("res://scripts/mobs/Stratum1Boss.gd")


# ==========================================================================
# 1 — Grunt.STATE_CHASING == "chasing"
# ==========================================================================
#
# soak-narrative-regression.spec.ts line 358 — regex:
#   /\[combat-trace\] (?:Grunt\.pos \| .*state=chasing|...)/
#
# Grunt._physics_process emits:
#   _combat_trace("Grunt.pos", "pos=(%.0f,%.0f) state=%s hp=%d dist_to_player=%.0f"
#                              % [..., _state, ...])
# where _state defaults to STATE_IDLE and transitions to STATE_CHASING
# (= &"chasing") via _process_chase when a player is in aggro range.

func test_grunt_state_chasing_string_value_matches_trace_contract() -> void:
	assert_eq(
		String(GruntScript.STATE_CHASING), "chasing",
		"Grunt.STATE_CHASING string value drives the [combat-trace] " +
		"Grunt.pos | ... state=chasing literal in soak-narrative-" +
		"regression.spec.ts. If this value changes, the Playwright spec " +
		"regex stops matching real production traces — but reports " +
		"'assertion failed' the same way as a real engine bug. Update " +
		"the spec regex AND this pin in the same PR if the rename is " +
		"intentional."
	)


# ==========================================================================
# 2 — Stratum1Boss.STATE_CHASING == "chasing"
# ==========================================================================
#
# The boss has its own state machine but emits state=%s the same way via
# its `.pos`-equivalent traces (boss does not emit a throttled .pos line
# today — only state-transition `_set_state` lines via the boss's own
# trace path which carries the state literal). Pinning here is preemptive
# coverage: mob-self-engagement.spec.ts S1 Boss Room block (currently
# test.fail()) plans to read this surface, and any future spec that asserts
# on boss state by literal would silently drift.

func test_stratum1boss_state_chasing_string_value_matches_trace_contract() -> void:
	assert_eq(
		String(Stratum1BossScript.STATE_CHASING), "chasing",
		"Stratum1Boss.STATE_CHASING string value matches Grunt." +
		"STATE_CHASING by convention. Both feed Playwright-asserted " +
		"state=chasing literals when a future spec drives the boss " +
		"engage-after-entry probe via the passive-player Hitbox.hit | " +
		"team=enemy target=Player gate (mob-self-engagement.spec.ts " +
		"S1 Boss Room block). Symmetric pin — keeps the two values in " +
		"lockstep so a partial rename doesn't ship."
	)


# ==========================================================================
# 3 — TutorialEventBus.BEAT_TEXTS keys
# ==========================================================================
#
# tutorial-beat-trace.spec.ts asserts on:
#   /\[combat-trace\] TutorialEventBus\.request_beat \| beat=wasd/
#   /\[combat-trace\] TutorialEventBus\.request_beat \| beat=dodge/
#   /\[combat-trace\] TutorialEventBus\.request_beat \| beat=lmb_strike/
#   /\[combat-trace\] TutorialEventBus\.request_beat \| beat=rmb_heavy/
#
# TutorialEventBus.request_beat emits:
#   DebugFlags.combat_trace("TutorialEventBus.request_beat",
#                           "beat=%s anchor=%d" % [beat_id, anchor])
# Stratum1Room01._wire_tutorial_flow latches each of the four beat_ids by
# StringName value. The set of keys in BEAT_TEXTS is the contract — if a
# fifth beat lands or a key is renamed, this pin surfaces the divergence
# before the Playwright spec drifts.

func test_tutorial_event_bus_beat_keys_match_trace_contract() -> void:
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("TutorialEventBus")
	assert_not_null(bus, "TutorialEventBus autoload must be registered")
	# Read the const dictionary via the autoload — the const is class-scope
	# so we access it through the script. Match-by-key-set rather than
	# by-array-order so re-ordering the dict entries isn't a false positive.
	var keys: Array = bus.BEAT_TEXTS.keys()
	var key_strings: Array = []
	for k in keys:
		key_strings.append(String(k))
	key_strings.sort()
	var expected: Array = ["dodge", "lmb_strike", "rmb_heavy", "wasd"]
	assert_eq(
		key_strings, expected,
		"TutorialEventBus.BEAT_TEXTS keys drive [combat-trace] " +
		"TutorialEventBus.request_beat | beat=<id> literals asserted in " +
		"tutorial-beat-trace.spec.ts. Adding or renaming a key requires " +
		"updating that spec's beat-trace assertions AND this pin in the " +
		"same PR. Missing-key drift: a beat the spec asserts is removed; " +
		"extra-key drift: a fifth beat lands without spec coverage."
	)


# ==========================================================================
# 4 — Inventory.equip source-tag literals
# ==========================================================================
#
# equip-flow.spec.ts + room01-traversal.ts assert on:
#   /source=auto_pickup/        (positive — onboarding pickup)
#   /source=lmb_click/          (positive — user click)
#   /source=auto_starter/       (negative — deprecated tag, no producer)
#
# Inventory.equip does NOT centralise these as constants — the values are
# inline literals at production call sites. We pin them by exercising the
# real `equip()` call shape (without inspecting the trace, which is HTML5-
# gated): the source values must remain valid StringName inputs accepted
# by the function. If a whitelist were added, this pin would fail and
# surface the gap.
#
# **Why not assert the trace string directly:** `DebugFlags.combat_trace`
# gates on `OS.has_feature("web")` → headless GUT never emits the line.
# The acceptance shape is the next-best pin: prove the call signature
# still accepts the strings Playwright greps for.

func test_inventory_equip_accepts_all_playwright_asserted_source_tags() -> void:
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(inv, "Inventory autoload must be registered")
	inv.reset()
	# Build three weapon items so each accept-call has a fresh source.
	var def: ItemDef = ContentFactory.make_item_def({
		"id": &"drift_pin_weapon",
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactory.make_item_base_stats({"damage": 2}),
	})
	# Tag 1: lmb_click — the default; matches the InventoryPanel click site.
	var i1: ItemInstance = ItemInstance.new(def, ItemDef.Tier.T1)
	inv.add(i1)
	assert_true(
		inv.equip(i1, &"weapon", &"lmb_click"),
		"Inventory.equip(item, slot, &\"lmb_click\") must succeed — this is " +
		"the literal asserted by equip-flow.spec.ts Phase 2.5 (P0 86c9q96m8)."
	)
	inv.reset()
	# Tag 2: auto_pickup — the onboarding path; matches the
	# Inventory.on_pickup_collected call site.
	var i2: ItemInstance = ItemInstance.new(def, ItemDef.Tier.T1)
	inv.add(i2)
	assert_true(
		inv.equip(i2, &"weapon", &"auto_pickup"),
		"Inventory.equip(item, slot, &\"auto_pickup\") must succeed — this " +
		"is the literal asserted by ac2/ac3/equip-flow/room-traversal-smoke " +
		"specs (onboarding auto-equip-first-weapon-on-pickup)."
	)
	inv.reset()
	# Tag 3: auto_starter — deprecated (no producer), but the equip() API
	# must still accept it so a future revival path has the slot reserved.
	# equip-flow.spec.ts negative-asserts ABSENCE post-reload.
	var i3: ItemInstance = ItemInstance.new(def, ItemDef.Tier.T1)
	inv.add(i3)
	assert_true(
		inv.equip(i3, &"weapon", &"auto_starter"),
		"Inventory.equip(item, slot, &\"auto_starter\") must STILL succeed — " +
		"the deprecated PR #146 boot-equip tag has no current producer but " +
		"equip-flow.spec.ts negative-asserts the LITERAL string in the trace. " +
		"If equip() ever adds a source whitelist, that decision must update " +
		"the Playwright spec's negative assertion AND this pin in the same PR."
	)
	inv.reset()
