class_name MobLootSpawner
extends RefCounted
## Glue between mob death events and loot spawning. Connect a Grunt's
## `mob_died` signal to `on_mob_died`, and this helper rolls the mob's
## loot table and spawns a Pickup for each rolled item at the death
## position.
##
## The helper holds a reference to the LootRoller so determinism (CI seed)
## stays under one knob.

const PickupScene: PackedScene = preload("res://scenes/loot/Pickup.tscn")

var roller: LootRoller
var parent_for_pickups: Node = null


func _init(p_roller: LootRoller = null) -> void:
	roller = p_roller if p_roller != null else LootRoller.new()


## Set the node that newly spawned pickups parent under. Typically the
## room/stratum root so pickups don't survive a room transition.
func set_parent_for_pickups(n: Node) -> void:
	parent_for_pickups = n


## Connect to a mob's `mob_died` signal:
##   grunt.mob_died.connect(spawner.on_mob_died)
##
## Returns spawned Pickup nodes for tests/inspection.
##
## **Physics-flush safety (run-002 P0, ticket TBA — Sponsor's
## `embergrave-html5-4ab2813` retest):** `mob_died` is emitted from
## `mob._die`, which itself runs synchronously on the physics-step
## callback chain (`Hitbox.body_entered → mob.take_damage → mob._die →
## mob_died.emit → on_mob_died`). The `Pickup` scene root is an `Area2D`,
## so calling `parent.add_child(pickup)` here is a physics-state mutation
## DURING THE PHYSICS QUERY FLUSH — Godot 4 panics with
## "Can't change this state while flushing queries. Use call_deferred()
## or set_deferred() to change monitoring state instead." and aborts the
## remaining call chain. From the player's perspective, mobs go
## `_die → tween-armed → ...permanent-stall...`, never reaching
## `_force_queue_free`. This is hidden as long as no mob actually dies
## (e.g. the FIST_DAMAGE=1 vs HP=50 imbalance), and surfaced the moment
## a kill lands.
##
## Fix: defer the `add_child` so it lands AFTER the physics flush. We
## still construct + configure the Pickup synchronously (so the returned
## array is populated for tests / signal-emission timing contracts), and
## still parent under `parent_for_pickups`, but the actual scene-tree
## insertion is `call_deferred`. Tests that need the pickup live this
## frame can `await get_tree().process_frame` once.
func on_mob_died(_mob: Node, death_pos: Vector2, mob_def: MobDef) -> Array[Node]:
	var spawned: Array[Node] = []
	if mob_def == null or mob_def.loot_table == null:
		_emit_trace("on_mob_died",
			"SKIPPED no_loot mob_def=%s loot_table=%s" % [
				str(mob_def), str(null if mob_def == null else mob_def.loot_table)])
		return spawned
	var rolls: Array[ItemInstance] = roller.roll(mob_def.loot_table)
	if rolls.is_empty():
		_emit_trace("on_mob_died",
			"SKIPPED empty_roll mob_def_id=%s" % str(mob_def.id))
		return spawned
	# Spread pickups in a small ring so they don't all stack on one pixel.
	var angle_step: float = TAU / max(1, rolls.size())
	# Diagnostic trace (ticket `86c9uemdg`): emit before spawning so Sponsor's
	# HTML5 soak captures (mob_id, roll_count, parent) at the entry point —
	# the dual-spawn bug (boss-room had its own loot spawner producing the
	# same drops Main was already spawning) showed up as TWO `on_mob_died`
	# lines per boss death. Future regressions in that family will surface the
	# same way: two lines for the same mob_id within the same frame.
	var parent_name: String = "<null>" if parent_for_pickups == null else str(parent_for_pickups)
	_emit_trace("on_mob_died",
		"SPAWNING mob_id=%s rolls=%d parent=%s pos=(%.0f,%.0f)" % [
			str(mob_def.id), rolls.size(), parent_name, death_pos.x, death_pos.y])
	for i in rolls.size():
		var item: ItemInstance = rolls[i]
		var offset: Vector2 = Vector2.RIGHT.rotated(angle_step * float(i)) * 12.0
		var pickup: Pickup = PickupScene.instantiate()
		pickup.configure(item)
		pickup.position = death_pos + offset
		if parent_for_pickups != null:
			# Defer add_child: Pickup is an Area2D, and on_mob_died runs
			# during the physics-query flush via the Hitbox body_entered
			# chain. Synchronous Area2D add panics Godot 4. See docstring.
			parent_for_pickups.call_deferred("add_child", pickup)
		spawned.append(pickup)
	return spawned


## TEST-ONLY — force-spawn a Pickup without going through `on_mob_died`.
##
## **Purpose (ticket 86c9ukc2e):** lets GUT tests exercise the
## "pickup collected while mob still alive" negative-arm (PR #229 finding #2
## counter-test) without needing a real mob_died event. The helper bypasses
## the loot-table roll and the `mob_def`/`mob_died` gate entirely, directly
## instantiating a Pickup from `PickupScene` at the requested position.
## The caller is responsible for wiring via `Inventory.auto_collect_pickups([pickup])`
## — the same convention `on_mob_died`'s callers use.
##
## **Naming convention:** the `_test_` prefix signals that this helper MUST
## NOT be called from production code paths. It exists solely for GUT harness
## use. No runtime feature flag is required — the naming convention + this
## docstring are the guard.
##
## **Physics-flush safety:** if `parent` is non-null the pickup is added via
## `call_deferred("add_child")` (same convention as `on_mob_died`) so callers
## coming from a physics callback context don't panic. Tests that need the
## pickup live in the same frame can `await get_tree().process_frame` once.
##
## **Why ItemInstance not item_id:** ContentRegistry is a RefCounted helper
## (not an autoload), so GUT tests always construct their own ItemInstance via
## ContentFactory. A Playwright fixture mapping an `item_id` string to an
## ItemInstance would call `ContentRegistry.resolve_item` before invoking this
## helper. The GUT-facing API keeps the seam slim.
##
## Parameters:
##   item: ItemInstance    — the already-constructed item to place in the Pickup
##   world_pos: Vector2    — absolute position for the spawned Pickup
##   parent: Node          — scene-tree parent (room root or autofree Node2D in
##                           tests); if null, pickup is returned un-parented
##                           (caller owns lifecycle)
##
## Returns the configured Pickup (never null — caller supplies the ItemInstance).
static func _test_force_spawn_pickup(
		item: ItemInstance,
		world_pos: Vector2,
		parent: Node,
) -> Pickup:
	var pickup: Pickup = PickupScene.instantiate()
	pickup.configure(item)
	pickup.position = world_pos
	if parent != null:
		# Deferred add_child — same physics-flush safety as on_mob_died.
		# Caller must await get_tree().process_frame before querying the tree.
		parent.call_deferred("add_child", pickup)
	return pickup


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
## MobLootSpawner is a RefCounted so we need a SceneTree handle to reach the
## autoload — pull it from `parent_for_pickups` if available, else fall back
## to `Engine.get_main_loop()`. Same no-op-on-desktop semantics as other
## combat-trace shims (only fires when `OS.has_feature("web")`).
func _emit_trace(tag: String, msg: String) -> void:
	var loop: SceneTree = null
	if parent_for_pickups != null and parent_for_pickups.is_inside_tree():
		loop = parent_for_pickups.get_tree()
	else:
		loop = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var df: Node = loop.root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace("MobLootSpawner." + tag, msg)
