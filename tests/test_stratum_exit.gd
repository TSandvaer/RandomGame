extends GutTest
## Unit + integration tests for `scripts/levels/StratumExit.gd` and its
## packed scene. Drew run-006 task spec (`86c9kxx6z`):
##
##   1. Spawned, exit is INACTIVE (no interaction prompt visible).
##   2. After `boss_died` signal, exit transitions to ACTIVE
##      (prompt visible, area collision enabled).
##   3. Player overlap + interact key fires `descend_triggered` signal.
##   4. Edge: rapid interaction spam doesn't double-fire.
##   5. Edge: exit not active before boss death — player overlap does nothing.
##
## Plus integration with `Stratum1BossRoom` so the boss-died → exit-active
## wiring is end-to-end-asserted (the room's existing test file covers the
## boss-died emit; this file covers the exit-side handling).

const ExitScript: Script = preload("res://scripts/levels/StratumExit.gd")
const BossRoomScript: Script = preload("res://scripts/levels/Stratum1BossRoom.gd")


# ---- Helpers ----------------------------------------------------------

func _make_exit() -> StratumExit:
	var packed: PackedScene = load("res://scenes/levels/StratumExit.tscn")
	var exit: StratumExit = packed.instantiate()
	add_child_autofree(exit)
	return exit


## Instantiates the boss room and drains one frame so the deferred
## `_assemble_room_fixtures` pass (ticket 86c9tv8uf physics-flush fix) has
## landed — the StratumExit + door trigger are built there, not in `_ready`.
## Callers must `await _make_room()`.
func _make_room() -> Stratum1BossRoom:
	var packed: PackedScene = load("res://scenes/levels/Stratum1BossRoom.tscn")
	var room: Stratum1BossRoom = packed.instantiate()
	add_child_autofree(room)
	await get_tree().process_frame
	return room


# ---- Spec test 1: scene loads + spawns inactive ----------------------

func test_stratum_exit_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/levels/StratumExit.tscn")
	assert_not_null(packed, "StratumExit.tscn must load")
	var instance: Node = packed.instantiate()
	assert_true(instance is StratumExit, "root is StratumExit typed")
	instance.free()


func test_exit_starts_inactive() -> void:
	var exit: StratumExit = _make_exit()
	assert_false(exit.is_active(), "exit starts INACTIVE on spawn")
	assert_false(exit.is_descend_triggered(), "descend has not fired on spawn")
	assert_false(exit.is_player_in_range(), "no player in range on spawn")


func test_inactive_exit_has_no_visible_prompt() -> void:
	var exit: StratumExit = _make_exit()
	var prompt: Label = exit.get_prompt_label()
	assert_not_null(prompt, "prompt label exists in scene")
	assert_false(prompt.visible, "prompt is hidden while exit is INACTIVE")


func test_inactive_exit_has_disabled_area_collision() -> void:
	var exit: StratumExit = _make_exit()
	var area: Area2D = exit.get_interaction_area()
	assert_not_null(area, "interaction Area2D exists")
	assert_false(area.monitoring, "Area2D monitoring OFF while INACTIVE")
	assert_false(area.monitorable, "Area2D monitorable OFF while INACTIVE")


# ---- Spec test 2: activate() flips to ACTIVE -------------------------

func test_activate_flips_to_active_state() -> void:
	var exit: StratumExit = _make_exit()
	watch_signals(exit)
	exit.activate()
	assert_true(exit.is_active(), "exit is ACTIVE after activate()")
	assert_signal_emitted(exit, "exit_activated")


func test_active_exit_enables_area_collision() -> void:
	var exit: StratumExit = _make_exit()
	exit.activate()
	var area: Area2D = exit.get_interaction_area()
	assert_true(area.monitoring, "Area2D monitoring ON while ACTIVE")
	assert_true(area.monitorable, "Area2D monitorable ON while ACTIVE")


func test_active_exit_shows_prompt_when_player_in_range() -> void:
	var exit: StratumExit = _make_exit()
	exit.activate()
	exit.set_player_overlap_for_test(true)
	var prompt: Label = exit.get_prompt_label()
	assert_true(prompt.visible, "prompt visible when active + player in range")


func test_active_exit_hides_prompt_when_player_out_of_range() -> void:
	var exit: StratumExit = _make_exit()
	exit.activate()
	exit.set_player_overlap_for_test(false)
	var prompt: Label = exit.get_prompt_label()
	assert_false(prompt.visible, "prompt hidden when active but no player in range")


func test_activate_is_idempotent() -> void:
	# Calling activate() multiple times must only emit `exit_activated` once
	# (defensive — if Stratum1BossRoom wires it twice we don't double-fire).
	var exit: StratumExit = _make_exit()
	watch_signals(exit)
	exit.activate()
	exit.activate()
	exit.activate()
	assert_signal_emit_count(exit, "exit_activated", 1,
		"exit_activated emits exactly once even with repeated activate() calls")


# ---- Spec test 3: overlap + interact fires descend_triggered ---------

func test_player_overlap_and_interact_fires_descend() -> void:
	var exit: StratumExit = _make_exit()
	watch_signals(exit)
	exit.activate()
	exit.set_player_overlap_for_test(true)
	var fired: bool = exit.try_interact()
	assert_true(fired, "try_interact returns true when active + in range")
	assert_signal_emitted(exit, "descend_triggered")
	assert_true(exit.is_descend_triggered(), "descend_triggered state is set")


func test_descend_hides_prompt_after_firing() -> void:
	var exit: StratumExit = _make_exit()
	exit.activate()
	exit.set_player_overlap_for_test(true)
	var prompt: Label = exit.get_prompt_label()
	assert_true(prompt.visible, "prompt visible before interact")
	exit.try_interact()
	assert_false(prompt.visible, "prompt hidden after interact fires descend")


# ---- Spec test 4: rapid interaction spam doesn't double-fire ---------

func test_rapid_interact_spam_fires_descend_exactly_once() -> void:
	var exit: StratumExit = _make_exit()
	watch_signals(exit)
	exit.activate()
	exit.set_player_overlap_for_test(true)
	var first: bool = exit.try_interact()
	var second: bool = exit.try_interact()
	var third: bool = exit.try_interact()
	assert_true(first, "first interact succeeds")
	assert_false(second, "second interact returns false (already fired)")
	assert_false(third, "third interact returns false (already fired)")
	assert_signal_emit_count(exit, "descend_triggered", 1,
		"descend_triggered emits exactly once even under rapid mash")


# ---- Spec test 5: inactive exit ignores overlap+interact -------------

func test_inactive_exit_overlap_does_nothing() -> void:
	var exit: StratumExit = _make_exit()
	watch_signals(exit)
	# DO NOT call activate(). Player walks in.
	exit.set_player_overlap_for_test(true)
	var prompt: Label = exit.get_prompt_label()
	assert_false(prompt.visible, "prompt stays hidden while INACTIVE even with overlap")
	# Player tries to interact — should be a no-op.
	var fired: bool = exit.try_interact()
	assert_false(fired, "try_interact returns false on INACTIVE exit")
	assert_signal_emit_count(exit, "descend_triggered", 0,
		"no descend_triggered emit on INACTIVE exit")


func test_overlap_without_active_then_activate_then_interact() -> void:
	# A common real flow: player wandered into the empty arena spot before
	# killing the boss. After the boss dies, activate() flips on, and the
	# pre-existing overlap state means the prompt appears immediately.
	var exit: StratumExit = _make_exit()
	exit.set_player_overlap_for_test(true)
	# Still inactive — no prompt, no signal.
	assert_false(exit.get_prompt_label().visible)
	# Boss dies → activate.
	watch_signals(exit)
	exit.activate()
	assert_true(exit.get_prompt_label().visible,
		"prompt appears the moment activate() runs if player already in range")
	exit.try_interact()
	assert_signal_emitted(exit, "descend_triggered")


# ---- Bounds + content sanity -----------------------------------------

func test_exit_position_applies_to_node() -> void:
	# Default scene authoring places portal at (240, 70).
	var exit: StratumExit = _make_exit()
	assert_almost_eq(exit.position.x, 240.0, 0.001)
	assert_almost_eq(exit.position.y, 70.0, 0.001)


func test_active_state_swaps_portal_color() -> void:
	var exit: StratumExit = _make_exit()
	# Find the portal visual ColorRect.
	var visual: ColorRect = exit.get_node_or_null("PortalVisual") as ColorRect
	assert_not_null(visual, "portal visual ColorRect exists")
	var inactive_color: Color = visual.color
	exit.activate()
	var active_color: Color = visual.color
	assert_ne(inactive_color, active_color,
		"portal color changes between INACTIVE and ACTIVE")
	assert_almost_eq(active_color.r, StratumExit.PORTAL_COLOR_ACTIVE.r, 0.01)
	assert_almost_eq(active_color.g, StratumExit.PORTAL_COLOR_ACTIVE.g, 0.01)


func test_interaction_area_collision_mask_targets_player() -> void:
	# Per DECISIONS.md 2026-05-01 physics-layers-reserved: layer 2 = player.
	# The exit's interaction area must mask layer 2.
	var exit: StratumExit = _make_exit()
	var area: Area2D = exit.get_interaction_area()
	assert_eq(area.collision_mask, 1 << 1,
		"interaction area masks player layer (bit 2) only")
	assert_eq(area.collision_layer, 0,
		"interaction area sits on no layer (passive trigger)")


# ---- Integration with Stratum1BossRoom -------------------------------

func test_room_spawns_stratum_exit_inactive() -> void:
	var room: Stratum1BossRoom = await _make_room()
	assert_not_null(room.get_stratum_exit(),
		"Stratum1BossRoom spawns a StratumExit child on _ready")
	var exit: StratumExit = room.get_stratum_exit()
	assert_false(exit.is_active(), "exit starts INACTIVE — boss not yet dead")


func test_room_activates_exit_on_boss_death() -> void:
	var room: Stratum1BossRoom = await _make_room()
	var boss: Stratum1Boss = room.get_boss()
	var exit: StratumExit = room.get_stratum_exit()
	assert_false(exit.is_active(), "precondition: exit inactive before boss death")
	# Run through the boss kill path the same way test_stratum1_boss_room.gd does.
	room.trigger_entry_sequence()
	room.complete_entry_sequence_for_test()
	boss.take_damage(204, Vector2.ZERO, null)  # 600 → 396 (phase 2 trigger)
	boss._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	boss.take_damage(198, Vector2.ZERO, null)  # 396 → 198 (phase 3 trigger)
	boss._physics_process(Stratum1Boss.PHASE_TRANSITION_DURATION + 0.01)
	boss.take_damage(198, Vector2.ZERO, null)  # 198 → 0 (death)
	assert_true(boss.is_dead())
	# REGRESSION-86c9ujq8d: StratumExit.activate() is now called via
	# call_deferred() from _on_boss_died to avoid the physics-flush ERR_FAIL_COND.
	# Drain one process frame so the deferred activate() lands before asserting.
	await get_tree().process_frame
	assert_true(exit.is_active(),
		"exit ACTIVE after boss_died propagates through room → exit.activate()")


func test_room_exit_position_within_arena() -> void:
	# Default exit placement at (240, 30) is inside the 480x270 arena and
	# at the "top" — opposite the door trigger at (240, 250). Player walks
	# deeper to descend. Sanity-check the bounds.
	var room: Stratum1BossRoom = await _make_room()
	var exit: StratumExit = room.get_stratum_exit()
	assert_gte(exit.position.x, 0.0)
	assert_lt(exit.position.x, 480.0)
	assert_gte(exit.position.y, 0.0)
	assert_lt(exit.position.y, 270.0)


# ---- REGRESSION-86c9un4nh: knockback-overlap fix for activate() ----------
#
# Finding 3 (M2 W3 re-soak) — player standing inside exit area when
# activate() runs. Body_entered never fires for pre-existing overlaps in
# Godot 4; _player_in_range stays false; prompt never shows; E key does
# nothing; player trapped.
#
# Fix: activate() calls get_overlapping_bodies() after monitoring turns on
# and fires _on_body_entered via call_deferred if a CharacterBody2D is
# already inside. Same shape as RoomGate._unlock() → _fire_traversal_if_unlocked
# (PR #230 knockback-overlap fix).
#
# NOTE: headless GUT cannot drive real Area2D physics overlaps —
# get_overlapping_bodies() returns [] without a physics server. These tests
# use set_player_overlap_for_test to simulate the pre-existing overlap STATE
# that the production path delivers via body_entered (or the re-check's
# deferred _on_body_entered call). The HTML5 release-build Playwright spec
# and Sponsor soak verify the real Area2D physics path.
#
# State-machine regression pinned:
#   - Player was "inside" at activate() time (overlap state true)
#     → prompt shows immediately after activate()
#     → try_interact() succeeds
#   - Player was NOT inside at activate() time (no overlap)
#     → prompt stays hidden after activate()
#     → try_interact() returns false

func test_activate_with_pre_existing_player_overlap_shows_prompt_and_allows_interact() -> void:
	# **REGRESSION-86c9un4nh** — the Sponsor scenario: player walked to the
	# exit portal while the boss was alive (area inactive, body_entered never
	# fired). Boss dies → call_deferred("activate") lands. At that moment the
	# player is already standing on the exit. Without the fix, _player_in_range
	# stays false; press-E does nothing. With the fix, activate() detects the
	# pre-existing overlap and fires body_entered deferred → _player_in_range = true.
	#
	# Simulation: set_player_overlap_for_test injects the overlap state that the
	# production fix's deferred _on_body_entered call produces. The prompt must
	# show immediately after activate() and try_interact() must succeed.
	var exit: StratumExit = _make_exit()
	watch_signals(exit)
	# Player walked into the exit area while boss was alive — area inactive.
	# body_entered never fired (monitoring was off). Set overlap state directly
	# (simulates the deferred _on_body_entered call result from the fix).
	exit.set_player_overlap_for_test(true)
	assert_false(exit.get_prompt_label().visible,
		"precondition: prompt hidden on inactive exit even with player standing inside")
	# Boss dies → call_deferred("activate") fires one frame later.
	exit.activate()
	assert_true(exit.is_active(),
		"REGRESSION-86c9un4nh: exit active after activate()")
	assert_true(exit.is_player_in_range(),
		"REGRESSION-86c9un4nh: _player_in_range true when player was overlapping at activate() time")
	assert_true(exit.get_prompt_label().visible,
		"REGRESSION-86c9un4nh: prompt visible immediately when player was in area at activate() time " +
		"(pre-existing overlap re-check in activate() surfaces the standing player)")
	# Player presses E — must fire descend_triggered.
	var fired: bool = exit.try_interact()
	assert_true(fired,
		"REGRESSION-86c9un4nh: try_interact succeeds when player was inside at activate() time")
	assert_signal_emitted(exit, "descend_triggered",
		"REGRESSION-86c9un4nh: descend_triggered fires — player can exit boss room")


func test_activate_without_pre_existing_overlap_prompt_stays_hidden() -> void:
	# Complementary to the above: normal post-boss-death flow. Player walks
	# to the exit AFTER it activates. Prompt is hidden until body_entered fires.
	var exit: StratumExit = _make_exit()
	exit.activate()
	assert_true(exit.is_active(), "exit active")
	assert_false(exit.is_player_in_range(),
		"REGRESSION-86c9un4nh: _player_in_range false when no body overlapping at activate()")
	assert_false(exit.get_prompt_label().visible,
		"REGRESSION-86c9un4nh: prompt hidden until player walks into area after activation")
	# Player walks in after activation.
	exit.set_player_overlap_for_test(true)
	assert_true(exit.get_prompt_label().visible,
		"prompt shows once player enters active exit area")
	assert_true(exit.try_interact(), "try_interact succeeds")


func test_activate_idempotent_with_pre_existing_overlap() -> void:
	# Edge: calling activate() twice with player inside must not double-fire
	# the body_entered deferred or emit exit_activated twice.
	var exit: StratumExit = _make_exit()
	watch_signals(exit)
	exit.set_player_overlap_for_test(true)
	exit.activate()
	exit.activate()  # second call must be a no-op
	assert_signal_emit_count(exit, "exit_activated", 1,
		"REGRESSION-86c9un4nh: exit_activated emits exactly once even with repeated activate() + overlap")
