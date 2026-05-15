extends GutTest
## Integration tests for Stratum-2 rooms 02 + 03 — extends the W2 baseline
## `test_stratum2_rooms.gd` (which covers s2_room01 from M2 W1 T5).
##
## Paired with W3-T2 (`feat(level): stratum-2 second + third rooms`) which
## authors `resources/level_chunks/s2_room0{2,3}.tres` and the corresponding
## `scenes/levels/Stratum2Room0{2,3}.tscn` files.
##
## **Scaffold-only**: This file ships with `pending()` stubs that compile so
## CI's GUT step doesn't trip on parse errors. Tess fills in each test with
## real assertions when Drew's W3-T2 PR lands the production .tscn + .tres
## resources. Mirrors the W1-T12 / W2-T10 parallel-acceptance pattern.
##
## See `team/tess-qa/m2-acceptance-plan-week-3.md` § W3-T2 for the
## acceptance criteria this file pins (W3-T2-AC1..AC7).
##
## Sibling pattern: `tests/test_stratum1_rooms.gd` (17-test pattern at
## scale; this file scaled to 2 rooms).


# ---- W3-T2-AC1 — Both rooms load + assemble -------------------------

func test_s2_room02_chunk_def_loads() -> void:
	pending("awaiting W3-T2 — Drew authors resources/level_chunks/s2_room02.tres")


func test_s2_room03_chunk_def_loads() -> void:
	pending("awaiting W3-T2 — Drew authors resources/level_chunks/s2_room03.tres")


func test_s2_room02_scene_instantiates() -> void:
	pending("awaiting W3-T2 — Drew authors scenes/levels/Stratum2Room02.tscn")


func test_s2_room03_scene_instantiates() -> void:
	pending("awaiting W3-T2 — Drew authors scenes/levels/Stratum2Room03.tscn")


func test_s2_room02_assembles_via_level_assembler() -> void:
	pending("awaiting W3-T2 — LevelAssembler.assemble_single on s2_room02")


func test_s2_room03_assembles_via_level_assembler() -> void:
	pending("awaiting W3-T2 — LevelAssembler.assemble_single on s2_room03")


# ---- W3-T2-AC2 — Mob mix per spec -----------------------------------
##
## Room 02: 2× Stoker + 1× Charger heat-blasted = 3 mobs total.
## Room 03: 1× Stoker + 1× Charger heat-blasted + 1× Shooter heat-blasted = 3 mobs total.

func test_s2_room02_mob_mix_two_stokers_one_charger() -> void:
	pending("awaiting W3-T2 — assert get_spawned_mobs() composition: 2 Stoker + 1 Charger")


func test_s2_room03_mob_mix_one_stoker_one_charger_one_shooter() -> void:
	pending("awaiting W3-T2 — assert get_spawned_mobs() composition: 1 Stoker + 1 Charger + 1 Shooter")


# ---- W3-T2-AC3 — Mobs spawn inside chunk bounds ---------------------

func test_s2_room02_mobs_spawn_inside_bounds() -> void:
	pending("awaiting W3-T2 — every spawned mob position inside room_rect at spawn-tick")


func test_s2_room03_mobs_spawn_inside_bounds() -> void:
	pending("awaiting W3-T2 — every spawned mob position inside room_rect at spawn-tick")


# ---- W3-T2-AC4 — `&\"boss_door\"` port tag on R3 ---------------------

func test_s2_room03_has_boss_door_port_tag() -> void:
	pending("awaiting W3-T2 — s2_room03.tres ports include port_tag = &\"boss_door\"")


# ---- W3-T2-AC5 — S1→S2→R2→R3 traversal works ----------------------

func test_s2_r1_to_r2_traversal_via_room_gate() -> void:
	pending("awaiting W3-T2 — player crosses R1→R2 via RoomGate flow")


func test_s2_r2_to_r3_traversal_via_room_gate() -> void:
	pending("awaiting W3-T2 — player crosses R2→R3 via RoomGate flow")


# ---- W3-T2-AC6 — RoomGate cleared-state persists --------------------
##
## Regression gate: existing test_stratum_progression.gd covers the
## carry-state mechanism; this asserts the S2 R2 + R3 cleared flags
## participate in the same snapshot/restore round-trip.

func test_s2_room02_cleared_state_round_trip() -> void:
	pending("awaiting W3-T2 — StratumProgression snapshot/restore covers s2_room02 cleared")


func test_s2_room03_cleared_state_round_trip() -> void:
	pending("awaiting W3-T2 — StratumProgression snapshot/restore covers s2_room03 cleared")


# ---- W3-T2-AC7 — 480×270 internal canvas + WEST entry / EAST exit ---

func test_s2_room02_canvas_size_matches_s1_pattern() -> void:
	pending("awaiting W3-T2 — assert room_rect.size matches the s1_room0N 480x270 pattern")


func test_s2_room02_west_entry_east_exit_ports() -> void:
	pending("awaiting W3-T2 — assert WEST/EAST port positions per Drew's level-chunks.md M2 checklist")


func test_s2_room03_canvas_size_matches_s1_pattern() -> void:
	pending("awaiting W3-T2 — assert room_rect.size matches the s1_room0N 480x270 pattern")


func test_s2_room03_west_entry_east_exit_ports() -> void:
	pending("awaiting W3-T2 — assert WEST/EAST port positions + boss_door port tag")
