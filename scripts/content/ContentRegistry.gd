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
##
## **HTML5 DirAccess quirk (load-bearing — ticket `86c9qah1f`):** in Godot 4.3
## HTML5 / `gl_compatibility` exports, `DirAccess.list_dir_begin()` over a
## res:// path packed inside the .pck may NOT enumerate subdirectories
## reliably — `current_is_dir()` can return false for entries that ARE
## directories on desktop. Pre-fix, the recursive scan worked on desktop +
## headless GUT but missed `resources/items/weapons/iron_sword.tres` in the
## HTML5 build, producing the boot-time
## `WARNING: ItemInstance.from_save_dict: unknown item id 'iron_sword'` on
## every F5-reload of a save with iron_sword equipped.
##
## **Fix:** alongside the recursive scan, we explicitly enumerate a list of
## known content subdirectories (`KNOWN_ITEM_SUBDIRS`) AND directly `load()`
## a list of starter content paths (`STARTER_ITEM_PATHS`). Direct `load()` of
## a packed res:// path always works in HTML5 — only DirAccess enumeration
## is unreliable. This guarantees the M1 starter inventory (iron_sword)
## resolves on every platform regardless of DirAccess behavior. Future
## starter / save-critical content should be appended to
## `STARTER_ITEM_PATHS` so a missing-from-DirAccess regression cannot ship.
##
## After `load_all()` completes, `is_resolved() == true` and the
## `items_resolved` signal has been emitted. Async-style awaiters (future
## use, e.g. `restore_from_save` calling `await registry.items_resolved` if
## the registry isn't yet built) should check `is_resolved()` first to avoid
## hanging on a never-fired signal.

const ITEMS_ROOT: String = "res://resources/items"
const AFFIXES_ROOT: String = "res://resources/affixes"

## Subdirectories under `ITEMS_ROOT` that are explicitly enumerated. Workaround
## for the HTML5 DirAccess `current_is_dir()` quirk: scanning the parent
## `resources/items` doesn't reliably recurse into these in the .pck-packed
## HTML5 export. Add to this list when a new top-level item subdir is
## introduced (e.g. `trinkets/`, `relics/`).
const KNOWN_ITEM_SUBDIRS: Array[String] = [
	"res://resources/items/weapons",
	"res://resources/items/armors",
]

## Critical content paths preloaded directly via `load()` regardless of
## DirAccess behavior. These are the items the save-restore path absolutely
## must resolve on every boot. Add new entries when a new save-critical item
## ships.
##
## **Why every item in a live loot table must be listed here (ticket `86c9uemdg`
## sibling — Sponsor M2 RC soak):** any item that can land in a save (via a
## live loot-table drop) needs a direct-load fallback. The recursive +
## KNOWN_ITEM_SUBDIRS scans are best-effort in HTML5 / `gl_compatibility`
## packed builds (the DirAccess `current_is_dir()` quirk + `list_dir_begin()`
## behavior on .pck resources is unreliable). Direct `load()` of a packed
## res:// path always works because it reads from the resource cache, not
## DirAccess. Pre-fix only `iron_sword.tres` was direct-loaded; Sponsor's
## M2 RC soak (build `5bef197`) surfaced `USER WARNING:
## ItemInstance.from_save_dict: unknown item id 'leather_vest'` on boot
## because the previous run had picked up a leather_vest (a guaranteed drop
## from the boss + a 0.30 cumulative weight on the grunt_drops table) into
## the save, and this run's HTML5 build failed to register it via DirAccess.
##
## **Inclusion rule:** any item appearing in `resources/loot_tables/*.tres`
## entries must be listed here. Future T2/T3 loot expansions need to extend
## this list as new items ship. The id-collision-from-different-instance
## guard in `_on_item_resource_found` lets the same item be registered
## multiple times by the three scan passes without warning.
const STARTER_ITEM_PATHS: Array[String] = [
	"res://resources/items/weapons/iron_sword.tres",
	"res://resources/items/armors/leather_vest.tres",
]

var _items: Dictionary = {}    # StringName -> ItemDef
var _affixes: Dictionary = {}  # StringName -> AffixDef
var _resolved: bool = false


## Emitted once at the end of a successful `load_all()` after all content
## maps are populated. Currently fires synchronously inside `load_all()` —
## any consumer that needs to gate on registry-ready can either:
##   (a) check `is_resolved()` first (fast path — almost always true by the
##       time anything outside `Main._ready` runs);
##   (b) `await registry.items_resolved` for the deferred case.
##
## Past-participle naming matches `Save.save_completed` / `Inventory.item_equipped`.
signal items_resolved()


## Scan both content directories and populate the registry. Idempotent —
## calling twice replaces the maps. Returns self for chaining.
##
## **Three-pronged scanning strategy** (HTML5-robust):
##   1. Recursive scan of `ITEMS_ROOT` / `AFFIXES_ROOT` (works on desktop,
##      partial in HTML5 due to DirAccess subdirectory recursion quirk).
##   2. Explicit subdirectory scan of `KNOWN_ITEM_SUBDIRS` (catches the
##      `weapons/`, `armors/` tier when the recursive scan misses them).
##   3. Direct `load()` of `STARTER_ITEM_PATHS` (load-bearing fallback —
##      always works because direct res:// `load()` reads from the packed
##      pck via the resource cache, not DirAccess).
##
## Steps 2 + 3 may register items already registered by step 1 — the
## `_on_item_resource_found` path silently skips same-instance duplicates
## (instance equality means the resource cache returned the same ItemDef
## twice, which is normal for a packed res:// path). Only an
## id-collision-from-different-instance warrants a push_warning.
func load_all() -> ContentRegistry:
	_items.clear()
	_affixes.clear()
	_resolved = false
	# Step 1: recursive scan from the roots.
	_scan_dir_recursive(ITEMS_ROOT, _on_item_resource_found)
	_scan_dir_recursive(AFFIXES_ROOT, _on_affix_resource_found)
	# Step 2: explicit subdirectory scan (HTML5 DirAccess fallback). Quiet
	# on open-fail because the recursive scan above may have already covered
	# these on platforms where DirAccess works correctly.
	for subdir: String in KNOWN_ITEM_SUBDIRS:
		_scan_dir_recursive(subdir, _on_item_resource_found, true)
	# Step 3: direct-load starter content paths (always-works fallback).
	for path: String in STARTER_ITEM_PATHS:
		var res: Resource = load(path)
		if res != null:
			_on_item_resource_found(res, path)
		else:
			push_warning("[ContentRegistry] starter item path %s failed to load" % path)
	_resolved = true
	items_resolved.emit()
	return self


## True after `load_all()` has completed at least once. Callers that need to
## gate on registry-ready (e.g. a deferred `Inventory.restore_from_save`) can
## fast-path on this and only `await items_resolved` when it's false.
func is_resolved() -> bool:
	return _resolved


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

## Scan `root` for .tres / .res files, recursing into subdirs.
##
## `quiet_on_open_fail` suppresses the push_warning when DirAccess can't open
## `root` — used by the `KNOWN_ITEM_SUBDIRS` second-pass scan in `load_all()`
## where a missing subdir is expected (the recursive scan already covered
## the same files on platforms where DirAccess works correctly).
func _scan_dir_recursive(root: String, on_resource: Callable, quiet_on_open_fail: bool = false) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		if not quiet_on_open_fail:
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
			_scan_dir_recursive(full_path, on_resource, quiet_on_open_fail)
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
	# Same-instance re-registration is a no-op (the three-pronged scan in
	# `load_all()` may visit the same path twice — DirAccess scan + explicit
	# subdir scan + STARTER_ITEM_PATHS preload). Only different-instance
	# id-collision warrants a warning.
	if _items.has(def.id) and _items[def.id] != def:
		push_warning("[ContentRegistry] duplicate ItemDef id '%s' at %s (overrides earlier)" % [def.id, path])
	_items[def.id] = def


func _on_affix_resource_found(res: Resource, path: String) -> void:
	if not (res is AffixDef):
		return
	var def: AffixDef = res
	if def.id == &"":
		push_warning("[ContentRegistry] AffixDef at %s has empty id — skipped" % path)
		return
	if _affixes.has(def.id) and _affixes[def.id] != def:
		push_warning("[ContentRegistry] duplicate AffixDef id '%s' at %s (overrides earlier)" % [def.id, path])
	_affixes[def.id] = def
