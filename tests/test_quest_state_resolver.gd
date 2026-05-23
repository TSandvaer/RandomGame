extends GutTest
## Tests for QuestStateResolver — the (npc_id, active_bounty,
## completed_bounties) → branch_key resolver (M3 Tier 3 W2-T6, ticket
## `86c9y7ydg`).
##
## **The 4-state matrix pin** (Part D of the W2-T6 ticket):
##
## | Player state                                                | Branch returned    |
## |---|---|
## | No active bounty, NPC's quest not in completed_bounties     | `&"pre_quest"`     |
## | active_bounty.quest_id == NPC's offered quest_id            | `&"quest_active"`  |
## | NPC's offered quest_id in completed_bounties                | `&"quest_completed"` |
## | NPC offers no quest (vendor/lore NPC)                       | `&"flavor"`        |
## | active_bounty for a DIFFERENT NPC's quest                   | `&"flavor"` (no business with the active bounty)
##
## Plus edge probes:
##   - String entries in completed_bounties (JSON-load shape) still match
##     by stringified comparison.
##   - completed_bounties precedence over no-active-bounty (a player who
##     COMPLETED + has NO active bounty sees quest_completed, not pre_quest).

const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")
const QuestStateScript: Script = preload("res://scripts/quests/QuestState.gd")
const QuestStateResolverScript: Script = preload(
	"res://scripts/quests/QuestStateResolver.gd")

var _warn_guard: NoWarningGuard


func before_each() -> void:
	_warn_guard = NoWarningGuard.new()
	_warn_guard.attach()


func after_each() -> void:
	_warn_guard.assert_clean(self)
	_warn_guard.detach()
	_warn_guard = null


# ---- NPC offers no quest → flavor -----------------------------------

func test_unknown_npc_resolves_to_flavor() -> void:
	# A vendor / lore NPC that isn't in NPC_OFFERED_QUEST defaults to
	# `&"flavor"` regardless of player state.
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_hadda", null, [])
	assert_eq(key, &"flavor",
		"hub_hadda (vendor, offers no quest) → flavor")


func test_unknown_npc_with_unrelated_active_bounty_still_flavor() -> void:
	# Vendor NPC sees flavor branch even if the player carries an unrelated
	# active bounty for ANOTHER NPC. Vendor has no business with it.
	var qs: QuestState = QuestStateScript.new()
	qs.quest_id = &"s1_recover_stoker_proof"
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_hadda", qs, [])
	assert_eq(key, &"flavor",
		"vendor flavor branch wins over unrelated active bounty")


# ---- NPC offers quest, no player state → pre_quest -----------------

func test_offered_npc_no_player_state_resolves_to_pre_quest() -> void:
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", null, [])
	assert_eq(key, &"pre_quest",
		"NPC offers quest + no active + not completed → pre_quest")


# ---- NPC offers quest, player on it → quest_active -----------------

func test_offered_npc_active_bounty_matches_resolves_to_quest_active() -> void:
	var qs: QuestState = QuestStateScript.new()
	qs.quest_id = &"s1_recover_stoker_proof"
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", qs, [])
	assert_eq(key, &"quest_active",
		"NPC offers quest + active matches → quest_active")


# ---- NPC offers quest, player completed it → quest_completed -------

func test_offered_npc_completed_resolves_to_quest_completed() -> void:
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", null,
		[StringName("s1_recover_stoker_proof")])
	assert_eq(key, &"quest_completed",
		"NPC offers quest + in completed_bounties → quest_completed")


# ---- Edge: completed PRECEDES no-active-bounty -----------------------

func test_completed_precedes_pre_quest_when_both_apply() -> void:
	# A player who has completed and currently has no active bounty MUST
	# see quest_completed, NOT pre_quest. The "no active" condition also
	# matches pre_quest in isolation; the resolver checks completed FIRST.
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", null,
		[StringName("s1_recover_stoker_proof")])
	assert_eq(key, &"quest_completed",
		"completed precedence over pre_quest when both conditions hold")


# ---- Edge: completed precedence over active (re-talk after complete) -

func test_completed_precedes_active_when_active_is_unrelated() -> void:
	# Player completed Sister Ennick's quest, then accepted SOME OTHER
	# bounty from another NPC. Talking to Sister Ennick again — should
	# see quest_completed (her bounty is done), not pre_quest (her bounty
	# is offered but already completed).
	var other_bounty: QuestState = QuestStateScript.new()
	other_bounty.quest_id = &"some_other_quest"  # not in NPC_OFFERED_QUEST
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", other_bounty,
		[StringName("s1_recover_stoker_proof")])
	assert_eq(key, &"quest_completed",
		"unrelated active bounty does NOT downgrade completed branch")


# ---- Edge: active bounty for DIFFERENT NPC's quest → pre_quest -----

func test_active_bounty_for_unrelated_quest_returns_pre_quest() -> void:
	# Player carries an active bounty FOR ANOTHER NPC's quest. Sister
	# Ennick has not been completed, so she shows pre_quest (the NPC's
	# content tree can choose to gate "I see you carry another's bounty"
	# at the content layer; the resolver doesn't model that).
	var other_bounty: QuestState = QuestStateScript.new()
	other_bounty.quest_id = &"some_unrelated_quest"
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", other_bounty, [])
	assert_eq(key, &"pre_quest",
		"unrelated active bounty + no completion → pre_quest (offer state)")


# ---- Edge: completed_bounties as String[] (JSON load shape) ---------

func test_completed_bounties_string_entries_still_match() -> void:
	# Save.gd JSON-serialises StringName as String; load returns
	# Array[String]. The resolver's `_completed_contains` helper normalises
	# the comparison via String(...) on both sides. Pin the shape.
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", null,
		["s1_recover_stoker_proof"])  # PLAIN String, not StringName
	assert_eq(key, &"quest_completed",
		"String entry in completed_bounties still matches by stringified compare")


# ---- Type tolerance: active_bounty as null vs QuestState ------------

func test_active_bounty_null_treated_as_no_active() -> void:
	# Explicit null is the no-active-bounty case. Should resolve to
	# pre_quest (NPC has not been completed).
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", null, [])
	assert_eq(key, &"pre_quest")


func test_active_bounty_non_quest_state_variant_treated_as_no_active() -> void:
	# A future regression might pass a Dictionary or String into the
	# resolver's active_bounty slot. The resolver's `is QuestState` check
	# means anything not-a-QuestState is treated as "no active bounty"
	# — defensive against future shape changes.
	var key: StringName = QuestStateResolver.resolve_branch_key(
		&"hub_sister_ennick", "not-a-quest-state", [])
	assert_eq(key, &"pre_quest",
		"non-QuestState active_bounty defensively treated as null")


# ---- NPC_OFFERED_QUEST map pin --------------------------------------

func test_npc_offered_quest_map_has_sister_ennick_entry() -> void:
	# W2-T6 shipped a single entry. When Track 3 W3 expands the map (per
	# the resolver doc), this assertion is the canary that the existing
	# entry survived the expansion.
	assert_true(QuestStateResolver.NPC_OFFERED_QUEST.has(&"hub_sister_ennick"),
		"NPC_OFFERED_QUEST contains hub_sister_ennick")
	assert_eq(QuestStateResolver.NPC_OFFERED_QUEST[&"hub_sister_ennick"],
		&"s1_recover_stoker_proof",
		"hub_sister_ennick offers s1_recover_stoker_proof")
