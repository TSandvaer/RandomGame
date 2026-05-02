class_name InventoryGrid
extends GridContainer
## Stand-alone 8x3 inventory grid widget. The InventoryPanel composes one of
## these for the main inventory area; tests instantiate it directly to
## drive click flows without standing up the full panel.
##
## **Click model** (per Uma `inventory-stats-panel.md` §"Keyboard + mouse
## interaction model"):
##   - Left-click cell with item -> emits `cell_left_clicked(index, item)`.
##   - Right-click cell with item -> emits `cell_right_clicked(index, item)`.
##   - Hover -> emits `cell_hovered(index, item)`; un-hover emits
##     `cell_unhovered(index)`.
##
## The widget is a pure view — it doesn't call Inventory.equip etc. The
## outer panel decides the policy from the click signals.

signal cell_left_clicked(index: int, item: ItemInstance)
signal cell_right_clicked(index: int, item: ItemInstance)
signal cell_hovered(index: int, item: ItemInstance)
signal cell_unhovered(index: int)

const COLS: int = 8
const ROWS: int = 3
const CELL_SIZE: Vector2 = Vector2(96, 96)

# Per-cell button cache. Index 0 is top-left, increases left-to-right then
# wraps to next row. Mirrors GridContainer's natural child order.
var _cells: Array[Button] = []
var _items: Array = []  # parallel to _cells; ItemInstance or null


func _ready() -> void:
	columns = COLS
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	if _cells.is_empty():
		_build_cells()


func _build_cells() -> void:
	for i in COLS * ROWS:
		var btn: Button = Button.new()
		btn.name = "Cell_%d" % i
		btn.custom_minimum_size = CELL_SIZE
		btn.text = ""
		btn.pressed.connect(_on_cell_pressed.bind(i))
		btn.gui_input.connect(_on_cell_gui_input.bind(i))
		btn.mouse_entered.connect(_on_cell_hover.bind(i, true))
		btn.mouse_exited.connect(_on_cell_hover.bind(i, false))
		add_child(btn)
		_cells.append(btn)
		_items.append(null)


## Re-render the grid against an Array[ItemInstance] from the Inventory
## autoload. Cells beyond the items array render as empty.
func set_items(items: Array) -> void:
	for i in _cells.size():
		var item: ItemInstance = null
		if i < items.size():
			item = items[i] as ItemInstance
		_items[i] = item
		var btn: Button = _cells[i]
		if item == null or item.def == null:
			btn.text = ""
		else:
			btn.text = item.get_display_name()


## Test-only — synthesize a left-click on cell `index`.
func force_left_click_for_test(index: int) -> void:
	_emit_click(index, MOUSE_BUTTON_LEFT)


## Test-only — synthesize a right-click on cell `index`.
func force_right_click_for_test(index: int) -> void:
	_emit_click(index, MOUSE_BUTTON_RIGHT)


# ---- Internals ---------------------------------------------------

func _on_cell_pressed(index: int) -> void:
	# Default Button.pressed only fires on left mouse.
	_emit_click(index, MOUSE_BUTTON_LEFT)


func _on_cell_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_emit_click(index, MOUSE_BUTTON_RIGHT)


func _on_cell_hover(index: int, entered: bool) -> void:
	if entered:
		var item: ItemInstance = null
		if index < _items.size():
			item = _items[index] as ItemInstance
		cell_hovered.emit(index, item)
	else:
		cell_unhovered.emit(index)


func _emit_click(index: int, button: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var item: ItemInstance = _items[index] as ItemInstance
	if item == null:
		# Empty-cell click — no signal (Uma: "Click empty slot -> no-op").
		return
	if button == MOUSE_BUTTON_LEFT:
		cell_left_clicked.emit(index, item)
	elif button == MOUSE_BUTTON_RIGHT:
		cell_right_clicked.emit(index, item)
