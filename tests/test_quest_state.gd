extends GutTest
## Tests for QuestState typed Resource + its to_dict / from_dict
## serialisation (M3 Tier 3 W2-T6, ticket `86c9y7ydg`).
##
## QuestState is the persisted-instance counterpart to QuestDef. The
## load-bearing surface here is the symmetric serialisation contract
## that Save.gd round-trips through `data.character.active_bounty`.

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const QuestStateScript: Script = preload("res://scripts/quests/QuestState.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- Defaults ---------------------------------------------------------

func test_default_quest_state_has_expected_field_defaults() -> void:
	var qs: QuestState = QuestStateScript.new()
	assert_eq(qs.quest_id, &"", "quest_id defaults to empty StringName")
	assert_eq(qs.accepted_at_tick, 0, "accepted_at_tick defaults to 0")
	assert_eq(qs.completion_progress.size(), 0,
		"completion_progress defaults to empty Dictionary")
	assert_eq(qs.state, &"quest_active",
		"state defaults to &\"quest_active\"")


# ---- Serialisation: to_dict / from_dict symmetry ---------------------

func test_to_dict_produces_json_safe_shape() -> void:
	var qs: QuestState = QuestStateScript.new()
	qs.quest_id = &"s1_recover_stoker_proof"
	qs.accepted_at_tick = 42_000
	qs.completion_progress = {"kills_remaining": 3}
	qs.state = &"quest_active"
	var d: Dictionary = qs.to_dict()
	# StringName fields stringified per JSON-friendliness (matches
	# v4 ember_bags convention).
	assert_eq(d["quest_id"], "s1_recover_stoker_proof",
		"quest_id stringified in to_dict")
	assert_eq(d["accepted_at_tick"], 42_000)
	assert_eq(d["completion_progress"]["kills_remaining"], 3)
	assert_eq(d["state"], "quest_active",
		"state stringified in to_dict")


func test_from_dict_then_to_dict_round_trips() -> void:
	# Symmetric round-trip: build → serialise → deserialise → re-serialise.
	# Both serialisations should yield identical Dictionaries.
	var qs_a: QuestState = QuestStateScript.new()
	qs_a.quest_id = &"s1_recover_stoker_proof"
	qs_a.accepted_at_tick = 12_345
	qs_a.completion_progress = {"kills_remaining": 2, "extra_kills": 0}
	qs_a.state = &"quest_active"
	var d_a: Dictionary = qs_a.to_dict()
	var qs_b: QuestState = QuestStateScript.from_dict(d_a)
	assert_not_null(qs_b, "from_dict returns a QuestState on valid payload")
	assert_eq(qs_b.quest_id, &"s1_recover_stoker_proof",
		"quest_id restored as StringName")
	assert_eq(qs_b.accepted_at_tick, 12_345)
	assert_eq(qs_b.completion_progress["kills_remaining"], 2)
	assert_eq(qs_b.completion_progress["extra_kills"], 0)
	assert_eq(qs_b.state, &"quest_active",
		"state restored as StringName")
	# Re-serialise; should equal the original.
	var d_b: Dictionary = qs_b.to_dict()
	assert_eq(d_a, d_b, "round-trip serialisation is identity")


# ---- from_dict tolerance / rejection ---------------------------------

func test_from_dict_returns_null_on_null_payload() -> void:
	assert_eq(QuestStateScript.from_dict(null), null,
		"from_dict(null) returns null (no-active-bounty case)")


func test_from_dict_returns_null_on_non_dictionary_payload() -> void:
	assert_eq(QuestStateScript.from_dict("not-a-dict"), null,
		"from_dict(non-Dict) returns null")
	assert_eq(QuestStateScript.from_dict(42), null,
		"from_dict(int) returns null")


func test_from_dict_returns_null_on_missing_quest_id() -> void:
	assert_eq(QuestStateScript.from_dict({}), null,
		"from_dict({}) returns null (missing quest_id)")
	assert_eq(QuestStateScript.from_dict({"state": "quest_active"}), null,
		"from_dict missing quest_id returns null even with other keys present")


func test_from_dict_returns_null_on_empty_quest_id() -> void:
	assert_eq(QuestStateScript.from_dict({"quest_id": ""}), null,
		"from_dict with empty-string quest_id returns null")


func test_from_dict_tolerates_missing_optional_fields() -> void:
	# Best-effort partial-payload: only quest_id is required. Other fields
	# get their defaults.
	var qs: QuestState = QuestStateScript.from_dict({
		"quest_id": "test_quest",
	})
	assert_not_null(qs, "from_dict with only quest_id returns a QuestState")
	assert_eq(qs.quest_id, &"test_quest")
	assert_eq(qs.accepted_at_tick, 0,
		"missing accepted_at_tick defaults to 0")
	assert_eq(qs.completion_progress.size(), 0,
		"missing completion_progress defaults to empty Dict")
	assert_eq(qs.state, &"quest_active",
		"missing state defaults to quest_active")


func test_from_dict_tolerates_non_dict_completion_progress() -> void:
	# Defensive: malformed payload where completion_progress isn't a Dict
	# (hand-edited save, partial corruption) — should default to {} rather
	# than crash.
	var qs: QuestState = QuestStateScript.from_dict({
		"quest_id": "test_quest",
		"completion_progress": "not-a-dict",
	})
	assert_not_null(qs)
	assert_eq(qs.completion_progress.size(), 0,
		"malformed completion_progress defaults to empty Dict")


# ---- Deep-copy invariant for completion_progress --------------------

func test_to_dict_returns_deep_copy_of_completion_progress() -> void:
	# from_dict / to_dict should not share dict references with the source,
	# or a Save.gd write would silently mutate live runtime state on later
	# completion_progress edits.
	var qs: QuestState = QuestStateScript.new()
	qs.quest_id = &"share_test"
	qs.completion_progress = {"kills": 5}
	var d: Dictionary = qs.to_dict()
	d["completion_progress"]["kills"] = 999
	assert_eq(qs.completion_progress["kills"], 5,
		"mutating to_dict() output does NOT mutate QuestState.completion_progress")
