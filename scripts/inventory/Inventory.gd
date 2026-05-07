extends Node
## Inventory autoload — single source of truth for the player's carried items
## and equipped slots. Sits alongside `PlayerStats` and `Levels` as a
## character-scoped progression layer.
##
## **Why an autoload (not a Player child)**: matches the M1 death-rule split.
## Per `team/uma-ux/inventory-stats-panel.md` Open-question #2 + DECISIONS.md
## "M1 death rule": **equipped** items survive run-death; **unequipped**
## inventory items are cleared on run-death (Uma proposed full-persistence
## but Priya's call landed on equipped-only — the simpler teaching beat that
## still rewards the player for slotting their best drop). Putting the data
## here means the Player node can be re-instantiated on restart without
## losing equipped state, identical to how PlayerStats survives the Player
## node's lifetime.
##
## **Capacity (M1):** 24 slots = 8x3 grid per Uma's spec. Adding past the cap
## emits `add_rejected(item)` and returns false — no auto-drop, no overflow
## queue.
##
## **Equipped slots (M1):** WEAPON and ARMOR are interactive. OFF_HAND,
## TRINKET, RELIC are visible-but-disabled per Uma — never equippable in M1
## even if a future loot table somehow rolls one. `equip()` rejects them.
##
## **API:**
##   Inventory.add(item)             -> bool   adds to first empty slot
##   Inventory.remove(item)          -> bool   removes if present
##   Inventory.get_items()           -> Array[ItemInstance]   read-only snapshot
##   Inventory.get_capacity()        -> int    24
##   Inventory.is_full()             -> bool
##   Inventory.equip(item, slot)     -> bool   item must be in inventory; on
##                                              success removes from inventory
##                                              and applies via Player.equip_item
##   Inventory.unequip(slot)         -> ItemInstance   returns the unequipped
##                                              item back into inventory; null
##                                              if slot empty or full inventory
##   Inventory.get_equipped(slot)    -> ItemInstance   currently-equipped item
##   Inventory.has_item(item)        -> bool   exact-instance check
##   Inventory.snapshot_to_save(d)   -> Dict   serialize into the save dict
##   Inventory.restore_from_save(d, item_resolver, affix_resolver) -> void
##   Inventory.clear_unequipped()    -> void   M1 death rule helper
##   Inventory.reset()               -> void   full wipe (new-game / tests)
##
## **Signals:**
##   inventory_changed(items: Array[ItemInstance])
##   item_added(item: ItemInstance)
##   item_removed(item: ItemInstance)
##   item_equipped(item: ItemInstance, slot: StringName)
##   item_unequipped(item: ItemInstance, slot: StringName)
##   add_rejected(item: ItemInstance, reason: StringName)   capacity / null
##
## **Save schema (v3 unchanged for M1):** Drew already authored
## `equipped: { slot: <item_dict> }` and `stash: [<item_dict>, ...]` in the
## save schema. Inventory uses `stash` as the inventory list for M1 (M2
## introduces a real stash; we'll bump v3 -> v4 then). For M1 the dispatch
## says no schema bump needed and Drew didn't bump — `stash` doubles as
## inventory storage and `equipped` is the equipped map. Decision logged
## inline in the dispatch report.

# ---- Constants -------------------------------------------------------

const CAPACITY: int = 24

const SLOT_WEAPON: StringName = &"weapon"
const SLOT_ARMOR: StringName = &"armor"

## Slots that exist in UI but are never interactive in M1. equip() on these
## returns false. Listed so the UI layer can render them dimmed without
## hard-coding the strings.
const SLOT_OFF_HAND: StringName = &"off_hand"
const SLOT_TRINKET: StringName = &"trinket"
const SLOT_RELIC: StringName = &"relic"

const ALL_SLOTS: Array[StringName] = [
	SLOT_WEAPON, SLOT_ARMOR, SLOT_OFF_HAND, SLOT_TRINKET, SLOT_RELIC,
]

const M1_INTERACTIVE_SLOTS: Array[StringName] = [SLOT_WEAPON, SLOT_ARMOR]

const REASON_FULL: StringName = &"full"
const REASON_NULL: StringName = &"null"

# ---- Signals ---------------------------------------------------------

signal inventory_changed(items: Array)
signal item_added(item: ItemInstance)
signal item_removed(item: ItemInstance)
signal item_equipped(item: ItemInstance, slot: StringName)
signal item_unequipped(item: ItemInstance, slot: StringName)
signal add_rejected(item: ItemInstance, reason: StringName)

# ---- Runtime state ---------------------------------------------------

var _items: Array[ItemInstance] = []
var _equipped: Dictionary = {}  # StringName slot -> ItemInstance


## Path to the T1 iron sword resource that seeds the player's starting
## inventory. Verified present in the project at M1 RC.
const IRON_SWORD_PATH: String = "res://resources/items/weapons/iron_sword.tres"

func _ready() -> void:
	# Smoke line so Tess can grep boot output.
	print("[Inventory] autoload ready (capacity=%d)" % CAPACITY)
	_seed_starting_inventory()


## Seed a single iron_sword into the inventory on a fresh game-start (both
## _items and _equipped empty). Only-if-empty rule: existing save files that
## already have inventory/equipped state are untouched — no dupe on reload.
## Called from _ready() so the sword is present before any scene boots.
func _seed_starting_inventory() -> void:
	if not _items.is_empty() or not _equipped.is_empty():
		# An existing save was already restored — respect it.
		return
	var def: ItemDef = load(IRON_SWORD_PATH) as ItemDef
	if def == null:
		push_warning("[Inventory] _seed_starting_inventory: iron_sword.tres not found at %s" % IRON_SWORD_PATH)
		return
	var inst: ItemInstance = ItemInstance.new(def, ItemDef.Tier.T1)
	# Bypass the public add() to avoid spurious inventory_changed before the
	# Player node is in the tree; the internal append is identical.
	_items.append(inst)
	print("[Inventory] starting iron_sword seeded (id=%s damage=%d)" % [def.id, def.base_stats.damage if def.base_stats != null else -1])


## Auto-equip the first iron_sword in the inventory into the weapon slot —
## called from Player._ready() after the Player joins the "player" group
## (so _find_player() can resolve it). Only runs if the weapon slot is empty,
## so an existing save's equipped weapon is never overwritten.
func equip_starter_weapon_if_needed() -> void:
	if _equipped.has(SLOT_WEAPON) and _equipped[SLOT_WEAPON] != null:
		# Weapon already equipped (restored save or prior equip). No-op.
		return
	# Find the first iron_sword in inventory and equip it.
	for it_v: ItemInstance in _items:
		if it_v == null or it_v.def == null:
			continue
		if it_v.def.id == &"iron_sword":
			equip(it_v, SLOT_WEAPON)
			print("[Inventory] starter iron_sword auto-equipped (weapon slot)")
			return
	# No iron_sword in inventory — defensive (seed may have failed or been
	# consumed by a prior save's state). No-op; player ships fistless which
	# was the original M1 RC state.
	push_warning("[Inventory] equip_starter_weapon_if_needed: no iron_sword in inventory to auto-equip")


# ---- Public API -------------------------------------------------------

## Add an item to the first empty inventory slot. Returns true on success;
## false if `item` is null or the inventory is full. Capacity overflow
## emits `add_rejected(item, REASON_FULL)`.
func add(item: ItemInstance) -> bool:
	if item == null:
		add_rejected.emit(null, REASON_NULL)
		push_warning("[Inventory] add: null item rejected")
		return false
	if _items.size() >= CAPACITY:
		add_rejected.emit(item, REASON_FULL)
		push_warning("[Inventory] add: capacity %d reached, item rejected" % CAPACITY)
		return false
	_items.append(item)
	item_added.emit(item)
	inventory_changed.emit(_items.duplicate())
	return true


## Remove the first occurrence of `item` (object identity). Returns true if
## found and removed; false otherwise.
func remove(item: ItemInstance) -> bool:
	if item == null:
		return false
	var idx: int = _items.find(item)
	if idx < 0:
		return false
	_items.remove_at(idx)
	item_removed.emit(item)
	inventory_changed.emit(_items.duplicate())
	return true


## Snapshot of carried items. Returned array is a fresh copy — mutate freely.
func get_items() -> Array[ItemInstance]:
	return _items.duplicate()


func get_capacity() -> int:
	return CAPACITY


func is_full() -> bool:
	return _items.size() >= CAPACITY


func has_item(item: ItemInstance) -> bool:
	return item != null and _items.has(item)


## Read the item currently equipped in `slot`, or null if empty.
func get_equipped(slot: StringName) -> ItemInstance:
	return _equipped.get(slot, null) as ItemInstance


## Returns the equipped map as a copy (slot -> ItemInstance).
func get_equipped_map() -> Dictionary:
	return _equipped.duplicate()


## Equip `item` into `slot`. Item must be in the inventory list (otherwise
## false). On success: removes item from inventory; if a different item was
## equipped in that slot it's unequipped first and pushed back into the
## inventory; calls `Player.equip_item` (defensive — falls back to
## `set_equipped_weapon` for weapons if equip_item is unavailable). Returns
## true on success, false on no-op (already equipped) or rejection.
func equip(item: ItemInstance, slot: StringName) -> bool:
	if item == null:
		return false
	if not (slot in M1_INTERACTIVE_SLOTS):
		push_warning("[Inventory] equip: slot %s is not interactive in M1" % slot)
		return false
	if not _items.has(item):
		push_warning("[Inventory] equip: item not in inventory")
		return false
	# Idempotent: same instance already equipped here = no-op.
	var current: ItemInstance = _equipped.get(slot, null) as ItemInstance
	if current == item:
		return false  # second equip = no-op per dispatch test 5
	# Unequip the existing slot occupant first; push it back into inventory.
	if current != null:
		_unequip_internal(slot, false)
	# Move the item from inventory into the equipped map.
	_items.erase(item)
	_equipped[slot] = item
	_apply_equip_to_player(item)
	item_equipped.emit(item, slot)
	inventory_changed.emit(_items.duplicate())
	return true


## Unequip whatever is in `slot` and place it back into the inventory.
## Returns the unequipped ItemInstance (or null if slot was empty / no
## room in inventory to receive it).
func unequip(slot: StringName) -> ItemInstance:
	return _unequip_internal(slot, true)


## Per the M1 death rule (DECISIONS.md): clear unequipped items only.
## Equipped state is preserved.
func clear_unequipped() -> void:
	if _items.is_empty():
		return
	_items.clear()
	inventory_changed.emit(_items.duplicate())


## Wipe everything. New-game / test fixture.
func reset() -> void:
	# Tell Player to drop equipped state too.
	for slot_v: Variant in _equipped.keys():
		var slot: StringName = slot_v
		_apply_unequip_to_player(slot)
	_items.clear()
	_equipped.clear()
	inventory_changed.emit(_items.duplicate())


# ---- Save serialization ---------------------------------------------

## Mutates `data` (a save's top-level dict) in place. Sets `data.stash`
## (the inventory items) and `data.equipped` (slot -> item dict). Returns
## `data` for chaining.
##
## Per save-format.md Drew authored, `stash` is a List[ItemDict] and
## `equipped` is a Dict[slot_string -> ItemDict]. M1 reuses `stash` as
## inventory storage; future stash separation = schema v4.
func snapshot_to_save(data: Dictionary) -> Dictionary:
	var stash: Array = []
	for it: ItemInstance in _items:
		var d: Dictionary = it.to_save_dict()
		if not d.is_empty():
			stash.append(d)
	data["stash"] = stash
	var eq: Dictionary = {}
	for slot_v: Variant in _equipped.keys():
		var slot: StringName = slot_v
		var inst: ItemInstance = _equipped[slot] as ItemInstance
		if inst == null:
			continue
		var ed: Dictionary = inst.to_save_dict()
		if not ed.is_empty():
			eq[String(slot)] = ed
	data["equipped"] = eq
	return data


## Restore from a save dict. `item_resolver` and `affix_resolver` are
## Callables that map StringName id -> Resource (ItemDef / AffixDef). See
## `ItemInstance.from_save_dict` for the resolver contract. Tolerates
## missing keys (defaults to empty inventory + no equipped) and items that
## fail to resolve (skipped with a push_warning).
func restore_from_save(data: Dictionary, item_resolver: Callable, affix_resolver: Callable) -> void:
	# Full reset first so reload is deterministic.
	for slot_v: Variant in _equipped.keys():
		var slot: StringName = slot_v
		_apply_unequip_to_player(slot)
	_items.clear()
	_equipped.clear()

	var stash_v: Variant = data.get("stash", [])
	if stash_v is Array:
		var stash: Array = stash_v
		for entry_v in stash:
			if not (entry_v is Dictionary):
				continue
			var entry_dict: Dictionary = entry_v
			var inst: ItemInstance = ItemInstance.from_save_dict(entry_dict, item_resolver, affix_resolver)
			if inst == null:
				continue
			if _items.size() < CAPACITY:
				_items.append(inst)
			else:
				push_warning("[Inventory] restore_from_save: stash exceeds capacity, item dropped")

	var equipped_v: Variant = data.get("equipped", {})
	if equipped_v is Dictionary:
		var eq: Dictionary = equipped_v
		for slot_str_v: Variant in eq.keys():
			var slot_str: String = String(slot_str_v)
			var slot_n: StringName = StringName(slot_str)
			var entry_v: Variant = eq[slot_str_v]
			if not (entry_v is Dictionary):
				continue
			var entry_dict: Dictionary = entry_v
			var inst: ItemInstance = ItemInstance.from_save_dict(entry_dict, item_resolver, affix_resolver)
			if inst == null:
				continue
			_equipped[slot_n] = inst
			_apply_equip_to_player(inst)
	inventory_changed.emit(_items.duplicate())


# ---- Loot pickup hook --------------------------------------------

## Convenience hook for `Pickup.picked_up(item, pickup)` — single-item
## variant. Mirrors `add(item)` but ignores the second argument.
func on_pickup_collected(item: ItemInstance, _pickup: Variant = null) -> void:
	add(item)


## Subscribe to every Pickup the given MobLootSpawner produced from an
## on_mob_died call. Wires each pickup's `picked_up` signal to
## `on_pickup_collected`. Tests use this to drive the
## "MobLootSpawner -> Inventory" integration without standing up the
## physics pipeline.
func auto_collect_pickups(pickups: Array) -> void:
	for p_v in pickups:
		var p: Node = p_v as Node
		if p == null:
			continue
		if p.has_signal("picked_up"):
			# Avoid duplicate connections if called twice on the same pickup.
			if not p.is_connected("picked_up", on_pickup_collected):
				p.connect("picked_up", on_pickup_collected)


## Drain an Array[ItemInstance] (e.g. the rolls a spawner produced) into
## the inventory, respecting capacity. Returns the count actually accepted.
## Used by the integration test to simulate the "auto-pickup on kill" path
## in M1 without standing up Area2D physics.
func ingest_rolls(items: Array) -> int:
	var accepted: int = 0
	for it_v in items:
		var it: ItemInstance = it_v as ItemInstance
		if it == null:
			continue
		if add(it):
			accepted += 1
	return accepted


# ---- Internals -------------------------------------------------------

func _unequip_internal(slot: StringName, push_back_to_inventory: bool) -> ItemInstance:
	var current: ItemInstance = _equipped.get(slot, null) as ItemInstance
	if current == null:
		return null
	# Refuse if returning to a full inventory would lose the item — caller
	# can choose to drop first.
	if push_back_to_inventory and _items.size() >= CAPACITY:
		push_warning("[Inventory] unequip: inventory full, leaving item equipped")
		return null
	_equipped.erase(slot)
	_apply_unequip_to_player(slot)
	if push_back_to_inventory:
		_items.append(current)
	item_unequipped.emit(current, slot)
	inventory_changed.emit(_items.duplicate())
	return current


# Defensive Player coupling. Drew's run-008 added Player.equip_item +
# Player.unequip_item (affix-aware path). If those methods aren't on Player
# yet (pre-merge of #55), fall back to set_equipped_weapon for weapons.
# Armor without equip_item simply skips the Player call — Inventory still
# tracks slot occupancy correctly.
func _apply_equip_to_player(item: ItemInstance) -> void:
	var player: Node = _find_player()
	if player == null:
		return
	if player.has_method("equip_item"):
		player.equip_item(item)
		return
	# Fallback path (pre-affix-system merge).
	if item.def != null and item.def.slot == ItemDef.Slot.WEAPON:
		if player.has_method("set_equipped_weapon"):
			player.set_equipped_weapon(item.def)


func _apply_unequip_to_player(slot: StringName) -> void:
	var player: Node = _find_player()
	if player == null:
		return
	if player.has_method("unequip_item"):
		player.unequip_item(slot)
		return
	# Fallback path: clear the legacy weapon ref.
	if slot == SLOT_WEAPON and player.has_method("set_equipped_weapon"):
		player.set_equipped_weapon(null)


func _find_player() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	# The Player node is typically in group "player" (per Pickup.gd convention).
	var nodes: Array = loop.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node
