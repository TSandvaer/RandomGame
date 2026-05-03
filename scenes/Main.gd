class_name Main
extends Node2D
## Main entry-scene controller — the M1 play-loop spine.
##
## Wires together the entire M1 product surface that previously shipped as
## isolated subsystems with paired GUT tests but no integration:
##
##   - Stratum1Room01 spawns as the starting room with Player + grunts.
##   - HUD (CanvasLayer) shows HP/XP/level + build SHA + room counter.
##   - InventoryPanel mounts (hidden); Tab toggles per Uma `inventory-stats-panel.md`.
##   - StatAllocationPanel mounts; auto-opens on first level-up per Uma `level-up-panel.md`.
##   - Mob death -> Levels.gain_xp + MobLootSpawner -> Pickup -> Inventory.add (auto-collect).
##   - Player death -> M1 death rule: level + equipped survive, unequipped + run-progress reset.
##   - RoomGate clears unlock the next room; Rooms 1->8 chain reachable.
##   - Stratum1BossRoom reachable from Room 08; boss intro + 3-phase fight + descend.
##   - Save on quit (NOTIFICATION_WM_CLOSE_REQUEST); load on boot.
##
## **Why one controller scene (vs. dispersed):** Every subsystem already has
## its own _ready / signal surface — what's missing is the plumbing that
## chains them at runtime. Putting it here keeps the sequence visible and
## makes the integration test (`test_m1_play_loop.gd`) a single owner.
##
## **Headless-test friendliness:** every step is also reachable via public
## methods (`load_room_index`, `force_descend_for_test`, `apply_death_rule`,
## etc.) so the integration test can advance the loop deterministically
## without relying on physics overlap or wall-clock waits.

# ---- Signals ----------------------------------------------------------

## Emitted whenever the active room scene swaps. Carries the new room's
## node and the room index (0-based — Room01 = 0, Room08 = 7, BossRoom = 8).
signal room_changed(room: Node, index: int)

## Emitted when the player dies (after the death rule has been applied and
## the player respawned at Room01). Useful for tests + future death-screen
## hook.
signal player_respawned()

## Emitted after the boss is defeated and the descend signal fires.
signal stratum_descended()

# ---- Constants --------------------------------------------------------

const SAVE_SLOT: int = 0

## Room sequence — 8 stratum-1 rooms then the boss room. Indexed by
## `_current_room_index`.
const ROOM_SCENE_PATHS: Array[String] = [
	"res://scenes/levels/Stratum1Room01.tscn",
	"res://scenes/levels/Stratum1Room02.tscn",
	"res://scenes/levels/Stratum1Room03.tscn",
	"res://scenes/levels/Stratum1Room04.tscn",
	"res://scenes/levels/Stratum1Room05.tscn",
	"res://scenes/levels/Stratum1Room06.tscn",
	"res://scenes/levels/Stratum1Room07.tscn",
	"res://scenes/levels/Stratum1Room08.tscn",
	"res://scenes/levels/Stratum1BossRoom.tscn",
]

const BOSS_ROOM_INDEX: int = 8

## Room IDs for StratumProgression bookkeeping (matches the chunk_def.id
## fields in the .tres files). One-to-one with ROOM_SCENE_PATHS.
const ROOM_IDS: Array[StringName] = [
	&"s1_room01",
	&"s1_room02",
	&"s1_room03",
	&"s1_room04",
	&"s1_room05",
	&"s1_room06",
	&"s1_room07",
	&"s1_room08",
	&"s1_boss_room",
]

const PLAYER_SCENE_PATH: String = "res://scenes/player/Player.tscn"
const INVENTORY_PANEL_SCENE_PATH: String = "res://scenes/ui/InventoryPanel.tscn"
const STAT_PANEL_SCENE_PATH: String = "res://scenes/ui/StatAllocationPanel.tscn"
const DESCEND_SCREEN_SCENE_PATH: String = "res://scenes/screens/DescendScreen.tscn"

## Player spawn position — center of a 480x270 internal canvas (rooms are
## sized to that grid per Uma's visual-direction lock).
const DEFAULT_PLAYER_SPAWN: Vector2 = Vector2(240, 200)

# ---- Runtime ---------------------------------------------------------

# Active scene-tree pointers. _world holds the current room; _player is
# parented to the world root so the room's bounds + camera reference work.
var _world: Node2D = null
var _player: Player = null
var _hud: CanvasLayer = null
var _inventory_panel: CanvasLayer = null
var _stat_panel: CanvasLayer = null
var _descend_screen: CanvasLayer = null
var _current_room: Node = null
var _current_room_index: int = 0
var _boss_room: Stratum1BossRoom = null
var _loot_spawner: MobLootSpawner = null

# HUD widgets (built by _build_hud).
var _hp_label: Label = null
var _hp_bar: ProgressBar = null
var _xp_label: Label = null
var _xp_bar: ProgressBar = null
var _level_label: Label = null
var _room_label: Label = null
var _build_label: Label = null
var _stat_pip_label: Label = null

# Save-on-quit guard so we don't double-write when both NOTIFICATION_WM_CLOSE_REQUEST
# and `_exit_tree` fire on shutdown.
var _saved_on_quit: bool = false


func _ready() -> void:
	# We listen for the OS close-request to autosave. Without this, browsers
	# tab-closing would lose run state.
	get_tree().auto_accept_quit = false
	_loot_spawner = MobLootSpawner.new()
	_build_world_root()
	_build_hud()
	_build_inventory_panel()
	_build_stat_panel()
	_spawn_player()
	_subscribe_to_levels()
	_subscribe_to_inventory()
	_subscribe_to_player_stats()
	# Load save (or defaults) BEFORE loading the first room so the player's
	# HP / XP / level / equipped state is correct when the room spawns mobs.
	_load_save_or_defaults()
	_load_room_at_index(0)
	_refresh_hud_full()
	print("[Main] M1 play-loop ready — Room 01 loaded, autoloads wired")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_on_quit()
		get_tree().quit()


func _exit_tree() -> void:
	# Reset the auto_accept_quit override we installed in `_ready` so a test
	# scene tear-down doesn't leak the override into other GUT tests. In
	# production this path also runs at engine shutdown but is harmless
	# (the override only matters while the tree is alive).
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop != null:
		loop.auto_accept_quit = true


# ---- Public API ------------------------------------------------------

## Returns the active room node (Stratum1Room01 / MultiMobRoom / Stratum1BossRoom).
func get_current_room() -> Node:
	return _current_room


func get_current_room_index() -> int:
	return _current_room_index


func get_player() -> Player:
	return _player


func get_inventory_panel() -> CanvasLayer:
	return _inventory_panel


func get_stat_panel() -> CanvasLayer:
	return _stat_panel


func get_descend_screen() -> CanvasLayer:
	return _descend_screen


func get_hud() -> CanvasLayer:
	return _hud


func is_boss_room_active() -> bool:
	return _current_room_index == BOSS_ROOM_INDEX


## Programmatically advance to the room at `index`. Used by the
## integration test to skip the gate-clear plumbing for a particular
## waypoint. Production never calls this — production flows through
## `_on_room_cleared`.
func load_room_index(index: int) -> void:
	_load_room_at_index(index)


## Force-apply the M1 death rule: level + equipped survive, unequipped
## inventory + run progression reset, HP refilled, player respawned at
## Room01. Used by both the live `player_died` handler and the integration
## test's death-rule assertions.
func apply_death_rule() -> void:
	# Per DECISIONS.md 2026-05-02 "M1 death rule":
	#   - keep: level, equipped, V/F/E (PlayerStats), unspent stat points.
	#   - lose: unequipped inventory items, cleared-rooms progression, in-progress XP.
	# Levels.set_state(level, 0) zeroes mid-level XP without changing level.
	var levels: Node = _levels()
	if levels != null:
		levels.set_state(levels.current_level(), 0)
	var inventory: Node = _inventory()
	if inventory != null:
		inventory.clear_unequipped()
	var sp: Node = _stratum_progression()
	if sp != null:
		sp.reset()
	# Refill HP and clear the dead latch on the current player node.
	if _player != null:
		_player.revive_full_hp()
	# Re-load Room01 (replaces _current_room).
	_load_room_at_index(0)
	# Persist immediately so a quit-during-respawn doesn't lose the rule.
	_persist_to_save()
	player_respawned.emit()


## Test-only / dispatch convenience — drive the descend handoff directly,
## bypassing the StratumExit interaction sequence. Production fires this
## via the StratumExit's `descend_triggered` signal (player walks to portal
## + presses E).
func force_descend_for_test() -> void:
	_on_descend_triggered()


## Snapshot all autoload state into a payload + persist via Save autoload.
## Returns true on success.
func save_now(slot: int = SAVE_SLOT) -> bool:
	return _persist_to_save(slot)


# ---- World / scene construction --------------------------------------

func _build_world_root() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)


func _spawn_player() -> void:
	var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[Main] failed to load Player scene at %s" % PLAYER_SCENE_PATH)
		return
	_player = packed.instantiate() as Player
	if _player == null:
		push_error("[Main] Player scene did not instantiate as Player")
		return
	_player.name = "Player"
	_player.position = DEFAULT_PLAYER_SPAWN
	_world.add_child(_player)
	# Player.gd's _ready adds itself to the "player" group so existing
	# group-lookup callers (Pickup / Grunt._resolve_player / InventoryPanel)
	# find it without further wiring.
	# Subscribe death so we drive the respawn flow.
	if not _player.player_died.is_connected(_on_player_died):
		_player.player_died.connect(_on_player_died)
	if not _player.hp_changed.is_connected(_on_player_hp_changed):
		_player.hp_changed.connect(_on_player_hp_changed)


# ---- Room loading ----------------------------------------------------

func _load_room_at_index(index: int) -> void:
	if index < 0 or index >= ROOM_SCENE_PATHS.size():
		push_error("[Main] room index %d out of range" % index)
		return
	# Tear down old room. Use queue_free so any signal listeners running on
	# this tick can finish first (mirrors Grunt._die's defer-free pattern).
	if _current_room != null:
		# Unparent the player BEFORE freeing the room so we don't take the
		# player down with it.
		if _player != null and _player.get_parent() == _current_room:
			_current_room.remove_child(_player)
			_world.add_child(_player)
		_current_room.queue_free()
		_current_room = null
		_boss_room = null
	var packed: PackedScene = load(ROOM_SCENE_PATHS[index]) as PackedScene
	if packed == null:
		push_error("[Main] failed to load room scene %s" % ROOM_SCENE_PATHS[index])
		return
	var room: Node = packed.instantiate()
	_current_room = room
	_current_room_index = index
	_world.add_child(room)
	# Re-parent player inside the new room so room-relative position is
	# stable + the room script's spawned children share its tree.
	if _player != null:
		if _player.get_parent() != null:
			_player.get_parent().remove_child(_player)
		_player.position = DEFAULT_PLAYER_SPAWN
		room.add_child(_player)
	# Wire room-specific signals.
	_wire_room_signals(room, index)
	# Push pickups into the room (loot spawner re-targets so dropped pickups
	# get freed when the room frees).
	_loot_spawner.set_parent_for_pickups(room)
	# Update HUD room counter.
	_refresh_room_label()
	room_changed.emit(room, index)


func _wire_room_signals(room: Node, index: int) -> void:
	# All multi-mob rooms (Room02..Room08) emit `room_cleared` from MultiMobRoom.
	# Room01 (Stratum1Room01) does NOT emit room_cleared — it has no RoomGate
	# in its .tscn. We fall back to listening on every spawned mob's mob_died
	# and counting down for both kinds of rooms; the gate-emitted path also
	# works because we always count from the live mob list.
	# Subscribe each spawned mob to Levels.gain_xp + MobLootSpawner.
	var mobs: Array[Node] = []
	if room.has_method("get_spawned_mobs"):
		mobs = room.get_spawned_mobs()
	for m: Node in mobs:
		_wire_mob(m)
	# Multi-mob rooms emit `room_cleared` once their RoomGate unlocks.
	if room.has_signal("room_cleared"):
		if not room.is_connected("room_cleared", _on_room_cleared):
			room.connect("room_cleared", _on_room_cleared)
	# Boss room: subscribe to entry-sequence + boss_died + stratum_exit_unlocked.
	if index == BOSS_ROOM_INDEX:
		_boss_room = room as Stratum1BossRoom
		if _boss_room != null:
			# Wire the boss too (same Levels.gain_xp + loot drop path).
			# The boss is spawned by the room's _spawn_boss, which runs on
			# the room's _ready. By the time we get here _ready has fired.
			var boss: Stratum1Boss = _boss_room.get_boss()
			if boss != null:
				_wire_mob(boss)
			if not _boss_room.stratum_exit_unlocked.is_connected(_on_stratum_exit_unlocked):
				_boss_room.stratum_exit_unlocked.connect(_on_stratum_exit_unlocked)
	else:
		# Room01 has no `room_cleared` signal. Wire a fallback: when the last
		# spawned mob dies, treat that as "cleared." This keeps the AC2 first-
		# room flow legible even with no gate.
		if not room.has_signal("room_cleared"):
			_install_room01_clear_listener(room, mobs)


# Shared mob wiring: XP gain + loot drop on death.
func _wire_mob(mob: Node) -> void:
	var levels: Node = _levels()
	if levels != null and levels.has_method("subscribe_to_mob"):
		levels.subscribe_to_mob(mob)
	# MobLootSpawner.on_mob_died subscribes the right way; we connect our
	# own handler that forwards to the spawner + immediately auto-collects
	# spawned pickups via Inventory.auto_collect_pickups.
	if mob.has_signal("mob_died"):
		if not mob.is_connected("mob_died", _on_mob_died):
			mob.connect("mob_died", _on_mob_died)
	# Boss uses `boss_died` instead of `mob_died`. Subscribe both — the
	# boss's `mob_died` doesn't exist; `boss_died` carries the same payload.
	if mob.has_signal("boss_died"):
		if not mob.is_connected("boss_died", _on_mob_died):
			mob.connect("boss_died", _on_mob_died)
	# Make sure the mob has a player target.
	if mob.has_method("set_player") and _player != null:
		mob.set_player(_player)


# Room01 has no RoomGate; we synthesize a "room_cleared" by observing every
# spawned mob's mob_died signal. After each death we ask the room to recount
# alive mobs (its get_spawned_mobs() returns the live mob array, which freed
# nodes drop out of). Idempotent — `_on_room_cleared` is itself one-shot
# because it advances `_current_room_index` and re-loads.
func _install_room01_clear_listener(_room: Node, mobs: Array[Node]) -> void:
	if mobs.is_empty():
		# Trivially clear — fire a deferred clear so the next-room load runs
		# after the current frame settles.
		call_deferred("_on_room_cleared")
		return
	for m: Node in mobs:
		if m.has_signal("mob_died") and not m.is_connected("mob_died", _on_room01_mob_died):
			m.connect("mob_died", _on_room01_mob_died)


# Room01 mob death handler — when the last live mob dies, fire the
# room_cleared synthetic signal. mob_died emits BEFORE the queue_free
# deferred call, so we count "still-alive non-dead mobs" on the current room.
func _on_room01_mob_died(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if _current_room == null:
		return
	if not _current_room.has_method("get_spawned_mobs"):
		return
	var alive_count: int = 0
	for n: Node in _current_room.get_spawned_mobs():
		if is_instance_valid(n) and not _mob_is_dead(n):
			alive_count += 1
	if alive_count == 0:
		# Deferred so any other `mob_died` listeners on this tick (XP gain,
		# loot drop) finish their work first.
		call_deferred("_on_room_cleared")


func _mob_is_dead(m: Node) -> bool:
	if m == null:
		return true
	if m.has_method("is_dead"):
		return bool(m.call("is_dead"))
	return false


# ---- HUD construction -----------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.layer = 10  # below InventoryPanel (80) and DescendScreen (100)
	add_child(_hud)
	# Top-left vitals — HP bar + level label + XP bar (lightweight per Uma hud.md).
	var vitals: Control = Control.new()
	vitals.name = "TopLeftVitals"
	vitals.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vitals.offset_left = 16.0
	vitals.offset_top = 16.0
	vitals.offset_right = 320.0
	vitals.offset_bottom = 100.0
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(vitals)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.4156862745, 0.1647058824, 1.0))
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.position = Vector2(0, 0)
	_level_label.size = Vector2(120, 20)
	_level_label.text = "LV 1"
	vitals.add_child(_level_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(0, 24)
	_hp_bar.size = Vector2(220, 14)
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	vitals.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.name = "HpLabel"
	_hp_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 1.0))
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.position = Vector2(228, 22)
	_hp_label.size = Vector2(120, 16)
	_hp_label.text = "100 / 100"
	vitals.add_child(_hp_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(0, 44)
	_xp_bar.size = Vector2(220, 6)
	_xp_bar.min_value = 0
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	vitals.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.name = "XpLabel"
	_xp_label.add_theme_color_override("font_color", Color(0.7215686275, 0.6745098039, 0.5568627451, 1.0))
	_xp_label.add_theme_font_size_override("font_size", 11)
	_xp_label.position = Vector2(228, 42)
	_xp_label.size = Vector2(160, 14)
	_xp_label.text = "0 / 100"
	vitals.add_child(_xp_label)

	# Top-right run context — STRATUM 1 · ROOM x/8 (or BOSS).
	var ctx: Control = Control.new()
	ctx.name = "TopRightContext"
	ctx.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ctx.offset_left = -300.0
	ctx.offset_top = 16.0
	ctx.offset_right = -16.0
	ctx.offset_bottom = 36.0
	ctx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(ctx)
	_room_label = Label.new()
	_room_label.name = "RoomLabel"
	_room_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 1.0))
	_room_label.add_theme_font_size_override("font_size", 14)
	_room_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_room_label.text = "STRATUM 1 · ROOM 1/8"
	ctx.add_child(_room_label)

	# Bottom-left build SHA footer (Tess testability hook).
	_build_label = Label.new()
	_build_label.name = "BuildLabel"
	_build_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_build_label.offset_left = 16.0
	_build_label.offset_top = -28.0
	_build_label.offset_right = 320.0
	_build_label.offset_bottom = -8.0
	_build_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 0.85))
	_build_label.add_theme_font_size_override("font_size", 10)
	_build_label.text = "build: dev-local"
	if BuildInfo != null:
		_build_label.text = BuildInfo.display_label
	_hud.add_child(_build_label)

	# Bottom-right [+1 STAT] pip — shows when PlayerStats has unspent points.
	_stat_pip_label = Label.new()
	_stat_pip_label.name = "StatPip"
	_stat_pip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_stat_pip_label.offset_left = -160.0
	_stat_pip_label.offset_top = -52.0
	_stat_pip_label.offset_right = -16.0
	_stat_pip_label.offset_bottom = -32.0
	_stat_pip_label.add_theme_color_override("font_color", Color(1.0, 0.4156862745, 0.1647058824, 1.0))
	_stat_pip_label.add_theme_font_size_override("font_size", 14)
	_stat_pip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stat_pip_label.text = ""
	_stat_pip_label.visible = false
	_hud.add_child(_stat_pip_label)


func _build_inventory_panel() -> void:
	var packed: PackedScene = load(INVENTORY_PANEL_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] inventory panel scene missing at %s" % INVENTORY_PANEL_SCENE_PATH)
		return
	_inventory_panel = packed.instantiate() as CanvasLayer
	if _inventory_panel == null:
		push_warning("[Main] InventoryPanel did not instantiate as CanvasLayer")
		return
	_inventory_panel.name = "InventoryPanel"
	add_child(_inventory_panel)


func _build_stat_panel() -> void:
	var packed: PackedScene = load(STAT_PANEL_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] stat allocation panel scene missing at %s" % STAT_PANEL_SCENE_PATH)
		return
	_stat_panel = packed.instantiate() as CanvasLayer
	if _stat_panel == null:
		push_warning("[Main] StatAllocationPanel did not instantiate as CanvasLayer")
		return
	_stat_panel.name = "StatAllocationPanel"
	add_child(_stat_panel)


# ---- Subscriptions: autoloads -------------------------------------

func _subscribe_to_levels() -> void:
	var levels: Node = _levels()
	if levels == null:
		return
	if levels.has_signal("xp_gained") and not levels.is_connected("xp_gained", _on_xp_gained):
		levels.connect("xp_gained", _on_xp_gained)
	if levels.has_signal("level_up") and not levels.is_connected("level_up", _on_level_up):
		levels.connect("level_up", _on_level_up)


func _subscribe_to_inventory() -> void:
	# Nothing to do — auto_collect_pickups wires per-pickup as they spawn.
	pass


func _subscribe_to_player_stats() -> void:
	var ps: Node = _player_stats()
	if ps == null:
		return
	if ps.has_signal("unspent_points_changed") and not ps.is_connected("unspent_points_changed", _on_unspent_points_changed):
		ps.connect("unspent_points_changed", _on_unspent_points_changed)


# ---- Save load / persist ------------------------------------------

func _load_save_or_defaults() -> void:
	var save_node: Node = _save()
	if save_node == null:
		return
	var data: Dictionary = save_node.load_game(SAVE_SLOT)
	if data.is_empty():
		# Fresh start — leave autoloads at default (already reset on autoload _ready).
		# Player HP defaults to 100/100 from Player.DEFAULT_HP_MAX.
		return
	# Restore Levels (level + xp).
	var character: Variant = data.get("character", {})
	if character is Dictionary:
		var ch: Dictionary = character
		var levels: Node = _levels()
		if levels != null:
			levels.set_state(int(ch.get("level", 1)), int(ch.get("xp", 0)))
		var ps: Node = _player_stats()
		if ps != null:
			ps.restore_from_character(ch)
		# Restore HP onto the player (set_hp clamps + emits hp_changed).
		if _player != null:
			# hp_max is bumped by future Vigor scaling (M2); for M1 we use the
			# saved value when present, falling back to DEFAULT_HP_MAX.
			var hp_max_saved: int = int(ch.get("hp_max", Player.DEFAULT_HP_MAX))
			var hp_cur_saved: int = int(ch.get("hp_current", hp_max_saved))
			_player.hp_max = max(1, hp_max_saved)
			_player.set_hp(hp_cur_saved)
	# Restore Inventory (no-op resolvers in M1; ItemDef registry is stub).
	var inventory: Node = _inventory()
	if inventory != null:
		var noop_item: Callable = func(_id: StringName) -> Resource: return null
		var noop_affix: Callable = func(_id: StringName) -> Resource: return null
		inventory.restore_from_save(data, noop_item, noop_affix)
	# Restore stratum progression.
	var sp: Node = _stratum_progression()
	if sp != null:
		sp.restore_from_save_data(data)


func _persist_to_save(slot: int = SAVE_SLOT) -> bool:
	var save_node: Node = _save()
	if save_node == null:
		return false
	var data: Dictionary = save_node.default_payload()
	# Layer in the autoload snapshots — same shape as test_ac6_quit_relaunch.gd.
	var character: Dictionary = data["character"]
	var levels: Node = _levels()
	if levels != null and levels.has_method("snapshot_to_character"):
		levels.snapshot_to_character(character)
	var ps: Node = _player_stats()
	if ps != null and ps.has_method("snapshot_to_character"):
		ps.snapshot_to_character(character)
	# HP snapshot.
	if _player != null:
		character["hp_current"] = _player.hp_current
		character["hp_max"] = _player.hp_max
	var inventory: Node = _inventory()
	if inventory != null and inventory.has_method("snapshot_to_save"):
		inventory.snapshot_to_save(data)
	var sp: Node = _stratum_progression()
	if sp != null and sp.has_method("snapshot_to_save_data"):
		sp.snapshot_to_save_data(data)
	return save_node.save_game(slot, data)


func _save_on_quit() -> void:
	if _saved_on_quit:
		return
	_saved_on_quit = true
	_persist_to_save()


# ---- Signal handlers --------------------------------------------

func _on_mob_died(mob: Node, death_position: Vector2, mob_def: Resource) -> void:
	# Forward to the loot spawner so a pickup spawns at the death position.
	if _loot_spawner != null and mob_def != null:
		var pickups: Array[Node] = _loot_spawner.on_mob_died(mob, death_position, mob_def as MobDef)
		var inventory: Node = _inventory()
		if inventory != null and inventory.has_method("auto_collect_pickups"):
			inventory.auto_collect_pickups(pickups)
	# Levels.subscribe_to_mob already grants XP via its own one-shot
	# connection, so we don't double-call here.


func _on_room_cleared(_room_id: Variant = null) -> void:
	# Mark cleared if the chunk_def carries an id (Room02..08 do; Room01 has
	# its own Stratum1Room01 script that lacks the gate->StratumProgression
	# wiring, so we mark from here too).
	var sp: Node = _stratum_progression()
	if sp != null and _current_room_index >= 0 and _current_room_index < ROOM_IDS.size():
		var rid: StringName = ROOM_IDS[_current_room_index]
		sp.mark_cleared(rid)
	# Persist progress on each clear so a quit-mid-run preserves the high-water mark.
	_persist_to_save()
	# Advance to the next room (boss room is the terminal — we don't auto-
	# advance past it; the StratumExit drives that transition).
	if _current_room_index < BOSS_ROOM_INDEX:
		var next_index: int = _current_room_index + 1
		_load_room_at_index(next_index)


func _on_stratum_exit_unlocked() -> void:
	# Boss is dead — drop loot already happened via _on_mob_died (the boss's
	# `boss_died` was wired in _wire_mob). Mark boss room cleared.
	var sp: Node = _stratum_progression()
	if sp != null:
		sp.mark_cleared(ROOM_IDS[BOSS_ROOM_INDEX])
	_persist_to_save()
	# Wire the StratumExit's descend signal so we open the descend screen
	# when the player walks to the portal + presses E.
	if _boss_room == null:
		return
	var exit: StratumExit = _boss_room.get_stratum_exit()
	if exit == null:
		return
	if not exit.descend_triggered.is_connected(_on_descend_triggered):
		exit.descend_triggered.connect(_on_descend_triggered)


func _on_descend_triggered() -> void:
	# Show the descend screen overlay. Hook its restart_run -> reload Room01
	# preserving level + equipped (the descend rule keeps everything per
	# DescendScreen.gd's docstring).
	if _descend_screen != null and is_instance_valid(_descend_screen):
		_descend_screen.queue_free()
	var packed: PackedScene = load(DESCEND_SCREEN_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] descend screen scene missing")
		return
	_descend_screen = packed.instantiate() as CanvasLayer
	if _descend_screen == null:
		return
	add_child(_descend_screen)
	if _descend_screen.has_signal("restart_run"):
		_descend_screen.connect("restart_run", _on_descend_restart_run)
	stratum_descended.emit()


func _on_descend_restart_run() -> void:
	# Tear down descend screen + reload Room01 keeping ALL state (descend
	# rule, not death rule). Player keeps level + equipped + inventory; only
	# room progression resets (the run starts over but with ALL gear).
	if _descend_screen != null and is_instance_valid(_descend_screen):
		_descend_screen.queue_free()
		_descend_screen = null
	var sp: Node = _stratum_progression()
	if sp != null:
		sp.preserve_for_descend()
		# preserve_for_descend is a no-op in M1; we still want the rooms
		# to be re-clearable so we reset progression. The descend rule says
		# "everything carries forward EXCEPT room-clear bookkeeping."
		sp.reset()
	if _player != null:
		_player.revive_full_hp()
	_load_room_at_index(0)
	_persist_to_save()


func _on_player_died(_death_position: Vector2) -> void:
	# Defer the death rule to the next frame so any signals on this tick
	# (final hit's mob_died, etc.) finish first.
	call_deferred("apply_death_rule")


func _on_player_hp_changed(_hp_current: int, _hp_max: int) -> void:
	_refresh_hp_widget()


func _on_xp_gained(_amount: int) -> void:
	_refresh_xp_widget()


func _on_level_up(_new_level: int) -> void:
	_refresh_level_widget()
	_refresh_xp_widget()
	# Persist on level-up — small enough that a quit-mid-XP-gain isn't
	# tragic, but a quit-mid-level-up that loses the level would be.
	_persist_to_save()


func _on_unspent_points_changed(new_unspent: int) -> void:
	if _stat_pip_label == null:
		return
	if new_unspent > 0:
		_stat_pip_label.text = "[+%d STAT]" % new_unspent
		_stat_pip_label.visible = true
	else:
		_stat_pip_label.text = ""
		_stat_pip_label.visible = false


# ---- HUD refresh ------------------------------------------------

func _refresh_hud_full() -> void:
	_refresh_hp_widget()
	_refresh_xp_widget()
	_refresh_level_widget()
	_refresh_room_label()
	_refresh_stat_pip()


func _refresh_hp_widget() -> void:
	if _player == null or _hp_bar == null or _hp_label == null:
		return
	_hp_bar.max_value = max(1, _player.hp_max)
	_hp_bar.value = _player.hp_current
	_hp_label.text = "%d / %d" % [_player.hp_current, _player.hp_max]


func _refresh_xp_widget() -> void:
	if _xp_bar == null or _xp_label == null:
		return
	var levels: Node = _levels()
	if levels == null:
		return
	var current_xp: int = int(levels.current_xp())
	var to_next: int = int(levels.xp_to_next())
	if to_next > 0:
		_xp_bar.max_value = to_next
		_xp_bar.value = clampf(float(current_xp), 0.0, float(to_next))
		_xp_label.text = "%d / %d" % [current_xp, to_next]
	else:
		_xp_bar.max_value = 1
		_xp_bar.value = 1
		_xp_label.text = "MAX"


func _refresh_level_widget() -> void:
	if _level_label == null:
		return
	var levels: Node = _levels()
	if levels == null:
		return
	_level_label.text = "LV %d" % int(levels.current_level())


func _refresh_room_label() -> void:
	if _room_label == null:
		return
	if _current_room_index == BOSS_ROOM_INDEX:
		_room_label.text = "STRATUM 1 · BOSS"
		_room_label.add_theme_color_override("font_color", Color(0.823, 0.290, 0.235, 1.0))
	else:
		_room_label.text = "STRATUM 1 · ROOM %d/8" % (_current_room_index + 1)
		_room_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 1.0))


func _refresh_stat_pip() -> void:
	var ps: Node = _player_stats()
	if ps == null or _stat_pip_label == null:
		return
	var n: int = int(ps.get_unspent_points())
	if n > 0:
		_stat_pip_label.text = "[+%d STAT]" % n
		_stat_pip_label.visible = true
	else:
		_stat_pip_label.text = ""
		_stat_pip_label.visible = false


# ---- Autoload accessors -----------------------------------------

func _save() -> Node:
	return get_tree().root.get_node_or_null("Save")


func _levels() -> Node:
	return get_tree().root.get_node_or_null("Levels")


func _player_stats() -> Node:
	return get_tree().root.get_node_or_null("PlayerStats")


func _inventory() -> Node:
	return get_tree().root.get_node_or_null("Inventory")


func _stratum_progression() -> Node:
	return get_tree().root.get_node_or_null("StratumProgression")
