class_name ArchiveSentinelBlinkVfx
extends Node2D
## Phase-blink reposition VFX for ArchiveSentinel (cosmetic — no damage, no
## collision).
##
## Source: ticket `86c9y7ygj` Stage 6 phase-blink revision (Sponsor 2026-05-30
## soak of `38e0ecb`). Binding spec: `team/uma-ux/palette-stratum-2.md` §5.5a
## "Archive Sentinel phase-blink reposition". The Sentinel no longer walks/
## chases — it **phase-shifts** (teleports) between fixed plinth-points between
## cast volleys. The reposition itself is an instant `global_position` set on the
## construct; THIS node renders the 3-beat "phase-shift, not generic teleport"
## visual at BOTH endpoints so the blink reads as a traversal.
##
## ## 3-beat effect (Uma §5.5a item 2, total ~520 ms)
##
## - **Departure (~140 ms)** — ember-dissolve UP at the departure plinth:
##   rising `#FF6A2A` ember motes + 4-6 parchment-tan `#A89270` "archive-glyph"
##   flecks scatter outward (reads as "pages losing their place"). The departure
##   point's construct body alpha-fade is owned by ArchiveSentinel (NOT hide()).
## - **Travel gap (~80 ms)** — a `#C25A1F` ash-glow floor-seam shimmer runs
##   along the line from departure → arrival via `_draw()` polyline (NOT
##   Polygon2D — `.claude/docs/html5-export.md` § "Shape OUTLINES"). This is
##   the only cue "it went *that* way."
## - **Arrival (~140 ms + ~160 ms pre-roll)** — ember motes converge DOWN onto
##   the arrival plinth + a faint book-eye pre-glow appears during the travel-
##   gap's tail (the read/punish window). Book-eye re-ignites last; a ≤50 ms
##   warm-white `#FFF2BF` impact-flare frame breaks the ember-on-floor blend
##   (PR #291 v5/v7 finding).
##
## ## Why this node owns the seam-shimmer + motes, ArchiveSentinel owns the body
##
## The construct's own `modulate.a` dissolve/reform (the body fade) stays on
## ArchiveSentinel because it must round-trip the exact rest alpha and survive
## death-mid-blink. This node owns everything that lives in WORLD space between
## the two plinths (motes, flecks, floor-seam) — it is room-parented + deferred-
## add (physics-flush rule; `_fire_blink` runs from `_physics_process`).
##
## All channels sub-1.0 (HTML5 HDR-clamp safe — Uma §5.5a verified the hexes).
## Floor-seam is a `_draw()` polyline; everything else is CPUParticles2D +
## ColorRect — all renderer-safe primitives.

# ---- Color channels (Uma §5.5a item 2, all sub-1.0) -------------------

## Rising ember motes — `#FF6A2A` (player-flame / vein-core hex, diegetic
## "returns to the substance it's made of").
const EMBER_MOTE_COLOR: Color = Color(1.0, 0.416, 0.165, 1.0)  # #FF6A2A

## Archive-glyph flecks — parchment-tan `#A89270` ("pages losing their place").
const GLYPH_FLECK_COLOR: Color = Color(0.659, 0.573, 0.439, 1.0)  # #A89270

## Floor-seam shimmer — ash-glow vein-mid `#C25A1F`.
const SEAM_COLOR: Color = Color(0.761, 0.353, 0.122, 1.0)  # #C25A1F

## Book-eye pre-glow + impact-flare — warm-white `#FFF2BF` (reuses PR #291 v7
## AFTERSHOCK_FLASH_WHITE-class; every channel < 1.0).
const IMPACT_FLARE_COLOR: Color = Color(1.0, 0.949, 0.749, 1.0)  # #FFF2BF

# ---- Beat timings (Uma §5.5a — feel targets) --------------------------

const DEPART_DURATION: float = 0.140
const TRAVEL_GAP_DURATION: float = 0.080
const ARRIVAL_DURATION: float = 0.140
## Arrival telegraph pre-roll — motes begin converging + book-eye pre-glow this
## long BEFORE the body reforms (the read/punish window, Uma §5.5a item 3).
const ARRIVAL_TELEGRAPH_PREROLL: float = 0.160

## Total wall-clock the VFX node lives (for the safety-net free).
const TOTAL_DURATION: float = DEPART_DURATION + TRAVEL_GAP_DURATION + ARRIVAL_DURATION

# ---- Particle / draw tuning -------------------------------------------

const MOTE_COUNT_DEPART: int = 18
const MOTE_COUNT_ARRIVE: int = 18
const GLYPH_FLECK_COUNT: int = 6  # 4-6 per Uma §5.5a — use the upper bound
const MOTE_Z_INDEX: int = 1  # above floor + construct (PR #291 T6 occlusion)
const SEAM_LINE_WIDTH: float = 2.0  # 2-px polyline per Uma §5.5a

## Pre-glow disc size at the arrival plinth (book-eye pre-glow telegraph).
const PREGLOW_SIZE: Vector2 = Vector2(22.0, 22.0)
const PREGLOW_PEAK_ALPHA: float = 0.55

var _depart_pos: Vector2 = Vector2.ZERO
var _arrival_pos: Vector2 = Vector2.ZERO
var _seam_alpha: float = 0.0
var _preglow: ColorRect = null
var _tween: Tween = null


## Configure before add_child. `depart_pos` / `arrival_pos` are the two plinth
## world positions; the construct teleports between them, this node renders the
## traversal cue.
func configure(depart_pos: Vector2, arrival_pos: Vector2) -> void:
	_depart_pos = depart_pos
	_arrival_pos = arrival_pos


func _ready() -> void:
	z_index = MOTE_Z_INDEX
	# Departure burst — ember motes rise UP + archive-glyph flecks scatter.
	_spawn_depart_motes()
	_spawn_glyph_flecks()
	# Arrival pre-glow — book-eye pre-glow telegraph at the destination plinth
	# during the travel-gap tail (the read/punish window). Fades up over the
	# preroll, holds, then the convergence motes land on it.
	_spawn_arrival_preglow()
	_spawn_arrival_motes()

	# Floor-seam shimmer — animate `_seam_alpha` 0 → peak → 0 across the travel
	# gap; `_draw` reads it. queue_redraw on each step (geometry is static, but
	# alpha drives the polyline visibility window).
	_tween = create_tween()
	_tween.tween_method(_set_seam_alpha, 0.0, 1.0, TRAVEL_GAP_DURATION * 0.5)
	_tween.tween_method(_set_seam_alpha, 1.0, 0.0, TRAVEL_GAP_DURATION * 0.5)
	_tween.tween_callback(queue_free)

	# Safety-net free even if the tween hangs (mob death-tween net convention).
	var safety: SceneTreeTimer = get_tree().create_timer(
		TOTAL_DURATION + ARRIVAL_TELEGRAPH_PREROLL + 0.3
	)
	safety.timeout.connect(_safety_free)

	_emit_visible_trace()


func _set_seam_alpha(a: float) -> void:
	_seam_alpha = a
	queue_redraw()


## Floor-seam shimmer polyline between the two plinths. `_draw()` + draw_polyline
## (NOT Polygon2D) per `.claude/docs/html5-export.md` § "Shape OUTLINES" + Uma
## §5.5a hard rule. Positions are world-space; the node sits at origin (0,0).
func _draw() -> void:
	if _seam_alpha <= 0.0:
		return
	var col: Color = SEAM_COLOR
	col.a = SEAM_COLOR.a * _seam_alpha
	draw_polyline([_depart_pos, _arrival_pos], col, SEAM_LINE_WIDTH, true)


func _spawn_depart_motes() -> void:
	var burst: CPUParticles2D = _make_mote_burst(_depart_pos, EMBER_MOTE_COLOR, MOTE_COUNT_DEPART)
	burst.direction = Vector2.UP
	burst.gravity = Vector2(0.0, -90.0)  # rise UP (returns to substance)
	burst.lifetime = DEPART_DURATION + 0.05
	add_child(burst)


func _spawn_glyph_flecks() -> void:
	var burst: CPUParticles2D = _make_mote_burst(_depart_pos, GLYPH_FLECK_COLOR, GLYPH_FLECK_COUNT)
	burst.direction = Vector2.UP
	burst.spread = 180.0  # scatter outward (pages losing their place)
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 120.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 1.5
	burst.lifetime = DEPART_DURATION + 0.10
	add_child(burst)


func _spawn_arrival_motes() -> void:
	# Motes converge DOWN onto the arrival plinth (reverse of departure). Spawn a
	# ring slightly above + around the arrival point with inward/downward gravity.
	var burst: CPUParticles2D = _make_mote_burst(
		_arrival_pos + Vector2(0.0, -28.0), EMBER_MOTE_COLOR, MOTE_COUNT_ARRIVE
	)
	burst.direction = Vector2.DOWN
	burst.gravity = Vector2(0.0, 140.0)  # converge DOWN onto the plinth
	burst.spread = 60.0
	burst.lifetime = ARRIVAL_DURATION + 0.05
	add_child(burst)


func _spawn_arrival_preglow() -> void:
	# Book-eye pre-glow at the arrival plinth — warm-white disc that fades up
	# during the travel-gap (the ~160ms read window), then winks as the body
	# reforms. ColorRect (renderer-safe) centered on the arrival point.
	_preglow = ColorRect.new()
	_preglow.color = IMPACT_FLARE_COLOR
	_preglow.size = PREGLOW_SIZE
	_preglow.position = _arrival_pos - PREGLOW_SIZE * 0.5
	_preglow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_preglow.z_index = MOTE_Z_INDEX
	add_child(_preglow)
	var pg_tween: Tween = create_tween()
	# Fade up over the pre-roll (the telegraph), hold, then wink out as the
	# body re-coheres.
	pg_tween.tween_property(_preglow, "modulate:a", PREGLOW_PEAK_ALPHA, ARRIVAL_TELEGRAPH_PREROLL)
	pg_tween.tween_property(_preglow, "modulate:a", PREGLOW_PEAK_ALPHA, ARRIVAL_DURATION * 0.5)
	pg_tween.tween_property(_preglow, "modulate:a", 0.0, ARRIVAL_DURATION * 0.5)


func _make_mote_burst(world_pos: Vector2, color: Color, count: int) -> CPUParticles2D:
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.global_position = world_pos
	burst.z_index = MOTE_Z_INDEX
	burst.amount = max(1, count)
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.emitting = true
	burst.spread = 45.0
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 110.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 2.5
	burst.color = color
	return burst


## Renderer-observable visibility trace — emitted from `_ready` so the values are
## renderer-truth (node in tree, z set, seam endpoints set). Regression guard for
## the Sponsor "blink not visible" class; node-presence is assertable headless,
## human-perceptibility stays the Sponsor-soak gate.
func _emit_visible_trace() -> void:
	if not is_inside_tree():
		return
	var df: Node = get_tree().root.get_node_or_null("DebugFlags")
	if df == null or not df.has_method("combat_trace"):
		return
	(
		df
		. combat_trace(
			"ArchiveSentinelBlinkVfx._ready",
			(
				"VISIBLE blink depart=(%.0f,%.0f) arrival=(%.0f,%.0f) z=%d preglow=%s"
				% [
					_depart_pos.x,
					_depart_pos.y,
					_arrival_pos.x,
					_arrival_pos.y,
					z_index,
					str(_preglow != null),
				]
			)
		)
	)


func _safety_free() -> void:
	if not is_queued_for_deletion():
		queue_free()
