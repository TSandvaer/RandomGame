class_name Main
extends Node2D
## Main entry-scene controller — the M1 play-loop spine.
##
## Wires together the entire M1 product surface that previously shipped as
## isolated subsystems with paired GUT tests but no integration:
##
##   - Stratum1Room01 spawns as the starting room with Player + grunts.
##   - HUD (CanvasLayer) shows HP/XP/level + build SHA + room counter.
##   - InventoryPanel mounts (hidden); Tab toggles per Uma `inventory-stats-panel.md`.
##   - StatAllocationPanel mounts; auto-opens on first level-up per Uma `level-up-panel.md`.
##   - Mob death -> Levels.gain_xp + MobLootSpawner -> Pickup -> Inventory.add (auto-collect).
##   - Player death -> M1 death rule: level + equipped survive, unequipped + run-progress reset.
##   - RoomGate clears unlock the next room; Rooms 1->8 chain reachable.
##   - Stratum1BossRoom reachable from Room 08; boss intro + 3-phase fight + descend.
##   - Save on quit (NOTIFICATION_WM_CLOSE_REQUEST); load on boot.
##
## **Why one controller scene (vs. dispersed):** Every subsystem already has
## its own _ready / signal surface — what's missing is the plumbing that
## chains them at runtime. Putting it here keeps the sequence visible and
## makes the integration test (`test_m1_play_loop.gd`) a single owner.
##
## **Headless-test friendliness:** every step is also reachable via public
## methods (`load_room_index`, `force_descend_for_test`, `apply_death_rule`,
## etc.) so the integration test can advance the loop deterministically
## without relying on physics overlap or wall-clock waits.

# ---- Signals ----------------------------------------------------------

## Emitted whenever the active room scene swaps. Carries the new room's
## node and the room index (0-based — Room01 = 0, Room08 = 7, BossRoom = 8).
signal room_changed(room: Node, index: int)

## Emitted when the player dies (after the death rule has been applied and
## the player respawned at Room01). Useful for tests + future death-screen
## hook.
signal player_respawned

## Emitted after the boss is defeated and the descend signal fires.
signal stratum_descended

# ---- Constants --------------------------------------------------------

const SAVE_SLOT: int = 0

## Room sequence — 8 stratum-1 rooms, the S1 boss room, then the S2 boss
## room as a terminal index. Indexed by `_current_room_index`.
##
## **W3-T7 Stage 6 (ticket `86c9y7ygj`) — S2 boss room reachability.** The
## Stratum2BossRoom was authored standalone through Stages 1-5 with no
## `_load_room_at_index` consumer (unreachable in production play). Stage 6
## appends it at index 9 (`S2_BOSS_ROOM_INDEX`) so it is reachable via the
## SAME production room-load mechanism every other room uses — and via the
## `DebugFlags.start_room=9` URL hook for soak / Playwright.
##
## **Terminal index = the S2 traversal terminal (ticket `86ca1m0ph`).** The
## descend flow (`_on_descend_restart_run`) now drives a real S2 floor
## transition via `FloorAssembler.assemble_floor(...)` (Option A): it traverses
## the S2 zones (`S2_ZONE_IDS`: z1 → z2 → z3) then loads THIS index 9 entry as
## the authored z4 (`s2_z4_inner_sanctum`) boss-room terminal. The S2 boss room
## is reached by the production descend path (and still via `?start_room=9` for
## soak / Playwright). See `_on_descend_restart_run` → `_begin_stratum_2` →
## `_load_s2_zone` → `_enter_s2_boss_room`.
const ROOM_SCENE_PATHS: Array[String] = [
	"res://scenes/levels/Stratum1Room01.tscn",
	"res://scenes/levels/Stratum1Room02.tscn",
	"res://scenes/levels/Stratum1Room03.tscn",
	"res://scenes/levels/Stratum1Room04.tscn",
	"res://scenes/levels/Stratum1Room05.tscn",
	"res://scenes/levels/Stratum1Room06.tscn",
	"res://scenes/levels/Stratum1Room07.tscn",
	"res://scenes/levels/Stratum1Room08.tscn",
	"res://scenes/levels/Stratum1BossRoom.tscn",
	"res://scenes/levels/Stratum2BossRoom.tscn",
]

## Index of the S1 boss room. The room-clear auto-advance (`_on_room_cleared`)
## still treats this as the S1 terminal — it does NOT auto-advance into the
## S2 boss room (descend is the inter-stratum gate). The S2 boss room is
## reached via `start_room=9` (soak) or the future S2 sequence, never by
## linear room-clear from the S1 boss.
const BOSS_ROOM_INDEX: int = 8

## W3-T7 Stage 6 — terminal index of the Stratum-2 boss room. Reachable via
## `_load_room_at_index(9)` (start_room hook / future S2 sequence). Wired in
## `_wire_room_signals` through the shared boss-room branch.
const S2_BOSS_ROOM_INDEX: int = 9

## S2 traversal (ticket `86ca1m0ph`, Option A — procgen-driven). The descend
## flow assembles each S2 zone via `FloorAssembler.assemble_floor(...)` in
## graph order (entry → boss-adjacent), then hands off to the authored
## Stratum2BossRoom (`ROOM_SCENE_PATHS[S2_BOSS_ROOM_INDEX]`) as the terminal.
##
## The zone_ids are the AUTHORITATIVE `ZoneDef.zone_id` values (NOT the .tres
## filenames). The non-boss zones z1→z2→z3 form a linked list via each exit
## anchor's `target_zone_id`; z4 (`s2_z4_inner_sanctum`) IS the authored boss
## room (see `ROOM_INDEX_TO_ZONE_ID[9]`), so it is loaded as the boss scene
## rather than assembled procedurally.
##
## **Content note (verified 2026-05-31, this PR).** The s2_roomNN chunk
## `.tres` resources HAVE authored `scene_path` (e.g. `s2_room01_chunk.tscn`),
## `ports`, and declarative `mob_spawns` — so z1/z2/z3 assemble to non-empty
## bounding boxes AND render their authored chunk geometry. TWO gaps remain,
## both OUT OF SCOPE for this traversal-wiring ticket (see PR body
## § "Cross-lane content gaps"):
##   1. **No runtime consumes `LevelChunkDef.mob_spawns`** — the assembler
##      records chunk placements but does not spawn mobs, and the chunk
##      `.tscn` roots are static geometry (no mob-spawn script). So S2 mid-
##      floor zones render geometry but spawn no mobs yet. Mob-spawn wiring
##      for assembled chunks is a separate surface.
##   2. **No chunk-clear signal exists** — there is no `LevelChunk.gd` /
##      `chunk_cleared` / `room_cleared` on chunk scenes (grep-confirmed). So
##      the zone-progression seam (`_on_s2_zone_advance_ready`) auto-advances
##      z1 → z2 → z3 → boss room rather than gating on a clear. When chunk
##      mob-spawn + clear-trigger content lands, only that advance condition
##      swaps from auto to clear-gated — every other seam here is unchanged.
const S2_ZONE_IDS: Array[StringName] = [
	&"s2_z1_entry_hall",
	&"s2_z2_reading_chamber",
	&"s2_z3_archive_vault",
]

## res:// path template for resolving an S2 ZoneDef from its zone_id. The
## filename slug matches the zone_id 1:1 for the S2 set.
const S2_ZONE_DEF_PATH_FMT: String = "res://resources/level/zones/%s.tres"

## Stratum index passed to FloorAssembler.derive_stratum_seed for S2 zones.
const S2_STRATUM_ID: int = 2

## Fallback world-bounds for an S2 assembled floor whose bounding box is
## degenerate (zero-size). Mirrors the S1_ROOM_BOUNDS viewport-native shape;
## the live floor normally drives bounds from `assembled.bounding_box_px`.
const S2_ROOM_BOUNDS: Rect2 = Rect2(0, 0, 480, 270)

## Room IDs for StratumProgression bookkeeping (matches the chunk_def.id
## fields in the .tres files). One-to-one with ROOM_SCENE_PATHS.
const ROOM_IDS: Array[StringName] = [
	&"s1_room01",
	&"s1_room02",
	&"s1_room03",
	&"s1_room04",
	&"s1_room05",
	&"s1_room06",
	&"s1_room07",
	&"s1_room08",
	&"s1_boss_room",
	&"s2_boss_room",  # W3-T7 Stage 6 — terminal S2 boss room
]

## M3 Tier 3 W2-T5 (ticket `86c9y10fv`) — world-map discovery hook.
## Every S1 room (Rooms 01-08 + boss) maps to the single S1 ZoneDef
## `s1_z1_outer_cloister` (the W2-T3 retrofit shipped one zone covering
## the full S1 narrative arc — see `resources/level/zones/s1_z1_outer_cloister.tres`).
## When `_load_room_at_index` fires for ANY S1 index, the player's
## `discovered_zones[s1_z1_outer_cloister] = true` is set idempotently.
##
## Forward-compat: when procgen impl (W2-T3) replaces `ROOM_SCENE_PATHS`
## traversal with `AssembledFloor` consumption, this constant becomes the
## `room_idx → zone_id` fallback for non-procgen rooms; the procgen path
## will derive the zone_id from the AssembledFloor.zone_id field. The
## present mapping is correct at HEAD (all M3 S1 content lives in the
## one zone).
const ROOM_INDEX_TO_ZONE_ID: Array[StringName] = [
	&"s1_z1_outer_cloister",  # Room 01
	&"s1_z1_outer_cloister",  # Room 02
	&"s1_z1_outer_cloister",  # Room 03
	&"s1_z1_outer_cloister",  # Room 04
	&"s1_z1_outer_cloister",  # Room 05
	&"s1_z1_outer_cloister",  # Room 06
	&"s1_z1_outer_cloister",  # Room 07
	&"s1_z1_outer_cloister",  # Room 08
	&"s1_z1_outer_cloister",  # S1 Boss room — still part of S1 z1
	&"s2_z4_inner_sanctum",  # W3-T7 Stage 6 — S2 boss room = S2 zone 4 (inner sanctum)
]

const PLAYER_SCENE_PATH: String = "res://scenes/player/Player.tscn"
const INVENTORY_PANEL_SCENE_PATH: String = "res://scenes/ui/InventoryPanel.tscn"
const DIALOGUE_PANEL_SCENE_PATH: String = "res://scenes/ui/DialoguePanel.tscn"
const STAT_PANEL_SCENE_PATH: String = "res://scenes/ui/StatAllocationPanel.tscn"
const DESCEND_SCREEN_SCENE_PATH: String = "res://scenes/screens/DescendScreen.tscn"
const BOSS_DEFEATED_TITLE_CARD_SCENE_PATH: String = "res://scenes/ui/BossDefeatedTitleCard.tscn"
## M3-T2-W2-T12 — global vignette CanvasLayer at layer 5 (above world, below
## HUD). Wave-2 foundation for T13 boss-entry deepen + T16 boss-defeat
## cinematic. Default boots at S1 baseline 30% per Uma vignette-spec.md.
const VIGNETTE_SCENE_PATH: String = "res://scenes/ui/Vignette.tscn"

## Player spawn position — center of a 480x270 internal canvas (rooms are
## sized to that grid per Uma's visual-direction lock).
const DEFAULT_PLAYER_SPAWN: Vector2 = Vector2(240, 200)

## M3-T3-W2-T1 — Continuous-scroll wiring. The CameraDirector spike (PR #314,
## ticket `86c9xu9yt`) added `follow_target(target, deadzone_px)` +
## `set_world_bounds(bounds)`. W2-T1 (ticket `86c9y0zmg`) wires every room
## load to engage continuous-scroll against the player with these constants.
##
## **Authored S1 room bounds — Rect2(0, 0, 480, 270).** All current
## Stratum-1 rooms (Rooms 01-08 + boss room) are authored at viewport-native
## 480×270. Per `.claude/docs/camera-scroll.md` § "Bounds-clamp math —
## viewport-aware", a `bounds.size <= viewport_world` rect takes the
## "narrower than viewport" branch in `_clamp_to_world_bounds` and centers
## the camera on the bounds center — preserving the pre-T9 viewport-stretch
## visual EXACTLY. Engaging follow_target is therefore zero-visual-change
## for current S1 content while still wiring the production code-path that
## W2-T3+ procgen / multi-chunk rooms will consume.
##
## **Forward-compat note (post-PR-#344):** `AssembledFloor.bounding_box_px`
## now exists on main (W2-T3 procgen). `Main.gd` does NOT yet consume it —
## room load goes through `ROOM_SCENE_PATHS` + authored .tscn instantiation.
## When the procgen W2-T3-impl PR swaps `_load_room_at_index` to consume
## `AssembledFloor`, the `set_world_bounds(...)` call below should switch
## its source from `S1_ROOM_BOUNDS` to `assembled.bounding_box_px` per
## `.claude/docs/procgen-pipeline.md` § "AssembledFloor output shape".
const S1_ROOM_BOUNDS: Rect2 = Rect2(0, 0, 480, 270)

## Half-extents of the camera deadzone in WORLD pixels. Identical to the
## W1 spike's authored value (`scenes/spike/CameraScrollSpike.tscn` →
## `scripts/spike/CameraScrollSpike.gd`). Vector2(40, 24) = 80×48 freely-
## moveable rectangle — small enough that the player rarely sits outside,
## large enough that single-frame WASD doesn't shake the camera.
const CAMERA_FOLLOW_DEADZONE: Vector2 = Vector2(40, 24)

# ---- Runtime ---------------------------------------------------------

# Active scene-tree pointers. _world holds the current room; _player is
# parented to the world root so the room's bounds + camera reference work.
var _world: Node2D = null
var _player: Player = null
var _hud: CanvasLayer = null
var _inventory_panel: CanvasLayer = null
## DialoguePanel mount (ticket W2-T2 `86c9y0zyv` — production wiring layer
## for the W1 dialogue spike `86c9xuab3`). Mounted in `_ready` parallel to
## the InventoryPanel mount; the panel subscribes to DialogueController
## signals from its own `_ready` and self-shows on `branch_opened` /
## self-hides on `dialogue_closed`. PANEL_LAYER = 90, above InventoryPanel
## (80) and HUD (10) so a future "dialogue-during-inventory" path renders
## correctly (single-session guard prevents it today, but layer ordering
## future-proofs).
var _dialogue_panel: CanvasLayer = null
var _stat_panel: CanvasLayer = null
var _descend_screen: CanvasLayer = null
## M3-T2-W2-T12 — global vignette CanvasLayer (layer 5). Built in _ready
## between world (layer 0) and HUD (layer 10). Exposes
## `set_opacity_tween(value, duration, curve_preset)` + the three convenience
## methods used by T13 + T16. Cross-stratum single object — does not rebuild
## on stratum transition.
var _vignette: Vignette = null
var _current_room: Node = null
var _current_room_index: int = 0
var _boss_room: Stratum1BossRoom = null
## W3-T7 Stage 6 — generic boss-room handle. Set for BOTH the S1 boss room
## (index 8) and the S2 boss room (index 9). `_boss_room` (typed
## Stratum1BossRoom) stays null for the S2 room; the generic node handle is
## used for the cross-boss `get_stratum_exit()` read in
## `_on_stratum_exit_unlocked`. Both rooms expose `get_stratum_exit()`.
var _boss_room_node: Node = null
var _loot_spawner: MobLootSpawner = null

## S2 procgen-traversal state (ticket `86ca1m0ph`, Option A). `_s2_zone_index`
## < 0 means "not currently in an S2 procgen floor". `_s2_world_seed` is the
## per-character seed (stable per save) the zone seeds derive from.
## `_s2_floor_container` holds the instantiated assembled-floor chunks (a
## Node2D under `_world`); it is freed on zone advance + on the boss-room
## handoff. `_s2_chunks_remaining` tracks live chunk instances for the
## forward-compatible chunk-clear progression (0 today since chunks are
## data-only shells — see S2_ZONE_IDS doc).
## `_s2_mobs_remaining` tracks live mobs spawned from the placed chunks'
## `mob_spawns` (ticket `86ca3amgt`). The chunk-clear zone-advance GATE is a
## SEPARATE ticket (`86ca3amyb`); this PR only makes the mobs EXIST + be
## trackable. Auto-advance behaviour is UNCHANGED here.
var _s2_zone_index: int = -1
var _s2_world_seed: int = 0
var _s2_floor_container: Node2D = null
var _s2_chunks_remaining: int = 0
var _s2_mobs_remaining: int = 0
var _s2_mobs: Array[Node] = []

## Room01 onboarding gate (ticket 86c9qbb3k). When the Room01 PracticeDummy
## dies it drops an iron_sword Pickup; the room advance to Room02 must WAIT
## until the player walks onto that Pickup and auto-equips it — otherwise the
## immediate room-load would `queue_free` Room01 (and the Pickup with it)
## before the player could ever collect it, and the "never fistless"
## onboarding guarantee would be impossible. This flag is set true when the
## dummy dies while the player is unequipped; `_on_weapon_equipped` clears it
## and fires the deferred room advance.
##
## **Post-death respawn path (P0 fix, ticket 86c9ujf0q):** when the player IS
## already equipped (death-respawn preserved the iron_sword in the equipped slot
## per the M1 death rule), the dummy still drops a fresh iron_sword Pickup on
## death. The prior "skip gate and advance immediately via call_deferred" path
## freed Room01 — taking the Pickup with it — before the player could ever reach
## it. `_room01_already_equipped_awaiting_pickup_add` is set true on that path;
## `_on_weapon_added_to_grid` listens to Inventory.item_added and fires the room
## advance once the Pickup lands in the grid (or if the player re-equips it).
var _room01_awaiting_pickup_equip: bool = false
## True when the dummy died while player was already-equipped (respawn path) and
## we are waiting for the dummy-dropped iron_sword to be collected into the grid.
## Mutually exclusive with `_room01_awaiting_pickup_equip`.
var _room01_already_equipped_awaiting_add: bool = false

# HUD widgets (built by _build_hud).
var _hp_label: Label = null
var _hp_bar: ProgressBar = null
## ColorRect shimmer overlay for the out-of-combat HP regen cue (Uma's spec
## hp-regen-design.md §"Visual cue"). Parented at the same position and size as
## _hp_bar; drawn on top with MOUSE_FILTER_IGNORE. modulate is tweened between
## rest (Color.WHITE / alpha=0 pass-through) and shimmer peak when regen is active.
var _hp_bar_shimmer: ColorRect = null
var _hp_shimmer_tween: Tween = null
var _xp_label: Label = null
var _xp_bar: ProgressBar = null
var _level_label: Label = null
var _room_label: Label = null
var _build_label: Label = null
var _stat_pip_label: Label = null
var _boot_banner_label: Label = null
## Save-confirmation toast (Ticket 2 — `86c9q7p38`). Bottom-right widget that
## fades in/out on every successful `Save.save_completed`. Connects on its
## own `_ready` — Main only needs to add it to the HUD CanvasLayer.
var _save_toast: SaveToast = null
## Tutorial-prompt overlay (ticket `86c9qajcf` — Drew Stage 2b prereq scaffold).
## Center-anchored non-modal prompt that fades in / holds / fades out on every
## `TutorialEventBus.tutorial_beat_requested` emission. Connects on its own
## `_ready` — Main only needs to add it to the HUD CanvasLayer. NO content
## triggers are wired here at scaffold time; Drew's Stage 2b PR fires beats
## from Room01.
var _tutorial_overlay: TutorialPromptOverlay = null

# Save-on-quit guard so we don't double-write when both NOTIFICATION_WM_CLOSE_REQUEST
# and `_exit_tree` fire on shutdown.
var _saved_on_quit: bool = false

# Content registry — scans res://resources/items + res://resources/affixes at
# boot and supplies the save-resolver Callables consumed by
# `Inventory.restore_from_save`. Built in `_ready` before the save loads so
# the resolvers can rebuild full ItemInstances on restore.
#
# Per BB-2 (`86c9m3911`): the previous shipping code passed two no-op
# resolvers here, which silently dropped every saved item. The registry +
# the resolver Callables it exposes are the production fix.
var _content_registry: ContentRegistry = null


func _ready() -> void:
	# We listen for the OS close-request to autosave. Without this, browsers
	# tab-closing would lose run state.
	get_tree().auto_accept_quit = false
	_loot_spawner = MobLootSpawner.new()
	# Build the content registry FIRST — `_load_save_or_defaults` consumes its
	# resolver callables, so it must exist before that runs (same _ready).
	_content_registry = ContentRegistry.new().load_all()
	_build_world_root()
	# M3-T2-W2-T12: vignette CanvasLayer (layer 5) sits between world (layer 0)
	# and HUD (layer 10). Build BEFORE HUD so the scene-tree order matches the
	# layer order — a defensive habit even though CanvasLayer rendering is
	# driven by `layer`, not child order.
	_build_vignette()
	_build_hud()
	_build_inventory_panel()
	_build_dialogue_panel()
	_build_stat_panel()
	_spawn_player()
	_subscribe_to_levels()
	_subscribe_to_inventory()
	_subscribe_to_player_stats()
	# Load save (or defaults) BEFORE loading the first room so the player's
	# HP / XP / level / equipped state is correct when the room spawns mobs.
	_load_save_or_defaults()
	# NOTE: there is no boot-time starter-weapon auto-equip here any more. The
	# PR #146 `equip_starter_weapon_if_needed` bandaid was retired in ticket
	# 86c9qbb3k. The design-correct onboarding path is auto-equip-first-weapon-
	# on-pickup: the Stage-2b Room01 PracticeDummy drops an iron_sword, the
	# player walks onto it, and `Inventory.on_pickup_collected` auto-equips it
	# (first-weapon-only). A save-restored equipped weapon is honored by
	# `_load_save_or_defaults` above, exactly as before.
	_load_room_at_index(0)
	_refresh_hud_full()
	print("[Main] M1 play-loop ready — Room 01 loaded, autoloads wired")
	# DebugFlags.start_room URL-param soak utility (2026-05-21, PR #291 v4 self-soak
	# gap). When set on the HTML5 URL (e.g. `?start_room=8`), bypass the Room 01 →
	# Room N traversal by jumping directly to Room N AFTER the normal Room 01
	# bootstrap. The Room 01 load above still happens (so autoloads / signals are
	# wired identically to production) — we just immediately replace the active
	# room with Room N. Same shape as the `boss_hp_mult` query-param soak utility.
	# `-1` (default) = no override. Clamped to `[0, BOSS_ROOM_INDEX]` in DebugFlags.
	var df: Node = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.get("start_room") != null:
		var target: int = int(df.start_room)
		if target >= 0 and target != 0:
			print("[Main] DebugFlags.start_room=%d — bypassing Room 01 traversal" % target)
			_load_room_at_index(target)
	# DebugFlags.force_descend URL-param soak utility (W2-T5 fix ticket
	# `86c9y10fv`, 2026-05-24). When `?force_descend=1` is set on the HTML5
	# URL, open the DescendScreen immediately AFTER the normal Room 01 boot.
	# This bypasses the boss-kill chain so the Playwright spec for the
	# "Open Map button → WorldMapPanel mount" path can exercise the click
	# handler empirically without needing to play through 8 rooms + a boss
	# fight. Same HTML5-only shape as `start_room`. The descend handoff
	# (force_descend_for_test → _on_descend_triggered) is the exact same
	# code path the StratumExit interaction fires in production.
	if df != null and bool(df.get("force_descend")):
		print("[Main] DebugFlags.force_descend=true — auto-opening DescendScreen")
		force_descend_for_test()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_on_quit()
		get_tree().quit()


func _exit_tree() -> void:
	# Reset the auto_accept_quit override we installed in `_ready` so a test
	# scene tear-down doesn't leak the override into other GUT tests. In
	# production this path also runs at engine shutdown but is harmless
	# (the override only matters while the tree is alive).
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop != null:
		loop.auto_accept_quit = true


# ---- Public API ------------------------------------------------------


## Returns the active room node (Stratum1Room01 / MultiMobRoom / Stratum1BossRoom).
func get_current_room() -> Node:
	return _current_room


func get_current_room_index() -> int:
	return _current_room_index


func get_player() -> Player:
	return _player


func get_inventory_panel() -> CanvasLayer:
	return _inventory_panel


## W2-T2 `86c9y0zyv` — accessor parallel to `get_inventory_panel()`. Returns
## the mounted DialoguePanel (or null in stripped test contexts). Tests pin
## "DialoguePanel is mounted on Main" via this accessor + the source-scan
## invariant in `tests/test_main_dialogue_panel_mounted.gd`.
func get_dialogue_panel() -> CanvasLayer:
	return _dialogue_panel


func get_stat_panel() -> CanvasLayer:
	return _stat_panel


func get_descend_screen() -> CanvasLayer:
	return _descend_screen


func get_hud() -> CanvasLayer:
	return _hud


## M3-T2-W2-T12 — vignette accessor. Returns null if scene failed to load
## (the load-failure path pushes a warning in `_build_vignette`). Wave-3
## consumers (T13/T16) prefer this getter over poking `_vignette` directly
## from outside the class.
func get_vignette() -> Vignette:
	return _vignette


## Returns the HP bar shimmer ColorRect node. Used by the paired regen shimmer
## test (AC-7 visual-primitive invariant) to assert modulate delta without
## poking internals via find_child traversal.
func get_hp_bar_shimmer() -> ColorRect:
	return _hp_bar_shimmer


## Returns the SaveToast widget. Used by paired tests (Ticket 2 AC2.x) to
## assert the toast actually mounts in the HUD without find_child traversal.
func get_save_toast() -> SaveToast:
	return _save_toast


## Returns the TutorialPromptOverlay widget. Used by paired tests (ticket
## `86c9qajcf` Tier 2 bus integration) to assert the overlay mounts in the
## HUD without find_child traversal. Drew's Stage 2b tests use the same
## accessor to assert the overlay surfaces the resolved text on bus emit.
func get_tutorial_overlay() -> TutorialPromptOverlay:
	return _tutorial_overlay


## Returns the boot-banner Label that lists all 7 player input actions
## (per `project.godot` §[input]). Used by the paired test
## `tests/test_boot_banner.gd` and any future onboarding tweak.
func get_boot_banner_label() -> Label:
	return _boot_banner_label


func is_boss_room_active() -> bool:
	return _current_room_index == BOSS_ROOM_INDEX


## Programmatically advance to the room at `index`. Used by the
## integration test to skip the gate-clear plumbing for a particular
## waypoint. Production never calls this — production flows through
## `_on_room_cleared`.
func load_room_index(index: int) -> void:
	_load_room_at_index(index)


## Force-apply the M1 death rule: level + equipped survive, unequipped
## inventory + run progression reset, HP refilled, player respawned at
## Room01. Used by both the live `player_died` handler and the integration
## test's death-rule assertions.
func apply_death_rule() -> void:
	# Per DECISIONS.md 2026-05-02 "M1 death rule":
	#   - keep: level, equipped, V/F/E (PlayerStats), unspent stat points.
	#   - lose: unequipped inventory items, cleared-rooms progression, in-progress XP.
	# Levels.set_state(level, 0) zeroes mid-level XP without changing level.
	#
	# **Diagnostic trace (ticket 86c9u397c — Drew investigation, 2026-05-15).**
	# Pairs with the `[combat-trace] Player._die` line in `Player._die` so the
	# entire death → respawn sequence is unambiguous in the trace stream. This
	# is what disambiguates a Player-death-driven "mob freeze" (the mobs were
	# freed when Room N was destroyed by the room reload) from a real
	# physics-flush sibling-freeze. See `Player._die` for the full rationale.
	var df: Node = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		(
			df
			. combat_trace(
				"Main.apply_death_rule",
				"reloading Room 01 — death rule: keep level/equipped/stats, lose unequipped+progression+xp"
			)
		)
	var levels: Node = _levels()
	if levels != null:
		levels.set_state(levels.current_level(), 0)
	var inventory: Node = _inventory()
	if inventory != null:
		inventory.clear_unequipped()
	var sp: Node = _stratum_progression()
	if sp != null:
		sp.reset()
	# Refill HP and clear the dead latch on the current player node.
	if _player != null:
		_player.revive_full_hp()
	# Re-load Room01 (replaces _current_room).
	_load_room_at_index(0)
	# Persist immediately so a quit-during-respawn doesn't lose the rule.
	_persist_to_save()
	player_respawned.emit()


## Test-only / dispatch convenience — drive the descend handoff directly,
## bypassing the StratumExit interaction sequence. Production fires this
## via the StratumExit's `descend_triggered` signal (player walks to portal
## + presses E).
func force_descend_for_test() -> void:
	_on_descend_triggered()


## Test/gate accessor — the live mobs spawned from the current S2 assembled
## floor's chunk `mob_spawns` (ticket `86ca3amgt`). Empty when not in an S2
## procgen floor. The sibling chunk-clear gate ticket (`86ca3amyb`) consumes
## this + `s2_mobs_remaining()` to hold zone advance until cleared.
func get_s2_mobs() -> Array[Node]:
	return _s2_mobs


## Count of live S2 mobs spawned from the current assembled floor. 0 when not
## in an S2 procgen floor.
func s2_mobs_remaining() -> int:
	return _s2_mobs_remaining


## Snapshot all autoload state into a payload + persist via Save autoload.
## Returns true on success.
func save_now(slot: int = SAVE_SLOT) -> bool:
	return _persist_to_save(slot)


## Access the content registry (for tests + future systems).
func get_content_registry() -> ContentRegistry:
	return _content_registry


## Returns the **production** item-resolver Callable used by the save-load
## path. Tests should drive this same Callable into Inventory.restore_from_save
## so a future regression of "Main uses no-ops, test uses shims" is impossible.
func get_item_resolver() -> Callable:
	if _content_registry == null:
		# Shouldn't happen — `_ready` always builds the registry — but stay
		# defensive so a partially-constructed Main in unit tests doesn't crash.
		return func(_id: StringName) -> Resource: return null
	return _content_registry.item_resolver_callable()


## Returns the production affix-resolver Callable. See `get_item_resolver`.
func get_affix_resolver() -> Callable:
	if _content_registry == null:
		return func(_id: StringName) -> Resource: return null
	return _content_registry.affix_resolver_callable()


# ---- World / scene construction --------------------------------------


func _build_world_root() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)


func _spawn_player() -> void:
	var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[Main] failed to load Player scene at %s" % PLAYER_SCENE_PATH)
		return
	_player = packed.instantiate() as Player
	if _player == null:
		push_error("[Main] Player scene did not instantiate as Player")
		return
	_player.name = "Player"
	_player.position = DEFAULT_PLAYER_SPAWN
	_world.add_child(_player)
	# Player.gd's _ready adds itself to the "player" group so existing
	# group-lookup callers (Pickup / Grunt._resolve_player / InventoryPanel)
	# find it without further wiring.
	# Subscribe death so we drive the respawn flow.
	if not _player.player_died.is_connected(_on_player_died):
		_player.player_died.connect(_on_player_died)
	if not _player.hp_changed.is_connected(_on_player_hp_changed):
		_player.hp_changed.connect(_on_player_hp_changed)
	# Wire the regen shimmer: regen_active_changed drives the HpBarShimmer tween.
	if not _player.regen_active_changed.is_connected(_on_player_regen_active_changed):
		_player.regen_active_changed.connect(_on_player_regen_active_changed)


# ---- Room loading ----------------------------------------------------


func _load_room_at_index(index: int) -> void:
	if index < 0 or index >= ROOM_SCENE_PATHS.size():
		push_error("[Main] room index %d out of range" % index)
		return
	# Defensive: clear the Room01 onboarding pickup gate on any room load.
	# Normally `_on_weapon_equipped` clears it before firing the advance, but
	# any other code path that loads a room while the gate is armed must not
	# leak the `Inventory.item_equipped` connection into the next room.
	_clear_room01_pickup_gate()
	# Tear down old room. Use queue_free so any signal listeners running on
	# this tick can finish first (mirrors Grunt._die's defer-free pattern).
	if _current_room != null:
		# Unparent the player BEFORE freeing the room so we don't take the
		# player down with it.
		if _player != null and _player.get_parent() == _current_room:
			_current_room.remove_child(_player)
			_world.add_child(_player)
		_current_room.queue_free()
		_current_room = null
		_boss_room = null
		_boss_room_node = null
	var packed: PackedScene = load(ROOM_SCENE_PATHS[index]) as PackedScene
	if packed == null:
		push_error("[Main] failed to load room scene %s" % ROOM_SCENE_PATHS[index])
		return
	var room: Node = packed.instantiate()
	_current_room = room
	_current_room_index = index
	_world.add_child(room)
	# Re-parent player inside the new room so room-relative position is
	# stable + the room script's spawned children share its tree.
	if _player != null:
		if _player.get_parent() != null:
			_player.get_parent().remove_child(_player)
		_player.position = DEFAULT_PLAYER_SPAWN
		room.add_child(_player)
	# M3-T3-W2-T1 — Engage continuous-scroll follow against the freshly-
	# re-parented player + clamp the camera to the room's authored bounds.
	# Both calls are idempotent per spike's idempotence semantics
	# (`.claude/docs/camera-scroll.md` § "Public API"): same target + same
	# deadzone → no signal spam, same bounds → no-op. Per-tick player-
	# fallback lookup in `CameraDirector._process` handles room-cycle re-
	# resolution if the player reference goes stale. The boss room uses
	# the same call shape but ALSO runs its own engage at the end of
	# `_assemble_room_fixtures` (deferred), guarding against an edge-case
	# where the deferred fixture pass could re-trigger camera bounds
	# changes after a future widened-boss-room refactor lands.
	_engage_camera_for_room()
	# Wire room-specific signals.
	_wire_room_signals(room, index)
	# M3 Tier 3 W2-T5 — world-map discovery hook (ticket `86c9y10fv`).
	# Idempotent on re-entry (Player.mark_zone_discovered returns false if
	# the zone was already discovered). Fires AFTER room is wired so the
	# trace stream's room-load ordering reads consistently
	# (room loaded → camera engaged → mob signals wired → discovery written).
	_mark_zone_discovered_for_room_index(index)
	# Push pickups into the room (loot spawner re-targets so dropped pickups
	# get freed when the room frees).
	_loot_spawner.set_parent_for_pickups(room)
	# M3-T2-W2-T10 — Stratum-1 ambient bed. For every non-boss S1 room
	# (indices 0..7) start (or idempotently keep playing) the S1 ambient.
	# The boss room (index 8) explicitly does NOT start ambient — the
	# `Stratum1BossRoom.entry_sequence_started` handler stops S1 ambient as
	# part of BI-03 (boss-room entry sequence Beat 2). Routing the start
	# from this single `_load_room_at_index` site means room-cycle
	# (R1→R2→R1) hits the idempotence guard cleanly — no audible re-seed.
	# Wiring rationale: Uma's brief §"Trigger wiring" calls for the cue to
	# fire from any S1 room's _ready, but routing through Main lets the
	# idempotence guard see the whole room-cycle without each room script
	# having to know about audio.
	# W3-T7 Stage 6: the S2 boss room (index 9) is NOT an S1 room — skip the
	# S1 ambient bed. The S2 boss room crossfades to `mus-boss-stratum2.ogg`
	# from its own `entry_sequence_completed` handler (see
	# `Stratum2BossRoom._on_entry_sequence_completed_audio`); starting S1
	# ambient here would fight that crossfade.
	if index != BOSS_ROOM_INDEX and index != S2_BOSS_ROOM_INDEX:
		var ad: Node = _audio_director()
		if ad != null and ad.has_method("play_stratum1_ambient"):
			ad.play_stratum1_ambient()
	# Update HUD room counter.
	_refresh_room_label()
	room_changed.emit(room, index)


func _wire_room_signals(room: Node, index: int) -> void:
	# All multi-mob rooms (Room02..Room08) emit `room_cleared` from MultiMobRoom.
	# Room01 (Stratum1Room01) does NOT emit room_cleared — it has no RoomGate
	# in its .tscn. We fall back to listening on every spawned mob's mob_died
	# and counting down for both kinds of rooms; the gate-emitted path also
	# works because we always count from the live mob list.
	# Subscribe each spawned mob to Levels.gain_xp + MobLootSpawner.
	var mobs: Array[Node] = []
	if room.has_method("get_spawned_mobs"):
		mobs = room.get_spawned_mobs()
	for m: Node in mobs:
		_wire_mob(m)
	# Multi-mob rooms emit `room_cleared` once their RoomGate unlocks.
	if room.has_signal("room_cleared"):
		if not room.is_connected("room_cleared", _on_room_cleared):
			room.connect("room_cleared", _on_room_cleared)
	# Boss room: subscribe to entry-sequence + boss_died + stratum_exit_unlocked.
	#
	# **W3-T7 Stage 6 (ticket `86c9y7ygj`) — shared boss-room branch.** Both
	# Stratum1BossRoom (index 8) and Stratum2BossRoom (index 9) expose the
	# SAME signal surface (`get_boss()` returning a boss with `boss_died` +
	# `damaged` + `phase_changed`, `stratum_exit_unlocked`, `boss_defeated`).
	# The branch is therefore loosely-typed (`Node` + `has_signal` guards)
	# rather than `as Stratum1BossRoom` so the S2 boss room flows through the
	# identical wiring without a parallel branch. `_boss_room` keeps its
	# `Stratum1BossRoom` field type for the S1-specific `get_stratum_exit()`
	# read in `_on_stratum_exit_unlocked`; for the S2 room it's resolved via
	# the generic `_boss_room_node` Node handle (both expose `get_stratum_exit`).
	if index == BOSS_ROOM_INDEX or index == S2_BOSS_ROOM_INDEX:
		_boss_room_node = room
		# Keep the typed `_boss_room` pointer only for the S1 room (S1-specific
		# call sites that need the concrete type). For S2 it stays null and the
		# generic node handle is used.
		_boss_room = room as Stratum1BossRoom
		# Wire the boss too (same Levels.gain_xp + loot drop path). The boss is
		# spawned by the room's _spawn_boss on the room's _ready, which has
		# fired by the time we get here. Single-pipeline loot rule (ticket
		# `86c9uemdg`): Main's MobLootSpawner is the SOLE boss-loot pipeline —
		# the boss room does NOT spawn its own loot. `_wire_mob` subscribes to
		# the boss's `boss_died` so `ArchiveSentinel.boss_died` lands here.
		if room.has_method("get_boss"):
			var boss: Node = room.get_boss()
			if boss != null:
				_wire_mob(boss)
		if room.has_signal("stratum_exit_unlocked"):
			if not room.is_connected("stratum_exit_unlocked", _on_stratum_exit_unlocked):
				room.connect("stratum_exit_unlocked", _on_stratum_exit_unlocked)
		# M3-T4 — defeat title card. Lazy-instantiated per kill via the room's
		# `boss_defeated` signal. Card subscribes once here (idempotent via
		# `is_connected`); it `queue_free`s itself when the fade-out completes.
		# The card reads `display_name` via tolerant lookups, so it renders
		# the S2 boss name ("ARCHIVE SENTINEL") without an S2-specific path.
		if room.has_signal("boss_defeated"):
			if not room.is_connected("boss_defeated", _on_boss_defeated):
				room.connect("boss_defeated", _on_boss_defeated)
	else:
		# Room01 has no `room_cleared` signal. Wire a fallback: when the last
		# spawned mob dies, treat that as "cleared." This keeps the AC2 first-
		# room flow legible even with no gate.
		if not room.has_signal("room_cleared"):
			_install_room01_clear_listener(room, mobs)


# Shared mob wiring: XP gain + loot drop on death.
func _wire_mob(mob: Node) -> void:
	var levels: Node = _levels()
	if levels != null and levels.has_method("subscribe_to_mob"):
		levels.subscribe_to_mob(mob)
	# MobLootSpawner.on_mob_died subscribes the right way; we connect our
	# own handler that forwards to the spawner + immediately auto-collects
	# spawned pickups via Inventory.auto_collect_pickups.
	if mob.has_signal("mob_died"):
		if not mob.is_connected("mob_died", _on_mob_died):
			mob.connect("mob_died", _on_mob_died)
	# Boss uses `boss_died` instead of `mob_died`. Subscribe both — the
	# boss's `mob_died` doesn't exist; `boss_died` carries the same payload.
	if mob.has_signal("boss_died"):
		if not mob.is_connected("boss_died", _on_mob_died):
			mob.connect("boss_died", _on_mob_died)
	# Make sure the mob has a player target.
	if mob.has_method("set_player") and _player != null:
		mob.set_player(_player)


# Room01 has no RoomGate; we synthesize a "room_cleared" by observing every
# spawned mob's mob_died signal. After each death we ask the room to recount
# alive mobs (its get_spawned_mobs() returns the live mob array, which freed
# nodes drop out of). Idempotent — `_on_room_cleared` is itself one-shot
# because it advances `_current_room_index` and re-loads.
func _install_room01_clear_listener(_room: Node, mobs: Array[Node]) -> void:
	if mobs.is_empty():
		# Trivially clear — fire a deferred clear so the next-room load runs
		# after the current frame settles.
		call_deferred("_on_room_cleared")
		return
	for m: Node in mobs:
		if m.has_signal("mob_died") and not m.is_connected("mob_died", _on_room01_mob_died):
			m.connect("mob_died", _on_room01_mob_died)


# Room01 mob death handler — when the last live mob dies, fire the
# room_cleared synthetic signal. mob_died emits BEFORE the queue_free
# deferred call, so we count "still-alive non-dead mobs" on the current room.
#
# **Onboarding pickup gate (ticket 86c9qbb3k).** Room01's dummy drops an
# iron_sword Pickup on death. If the player is not yet equipped, the room
# advance MUST wait until the player collects that Pickup and auto-equips —
# otherwise `_on_room_cleared → _load_room_at_index` would `queue_free` Room01
# (taking the Pickup with it) on the very next frame, before the player could
# ever reach it. We arm `_room01_awaiting_pickup_equip` and connect to
# `Inventory.item_equipped`; the room advances from `_on_weapon_equipped` once
# the weapon slot is filled. If the player is ALREADY equipped (save-restored
# weapon, or a post-death respawn that preserved equipped state), the gate is
# skipped and the room advances immediately.
func _on_room01_mob_died(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if _current_room == null:
		return
	if not _current_room.has_method("get_spawned_mobs"):
		return
	var alive_count: int = 0
	for n: Node in _current_room.get_spawned_mobs():
		if is_instance_valid(n) and not _mob_is_dead(n):
			alive_count += 1
	if alive_count != 0:
		return
	# Room01's dummy is dead. Decide: gate on pickup-equip (normal first-run
	# path) or gate on pickup-add (post-death respawn with existing weapon).
	if _current_room_index == 0 and not _player_has_weapon_equipped():
		# Player is fistless — wait for the iron_sword Pickup to be collected
		# and auto-equipped before advancing. Arm the gate.
		_room01_awaiting_pickup_equip = true
		var inventory: Node = _inventory()
		if inventory != null and inventory.has_signal("item_equipped"):
			if not inventory.is_connected("item_equipped", _on_weapon_equipped):
				inventory.connect("item_equipped", _on_weapon_equipped)
		return
	# Player already equipped (save-restored weapon, or a post-death respawn
	# that preserved the iron_sword per the M1 death rule). The dummy still
	# drops a fresh iron_sword Pickup — arm the item_added gate so Room01 does
	# NOT free until the player collects it (or it is explicitly dismissed).
	# This fixes the P0 respawn race: the prior `call_deferred("_on_room_cleared")`
	# ran before the Pickup Add could fire, destroying the Pickup in the process
	# (ticket 86c9ujf0q).
	_room01_already_equipped_awaiting_add = true
	var inventory: Node = _inventory()
	if inventory != null and inventory.has_signal("item_added"):
		if not inventory.is_connected("item_added", _on_weapon_added_to_grid):
			inventory.connect("item_added", _on_weapon_added_to_grid)


# Returns true if the player currently has a weapon equipped (Inventory's
# weapon slot is occupied). Used by the Room01 onboarding pickup gate.
func _player_has_weapon_equipped() -> bool:
	var inventory: Node = _inventory()
	if inventory == null or not inventory.has_method("get_equipped"):
		return false
	return inventory.get_equipped(&"weapon") != null


# Inventory.item_equipped handler — armed only while the Room01 onboarding
# pickup gate is open. When the player walks onto the dummy-dropped iron_sword
# Pickup, `Inventory.on_pickup_collected` auto-equips it and fires
# `item_equipped`. That's our cue to finally advance Room01 → Room02. One-shot:
# we disconnect immediately so a later equip (Tab → LMB-click swap) doesn't
# re-trigger a room advance.
func _on_weapon_equipped(_item: Variant = null, slot: Variant = null) -> void:
	if not _room01_awaiting_pickup_equip:
		return
	if slot != null and StringName(slot) != &"weapon":
		# Some other slot (armor) was equipped — keep waiting for the weapon.
		return
	_clear_room01_pickup_gate()
	# Deferred so the equip's own signal listeners finish first, mirroring the
	# immediate-advance path above.
	call_deferred("_on_room_cleared")


# Inventory.item_added handler — armed only on the post-death-respawn path
# (player already equipped when dummy dies). When the player walks onto the
# dummy-dropped iron_sword Pickup, `Inventory.on_pickup_collected` calls
# `add()` which emits `item_added`. Since the weapon slot is already occupied,
# auto-equip is skipped and `item_equipped` never fires — so we gate here
# instead. Fires the room advance once any item is added (the only item that
# can be added in Room01 after the dummy dies is the dropped iron_sword). One-
# shot: disconnect immediately.
func _on_weapon_added_to_grid(_item: Variant = null) -> void:
	if not _room01_already_equipped_awaiting_add:
		return
	_clear_room01_pickup_gate()
	call_deferred("_on_room_cleared")


# Disarm the Room01 onboarding pickup gate: clear both flags and drop both
# Inventory signal connections. Idempotent — safe to call when the gate was
# never armed (either path).
func _clear_room01_pickup_gate() -> void:
	_room01_awaiting_pickup_equip = false
	_room01_already_equipped_awaiting_add = false
	var inventory: Node = _inventory()
	if inventory != null:
		if (
			inventory.has_signal("item_equipped")
			and inventory.is_connected("item_equipped", _on_weapon_equipped)
		):
			inventory.disconnect("item_equipped", _on_weapon_equipped)
		if (
			inventory.has_signal("item_added")
			and inventory.is_connected("item_added", _on_weapon_added_to_grid)
		):
			inventory.disconnect("item_added", _on_weapon_added_to_grid)


func _mob_is_dead(m: Node) -> bool:
	if m == null:
		return true
	if m.has_method("is_dead"):
		return bool(m.call("is_dead"))
	return false


# ---- HUD construction -----------------------------------------------


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.layer = 10  # below InventoryPanel (80) and DescendScreen (100)
	add_child(_hud)
	# Top-left vitals — HP bar + level label + XP bar (lightweight per Uma hud.md).
	var vitals: Control = Control.new()
	vitals.name = "TopLeftVitals"
	vitals.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vitals.offset_left = 16.0
	vitals.offset_top = 16.0
	vitals.offset_right = 320.0
	vitals.offset_bottom = 100.0
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(vitals)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.4156862745, 0.1647058824, 1.0))
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.position = Vector2(0, 0)
	_level_label.size = Vector2(120, 20)
	_level_label.text = "LV 1"
	vitals.add_child(_level_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(0, 24)
	_hp_bar.size = Vector2(220, 14)
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	vitals.add_child(_hp_bar)

	# HP bar regen shimmer overlay — a ColorRect drawn on top of the HP bar at
	# the exact same position/size. At rest its modulate is Color.WHITE (no
	# tinting). When regen is active, a looping SINE tween oscillates the
	# modulate between rest (Color.WHITE) and shimmer peak (warm amber per Uma's
	# spec §"Visual cue"). Using a separate ColorRect node:
	#   (a) avoids tweening the ProgressBar itself (whose fill stylebox is
	#       managed by the theme engine and not tween-friendly);
	#   (b) follows the combat-architecture.md "tween the visible-draw node
	#       directly" rule — NOT the parent vitals Control.
	# MOUSE_FILTER_IGNORE prevents the overlay from eating pointer events.
	_hp_bar_shimmer = ColorRect.new()
	_hp_bar_shimmer.name = "HpBarShimmer"
	_hp_bar_shimmer.position = Vector2(0, 24)
	_hp_bar_shimmer.size = Vector2(220, 14)
	# Start fully transparent so it is invisible at rest. The shimmer is driven
	# via modulate (not color.a) so it composes correctly with the ColorRect's
	# own color — Color.WHITE at alpha=0 means "draw nothing", not "draw white".
	_hp_bar_shimmer.color = Color(1.0, 0.85, 0.55, 0.35)  # warm amber, partial opacity
	_hp_bar_shimmer.modulate = Color(1.0, 1.0, 1.0, 0.0)  # fully transparent at rest
	_hp_bar_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(_hp_bar_shimmer)

	_hp_label = Label.new()
	_hp_label.name = "HpLabel"
	_hp_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 1.0))
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.position = Vector2(228, 22)
	_hp_label.size = Vector2(120, 16)
	_hp_label.text = "100 / 100"
	vitals.add_child(_hp_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(0, 44)
	_xp_bar.size = Vector2(220, 6)
	_xp_bar.min_value = 0
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	vitals.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.name = "XpLabel"
	_xp_label.add_theme_color_override(
		"font_color", Color(0.7215686275, 0.6745098039, 0.5568627451, 1.0)
	)
	_xp_label.add_theme_font_size_override("font_size", 11)
	_xp_label.position = Vector2(228, 42)
	_xp_label.size = Vector2(160, 14)
	_xp_label.text = "0 / 100"
	vitals.add_child(_xp_label)

	# Top-right run context — STRATUM 1 · ROOM x/8 (or BOSS).
	var ctx: Control = Control.new()
	ctx.name = "TopRightContext"
	ctx.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ctx.offset_left = -300.0
	ctx.offset_top = 16.0
	ctx.offset_right = -16.0
	ctx.offset_bottom = 36.0
	ctx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(ctx)
	_room_label = Label.new()
	_room_label.name = "RoomLabel"
	_room_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 1.0))
	_room_label.add_theme_font_size_override("font_size", 14)
	_room_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_room_label.text = "STRATUM 1 · ROOM 1/8"
	ctx.add_child(_room_label)

	# Bottom-left build SHA footer (Tess testability hook).
	_build_label = Label.new()
	_build_label.name = "BuildLabel"
	_build_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_build_label.offset_left = 16.0
	_build_label.offset_top = -28.0
	_build_label.offset_right = 320.0
	_build_label.offset_bottom = -8.0
	_build_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 0.85))
	_build_label.add_theme_font_size_override("font_size", 10)
	_build_label.text = "build: dev-local"
	if BuildInfo != null:
		_build_label.text = BuildInfo.display_label
	_hud.add_child(_build_label)

	# Bottom-right [+1 STAT] pip — shows when PlayerStats has unspent points.
	_stat_pip_label = Label.new()
	_stat_pip_label.name = "StatPip"
	_stat_pip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_stat_pip_label.offset_left = -160.0
	_stat_pip_label.offset_top = -52.0
	_stat_pip_label.offset_right = -16.0
	_stat_pip_label.offset_bottom = -32.0
	_stat_pip_label.add_theme_color_override(
		"font_color", Color(1.0, 0.4156862745, 0.1647058824, 1.0)
	)
	_stat_pip_label.add_theme_font_size_override("font_size", 14)
	_stat_pip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stat_pip_label.text = ""
	_stat_pip_label.visible = false
	_hud.add_child(_stat_pip_label)

	# Bottom-center boot banner — the only on-screen control reference in M1
	# (no in-game tutorial). Lists every input action from `project.godot`
	# §[input] so a first-time player has all 7 verbs visible. Per Uma
	# `player-journey.md` PJ-09: white text at 60% opacity, no panel
	# background, bottom-centered. Single Label with newline-separated lines
	# keeps font + alignment consistent with the other HUD widgets and
	# preserves spacing if any single line is later edited.
	#
	# BB-5 (`86c9m3969`): pre-fix banner mentioned only WASD / Shift / Space —
	# missing LMB (light attack) + RMB (heavy attack) made attacks invisible
	# to first-time players. Fully spelling out the 7 controls closes the
	# onboarding gap surfaced in Tess run-024 bug-bash.
	var banner_lines: Array[String] = [
		"WASD to move",
		"Shift to sprint",
		"Space to dodge",
		"LMB to attack",
		"RMB to heavy attack",
		"Tab for inventory",
		"P to allocate stats",
	]
	_boot_banner_label = Label.new()
	_boot_banner_label.name = "BootBanner"
	_boot_banner_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boot_banner_label.offset_left = 0.0
	_boot_banner_label.offset_top = -150.0
	_boot_banner_label.offset_right = 0.0
	_boot_banner_label.offset_bottom = -32.0
	_boot_banner_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 0.6))
	_boot_banner_label.add_theme_font_size_override("font_size", 12)
	_boot_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_boot_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_banner_label.text = "\n".join(banner_lines)
	_hud.add_child(_boot_banner_label)

	# Save-confirmation toast (Ticket 2 — `86c9q7p38`). Bottom-right widget
	# that connects to `Save.save_completed` on its own `_ready`. Per Uma's
	# design, it sits at offset (-260, -64) from BOTTOM_RIGHT — clear of the
	# build-SHA footer (bottom-left) and the [+1 STAT] pip (offset_left=-160
	# bottom-right). The bottom-center BootBanner stops 32 px from the bottom
	# edge so there is no collision with the toast plate at -64 either.
	_save_toast = SaveToast.new()
	_save_toast.name = "SaveToast"
	_hud.add_child(_save_toast)

	# Tutorial-prompt overlay (ticket `86c9qajcf` — Drew Stage 2b prereq
	# scaffold). Mounted on the HUD CanvasLayer (layer 10) so it sits above
	# the world but below InventoryPanel (80) and DescendScreen (100).
	# Connects to `TutorialEventBus.tutorial_beat_requested` from its own
	# `_ready`. Drew's Stage 2b PR drives content from Room01.
	_tutorial_overlay = TutorialPromptOverlay.new()
	_tutorial_overlay.name = "TutorialPromptOverlay"
	_hud.add_child(_tutorial_overlay)


func _build_inventory_panel() -> void:
	var packed: PackedScene = load(INVENTORY_PANEL_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] inventory panel scene missing at %s" % INVENTORY_PANEL_SCENE_PATH)
		return
	_inventory_panel = packed.instantiate() as CanvasLayer
	if _inventory_panel == null:
		push_warning("[Main] InventoryPanel did not instantiate as CanvasLayer")
		return
	_inventory_panel.name = "InventoryPanel"
	add_child(_inventory_panel)


## W2-T2 `86c9y0zyv` — mount the DialoguePanel into Main alongside
## InventoryPanel. The panel self-subscribes to DialogueController signals
## from its own `_ready` and hides until `branch_opened` fires; no
## further wiring needed at this scene root. PANEL_LAYER = 90 sits above
## InventoryPanel (80) so single-session guard violations (controller-side
## bug — should never fire) render predictably rather than as the
## bottom-edge ribbon stacked behind the inventory grid.
##
## Per `.claude/docs/dialogue-system.md` + `.claude/docs/html5-export.md` §
## "Visual-verification escape clause": the panel's visible elements are
## Label / Button / ColorRect / RichTextLabel — escape-clause-eligible
## under HTML5 visual-verification gate when paired with an honest-disclose
## probe list in the Self-Test Report.
func _build_dialogue_panel() -> void:
	var packed: PackedScene = load(DIALOGUE_PANEL_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] dialogue panel scene missing at %s" % DIALOGUE_PANEL_SCENE_PATH)
		return
	_dialogue_panel = packed.instantiate() as CanvasLayer
	if _dialogue_panel == null:
		push_warning("[Main] DialoguePanel did not instantiate as CanvasLayer")
		return
	_dialogue_panel.name = "DialoguePanel"
	add_child(_dialogue_panel)


## M3-T2-W2-T12 — global vignette CanvasLayer. Renders above world (layer 0)
## and below every UI layer (HUD=10, defeat-card=50, InventoryPanel=80,
## DescendScreen=100). Default boots at S1 baseline opacity 30% per Uma
## vignette-spec.md. Wave-3 consumers (T13 boss-entry deepen, T16 boss-defeat
## cinematic) reach the API via `get_vignette()` or `Main._vignette`.
func _build_vignette() -> void:
	var packed: PackedScene = load(VIGNETTE_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] Vignette scene missing at %s" % VIGNETTE_SCENE_PATH)
		return
	_vignette = packed.instantiate() as Vignette
	if _vignette == null:
		push_warning("[Main] Vignette did not instantiate as Vignette CanvasLayer")
		return
	_vignette.name = "Vignette"
	add_child(_vignette)


func _build_stat_panel() -> void:
	var packed: PackedScene = load(STAT_PANEL_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] stat allocation panel scene missing at %s" % STAT_PANEL_SCENE_PATH)
		return
	_stat_panel = packed.instantiate() as CanvasLayer
	if _stat_panel == null:
		push_warning("[Main] StatAllocationPanel did not instantiate as CanvasLayer")
		return
	_stat_panel.name = "StatAllocationPanel"
	add_child(_stat_panel)


# ---- Subscriptions: autoloads -------------------------------------


func _subscribe_to_levels() -> void:
	var levels: Node = _levels()
	if levels == null:
		return
	if levels.has_signal("xp_gained") and not levels.is_connected("xp_gained", _on_xp_gained):
		levels.connect("xp_gained", _on_xp_gained)
	if levels.has_signal("level_up") and not levels.is_connected("level_up", _on_level_up):
		levels.connect("level_up", _on_level_up)


func _subscribe_to_inventory() -> void:
	# Nothing to do — auto_collect_pickups wires per-pickup as they spawn.
	pass


func _subscribe_to_player_stats() -> void:
	var ps: Node = _player_stats()
	if ps == null:
		return
	if (
		ps.has_signal("unspent_points_changed")
		and not ps.is_connected("unspent_points_changed", _on_unspent_points_changed)
	):
		ps.connect("unspent_points_changed", _on_unspent_points_changed)


# ---- Save load / persist ------------------------------------------


func _load_save_or_defaults() -> void:
	var save_node: Node = _save()
	if save_node == null:
		return
	var data: Dictionary = save_node.load_game(SAVE_SLOT)
	if data.is_empty():
		# Fresh start — leave autoloads at default (already reset on autoload _ready).
		# Player HP defaults to 100/100 from Player.DEFAULT_HP_MAX.
		return
	# Restore Levels (level + xp).
	var character: Variant = data.get("character", {})
	if character is Dictionary:
		var ch: Dictionary = character
		var levels: Node = _levels()
		if levels != null:
			levels.set_state(int(ch.get("level", 1)), int(ch.get("xp", 0)))
		var ps: Node = _player_stats()
		if ps != null:
			ps.restore_from_character(ch)
		# Restore HP onto the player (set_hp clamps + emits hp_changed).
		if _player != null:
			# hp_max is bumped by future Vigor scaling (M2); for M1 we use the
			# saved value when present, falling back to DEFAULT_HP_MAX.
			var hp_max_saved: int = int(ch.get("hp_max", Player.DEFAULT_HP_MAX))
			var hp_cur_saved: int = int(ch.get("hp_current", hp_max_saved))
			_player.hp_max = max(1, hp_max_saved)
			_player.set_hp(hp_cur_saved)
	# Restore Inventory using real resolvers from the ContentRegistry. Per
	# BB-2 (`86c9m3911`) the previous no-op resolvers dropped every saved
	# item silently. The registry was scanned in `_ready` before this runs.
	var inventory: Node = _inventory()
	if inventory != null:
		(
			inventory
			. restore_from_save(
				data,
				get_item_resolver(),
				get_affix_resolver(),
			)
		)
	# Restore stratum progression.
	var sp: Node = _stratum_progression()
	if sp != null:
		sp.restore_from_save_data(data)
	# W2-T5: restore Player quest + world-map state via Player.restore_from_save_dict.
	# Pre-W2-T5 this round-trip wasn't wired into Main even though
	# Player.to_save_dict / restore_from_save_dict existed (PR #352 shipped the
	# methods + the Save.gd backfill but skipped the Main wiring — the
	# field-level round-trip GUT test in test_save_migrate_quest_fields_backfill
	# covers the methods in isolation; this Main wiring is the integration
	# surface). Reads from `data.character` for v5 saves (pre-multi-character
	# lift); `data.characters[active_slot]` for post-lift saves — branch
	# defensively via `has()`-guard.
	if _player != null and _player.has_method("restore_from_save_dict"):
		if character is Dictionary:
			_player.restore_from_save_dict(character)


func _persist_to_save(slot: int = SAVE_SLOT) -> bool:
	var save_node: Node = _save()
	if save_node == null:
		return false
	var data: Dictionary = save_node.default_payload()
	# Layer in the autoload snapshots — same shape as test_ac6_quit_relaunch.gd.
	var character: Dictionary = data["character"]
	var levels: Node = _levels()
	if levels != null and levels.has_method("snapshot_to_character"):
		levels.snapshot_to_character(character)
	var ps: Node = _player_stats()
	if ps != null and ps.has_method("snapshot_to_character"):
		ps.snapshot_to_character(character)
	# HP snapshot.
	if _player != null:
		character["hp_current"] = _player.hp_current
		character["hp_max"] = _player.hp_max
	# W2-T5: Player quest + world-map fields. Merge Player.to_save_dict()
	# keys into the character dict — additive (does not overwrite
	# levels/stats/HP). Pre-W2-T5 this wasn't wired (see _load_save_or_defaults
	# comment); the gap meant `active_bounty` / `completed_bounties` /
	# `discovered_zones` / `discovered_waypoints` all relied on the Save.gd
	# default-payload defaults instead of round-tripping in-memory state.
	if _player != null and _player.has_method("to_save_dict"):
		var player_save: Dictionary = _player.to_save_dict()
		for k in player_save.keys():
			character[k] = player_save[k]
	var inventory: Node = _inventory()
	if inventory != null and inventory.has_method("snapshot_to_save"):
		inventory.snapshot_to_save(data)
	var sp: Node = _stratum_progression()
	if sp != null and sp.has_method("snapshot_to_save_data"):
		sp.snapshot_to_save_data(data)
	return save_node.save_game(slot, data)


func _save_on_quit() -> void:
	if _saved_on_quit:
		return
	_saved_on_quit = true
	_persist_to_save()


# ---- Signal handlers --------------------------------------------


func _on_mob_died(mob: Node, death_position: Vector2, mob_def: Resource) -> void:
	# Diagnostic trace (ticket 86c9un4nh — Finding 2 re-diagnosis). Emit at
	# the entry point so the trace stream shows WHICH mob died and whether
	# mob_def is null (the two early-exit conditions for the loot pipeline).
	# Two on_mob_died lines for the same mob in the same frame = dual-spawner
	# regression. Zero lines for a boss kill = signal not wired in _wire_mob.
	var df: Node = get_tree().root.get_node_or_null("DebugFlags") if is_inside_tree() else null
	if df != null and df.has_method("combat_trace"):
		var mob_id: String = "<null>"
		if mob_def != null and mob_def.has_method("get") and mob_def.get("id") != null:
			mob_id = String(mob_def.get("id"))
		df.combat_trace(
			"Main._on_mob_died",
			(
				"mob=%s mob_def=%s mob_id=%s pos=(%.0f,%.0f)"
				% [str(mob), str(mob_def != null), mob_id, death_position.x, death_position.y]
			)
		)
	# Forward to the loot spawner so a pickup spawns at the death position.
	if _loot_spawner != null and mob_def != null:
		var pickups: Array[Node] = _loot_spawner.on_mob_died(mob, death_position, mob_def as MobDef)
		var inventory: Node = _inventory()
		if inventory != null and inventory.has_method("auto_collect_pickups"):
			inventory.auto_collect_pickups(pickups)
			if df != null and df.has_method("combat_trace"):
				(
					df
					. combat_trace(
						"Main._on_mob_died",
						(
							"auto_collect_pickups wired for %d pickups — picked_up→on_pickup_collected connected"
							% pickups.size()
						)
					)
				)
	# Levels.subscribe_to_mob already grants XP via its own one-shot
	# connection, so we don't double-call here.


func _on_room_cleared(_room_id: Variant = null) -> void:
	# Mark cleared if the chunk_def carries an id (Room02..08 do; Room01 has
	# its own Stratum1Room01 script that lacks the gate->StratumProgression
	# wiring, so we mark from here too).
	var sp: Node = _stratum_progression()
	if sp != null and _current_room_index >= 0 and _current_room_index < ROOM_IDS.size():
		var rid: StringName = ROOM_IDS[_current_room_index]
		sp.mark_cleared(rid)
	# Persist progress on each clear so a quit-mid-run preserves the high-water mark.
	_persist_to_save()
	# Advance to the next room (boss room is the terminal — we don't auto-
	# advance past it; the StratumExit drives that transition).
	if _current_room_index < BOSS_ROOM_INDEX:
		var next_index: int = _current_room_index + 1
		_load_room_at_index(next_index)


## M3-T4 — defeat title card. Per Uma's brief (`team/uma-ux/m3-t4-defeat-title-card-brief.md`),
## the card is a transient overlay instantiated per kill. Lazy-load the
## PackedScene + add as Main's child + call `show_for(boss, pos)`. The
## card runs its own tween (1.2 s pre-delay + 0.4 s fade-in + 0.8 s hold
## + 0.4 s fade-out, all on game time) and `queue_free`s itself on
## completion. Main does NOT track the instance — re-entry on a future
## New Game + run simply instantiates a fresh node.
##
## **Signal payload** matches `Stratum1BossRoom.boss_defeated(boss: Stratum1Boss,
## death_position: Vector2)` AND `Stratum2BossRoom.boss_defeated(boss:
## ArchiveSentinel, death_position: Vector2)` (W3-T7 Stage 6). The `boss`
## param is loosely typed `Node` so BOTH boss types connect cleanly — a
## typed `Stratum1Boss` param would refuse the ArchiveSentinel payload at
## connect time. The card only needs `boss` for the `display_name`
## templating (read via tolerant lookups), so the loose type is safe;
## `death_position` is forwarded for future anchored-card variants.
func _on_boss_defeated(boss: Node, death_position: Vector2) -> void:
	var packed: PackedScene = load(BOSS_DEFEATED_TITLE_CARD_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning(
			(
				"[Main] BossDefeatedTitleCard scene missing at '%s'"
				% BOSS_DEFEATED_TITLE_CARD_SCENE_PATH
			)
		)
		return
	var card: BossDefeatedTitleCard = packed.instantiate() as BossDefeatedTitleCard
	if card == null:
		return
	add_child(card)
	# M3-T2-W2-T10 — wire F4 ambient resume to the card-dismissed signal so
	# the bed comes back at 60% AFTER the silence-as-punctuation hold (per
	# `.claude/docs/audio-architecture.md` § "Tonal pattern — silence as
	# punctuation" + Uma's s1-ambient.md §"F4"). Subscribed BEFORE
	# `show_for` so the tween chain inside the card can fire `dismissed`
	# without the resume missing it. If the AudioDirector autoload is
	# absent (test surface), the connect is skipped silently.
	var ad: Node = _audio_director()
	if ad != null and ad.has_method("resume_stratum1_ambient_at_60_percent"):
		# Wrap in lambda so the default-arg form is called (Callable.connect
		# strict-arg-counts means the raw Callable would expect zero args; a
		# zero-arg lambda forwards into the default-fade method cleanly).
		card.title_card_dismissed.connect(
			func() -> void: ad.resume_stratum1_ambient_at_60_percent()
		)
	# T16 F3 ramp-out (`86c9wjzgh`, M3 Tier 2 Wave 3). The F2 camera zoom +
	# vignette deepen were fired from `Stratum1BossRoom._on_boss_died` over
	# the same 0.9 s window as the sustained ember emitter; the card then
	# pre-fade-delays for 1.2 s and runs its 0.4 s fade-in + 0.8 s hold + 0.4
	# s fade-out. On `title_card_dismissed` (after the fade-out completes
	# and the card is about to queue_free), F3 returns the camera to player-
	# follow over 0.4 s and the vignette to S1 default 30% over 0.4 s.
	#
	# Two separate connections so a future ticket can detach one without
	# disturbing the other (e.g. if a "post-card cinematic" beat lands
	# between F3 vignette and F3 camera). Same shape as the audio-resume
	# wiring above — soft no-ops when the autoload / Vignette is absent.
	# On card-dismiss, restore the boss room's RESTING camera, NOT the game-wide
	# player-default. The boss room owns what "resting" means: the S1 boss room's
	# resting zoom IS the CameraDirector default (so `restore_resting_camera()`
	# is byte-equivalent to the legacy `reset_to_player()` follow-restore), but
	# the S2 arena holds a standing 0.5 zoom-out that must SURVIVE the boss death
	# (Sponsor re-soak #4 — boss death over-zoomed the arena). Prefer the room's
	# own re-assert hook; fall back to `reset_to_player()` only when the active
	# boss room doesn't expose it (defensive — every production boss room does).
	# See `Stratum2BossRoom.restore_resting_camera` for the bug this guards.
	var cam: Node = _camera_director()
	if _boss_room_node != null and _boss_room_node.has_method("restore_resting_camera"):
		var room: Node = _boss_room_node
		card.title_card_dismissed.connect(func() -> void: room.restore_resting_camera())
	elif cam != null and cam.has_method("reset_to_player"):
		card.title_card_dismissed.connect(func() -> void: cam.reset_to_player())
	if _vignette != null and _vignette.has_method("boss_defeat_return"):
		card.title_card_dismissed.connect(func() -> void: _vignette.boss_defeat_return())
	card.show_for(boss, death_position)


func _on_stratum_exit_unlocked() -> void:
	# Boss is dead — drop loot already happened via _on_mob_died (the boss's
	# `boss_died` was wired in _wire_mob). Mark boss room cleared.
	#
	# W3-T7 Stage 6: use the generic `_boss_room_node` handle so both the S1
	# boss room (index 8) and S2 boss room (index 9) resolve their StratumExit
	# + mark the right ROOM_IDS entry. `_current_room_index` distinguishes the
	# two so the cleared-mark targets the correct room id.
	var sp: Node = _stratum_progression()
	if sp != null and _current_room_index >= 0 and _current_room_index < ROOM_IDS.size():
		sp.mark_cleared(ROOM_IDS[_current_room_index])
	_persist_to_save()
	# Wire the StratumExit's descend signal so we open the descend screen
	# when the player walks to the portal + presses E. Both boss rooms expose
	# `get_stratum_exit()`; resolve via the generic node handle.
	if _boss_room_node == null or not _boss_room_node.has_method("get_stratum_exit"):
		return
	var exit: StratumExit = _boss_room_node.get_stratum_exit()
	if exit == null:
		return
	if not exit.descend_triggered.is_connected(_on_descend_triggered):
		exit.descend_triggered.connect(_on_descend_triggered)


func _on_descend_triggered() -> void:
	# Show the descend screen overlay. Hook its restart_run -> reload Room01
	# preserving level + equipped (the descend rule keeps everything per
	# DescendScreen.gd's docstring).
	if _descend_screen != null and is_instance_valid(_descend_screen):
		_descend_screen.queue_free()
	var packed: PackedScene = load(DESCEND_SCREEN_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[Main] descend screen scene missing")
		return
	_descend_screen = packed.instantiate() as CanvasLayer
	if _descend_screen == null:
		return
	add_child(_descend_screen)
	if _descend_screen.has_signal("restart_run"):
		_descend_screen.connect("restart_run", _on_descend_restart_run)
	stratum_descended.emit()


func _on_descend_restart_run() -> void:
	# Descend from the S1 boss into Stratum 2 (ticket `86ca1m0ph`, Option A —
	# procgen-driven traversal). Replaces the M1 Room01-reload placeholder with
	# a real S2 floor transition driven by `FloorAssembler.assemble_floor(...)`.
	# Per the descend rule (DECISIONS.md 2026-05-02): the player keeps EVERYTHING
	# (level + equipped + inventory) — only room-clear progression bookkeeping
	# resets.
	if _descend_screen != null and is_instance_valid(_descend_screen):
		_descend_screen.queue_free()
		_descend_screen = null
	var sp: Node = _stratum_progression()
	if sp != null:
		sp.preserve_for_descend()
		# preserve_for_descend is a no-op in M1; we still reset room-clear
		# bookkeeping so the rooms are re-clearable. "Everything carries forward
		# EXCEPT room-clear bookkeeping."
		sp.reset()
	if _player != null:
		_player.revive_full_hp()
	_begin_stratum_2()
	_persist_to_save()


## Entry point into Stratum 2 (ticket `86ca1m0ph`). Fires the S1→S2 audio
## entry trigger (BGM + Ambient) then assembles + loads the first S2 zone.
##
## **HTML5 audio gate:** this runs from the DescendScreen "Return to Stratum 1"
## button click — a user gesture — so the AudioContext is unlocked here
## (AudioDirector.gd § HTML5 audio-playback gate). The BGM/Ambient is audible
## from the moment the player descends.
func _begin_stratum_2() -> void:
	# S1→S2 audio entry trigger. `play_stratum2_entry()` fires BGM + Ambient in
	# one call (the canonical entry-point per AudioDirector docs). This is the
	# real S1→S2 entry trigger the prior deferral comment promised — it now
	# fires at the START of the genuine S2 transition, not on a Room01 reload.
	var audio_director: Node = _audio_director()
	if audio_director != null and audio_director.has_method("play_stratum2_entry"):
		audio_director.play_stratum2_entry()
	_s2_world_seed = _resolve_s2_world_seed()
	_load_s2_zone(0)


## Resolve the per-character world seed the S2 zone seeds derive from.
##
## **As of this PR there is NO `world_seed` surface in the codebase** — the
## per-character seed (`Character.world_seed` round-tripping through Save.gd,
## per procgen-pipeline.md § "Save-schema binding") is unimplemented; a grep
## for `world_seed` across `scripts/`+`scenes/` returns zero matches at HEAD.
## Until that lands (Commitment 5 — randomized maps per character), this
## returns a fixed deterministic seed so S2 layouts are stable across runs.
## Forward-compat: when `Save.get_world_seed()` (or equivalent) ships, swap the
## constant return for that read — every other seam here already keys off
## `_s2_world_seed`, so it is a single-line change.
func _resolve_s2_world_seed() -> int:
	var save: Node = _save()
	if save != null and save.has_method("get_world_seed"):
		return int(save.get_world_seed())
	return 0


## Assemble S2 zone `zone_idx` (index into `S2_ZONE_IDS`) via FloorAssembler
## and render it into the world. When `zone_idx` is past the last authored S2
## zone, hand off to the authored boss room (the z4 terminal).
func _load_s2_zone(zone_idx: int) -> void:
	if zone_idx < 0 or zone_idx >= S2_ZONE_IDS.size():
		_enter_s2_boss_room()
		return
	var zone_id: StringName = S2_ZONE_IDS[zone_idx]
	var zone_path: String = S2_ZONE_DEF_PATH_FMT % String(zone_id)
	var zone_def: ZoneDef = load(zone_path) as ZoneDef
	if zone_def == null:
		WarningBus.warn("[Main] S2 zone def failed to load: %s" % zone_path, &"level")
		_enter_s2_boss_room()
		return
	_s2_zone_index = zone_idx
	var stratum_seed: int = FloorAssembler.derive_stratum_seed(_s2_world_seed, S2_STRATUM_ID)
	var zone_seed: int = FloorAssembler.derive_zone_seed(stratum_seed, zone_def.zone_id)
	var assembler: FloorAssembler = FloorAssembler.new()
	var assembled: AssembledFloor = assembler.assemble_floor(zone_def, zone_seed)
	_record_discovered_zone(zone_def.zone_id)
	_render_assembled_floor(assembled)
	_combat_trace_main(
		"Main.load_s2_zone",
		(
			"zone_id=%s seed=%d chunks=%d mobs=%d bounds=%s"
			% [
				String(zone_def.zone_id),
				zone_seed,
				assembled.chunk_count(),
				_s2_mobs_remaining,
				str(assembled.bounding_box_px),
			]
		)
	)
	_persist_to_save()


## Instantiate every placed chunk into a fresh container under `_world`,
## re-parent the player to the floor origin, and engage the continuous-scroll
## camera against the assembled floor bounds. Then arm zone progression.
##
## S2 chunks render their authored geometry (`scene_path` is populated) AND
## spawn the mobs declared in each placed chunk's `mob_spawns` (ticket
## `86ca3amgt`). Spawned mobs are CharacterBody2D nodes parented under the
## floor container — they hook into the standard combat/death pipeline (their
## own melee Hitbox / Projectile uses the encapsulated `_init` deferred-
## monitoring pattern, so the spawn is physics-flush-safe regardless of this
## call's context; see combat-architecture.md § Hitbox encapsulated-monitoring).
## This call path is NOT inside a physics flush (it is reached from the
## DescendScreen `restart_run` button click → `_begin_stratum_2`, or from the
## `call_deferred`-driven `_advance_s2_zone`), so the synchronous child-add of
## CharacterBody2D mobs is safe — same justification as `Stratum1BossRoom`'s
## synchronous `_spawn_boss`.
func _render_assembled_floor(assembled: AssembledFloor) -> void:
	_teardown_active_room_for_s2()
	_teardown_s2_floor()
	_s2_floor_container = Node2D.new()
	_s2_floor_container.name = "S2FloorContainer"
	if _world != null:
		_world.add_child(_s2_floor_container)
	else:
		add_child(_s2_floor_container)
	var live_chunks: Array[Node] = _instantiate_chunks(assembled)
	_s2_chunks_remaining = live_chunks.size()
	_s2_mobs = _spawn_assembled_floor_mobs(assembled)
	_s2_mobs_remaining = _s2_mobs.size()
	_reparent_player_into(_s2_floor_container, _s2_floor_spawn(assembled))
	_engage_camera_for_assembled_floor(assembled)
	# Forward-compatible zone-progression seam. Today the chunks expose no
	# clear trigger, so the zone auto-advances on the next frame. Mobs now
	# EXIST + are tracked in `_s2_mobs_remaining`, but the chunk-clear GATE
	# that would hold the advance until `_s2_mobs_remaining == 0` is the
	# SEPARATE sibling ticket (`86ca3amyb`) — do NOT gate the advance here.
	_on_s2_zone_advance_ready()


## Returns the live chunk nodes instantiated from the assembled floor. Skips
## chunks whose `scene_path` is empty (defensive — S2 chunks have geometry, but
## a future zone could reference a geometry-less chunk) and chunks whose scene
## fails to load (warned via WarningBus).
func _instantiate_chunks(assembled: AssembledFloor) -> Array[Node]:
	var live: Array[Node] = []
	for placed: PlacedChunk in assembled.placed_chunks:
		var chunk_def: LevelChunkDef = _resolve_chunk_def(placed.chunk_id)
		if chunk_def == null or chunk_def.scene_path.is_empty():
			continue
		var packed: PackedScene = load(chunk_def.scene_path) as PackedScene
		if packed == null:
			WarningBus.warn(
				"[Main] S2 chunk scene failed to load: %s" % chunk_def.scene_path, &"level"
			)
			continue
		var inst: Node = packed.instantiate()
		if inst is Node2D:
			(inst as Node2D).position = placed.position_px
		_s2_floor_container.add_child(inst)
		live.append(inst)
	return live


## Spawn the mobs declared in every placed chunk's `mob_spawns` (ticket
## `86ca3amgt`). For each placed chunk we resolve its `LevelChunkDef`, then for
## each `MobSpawnPoint` resolve `mob_id` via the `MobRegistry` autoload and
## instantiate the registered scene at the spawn's authored tile position,
## converted to world pixels and offset by the chunk's placement
## (`placed.position_px + position_tiles × chunk_def.tile_size_px`).
##
## mob_id resolution goes through MobRegistry; an UNKNOWN mob_id is handled
## explicitly — WarningBus.warn + skip (no silent crash) so the universal
## warning gate catches a content regression. Returns the live mob nodes for
## the caller to track (`_s2_mobs_remaining`) — the chunk-clear zone-advance
## gate (sibling ticket `86ca3amyb`) consumes that count later.
func _spawn_assembled_floor_mobs(assembled: AssembledFloor) -> Array[Node]:
	var live: Array[Node] = []
	var registry: Node = _mob_registry()
	if registry == null:
		WarningBus.warn("[Main] S2 mob spawn: MobRegistry autoload unavailable", &"level")
		return live
	for placed: PlacedChunk in assembled.placed_chunks:
		var chunk_def: LevelChunkDef = _resolve_chunk_def(placed.chunk_id)
		if chunk_def == null:
			continue
		for spawn: MobSpawnPoint in chunk_def.mob_spawns:
			var mob: Node = _spawn_one_chunk_mob(registry, chunk_def, placed, spawn)
			if mob != null:
				live.append(mob)
	return live


## Resolve + instantiate a single `MobSpawnPoint`. Returns the live mob node, or
## null (warned + skipped) on an unknown / unloadable mob_id. Mirrors
## `MobRegistry.spawn`'s scene-instantiate + mob_def-apply shape but parents
## under the S2 floor container and positions from the chunk-relative tile
## offset.
func _spawn_one_chunk_mob(
	registry: Node, chunk_def: LevelChunkDef, placed: PlacedChunk, spawn: MobSpawnPoint
) -> Node:
	if not registry.has_mob(spawn.mob_id):
		WarningBus.warn(
			(
				"[Main] S2 mob spawn: unknown mob_id '%s' in chunk '%s' -- skipped"
				% [String(spawn.mob_id), String(chunk_def.id)]
			),
			&"level"
		)
		return null
	var scene: PackedScene = registry.get_mob_scene(spawn.mob_id)
	if scene == null:
		# get_mob_scene already routes its own load-failure warning through
		# WarningBus (MobRegistry._emit_warning); just skip here.
		return null
	var node: Node = scene.instantiate()
	var def: MobDef = registry.get_mob_def(spawn.mob_id)
	# Apply the MobDef so the kill → mob_died → XP/loot pipelines see a
	# non-null payload (otherwise both pipelines silently no-op). Matches the
	# MultiMobRoom / MobRegistry.spawn contract exactly.
	if def != null and "mob_def" in node:
		node.mob_def = def
	if node is Node2D:
		var local_px := Vector2(spawn.position_tiles * chunk_def.tile_size_px)
		(node as Node2D).position = placed.position_px + local_px
	_s2_floor_container.add_child(node)
	return node


## Resolve the MobRegistry autoload (null if unavailable — degenerate test/boot
## context). Mirrors `MultiMobRoom._get_mob_registry`.
func _mob_registry() -> Node:
	return get_tree().root.get_node_or_null("MobRegistry")


## Resolve a `LevelChunkDef` by id from the canonical chunk root. Returns null
## (warned) on a miss.
func _resolve_chunk_def(chunk_id: StringName) -> LevelChunkDef:
	var path: String = "res://resources/level_chunks/%s.tres" % String(chunk_id)
	var res: Resource = load(path)
	if res is LevelChunkDef:
		return res as LevelChunkDef
	return null


## Player spawn for an assembled S2 floor — left edge of the floor, vertically
## centred in the bounds. Falls back to DEFAULT_PLAYER_SPAWN for a degenerate
## (zero-size) bounding box.
func _s2_floor_spawn(assembled: AssembledFloor) -> Vector2:
	var bounds: Rect2 = assembled.bounding_box_px
	if bounds.size == Vector2.ZERO:
		return DEFAULT_PLAYER_SPAWN
	return Vector2(bounds.position.x + 24.0, bounds.position.y + bounds.size.y * 0.5)


## Engage continuous-scroll follow + world-bounds clamp against the assembled
## floor (camera-scroll.md § "Forward-compat — AssembledFloor.bounding_box_px
## swap"). This is the production consumer the W2-T1 camera wiring anticipated.
func _engage_camera_for_assembled_floor(assembled: AssembledFloor) -> void:
	if _player == null:
		return
	var cd: Node = _camera_director()
	if cd == null:
		return
	if cd.has_method("follow_target"):
		cd.follow_target(_player, CAMERA_FOLLOW_DEADZONE)
	if cd.has_method("set_world_bounds"):
		var bounds: Rect2 = assembled.bounding_box_px
		if bounds.size == Vector2.ZERO:
			bounds = S2_ROOM_BOUNDS
		cd.set_world_bounds(bounds)


## Zone-progression advance hook. Forward-compatible seam: today (data-only
## chunks, no clear trigger) it advances to the next zone deferred so the
## current frame settles first. When chunk-clear content lands, gate this on
## `_s2_chunks_remaining == 0`.
func _on_s2_zone_advance_ready() -> void:
	call_deferred("_advance_s2_zone")


func _advance_s2_zone() -> void:
	if _s2_zone_index < 0:
		# Already left the S2 procgen floor (e.g. boss-room handoff fired).
		return
	_load_s2_zone(_s2_zone_index + 1)


## Terminal of the S2 floor: hand off to the authored Stratum2BossRoom scene
## (`ROOM_SCENE_PATHS[S2_BOSS_ROOM_INDEX]`) — the z4 (`s2_z4_inner_sanctum`)
## terminal with real authored content (ArchiveSentinel boss + arena + exit).
func _enter_s2_boss_room() -> void:
	_teardown_s2_floor()
	_s2_zone_index = -1
	_load_room_at_index(S2_BOSS_ROOM_INDEX)


func _teardown_s2_floor() -> void:
	if _s2_floor_container == null:
		return
	if is_instance_valid(_s2_floor_container):
		_s2_floor_container.queue_free()
	_s2_floor_container = null
	_s2_chunks_remaining = 0
	_s2_mobs_remaining = 0
	_s2_mobs = []


## Re-parent the player under `parent` at `spawn` (world pos). Mirrors the
## re-parent block in `_load_room_at_index`. The player is preserved across the
## S1→S2 transition (descend rule keeps the character intact).
func _reparent_player_into(parent: Node, spawn: Vector2) -> void:
	if _player == null or parent == null:
		return
	if _player.get_parent() != parent:
		if _player.get_parent() != null:
			_player.get_parent().remove_child(_player)
		parent.add_child(_player)
	_player.global_position = spawn


## Record a discovered S2 zone on the Player so the world-map discovery surface
## + save round-trip see it (`discovered_zones` for S2 populates on real
## traversal — composes against the W2-T5 save work). Mirrors the S1 discovery
## path in `_mark_zone_discovered_for_room_index`; `Player.mark_zone_discovered`
## is idempotent (returns false if the zone was already discovered). Emits the
## same `Main.discover_zone` trace line for parity.
func _record_discovered_zone(zone_id: StringName) -> void:
	if zone_id == &"":
		return
	if _player == null or not _player.has_method("mark_zone_discovered"):
		return
	var was_new: bool = bool(_player.call("mark_zone_discovered", zone_id))
	_combat_trace_main("Main.discover_zone", "zone_id=%s new=%s" % [str(zone_id), str(was_new)])


## Tear down the active authored room before rendering an assembled S2 floor.
## Mirrors the room-teardown block in `_load_room_at_index` — unparent the
## player BEFORE freeing the room so the player isn't taken down with it.
func _teardown_active_room_for_s2() -> void:
	if _current_room == null:
		return
	if _player != null and _player.get_parent() == _current_room:
		_current_room.remove_child(_player)
		if _world != null:
			_world.add_child(_player)
	_current_room.queue_free()
	_current_room = null
	_boss_room = null
	_boss_room_node = null


## HTML5-only `[combat-trace]` shim for the S2 traversal path. Mirrors the
## AudioDirector / DescendScreen trace pattern so the Playwright spec + Sponsor
## DevTools can confirm the descend→S2 transition fired (and read the assembled
## floor's chunk count + bounds).
func _combat_trace_main(tag: String, msg: String = "") -> void:
	if not is_inside_tree():
		return
	var df: Node = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)


func _on_player_died(_death_position: Vector2) -> void:
	# Defer the death rule to the next frame so any signals on this tick
	# (final hit's mob_died, etc.) finish first.
	# W3-T9 (`86c9uf6hh`) — per `audio-direction.md §3 ducking rule 3` the
	# death sequence Beat A hard-mutes BGM over 200 ms. We fire it
	# synchronously here (not deferred) so the music begins fading
	# immediately when the death frame freezes — the audio cue lands
	# alongside Uma's Beat A visual freeze rather than one frame later.
	var audio_director: Node = _audio_director()
	if audio_director != null and audio_director.has_method("stop_all_music"):
		audio_director.stop_all_music(200)
	call_deferred("apply_death_rule")


func _on_player_hp_changed(_hp_current: int, _hp_max: int) -> void:
	_refresh_hp_widget()


## HP regen shimmer — drives the HpBarShimmer ColorRect tween.
## Per Uma's spec §"Visual cue": warm-amber oscillation (0.8s SINE loop) when
## regen is active; kill + reset to transparent when regen deactivates.
##
## Shimmer design (ColorRect over the ProgressBar):
##   - Rest (regen inactive):    modulate alpha = 0.0 (fully transparent)
##   - Active peak:              modulate = Color(1.0, 1.0, 1.0, 1.0) (full opacity,
##                               colour comes from ColorRect.color = warm amber)
##   - Active trough:            modulate alpha ≈ 0.25 (dim, "breathing" oscillation)
## This is a Tier 1 visual-primitive-test invariant: target modulate != rest modulate.
func _on_player_regen_active_changed(active: bool) -> void:
	if _hp_bar_shimmer == null:
		return
	# Kill any in-flight tween before starting a new one.
	if _hp_shimmer_tween != null and _hp_shimmer_tween.is_valid():
		_hp_shimmer_tween.kill()
	_hp_shimmer_tween = null
	if active:
		# Shimmer on: oscillate modulate alpha between dim and bright with SINE
		# easing to produce a smooth "breathing" light effect. 0.8 s per cycle.
		_hp_shimmer_tween = create_tween()
		_hp_shimmer_tween.set_loops()
		_hp_shimmer_tween.set_trans(Tween.TRANS_SINE)
		_hp_shimmer_tween.set_ease(Tween.EASE_IN_OUT)
		_hp_shimmer_tween.tween_property(
			_hp_bar_shimmer, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4  # peak: full opacity → warm amber shows through
		)
		_hp_shimmer_tween.tween_property(
			_hp_bar_shimmer, "modulate", Color(1.0, 1.0, 1.0, 0.25), 0.4  # trough: dim, "breathing" dip
		)
	else:
		# Shimmer off: immediately snap to transparent so the shimmer doesn't
		# linger after regen deactivates (e.g. on damage taken mid-shimmer).
		_hp_bar_shimmer.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _on_xp_gained(_amount: int) -> void:
	_refresh_xp_widget()


func _on_level_up(_new_level: int) -> void:
	_refresh_level_widget()
	_refresh_xp_widget()
	# Persist on level-up — small enough that a quit-mid-XP-gain isn't
	# tragic, but a quit-mid-level-up that loses the level would be.
	_persist_to_save()


func _on_unspent_points_changed(new_unspent: int) -> void:
	if _stat_pip_label == null:
		return
	if new_unspent > 0:
		_stat_pip_label.text = "[+%d STAT]" % new_unspent
		_stat_pip_label.visible = true
	else:
		_stat_pip_label.text = ""
		_stat_pip_label.visible = false


# ---- HUD refresh ------------------------------------------------


func _refresh_hud_full() -> void:
	_refresh_hp_widget()
	_refresh_xp_widget()
	_refresh_level_widget()
	_refresh_room_label()
	_refresh_stat_pip()


func _refresh_hp_widget() -> void:
	if _player == null or _hp_bar == null or _hp_label == null:
		return
	_hp_bar.max_value = max(1, _player.hp_max)
	_hp_bar.value = _player.hp_current
	_hp_label.text = "%d / %d" % [_player.hp_current, _player.hp_max]


func _refresh_xp_widget() -> void:
	if _xp_bar == null or _xp_label == null:
		return
	var levels: Node = _levels()
	if levels == null:
		return
	var current_xp: int = int(levels.current_xp())
	var to_next: int = int(levels.xp_to_next())
	if to_next > 0:
		_xp_bar.max_value = to_next
		_xp_bar.value = clampf(float(current_xp), 0.0, float(to_next))
		_xp_label.text = "%d / %d" % [current_xp, to_next]
	else:
		_xp_bar.max_value = 1
		_xp_bar.value = 1
		_xp_label.text = "MAX"


func _refresh_level_widget() -> void:
	if _level_label == null:
		return
	var levels: Node = _levels()
	if levels == null:
		return
	_level_label.text = "LV %d" % int(levels.current_level())


func _refresh_room_label() -> void:
	if _room_label == null:
		return
	if _current_room_index == S2_BOSS_ROOM_INDEX:
		# W3-T7 Stage 6 — S2 boss room label.
		_room_label.text = "STRATUM 2 · BOSS"
		_room_label.add_theme_color_override("font_color", Color(0.823, 0.290, 0.235, 1.0))
	elif _current_room_index == BOSS_ROOM_INDEX:
		_room_label.text = "STRATUM 1 · BOSS"
		_room_label.add_theme_color_override("font_color", Color(0.823, 0.290, 0.235, 1.0))
	else:
		_room_label.text = "STRATUM 1 · ROOM %d/8" % (_current_room_index + 1)
		_room_label.add_theme_color_override("font_color", Color(0.9098, 0.8941, 0.8392, 1.0))


func _refresh_stat_pip() -> void:
	var ps: Node = _player_stats()
	if ps == null or _stat_pip_label == null:
		return
	var n: int = int(ps.get_unspent_points())
	if n > 0:
		_stat_pip_label.text = "[+%d STAT]" % n
		_stat_pip_label.visible = true
	else:
		_stat_pip_label.text = ""
		_stat_pip_label.visible = false


# ---- Autoload accessors -----------------------------------------


func _save() -> Node:
	return get_tree().root.get_node_or_null("Save")


func _levels() -> Node:
	return get_tree().root.get_node_or_null("Levels")


func _player_stats() -> Node:
	return get_tree().root.get_node_or_null("PlayerStats")


func _inventory() -> Node:
	return get_tree().root.get_node_or_null("Inventory")


func _stratum_progression() -> Node:
	return get_tree().root.get_node_or_null("StratumProgression")


func _audio_director() -> Node:
	return get_tree().root.get_node_or_null("AudioDirector")


## T16 (`86c9wjzgh`, M3 Tier 2 Wave 3) — CameraDirector autoload resolver.
## Mirrors `_audio_director()` shape so bare-test surfaces (e.g.
## `tests/integration/test_t16_boss_death_cinematic_wiring.gd`) can
## construct Main without crashing if the autoload is absent.
func _camera_director() -> Node:
	return get_tree().root.get_node_or_null("CameraDirector")


## M3-T3-W2-T1 (`86c9y0zmg`) — Engage CameraDirector continuous-scroll
## against the freshly-loaded room. Called from `_load_room_at_index`
## after the player has been re-parented into the new room.
##
## Idempotent on room-cycle: re-engaging with the same player + deadzone
## emits no follow_target_changed signal (per spike's idempotence
## semantics); re-setting the same Rect2 bounds is also a no-op. The
## CameraDirector autoload survives the room-swap, so the live-state
## persists across loads — these calls just re-assert the same contract.
##
## Bare-test soft-fail: if `CameraDirector` autoload is absent (bare-
## instance GUT tests that don't include the autoload), the helper logs
## once and returns. Mirrors the `_audio_director()` / `_camera_director()`
## soft-resolve shape — the rest of the room-load flow MUST continue.
##
## See `.claude/docs/camera-scroll.md` § "Production wiring" for the
## end-to-end contract; `S1_ROOM_BOUNDS` + `CAMERA_FOLLOW_DEADZONE`
## constants define the values used.
func _engage_camera_for_room() -> void:
	if _player == null:
		return
	var cd: Node = _camera_director()
	if cd == null:
		return
	if cd.has_method("follow_target"):
		cd.follow_target(_player, CAMERA_FOLLOW_DEADZONE)
	if cd.has_method("set_world_bounds"):
		cd.set_world_bounds(S1_ROOM_BOUNDS)


## M3 Tier 3 W2-T5 — discovery write hook (ticket `86c9y10fv`). Looks up
## the zone_id for the given room index in `ROOM_INDEX_TO_ZONE_ID` and
## calls `Player.mark_zone_discovered(zone_id)`. The Player method is
## idempotent; re-entering an already-discovered zone is a no-op.
##
## Fires a `[combat-trace] Main.discover_zone | zone_id=<id> new=<bool>`
## line so Playwright + Sponsor soak can verify the hook empirically. The
## `new` flag distinguishes first-discovery (true) from re-entry (false).
##
## Defensive against bare-test surfaces: returns cleanly when Player is
## null or the index is out of range.
func _mark_zone_discovered_for_room_index(index: int) -> void:
	if _player == null:
		return
	if index < 0 or index >= ROOM_INDEX_TO_ZONE_ID.size():
		return
	var zone_id: StringName = ROOM_INDEX_TO_ZONE_ID[index]
	if not _player.has_method("mark_zone_discovered"):
		return
	var was_new: bool = bool(_player.call("mark_zone_discovered", zone_id))
	var df: Node = get_tree().root.get_node_or_null("DebugFlags") if is_inside_tree() else null
	if df != null and df.has_method("combat_trace"):
		df.combat_trace("Main.discover_zone", "zone_id=%s new=%s" % [str(zone_id), str(was_new)])
