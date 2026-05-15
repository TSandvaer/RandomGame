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
##   Inventory.equip(item, slot, source = &"lmb_click") -> bool
##                                              item must be in inventory; on
##                                              success removes from inventory
##                                              and applies via Player.equip_item.
##                                              `source` tags the combat-trace
##                                              line (lmb_click vs auto_pickup,
##                                              ticket 86c9qah0v / 86c9qbb3k).
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


func _ready() -> void:
	# Smoke line so Tess can grep boot output.
	print("[Inventory] autoload ready (capacity=%d)" % CAPACITY)


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
##
## **Equip-swap order (P0 86c9q96m8 fix):** when a different item is already
## equipped, we MUST preserve it back into the inventory grid (Sponsor's M1
## RC re-soak attempt 5 — picking up a second sword and equipping it dropped
## the previously-equipped sword on the floor). We erase the new item from
## `_items` BEFORE calling `_unequip_internal(..., true)` so the grid has a
## free slot for the previously-equipped item to land in — even from a 24/24
## inventory. This guarantees no item is silently lost on swap.
##
## **Combat-trace (P0 86c9q96m8 surface):** emits the
## `[combat-trace] Inventory.equip | item=<id> slot=<weapon|armor>
## source=<source_tag> damage_after=<N>` line on every successful `equip()`.
## `restore_from_save` does NOT route through `equip()` — it directly mutates
## `_equipped` and calls `_apply_equip_to_player`, so the trace line is
## scoped to user/system equip paths (never save-restore).
##
## **`source` parameter (`86c9qah0v` fix):** distinguishes user-driven equips
## from system-driven equips so the negative-assertion sweep can tell them
## apart. Default `&"lmb_click"` preserves backwards-compat for all existing
## callers (`InventoryPanel._handle_inventory_click`, GUT tests).
## `on_pickup_collected` overrides to `&"auto_pickup"` — the
## auto-equip-first-weapon-on-pickup onboarding path is system-driven, not
## user-driven, so it must NOT pollute the `lmb_click` channel that Playwright
## greps for during the user-click window. (`&"auto_starter"` — the old
## PR #146 boot-equip tag — is **deprecated**; that bandaid was retired in
## ticket `86c9qbb3k`. No current producer passes it; see the source-tag
## footnote in `_emit_equip_trace`.) Future system-driven equip paths
## (e.g. fast-travel re-equip, scripted scenes) should add their own `source`
## tag rather than reusing `lmb_click`.
func equip(item: ItemInstance, slot: StringName, source: StringName = &"lmb_click") -> bool:
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
	# Erase the new item from `_items` FIRST so the grid has room for the
	# previously-equipped item to land in (otherwise a 24/24 grid would
	# refuse the unequip and silently leak the swap). Order matters:
	#   1. erase new item -> grid free slot
	#   2. unequip old (push_back=true) -> old item lands in grid
	#   3. equip new -> _equipped[slot] = new
	_items.erase(item)
	# Unequip the existing slot occupant; push it back into inventory so it's
	# preserved (P0 86c9q96m8 — pre-fix passed false here, leaking the old item).
	if current != null:
		_unequip_internal(slot, true)
	# Move the item into the equipped map.
	_equipped[slot] = item
	_apply_equip_to_player(item)
	item_equipped.emit(item, slot)
	inventory_changed.emit(_items.duplicate())
	# Combat-trace shim — surfaces the dual-surface state to Sponsor's HTML5
	# DevTools console so equip-flow regressions are observable in soak. Pure
	# instrumentation; no-op outside HTML5 (DebugFlags.combat_trace gate).
	# `source` defaults to `lmb_click` so all existing user-click callers stay
	# correctly tagged; `on_pickup_collected` overrides to `auto_pickup` for the
	# auto-equip-first-weapon-on-pickup onboarding path (ticket `86c9qbb3k`).
	_emit_equip_trace(item, slot, source)
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
## variant. Adds the item to the grid, then **auto-equips the first weapon
## the player picks up** so the player is never fistless during onboarding
## (ticket `86c9qbb3k` — replaces the retired PR #146 boot-equip bandaid).
##
## **Auto-equip-first-weapon-on-pickup rule:** if the collected item is a
## weapon AND the weapon slot is currently empty, the item is immediately
## equipped via `equip(item, SLOT_WEAPON, &"auto_pickup")`. This is the
## design-correct onboarding path — the Stage-2b PracticeDummy drops an
## iron_sword, the player walks onto it, and it auto-equips through the
## legitimate pickup flow (no boot-time seeding, no `Main._ready` bandaid).
##
## **First-weapon-only — NOT auto-swap.** If a weapon is already equipped,
## a subsequently-collected weapon just lands in the grid; it does NOT
## auto-swap. Mid-run weapon swaps stay user-driven (Tab → LMB-click). The
## auto-equip is strictly an onboarding affordance: "your first weapon is
## equipped the moment you grab it."
##
## **Combat-trace `source=auto_pickup`:** the auto-equip routes through
## `equip()` and tags its trace line `source=auto_pickup` (distinct from
## `lmb_click` user-clicks). The negative-assertion sweep can tell the
## onboarding auto-equip apart from a user click. (`auto_starter` — the old
## PR #146 boot-equip tag — is retired; see `equip()` docstring.)
##
## **Pickup lifecycle ownership (ticket `86c9u33h1`).** This hook owns the
## Pickup's destruction: `Pickup._on_body_entered` no longer queue_frees itself
## unconditionally — instead it emits `picked_up` and waits for the consumer
## (us) to call `consume_after_pickup()` if-and-only-if `add()` succeeded.
## When `add()` rejects the item (grid full at 24/24), we return early WITHOUT
## consuming the Pickup, leaving it on the ground so the player can free a
## slot and re-collect it. Pre-fix this hook left destruction to the Pickup
## itself, which `queue_free`'d unconditionally — and any add-rejected item
## was silently destroyed (Tess bug-bash `86c9kxx7h`).
func on_pickup_collected(item: ItemInstance, pickup: Variant = null) -> void:
	if not add(item):
		# add() rejected (null item or grid full at 24/24). The Pickup stays
		# on the ground — do NOT call consume_after_pickup. The Pickup's own
		# `_clear_collected_latch_if_alive` deferred call re-arms the latch so
		# the player can re-attempt after freeing a slot (must walk off + back
		# on per body_entered single-event semantics).
		return
	# add() succeeded — destroy the Pickup. The pickup arg is the second
	# positional arg of `Pickup.picked_up(item, pickup)`; defend against tests
	# / call sites that pass null or a non-Pickup.
	if pickup is Pickup:
		(pickup as Pickup).consume_after_pickup()
	# Auto-equip-first-weapon-on-pickup: only when the picked-up item is a
	# weapon AND no weapon is currently equipped. First-weapon-only — an
	# already-equipped weapon is never auto-swapped. This branch only runs
	# when add() succeeded above, so a rejected-add never auto-equips either.
	if item == null or item.def == null:
		return
	if item.def.slot != ItemDef.Slot.WEAPON:
		return
	var current_weapon: ItemInstance = _equipped.get(SLOT_WEAPON, null) as ItemInstance
	if current_weapon != null:
		# A weapon is already equipped — leave the pickup in the grid.
		return
	equip(item, SLOT_WEAPON, &"auto_pickup")


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


# ---- Combat-trace (P0 86c9q96m8) -------------------------------------

## Emit a `[combat-trace] Inventory.equip` line via DebugFlags.combat_trace.
## HTML5-only (the gate in `DebugFlags.combat_trace_enabled` returns false on
## desktop and headless GUT, so this is a silent no-op there). The line is
## scoped to `equip()` callers; F5-reload restoration uses
## `restore_from_save` which bypasses `equip()` entirely, so it does NOT fire
## this trace.
##
## Line shape (verbatim contract — Playwright spec greps this):
##   [combat-trace] Inventory.equip | item=<id> slot=<weapon|armor> \
##       source=<source_tag> damage_after=<N>
##
## `source_tag` enum (ticket `86c9qah0v` / `86c9qbb3k`):
##   - `lmb_click` — user-driven equip via `InventoryPanel._handle_inventory_click`.
##     Default for `equip()` so existing callers don't need to pass a tag.
##   - `auto_pickup` — system-driven auto-equip-first-weapon-on-pickup via
##     `on_pickup_collected`. Distinct so the negative-assertion sweep can tell
##     user-clicks from the onboarding auto-equip apart.
##   - `auto_starter` — **deprecated, no current producer.** Was the PR #146
##     boot-equip bandaid's tag (`equip_starter_weapon_if_needed`, retired in
##     ticket `86c9qbb3k`). `equip()` has no `match`/branch on `source`, so the
##     value still type-checks as a valid `StringName` input — but nothing in
##     the codebase passes it any more. Kept documented (not deleted) so a
##     future re-introduction of a boot-time equip path has a named slot.
##   - (future) — additional `source` tags should be added rather than
##     overloading `lmb_click`.
##
## damage_after reads from `Damage.compute_player_damage` for weapon slots
## (the freshly-equipped weapon's light-attack damage at the player's current
## edge). Armor equips emit `damage_after=<player's existing weapon damage>`
## so the trace is mechanically uniform — but since equipping armor doesn't
## change weapon damage, the value is the same as before the equip; tests
## should not assert delta on armor equips.
##
## Mirror format with Player.try_attack's "POST damage=N" line: same
## `<tag> | <key>=<val>` style for grep parity.
func _emit_equip_trace(item: ItemInstance, slot: StringName, source: StringName) -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var df: Node = loop.root.get_node_or_null("DebugFlags")
	if df == null or not df.has_method("combat_trace"):
		return
	if item == null or item.def == null:
		return
	var item_id: String = String(item.def.id)
	var slot_str: String = String(slot)
	# Compute damage_after via the same formula Player.try_attack uses, so the
	# trace value matches what the next swing will deal.
	var damage_after: int = _compute_post_equip_damage()
	var msg: String = "item=%s slot=%s source=%s damage_after=%d" % [
		item_id, slot_str, String(source), damage_after,
	]
	df.combat_trace("Inventory.equip", msg)


## Read the current player's expected light-attack damage. Used by the
## Inventory.equip trace line so Sponsor / Playwright can assert "the
## post-equip damage value matches the equipped weapon" without hitting a
## grunt. Returns FIST_DAMAGE (1) if no Player or no weapon equipped — the
## same fallback `Damage.compute_player_damage(null, _, _)` returns.
func _compute_post_equip_damage() -> int:
	const DamageScript: Script = preload("res://scripts/combat/Damage.gd")
	var player: Node = _find_player()
	if player == null:
		# No Player in tree — return FIST_DAMAGE as the conservative default.
		return DamageScript.FIST_DAMAGE
	var weapon: ItemDef = null
	if player.has_method("get_equipped_weapon"):
		weapon = player.get_equipped_weapon() as ItemDef
	var edge: int = 0
	if player.has_method("get_edge"):
		edge = int(player.get_edge())
	return DamageScript.compute_player_damage(weapon, edge, &"light")
