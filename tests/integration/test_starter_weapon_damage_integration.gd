extends GutTest
## Integration test for the auto-equip-first-weapon-on-pickup onboarding path
## → Player.try_attack damage surface (ticket 86c9qbb3k).
##
## **Why this test exists / what changed:**
## PR #145 added `Inventory._seed_starting_inventory` + a boot-time
## `equip_starter_weapon_if_needed` auto-equip. PR #146 moved that call after
## save-restore. Both are now RETIRED (ticket 86c9qbb3k) — the design-correct
## onboarding path is **auto-equip the first weapon on pickup**: the Stage-2b
## Room01 PracticeDummy drops an iron_sword, the player walks onto it, and
## `Inventory.on_pickup_collected` adds it to the grid AND auto-equips it
## (first-weapon-only).
##
## This file drives the integration surface that the bandaid used to cover —
## the dual-surface equipped state + the actual `Player.try_attack` damage
## delta on a real Grunt — but through the new pickup path instead of boot.
##
## **What these tests drive:**
##   A. Boot Main.tscn → assert the player boots FISTLESS (no boot-time
##      auto-equip). `Player.get_equipped_weapon()` is null right after boot.
##   B. Boot Main.tscn → drive `Inventory.on_pickup_collected(iron_sword)` (the
##      production pickup hook the dummy-dropped Pickup wires into) → assert
##      `Player.get_equipped_weapon()` is the iron_sword AND `Player.try_attack`
##      produces weapon-scaled damage on a real Grunt (NOT FIST_DAMAGE).
##   C. After the pickup-equip, open InventoryPanel → assert the equipped-row
##      weapon cell shows the iron_sword (Tab UI surface).
##   D. Regression: a save with an equipped iron_sword restores it on boot —
##      the save-restore path is unchanged by the bandaid retirement, and the
##      player ends up equipped from the save (no pickup needed). This is the
##      "returning player" path.
##   E. LMB-click equip-swap drives the FULL dual-surface integration surface
##      (P0 86c9q96m8 — unchanged by this PR, kept as a regression guard).

const DamageScript: Script = preload("res://scripts/combat/Damage.gd")

const PHYS_DELTA: float = 1.0 / 60.0


# ---- Helpers ----------------------------------------------------------

func _instantiate_main(preserve_save: bool = false) -> Node:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var main: Node = packed.instantiate()
	_reset_autoloads()
	# By default, ensure no save on disk so _load_save_or_defaults is a
	# fresh-start path. AC-D passes preserve_save=true so its crafted save
	# survives to be loaded by Main._ready().
	if not preserve_save:
		var save_node: Node = _save()
		if save_node != null and save_node.has_method("has_save") and save_node.has_save(0):
			save_node.delete_save(0)
	add_child_autofree(main)
	return main


func _reset_autoloads() -> void:
	# Bandaid retired (ticket 86c9qbb3k): there is NO _seed_starting_inventory
	# re-seed here any more. A reset Inventory has an empty grid + empty
	# equipped map — exactly the fresh-boot state production sees.
	var inv: Node = _inventory()
	if inv != null:
		inv.reset()
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


func _make_iron_sword_instance() -> ItemInstance:
	var def: ItemDef = load("res://resources/items/weapons/iron_sword.tres") as ItemDef
	assert_not_null(def, "iron_sword.tres must load")
	return ItemInstance.new(def, def.tier)


# ==========================================================================
# AC A — Player boots FISTLESS (no boot-time auto-equip)
# ==========================================================================

func test_player_boots_fistless_no_boot_equip() -> void:
	## With the PR #146 bandaid retired, Main._ready does NOT auto-equip a
	## starter weapon. On a fresh boot (no save), the player is fistless until
	## they pick up the iron_sword the Room01 dummy drops.
	var main: Node = _instantiate_main()
	await get_tree().process_frame
	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-A: Player spawned")
	var weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_null(weapon,
		"AC-A: Player.get_equipped_weapon() must be NULL on a fresh boot — " +
		"the boot-time auto-equip bandaid was retired (ticket 86c9qbb3k); " +
		"the player equips by picking up the dummy's iron_sword drop")
	var inv: Node = _inventory()
	assert_null(inv.get_equipped(&"weapon"),
		"AC-A: Inventory weapon slot must be empty on a fresh boot")


# ==========================================================================
# AC B — pickup auto-equip → Player.try_attack produces weapon-scaled damage
# ==========================================================================

func test_pickup_equip_drives_weapon_scaled_damage_not_fist() -> void:
	## The integration test that replaces PR #145's missing coverage, through
	## the NEW path: the dummy-dropped iron_sword Pickup wires into
	## `Inventory.on_pickup_collected`, which auto-equips it. Post-equip,
	## Player.try_attack must produce the iron_sword formula output, not
	## damage=1 (FIST_DAMAGE).
	var main: Node = _instantiate_main()
	await get_tree().process_frame

	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-B: Player spawned")
	# Precondition: fistless at boot.
	assert_null(player.get_equipped_weapon(),
		"AC-B: precondition — player is fistless at boot (see AC-A)")

	# Drive the production pickup hook — this is exactly what the dummy-dropped
	# Pickup's `picked_up` signal calls (PracticeDummy wires it to the Inventory
	# autoload's on_pickup_collected).
	var inv: Node = _inventory()
	inv.on_pickup_collected(_make_iron_sword_instance())

	# Post-pickup: the iron_sword must be equipped on BOTH surfaces.
	var weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon,
		"AC-B: Player.get_equipped_weapon() must be non-null after pickup-equip — " +
		"null means on_pickup_collected didn't auto-equip or didn't reach the Player")
	assert_eq(weapon.id, &"iron_sword", "AC-B: equipped weapon is the iron_sword")

	# Build a minimal Grunt target (bare-instanced, same pattern as test_grunt.gd).
	var GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
	var grunt: Grunt = GruntScript.new()
	var ContentFactoryScript: Script = preload("res://tests/factories/content_factory.gd")
	var def_overrides: Dictionary = {"hp_base": 50, "damage_base": 5, "move_speed": 60.0}
	grunt.mob_def = ContentFactoryScript.make_mob_def(def_overrides)
	add_child_autofree(grunt)
	await get_tree().process_frame

	var hp_before: int = grunt.get_hp()
	assert_eq(hp_before, 50, "AC-B: grunt starts at 50 HP")

	# Fire a light attack through the real Player.try_attack path.
	var hb: Hitbox = player.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
	assert_not_null(hb, "AC-B: try_attack must return a Hitbox")

	var expected_light_dmg: int = DamageScript.compute_player_damage(weapon, 0, &"light")
	assert_eq(hb.damage, expected_light_dmg,
		"AC-B: hitbox.damage must equal Damage.compute_player_damage(iron_sword, 0, light) = %d" % expected_light_dmg)
	assert_gt(hb.damage, DamageScript.FIST_DAMAGE,
		"AC-B: hitbox.damage=%d must be > FIST_DAMAGE=%d — if this fails, the pickup-equip " % [hb.damage, DamageScript.FIST_DAMAGE] +
		"didn't propagate to Player._equipped_weapon (dual-surface miss)")

	# Apply the hit and confirm HP drop matches formula output.
	hb._try_apply_hit(grunt)
	var hp_after: int = grunt.get_hp()
	assert_eq(hp_after, hp_before - expected_light_dmg,
		"AC-B: grunt HP must drop by %d (iron_sword light damage), not by 1 (fist)" % expected_light_dmg)


# ==========================================================================
# AC C — InventoryPanel Tab UI shows iron_sword after the pickup-equip
# ==========================================================================

func test_inventory_panel_equipped_row_shows_iron_sword_after_pickup() -> void:
	## After the player picks up the iron_sword, the InventoryPanel's weapon
	## equipped cell must display it (the Tab UI surface).
	var main: Node = _instantiate_main()
	await get_tree().process_frame

	var inv: Node = _inventory()
	inv.on_pickup_collected(_make_iron_sword_instance())

	var panel: InventoryPanel = (main as Main).get_inventory_panel() as InventoryPanel
	assert_not_null(panel, "AC-C: InventoryPanel mounted")
	panel.open()
	assert_true(panel.is_open(), "AC-C: panel opens")

	var equipped_item: ItemInstance = inv.get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped_item,
		"AC-C: Inventory.get_equipped('weapon') must be non-null after pickup-equip")
	assert_eq(equipped_item.def.id, &"iron_sword",
		"AC-C: equipped weapon must be iron_sword")

	var cells: Dictionary = panel.get("_equipped_cells") if "get" in panel else {}
	if cells != null and not cells.is_empty():
		var weapon_btn: Button = cells.get(&"weapon", null) as Button
		if weapon_btn != null:
			assert_ne(weapon_btn.text, "",
				"AC-C: equipped weapon slot button must show the iron_sword name, not empty string")

	panel.close()


# ==========================================================================
# AC D — a save with an equipped iron_sword restores it on boot
# ==========================================================================

func test_save_with_equipped_weapon_restores_on_boot() -> void:
	## The "returning player" path: a save that already has an equipped
	## iron_sword restores it on boot via Inventory.restore_from_save. The
	## bandaid retirement does NOT touch the save-restore path — a returning
	## player ends up equipped from their save, no pickup required.
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node == null:
		gut.p("SKIP: Save autoload not available")
		return

	# Build a save that has an equipped iron_sword (schema v3 shape).
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
		"equipped": {
			"weapon": _make_iron_sword_instance().to_save_dict(),
		},
		"stash": [],
		"meta": {"runs_completed": 0, "deepest_stratum": 1},
		"stratum": {},
	}
	assert_false(fake_data["equipped"]["weapon"].is_empty(),
		"AC-D: precondition — iron_sword serialized into the save dict")
	if save_node.has_method("save_game"):
		save_node.save_game(0, fake_data)

	# Boot Main — it loads the save and restores the equipped iron_sword.
	# preserve_save=true so _instantiate_main does NOT delete the crafted save.
	var main: Node = _instantiate_main(true)
	await get_tree().process_frame

	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-D: Player spawned")
	var weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon,
		"AC-D: a save with an equipped iron_sword must restore it on boot — " +
		"null means restore_from_save failed to re-apply the equipped weapon")
	assert_eq(weapon.id, &"iron_sword",
		"AC-D: restored equipped weapon must be the iron_sword from the save")
	var inv: Node = _inventory()
	var inv_equipped: ItemInstance = inv.get_equipped(&"weapon") as ItemInstance
	assert_not_null(inv_equipped, "AC-D: Inventory surface — weapon slot restored")
	assert_eq(inv_equipped.def.id, &"iron_sword",
		"AC-D: Inventory surface — restored weapon is the iron_sword")

	if save_node.has_method("delete_save"):
		save_node.delete_save(0)


# ==========================================================================
# AC E — LMB-click equip-swap drives the FULL integration surface (P0 86c9q96m8)
# ==========================================================================

func test_lmb_click_equip_swap_real_main_drives_dual_surfaces() -> void:
	## Sponsor M1 RC re-soak attempt 5 P0 86c9q96m8 — pick up a sword, click to
	## equip via LMB on inventory grid → "item disappears from grid but is NOT
	## actually equipped (subsequent swings still register the previous
	## weapon's damage)."
	##
	## This integration AC drives the full real-Main path through an equip-swap
	## and confirms BOTH the Inventory surface AND the Player surface end up
	## pointing at the new sword. Unchanged by the bandaid retirement — kept as
	## a regression guard for the equip-swap dual-surface invariant.
	var main: Node = _instantiate_main()
	await get_tree().process_frame

	var player: Player = (main as Main).get_player() as Player
	assert_not_null(player, "AC-E: Player spawned")

	# Establish the starting equipped weapon via the production pickup path
	# (the player is fistless at boot now — no bandaid). The picked-up
	# iron_sword auto-equips.
	var inv: Node = _inventory()
	inv.on_pickup_collected(_make_iron_sword_instance())
	var pre_weapon: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(pre_weapon, "AC-E: precondition — iron_sword equipped via pickup")
	assert_eq(pre_weapon.id, &"iron_sword", "AC-E: starter is iron_sword")
	var pre_damage: int = DamageScript.compute_player_damage(pre_weapon, 0, &"light")

	# Build a higher-damage replacement weapon (a "Room 02 pickup"). This one
	# does NOT auto-equip — a weapon is already equipped (first-weapon-only
	# rule), so it lands in the grid for the user to LMB-click-equip.
	var ContentFactoryScript: Script = preload("res://tests/factories/content_factory.gd")
	var swap_def: ItemDef = ContentFactoryScript.make_item_def({
		"id": &"swap_sword_e2e",
		"slot": ItemDef.Slot.WEAPON,
		"base_stats": ContentFactoryScript.make_item_base_stats({"damage": 12}),
	})
	var swap_sword: ItemInstance = ItemInstance.new(swap_def, ItemDef.Tier.T1)
	inv.on_pickup_collected(swap_sword)
	# First-weapon-only: the swap sword must NOT have auto-swapped.
	assert_eq((inv.get_equipped(&"weapon") as ItemInstance).def.id, &"iron_sword",
		"AC-E: second weapon pickup must NOT auto-swap — iron_sword stays equipped")
	assert_true(inv.get_items().has(swap_sword),
		"AC-E: the second weapon pickup lands in the grid (first-weapon-only rule)")

	# Drive the LMB click via the InventoryPanel test helper.
	var panel: InventoryPanel = (main as Main).get_inventory_panel() as InventoryPanel
	assert_not_null(panel, "AC-E: InventoryPanel mounted")
	panel.open()
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
		"propagate to Player (dual-surface mismatch).")

	# The previously-equipped iron_sword must be BACK IN THE GRID.
	var preserved_in_grid: bool = false
	for it_v in inv.get_items():
		var it_inst: ItemInstance = it_v as ItemInstance
		if it_inst != null and it_inst.def != null and it_inst.def.id == &"iron_sword":
			preserved_in_grid = true
			break
	assert_true(preserved_in_grid,
		"AC-E: previously-equipped iron_sword must land back in the grid on swap " +
		"(equip-swap data-loss guard — pre-fix this was lost to the floor)")

	# Tier 3 — damage delta on a real Grunt confirms the swap took effect.
	var GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
	var grunt: Grunt = GruntScript.new()
	var def_overrides: Dictionary = {"hp_base": 100, "damage_base": 5, "move_speed": 60.0}
	grunt.mob_def = ContentFactoryScript.make_mob_def(def_overrides)
	add_child_autofree(grunt)
	await get_tree().process_frame

	var hp_before: int = grunt.get_hp()
	var hb: Hitbox = player.try_attack(Player.ATTACK_LIGHT, Vector2.RIGHT) as Hitbox
	assert_not_null(hb, "AC-E: try_attack returned a Hitbox post-swap")
	var expected_post: int = DamageScript.compute_player_damage(swap_def, 0, &"light")
	assert_eq(hb.damage, expected_post,
		"AC-E: hitbox.damage uses NEW weapon (%d), not old iron_sword (%d)" %
		[expected_post, pre_damage])
	hb._try_apply_hit(grunt)
	assert_eq(grunt.get_hp(), hp_before - expected_post,
		"AC-E: grunt HP drops by NEW weapon damage, not by iron_sword's")


func before_each() -> void:
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node != null and save_node.has_method("has_save") and save_node.has_save(0):
		save_node.delete_save(0)


func after_each() -> void:
	_reset_autoloads()
	var save_node: Node = _save()
	if save_node != null and save_node.has_method("has_save") and save_node.has_save(0):
		save_node.delete_save(0)
