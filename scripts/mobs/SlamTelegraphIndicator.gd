class_name SlamTelegraphIndicator
extends Node2D
## Visible slam-telegraph danger-zone circle outline for Stratum1Boss.
##
## Source: M3 Tier 2 Wave 2 T5 (ticket `86c9wjyrc`). Spec lives in
## `team/priya-pl/m3-tier2-boss-room-polish-scope.md §3 T5` and is
## summarized in `Stratum1Boss.gd` § "M3 Tier 2 Wave 2 T5+T6" header.
##
## ## Why Node2D + draw_arc(), not Polygon2D
##
## The ticket title says "Polygon2D circle" but Polygon2D natively renders
## FILLED convex polygons — a circle OUTLINE requires either a 32-segment
## annulus polygon (32 outer + 32 inner verts) or a `_draw()` callback with
## `draw_arc()`. The latter is the canonical Godot 4 idiom and does NOT
## touch the `.claude/docs/html5-export.md §Polygon2D rendering quirks`
## failure class — that bug (PR #137 swing wedge) affects FILLED Polygon2D
## under gl_compatibility, not the canvas-item draw API.
##
## `draw_arc` renders identically on `forward_plus` (desktop) and
## `gl_compatibility` (HTML5) because it routes through the canvas-item
## draw command stream, not the polygon rasterizer.
##
## ## Drawing parameters
##
## - Radius: `Stratum1Boss.SLAM_HITBOX_RADIUS` (80 px). Read from the
##   constant on `_ready` so a future tuning change to the constant
##   automatically propagates.
## - Color: `Stratum1Boss.SLAM_INDICATOR_COLOR` = `#FF6A2A` at α=0.5.
##   Sub-1.0 RGB channels for HTML5 HDR-clamp safety (PR #137 lesson).
## - Line width: `Stratum1Boss.SLAM_INDICATOR_LINE_WIDTH` = 2 px.
## - Segments: `Stratum1Boss.SLAM_INDICATOR_ARC_POINTS` = 32 (smooth at 80 px).
##
## ## Alpha source-of-truth
##
## The `modulate` alpha is the fade-in/out animation channel — the parent
## boss's `_spawn_slam_indicator` tween writes `modulate:a` from 0.0 to 1.0
## (fade-in) and back to 0.0 (fade-out). The base color's alpha (0.5)
## multiplies through, so the perceived peak alpha is 0.5 and the perceived
## min is 0.0 — the desired "off / on at 0.5" envelope.
##
## ## Test conventions
##
## - The indicator is added as a child of the boss in `_spawn_slam_indicator`
##   and freed in `_fade_out_slam_indicator` / `_force_free_slam_indicator`.
## - GUT tests assert `get_node_or_null` for the type matches via the
##   `class_name SlamTelegraphIndicator` global, and assert
##   `is_queued_for_deletion()` on the indicator after slam-fire / boss-die.

const SLAM_HITBOX_RADIUS_CONST: float = 80.0  # mirrors Stratum1Boss.SLAM_HITBOX_RADIUS
const SLAM_INDICATOR_COLOR_CONST: Color = Color(1.0, 0.416, 0.165, 0.5)
const SLAM_INDICATOR_LINE_WIDTH_CONST: float = 2.0
const SLAM_INDICATOR_ARC_POINTS_CONST: int = 32


func _ready() -> void:
	# z_index = +1 so the indicator draws above floor + boss body but below
	# HUD. Per `.claude/docs/html5-export.md` § "Z-index sensitivity" — never
	# use negative z_index in gl_compatibility (sinks below room background).
	z_index = 1


func _draw() -> void:
	# draw_arc(center, radius, start_angle, end_angle, point_count, color, width).
	# Full circle = 0 → TAU. 32 points produces a smooth circle at 80 px radius.
	draw_arc(
		Vector2.ZERO,
		SLAM_HITBOX_RADIUS_CONST,
		0.0,
		TAU,
		SLAM_INDICATOR_ARC_POINTS_CONST,
		SLAM_INDICATOR_COLOR_CONST,
		SLAM_INDICATOR_LINE_WIDTH_CONST
	)
