class_name ProcgenSpike
extends Node2D
## M3 Tier 3 W1 — Procgen visual-proof spike (`86c9xub9p` Part C).
##
## **Visual-proof scene** that loads the S1 Outer Cloister worked-example
## ZoneDef (`s1_z1_outer_cloister.tres`) and a fixed `world_seed`, then
## runs `FloorAssembler.assemble_floor(...)` and RENDERS the resulting
## placement as a horizontal strip of chunks (anchors + procedural fill).
## Camera-scrolls across the assembly using the W1-shipped
## `CameraDirector.follow_target(...)` + `set_world_bounds(...)` API
## (the sibling spike — PR #314, ticket `86c9xu9yt`).
##
## ## What this scene proves
##
##   1. **Seed round-trip** (consumed by Part B GUT test
##      `test_world_seed_drives_identical_assemble_across_save_load`) —
##      a fixed seed produces the same placement on every boot. Visible
##      via the in-scene determinism diff trace (`[procgen-spike]
##      assemble | placement=...`).
##   2. **Anchor + procedural composition** — hand-authored anchors
##      (entry/npc_room/quest_target/boss_room/exit) interleave with
##      procedural fill (1..3 slots between consecutive anchors).
##      Visible via per-chunk color: anchor chunks render in a
##      stratum-1 sandstone family; procedural chunks render in a
##      slightly-cooler tone so the anchor / fill boundary is visually
##      legible during soak.
##   3. **HTML5 procedural-seam rendering** under `gl_compatibility`.
##      Chunk seams marked by 2-px ember-orange vertical lines (same
##      pattern as the camera-scroll spike). If z-index sharp edges
##      regress, the seam markers visibly drop behind chunk floors.
##   4. **R-PROCGEN.b empirical case** — the S1 worked-example zone
##      currently has one known port-mating error at the `s1_room01`
##      east seam (production chunk has only a WEST entry port; W2
##      retrofit fixes this). The spike scene RENDERS THE FLOOR
##      ANYWAY (assembler records-not-raises) so Sponsor can SEE the
##      pre-fix state. A HUD line surfaces the port_mating_errors
##      count + first error string.
##
## ## Activation pattern — same diag-build shape as PR #314
##
## This spike lives at `scenes/spike/ProcgenSpikeScene.tscn`. Activation:
##
##   1. `git checkout -b diag/procgen-spike-soak`
##   2. Edit `project.godot::run/main_scene =
##      "res://scenes/spike/ProcgenSpikeScene.tscn"`
##   3. `git commit -m "[diag-only] swap main_scene to procgen-spike — TEMPORARY (DO NOT MERGE)"`
##   4. `gh workflow run release-github.yml --ref diag/procgen-spike-soak`
##   5. Download artifact + extract to a fresh folder; serve via
##      `python -m http.server 8000`; open in incognito with DevTools.
##   6. WASD-walk the marker across the assembled floor; observe
##      camera-scroll, chunk seams, HUD trace lines.
##   7. `git push origin --delete diag/procgen-spike-soak` when done.
##
## Production `Main.tscn` is unaffected; the spec
## `tests/playwright/specs/procgen-spike.spec.ts` auto-skips when the
## production artifact boots.
##
## ## Cross-references
##
##   - `scripts/levels/FloorAssembler.gd` — Part A producer
##   - `resources/level/AssembledFloor.gd` — Part A output container
##   - `resources/level/zones/s1_z1_outer_cloister.tres` — worked-example zone
##   - `scripts/camera/CameraDirector.gd` — `follow_target` + `set_world_bounds` API
##   - `scripts/spike/CameraScrollSpike.gd` — sibling spike (HUD pattern)
##   - `.claude/docs/html5-export.md` § Diagnostic-build pattern + Z-index sensitivity
##   - `.claude/docs/camera-scroll.md` — follow_target API consumed here
##   - `.claude/docs/test-conventions.md` § Spike-class specs — paired Playwright shape


# ---- Tuning constants -------------------------------------------------


## Path to the worked-example ZoneDef from the merged zone-schema spike
## (`86c9xuap4`).
const ZONE_PATH: String = "res://resources/level/zones/s1_z1_outer_cloister.tres"

## Fixed `world_seed` for the spike — chosen so the assembled placement
## is non-trivial (9..17 chunks) without being absurdly long. Any int
## works; this seed was picked once and pinned so soak screenshots are
## reproducible.
const SPIKE_WORLD_SEED: int = 0xC10157E5  # "Cloister" themed, no other meaning

## Marker movement speed in world pixels/sec (matches camera-scroll spike).
const MARKER_SPEED: float = 180.0
const MARKER_SPRINT_MULT: float = 2.0

## Deadzone half-extents — same as camera-scroll spike for visual parity.
const DEADZONE: Vector2 = Vector2(40.0, 24.0)

## Floor visualization tones. Anchors render in the warm-sandstone S1
## family; procedural fill renders in a slightly-cooler tone so the
## anchor/fill alternation is legible during soak.
const ANCHOR_FLOOR_COLOR: Color = Color(0.45, 0.36, 0.27, 1.0)   # warm sandstone
const PROCEDURAL_FLOOR_COLOR: Color = Color(0.34, 0.32, 0.28, 1.0) # cooler grey-sand
const SEAM_MARKER_COLOR: Color = Color(1.0, 0.42, 0.16, 1.0)     # ember-orange
const SEAM_MARKER_WIDTH_PX: float = 2.0


# ---- Node refs --------------------------------------------------------


@onready var _world: Node2D = $World
@onready var _marker: CharacterBody2D = $PlayerMarker
@onready var _hud_build_label: Label = $HUD/BuildLabel
@onready var _hud_assemble_label: Label = $HUD/AssembleLabel
@onready var _hud_marker_pos_label: Label = $HUD/MarkerPosLabel
@onready var _hud_camera_pos_label: Label = $HUD/CameraPosLabel
@onready var _hud_mating_label: Label = $HUD/MatingLabel
@onready var _hud_chunks_label: Label = $HUD/ChunksLabel


# ---- Internal state ---------------------------------------------------


var _assembled: AssembledFloor


# ---- Lifecycle --------------------------------------------------------


func _ready() -> void:
	# 1. Load the worked-example ZoneDef.
	var zone_res: Resource = load(ZONE_PATH)
	if zone_res == null or not (zone_res is ZoneDef):
		push_warning("[ProcgenSpike] failed to load ZoneDef at %s — spike inactive" % ZONE_PATH)
		return
	var zone: ZoneDef = zone_res

	# 2. Derive zone-level seed from the spike's fixed world_seed.
	var stratum_seed: int = FloorAssembler.derive_stratum_seed(SPIKE_WORLD_SEED, zone.stratum_id)
	var zone_seed: int = FloorAssembler.derive_zone_seed(stratum_seed, zone.zone_id)

	# 3. Assemble.
	var assembler: FloorAssembler = FloorAssembler.new()
	_assembled = assembler.assemble_floor(zone, zone_seed)

	if _assembled == null or _assembled.is_empty():
		push_warning("[ProcgenSpike] assemble returned empty floor — spike inactive")
		return

	# 4. Render placed chunks into the World node.
	_render_placement(_assembled)

	# 5. Engage CameraDirector continuous-scroll + world-bounds clamp.
	var cd: Node = get_tree().root.get_node_or_null("CameraDirector")
	if cd == null:
		push_warning("[ProcgenSpike] CameraDirector autoload missing — camera-scroll inactive")
	else:
		# Spawn marker at the entry-anchor's left edge + 1 tile inset.
		var entry_pc: PlacedChunk = _assembled.placed_chunks[0]
		_marker.global_position = entry_pc.position_px + Vector2(
			float(entry_pc.size_px.x) * 0.25,
			float(entry_pc.size_px.y) * 0.5)
		if cd.has_method("follow_target"):
			cd.follow_target(_marker, DEADZONE)
		if cd.has_method("set_world_bounds"):
			cd.set_world_bounds(_assembled.bounding_box_px)

	# 6. Populate HUD.
	_populate_hud()

	# 7. Boot line — `[procgen-spike] ready` is the spec's activation
	#    detection regex.
	print(
		("[procgen-spike] ready zone=%s world_seed=%d zone_seed=%d chunks=%d"
			+ " bounds=(%.0f,%.0f,%.0f,%.0f) mating_errors=%d")
		% [
			String(zone.zone_id), SPIKE_WORLD_SEED, zone_seed,
			_assembled.chunk_count(),
			_assembled.bounding_box_px.position.x, _assembled.bounding_box_px.position.y,
			_assembled.bounding_box_px.size.x, _assembled.bounding_box_px.size.y,
			_assembled.port_mating_errors.size(),
		]
	)

	# 8. Determinism diff — emit the assembled placement vector so a
	#    re-soak with the same seed can confirm bit-identical output via
	#    DevTools console diff (the Playwright spec also asserts on this).
	var placement_strs: PackedStringArray = PackedStringArray()
	for pc: PlacedChunk in _assembled.placed_chunks:
		placement_strs.append("%s@%.0f" % [String(pc.chunk_id), pc.position_px.x])
	print(
		"[procgen-spike] assemble | placement=%s"
		% ",".join(placement_strs)
	)
	if not _assembled.port_mating_errors.is_empty():
		print(
			"[procgen-spike] port_mating_errors | count=%d first=%s"
			% [_assembled.port_mating_errors.size(), _assembled.port_mating_errors[0]]
		)


func _exit_tree() -> void:
	# Tear down our follow + bounds when the scene unloads so other tests
	# that share this autoload start from a clean baseline.
	var cd: Node = get_tree().root.get_node_or_null("CameraDirector")
	if cd == null:
		return
	if cd.has_method("clear_follow_target"):
		cd.clear_follow_target()
	if cd.has_method("clear_world_bounds"):
		cd.clear_world_bounds()


func _physics_process(_delta: float) -> void:
	if _marker == null:
		return
	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1.0
	var speed: float = MARKER_SPEED
	if Input.is_action_pressed("sprint"):
		speed *= MARKER_SPRINT_MULT
	_marker.velocity = input_dir.normalized() * speed
	_marker.move_and_slide()


func _process(_delta: float) -> void:
	if _marker != null and _hud_marker_pos_label != null:
		_hud_marker_pos_label.text = "marker=(%.0f, %.0f)" % [
			_marker.global_position.x, _marker.global_position.y]
	var cd: Node = get_tree().root.get_node_or_null("CameraDirector")
	if cd != null and cd.has_method("get_camera") and _hud_camera_pos_label != null:
		var cam: Camera2D = cd.get_camera()
		if cam != null:
			_hud_camera_pos_label.text = "camera=(%.0f, %.0f)" % [
				cam.global_position.x, cam.global_position.y]


# ---- Rendering --------------------------------------------------------


## Spawn ColorRect floor nodes + seam markers + per-chunk labels for every
## placed chunk in the assembled floor. Anchors get the warm sandstone
## tone; procedural fills get the cooler grey-sand. Seam markers fire
## between every consecutive pair.
func _render_placement(floor: AssembledFloor) -> void:
	if _world == null:
		return
	for i: int in range(floor.placed_chunks.size()):
		var pc: PlacedChunk = floor.placed_chunks[i]
		_spawn_floor_chunk(pc, i)
		# Seam marker AFTER this chunk (between this chunk and the next),
		# except after the last placement (no seam at the right world edge).
		if i < floor.placed_chunks.size() - 1:
			var seam_x: float = pc.position_px.x + float(pc.size_px.x) - SEAM_MARKER_WIDTH_PX * 0.5
			_spawn_seam_marker(seam_x, float(pc.size_px.y))


## Spawn one chunk's floor + label + (if anchor) anchor-tag pip.
func _spawn_floor_chunk(pc: PlacedChunk, index: int) -> void:
	var floor: ColorRect = ColorRect.new()
	floor.position = pc.position_px
	floor.size = Vector2(float(pc.size_px.x), float(pc.size_px.y))
	floor.color = ANCHOR_FLOOR_COLOR if pc.kind == &"anchor" else PROCEDURAL_FLOOR_COLOR
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor.z_index = 0
	_world.add_child(floor)

	# Center label — chunk_id + (anchor room_id if present).
	var label: Label = Label.new()
	label.position = pc.position_px + Vector2(
		float(pc.size_px.x) * 0.5 - 60.0,
		float(pc.size_px.y) * 0.5 - 16.0)
	label.size = Vector2(120.0, 32.0)
	var label_text: String = "[%d] %s" % [index, String(pc.chunk_id)]
	if pc.kind == &"anchor" and pc.anchor_room_id != &"":
		label_text += "\n%s" % String(pc.anchor_room_id)
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1
	_world.add_child(label)


## Spawn a 2-px ember-orange seam marker between two chunks.
func _spawn_seam_marker(seam_x: float, height: float) -> void:
	var seam: ColorRect = ColorRect.new()
	seam.position = Vector2(seam_x, 0.0)
	seam.size = Vector2(SEAM_MARKER_WIDTH_PX, height)
	seam.color = SEAM_MARKER_COLOR
	seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# +1 above floor so the seam stays visible if z-index ordering shifts
	# under gl_compatibility (per `html5-export.md` § Z-index sensitivity).
	seam.z_index = 2
	_world.add_child(seam)


# ---- HUD --------------------------------------------------------------


func _populate_hud() -> void:
	# Build SHA (sanity-check the right artifact loaded).
	var bi: Node = get_tree().root.get_node_or_null("BuildInfo")
	var sha: String = ""
	if bi != null and "short_sha" in bi:
		sha = String(bi.short_sha)
	if _hud_build_label != null:
		_hud_build_label.text = "[ProcgenSpike] build=%s" % (sha if sha != "" else "dev")

	# Assemble summary.
	if _hud_assemble_label != null:
		_hud_assemble_label.text = (
			"seed=%d chunks=%d (anchors=%d procedural=%d)"
			% [
				SPIKE_WORLD_SEED,
				_assembled.chunk_count(),
				_assembled.anchor_count(),
				_assembled.procedural_count(),
			]
		)

	# Port-mating summary — `0 errors` is the W2-retrofit target;
	# `≥1` is the R-PROCGEN.b empirical state (expected pre-W2).
	if _hud_mating_label != null:
		if _assembled.port_mating_errors.is_empty():
			_hud_mating_label.text = "port_mating_errors=0 (well-mated)"
			_hud_mating_label.add_theme_color_override(
				"font_color", Color(0.5, 0.85, 0.45, 1.0))  # green
		else:
			_hud_mating_label.text = "port_mating_errors=%d (R-PROCGEN.b — first: %s)" % [
				_assembled.port_mating_errors.size(),
				_assembled.port_mating_errors[0],
			]
			_hud_mating_label.add_theme_color_override(
				"font_color", Color(1.0, 0.7, 0.3, 1.0))  # amber

	# Bounds + chunk count.
	if _hud_chunks_label != null:
		_hud_chunks_label.text = "bounds=(%.0f,%.0f,%.0f,%.0f) chunks=%d" % [
			_assembled.bounding_box_px.position.x,
			_assembled.bounding_box_px.position.y,
			_assembled.bounding_box_px.size.x,
			_assembled.bounding_box_px.size.y,
			_assembled.chunk_count(),
		]
