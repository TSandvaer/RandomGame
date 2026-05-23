extends GutTest
## Tests for QuestDef typed Resource (M3 Tier 3 W2-T6, ticket `86c9y7ydg`).
##
## QuestDef is the authoring-side template for an offered quest. This file
## pins the schema + default values so a regression that drops a field
## (or changes its default) surfaces before the per-quest .tres fixtures
## start drifting.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const QuestDefScript: Script = preload("res://scripts/quests/QuestDef.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Schema defaults --------------------------------------------------

func test_default_quest_def_has_expected_field_defaults() -> void:
	var qd: QuestDef = QuestDefScript.new()
	assert_eq(qd.quest_id, &"", "quest_id defaults to empty StringName")
	assert_eq(qd.display_name, "", "display_name defaults to empty String")
	assert_eq(qd.accept_branch_quote, "",
		"accept_branch_quote defaults to empty String")
	assert_eq(qd.complete_branch_quote, "",
		"complete_branch_quote defaults to empty String")
	assert_eq(qd.reward_payload.size(), 0,
		"reward_payload defaults to empty Dictionary")
	assert_true(qd.reward_payload is Dictionary,
		"reward_payload typed as Dictionary")


func test_quest_def_round_trips_field_writes() -> void:
	# Sanity smoke: every authored field survives a write→read cycle. Catches
	# accidental @export type changes that would silently coerce values.
	var qd: QuestDef = QuestDefScript.new()
	qd.quest_id = &"s1_recover_stoker_proof"
	qd.display_name = "Recover the Stoker's Proof"
	qd.accept_branch_quote = "I will bring you proof."
	qd.complete_branch_quote = "Here is the proof."
	qd.reward_payload = {"xp": 250, "gold": 50}
	assert_eq(qd.quest_id, &"s1_recover_stoker_proof")
	assert_eq(qd.display_name, "Recover the Stoker's Proof")
	assert_eq(qd.accept_branch_quote, "I will bring you proof.")
	assert_eq(qd.complete_branch_quote, "Here is the proof.")
	assert_eq(qd.reward_payload["xp"], 250)
	assert_eq(qd.reward_payload["gold"], 50)
