class_name ArchiveSentinelSlamIndicator
extends Node2D
## Visible slam-telegraph danger-zone circle outline for ArchiveSentinel.
##
## Source: W3-T7 Stage 5 (ticket `86c9y7ygj` Part D). Sibling of
## `scripts/mobs/SlamTelegraphIndicator.gd` — same `_draw()` + `draw_arc()`
## pattern but with the Sentinel-specific wider slam radius (96 px vs S1
## Boss's 80 px) per Uma `palette-stratum-2.md` §5.5: "Circle outline in
## `#FF6A2A` ember-accent at radius matched to S1 boss slam" — Stage 5
## widens this to 96 px because the Sentinel is rooted to its plinth and
## the player has more arena to back off into; a wider AOE is fair when
## the boss cannot pursue.
##
## ## Why a separate class, not parameterized
##
## The S1 Boss `SlamTelegraphIndicator` hard-codes its constants. Adding
## exported `@export var radius / color / arc_points` to the existing
## class would change its draw shape on every instantiation site (the S1
## boss + any future consumer), risking a silent regression on the S1
## boss surface. A separate class with its own constants leaves the S1
## boss draw unchanged while letting the Sentinel ship its own AOE shape.
## Future bosses with distinct slam radii (Stratum-3+) follow the same
## sibling-class pattern.
##
## ## Drawing parameters (Stage 5 ship state)
##
## - Radius: 96 px (mirrors `ArchiveSentinel.SLAM_HITBOX_RADIUS`). If the
##   constant ever drifts, this hard-coded mirror surfaces in the GUT
##   pin (`test_archive_sentinel_slam_indicator_radius_matches_hitbox`).
## - Color: `#FF6A2A` at α=0.5 — same ember-orange as S1 Boss indicator
##   per Uma §5.5 ("matched to S1 boss slam"). Sub-1.0 RGB channels for
##   HTML5 HDR-clamp safety (PR #137 lesson).
## - Line width: 2 px (same as S1 Boss indicator).
## - Segments: 32 (smooth at this radius).
##
## ## Alpha source-of-truth
##
## The `modulate` alpha is the fade-in/out + strobe animation channel —
## the parent ArchiveSentinel's `_spawn_slam_indicator` tween writes
## `modulate:a` via the same shape S1 Boss uses (fade-in then strobe at
## 5 Hz across the hold window). Base color's α=0.5 multiplies through.
##
## ## z_index
##
## +1 so the indicator draws above the room floor + Sentinel body but
## below HUD. Per `.claude/docs/html5-export.md` § "Z-index sensitivity".

const SLAM_HITBOX_RADIUS_CONST: float = 96.0  # mirrors ArchiveSentinel.SLAM_HITBOX_RADIUS
const SLAM_INDICATOR_COLOR_CONST: Color = Color(1.0, 0.416, 0.165, 0.5)
const SLAM_INDICATOR_LINE_WIDTH_CONST: float = 2.0
const SLAM_INDICATOR_ARC_POINTS_CONST: int = 32


func _ready() -> void:
	z_index = 1


func _draw() -> void:
	draw_arc(
		Vector2.ZERO,
		SLAM_HITBOX_RADIUS_CONST,
		0.0,
		TAU,
		SLAM_INDICATOR_ARC_POINTS_CONST,
		SLAM_INDICATOR_COLOR_CONST,
		SLAM_INDICATOR_LINE_WIDTH_CONST
	)
