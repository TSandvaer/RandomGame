extends GutTest
## Unit-level tests for the Pickup Area2D — collection lifecycle and the
## listener-owned destruction contract added by ticket `86c9u33h1`.
##
## **Background — ticket 86c9u33h1 (fixes Tess bug-bash 86c9kxx7h):** pre-fix,
## `Pickup._on_body_entered` called `queue_free()` unconditionally after
## emitting `picked_up` — independent of whether the listener accepted or
## rejected the item. Result: at 24/24 grid capacity, `Inventory.add()` rejected
## the item but the Pickup was already destroyed → silent loss with no feedback,
## no toast, no ground-leave.
##
## **Post-fix contract:** `Pickup._on_body_entered` emits `picked_up` and waits.
## The listener calls `pickup.consume_after_pickup()` IFF it accepted the item;
## otherwise the Pickup remains alive on the ground for the player to re-attempt
## after freeing a slot. The Pickup defers `_clear_collected_latch_if_alive` to
## re-arm the idempotency latch one frame later (only if still in the tree),
## supporting re-collection via a fresh body_entered transition.
##
## Edge cases covered:
##   1. Listener-consumed pickup is queue_freed (success path).
##   2. Listener-rejected pickup is NOT queue_freed (silent-drop bug fixed).
##   3. Latch re-arm: a rejected pickup can be re-collected after a frame +
##      a fresh body_entered (no double-emit during the same emit chain).
##   4. Mob bodies are filtered (collision_mask + group check).
##   5. Pickup with null item queue_frees defensively (no listener notified).

const PickupScript: Script = preload("res://scripts/loot/Pickup.gd")
const PickupScene: PackedScene = preload("res://scenes/loot/Pickup.tscn")


# Lightweight stand-in for the player's CharacterBody2D — we only need
# `is_in_group("player")` to return true.
class FakePlayerBody:
	extends CharacterBody2D
	func _init() -> void:
		add_to_group("player")


# Minimal listener that records picked_up calls and either accepts (calls
# consume_after_pickup) or rejects (does nothing).
class FakeListener:
	extends Node
	var should_accept: bool = true
	var collected_items: Array = []

	func on_picked_up(item: Variant, pickup: Pickup) -> void:
		collected_items.append(item)
		if should_accept:
			pickup.consume_after_pickup()


func _make_pickup(item: ItemInstance) -> Pickup:
	var p: Pickup = PickupScene.instantiate() as Pickup
	p.configure(item)
	return p


func _make_item() -> ItemInstance:
	var def: ItemDef = ContentFactory.make_item_def({"id": &"test_pickup_item"})
	return ItemInstance.new(def, ItemDef.Tier.T1)


# --- 1: listener-consumed pickup is queue_freed ---------------------------

func test_consumed_pickup_is_queue_freed_on_success() -> void:
	# Success path: listener calls consume_after_pickup → pickup queue_freed.
	# Pre-fix the Pickup queue_freed itself unconditionally; post-fix it waits
	# for the listener to call consume_after_pickup. This test asserts the
	# success path still queue_frees (the listener consumes correctly).
	var pickup: Pickup = _make_pickup(_make_item())
	add_child(pickup)  # Don't autofree — we expect queue_free to handle it.
	var listener: FakeListener = FakeListener.new()
	listener.should_accept = true
	add_child_autofree(listener)
	pickup.picked_up.connect(listener.on_picked_up)
	# Directly drive the body_entered handler with a fake player body.
	var body: FakePlayerBody = FakePlayerBody.new()
	add_child_autofree(body)
	pickup._on_body_entered(body)
	assert_eq(listener.collected_items.size(), 1, "listener received the pickup")
	# queue_free schedules deletion at end of frame; assert via the queued flag.
	assert_true(pickup.is_queued_for_deletion(),
		"Pickup is queue_freed on success (consume_after_pickup ran)")


# --- 2: listener-rejected pickup is NOT queue_freed (the bug 86c9u33h1) ---

func test_rejected_pickup_is_NOT_destroyed_silent_drop_bug_fixed() -> void:
	# THE LOAD-BEARING TEST for ticket 86c9u33h1. Pre-fix, the Pickup
	# queue_freed itself in `_on_body_entered` unconditionally — independent
	# of whether the listener accepted or rejected the item. Post-fix the
	# Pickup must STAY ALIVE when the listener rejects (no consume call).
	var pickup: Pickup = _make_pickup(_make_item())
	add_child_autofree(pickup)  # Autofree — pickup must survive end of test.
	var listener: FakeListener = FakeListener.new()
	listener.should_accept = false  # Reject — do NOT call consume_after_pickup.
	add_child_autofree(listener)
	pickup.picked_up.connect(listener.on_picked_up)
	var body: FakePlayerBody = FakePlayerBody.new()
	add_child_autofree(body)
	pickup._on_body_entered(body)
	# Listener was notified.
	assert_eq(listener.collected_items.size(), 1, "listener received the pickup")
	# THE INVARIANT: pickup must NOT be queue_freed on rejection.
	assert_false(pickup.is_queued_for_deletion(),
		"Pickup must NOT be queue_freed when listener rejects — " +
		"the silent-drop bug ticket 86c9u33h1 fixes")
	assert_true(is_instance_valid(pickup),
		"Pickup is still a valid instance after rejected collection")


# --- 3: latch re-arm — rejected pickup can be re-collected next frame -----

func test_rejected_pickup_latch_clears_for_re_collection() -> void:
	# Edge probe — after a rejected collection, the `_collected` latch must
	# clear by next frame so a fresh body_entered (player walk-off + walk-back)
	# can re-collect. The latch is critical for preventing double-emit during
	# the same synchronous emit chain, but it must NOT permanently lock the
	# Pickup against future collection attempts.
	var pickup: Pickup = _make_pickup(_make_item())
	add_child_autofree(pickup)
	var listener: FakeListener = FakeListener.new()
	listener.should_accept = false  # Round 1: reject.
	add_child_autofree(listener)
	pickup.picked_up.connect(listener.on_picked_up)
	var body: FakePlayerBody = FakePlayerBody.new()
	add_child_autofree(body)

	# Round 1 — rejection.
	pickup._on_body_entered(body)
	assert_eq(listener.collected_items.size(), 1, "round 1: emitted")
	assert_true(pickup._collected, "round 1: latch is set (mid-frame)")
	assert_true(is_instance_valid(pickup), "round 1: pickup still alive")
	# Drain the deferred call (`_clear_collected_latch_if_alive`).
	await get_tree().process_frame
	assert_false(pickup._collected,
		"round 1 → next frame: latch cleared by _clear_collected_latch_if_alive " +
		"(Pickup re-armed for a future re-attempt)")

	# Round 2 — re-emit body_entered with the listener now accepting.
	listener.should_accept = true
	pickup._on_body_entered(body)
	assert_eq(listener.collected_items.size(), 2,
		"round 2: pickup re-emitted picked_up after walk-off + walk-back-on")
	assert_true(pickup.is_queued_for_deletion(),
		"round 2: pickup consumed on accepting listener")


# --- 4: mob bodies are filtered ------------------------------------------

func test_mob_body_does_not_trigger_pickup() -> void:
	# Belt-and-suspenders: collision_mask = LAYER_PLAYER (bit 2), so the
	# physics layer should already prevent mobs from triggering body_entered.
	# But _on_body_entered also explicitly checks `is_in_group("player")` —
	# this test asserts the group check rejects a non-player body.
	var pickup: Pickup = _make_pickup(_make_item())
	add_child_autofree(pickup)
	var listener: FakeListener = FakeListener.new()
	add_child_autofree(listener)
	pickup.picked_up.connect(listener.on_picked_up)
	# A body that is NOT in the "player" group (e.g. a mob).
	var mob_body: CharacterBody2D = CharacterBody2D.new()
	add_child_autofree(mob_body)
	pickup._on_body_entered(mob_body)
	assert_eq(listener.collected_items.size(), 0,
		"mob body is filtered — no picked_up emission")
	assert_false(pickup.is_queued_for_deletion(),
		"mob body does not trigger queue_free either")


# --- 5: null-item Pickup self-frees defensively --------------------------

func test_null_item_pickup_self_frees_defensively() -> void:
	# Defensive code path: a Pickup with null item still self-frees on body
	# contact (avoids a stuck-on-ground orphan). This is the only path where
	# the Pickup queue_frees independent of the listener — the contract is
	# "no item to emit, no point staying around."
	var pickup: Pickup = _make_pickup(null)
	add_child(pickup)  # Don't autofree — expect queue_free to fire.
	var listener: FakeListener = FakeListener.new()
	add_child_autofree(listener)
	pickup.picked_up.connect(listener.on_picked_up)
	var body: FakePlayerBody = FakePlayerBody.new()
	add_child_autofree(body)
	pickup._on_body_entered(body)
	assert_eq(listener.collected_items.size(), 0,
		"null-item pickup does not emit picked_up")
	assert_true(pickup.is_queued_for_deletion(),
		"null-item pickup still self-frees (no orphan on ground)")
