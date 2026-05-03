class_name ContentRegistry
extends RefCounted
## Save-resolver registry for ItemDef + AffixDef lookups by StringName id.
##
## **Why this exists (BB-2 / `86c9m3911`):** Save round-trip persists items as
## `{id, tier, rolled_affixes:[{affix_id,value}]}` dicts (per
## `ItemInstance.to_save_dict`). To rebuild an `ItemInstance` on load,
## `ItemInstance.from_save_dict` needs `item_resolver(id) -> ItemDef` and
## `affix_resolver(id) -> AffixDef` callables. Main.gd shipped no-op
## resolvers in PR #107, silently dropping every saved item. This class is
## the resolver source of truth.
##
## **Scan paths:**
##   - `res://resources/items/**/*.tres`   (ItemDef instances)
##   - `res://resources/affixes/*.tres`    (AffixDef instances)
##
## Both directories are walked recursively at build time so new content drops
## under `weapons/`, `armors/`, etc. land automatically.
##
## **Usage:**
##   var reg := ContentRegistry.new()
##   reg.load_all()                          # scans both dirs
##   var def: ItemDef = reg.resolve_item(&"iron_sword")
##   var aff: AffixDef = reg.resolve_affix(&"swift")
##   var item_resolver: Callable = reg.item_resolver_callable()
##   var affix_resolver: Callable = reg.affix_resolver_callable()
##
## **M1 scope:** This is an in-process registry (not an autoload). Main.gd
## holds the only instance; tests can construct their own. M2's save schema
## v4 (`team/devon-dev/save-schema-v4-plan.md`) plans to promote this into a
## SaveSchema autoload that owns the resolvers + migration table together.
##
## **Performance:** ~5 .tres files in M1, scanned once at Main._ready, never
## re-scanned. Scan cost is negligible (single-digit ms on cold-load).

const ITEMS_ROOT: String = "res://resources/items"
const AFFIXES_ROOT: String = "res://resources/affixes"

var _items: Dictionary = {}    # StringName -> ItemDef
var _affixes: Dictionary = {}  # StringName -> AffixDef


## Scan both content directories and populate the registry. Idempotent —
## calling twice replaces the maps. Returns self for chaining.
func load_all() -> ContentRegistry:
	_items.clear()
	_affixes.clear()
	_scan_dir_recursive(ITEMS_ROOT, _on_item_resource_found)
	_scan_dir_recursive(AFFIXES_ROOT, _on_affix_resource_found)
	return self


## Number of items registered (for tests + diagnostics).
func item_count() -> int:
	return _items.size()


## Number of affixes registered (for tests + diagnostics).
func affix_count() -> int:
	return _affixes.size()


## Resolve an item def by id. Returns null on miss (caller logs).
func resolve_item(id: StringName) -> ItemDef:
	return _items.get(id, null) as ItemDef


## Resolve an affix def by id. Returns null on miss (caller logs).
func resolve_affix(id: StringName) -> AffixDef:
	return _affixes.get(id, null) as AffixDef


## Returns a Callable usable as the `item_resolver` arg to
## `Inventory.restore_from_save` / `ItemInstance.from_save_dict`.
##
## We bind via a lambda over `self` so the Callable owns a reference to the
## registry — no dangling-pointer risk if the call happens after the holder
## drops its var.
func item_resolver_callable() -> Callable:
	return func(id: StringName) -> Resource: return resolve_item(id)


## Returns a Callable usable as the `affix_resolver` arg.
func affix_resolver_callable() -> Callable:
	return func(id: StringName) -> Resource: return resolve_affix(id)


# ---- Internals ---------------------------------------------------------

func _scan_dir_recursive(root: String, on_resource: Callable) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		# Not fatal — content dir is optional in tests / minimal builds.
		push_warning("[ContentRegistry] cannot open dir %s (err %d)" % [root, DirAccess.get_open_error()])
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		# Skip hidden + reserved entries.
		if entry == "." or entry == ".." or entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path: String = root.path_join(entry)
		if dir.current_is_dir():
			_scan_dir_recursive(full_path, on_resource)
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			var res: Resource = load(full_path)
			if res != null:
				on_resource.call(res, full_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _on_item_resource_found(res: Resource, path: String) -> void:
	if not (res is ItemDef):
		# Not all .tres files in resources/items/ need to be ItemDefs (sub-
		# resources like ItemBaseStats can be authored separately). Skip.
		return
	var def: ItemDef = res
	if def.id == &"":
		push_warning("[ContentRegistry] ItemDef at %s has empty id — skipped" % path)
		return
	if _items.has(def.id):
		push_warning("[ContentRegistry] duplicate ItemDef id '%s' at %s (overrides earlier)" % [def.id, path])
	_items[def.id] = def


func _on_affix_resource_found(res: Resource, path: String) -> void:
	if not (res is AffixDef):
		return
	var def: AffixDef = res
	if def.id == &"":
		push_warning("[ContentRegistry] AffixDef at %s has empty id — skipped" % path)
		return
	if _affixes.has(def.id):
		push_warning("[ContentRegistry] duplicate AffixDef id '%s' at %s (overrides earlier)" % [def.id, path])
	_affixes[def.id] = def
