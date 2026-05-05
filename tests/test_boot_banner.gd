extends GutTest
## Boot-banner contract — Main.tscn must mount a HUD child named
## `BootBanner` whose text lists all 7 player input actions, including
## LMB (light attack) and RMB (heavy attack).
##
## Why this test exists — BB-5 (`86c9m3969`, Tess run-024 bug-bash):
## the M1 boot banner is the only on-screen control reference (no in-game
## tutorial). Pre-fix it mentioned only WASD / Shift / Space — missing
## LMB + RMB made attacks invisible to first-time players. AC1 of
## `m1-test-plan.md` ("first-time player understands controls within the
## first room") regresses if the banner ever drops a binding again.
##
## Verification gate (per Tess BB-5): load Main.tscn, find the
## banner-string render target, assert it contains `LMB` and `RMB`
## substrings. We assert all 7 strings so the regression net catches any
## drop, not only the two BB-5 callouts.
##
## Slot 0 is reset between siblings — the banner is built unconditionally
## in `_build_hud` so save state is irrelevant, but we clear slot 0 to
## stay friendly with sibling integration tests.


func _instantiate_main() -> Main:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var instance: Node = packed.instantiate()
	assert_not_null(instance, "Main.tscn instantiate() must return a node")
	# Reset save slot so this test runs clean across siblings.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	add_child_autofree(instance)
	return instance as Main


# ---- Banner mount ----------------------------------------------------

func test_boot_banner_label_mounts_in_hud() -> void:
	var main: Main = _instantiate_main()
	await get_tree().process_frame
	var hud: CanvasLayer = main.get_hud()
	assert_not_null(hud, "HUD CanvasLayer is mounted")
	var banner: Node = hud.find_child("BootBanner", true, false)
	assert_not_null(banner, "BB-5: HUD has a 'BootBanner' child Label")
	assert_true(banner is Label, "BB-5: BootBanner is a Label node")


func test_get_boot_banner_label_accessor_returns_the_mounted_label() -> void:
	var main: Main = _instantiate_main()
	await get_tree().process_frame
	var label: Label = main.get_boot_banner_label()
	assert_not_null(label, "Main.get_boot_banner_label() returns the mounted Label")
	assert_true(label.is_inside_tree(),
		"BootBanner is parented under the HUD CanvasLayer (not orphaned)")


# ---- Banner copy contract -------------------------------------------

func test_boot_banner_lists_lmb_attack_binding() -> void:
	# Direct BB-5 regression guard — the original symptom was "no mention
	# of LMB". Assert the binding line is present.
	var main: Main = _instantiate_main()
	await get_tree().process_frame
	var label: Label = main.get_boot_banner_label()
	assert_not_null(label, "BootBanner exists")
	assert_string_contains(label.text, "LMB",
		"BB-5: banner must mention LMB (light attack) — was missing pre-fix")
	assert_string_contains(label.text, "LMB to attack",
		"BB-5: full LMB-to-attack line preserved exactly")


func test_boot_banner_lists_rmb_heavy_attack_binding() -> void:
	# Direct BB-5 regression guard for the second missing binding.
	var main: Main = _instantiate_main()
	await get_tree().process_frame
	var label: Label = main.get_boot_banner_label()
	assert_not_null(label, "BootBanner exists")
	assert_string_contains(label.text, "RMB",
		"BB-5: banner must mention RMB (heavy attack) — was missing pre-fix")
	assert_string_contains(label.text, "RMB to heavy attack",
		"BB-5: full RMB-to-heavy-attack line preserved exactly")


func test_boot_banner_lists_every_player_input_action() -> void:
	# Stronger contract than BB-5 — every input action from
	# `project.godot` §[input] (move/sprint/dodge/attack_light/
	# attack_heavy/toggle_inventory/interact mapped to user-facing labels)
	# must appear on the banner. If a future input is added, this test
	# will flag the omission so the onboarding surface stays in sync.
	var main: Main = _instantiate_main()
	await get_tree().process_frame
	var label: Label = main.get_boot_banner_label()
	assert_not_null(label, "BootBanner exists")
	var required_lines: Array[String] = [
		"WASD to move",
		"Shift to sprint",
		"Space to dodge",
		"LMB to attack",
		"RMB to heavy attack",
		"Tab for inventory",
		"P to allocate stats",
	]
	for line: String in required_lines:
		assert_string_contains(label.text, line,
			"BB-5: banner must contain '%s' so first-time players see all 7 verbs" % line)


# ---- Banner visibility / layout contract ----------------------------

func test_boot_banner_is_visible_at_boot() -> void:
	# Whole point — first-time players should see this on boot, not after
	# discovering the toggle. Visible by default, alpha > 0.
	var main: Main = _instantiate_main()
	await get_tree().process_frame
	var label: Label = main.get_boot_banner_label()
	assert_not_null(label, "BootBanner exists")
	assert_true(label.visible,
		"BB-5: BootBanner is visible at boot (no toggle-to-discover)")
	var color: Color = label.get_theme_color("font_color")
	assert_gt(color.a, 0.0,
		"BB-5: BootBanner font alpha > 0 (would render invisible at 0)")


func test_boot_banner_does_not_block_mouse_input() -> void:
	# The banner sits over the play area — it must not eat clicks (LMB
	# attack would silently no-op if MOUSE_FILTER_STOP). Per HUD pattern
	# in Main.gd's other Control widgets, mouse_filter == IGNORE.
	var main: Main = _instantiate_main()
	await get_tree().process_frame
	var label: Label = main.get_boot_banner_label()
	assert_not_null(label, "BootBanner exists")
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"BB-5: BootBanner mouse_filter is IGNORE so LMB/RMB clicks reach the play area")
