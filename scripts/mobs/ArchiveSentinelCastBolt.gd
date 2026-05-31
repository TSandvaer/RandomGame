class_name ArchiveSentinelCastBolt
extends Node2D
## Visible cast-projectile VFX for ArchiveSentinel's phase-1/phase-2 cast.
##
## Source: ticket `86c9y7ygj` re-soak fix (Sponsor 2026-05-29 — "ArchiveSentinel
## deals damage with ZERO visible attack"). The cast's DAMAGE is an
## instantaneous `Hitbox` spawned at the captured target position (see
## `ArchiveSentinel._fire_cast` — dodge model: snapshot-at-telegraph-start,
## player who moved escapes). That hitbox is a bare Area2D + CollisionShape2D
## with NO visual node, so the cast was invisible in BOTH desktop and WebGL2 —
## the construct's modulate-flare telegraph plays on its own body across the
## arena, not on the cast itself, so "HP just drops, nothing visible."
##
## This node is the missing VISUAL — a cosmetic ember bolt that travels from the
## construct's book toward the captured target over the cast window, arriving as
## a brief impact flash at the damage point. It carries NO damage and NO
## collision (the damage hitbox is unchanged — dodge semantics + the GUT
## `test_cast_hitbox_spawns_at_captured_player_position` contract are preserved).
##
## ## Why a ColorRect body, not Polygon2D / Sprite2D
##
## The bolt body is a `ColorRect` (renderer-safe filled rect per
## `.claude/docs/html5-export.md` § "Polygon2D rendering quirks" — PR #137
## swapped the swing wedge Polygon2D → ColorRect for exactly this reason). The
## existing `Projectile.tscn` uses the same ColorRect-Sprite shape and renders
## correctly in `gl_compatibility`. Channels are sub-1.0 (ember-orange) so the
## HDR clamp leaves the color intact (PR #137 white-clamp lesson).
##
## ## z_index
##
## +1 so the bolt draws above the room floor + the construct body (PR #291 T6
## same-z occlusion lesson — a same-z bolt could be silently obscured by the
## construct or floor under `gl_compatibility`).
##
## ## Lifecycle
##
## Room-parented + deferred-add by the caller (physics-flush rule). On _ready
## it tweens its `position` from spawn → target over `travel_duration`, then
## flashes + fades the impact, then `queue_free`s. Fully self-cleaning; a
## SceneTreeTimer safety-net frees it even if the tween hangs (mirrors the mob
## death-tween safety-net convention).

## Ember-accent bolt body — Uma §5.5 boss-projectile ember-burst `#FF6A2A`.
## Sub-1.0 channels (HTML5 HDR-clamp safe). The bolt body is rotated 45° (see
## BOLT_ROTATION) so the square ColorRect reads as a diamond ember-shard rather
## than a flat block — a zero-cost shape upgrade over the soak-round-2 plain
## square ("not pretty but it's there", Sponsor 2026-05-29) that keeps the
## renderer-safe ColorRect body + the visibility-trace contract unchanged.
const BOLT_COLOR: Color = Color(1.0, 0.416, 0.165, 1.0)  # #FF6A2A ember-accent (Uma §5.5)
const BOLT_SIZE: Vector2 = Vector2(13.0, 13.0)
const BOLT_Z_INDEX: int = 1

## 45° rotation makes the square body read as a diamond ember-shard.
const BOLT_ROTATION: float = PI * 0.25

## Impact flash — a brief bright pop at the target on arrival so the landing
## point is unmistakable. Sub-1.0 warm-white (breaks the ember-on-floor blend
## per PR #291 v5 finding) at a wider scale.
const IMPACT_COLOR: Color = Color(1.0, 0.949, 0.749, 1.0)  # #FFF2BF warm flash
const IMPACT_SIZE: Vector2 = Vector2(28.0, 28.0)
const IMPACT_FLASH_DURATION: float = 0.10

var _spawn_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _travel_duration: float = 0.18
var _bolt: ColorRect = null
var _tween: Tween = null


## Configure before add_child. `travel_duration` should be the cast-fire→impact
## window — short (the damage already landed instantaneously; this is the
## "where it came from / where it went" cue).
func configure(spawn_pos: Vector2, target_pos: Vector2, travel_duration: float) -> void:
	_spawn_pos = spawn_pos
	_target_pos = target_pos
	_travel_duration = max(0.02, travel_duration)


func _ready() -> void:
	z_index = BOLT_Z_INDEX
	global_position = _spawn_pos
	_bolt = ColorRect.new()
	_bolt.color = BOLT_COLOR
	_bolt.size = BOLT_SIZE
	# Center the rect on the node origin so it travels centered on the line.
	_bolt.position = -BOLT_SIZE * 0.5
	# Rotate 45° about the body center so the square reads as a diamond
	# ember-shard. pivot_offset = center keeps the rotation centered on the
	# travel line (without it, ColorRect rotates about its top-left corner).
	_bolt.pivot_offset = BOLT_SIZE * 0.5
	_bolt.rotation = BOLT_ROTATION
	add_child(_bolt)

	_tween = create_tween()
	# Leg 1: travel spawn → target.
	_tween.tween_property(self, "global_position", _target_pos, _travel_duration)
	# Leg 2: arrival — swap the body to a wider warm impact flash, then fade.
	_tween.tween_callback(_on_arrival)
	_tween.tween_property(_bolt, "modulate:a", 0.0, IMPACT_FLASH_DURATION)
	_tween.tween_callback(queue_free)

	# Safety-net: free even if the tween hangs (mirrors mob death-tween net).
	var safety: SceneTreeTimer = get_tree().create_timer(
		_travel_duration + IMPACT_FLASH_DURATION + 0.2
	)
	safety.timeout.connect(_safety_free)

	# Renderer-observable visibility trace — emitted from _ready (the bolt is NOW
	# in the tree, modulate is its real on-screen value, z is set). This is the
	# load-bearing "the visible attack node is actually VISIBLE when the cast
	# lands" signal the Playwright spec asserts on. `ArchiveSentinel._spawn_cast_bolt`
	# traces the spawn INTENT (before the deferred add); THIS line proves the node
	# rendered visible. Regression guard for the Sponsor "HP just drops, nothing
	# visible" re-soak (ticket 86c9y7ygj) — node-presence + visibility is
	# assertable headless; human-perceptibility stays the Sponsor-soak gate.
	_emit_visible_trace()


## Emit the on-screen visibility state via the DebugFlags combat-trace shim (same
## shim ArchiveSentinel uses). Reads `visible`, `modulate.a`, `z_index`, and the
## body type back AFTER mount so the values are renderer-truth, not spawn-intent.
func _emit_visible_trace() -> void:
	if not is_inside_tree():
		return
	var df: Node = get_tree().root.get_node_or_null("DebugFlags")
	if df == null or not df.has_method("combat_trace"):
		return
	var body_is_color_rect: bool = _bolt != null and _bolt is ColorRect
	df.combat_trace(
		"ArchiveSentinelCastBolt._ready",
		(
			"VISIBLE bolt pos=(%.0f,%.0f) visible=%s alpha=%.2f z=%d color_rect=%s"
			% [
				global_position.x,
				global_position.y,
				str(visible),
				modulate.a,
				z_index,
				str(body_is_color_rect),
			]
		)
	)


func _on_arrival() -> void:
	if _bolt == null or not is_instance_valid(_bolt):
		return
	_bolt.color = IMPACT_COLOR
	_bolt.size = IMPACT_SIZE
	_bolt.position = -IMPACT_SIZE * 0.5
	# Impact pop reads better as an upright burst — drop the diamond rotation.
	_bolt.pivot_offset = IMPACT_SIZE * 0.5
	_bolt.rotation = 0.0


func _safety_free() -> void:
	if not is_queued_for_deletion():
		queue_free()
