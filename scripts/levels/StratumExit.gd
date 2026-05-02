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
func activate() -> void:
	if _is_active:
		return
	_is_active = true
	_apply_active_state(true)
	exit_activated.emit()


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


func _apply_active_state(active: bool) -> void:
	if _portal_visual != null:
		_portal_visual.color = PORTAL_COLOR_ACTIVE if active else PORTAL_COLOR_INACTIVE
	if _interaction_area != null:
		_interaction_area.monitoring = active
		_interaction_area.monitorable = active
	_update_prompt_visibility()


func _update_prompt_visibility() -> void:
	if _prompt_label == null:
		return
	# Prompt is visible only when the exit is active, the player is in
	# range, and the descend hasn't already fired.
	_prompt_label.visible = _is_active and _player_in_range and not _descend_triggered


func _on_body_entered(_body: Node) -> void:
	# Defensive: we only mask layer 2 (player) so any body crossing should
	# be the player. Don't couple to Player class — keeps tests light.
	_player_in_range = true
	_update_prompt_visibility()


func _on_body_exited(_body: Node) -> void:
	_player_in_range = false
	_update_prompt_visibility()
