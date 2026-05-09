class_name Stratum1Room01
extends Node2D
## Stratum-1, room 01 — the player's first encounter with Embergrave's
## tutorial loop. Single-chunk room loaded via `LevelAssembler`. Spawns
## the chunk's authored mobs (Stage 2b: a single PracticeDummy, no grunts)
## and drives the WASD / Space / LMB / RMB tutorial-prompt sequence per
## Uma `team/uma-ux/player-journey.md` Beats 4-5.
##
## **Stage 2b changes (ticket `86c9qaj3u`):**
##   - Mob roster: 1 `practice_dummy` (was: 2 grunts that broke the cold-open
##     non-threatening intro per Uma's spec).
##   - TutorialEventBus emits: room-entry → `&"wasd"` → first-movement →
##     `&"dodge"` → first-dodge → `&"lmb_strike"` → dummy-poof → `&"rmb_heavy"`.
##   - PracticeDummy drops a guaranteed iron_sword on death — the player
##     walks into Room02 already equipped (design-correct path retiring
##     PR #146's boot-equip bandaid; bandaid stays in main this PR per
##     dispatch scope).
##   - Door-open + room-clear flow is unchanged: Main's
##     `_install_room01_clear_listener` counts the dummy via the same
##     `mob_died` signal Grunt fires, so Room01 still advances to Room02
##     when the dummy poofs.
##
## **Why the room script drives tutorial beats (not Player.gd, not Main.gd):**
##   - Room01 is the only place the WASD/dodge/LMB/RMB sequence is wanted —
##     a Player-level emit would fire on every room. Anchoring in the
##     Stage1Room01 script keeps the tutorial entirely scoped to first-room
##     entry.
##   - Beat advancement reads Player signals (`damaged` / `mob_died` on the
##     dummy, `attack_spawned` for LMB landed) so we don't have to peek into
##     Player private state. One subscriber, one room, scope-correct.
##
## M1 acceptance criteria touched here:
##   - AC2 ("player can engage one grunt in stratum 1's first room") — moved
##     to Room02 in Stage 2b: AC2 in M1's original framing was "first kill
##     within 60s," which the dummy now satisfies (and the iron_sword drop
##     primes the Room02 grunt fight).
##   - AC4 (combat math vs grunt — covered in Room02 onward).
##
## See `team/drew-dev/level-chunks.md` and Uma's `visual-direction.md`
## (480x270 internal canvas).

# ---- Tutorial beat IDs (mirror TutorialEventBus.BEAT_TEXTS) ------------
##
## StringName constants so we don't open-code the literals in three places
## (room-entry / movement-detected / dodge-detected / dummy-poof). Devon's
## TutorialEventBus reserves these in `BEAT_TEXTS`; we resolve text via the
## bus, never hard-code copy here.

const BEAT_WASD: StringName = &"wasd"
const BEAT_DODGE: StringName = &"dodge"
const BEAT_LMB: StringName = &"lmb_strike"
const BEAT_RMB: StringName = &"rmb_heavy"

## Anchor for tutorial prompts in Beats 4-5. Uma's spec ("centered low,
## white text 60% opacity, no panel background") = BOTTOM = 2 in the
## TutorialPromptOverlay.AnchorPos enum (CENTER_TOP=0, CENTER=1, BOTTOM=2).
## Pass as int because autoload signals cross script-class boundaries.
const TUTORIAL_ANCHOR_BOTTOM: int = 2

## Player movement is detected by sampling velocity squared per tick. We
## treat anything with velocity_squared > MOVEMENT_THRESHOLD_SQ as "moved."
## The 30 px/s threshold (squared = 900) is a generous floor that filters
## any single-frame jitter or knockback drift but registers a deliberate
## WASD press immediately (WALK_SPEED = 120 px/s, well above threshold).
const MOVEMENT_THRESHOLD_SQ: float = 900.0

# ---- Inspector --------------------------------------------------------

## The chunk this room loads. Either set in the .tscn at author time or
## injected at runtime by tests.
@export var chunk_def: LevelChunkDef

## res:// path to the Grunt scene. Indirected via export so tests can swap
## in a marker fake without coupling the assembler to Grunt's spec.
##
## **Stage 2b note:** Room01 no longer spawns grunts (chunk_def carries a
## `practice_dummy` spawn instead) — the export is preserved for tests
## that historically swapped it in for marker-style fakes. The factory
## ladder below still recognizes &"grunt" so a test can re-add a grunt
## spawn to the chunk if it needs to.
@export_file("*.tscn") var grunt_scene_path: String = "res://scenes/mobs/Grunt.tscn"

## res:// path to the PracticeDummy scene (Stage 2b). Indirected via export
## so tests can swap in a marker fake.
@export_file("*.tscn") var practice_dummy_scene_path: String = "res://scenes/mobs/PracticeDummy.tscn"

## res:// path to the Grunt MobDef.
@export_file("*.tres") var grunt_mob_def_path: String = "res://resources/mobs/grunt.tres"

# Cached loads to avoid re-parsing the scene / TRES per spawn.
var _grunt_scene_cache: PackedScene = null
var _grunt_def_cache: MobDef = null
var _practice_dummy_scene_cache: PackedScene = null

# The assembled result, exposed for tests / save code that wants to
# enumerate spawned mobs after `_ready`.
var _assembly: LevelAssembler.AssemblyResult = null

# ---- Tutorial flow runtime ------------------------------------------

# One-shot latches per beat — `request_beat` is idempotent at the bus level
# but we still gate per-beat so a chatty signal source can't re-fire the
# same prompt repeatedly. Mirrors the FIFO "one prompt at a time" rule
# (Uma cross-cutting #6 / TutorialPromptOverlay's replace-on-new-show).
var _wasd_emitted: bool = false
var _dodge_emitted: bool = false
var _lmb_emitted: bool = false
var _rmb_emitted: bool = false

# Subscribed-to player ref for movement / dodge / attack-detection. Resolved
# in `_ready` via the "player" group (set by Player._ready) — same lookup
# pattern Grunt uses. Stored so we can clean up signal connections on exit.
var _player: Player = null


func _ready() -> void:
	if chunk_def == null:
		# Fallback: try the canonical M1 chunk. Logged so a missing assignment
		# surfaces loudly.
		chunk_def = load("res://resources/level_chunks/s1_room01.tres") as LevelChunkDef
	if chunk_def == null:
		push_error("Stratum1Room01: no chunk_def assigned and fallback load failed")
		return
	_build()
	# Defer tutorial-flow wiring to next-frame so Main._load_room_at_index has
	# fully re-parented the player into this room before we resolve `_player`.
	# Mirrors the `Stratum1BossRoom._ready → call_deferred("trigger_entry_sequence")`
	# pattern from the `.claude/docs/combat-architecture.md` § "Room-load
	# triggers vs body_entered triggers" rule.
	call_deferred("_wire_tutorial_flow")


func _build() -> void:
	var assembler: LevelAssembler = LevelAssembler.new()
	var spawner: Callable = Callable(self, "_spawn_mob")
	_assembly = assembler.assemble_single(chunk_def, spawner)
	if _assembly == null:
		return
	add_child(_assembly.root)


# ---- Public API -------------------------------------------------------

func get_assembly() -> LevelAssembler.AssemblyResult:
	return _assembly


func get_bounds_px() -> Rect2:
	if _assembly == null:
		return Rect2()
	return _assembly.bounds_px


func get_spawned_mobs() -> Array[Node]:
	if _assembly == null:
		return []
	return _assembly.mobs


## Test-only access to the per-beat emit-once latches. Tests assert the
## emission sequence (WASD → dodge → LMB → RMB) without polling the bus.
func get_tutorial_beat_emitted(beat_id: StringName) -> bool:
	match beat_id:
		BEAT_WASD: return _wasd_emitted
		BEAT_DODGE: return _dodge_emitted
		BEAT_LMB: return _lmb_emitted
		BEAT_RMB: return _rmb_emitted
		_: return false


# ---- Spawner ----------------------------------------------------------

func _spawn_mob(mob_id: StringName, _world_pos: Vector2) -> Node:
	# Stage 2b: factory recognizes both &"grunt" (legacy / tests) and
	# &"practice_dummy" (the new tutorial entity). The shipped chunk_def
	# spawns only practice_dummy; grunt remains a valid mob_id so a test
	# that swaps the chunk_def can still get a grunt instantiated here.
	if mob_id == &"practice_dummy":
		var dummy_scene: PackedScene = _get_practice_dummy_scene()
		if dummy_scene == null:
			push_warning("Stratum1Room01: practice_dummy scene failed to load at '%s'" % practice_dummy_scene_path)
			return null
		return dummy_scene.instantiate()
	if mob_id == &"grunt":
		var scene: PackedScene = _get_grunt_scene()
		if scene == null:
			push_warning("Stratum1Room01: grunt scene failed to load at '%s'" % grunt_scene_path)
			return null
		var node: Node = scene.instantiate()
		var def: MobDef = _get_grunt_def()
		if def != null:
			(node as Grunt).mob_def = def
		return node
	push_warning("Stratum1Room01: unknown mob_id '%s' — no factory entry" % mob_id)
	return null


func _get_grunt_scene() -> PackedScene:
	if _grunt_scene_cache != null:
		return _grunt_scene_cache
	if grunt_scene_path == "":
		return null
	_grunt_scene_cache = load(grunt_scene_path) as PackedScene
	return _grunt_scene_cache


func _get_grunt_def() -> MobDef:
	if _grunt_def_cache != null:
		return _grunt_def_cache
	if grunt_mob_def_path == "":
		return null
	_grunt_def_cache = load(grunt_mob_def_path) as MobDef
	return _grunt_def_cache


func _get_practice_dummy_scene() -> PackedScene:
	if _practice_dummy_scene_cache != null:
		return _practice_dummy_scene_cache
	if practice_dummy_scene_path == "":
		return null
	_practice_dummy_scene_cache = load(practice_dummy_scene_path) as PackedScene
	return _practice_dummy_scene_cache


# ---- Tutorial flow wiring -------------------------------------------

## Resolve the player + the spawned dummy, fire the WASD beat, and wire the
## detection chain that advances through dodge → LMB → RMB.
##
## Detection model (signal-driven where possible, polling fallback only for
## movement which has no Player-level "started moving" signal):
##   - WASD beat: fired immediately at room-entry.
##   - dodge beat: fired on first movement detected via `_physics_process`
##     polling Player.velocity. Latched.
##   - lmb_strike beat: fired on first dodge — `Player.iframes_started` is
##     the first signal that fires inside `try_dodge`.
##   - rmb_heavy beat: fired on dummy `mob_died` (the dummy poofs after
##     the third LMB hit at FIST_DAMAGE=1).
func _wire_tutorial_flow() -> void:
	# Resolve the player via the "player" group (set by Player._ready).
	if not is_inside_tree():
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Player:
		_player = players[0] as Player
	# Fire the first beat unconditionally — the WASD prompt must show on
	# room-entry whether or not the player has moved yet.
	_emit_beat(BEAT_WASD)
	if _player != null:
		# Subscribe dodge → LMB beat (Player.iframes_started fires inside
		# try_dodge — the moment a dodge actually starts, before the cooldown
		# tick). Connect-once guard via is_connected.
		if not _player.iframes_started.is_connected(_on_player_iframes_started):
			_player.iframes_started.connect(_on_player_iframes_started)
	# Subscribe to the dummy's mob_died — dummy poof advances to RMB beat.
	for m: Node in get_spawned_mobs():
		if m is PracticeDummy:
			var pd: PracticeDummy = m as PracticeDummy
			if not pd.mob_died.is_connected(_on_practice_dummy_died):
				pd.mob_died.connect(_on_practice_dummy_died)


# Per-physics-tick polling for movement detection. Cheaper to poll than to
# add a Player.movement_started signal (and avoids drift in a single-
# subscriber tutorial flow) — once `_dodge_emitted` flips true the polling
# stops mattering because the WASD/dodge advancement is complete.
func _physics_process(_delta: float) -> void:
	if _dodge_emitted:
		# Once the movement→dodge prompt advance has fired, no further polling
		# is needed. Also short-circuit when player ref is missing (test bare).
		return
	if _player == null:
		return
	# Movement detected when the player is actually moving (not just standing
	# in idle with velocity ≈ 0). 30 px/s squared threshold.
	if _player.velocity.length_squared() > MOVEMENT_THRESHOLD_SQ:
		_emit_beat(BEAT_DODGE)


# ---- Tutorial flow signal handlers ----------------------------------

## Player started a dodge i-frame window. Fires `lmb_strike` beat.
##
## **Why iframes_started, not state_changed:** `state_changed` fires on
## EVERY transition (idle ↔ walk happens dozens of times pre-first-attack);
## `iframes_started` only fires inside `try_dodge`, which is exactly the
## "player just dodged" semantics we want.
func _on_player_iframes_started() -> void:
	_emit_beat(BEAT_LMB)


## PracticeDummy poofed (HP=0). Fires `rmb_heavy` beat — the player has
## proven they can land an LMB strike, the door is grinding open, time to
## introduce heavy attacks.
##
## Args mirror Grunt.mob_died (mob, position, mob_def). We don't read any
## of them — payload is unused by the prompt advance.
func _on_practice_dummy_died(_mob: Variant, _pos: Variant, _def: Variant) -> void:
	_emit_beat(BEAT_RMB)


# ---- Beat emission helper -----------------------------------------

## Resolve which one-shot latch to flip + call into TutorialEventBus.
## Keeps the latch + bus call in one place so a "did I just emit X already?"
## check can never drift between caller and emitter.
##
## Returns true if the beat fired (latch flipped), false if it was a no-op
## because the beat had already fired this room-entry.
func _emit_beat(beat_id: StringName) -> bool:
	# Per-beat latch — replace-on-new-show is the overlay's job (FIFO); the
	# room script's job is "fire each beat at most once per room-entry."
	match beat_id:
		BEAT_WASD:
			if _wasd_emitted: return false
			_wasd_emitted = true
		BEAT_DODGE:
			if _dodge_emitted: return false
			_dodge_emitted = true
		BEAT_LMB:
			if _lmb_emitted: return false
			_lmb_emitted = true
		BEAT_RMB:
			if _rmb_emitted: return false
			_rmb_emitted = true
		_:
			return false
	var bus: Node = _bus_node()
	if bus == null:
		return false
	if bus.has_method("request_beat"):
		bus.call("request_beat", beat_id, TUTORIAL_ANCHOR_BOTTOM)
	return true


func _bus_node() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("TutorialEventBus")
