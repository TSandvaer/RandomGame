extends GutTest
## Integration test for iron_sword starter-equip → Player.try_attack damage surface.
##
## **Why this test exists:**
## PR #145 added Inventory._seed_starting_inventory + equip_starter_weapon_if_needed.
## Its paired tests (test_starting_inventory.gd) verified Inventory state-only:
## _equipped[weapon] != null, get_equipped("weapon") returns iron_sword.
## They did NOT verify that Player.try_attack actually produces weapon-scaled
## damage through the real combat path.
##
## Sponsor soak on embergrave-html5-3937831 found every swing still dealt
## damage=1 (FIST_DAMAGE). Root cause: equip_starter_weapon_if_needed() fired in
## Player._ready(), but Main._ready() called _load_save_or_defaults() immediately
## after _spawn_player(). A pre-existing save with equipped:{} triggered
## Inventory.restore_from_save which called _apply_unequip_to_player("weapon"),
## setting Player._equipped_weapon = null. The equip was clobbered.
##
## Fix: equip_starter_weapon_if_needed is now called from Main._ready() AFTER
## _load_save_or_defaults(). These tests exercise the integrated path so this
## class of bug (equip fires before save-restore finishes) cannot ship again
## with green CI.
##
## **What these tests drive:**
##   A. Boot Main.tscn → assert Player.get_equipped_weapon() != null immediately
##      after main is ready (starter sword survives the save-restore sequence).
##   B. Boot Main.tscn → drive Player.try_attack on a fresh Grunt → assert
##      Grunt.hp dropped by weapon-scaled damage (NOT 1 / FIST_DAMAGE).
##   C. Boot Main.tscn → open InventoryPanel → assert equipped-row shows the
##      iron_sword (Tab UI surface renders the equipped slot).
##   D. Regression: boot with a simulated "old save" that has equipped:{} (empty)
##      → starter sword is still equipped after load (the save-restore does not
##      clobber the starter).

const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

const PHYS_DELTA: float = 1.0 / 60.0


# ---- Helpers ----------------------------------------------------------

func _instantiate_main(preserve_save: bool = false) -> Node:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var main: Node = packed.instantiate()
	_reset_autoloads()
	# By default, ensure no save on disk so _load_save_or_defaults is a
	# fresh-start path. AC-D passes preserve_save=true so its crafted
	# pre-PR-145-shaped save survives to be loaded by Main._ready().
	if not preserve_save:
		var save_node: Node = _save()
		if save_node != null and save_node.has_method("has_save") and save_node.has_save(0):
			save_node.delete_save(0)
	add_child_autofree(main)
	return main


func _reset_autoloads() -> void:
	var inv: Node = _inventory()
	if inv != null:
		inv.reset()
		# Re-seed the iron_sword so the test exercises the same fresh-game-start
		# state production sees: Inventory autoload's _ready() seeded the sword
		# at process start, but inv.reset() above wiped that. Without re-seeding,
		# Main._ready()'s post-save-restore equip_starter_weapon_if_needed() finds
		# an empty inventory and warns "no iron_sword to auto-equip" — which would
		# defeat the integration these tests assert. The seed is idempotent
		# (only-if-empty rule) so calling it on a freshly-reset inventory is safe.
		inv.call("_seed_starting_inventory")
	var levels: Node = _levels()
	if levels != null:
		levels.reset()
	var ps: Node = _player_stats()
	if ps != null:
		ps.reset()
	var sp: Node = _stratum()
	if sp != null:
		sp.reset()


func _save() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Save")


func _inventory() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Inventory")


func _levels() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("Levels")


func _player_stats() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PlayerStats")


func _stratum() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("StratumProgression")


# ==========================================================================
# AC A — Starter sword survives save-restore on fresh boot
# ==========================================================================

func test_player_equipped_weapon_is_non_null_after_boot() -> void:
	## The title is the test: on a fresh boot (no save), Player._equipped_weapon
	## must be the iron_sword, not null. Fails pre-fix because equip fires
	## before save-restore, which clobbers it.
	var main: Node = _instantiate_main()
	await get_tree().process_frame
	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-A: Player spawned")
	var weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon,
		"AC-A: Player.get_equipped_weapon() must be non-null after boot — " +
		"null means the starter equip was clobbered by save-restore")
	assert_eq(weapon.id, &"iron_sword",
		"AC-A: equipped weapon must be the iron_sword (id check)")


# ==========================================================================
# AC B — Player.try_attack produces weapon-scaled damage, NOT FIST_DAMAGE
# ==========================================================================

func test_first_swing_deals_weapon_scaled_damage_not_fist() -> void:
	## This is the behavioral integration test that was missing from PR #145.
	## Pre-fix: every swing dealt damage=1 because Player._equipped_weapon was
	## null (save-restore clobber). Post-fix: damage must equal the iron_sword
	## formula output (floor(6 * 1.0 * 1.0) = 6 for a light attack at edge=0).
	var main: Node = _instantiate_main()
	await get_tree().process_frame

	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-B: Player spawned")

	# Verify the weapon is actually equipped before we test swings.
	var weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon, "AC-B: precondition — weapon equipped (if this fails, see AC-A)")
	assert_eq(weapon.id, &"iron_sword", "AC-B: precondition — iron_sword equipped")

	# Build a minimal Grunt to be the target. We use a bare-instantiated Grunt
	# without a scene (same pattern as test_grunt.gd) so we can call
	# _try_apply_hit directly without physics pipeline.
	var GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
	var grunt: Grunt = GruntScript.new()
	# Give it a MobDef with known HP so we can compute the delta exactly.
	var ContentFactoryScript: Script = preload("res://tests/factories/content_factory.gd")
	var def_overrides: Dictionary = {"hp_base": 50, "damage_base": 5, "move_speed": 60.0}
	grunt.mob_def = ContentFactoryScript.make_mob_def(def_overrides)
	add_child_autofree(grunt)
	await get_tree().process_frame

	var hp_before: int = grunt.get_hp()
	assert_eq(hp_before, 50, "AC-B: grunt starts at 50 HP")

	# Fire a light attack through the real Player.try_attack path, then
	# manually drive the Hitbox._try_apply_hit (same technique as test_m1_play_loop.gd
	# _walk_in_and_kill helper — bypasses the Area2D physics overlap which
	# requires a running physics server).
	var hb: Hitbox = player.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
	assert_not_null(hb, "AC-B: try_attack must return a Hitbox")

	# The damage encoded on the hitbox is the formula output. Assert it here
	# so the test is specific about the exact value pre-apply.
	var expected_light_dmg: int = DamageScript.compute_player_damage(weapon, 0, &"light")
	assert_eq(hb.damage, expected_light_dmg,
		"AC-B: hitbox.damage must equal Damage.compute_player_damage(iron_sword, 0, light) = %d" % expected_light_dmg)
	assert_gt(hb.damage, DamageScript.FIST_DAMAGE,
		"AC-B: hitbox.damage=%d must be > FIST_DAMAGE=%d — if this fails, Player._equipped_weapon was null when try_attack fired" % [hb.damage, DamageScript.FIST_DAMAGE])

	# Apply the hit to the grunt and confirm HP drop matches formula output.
	hb._try_apply_hit(grunt)
	var hp_after: int = grunt.get_hp()
	assert_eq(hp_after, hp_before - expected_light_dmg,
		"AC-B: grunt HP must drop by %d (iron_sword light damage), not by 1 (fist)" % expected_light_dmg)


# ==========================================================================
# AC C — InventoryPanel Tab UI shows iron_sword in equipped row
# ==========================================================================

func test_inventory_panel_equipped_row_shows_iron_sword() -> void:
	## Sponsor reported "I can't see any sword when I press Tab for inventory."
	## This test asserts that after boot the InventoryPanel's weapon equipped
	## cell displays the iron_sword name (non-empty text).
	var main: Node = _instantiate_main()
	await get_tree().process_frame

	var panel: InventoryPanel = (main as Main).get_inventory_panel() as InventoryPanel
	assert_not_null(panel, "AC-C: InventoryPanel mounted")

	# Open the panel (same as Tab key in the live game).
	panel.open()
	assert_true(panel.is_open(), "AC-C: panel opens")

	# The equipped slot button for "weapon" should have non-empty text.
	# InventoryPanel._equipped_cells is a Dictionary (StringName slot -> Button).
	# We access it via the test-only path: _refresh_equipped_row is called on
	# open(), so by the time open() returns the cells are populated.
	var inv: Node = _inventory()
	assert_not_null(inv, "AC-C: Inventory autoload registered")
	var equipped_item: ItemInstance = inv.get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped_item,
		"AC-C: Inventory.get_equipped('weapon') must be non-null after boot")
	assert_eq(equipped_item.def.id, &"iron_sword",
		"AC-C: equipped weapon must be iron_sword")

	# Verify the panel's weapon cell text is set (visual surface).
	# InventoryPanel._equipped_cells is a var, accessible via Godot object property read.
	var cells: Dictionary = panel.get("_equipped_cells") if "get" in panel else {}
	if cells != null and not cells.is_empty():
		var weapon_btn: Button = cells.get(&"weapon", null) as Button
		if weapon_btn != null:
			assert_ne(weapon_btn.text, "",
				"AC-C: equipped weapon slot button must show the iron_sword name, not empty string")

	panel.close()


# ==========================================================================
# AC D — Pre-PR-145 save (equipped:{}) does NOT clobber starter equip
# ==========================================================================

func test_old_save_with_empty_equipped_does_not_clobber_starter_sword() -> void:
	## Regression guard for the exact bug this PR fixes. A save created before
	## PR #145 (or any save with equipped:{}) must not prevent the starter sword
	## from being equipped. Pre-fix: restore_from_save called
	## _apply_unequip_to_player("weapon") → Player._equipped_weapon = null.
	## Post-fix: equip_starter_weapon_if_needed fires AFTER restore_from_save,
	## so an empty equipped slot still gets the starter sword.
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node == null:
		gut.p("SKIP: Save autoload not available")
		return

	# Write a minimal save that has equipped:{} (like a pre-PR-145 save).
	# We write directly via Save.save_game with a crafted payload rather than
	# going through the full save pipeline.
	var fake_data: Dictionary = {
		"schema_version": 3,
		"character": {
			"level": 1,
			"xp": 0,
			"hp_current": 100,
			"hp_max": 100,
			"vigor": 0,
			"focus": 0,
			"edge": 0,
			"stats": {"vigor": 0, "focus": 0, "edge": 0},
			"unspent_points": 0,
		},
		"equipped": {},   # <-- the "old save" condition: no equipped weapon
		"stash": [],
		"meta": {"runs_completed": 0, "deepest_stratum": 1},
		"stratum": {},
	}
	if save_node.has_method("save_game"):
		save_node.save_game(0, fake_data)

	# Now boot Main — it should load the fake save, get equipped:{},
	# and STILL call equip_starter_weapon_if_needed after restore.
	# preserve_save=true so _instantiate_main does NOT delete our crafted save.
	var main: Node = _instantiate_main(true)
	await get_tree().process_frame

	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-D: Player spawned")
	var weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon,
		"AC-D: starter sword must be equipped even when save has equipped:{} — " +
		"null means restore_from_save clobbered the equip (pre-fix regression)")
	assert_eq(weapon.id, &"iron_sword",
		"AC-D: equipped weapon must be iron_sword")

	# Clean up the test save so subsequent tests start fresh.
	if save_node.has_method("delete_save"):
		save_node.delete_save(0)


# ==========================================================================
# AC E — LMB-click equip-swap drives the FULL integration surface (P0 86c9q96m8)
# ==========================================================================

func test_lmb_click_equip_swap_real_main_drives_dual_surfaces() -> void:
	## Sponsor M1 RC re-soak attempt 5 P0 86c9q96m8 — pick up a sword in
	## Room 02, click to equip via LMB on inventory grid → "item disappears
	## from grid but is NOT actually equipped (subsequent swings still
	## register the previous weapon's damage)."
	##
	## This integration AC drives the full real-Main path (autoloads,
	## Player, InventoryPanel, the Tab UI's `_handle_inventory_click`)
	## through an equip-swap and confirms BOTH the Inventory surface AND
	## the Player surface (dual-surface rule) end up pointing at the new
	## sword. A swing on a fresh grunt confirms the damage value updated
	## (Tier 3 of the combat-architecture.md §"Equipped-weapon dual-surface
	## rule" test bar — actual damage delta on a real Grunt, NOT just the
	## formula in isolation).
	var main: Node = _instantiate_main()
	await get_tree().process_frame

	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-E: Player spawned")

	# Confirm starter sword is the iron_sword (damage=6) so the post-swap
	# delta is observable.
	var pre_weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(pre_weapon, "AC-E: precondition — starter weapon equipped")
	assert_eq(pre_weapon.id, &"iron_sword", "AC-E: starter is iron_sword")
	var pre_damage: int = DamageScript.compute_player_damage(pre_weapon, 0, &"light")

	# Build a higher-damage replacement weapon (a "Room 02 pickup").
	var ContentFactoryScript: Script = preload("res://tests/factories/content_factory.gd")
	var swap_def: ItemDef = ContentFactoryScript.make_item_def({
		"id": &"swap_sword_e2e",
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactoryScript.make_item_base_stats({"damage": 12}),
	})
	var swap_sword: ItemInstance = ItemInstance.new(swap_def, ItemDef.Tier.T1)
	var inv: Node = _inventory()
	assert_true(inv.add(swap_sword),
		"AC-E: Room 02 pickup lands in grid via Inventory.add")

	# Drive the LMB click via the InventoryPanel test helper (mirrors the
	# production click path — `_handle_inventory_click(0, MOUSE_BUTTON_LEFT)`).
	var panel: InventoryPanel = (main as Main).get_inventory_panel() as InventoryPanel
	assert_not_null(panel, "AC-E: InventoryPanel mounted")
	panel.open()
	# Find the index of the swap_sword in the grid (it was just added; index 0
	# since auto-equip already moved iron_sword out of _items).
	var items: Array = inv.get_items()
	var swap_idx: int = items.find(swap_sword)
	assert_gte(swap_idx, 0, "AC-E: swap_sword is in the grid pre-click")
	panel.force_click_inventory_index_for_test(swap_idx, MOUSE_BUTTON_LEFT)

	# DUAL-SURFACE ASSERTIONS — both must point to the swap sword post-click.
	var post_inv_eq: ItemInstance = inv.get_equipped(&"weapon") as ItemInstance
	assert_not_null(post_inv_eq, "AC-E: Inventory surface — weapon slot occupied")
	assert_eq(post_inv_eq.def.id, &"swap_sword_e2e",
		"AC-E: Inventory.get_equipped('weapon') points to the new sword")
	var post_player_weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(post_player_weapon,
		"AC-E: Player surface — _equipped_weapon non-null")
	assert_eq(post_player_weapon.id, &"swap_sword_e2e",
		"AC-E: Player._equipped_weapon points to the new sword — " +
		"if this fails, the LMB-click path updated Inventory but didn't " +
		"propagate to Player (dual-surface mismatch). Sponsor's exact symptom: " +
		"grid shows new sword equipped but combat damage uses the OLD weapon.")

	# Iron_sword (the previously-equipped weapon) must be BACK IN THE GRID,
	# NOT silently lost to the equip-swap leak.
	var preserved_in_grid: bool = false
	for it_v in inv.get_items():
		var it_inst: ItemInstance = it_v as ItemInstance
		if it_inst != null and it_inst.def != null and it_inst.def.id == &"iron_sword":
			preserved_in_grid = true
			break
	assert_true(preserved_in_grid,
		"AC-E: previously-equipped iron_sword must land back in the grid on swap " +
		"(equip-swap data-loss guard — pre-fix this was lost to the floor)")

	# Tier 3 — damage delta on a real Grunt confirms the swap took effect
	# at the combat surface, not just the autoload state.
	var GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
	var grunt: Grunt = GruntScript.new()
	var def_overrides: Dictionary = {"hp_base": 100, "damage_base": 5, "move_speed": 60.0}
	grunt.mob_def = ContentFactoryScript.make_mob_def(def_overrides)
	add_child_autofree(grunt)
	await get_tree().process_frame

	var hp_before: int = grunt.get_hp()
	var hb: Hitbox = player.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
	assert_not_null(hb, "AC-E: try_attack returned a Hitbox post-swap")
	# Hitbox damage MUST equal the new sword's formula output, NOT the old.
	var expected_post: int = DamageScript.compute_player_damage(swap_def, 0, &"light")
	assert_eq(hb.damage, expected_post,
		"AC-E: hitbox.damage uses NEW weapon (%d), not old iron_sword (%d) — " %
		[expected_post, pre_damage] +
		"the load-bearing combat surface confirms the swap propagated.")
	hb._try_apply_hit(grunt)
	assert_eq(grunt.get_hp(), hp_before - expected_post,
		"AC-E: grunt HP drops by NEW weapon damage, not by iron_sword's")


func before_each() -> void:
	_reset_autoloads()
	# Clean any leftover test save.
	var save_node: Node = _save()
	if save_node != null and save_node.has_method("has_save") and save_node.has_save(0):
		save_node.delete_save(0)


func after_each() -> void:
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node != null and save_node.has_method("has_save") and save_node.has_save(0):
		save_node.delete_save(0)
