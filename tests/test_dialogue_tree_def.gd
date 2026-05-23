extends GutTest
## Tests for the DialogueTreeDef / DialogueBranch / DialogueResponse Resource
## schema (ticket `86c9xuab3` — M3 Tier 3 W1 dialogue system spike).
##
## Invariants covered:
##   1. Resource scripts load + .new() succeeds (smoke).
##   2. `resolve_branch(quest_state)` returns the correct branch when key
##      is present in `branches`.
##   3. `resolve_branch` falls back to `default_branch_key` when key absent.
##   4. `resolve_branch` returns null when neither key nor default is present
##      (controller is responsible for the WarningBus emission).
##   5. The 3 shipped .tres fixtures load + every branch entry is a
##      DialogueBranch + every response entry is a DialogueResponse
##      (drift-pin per `.claude/docs/test-conventions.md` §
##      Spec-string-vs-engine-emit drift — for typed-Resource analog).

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const TreeScript: Script = preload("res://scripts/dialogue/DialogueTreeDef.gd")
const BranchScript: Script = preload("res://scripts/dialogue/DialogueBranch.gd")
const ResponseScript: Script = preload("res://scripts/dialogue/DialogueResponse.gd")

const FIXTURE_PATHS: Array[String] = [
	"res://resources/dialogue/s1_warden_scholar.tres",
	"res://resources/dialogue/hub_vendor.tres",
	"res://resources/dialogue/hub_anvil_keeper.tres",
]

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Smoke ----------------------------------------------------------


func test_resource_scripts_load_and_instantiate() -> void:
	var tree: Resource = TreeScript.new()
	assert_not_null(tree, "DialogueTreeDef.new() returns non-null")
	var branch: Resource = BranchScript.new()
	assert_not_null(branch, "DialogueBranch.new() returns non-null")
	var response: Resource = ResponseScript.new()
	assert_not_null(response, "DialogueResponse.new() returns non-null")


# ---- AC2: resolve_branch happy path --------------------------------


func test_resolve_branch_returns_quest_state_branch_when_present() -> void:
	var tree: DialogueTreeDef = _make_tree_with_two_branches()
	var branch: DialogueBranch = tree.resolve_branch(&"quest_active")
	assert_not_null(branch, "quest_active branch is in the tree")
	assert_eq(branch.lines[0], "quest_active line", "resolved the quest_active branch")


# ---- AC3: resolve_branch falls back to default --------------------


func test_resolve_branch_falls_back_to_default_when_quest_state_absent() -> void:
	var tree: DialogueTreeDef = _make_tree_with_two_branches()
	# `quest_completed` is NOT in the test tree — should fall back to default.
	var branch: DialogueBranch = tree.resolve_branch(&"quest_completed")
	assert_not_null(branch, "default_branch_key (flavor) resolves")
	assert_eq(branch.lines[0], "flavor line", "fallback to default_branch_key")


# ---- AC4: resolve_branch returns null on unresolvable ----------


func test_resolve_branch_returns_null_when_neither_state_nor_default_present() -> void:
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"empty_npc"
	tree.default_branch_key = &"nonexistent"
	tree.branches = {}
	var branch: DialogueBranch = tree.resolve_branch(&"flavor")
	assert_null(
		branch,
		"unresolvable resolve_branch returns null (controller emits the warning, not the resource)"
	)


# ---- AC5: shipped fixtures load + schema invariants ----------


func test_all_fixtures_load_as_DialogueTreeDef() -> void:
	for path in FIXTURE_PATHS:
		var res: Resource = load(path)
		assert_not_null(res, "fixture loads: %s" % path)
		assert_true(res is DialogueTreeDef, "fixture is DialogueTreeDef instance: %s" % path)
		var tree: DialogueTreeDef = res as DialogueTreeDef
		assert_ne(String(tree.npc_id), "", "fixture has non-empty npc_id: %s" % path)
		assert_ne(tree.display_name, "", "fixture has non-empty display_name: %s" % path)
		assert_gt(tree.branches.size(), 0, "fixture has at least one branch: %s" % path)


func test_all_fixture_branches_are_DialogueBranch() -> void:
	# Drift-pin: catches authoring slips where a branches entry is a
	# Dictionary, String, or wrong-resource-type. The DialogueTreeDef field
	# is untyped Dictionary because Godot 4.3 GA had editor quirks with
	# typed Dictionary[StringName, DialogueBranch]; this test backstops
	# the lost type-check.
	for path in FIXTURE_PATHS:
		var tree: DialogueTreeDef = load(path) as DialogueTreeDef
		for key_v: Variant in tree.branches.keys():
			var entry: Variant = tree.branches[key_v]
			assert_true(
				entry is DialogueBranch,
				(
					"branch entry %s in %s is DialogueBranch (got: %s)"
					% [str(key_v), path, str(typeof(entry))]
				)
			)


func test_all_fixture_responses_are_DialogueResponse() -> void:
	# Drift-pin sibling — assert response array entries are DialogueResponse.
	for path in FIXTURE_PATHS:
		var tree: DialogueTreeDef = load(path) as DialogueTreeDef
		for key_v: Variant in tree.branches.keys():
			var branch: DialogueBranch = tree.branches[key_v] as DialogueBranch
			if branch == null:
				continue
			for r: Variant in branch.responses:
				assert_true(
					r is DialogueResponse,
					"response in branch %s of %s is DialogueResponse" % [str(key_v), path]
				)


# ---- Helpers --------------------------------------------------------


func _make_tree_with_two_branches() -> DialogueTreeDef:
	var flavor: DialogueBranch = BranchScript.new()
	flavor.lines = ["flavor line"]
	flavor.responses = []
	var active: DialogueBranch = BranchScript.new()
	active.lines = ["quest_active line"]
	active.responses = []
	var tree: DialogueTreeDef = TreeScript.new()
	tree.npc_id = &"test_npc"
	tree.display_name = "Test NPC"
	tree.branches = {
		&"flavor": flavor,
		&"quest_active": active,
	}
	tree.default_branch_key = &"flavor"
	return tree
