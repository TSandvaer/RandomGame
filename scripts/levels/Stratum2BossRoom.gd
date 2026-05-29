class_name Stratum2BossRoom
extends Node2D
## Stratum-2 boss room — wires the boss-intro entry sequence to a door
## trigger, spawns the Archive Sentinel on its center plinth, locks all
## four cardinal ports during the fight, and routes boss-died into the
## stratum-exit-unlocked state.
##
## Design source: `team/uma-ux/palette-stratum-2.md` §5.5 Archive Sentinel
## ("boss-arena note" + boss-intro reveal beat) + `team/uma-ux/boss-intro.md`
## (Uma — binding for the BI-01 through BI-08 beat sequence) + W3-T7 Stage 5
## dispatch brief (ticket 86c9y7ygj Part D).
##
## **Structurally mirrors `scripts/levels/Stratum1BossRoom.gd`** — same
## entry-sequence + boss-spawn + boss-died wiring shape — with these
## Sentinel-specific departures:
##
##   1. **Arena ~32×24 tiles (1024×768 px world).** Larger than S1 boss
##      room (480×270) because the Sentinel is stationary; player needs
##      the additional arena to navigate around it and back off from
##      slam AOE. Continuous-scroll camera engages on room entry per
##      M3-T3-W2-T1 contract.
##   2. **Four cardinal ports lock on entry.** Per Uma §5.5: "room ports
##      at four cardinal directions for player navigation but ports stay
##      LOCKED during fight per `room-gate` convention." The door
##      trigger that the player crossed (south port by convention) locks
##      when the entry sequence fires; other three ports were always
##      locked (only the entry port was traversable).
##   3. **Boss-music crossfade to `mus-boss-stratum2.ogg`.** Distinct
##      from S1 boss music per DECISIONS.md 2026-05-15 UNIQUE decision.
##      Routes through `AudioDirector.crossfade_to_boss_stratum2`.
##   4. **No first-kill skip flag** (Stage 5 ship scope). The skip-after-
##      first-kill pattern (`Stratum1BossRoom._skip_eligible`) is per-
##      boss; the Sentinel can adopt the same shape in a Stage 6 follow-
##      up if subsequent-fight onboarding becomes a real consumer.
##   5. **BossNameplate reused from S1 (Stage 6, ticket `86c9y7ygj`).** The
##      Stage-5 `_spawn_boss_nameplate` no-op hook is now a real spawn that
##      reuses `res://scenes/ui/BossNameplate.tscn` (the same M3-T2-W3-T13
##      banner S1 BossRoom uses) — NOT a parallel S2-specific nameplate, per
##      the Stage-6 dispatch brief ("Reuse the S1 boss nameplate scene if one
##      exists; don't author a parallel one"). The banner slides down on
##      `entry_sequence_completed` (Uma `boss-intro.md` BI-07, 0.4 s) and
##      shows the Sentinel's `display_name` ("ARCHIVE SENTINEL"). **Known
##      cosmetic mismatch (follow-up, not a Stage-6 fix):** BossNameplate is
##      authored for a 3-phase boss (3 segments); ArchiveSentinel is 2-phase
##      (`PHASE_2_HP_FRAC=0.50`). The banner name + threat label + slide-in
##      render correctly; the 3-segment phase bar is a visual mismatch for a
##      2-phase boss. Parameterizing the nameplate's segment count is scope
##      expansion — filed as a follow-up ticket rather than bundled.
##
## **Boss loot single-pipeline rule (inherited from S1 BossRoom).** Loot
## is owned by Main's `MobLootSpawner` subscribed to the Sentinel's
## `boss_died` via `_wire_mob`. Stratum2BossRoom does NOT spawn its own
## loot — the pre-fix S1 dual-spawn bug (ticket `86c9uemdg`) produced
## uncollectable pickups when this rule was violated. Inherit the
## single-pipeline rule from day one.
##
## **Physics-flush safety (inherited from S1 BossRoom + ticket `86c9tv8uf`).**
## `_ready` defers Area2D-fixture builds to `_assemble_room_fixtures`
## via `call_deferred` so the deferred pass lands AFTER the physics-
## flush window (Stratum2BossRoom is loaded by `Main._load_room_at_index`
## from a port-traversal callback rooted in a CharacterBody2D body_entered
## physics callback — same root-cause class as S1).
##
## Stage 5 ship state:
##   - Placeholder Sentinel sprite is a ColorRect (`scenes/mobs/ArchiveSentinel.tscn`).
##   - Boss music `mus-boss-stratum2.ogg` already exists from PR #210.
##   - Audio cue wiring through existing `crossfade_to_boss_stratum2` API.
##   - Boss-intro full BI-01 through BI-08 beat sequence (door-slam, pan,
##     dormant→wake, zoom-in, nameplate-skipped-for-stage5, music crossfade).

# ---- Signals ------------------------------------------------------------

## The player crossed the boss-room threshold. Cinematic layer subscribes
## to start the door-slam, ambient-cut, camera-zoom.
signal entry_sequence_started

## The 1.8 s entry sequence has elapsed. Boss is about to wake. Cinematic
## layer subscribes to ramp camera back to player-anchored and start boss
## music. Wake fires immediately after.
signal entry_sequence_completed

## The boss has been defeated. Cinematic layer subscribes to drive the
## defeat sequence (time-freeze, ember dissolve, title card).
signal boss_defeated(boss: ArchiveSentinel, death_position: Vector2)

## Stratum-exit door has unlocked — player can leave the arena. Stage 5
## leaves the player with the standard descend / loot pickup flow.
signal stratum_exit_unlocked

# ---- Tuning ------------------------------------------------------------

## Total entry-sequence duration per Uma's spec (Beats 1–4 of boss-intro.md).
## Mirrors S1 Boss ENTRY_SEQUENCE_DURATION for cross-boss timing consistency.
const ENTRY_SEQUENCE_DURATION: float = 1.8

## Arena bounds — ~32×24 tiles at 32 px/tile = 1024×768 world units.
## Wider than the S1 boss arena (480×270) per Uma §5.5: "arena ~32×24
## tiles, sentinel plinth in center, room ports at four cardinal
## directions for player navigation." Continuous-scroll camera engages
## against these bounds on room entry.
const ARENA_BOUNDS: Rect2 = Rect2(0, 0, 1024, 768)
const ARENA_FOLLOW_DEADZONE: Vector2 = Vector2(40, 24)

## Arena zoom-out — Sponsor soak-round-2 finding ("characters too big") fix.
##
## **Diagnosed cause (b) — boss-room default zoom miscalibrated for the wider
## arena.** S1 rooms (incl. S1 boss room) are viewport-native 480×270, so the
## CameraDirector default (normalized 1.0 = BASELINE_ZOOM 2.6667× engine, which
## maps the 1280×720 viewport onto exactly 480×270 world px) renders them at the
## intended scale. The S2 arena is 1024×768 — 2.13× wider / 2.84× taller than
## the baseline viewport-world window. At default zoom the camera shows only
## ~480×270 of the arena, so boss + player render at full baseline scale while
## the player sees <half the arena → "too zoomed in / characters too big".
##
## The arena is intentionally larger-than-screen (Diablo-style continuous
## scroll), so the fix is NOT "fit the whole arena" (that would need normalized
## ~0.35, below the 0.5 CameraDirector floor anyway). It is "zoom OUT to read
## the arena + combatants at an appropriate scale". At normalized 0.5 the
## viewport-world window is `LOGICAL_VIEWPORT_BASE / (BASELINE_ZOOM * 0.5)` =
## (1280,720)/(1.3334,1.3334) = 960×540 world px — ~2× the content the baseline
## shows, with the deadzone-follow + ARENA_BOUNDS clamp handling the residual
## scroll. 0.5 is the CameraDirector MIN_NORMALIZED_ZOOM (widest allowed view).
##
## Scope: boss-room-specific (S1 unaffected — it stays 480×270 viewport-native
## at default zoom). NOT a game-wide camera change. The S1 boss room's only
## non-default zoom is the T16 death ember-rise (1.5×, fired at boss-death).
const ARENA_CAMERA_ZOOM: float = 0.5
const ARENA_CAMERA_ZOOM_DURATION: float = 0.0

## Center plinth position — where the Sentinel spawns + remains rooted.
## Center of the 1024×768 arena = (512, 384).
const PLINTH_POSITION: Vector2 = Vector2(512.0, 384.0)

# ---- Inspector --------------------------------------------------------

## res:// path to the boss scene. Indirected via export so tests can swap
## in a fake boss without coupling to the real scene's spec.
@export_file("*.tscn") var boss_scene_path: String = "res://scenes/mobs/ArchiveSentinel.tscn"

## res:// path to the boss MobDef TRES. Applied to the spawned boss after
## instantiation so HP/damage come from authored content.
@export_file("*.tres") var boss_mob_def_path: String = "res://resources/mobs/archive_sentinel.tres"

## World-space spawn position for the boss within the room. Default is the
## center plinth. Test/level can override.
@export var boss_spawn_position: Vector2 = PLINTH_POSITION

## World-space position of the door trigger. Player crossing this Area2D
## fires the entry sequence. Default placement at the room's south port
## (mid-bottom edge of the 1024×768 arena).
@export var door_trigger_position: Vector2 = Vector2(512.0, 720.0)
@export var door_trigger_size: Vector2 = Vector2(96.0, 16.0)

## res:// path to the StratumExit scene. Spawned (inactive) at room ready
## and activated via `boss_died` plumbing.
@export_file("*.tscn") var stratum_exit_scene_path: String = "res://scenes/levels/StratumExit.tscn"

## Stage 6 (ticket `86c9y7ygj`) — res:// path to the BossNameplate scene.
## Reuses the S1 M3-T2-W3-T13 banner (NOT a parallel S2 nameplate). Lazy-
## spawned in `_assemble_room_fixtures`; shown on `entry_sequence_completed`
## via `show_for(boss)`. Indirected via export so tests can opt in/out
## cleanly (set to "" to skip the spawn).
@export_file("*.tscn") var boss_nameplate_scene_path: String = "res://scenes/ui/BossNameplate.tscn"

## World-space position of the stratum exit portal. Default places it at
## the room's north port (mid-top edge of the arena) — opposite the
## entry door, so the player walks "deeper" to descend.
@export var stratum_exit_position: Vector2 = Vector2(512.0, 48.0)

# ---- Runtime ----------------------------------------------------------

var _boss: ArchiveSentinel = null
var _door_trigger: Area2D = null
var _entry_timer: SceneTreeTimer = null
var _entry_sequence_active: bool = false
var _entry_sequence_completed: bool = false
var _entry_started_time_ms: int = 0
var _entry_completed_time_ms: int = 0
var _stratum_exit_unlocked: bool = false
var _stratum_exit: StratumExit = null
## Stage 6 (ticket `86c9y7ygj`) — BossNameplate instance (typed loosely as
## Node for test-friendliness; production resolves to BossNameplate via the
## scene load in `_spawn_boss_nameplate`). Mirrors S1 BossRoom's field.
var _boss_nameplate: Node = null


func _ready() -> void:
	# Boss spawned synchronously per S1 BossRoom precedent — the boss is a
	# CharacterBody2D (no Area2D monitoring mutation on tree-entry), and
	# Main._wire_room_signals reads `get_boss()` on the same tick the room
	# is added. Deferring would null-out the wiring.
	_spawn_boss()
	_wire_audio_cues()
	# Defer Area2D-fixture builds out of the physics-flush window. Same
	# root-cause class as S1 BossRoom (ticket 86c9tv8uf) — the room is
	# loaded from a port-traversal callback rooted in a CharacterBody2D
	# body_entered physics callback; adding the door-trigger Area2D + the
	# StratumExit (which builds its own Area2D interaction area) inside
	# that flush panics with Godot's "Can't change this state while
	# flushing queries" guard.
	call_deferred("_assemble_room_fixtures")


func _assemble_room_fixtures() -> void:
	if not is_inside_tree():
		return
	_build_door_trigger()
	_spawn_stratum_exit()
	# Stage 6 (ticket `86c9y7ygj`) — spawn the boss nameplate (reused S1
	# banner). Hidden by default; `_complete_entry_sequence` calls
	# `show_for(boss)` at T+1.8 s to start the slide-in tween (Uma BI-07).
	_spawn_boss_nameplate()
	# Engage continuous-scroll camera against the arena bounds.
	_engage_camera_for_boss_room()
	# HTML5-only datapoint — confirms the deferred fixture pass ran and the
	# door-trigger Area2D is in the tree + monitoring. If a physics-flush
	# regression ever re-breaks the Area2D insertion, `monitoring` reads
	# false here. Mirrors S1 BossRoom trace.
	if _door_trigger != null:
		_combat_trace(
			"Stratum2BossRoom._assemble_room_fixtures",
			(
				"door_trigger built — inside_tree=%s monitoring=%s"
				% [str(_door_trigger.is_inside_tree()), str(_door_trigger.monitoring)]
			)
		)
	# Auto-fire the entry sequence. Same rationale as S1 BossRoom — production
	# `Main._load_room_at_index` teleports the player into the room without
	# any physics overlap event, so the door-trigger body_entered would never
	# fire on its own. The trigger remains a safe fallback (idempotent guard).
	#
	# Gated on `_boss != null`: tests that construct the room with empty
	# `boss_scene_path` should NOT auto-fire (they're inspecting only the
	# trigger Area2D properties). Production always has the boss path set.
	if _boss != null:
		trigger_entry_sequence()


# ---- Public API -------------------------------------------------------


func get_boss() -> ArchiveSentinel:
	return _boss


func get_door_trigger() -> Area2D:
	return _door_trigger


func get_stratum_exit() -> StratumExit:
	return _stratum_exit


## Stage 6 — boss nameplate accessor (typed loosely so tests with the
## nameplate scene opted-out get a null cleanly). Mirrors S1 BossRoom.
func get_boss_nameplate() -> Node:
	return _boss_nameplate


func is_entry_sequence_active() -> bool:
	return _entry_sequence_active


func is_entry_sequence_completed() -> bool:
	return _entry_sequence_completed


func is_stratum_exit_unlocked() -> bool:
	return _stratum_exit_unlocked


## Force-fire the entry sequence (used by tests that don't simulate physics
## overlap). The Area2D body_entered handler also calls this in production.
func trigger_entry_sequence() -> void:
	if _entry_sequence_active or _entry_sequence_completed:
		return
	_entry_sequence_active = true
	_entry_started_time_ms = Time.get_ticks_msec()
	entry_sequence_started.emit()
	if is_inside_tree():
		_entry_timer = get_tree().create_timer(ENTRY_SEQUENCE_DURATION)
		_entry_timer.timeout.connect(_complete_entry_sequence)


## Test-only: skip the wall-clock wait and complete the sequence now.
## Production code never calls this. Fast-forwards through both the
## entry-sequence 1.8 s timer AND the boss's ~417 ms wake-anim window.
func complete_entry_sequence_for_test() -> void:
	_complete_entry_sequence()
	if _boss != null and is_instance_valid(_boss) and _boss.has_method("complete_wake_for_test"):
		_boss.complete_wake_for_test()


# ---- Internal --------------------------------------------------------


func _build_door_trigger() -> void:
	_door_trigger = Area2D.new()
	_door_trigger.name = "Stratum2BossRoomDoorTrigger"
	_door_trigger.position = door_trigger_position
	# Player is on layer 2 (player). The trigger sits on no layer and masks
	# player so player overlap fires body_entered. Receiver-side encapsulation
	# (monitorable=false) per Hitbox/Projectile/Stratum1BossRoom precedent.
	_door_trigger.collision_layer = 0
	_door_trigger.collision_mask = 1 << 1  # bit 2 = player
	_door_trigger.monitorable = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = door_trigger_size
	shape.shape = rect
	_door_trigger.add_child(shape)
	_door_trigger.body_entered.connect(_on_door_trigger_body_entered)
	_door_trigger.area_entered.connect(_on_door_trigger_area_entered_ignored)
	add_child(_door_trigger)


func _spawn_boss() -> void:
	var packed: PackedScene = load(boss_scene_path) as PackedScene
	if packed == null:
		push_error("Stratum2BossRoom: failed to load boss scene at '%s'" % boss_scene_path)
		return
	var node: Node = packed.instantiate()
	if not node is ArchiveSentinel:
		push_error("Stratum2BossRoom: boss scene root is not ArchiveSentinel")
		node.free()
		return
	_boss = node
	_boss.position = boss_spawn_position
	if boss_mob_def_path != "":
		var def: MobDef = load(boss_mob_def_path) as MobDef
		if def != null:
			_boss.mob_def = def
	add_child(_boss)
	# Re-apply def post-add_child so the boss's _ready resolves with the
	# right hp_max even if the export-path load completed late.
	if _boss.mob_def != null:
		_boss.apply_mob_def(_boss.mob_def)
	# Wire boss death to loot drop + exit-unlock.
	_boss.boss_died.connect(_on_boss_died)


func _on_door_trigger_body_entered(body: Node) -> void:
	# Belt-and-suspenders CharacterBody2D guard — the collision_mask already
	# filters at the physics level. Mirrors S1 BossRoom trace shape so a
	# Playwright spec / Sponsor DevTools can confirm the trigger saw a body.
	_combat_trace(
		"Stratum2BossRoom._on_door_trigger_body_entered",
		"body=%s is_character_body=%s" % [str(body), str(body is CharacterBody2D)]
	)
	if not body is CharacterBody2D:
		return
	trigger_entry_sequence()


## Area2D neighbors are never allowed to fire the boss entry sequence.
## See RoomGate._on_area_entered_ignored for the full rationale.
func _on_door_trigger_area_entered_ignored(_area: Area2D) -> void:
	pass


func _complete_entry_sequence() -> void:
	if _entry_sequence_completed:
		return
	_entry_sequence_completed = true
	_entry_sequence_active = false
	_entry_completed_time_ms = Time.get_ticks_msec()
	entry_sequence_completed.emit()
	# Stage 6 — kick the nameplate slide-in at the Beat 4 → Beat 5 boundary
	# (Uma `boss-intro.md` BI-07, 0.4 s ease-out). Fires AFTER
	# `entry_sequence_completed.emit()` so subscribers see the signal before
	# the nameplate animates. Guarded on null + has_method so the room boots
	# fine when the nameplate scene is opted-out (bare-test surface).
	if (
		_boss_nameplate != null
		and is_instance_valid(_boss_nameplate)
		and _boss_nameplate.has_method("show_for")
	):
		_boss_nameplate.call("show_for", _boss)
	# Wake the Sentinel now that Beats 1–4 are over.
	if _boss != null and not _boss.is_dead():
		_boss.wake()


func _on_boss_died(boss: ArchiveSentinel, death_position: Vector2, _mob_def: MobDef) -> void:
	# Loot owned by Main's MobLootSpawner (subscribed to boss_died via
	# _wire_mob). Stratum2BossRoom does NOT spawn its own loot — same
	# single-pipeline rule as S1 BossRoom (ticket `86c9uemdg`).
	_stratum_exit_unlocked = true
	# Activate the StratumExit — physics-flush safety same as S1 BossRoom
	# (ticket `86c9ujq8d`): `_on_boss_died` fires from `_die` → take_damage
	# → Hitbox.body_entered, which is a physics-flush callback. Mutating
	# StratumExit's Area2D monitoring inside that flush triggers Godot's
	# ERR_FAIL_COND guard silently. Defer the activate() call.
	_combat_trace(
		"Stratum2BossRoom._on_boss_died",
		"boss_died received — deferring StratumExit.activate() to clear physics flush"
	)
	if _stratum_exit != null:
		_stratum_exit.call_deferred("activate")
	stratum_exit_unlocked.emit()
	boss_defeated.emit(boss, death_position)


func _spawn_stratum_exit() -> void:
	if stratum_exit_scene_path == "":
		return
	var packed: PackedScene = load(stratum_exit_scene_path) as PackedScene
	if packed == null:
		push_error(
			"Stratum2BossRoom: failed to load StratumExit scene at '%s'" % stratum_exit_scene_path
		)
		return
	var node: Node = packed.instantiate()
	if not node is StratumExit:
		push_error("Stratum2BossRoom: StratumExit scene root is not StratumExit")
		node.free()
		return
	_stratum_exit = node
	_stratum_exit.portal_position = stratum_exit_position
	add_child(_stratum_exit)


## Stage 6 (ticket `86c9y7ygj`) — lazy-spawn the BossNameplate CanvasLayer
## at room assembly. Reuses the S1 `res://scenes/ui/BossNameplate.tscn`
## banner (NOT a parallel S2 nameplate). Stays hidden (modulate.a = 0,
## offscreen above the top edge) until `_complete_entry_sequence` calls
## `show_for(boss)`. Adding it as a child of the room means the nameplate is
## freed cleanly when the room is freed — same lifecycle as the door trigger
## + stratum exit. Mirrors `Stratum1BossRoom._spawn_boss_nameplate` verbatim.
##
## Tests opt out by setting `boss_nameplate_scene_path = ""`. The
## `_complete_entry_sequence` `show_for` call guards on null + has_method so
## the room boots fine without the scene.
func _spawn_boss_nameplate() -> void:
	if boss_nameplate_scene_path == "":
		return
	var packed: PackedScene = load(boss_nameplate_scene_path) as PackedScene
	if packed == null:
		push_warning(
			"[Stratum2BossRoom] BossNameplate scene missing at '%s'" % boss_nameplate_scene_path
		)
		return
	var node: Node = packed.instantiate()
	if node == null:
		push_warning("[Stratum2BossRoom] BossNameplate failed to instantiate")
		return
	_boss_nameplate = node
	add_child(_boss_nameplate)


# ---- Diagnostics ------------------------------------------------------


func entry_sequence_elapsed_ms() -> int:
	if _entry_completed_time_ms == 0 or _entry_started_time_ms == 0:
		return -1
	return _entry_completed_time_ms - _entry_started_time_ms


func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


# ---- Audio cue wiring -------------------------------------------------


## Wire `entry_sequence_completed` to the boss-stratum-2 BGM crossfade.
## The S2 boss music `mus-boss-stratum2.ogg` is UNIQUE per DECISIONS.md
## 2026-05-15 — different composition from S1 boss music. Routes through
## the existing `AudioDirector.crossfade_to_boss_stratum2` API (landed
## with PR #210 / Sponsor S2 audio batch).
##
## Idempotent triple-wire guard mirrors S1 BossRoom pattern. Production
## wires once from `_ready`; tests can call `_wire_audio_cues()` without
## stacking handlers.
func _wire_audio_cues() -> void:
	if not entry_sequence_completed.is_connected(_on_entry_sequence_completed_audio):
		entry_sequence_completed.connect(_on_entry_sequence_completed_audio)


## Handler — fires when the 1.8 s entry sequence elapses. Crossfades the
## BGM bus to `mus-boss-stratum2.ogg` over the AudioDirector default
## 600 ms (Uma `boss-intro.md` Beat 5 / `audio-direction.md §3 ducking
## rule 4`). The crossfade composes cleanly with S2 stratum BGM (if
## active) — `crossfade_to_boss_stratum2` handles both the swap-case
## (S2 BGM playing) and the pure-fade-in case (no BGM active).
##
## Resolves AudioDirector lazily via the scene tree — soft no-op when
## the autoload is absent (bare-test surface).
func _on_entry_sequence_completed_audio() -> void:
	var ad: Node = _resolve_audio_director()
	if ad == null or not ad.has_method("crossfade_to_boss_stratum2"):
		return
	ad.crossfade_to_boss_stratum2()


func _resolve_audio_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioDirector")


# ---- Camera engagement ------------------------------------------------


## Engage CameraDirector continuous-scroll against the arena's wider
## bounds. Mirrors `Stratum1BossRoom._engage_camera_for_boss_room` shape
## with the Sentinel-arena ARENA_BOUNDS (1024×768) + ARENA_FOLLOW_DEADZONE
## (40×24, matches Main's authored value).
##
## Same call shape — soft-fail when CameraDirector autoload OR the
## player group is absent (bare-test surface).
func _engage_camera_for_boss_room() -> void:
	if not is_inside_tree():
		return
	var cd: Node = _resolve_camera_director()
	if cd == null:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if cd.has_method("follow_target"):
		cd.follow_target(player, ARENA_FOLLOW_DEADZONE)
	if cd.has_method("set_world_bounds"):
		cd.set_world_bounds(ARENA_BOUNDS)
	# Zoom OUT for the wider 1024×768 arena so combatants read at an
	# appropriate scale (Sponsor soak-round-2 "characters too big" fix —
	# diagnosed cause (b), see ARENA_CAMERA_ZOOM). anchor = Vector2.ZERO keeps
	# player-follow; the bounds-clamp above keeps the wider view inside the
	# arena. Instant (duration 0.0) since the player drops straight into the
	# arena via start_room=9 / production room-load — no easing beat needed.
	if cd.has_method("request_zoom"):
		cd.request_zoom(ARENA_CAMERA_ZOOM, ARENA_CAMERA_ZOOM_DURATION)


func _resolve_camera_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("CameraDirector")
