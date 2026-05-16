class_name StratumExit
extends Node2D
## Stratum exit portal — the player's "you cleared this stratum, descend?"
## prompt that appears in the boss room after the boss is defeated.
##
## Lifecycle (M1):
##   1. Spawned INACTIVE (interaction area collision off, prompt label hidden,
##      portal sprite at "dim" tint). At this state the player can walk
##      through the exit and nothing happens.
##   2. The owning level (`Stratum1BossRoom`) calls `activate()` when its
##      `boss_died` plumbing has fired. This flips the area collision on,
##      shows the prompt, and brightens the portal sprite.
##   3. Player walks into the area → `_player_in_range` flips on. While
##      in-range, pressing the `interact` action fires `descend_triggered`.
##   4. `descend_triggered` is a one-shot — once fired, the exit becomes
##      INERT (no more signals) so rapid mash / spam can't double-fire.
##
## Test surface (per `tests/test_stratum_exit.gd`):
##   - `is_active() / is_descend_triggered()` for state assertions.
##   - `set_player_overlap_for_test(bool)` to simulate the area-overlap
##     without standing up a real CharacterBody2D + physics step.
##   - `try_interact()` to simulate the keypress without dispatching a
##     real InputEvent.
##
## Input binding: respects an `interact` action if one is defined in
## `project.godot` (forward-compat for input-rebind), else falls back to
## the literal E key. This way the feature ships without requiring
## project.godot edits, but works seamlessly if Devon adds the action
## during the M2 input-rebind pass.
##
## Visuals are deliberately minimal — placeholder ColorRect for the portal
## body and a Label for the prompt. Real sprite art is M2 polish.
##
## Per Uma's `palette.md` (Stratum 1 ramp):
##   - Doorway ember-glow `#FF6A2A` for the active portal core.
##   - HUD body text `#E8E4D6` for the prompt, muted parchment `#B8AC8E`
##     for the inactive state hint.
##   - Active portal pulses gently — the brand's flame-as-through-line.

# ---- Signals ------------------------------------------------------------

## Fired the first time the player presses interact while in range and the
## exit is active. One-shot; after this the exit ignores further input.
signal descend_triggered()

## Fired when `activate()` runs the very first time. Useful for cinematic
## hooks that want to play the "exit becomes available" cue.
signal exit_activated()

# ---- Tuning ------------------------------------------------------------

## Default size of the interaction Area2D. Designed to be roughly the size
## of one tile (32 internal px) plus a small "be generous to the player"
## margin so they don't have to stand on the exact pixel.
const INTERACTION_AREA_SIZE: Vector2 = Vector2(40.0, 40.0)

## Active portal tint — Uma's ember accent (`#FF6A2A`). Constant across
## strata; this is the player's flame.
const PORTAL_COLOR_ACTIVE: Color = Color(1.0, 0.4156862745, 0.1647058824, 1.0)

## Inactive portal tint — heavily desaturated muted parchment, signals
## "this is here but locked." Uma's HUD-disabled value (`#605C50`).
const PORTAL_COLOR_INACTIVE: Color = Color(0.3764705882, 0.3607843137, 0.3137254902, 1.0)

## Prompt copy. Kept here as a constant (not in `inventory-stats-panel.md`
## or `hud.md`) so a future Uma microcopy pass has one obvious spot to
## change. Uma may revise during her copy/microcopy sweep.
const PROMPT_TEXT: String = "Press E to descend"

# ---- Inspector --------------------------------------------------------

## Local position to place the portal at. Default: a couple tiles north of
## the door trigger so the player has somewhere to walk *to* after the
## boss dies, not where they walked *in* from.
@export var portal_position: Vector2 = Vector2(240.0, 70.0)

## Visual size of the placeholder portal sprite ColorRect. Real sprite is
## M2 polish.
@export var portal_visual_size: Vector2 = Vector2(32.0, 48.0)

# ---- Runtime ----------------------------------------------------------

var _is_active: bool = false
var _descend_triggered: bool = false
var _player_in_range: bool = false

var _interaction_area: Area2D = null
var _portal_visual: ColorRect = null
var _prompt_label: Label = null


func _ready() -> void:
	position = portal_position
	_build_portal_visual()
	_build_interaction_area()
	_build_prompt_label()
	_apply_active_state(false)
	# We use `_unhandled_input` for the interact key — node receives input
	# events by default, but we set the flag for clarity.
	set_process_unhandled_input(true)


# ---- Public API -------------------------------------------------------

func is_active() -> bool:
	return _is_active


func is_descend_triggered() -> bool:
	return _descend_triggered


func is_player_in_range() -> bool:
	return _player_in_range


func get_interaction_area() -> Area2D:
	return _interaction_area


func get_prompt_label() -> Label:
	return _prompt_label


## Flip the exit from INACTIVE to ACTIVE. Idempotent — calling multiple
## times after the first does nothing (the second `boss_died` is impossible
## but defensive: if the host scene wires the same signal twice we don't
## want a flicker or duplicate emit).
##
## **Knockback-overlap fix (ticket 86c9un4nh — Finding 3 M2 W3 re-soak).**
## `activate()` is called via `call_deferred` from `Stratum1BossRoom._on_boss_died`
## (PR #232 physics-flush fix). This defers the monitoring flip to the next
## frame — but if the player is ALREADY standing inside the 40×40 interaction
## area when monitoring turns on, Godot 4's `body_entered` does NOT re-fire
## for pre-existing overlaps. `_player_in_range` stays false, the prompt never
## shows, pressing E does nothing — player is trapped forever.
##
## This is the same bug class as `RoomGate._unlock()` (PR #230 knockback-
## overlap fix): after `gate_unlocked` the player may be physically inside the
## gate trigger but `body_entered` won't re-fire. Fix: explicit
## `get_overlapping_bodies()` check after flipping monitoring on.
##
## Fix: after `_apply_active_state(true)`, walk `get_overlapping_bodies()`.
## If the player is already inside, call `_on_body_entered(body)` directly
## (deferred — stay out of any residual physics-flush context in the
## call_deferred chain) so `_player_in_range` is set and the prompt appears.
## Same shape as `RoomGate._fire_traversal_if_unlocked`.
##
## **Double-defer (ticket `86c9unkr2` — Finding 2 STILL repro on PR #236 build
## `92b6206`, 2026-05-16 soak):** the single `call_deferred("activate")` from
## `Stratum1BossRoom._on_boss_died` lands in the same end-of-frame deferred
## queue that also drains 2x Pickup `add_child` calls + particle adds + room
## transitions. Sponsor's HTML5 trace stream shows the StratumExit + Pickup
## monitoring flips silently failing despite the trace label saying "monitoring
## flipped ON" (the label was hard-coded, not a readback). Adding
## `await get_tree().physics_frame` here guarantees the monitoring mutation
## lands AFTER at least one full physics tick has elapsed past any in-flight
## `flush_queries()` window. Same fix landed on `Pickup._activate_and_check_initial_overlap`.
##
## **Sync/async-mix consequence — readability and test discipline:** with
## `await`, `activate()` returns a Coroutine to its caller; callers that need
## post-conditions (e.g. `_is_active`, `_interaction_area.monitoring`) on the
## SAME tick must instead `await activate()` or `await get_tree().process_frame`
## after invocation. `_is_active` flips synchronously at the top of the function
## (before the await), so the idempotency guard still works against a re-entrant
## call. Production callers (`Stratum1BossRoom._on_boss_died` via `call_deferred`)
## fire-and-forget — they don't read post-state from the same callsite. Tests
## must `await get_tree().process_frame` (or `physics_frame`) after `activate()`
## to observe the monitoring transition.
func activate() -> void:
	if _is_active:
		return
	# Synchronous flip: idempotency latch + visual portal-color + prompt-tracking.
	# Tests that observe `is_active()`, prompt visibility, and visual state on the
	# SAME tick as `activate()` continue to pass without re-architecting (a real
	# constraint — see test_stratum_exit.gd tests that don't await).
	_is_active = true
	_apply_active_visual_state(true)
	# Diagnostic trace (ticket `86c9unkr2`): readback of monitoring state lands
	# in `_arm_interaction_area_after_flush` once the await resolves. We emit a
	# synchronous marker here so the trace stream shows the activate() entry
	# point separately from the deferred monitoring flip.
	_combat_trace("StratumExit.activate",
		"sync entry — visual flipped, awaiting physics_frame to arm interaction area (double-defer)")
	# Async: arm the Area2D monitoring strictly outside any physics-flush window.
	# `await get_tree().physics_frame` yields until the next physics tick
	# boundary, which is by definition AFTER any in-flight `flush_queries()`
	# call has completed. The single `call_deferred("activate")` from
	# `Stratum1BossRoom._on_boss_died` was insufficient under HTML5 (Sponsor's
	# 2026-05-16 soak of `92b6206` showed pickups + exit both un-overlappable).
	# See `activate()` docstring above for the full pattern rationale.
	_arm_interaction_area_after_flush()
	exit_activated.emit()


## Async portion of activate(): wait one full physics frame, then flip the
## Area2D monitoring on. Separate from `activate()` so the synchronous parts
## (idempotency latch + visual portal flip) land on the same tick as the
## caller — only the physics-server-touching mutation is deferred.
##
## Standalone function (rather than inline `await` in `activate()`) so tests
## can `await exit._arm_interaction_area_after_flush()` to wait deterministically
## for the monitoring transition without re-engineering the public surface.
## Idempotent — re-callable; the post-flush check + monitoring set are both
## guarded.
func _arm_interaction_area_after_flush() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		# Room queue_freed in the interim (test teardown, room transition).
		return
	if _interaction_area == null:
		return
	# Apply the monitoring flip now that we're strictly outside the flush window.
	# `monitorable` flips together so the area can both detect AND be detected
	# (the exit doesn't actually need `monitorable` since nothing queries IT,
	# but `_apply_active_state` previously set both together — keep parity).
	_interaction_area.monitoring = true
	_interaction_area.monitorable = true
	# Diagnostic trace with readback (ticket `86c9unkr2`): read `monitoring`
	# BACK after the setter — if the C++ `ERR_FAIL_COND` (silent under HTML5)
	# rejected the set, `monitoring` stays at false and `mon_actual=false`
	# surfaces in the trace. Pre-fix the label was hard-coded "monitoring flipped
	# ON" regardless of actual state — no signal whether the setter took effect.
	_combat_trace("StratumExit.activate",
		"mon_actual=%s mon_req=true — checking pre-existing body overlaps (knockback-overlap fix)" % str(_interaction_area.monitoring))
	# **Pre-existing overlap re-check (ticket 86c9un4nh):** if the player was
	# already inside the interaction area before monitoring turned on, fire the
	# in-range detection manually. Deferred (via call_deferred on _on_body_entered
	# equivalent) to stay out of any physics-flush context this activate() might
	# run in.
	for body in _interaction_area.get_overlapping_bodies():
		if body is CharacterBody2D:
			_combat_trace("StratumExit.activate",
				"player already inside interaction area — firing _on_body_entered deferred")
			call_deferred("_on_body_entered", body)
			break


## Test-only: simulate the player crossing into / out of the interaction
## area without needing a CharacterBody2D + a physics step. The prompt
## visibility tracks this.
func set_player_overlap_for_test(overlap: bool) -> void:
	_player_in_range = overlap
	_update_prompt_visibility()


## Test-only and runtime: attempt the interact action. Fires the descend
## signal IFF the exit is active, the player is in range, and the signal
## hasn't already been fired. Spamming this is a no-op after the first
## successful fire — that's the rapid-mash idempotence guarantee.
func try_interact() -> bool:
	if _descend_triggered:
		return false
	if not _is_active:
		return false
	if not _player_in_range:
		return false
	_descend_triggered = true
	descend_triggered.emit()
	# After firing, hide the prompt so the player gets feedback that the
	# input registered (the screen will fade-to-descend right after).
	if _prompt_label != null:
		_prompt_label.visible = false
	return true


# ---- Process loop -----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Only respond when the exit is active, player is in range, and we
	# haven't fired yet. Avoids consuming the E key in unrelated contexts.
	if not _is_active or not _player_in_range or _descend_triggered:
		return
	# Prefer the project-level `interact` action if defined (so a future
	# input-rebind feature still works), else fall back to the literal E
	# key. We don't want to require project.godot edits for this feature.
	if InputMap.has_action("interact"):
		if event.is_action_pressed("interact"):
			try_interact()
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_E:
			try_interact()


# ---- Internal --------------------------------------------------------

func _build_portal_visual() -> void:
	_portal_visual = ColorRect.new()
	_portal_visual.name = "PortalVisual"
	# Center the visual on the StratumExit node's origin.
	_portal_visual.position = Vector2(
		-portal_visual_size.x * 0.5,
		-portal_visual_size.y * 0.5
	)
	_portal_visual.size = portal_visual_size
	_portal_visual.color = PORTAL_COLOR_INACTIVE
	add_child(_portal_visual)


func _build_interaction_area() -> void:
	_interaction_area = Area2D.new()
	_interaction_area.name = "InteractionArea"
	# Same layer convention as Stratum1BossRoom's door trigger: no own layer,
	# masks player (bit 2 = layer 2 = "player").
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1 << 1
	# INACTIVE by default. Production flow won't see the player overlap
	# until activate() flips this. We disable both monitoring and
	# monitorable so the area is fully inert.
	_interaction_area.monitoring = false
	_interaction_area.monitorable = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = INTERACTION_AREA_SIZE
	shape.shape = rect
	_interaction_area.add_child(shape)
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)
	add_child(_interaction_area)


func _build_prompt_label() -> void:
	_prompt_label = Label.new()
	_prompt_label.name = "InteractPrompt"
	_prompt_label.text = PROMPT_TEXT
	# Off-white HUD body color — Uma `palette.md` `#E8E4D6`.
	_prompt_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 1.0))
	# Place the label below the portal visual.
	_prompt_label.position = Vector2(-40.0, portal_visual_size.y * 0.5 + 4.0)
	_prompt_label.size = Vector2(80.0, 16.0)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.visible = false
	add_child(_prompt_label)


## Synchronous portal-color + prompt visibility flip. Does NOT touch the
## Area2D monitoring state — that lands in `_arm_interaction_area_after_flush`
## via an `await get_tree().physics_frame` from `activate()` (ticket
## `86c9unkr2` double-defer fix). Callers that need the deactivate path
## (currently only `_ready`'s INACTIVE init) use `_apply_active_state(false)`
## which DOES touch monitoring — initial setup runs before any physics flush
## could be in flight, so a sync write is safe.
func _apply_active_visual_state(active: bool) -> void:
	if _portal_visual != null:
		_portal_visual.color = PORTAL_COLOR_ACTIVE if active else PORTAL_COLOR_INACTIVE
	_update_prompt_visibility()


## Synchronous full state-flip — visual + monitoring together. ONLY safe to
## call from contexts that are NOT inside a physics flush (e.g. `_ready` boot
## init, where the engine has not started any flush_queries yet). The ACTIVE
## path goes through `activate() → _arm_interaction_area_after_flush` instead,
## which awaits a physics_frame before touching monitoring (HTML5-safe).
func _apply_active_state(active: bool) -> void:
	_apply_active_visual_state(active)
	if _interaction_area != null:
		_interaction_area.monitoring = active
		_interaction_area.monitorable = active


func _update_prompt_visibility() -> void:
	if _prompt_label == null:
		return
	# Prompt is visible only when the exit is active, the player is in
	# range, and the descend hasn't already fired.
	_prompt_label.visible = _is_active and _player_in_range and not _descend_triggered


func _on_body_entered(body: Node) -> void:
	# Defensive: we only mask layer 2 (player) so any body crossing should
	# be the player. Don't couple to Player class — keeps tests light.
	_player_in_range = true
	_update_prompt_visibility()
	# Readback trace (ticket `86c9unkr2`): emit BEFORE the in-range flip if the
	# monitoring state ever silently drifts. The body class + monitoring readback
	# together let Sponsor's HTML5 trace stream tell "body_entered fired and we
	# saw it" apart from "body_entered never reached us" — the latter is the
	# bug class this PR is targeting.
	var area_mon: String = "<null>"
	if _interaction_area != null:
		area_mon = str(_interaction_area.monitoring)
	_combat_trace("StratumExit._on_body_entered",
		"body=%s mon_actual=%s player_in_range=true is_active=%s descend_triggered=%s" % [
			str(body), area_mon, str(_is_active), str(_descend_triggered)])


func _on_body_exited(_body: Node) -> void:
	_player_in_range = false
	_update_prompt_visibility()


## Combat-trace shim — routes through DebugFlags.combat_trace (HTML5-only).
## Same pattern as RoomGate._combat_trace and mob _combat_trace helpers; emits
## in HTML5 builds so Sponsor's DevTools console can confirm the StratumExit
## monitoring + player-overlap state — the observable surface for the ticket
## 86c9un4nh knockback-overlap fix (Finding 3 M2 W3 re-soak).
func _combat_trace(tag: String, msg: String = "") -> void:
	var df: Node = null
	if is_inside_tree():
		df = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
