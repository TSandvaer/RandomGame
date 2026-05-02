extends GutTest
## Tests for the `Stratum` namespace class (multi-stratum tooling scaffold).
##
## Paired with `scripts/levels/Stratum.gd`. The namespace is the single
## source of truth for "which stratum is this?" — these tests pin the
## round-trip + listing contract so that adding a new stratum (M2: S2,
## M3+: S3..S8) requires updating both the production code AND this test
## file in lockstep, surfacing the change in code review.
##
## Per W3-B2 (Priya's `team/priya-pl/week-2-retro-and-week-3-scope.md` row
## B2): stratum-N references must be unambiguous; this test asserts the
## namespace is the place to resolve them.

const StratumScript: Script = preload("res://scripts/levels/Stratum.gd")


# ---- 1. Enum + ALL_IDS exhaustiveness -------------------------------

func test_all_ids_lists_every_known_stratum() -> void:
	# If this fails because the count changed, ALSO update the per-id
	# round-trip + display-name tests below. Keeping them in lockstep is
	# the whole point of having an exhaustive listing test.
	assert_eq(Stratum.ALL_IDS.size(), 8, "M1+M2 plan: 8 strata total")


func test_all_ids_in_descent_order() -> void:
	# ALL_IDS is the canonical descent order. M1 ships only S1; M2+ adds
	# the remaining slots. Order must be append-only — saves persist the
	# int value, so reordering would corrupt loaded saves silently.
	var expected: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
	for i in range(expected.size()):
		assert_eq(Stratum.ALL_IDS[i], expected[i], "ALL_IDS[%d]" % i)


func test_id_enum_values_match_int_constants() -> void:
	# The enum values are the persisted save format. Asserting them by
	# literal value (not just by enum-symbol equality) catches a sneaky
	# refactor that reorders the enum without realising saves break.
	assert_eq(int(Stratum.Id.S1), 1)
	assert_eq(int(Stratum.Id.S2), 2)
	assert_eq(int(Stratum.Id.S3), 3)
	assert_eq(int(Stratum.Id.S4), 4)
	assert_eq(int(Stratum.Id.S5), 5)
	assert_eq(int(Stratum.Id.S6), 6)
	assert_eq(int(Stratum.Id.S7), 7)
	assert_eq(int(Stratum.Id.S8), 8)


# ---- 2. is_known() bounds ------------------------------------------

func test_is_known_accepts_all_registered_ids() -> void:
	for id in Stratum.ALL_IDS:
		assert_true(Stratum.is_known(id), "id %d known" % id)


func test_is_known_rejects_zero() -> void:
	# 0 is the explicit "unknown" sentinel returned by id_from_prefix /
	# id_from_chunk_id / next on miss. Must round-trip cleanly via is_known.
	assert_false(Stratum.is_known(0))


func test_is_known_rejects_negatives() -> void:
	assert_false(Stratum.is_known(-1))
	assert_false(Stratum.is_known(-99))


func test_is_known_rejects_above_range() -> void:
	# 9 is the first id past the M1+M2 plan's S8 cap. Reject so a future
	# scaffolding bug that hands out 9 doesn't silently become "an unknown
	# but kinda-treated-as-valid" stratum.
	assert_false(Stratum.is_known(9))
	assert_false(Stratum.is_known(99))
	assert_false(Stratum.is_known(1000))


# ---- 3. prefix() / id_from_prefix() round-trip ----------------------

func test_prefix_roundtrip_for_every_id() -> void:
	# Stratum.S1 -> "s1" -> Stratum.S1. This is the contract that lets
	# the chunk loader route a chunk path back to its owning stratum.
	for id in Stratum.ALL_IDS:
		var p: StringName = Stratum.prefix(id)
		assert_ne(p, &"", "prefix(%d) non-empty" % id)
		var back: int = Stratum.id_from_prefix(p)
		assert_eq(back, id, "id_from_prefix(%s) -> %d" % [String(p), id])


func test_prefix_format_is_lowercase_s_plus_int() -> void:
	# Pin the convention so a future "S1"/"strat1" rename has to come
	# through here. Authoring tools, save keys, and resource paths all
	# depend on lowercase "sN".
	for id in Stratum.ALL_IDS:
		var p: String = String(Stratum.prefix(id))
		assert_eq(p, "s%d" % id, "prefix shape sN for id %d" % id)


func test_prefix_unknown_id_returns_empty() -> void:
	assert_eq(Stratum.prefix(0), &"", "0 has no prefix")
	assert_eq(Stratum.prefix(99), &"", "99 has no prefix")
	assert_eq(Stratum.prefix(-1), &"", "-1 has no prefix")


func test_id_from_prefix_unknown_returns_zero() -> void:
	# 0 is the explicit unknown sentinel — never == Id.S1, so callers can
	# use a truthy check (`if id_from_prefix(p):` reads as "known").
	assert_eq(Stratum.id_from_prefix(&"s99"), 0)
	assert_eq(Stratum.id_from_prefix(&""), 0)
	assert_eq(Stratum.id_from_prefix(&"foo"), 0)
	assert_eq(Stratum.id_from_prefix(&"S1"), 0, "case-sensitive (lowercase only)")


# ---- 4. display_name --------------------------------------------------

func test_display_name_for_every_id() -> void:
	for id in Stratum.ALL_IDS:
		var n: String = Stratum.display_name(id)
		assert_ne(n, "", "display_name(%d) non-empty" % id)
		assert_true(n.contains("Stratum"), "display_name contains 'Stratum'")


func test_display_name_unknown_id_returns_empty() -> void:
	assert_eq(Stratum.display_name(0), "")
	assert_eq(Stratum.display_name(99), "")


# ---- 5. next() descent ordering -------------------------------------

func test_next_walks_through_full_chain() -> void:
	# Walking next() from S1 must land on S2, S3, ... S8 then 0 (no more).
	var current: int = Stratum.Id.S1
	var visited: Array[int] = [current]
	while true:
		var nxt: int = Stratum.next(current)
		if nxt == 0:
			break
		visited.append(nxt)
		current = nxt
	# Visited every stratum in order, in exactly ALL_IDS.size() steps.
	assert_eq(visited.size(), Stratum.ALL_IDS.size(),
		"next() chain length matches ALL_IDS")
	for i in range(visited.size()):
		assert_eq(visited[i], Stratum.ALL_IDS[i], "next() chain step %d" % i)


func test_next_at_terminal_returns_zero() -> void:
	# S8 is the last known stratum in the M1+M2 plan. next(S8) -> 0 lets
	# the descent-portal flow detect "run completed".
	assert_eq(Stratum.next(Stratum.Id.S8), 0)


func test_next_unknown_returns_zero() -> void:
	assert_eq(Stratum.next(0), 0)
	assert_eq(Stratum.next(99), 0)
	assert_eq(Stratum.next(-1), 0)


# ---- 6. id_from_chunk_id parsing ------------------------------------

func test_id_from_chunk_id_for_authored_s1_chunks() -> void:
	# These are the actual chunk ids used in M1 .tres files. Pinning the
	# parser against real authored ids catches a regression where the
	# prefix split changes and silently returns 0.
	assert_eq(Stratum.id_from_chunk_id(&"s1_room01"), Stratum.Id.S1)
	assert_eq(Stratum.id_from_chunk_id(&"s1_room02"), Stratum.Id.S1)
	assert_eq(Stratum.id_from_chunk_id(&"s1_room08"), Stratum.Id.S1)


func test_id_from_chunk_id_for_future_strata() -> void:
	# Forward-compat — when M2 ships s2_room01.tres, the parser must
	# already route correctly. Tested here so the implementation can't
	# regress between now and M2.
	assert_eq(Stratum.id_from_chunk_id(&"s2_room01"), Stratum.Id.S2)
	assert_eq(Stratum.id_from_chunk_id(&"s3_boss"), Stratum.Id.S3)
	assert_eq(Stratum.id_from_chunk_id(&"s8_room01"), Stratum.Id.S8)


func test_id_from_chunk_id_malformed_returns_zero() -> void:
	# Anything without a `prefix_` shape, or with an unknown prefix, must
	# return 0 — never a coincidental "looks like S1 because it starts
	# with 's'".
	assert_eq(Stratum.id_from_chunk_id(&""), 0, "empty -> 0")
	assert_eq(Stratum.id_from_chunk_id(&"no_underscore_at_zero"), 0,
		"underscore at 0 not allowed (would be empty prefix)")
	assert_eq(Stratum.id_from_chunk_id(&"_room01"), 0,
		"leading underscore -> empty prefix -> 0")
	assert_eq(Stratum.id_from_chunk_id(&"s99_room01"), 0,
		"unknown prefix -> 0")
	assert_eq(Stratum.id_from_chunk_id(&"foo_bar"), 0,
		"unknown prefix -> 0")


# ---- 7. ALL_IDS / Id.* listing consistency --------------------------

func test_every_id_enum_value_appears_in_all_ids() -> void:
	# Belt-and-braces: ALL_IDS must be exhaustive vs the Id enum. If
	# someone adds Id.S9 but forgets ALL_IDS, this test fails.
	var enum_values: Array[int] = [
		Stratum.Id.S1,
		Stratum.Id.S2,
		Stratum.Id.S3,
		Stratum.Id.S4,
		Stratum.Id.S5,
		Stratum.Id.S6,
		Stratum.Id.S7,
		Stratum.Id.S8,
	]
	assert_eq(enum_values.size(), Stratum.ALL_IDS.size(),
		"every Id.S* appears in ALL_IDS")
	for v in enum_values:
		assert_true(v in Stratum.ALL_IDS, "Id %d in ALL_IDS" % v)
