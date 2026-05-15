extends GutTest
## Paired tests for `fix(save-restore): await ContentRegistry resolver before
## restoring inventory items` — ClickUp `86c9qah1f`.
##
## **Bug guarded:** F5-reload of a save with iron_sword equipped produced
##   `WARNING: ItemInstance.from_save_dict: unknown item id 'iron_sword'`
## in the HTML5 / WebGL2 build. Root cause: `ContentRegistry`'s recursive
## DirAccess scan over the .pck-packed `res://resources/items` did not
## reliably enumerate subdirectories (`weapons/`, `armors/`) in HTML5 —
## `current_is_dir()` returned false for entries that ARE subdirs on
## desktop. iron_sword.tres lives at `resources/items/weapons/iron_sword.tres`
## so the registry's `_items` map was missing the key, the resolver returned
## null, `ItemInstance.from_save_dict` push_warning'd, and the save-restore
## auto-equip path silently re-equipped via direct `load()`. Benign for
## gameplay; pollutes the AC5 console-silence assertion the harness wants.
##
## **Fix shape:** `ContentRegistry.load_all()` is now three-pronged:
##   1. Recursive scan from `ITEMS_ROOT` / `AFFIXES_ROOT` (works on desktop).
##   2. Explicit subdir scan of `KNOWN_ITEM_SUBDIRS` (HTML5 fallback).
##   3. Direct `load()` of `STARTER_ITEM_PATHS` (always-works fallback).
## Steps 2+3 dedupe-via-instance-equality so re-registration doesn't warn.
## After load_all() completes, `is_resolved()` returns true and the
## `items_resolved` signal has been emitted.
##
## **What this file asserts:**
##   1. `ContentRegistry.load_all` populates `_items[&"iron_sword"]` on the
##      same code paths the production HTML5 build uses (direct path-load).
##   2. `is_resolved()` flips false→true across `load_all()`.
##   3. `items_resolved` signal emits exactly once on `load_all()`.
##   4. Round-trip: a save dict with iron_sword in `equipped.weapon` and
##      `stash[]` resolves through `Inventory.restore_from_save` using the
##      production `ContentRegistry.item_resolver_callable()` — equipped
##      slot ends up populated (proving the resolver returned non-null;
##      had it returned null, `from_save_dict` would have push_warning'd
##      and `_equipped[weapon]` would be empty).
##   5. Re-running `load_all()` is idempotent (same instance re-registered
##      doesn't push_warning).
##
## **AC5 dependency unlock:** Once this fix lands, the Playwright
## `equip-flow.spec.ts:454-471` filter for `unknown item id 'iron_sword'`
## becomes obsolete. The harness can shift from "filter known noise" to
## "assert console-clean" — which is the AC5 console-silence positive
## assertion this ticket exists to unlock.

const PlayerScript: Script = preload("res://scripts/player/Player.gd")
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")


# ---- Universal-warning gate (ticket 86c9uf0mm Half B) ----------------
##
## This whole file's purpose is pinning the no-warning posture for save-
## restore. The guard makes the contract explicit: every test must
## complete with zero ItemInstance.from_save_dict unknown-id warnings
## (otherwise the AC5 console-silence assertion regresses).

var _warn_guard: NoWarningGuard


func _inv() -> Node:
	var n: Node = Engine.get_main_loop().root.get_node_or_null("Inventory")
	assert_not_null(n, "Inventory autoload must be registered in project.godot")
	return n


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	_inv().reset()


func after_each() -> void:
	_inv().reset()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# =======================================================================
# AC1 — registry resolves iron_sword regardless of DirAccess behavior
# =======================================================================

func test_load_all_resolves_iron_sword_via_starter_paths() -> void:
	# This is the load-bearing assertion. If iron_sword is NOT in `_items`
	# after load_all(), the production save-restore will push_warning on
	# every F5 reload. Pre-fix this passed in headless GUT (DirAccess
	# subdir-recursion works on desktop) but failed in the HTML5 export.
	# The STARTER_ITEM_PATHS preload step makes this assertion platform-
	# agnostic — direct `load()` of a packed res:// path always works.
	var reg: ContentRegistry = ContentRegistry.new()
	reg.load_all()
	var def: ItemDef = reg.resolve_item(&"iron_sword")
	assert_not_null(def,
		"iron_sword MUST resolve via ContentRegistry after load_all() — " +
		"if null, save-restore will push_warning on F5 reload (ticket 86c9qah1f)")
	assert_eq(def.id, &"iron_sword", "resolved item id matches lookup key")


func test_load_all_starter_paths_register_even_if_diraccess_fails() -> void:
	# Stronger assertion: the STARTER_ITEM_PATHS list (line 79-81 of
	# ContentRegistry.gd) is the always-works fallback that guarantees the
	# starter sword resolves regardless of DirAccess behavior. Verify the
	# starter paths list contains the iron_sword path — drift detector. If
	# someone removes iron_sword from STARTER_ITEM_PATHS thinking the
	# DirAccess scan covers it, this fails and surfaces the regression.
	assert_true(
		ContentRegistry.STARTER_ITEM_PATHS.has("res://resources/items/weapons/iron_sword.tres"),
		"STARTER_ITEM_PATHS must include iron_sword.tres — load-bearing for " +
		"HTML5 save-restore (ticket 86c9qah1f). Do NOT remove without testing " +
		"in HTML5 build that DirAccess subdir recursion now works.")


# =======================================================================
# AC1b — REGRESSION-86c9uemdg: leather_vest also direct-loaded
# =======================================================================
# Sponsor M2 RC soak (build `5bef197`) surfaced:
#   USER WARNING: ItemInstance.from_save_dict: unknown item id 'leather_vest'
# fires once at boot. Root cause: same DirAccess subdir-recursion quirk as the
# iron_sword case (ticket 86c9qah1f) but for the `armors/` subdir instead of
# `weapons/`. Pre-fix only iron_sword was direct-loaded via STARTER_ITEM_PATHS;
# leather_vest relied on the DirAccess scan which silently failed in HTML5.
# `leather_vest` is in `boss_drops.tres` (guaranteed boss drop) AND
# `grunt_drops.tres` (0.30 cumulative weight) — so once it lands in a save,
# every subsequent boot push_warnings unless the registry direct-loads it.

func test_load_all_resolves_leather_vest_via_starter_paths() -> void:
	var reg: ContentRegistry = ContentRegistry.new()
	reg.load_all()
	var def: ItemDef = reg.resolve_item(&"leather_vest")
	assert_not_null(def,
		"REGRESSION-86c9uemdg: leather_vest MUST resolve via ContentRegistry after load_all() — " +
		"if null, save-restore push_warnings on every boot of a save containing leather_vest")
	assert_eq(def.id, &"leather_vest", "resolved item id matches lookup key")


func test_starter_item_paths_includes_leather_vest_drift_detector() -> void:
	# Drift detector mirror of the iron_sword test: if someone removes
	# leather_vest from STARTER_ITEM_PATHS thinking DirAccess covers it, this
	# fails and surfaces the regression. Any item that can land in a save (via
	# a live loot table) MUST be in STARTER_ITEM_PATHS — see the inclusion
	# rule in ContentRegistry.STARTER_ITEM_PATHS docstring.
	assert_true(
		ContentRegistry.STARTER_ITEM_PATHS.has("res://resources/items/armors/leather_vest.tres"),
		"REGRESSION-86c9uemdg: STARTER_ITEM_PATHS must include leather_vest.tres — " +
		"load-bearing for HTML5 save-restore of saves containing leather_vest. " +
		"Do NOT remove without verifying DirAccess subdir-recursion works for armors/ in HTML5.")


func test_restore_from_save_leather_vest_in_stash_resolves_silently() -> void:
	# Reproduces the Sponsor M2 RC soak symptom shape: save dict contains a
	# leather_vest entry, restore_from_save must NOT push_warning, and the
	# Inventory must contain the resolved ItemInstance.
	var save_data: Dictionary = {
		"equipped": {},
		"stash": [
			{
				"id": "leather_vest",
				"tier": 1,  # boss_drops.tres ships leather_vest at tier_modifier=1 (T2)
				"rolled_affixes": [],
				"stack_count": 1,
			},
		],
	}
	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		save_data,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1,
		"REGRESSION-86c9uemdg: stash with one leather_vest must produce one ItemInstance after restore")
	var inst: ItemInstance = items[0] as ItemInstance
	assert_not_null(inst.def,
		"restored leather_vest ItemInstance has non-null def (resolver returned non-null)")
	assert_eq(inst.def.id, &"leather_vest",
		"restored stash item is the leather_vest from the save dict")


# =======================================================================
# AC2 — is_resolved() flips false → true across load_all()
# =======================================================================

func test_is_resolved_starts_false() -> void:
	var reg: ContentRegistry = ContentRegistry.new()
	assert_false(reg.is_resolved(),
		"is_resolved() must be false before load_all() — gates async awaiters")


func test_is_resolved_flips_true_after_load_all() -> void:
	var reg: ContentRegistry = ContentRegistry.new()
	reg.load_all()
	assert_true(reg.is_resolved(),
		"is_resolved() must be true after load_all() completes")


# =======================================================================
# AC3 — items_resolved signal fires exactly once on load_all()
# =======================================================================

func test_items_resolved_signal_fires_on_load_all() -> void:
	var reg: ContentRegistry = ContentRegistry.new()
	watch_signals(reg)
	reg.load_all()
	assert_signal_emitted(reg, "items_resolved",
		"items_resolved signal must fire when load_all() completes")
	assert_signal_emit_count(reg, "items_resolved", 1,
		"items_resolved must fire exactly once per load_all() call")


# =======================================================================
# AC4 — Inventory.restore_from_save with a real iron_sword save resolves
#         through production resolvers, populating equipped slot
# =======================================================================
# This is the integration-level proof. If the resolver had returned null
# for iron_sword, ItemInstance.from_save_dict would have push_warning'd
# AND returned null, leaving _equipped[weapon] empty. Asserting the
# equipped slot is populated post-restore is the structural proof that
# zero warnings fired during the resolver chain.

func test_restore_from_save_iron_sword_equipped_resolves_silently() -> void:
	var inv: Node = _inv()
	# Need a real Player so _apply_equip_to_player wires through (per the
	# dual-surface rule — see .claude/docs/combat-architecture.md). The
	# Player adds itself to the "player" group in _ready, which is how
	# Inventory._find_player picks it up.
	var player: Player = PlayerScript.new()
	add_child_autofree(player)

	# Build a production-shaped save dict matching what the running game
	# would have written: iron_sword equipped in the weapon slot, no stash.
	var save_data: Dictionary = {
		"equipped": {
			"weapon": {
				"id": "iron_sword",
				"tier": 0,  # ItemDef.Tier.T1
				"rolled_affixes": [],
				"stack_count": 1,
			},
		},
		"stash": [],
	}

	# Use the PRODUCTION resolver path — same Callable Main.get_item_resolver()
	# returns. Pre-fix this would have returned null for iron_sword in HTML5
	# (and thus push_warning'd via from_save_dict). With the three-pronged
	# load_all() this resolves cleanly on every platform.
	var registry: ContentRegistry = ContentRegistry.new().load_all()
	inv.restore_from_save(
		save_data,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)

	# Equipped slot must be populated post-restore — the structural proof
	# that the resolver returned non-null for iron_sword.
	var equipped: ItemInstance = inv.get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped,
		"equipped weapon slot must be populated after restore_from_save — " +
		"if null, the resolver returned null and from_save_dict push_warning'd " +
		"(ticket 86c9qah1f symptom: 'unknown item id iron_sword' on F5 reload)")
	assert_not_null(equipped.def, "restored ItemInstance has non-null def")
	assert_eq(equipped.def.id, &"iron_sword",
		"restored equipped weapon is the iron_sword from the save dict")
	# Dual-surface assertion (per combat-architecture.md): _apply_equip_to_player
	# must have been called, propagating the equip onto the Player surface.
	var weapon_on_player: ItemDef = player.get_equipped_weapon() as ItemDef
	assert_not_null(weapon_on_player,
		"Player._equipped_weapon must be set after restore_from_save — " +
		"the dual-surface rule (combat-architecture.md) requires both surfaces in lockstep")
	assert_eq(weapon_on_player.id, &"iron_sword",
		"Player surface holds the iron_sword post-restore")


func test_restore_from_save_iron_sword_in_stash_resolves_silently() -> void:
	# Same resolver path, but iron_sword is in the stash (inventory grid)
	# rather than equipped. Different code branch in restore_from_save —
	# both branches call the same from_save_dict resolver, so this catches
	# any future divergence between the two paths.
	var save_data: Dictionary = {
		"equipped": {},
		"stash": [
			{
				"id": "iron_sword",
				"tier": 0,
				"rolled_affixes": [],
				"stack_count": 1,
			},
		],
	}
	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		save_data,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)
	var items: Array = _inv().get_items()
	assert_eq(items.size(), 1,
		"stash with one iron_sword must produce one ItemInstance after restore")
	var inst: ItemInstance = items[0] as ItemInstance
	assert_not_null(inst.def,
		"restored stash ItemInstance has non-null def (resolver returned non-null)")
	assert_eq(inst.def.id, &"iron_sword",
		"restored stash item is the iron_sword from the save dict")


# =======================================================================
# AC5 — load_all() is idempotent: re-running on the same instance does
#        NOT push_warning even though the same item is registered twice
# =======================================================================

func test_load_all_is_idempotent_across_two_calls() -> void:
	var reg: ContentRegistry = ContentRegistry.new()
	reg.load_all()
	var iron_first: ItemDef = reg.resolve_item(&"iron_sword")
	assert_not_null(iron_first, "first load_all resolves iron_sword")
	# Re-run. The three-pronged scan will visit iron_sword.tres MULTIPLE
	# times in a single call (recursive scan of items_root + KNOWN_ITEM_SUBDIRS
	# explicit scan of weapons/ + STARTER_ITEM_PATHS direct load). The
	# _on_item_resource_found dedupe (instance equality) keeps this silent.
	reg.load_all()
	var iron_second: ItemDef = reg.resolve_item(&"iron_sword")
	assert_not_null(iron_second, "second load_all still resolves iron_sword")
	# Resource cache hands out the same instance for the same path, so
	# instance equality holds across both registrations.
	assert_eq(iron_first, iron_second,
		"load_all is idempotent — same instance returned on re-scan")


# =======================================================================
# AC6 — affixes still resolve (no regression from the items-only fix)
# =======================================================================

func test_load_all_still_resolves_affixes() -> void:
	var reg: ContentRegistry = ContentRegistry.new()
	reg.load_all()
	# `swift.tres` is one of the iron_sword's affix pool — exercised on
	# F5-reload of a save where iron_sword has a swift roll.
	var swift: AffixDef = reg.resolve_affix(&"swift")
	assert_not_null(swift,
		"swift affix must still resolve — items-only fix must not regress affixes")


func test_load_all_iron_sword_with_affix_round_trips_through_restore() -> void:
	# Combined: iron_sword equipped WITH a swift affix roll. Both the item
	# resolver AND the affix resolver must succeed for from_save_dict to
	# return a non-null instance with the affix attached. We don't need a
	# real Player here — the assertion is on the resolver chain producing
	# a non-null ItemInstance with the affix attached, not on the dual-
	# surface propagation (covered by the equipped-slot test above).
	var save_data: Dictionary = {
		"equipped": {
			"weapon": {
				"id": "iron_sword",
				"tier": 0,
				"rolled_affixes": [{"affix_id": "swift", "value": 0.08}],
				"stack_count": 1,
			},
		},
		"stash": [],
	}
	var registry: ContentRegistry = ContentRegistry.new().load_all()
	_inv().restore_from_save(
		save_data,
		registry.item_resolver_callable(),
		registry.affix_resolver_callable(),
	)
	var equipped: ItemInstance = _inv().get_equipped(&"weapon") as ItemInstance
	assert_not_null(equipped, "iron_sword + swift round-trips cleanly")
	assert_eq(equipped.rolled_affixes.size(), 1,
		"swift affix attached to restored iron_sword")
	assert_eq(equipped.rolled_affixes[0].def.id, &"swift",
		"affix def resolved correctly via affix_resolver_callable")
