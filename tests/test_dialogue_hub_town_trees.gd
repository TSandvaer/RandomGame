extends GutTest
## Tests for the 3 hub-town dialogue trees shipped in W2-T2 (ticket
## `86c9y0zyv`). Smoke-loads each .tres + asserts schema invariants +
## opens each branch through the controller to confirm no fixture-level
## drift between author intent and engine resolution.
##
## Trees covered:
##   - resources/dialogue/hub_town/hadda_vendor.tres       (npc_id=hub_hadda)
##   - resources/dialogue/hub_town/brother_voll_anvil.tres (npc_id=hub_brother_voll)
##   - resources/dialogue/hub_town/sister_ennick_storyteller.tres
##                                                          (npc_id=hub_sister_ennick)
##
## Invariants pinned per tree:
##   1. .tres loads cleanly via `load(<path>)`.
##   2. npc_id, display_name fields populated.
##   3. branches Dictionary contains at least 2 branches.
##   4. default_branch_key resolves to a valid DialogueBranch.
##   5. Every branch entry `is DialogueBranch` (drift pin — survives the
##      "untyped Dictionary" choice in DialogueTreeDef per the W1 spike doc).
##   6. Every response entry `is DialogueResponse` (drift pin).
##   7. At least one branch contains at least one response with a non-empty
##      `quest_action` — pins the W2-T2 acceptance requirement that each
##      tree has "at least one quest_action side-effect emit to exercise
##      the QuestActionRouter listener stub" (per dispatch brief).
##
## Plus cross-tree invariants:
##   8. npc_ids are unique across the three trees.
##   9. Loading and opening each tree through DialogueController emits zero
##      WarningBus warnings (NoWarningGuard).

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

const HUB_TREE_PATHS := [
	"res://resources/dialogue/hub_town/hadda_vendor.tres",
	"res://resources/dialogue/hub_town/brother_voll_anvil.tres",
	"res://resources/dialogue/hub_town/sister_ennick_storyteller.tres",
]

const EXPECTED_NPC_IDS := [
	&"hub_hadda",
	&"hub_brother_voll",
	&"hub_sister_ennick",
]

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()
	var dc: Node = _controller()
	if dc != null and dc.has_method("is_active") and dc.is_active():
		dc.close()


func after_each() -> void:
	var dc: Node = _controller()
	if dc != null and dc.has_method("close"):
		dc.close()
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Per-tree smoke-loads -----------------------------------------

func test_hadda_vendor_tree_loads_clean() -> void:
	_assert_tree_smoke(HUB_TREE_PATHS[0], &"hub_hadda")


func test_brother_voll_anvil_tree_loads_clean() -> void:
	_assert_tree_smoke(HUB_TREE_PATHS[1], &"hub_brother_voll")


func test_sister_ennick_storyteller_tree_loads_clean() -> void:
	_assert_tree_smoke(HUB_TREE_PATHS[2], &"hub_sister_ennick")


# ---- Cross-tree invariants ---------------------------------------

func test_all_hub_town_trees_have_unique_npc_ids() -> void:
	var seen: Dictionary = {}
	for path: String in HUB_TREE_PATHS:
		var t: DialogueTreeDef = load(path) as DialogueTreeDef
		assert_not_null(t, "tree at %s loads" % path)
		assert_false(seen.has(t.npc_id),
			"npc_id %s appears in two trees" % str(t.npc_id))
		seen[t.npc_id] = true


func test_all_hub_town_trees_match_expected_npc_id_set() -> void:
	# Pins that the trio shipped matches the canonical hub-town roster
	# (Hadda / Brother Voll / Sister Ennick per m3-design-seeds.md §2).
	# A future refactor renaming an npc_id without updating the consumer
	# (the W3 hub-town impl spawning the NPCs) would fail this pin LOUDLY.
	var actual: Array = []
	for path: String in HUB_TREE_PATHS:
		var t: DialogueTreeDef = load(path) as DialogueTreeDef
		actual.append(t.npc_id)
	for expected: StringName in EXPECTED_NPC_IDS:
		assert_true(actual.has(expected),
			"expected npc_id %s present in hub-town trio" % str(expected))


func test_at_least_one_branch_per_tree_has_a_quest_action() -> void:
	# Dispatch-brief acceptance pin: "Each tree has 2-4 branches with at
	# least one `quest_action` side-effect emit to exercise the
	# QuestActionRouter listener stub."
	for path: String in HUB_TREE_PATHS:
		var t: DialogueTreeDef = load(path) as DialogueTreeDef
		var has_action: bool = false
		for key: StringName in t.branches:
			var branch: DialogueBranch = t.branches[key] as DialogueBranch
			if branch == null:
				continue
			for resp: DialogueResponse in branch.responses:
				if resp != null and resp.quest_action != &"":
					has_action = true
					break
			if has_action:
				break
		assert_true(has_action,
			"tree at %s has at least one response with non-empty quest_action" % path)


# ---- Helpers --------------------------------------------------------

func _controller() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("DialogueController")


func _assert_tree_smoke(path: String, expected_npc_id: StringName) -> void:
	# Pin 1: loads cleanly.
	var t: DialogueTreeDef = load(path) as DialogueTreeDef
	assert_not_null(t, "tree at %s loads as DialogueTreeDef" % path)
	# Pin 2: npc_id + display_name populated.
	assert_eq(t.npc_id, expected_npc_id,
		"npc_id matches expected (%s)" % str(expected_npc_id))
	assert_gt(t.display_name.length(), 0, "display_name non-empty")
	# Pin 3: branches dict has 2+ entries.
	assert_gte(t.branches.size(), 2,
		"tree has at least 2 branches (state-branching minimum)")
	# Pin 4 + 5: default_branch_key resolves + every branch is DialogueBranch.
	assert_true(t.branches.has(t.default_branch_key),
		"default_branch_key (%s) present in branches" % str(t.default_branch_key))
	for key: StringName in t.branches:
		var branch: DialogueBranch = t.branches[key] as DialogueBranch
		assert_not_null(branch,
			"branch at key %s is a DialogueBranch" % str(key))
		# Pin 6: every response is DialogueResponse.
		for r: DialogueResponse in branch.responses:
			assert_not_null(r,
				"response in branch %s is a DialogueResponse" % str(key))
	# Pin 9: opening the tree through controller emits no warnings.
	var dc: Node = _controller()
	var ok: bool = dc.open(t, t.default_branch_key)
	assert_true(ok, "controller opens default branch of %s" % path)
	assert_true(dc.is_active(), "session active after open")
	dc.close()
	assert_false(dc.is_active(), "session closed after close()")
