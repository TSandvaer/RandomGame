extends GutTest
## Integration tests for `scenes/levels/Stratum1Room01.tscn` — verifies the
## room loads, builds against the authored chunk, spawns the practice
## dummy, and reports correct bounds. Per testing bar §integration check.
##
## **Stage 2b update (ticket `86c9qaj3u`):** Room01 now spawns a single
## PracticeDummy (not 2 grunts). The grunt-roster assertions below have
## been updated to assert a PracticeDummy spawn instead. See
## `team/uma-ux/player-journey.md` Beats 4-5 for the design rationale —
## first room is non-threatening tutorial, grunts arrive in Room02.

const Stratum1Room01Script: Script = preload("res://scripts/levels/Stratum1Room01.gd")
const GruntScript: Script = preload("res://scripts/mobs/Grunt.gd")
const PracticeDummyScript: Script = preload("res://scripts/mobs/PracticeDummy.gd")


func test_stratum1_room01_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	assert_not_null(packed, "Stratum1Room01.tscn must load")
	var instance: Node = packed.instantiate()
	assert_not_null(instance)
	assert_true(instance is Stratum1Room01, "root is Stratum1Room01 typed")
	instance.free()


func test_stratum1_room01_assembles_via_assembler() -> void:
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	var room: Stratum1Room01 = packed.instantiate()
	add_child_autofree(room)
	# _ready ran on add_child — assembly should be present.
	var asm: LevelAssembler.AssemblyResult = room.get_assembly()
	assert_not_null(asm, "room must have an assembly result after _ready")
	assert_not_null(asm.root, "assembly root spawned")


func test_stratum1_room01_bounds_match_canvas() -> void:
	# Bounds must fit Uma's 480x270 internal canvas (single-screen room).
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	var room: Stratum1Room01 = packed.instantiate()
	add_child_autofree(room)
	var bounds: Rect2 = room.get_bounds_px()
	assert_eq(bounds.position, Vector2.ZERO, "room origin at 0,0")
	assert_lte(bounds.size.x, 480.0, "width fits 480 logical px canvas")
	assert_lte(bounds.size.y, 270.0, "height fits 270 logical px canvas")


func test_stratum1_room01_spawns_practice_dummy() -> void:
	# Stage 2b: Room01 spawns a single PracticeDummy (not grunts) per
	# Uma's player-journey Beat 4-5 spec. Grunts moved to Room02 onward.
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	var room: Stratum1Room01 = packed.instantiate()
	add_child_autofree(room)
	var mobs: Array[Node] = room.get_spawned_mobs()
	assert_eq(mobs.size(), 1, "room spawns exactly one tutorial entity (Stage 2b)")
	var first: Node = mobs[0]
	assert_true(first is PracticeDummy, "spawned mob is PracticeDummy (Stage 2b)")
	var dummy: PracticeDummy = first
	assert_eq(dummy.collision_layer, PracticeDummy.LAYER_ENEMY, "dummy on enemy layer")
	# Dummy must NOT carry damage_base — non-threatening tutorial entity.
	assert_false("damage_base" in dummy and int(dummy.get("damage_base")) > 0,
		"PracticeDummy deals zero damage by design (no damage_base, or 0)")


func test_stratum1_room01_dummy_positioned_inside_bounds() -> void:
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	var room: Stratum1Room01 = packed.instantiate()
	add_child_autofree(room)
	var bounds: Rect2 = room.get_bounds_px()
	for m: Node in room.get_spawned_mobs():
		var n: Node2D = m
		assert_true(bounds.has_point(n.position), "dummy at %s inside bounds %s" % [str(n.position), str(bounds)])


func test_stratum1_room01_chunk_def_canonical() -> void:
	# Sanity: the .tscn references the canonical s1_room01.tres.
	var packed: PackedScene = load("res://scenes/levels/Stratum1Room01.tscn")
	var room: Stratum1Room01 = packed.instantiate()
	add_child_autofree(room)
	assert_not_null(room.chunk_def)
	assert_eq(room.chunk_def.id, &"s1_room01", "canonical chunk loaded")
