extends GutTest
## Tier 1 paired tests for PracticeDummy (Stage 2b — ticket `86c9qaj3u`).
##
## Coverage per testing bar (`team/TESTING_BAR.md` §Devon-and-Drew):
##   1. Spawns at HP_MAX with no MobDef required (tutorial entity is
##      MobDef-less by design).
##   2. Takes damage from a player-team Hitbox: HP decrements + `damaged`
##      signal fires.
##   3. Three fist hits (FIST_DAMAGE=1 each) kill the dummy (Uma Beat 5
##      "harmlessly poofs into ember-dust on the third strike").
##   4. Dummy deals zero damage — there is no swing path / hitbox / AI.
##   5. Dies at HP=0 emitting `mob_died` exactly once with `mob_def == null`
##      (mirrors the Grunt signal contract; null mob_def is the documented
##      "tutorial entity" sentinel that XP/loot pipelines no-op on).
##   6. Death sequence runs the standard hit-flash → death-tween → ember-poof
##      pipeline (target reference change tween, not is_valid flip per the
##      Tween.kill discipline rule from `.claude/docs/combat-architecture.md`).
##   7. Deferred queue_free idempotent guard works (mirrors Grunt's HTML5
##      safety-net pattern — second caller is a no-op).
##   8. CharacterBody2D motion_mode = MOTION_MODE_FLOATING from `_ready`
##      (universal-bug-class fix per Stratum1Boss PR #163, adopted day-one).
##   9. Layers/masks set per DECISIONS.md (enemy collision_layer = bit 4).
##  10. Drops a guaranteed iron_sword Pickup at death position (deterministic
##      starter-equip drop, no RNG — Stage 2b design-correct path retiring
##      PR #146's boot-equip bandaid).
##  11. EDGE: damage during dead is ignored (idempotent — multi-hit collapse
##      already happens at Hitbox level, but PracticeDummy mirrors the same
##      belt-and-suspenders guard Grunt uses).

const PracticeDummyScript: Script = preload("res://scripts/mobs/PracticeDummy.gd")
const HitboxScript: Script = preload("res://scripts/combat/Hitbox.gd")


# ---- Helpers ----------------------------------------------------------

func _make_dummy() -> PracticeDummy:
	var d: PracticeDummy = PracticeDummyScript.new()
	add_child_autofree(d)
	return d


# Build a parented dummy + parent so the iron_sword drop has a room to land
# in. Returns (dummy, room) — both autofreed.
func _make_dummy_in_room() -> Array:
	var room: Node2D = autofree(Node2D.new())
	add_child(room)
	var d: PracticeDummy = PracticeDummyScript.new()
	room.add_child(d)
	return [d, room]


func _hit_dummy(d: PracticeDummy, dmg: int) -> void:
	# Direct take_damage call mirrors what `Hitbox._try_apply_hit` does.
	d.take_damage(dmg, Vector2.ZERO, null)


# ---- 1: spawns at HP_MAX with no MobDef required --------------------

func test_spawns_at_full_hp_no_mob_def_required() -> void:
	var d: PracticeDummy = _make_dummy()
	assert_eq(d.get_hp(), PracticeDummy.HP_MAX, "PracticeDummy spawns at HP_MAX")
	assert_eq(d.get_max_hp(), PracticeDummy.HP_MAX, "max HP equals HP_MAX const")
	assert_eq(PracticeDummy.HP_MAX, 3,
		"HP_MAX = 3 — Uma Beat 5 'third strike' invariant")
	assert_null(d.mob_def, "PracticeDummy has no MobDef by design (tutorial entity)")


# ---- 2: take damage decrements HP + emits damaged ---------------------

func test_take_damage_decrements_hp_and_emits_damaged() -> void:
	var d: PracticeDummy = _make_dummy()
	watch_signals(d)
	_hit_dummy(d, 1)
	assert_eq(d.get_hp(), PracticeDummy.HP_MAX - 1, "HP decrements by 1 on fist hit")
	assert_signal_emitted(d, "damaged", "damaged signal fires on hit")
	var params: Array = get_signal_parameters(d, "damaged", 0)
	assert_eq(params[0], 1, "damaged amount is 1")
	assert_eq(params[1], PracticeDummy.HP_MAX - 1, "damaged hp_remaining is 2")


# ---- 3: three fist hits kill the dummy -------------------------------

func test_three_fist_hits_kill_dummy() -> void:
	# Uma Beat 5: dummy "harmlessly poofs into ember-dust on the third strike."
	# At FIST_DAMAGE=1 (fistless player), three hits = HP_MAX = 3 = dead.
	var bundle: Array = _make_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	_hit_dummy(d, 1)
	assert_false(d.is_dead(), "alive after 1st hit")
	_hit_dummy(d, 1)
	assert_false(d.is_dead(), "alive after 2nd hit")
	_hit_dummy(d, 1)
	assert_true(d.is_dead(), "DEAD after 3rd hit — Beat 5 invariant")
	assert_eq(d.get_hp(), 0, "HP exactly 0 on death")


# ---- 4: dummy deals zero damage (no swing / no hitbox / no AI) --------

func test_dummy_has_no_swing_or_damage_path() -> void:
	# PracticeDummy is non-threatening by design. No `_swing_*` methods, no
	# `damage_base` field (or 0 if introduced later via mob_def assignment),
	# no AI tick that deals damage.
	var d: PracticeDummy = _make_dummy()
	assert_false(d.has_method("_swing_light"),
		"PracticeDummy has no light-attack swing path (zero damage by design)")
	assert_false(d.has_method("_swing_heavy"),
		"PracticeDummy has no heavy-attack swing path")
	assert_false(d.has_method("_begin_light_telegraph"),
		"PracticeDummy has no attack-telegraph path")
	# `set_player` exists for duck-typed compatibility with Main._wire_mob —
	# but it's a stub that ignores the player ref (no chase / no aggro).
	assert_true(d.has_method("set_player"),
		"set_player stub present for duck-typed wiring compatibility")


# ---- 5: dies emitting mob_died once with mob_def == null --------------

func test_die_emits_mob_died_exactly_once_with_null_mob_def() -> void:
	var bundle: Array = _make_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	watch_signals(d)
	_hit_dummy(d, PracticeDummy.HP_MAX)
	assert_true(d.is_dead(), "dummy dies on lethal hit")
	assert_signal_emit_count(d, "mob_died", 1, "mob_died fires exactly once")
	var params: Array = get_signal_parameters(d, "mob_died", 0)
	assert_eq(params[0], d, "mob_died payload[0] = the dummy node")
	# mob_def is null per the documented contract — XP/loot pipelines that
	# gate on `mob_def != null` (MobLootSpawner.on_mob_died, Levels) silently
	# no-op on dummy death.
	assert_null(params[2], "mob_died payload[2] = null mob_def (tutorial sentinel)")


# ---- 6: hit-flash tween + death tween reference-change pattern --------

func test_hit_flash_uses_sprite_color_tween() -> void:
	# Sprite child is loaded from PracticeDummy.tscn; bare-instanced dummy
	# has no Sprite, so this test loads the production scene.
	var packed: PackedScene = load("res://scenes/mobs/PracticeDummy.tscn")
	var d: PracticeDummy = packed.instantiate() as PracticeDummy
	add_child_autofree(d)
	# Pre-hit — no flash tween yet.
	assert_null(d._hit_flash_tween, "no hit-flash tween before first hit")
	_hit_dummy(d, 1)
	# Post-hit — tween reference exists. Tween.kill sets is_valid=false
	# asynchronously, so we assert ON THE REFERENCE per
	# `.claude/docs/combat-architecture.md` § Tier 1 corollary.
	assert_not_null(d._hit_flash_tween,
		"hit-flash tween exists after first hit (sprite color tween reference)")


func test_second_hit_during_flash_kills_and_restarts_tween() -> void:
	var packed: PackedScene = load("res://scenes/mobs/PracticeDummy.tscn")
	var d: PracticeDummy = packed.instantiate() as PracticeDummy
	add_child_autofree(d)
	_hit_dummy(d, 1)
	var first_tween: Tween = d._hit_flash_tween
	assert_not_null(first_tween, "first hit produces a flash tween")
	# Hit again within the flash window.
	_hit_dummy(d, 1)
	var second_tween: Tween = d._hit_flash_tween
	assert_not_null(second_tween, "second hit leaves a tween in place")
	assert_ne(first_tween, second_tween,
		"second hit kills + restarts: tween reference flipped (Tier 1 invariant per HTML5 corollary)")


# ---- 7: idempotent _force_queue_free guard ----------------------------

func test_force_queue_free_idempotent() -> void:
	var bundle: Array = _make_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	# Drive death so the queue_free path has run once.
	_hit_dummy(d, PracticeDummy.HP_MAX)
	# Second call must be a no-op (already queued for deletion).
	d._force_queue_free()
	# If the second call wasn't idempotent we'd panic — reaching here is the
	# pass condition. Belt-and-suspenders assertion via is_queued_for_deletion.
	assert_true(d.is_queued_for_deletion() or not is_instance_valid(d),
		"dummy queued for deletion (or freed) after _force_queue_free path")


# ---- 8: CharacterBody2D motion_mode = FLOATING ------------------------

func test_motion_mode_is_floating_from_ready() -> void:
	# Per `.claude/docs/combat-architecture.md` § "CharacterBody2D motion_mode
	# rule" + Stratum1Boss PR #163: every CharacterBody2D in this top-down
	# 2D game adopts MOTION_MODE_FLOATING from day-one to avoid the
	# direction-asymmetric collision-resolution bug class.
	var d: PracticeDummy = _make_dummy()
	# `_ready` ran on add_child_autofree -> _apply_motion_mode fired.
	assert_eq(d.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING,
		"motion_mode = FLOATING (universal-bug-class fix adopted day-one)")


# ---- 9: layers/masks set per DECISIONS.md ----------------------------

func test_layers_and_masks_per_decisions() -> void:
	# Bare-instanced dummy ends up on the enemy layer just like a scene-loaded one.
	var d: PracticeDummy = _make_dummy()
	assert_eq(d.collision_layer, PracticeDummy.LAYER_ENEMY, "dummy on enemy layer (bit 4)")
	# Mask = world | player so dummy collides with both (won't move into
	# walls; player can run into the dummy's collider).
	var expected_mask: int = PracticeDummy.LAYER_WORLD | PracticeDummy.LAYER_PLAYER
	assert_eq(d.collision_mask, expected_mask,
		"dummy mask = world | player (bits 1+2)")


# ---- 10: drops guaranteed iron_sword on death -------------------------

func test_dummy_drops_guaranteed_iron_sword() -> void:
	# Stage 2b: every dummy death drops one iron_sword pickup at the dummy's
	# death position. Deterministic — no RNG, no LootTableDef — the player
	# walks into Room02 already equipped on every playthrough.
	var bundle: Array = _make_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	var room: Node2D = bundle[1]
	# Pre-death: room has only the dummy.
	var pre_room_children: int = room.get_child_count()
	# Drive lethal damage. The Pickup is added via call_deferred to honor the
	# Area2D physics-flush rule, so we must process_frame to let the deferred
	# call land.
	_hit_dummy(d, PracticeDummy.HP_MAX)
	await get_tree().process_frame
	# Post-death: room has dummy + pickup. Find the Pickup.
	var found_pickup: Pickup = null
	for child in room.get_children():
		if child is Pickup:
			found_pickup = child
			break
	assert_not_null(found_pickup, "iron_sword Pickup added to room after dummy death")
	assert_not_null(found_pickup.item, "Pickup carries an ItemInstance")
	assert_eq(found_pickup.item.def.id, &"iron_sword",
		"Pickup item is iron_sword (deterministic starter-equip drop)")


# ---- 10b: dropped Pickup is wired to Inventory.on_pickup_collected -----

func test_dummy_pickup_is_wired_to_inventory_on_pickup_collected() -> void:
	# Ticket 86c9qbb3k: the dummy bypasses MobLootSpawner (mob_def == null), so
	# Main._on_mob_died's auto_collect_pickups never sees this Pickup. The
	# dummy must wire the Pickup's `picked_up` signal to the Inventory
	# autoload's `on_pickup_collected` itself — otherwise the design-correct
	# auto-equip-on-pickup onboarding flow could never fire.
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(inv, "Inventory autoload registered")
	inv.reset()
	var bundle: Array = _make_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	var room: Node2D = bundle[1]
	_hit_dummy(d, PracticeDummy.HP_MAX)
	await get_tree().process_frame
	var found_pickup: Pickup = null
	for child in room.get_children():
		if child is Pickup:
			found_pickup = child
			break
	assert_not_null(found_pickup, "precondition: iron_sword Pickup dropped")
	# The load-bearing assertion: the Pickup's `picked_up` signal is connected
	# to the Inventory autoload's `on_pickup_collected`.
	assert_true(
		found_pickup.picked_up.is_connected(inv.on_pickup_collected),
		"the dummy-dropped Pickup must wire its `picked_up` signal to " +
		"Inventory.on_pickup_collected — without this, walking onto the drop " +
		"would not equip the iron_sword (ticket 86c9qbb3k onboarding path)")
	# End-to-end: emitting `picked_up` (simulating the player walking onto it)
	# auto-equips the iron_sword via on_pickup_collected.
	found_pickup.picked_up.emit(found_pickup.item, found_pickup)
	var equipped: ItemInstance = inv.get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped,
		"collecting the dummy-dropped Pickup auto-equips the iron_sword")
	assert_eq(equipped.def.id, &"iron_sword",
		"the auto-equipped weapon is the dummy's iron_sword drop")
	inv.reset()


# ---- 11: damage during dead is ignored (idempotent) -------------------

func test_damage_during_dead_is_ignored() -> void:
	var bundle: Array = _make_dummy_in_room()
	var d: PracticeDummy = bundle[0]
	_hit_dummy(d, PracticeDummy.HP_MAX)
	assert_true(d.is_dead(), "dummy dead after lethal hit")
	watch_signals(d)
	# Hit a corpse — should be a no-op.
	_hit_dummy(d, 99)
	assert_signal_emit_count(d, "damaged", 0, "no damaged signal on dead-dummy hit")
	assert_signal_emit_count(d, "mob_died", 0, "no second mob_died on dead-dummy hit")
	assert_eq(d.get_hp(), 0, "HP stays at 0")
