# Combat Architecture

What this doc covers: the combat system's runtime topology — Player swing flow, Hitbox / Projectile encapsulated-monitoring pattern, mob `_die` death pipeline, hit-flash / death-tween visuals, the `[combat-trace]` shim, and the load-bearing Godot 4 physics-flush rule that constrains every `Area2D` add path. Combat tunables and balance live in `resources/mobs/*.tres` and the Damage formula constants (see `team/decisions/DECISIONS.md` `2026-05-02 — Damage formula constants locked`).

## Player swing path

[`scripts/player/Player.gd`](scripts/player/Player.gd) — `try_attack` is the entry point on every LMB / RMB. Per swing it:

1. Spawns a `swing_wedge` ColorRect (rotated rectangle, sized `reach × radius*2`) parented to Player at `z_index = 1`. Tweens it out over `lifetime` (light: 0.100s; heavy: 0.140s). The wedge is a **ColorRect**, not a Polygon2D — Polygon2D + Godot 4.3's `gl_compatibility` renderer (HTML5 default) was the load-bearing visibility bug fixed in PR #137.
2. Runs `swing_flash` — tweens `Player.modulate` to `SWING_FLASH_TINT = Color(1.0, 0.85, 0.6, 1.0)` for 60ms, then back to white. The tint is **sub-1.0 on every channel** — earlier `Color(1.4, 1.0, 0.7)` clamped to white in WebGL2's sRGB pipeline (HTML5) and produced no visible flash. See `.claude/docs/html5-export.md`.
3. Constructs a `Hitbox` Area2D, parents it under Player. Hitbox enters the tree with `monitoring = false / monitorable = false` (set in `_init`); `_ready()` defer-activates monitoring and runs `_activate_and_check_initial_overlaps()` — see "Physics-flush rule" below.
4. Emits `Player.try_attack | POST damage=N hitbox=@Area2D@<id>` via the combat-trace shim.

Damage routing: `Damage.compute_player_damage()` short-circuits to `FIST_DAMAGE = 1` when `weapon == null` (the player starts fistless **by design** per `DECISIONS.md 2026-05-02`). The `HEAVY_MULT = 0.6` multiplier path is bypassed when fistless — both light and heavy LMB/RMB deal 1 damage. Once a weapon is equipped, the multiplier path engages.

## Hitbox + Projectile encapsulated-monitoring rule

[`scripts/combat/Hitbox.gd`](scripts/combat/Hitbox.gd) and [`scripts/projectiles/Projectile.gd`](scripts/projectiles/Projectile.gd) both follow this pattern:

```gdscript
func _init() -> void:
    monitoring = false
    monitorable = false

func _ready() -> void:
    # Godot defers _ready to after the current physics step,
    # so it's safe to flip monitoring on here.
    monitoring = true
    monitorable = true
    _activate_and_check_initial_overlaps()
```

This is the **load-bearing fix** for the M1 RC P0 wave 2 (PR #143). Five spawn sites benefit: `Player.gd:870` (swing hitbox), `Grunt.gd:355` / `Charger.gd:449` / `Stratum1Boss.gd:531` (mob melee hitboxes), `Shooter.gd:371` (projectile). All construct via `HitboxScript.new()` or `ProjectileScene.instantiate()` (the `.tscn` does NOT override monitoring properties, so `_init` defaults flow through).

**Why receiver-side encapsulation, not caller-side `set_deferred("add_child", ...)`:** future spawn sites are auto-protected without caller-side discipline. `StratumExit._build_interaction_area` already used the same idiom organically — Devon's PR #143 harmonized Hitbox/Projectile with that pre-existing pattern rather than introducing a new convention.

`Stratum1BossRoom._build_door_trigger` **was** a latent instance of this bug class — fixed in ticket `86c9tv8uf` (the follow-up flagged in PR #183). The earlier claim here that it had "zero panic risk because it spawns from `_ready`, not a physics-tick path" was **wrong**: the boss room is loaded by `Main._load_room_at_index(8)` from Room 08's `RoomGate.gate_traversed` body callback, so `Stratum1BossRoom._ready()` runs *inside a physics flush* — exactly like Rooms 02–08. `_build_door_trigger` (synchronous Area2D `add_child`) and `_spawn_stratum_exit` (adds a `StratumExit` whose own `_ready` builds an Area2D interaction area) are now deferred via `Stratum1BossRoom._ready → call_deferred("_assemble_room_fixtures")`, landing them after the flush closes. `_spawn_boss` stays synchronous in `_ready` — the boss is a CharacterBody2D (no monitoring mutation on tree-entry) and `Main._wire_room_signals` reads `get_boss()` on the same tick. Tracking tickets: `86c9p1fgf` (the original monitorable harmonization), `86c9tv8uf` (the physics-flush defer). See `team/log/process-incidents.md` for the full history.

**Third known case — `StratumExit.activate()` from `_on_boss_died` (PR #232, ticket `86c9ujq8d`, M2 W3 Sponsor soak).** Spawning the StratumExit deferred is not enough: the *activation* path is ALSO inside a physics flush. The chain is `Hitbox.body_entered → boss.take_damage → boss._die → boss_died.emit → Stratum1BossRoom._on_boss_died → _stratum_exit.activate() → _interaction_area.monitoring = true`. The C++ Area2D monitoring setter's `ERR_FAIL_COND` fires the familiar "Can't change this state while flushing queries" — but the failure is **silent in GDScript** (USER ERROR log only, no exception, monitoring just stays `false`). User-visible symptom: player beats boss, walks to exit, press-E does nothing, trapped forever. Fix: `_stratum_exit.call_deferred("activate")` in `_on_boss_died`. The `stratum_exit_unlocked` signal can still fire synchronously immediately after so downstream wiring (`Main._on_stratum_exit_unlocked`) lands in the same frame; only the Area2D monitoring mutation needs to wait one frame. **Three known cases in the chain pattern now:** `_build_door_trigger` (door build), `MobLootSpawner.on_mob_died` (loot Pickup add_child), and `StratumExit.activate` (exit monitoring flip) — any future Area2D monitoring write or `add_child` reachable from a `body_entered`/`area_entered` callback should be defaulted to `call_deferred`. The silence is the diagnostic trap: code review sees a normal-looking call site and no panic / no test failure — only HTML5 soak surfaces it. Regression-pin pattern: `test_stratum_exit_activate_deferred_after_boss_death` asserts exit is NOT active same-frame, IS active after one `process_frame` await.

**Boss-room Finding 2 is a DIFFERENT bug class — NOT silent ERR_FAIL_COND (PR #247, ticket `86c9uq0ky`, Sponsor 2026-05-16 soak of diag `83267fd`).** The framing above (silent `ERR_FAIL_COND` on the Area2D monitoring setter) is the correct root cause for **non-boss** Pickups + StratumExit; PR #241's double-defer fix verifiably resolved those (Rooms 01/02/03/08 all show `mon_actual=true` + `body_entered` fires + `Inventory.add` succeeds in post-#241 soaks). But the boss-room manifestation of "press-E does nothing on the dropped iron_sword + leather_vest" had a **second, independent root cause** that the silent-ERR_FAIL_COND framing did NOT cover: **`Player.collision_layer` got stuck at `0` after the boss fight.** Pickup `mask=2` cannot detect a Player CharacterBody2D on `layer=0`; same for StratumExit. The Sponsor diag-build `83267fd` instrumented `Player.coll_diag | pos layer mask cs_disabled iframes` alongside `Pickup._activate_diag` + `StratumExit._arm_diag` (paired the area-side readback with the player-side state) and traced the empirical end-state `layer=0 mask=1 cs_disabled=false iframes=false` after boss death + 60+ idle ticks of HP regen — area-side was healthy, **player-side was at layer 0**. The chain: `_enter_iframes` is called by both `take_damage` (line 585 — post-hit iframe grant) and `try_dodge` (line 741 — dodge iframe entry); both call sites save `_saved_collision_layer = collision_layer`, then clear `collision_layer = 0`. **Pre-fix, with no re-entry guard,** a dodge during the post-hit iframe window re-saved `_saved_collision_layer = 0` (the already-cleared value), destroying the genuine layer-2 restore target. When the dodge ended, `_exit_iframes` restored to 0 permanently. **Fix:** `_enter_iframes` early-returns when `_is_invulnerable` is already true, leaving the original `_saved_collision_layer` intact. Single-line guard at function head; `_exit_iframes` unchanged. **Test discipline:** the bug had been latent across the whole codebase since post-hit iframes shipped (PR for ticket `86c9u4mdc`, Uma's AC4 Room 05 balance pin §3.B) — `tests/test_player_hit_iframes.gd` covered the timer-arm + dodge-precedence semantics but did NOT exercise `collision_layer` round-trip through the dodge-during-iframes chain. Regression pin landed: `tests/test_player_collision_layer_restore.gd` (baseline non-zero, single round-trip, N=2 re-entry, realistic `take_damage → try_dodge → _process_dodge` chain, N=3 paranoia). **Why boss room not Room 05 / earlier rooms.** Pre-boss rooms have no pickup-on-floor user-visible surface — the iframe regression was invisible because nothing depended on Player layer being 2 (enemy hitboxes use `collision_mask`, not `collision_layer`, so combat continued working; world collision uses `collision_mask`, not `collision_layer`, so walls still blocked). The boss room is the FIRST place where a Pickup body_entered cares about Player.collision_layer after a boss-damage cluster has set up the dodge-during-iframes scenario. Sponsor's report "boss room 8 cannot loot dropped items" was the first user-visible manifestation. **Diagnostic-pattern lesson:** `Player.coll_diag` (player layer + mask + cs_disabled + iframes), `Pickup._activate_diag` (overlapping_bodies + cs state + mon readback), and `StratumExit._arm_diag` (sibling readback) are now the **canonical discrimination triad** for "Area2D body_entered never fires" bugs. The area-side readback (`mon_actual=true`) RULES OUT silent ERR_FAIL_COND. The player-side readback (`layer=0`) DIAGNOSES the collision-layer regression. Together they discriminate the two known classes in one trace cycle — without both halves, the second class was invisible to PR #241's area-side-only instrumentation. **Bug-class taxonomy now:** Class A = silent ERR_FAIL_COND on Area2D monitoring setter (PR #232 + PR #241, area-side, fixed by `await physics_frame`); Class B = Player.collision_layer regression from un-guarded iframe re-entry (PR #247, player-side, fixed by re-entry guard). The diag instrumentation from `83267fd` is cherry-picked onto the PR #247 fix branch so the triad stays in main for future regression catches.

**Double-defer addendum (PR #240, ticket `86c9unkr2`, M2 W3 Sponsor 2026-05-16 soak of `92b6206`).** PR #232's single `call_deferred("activate")` was empirically **insufficient under HTML5** — Sponsor's trace stream showed `StratumExit.activate` running, the synchronous trace `monitoring flipped ON` printed, then `body_entered` never fired against the area for 60+ seconds. Sibling `Pickup._activate_and_check_initial_overlap` failed the same way. The diagnostic trap was that the "monitoring flipped ON" string was a hardcoded label, not a readback — there was no signal whether the C++ setter actually succeeded. Hypothesis (verifiable on next soak via the readback trace below): the boss-death frame's end-of-frame deferred queue drains 1× StratumExit `activate`, 2× Pickup `add_child`, 2× Pickup `_ready`-deferred `_activate`, particle adds, and signal cascades — under HTML5's `gl_compatibility` physics timing, monitoring mutations from inside that crowded deferred drain still race against in-flight `flush_queries()`. **Fix shape (a) "double-defer":** `await get_tree().physics_frame` BEFORE the `monitoring = true` write. `await physics_frame` yields until the next physics tick boundary, by definition AFTER any in-flight flush has completed. Applied to both `StratumExit.activate` (split into sync `activate` + async `_arm_interaction_area_after_flush`) and `Pickup._activate_and_check_initial_overlap` (await at top). **Readback trace as diagnostic surface:** every monitoring write is now paired with `mon_actual=%s` (reads `monitoring` BACK after the setter). If the silent ERR_FAIL_COND ever fires again, `mon_actual=false` will surface in the trace stream and the failure mode is empirically distinguishable from "code never reached." Pre-fix the labels were hardcoded "true" regardless of actual state. **Test-discipline consequence:** `activate()` flips `_is_active` + visual state synchronously (test compat), but the `_interaction_area.monitoring` flip is now async — GUT tests that assert post-`activate()` monitoring must `await get_tree().physics_frame; await get_tree().process_frame`. Pinned by `test_activate_monitoring_flips_after_physics_frame_not_synchronously` (StratumExit + Pickup test files).

## Mob spawn registry (MobRegistry autoload)

[`scripts/content/MobRegistry.gd`](scripts/content/MobRegistry.gd) — autoload registered in `project.godot` as `MobRegistry="*res://scripts/content/MobRegistry.gd"` (ticket `#86c9ue1up`, W3-T5). Maps `mob_id: StringName → MobDef + PackedScene` and exposes stratum-scaling.

**Surface:**

- `get_mob_def(mob_id) -> MobDef` / `get_mob_scene(mob_id) -> PackedScene` — return `null` on unknown id (graceful, push_warning'd).
- `has_mob(mob_id) -> bool` — allocation-free check; mirrors get_mob_def's null result.
- `apply_stratum_scaling(mob_def, stratum_id) -> MobDef` — returns a **NEW** MobDef with hp_base × multiplier + damage_base × multiplier. Source is NEVER mutated — calling twice with `&"s2"` returns a new def with the SAME 1.2x value, NOT compounded 1.44x. Integer scaling uses `roundi`. Unknown stratum falls back to baseline 1.0/1.0 with push_warning.
- `spawn(mob_id, world_position, room_node) -> Node` — unified entry-point. Instantiates the scene, applies MobDef to `node.mob_def`, sets position, parents under `room_node`. Returns null on unknown id.
- `registered_ids() -> Array` — diagnostic enumeration of mob_ids.

**Scaling table** (mvp-scope.md §M2): `&"s1"` → {hp: 1.0, damage: 1.0}; `&"s2"` → {hp: 1.2, damage: 1.15}. Add future strata by appending to `_STRATUM_SCALING`.

**Adding a new mob class** (e.g. Stoker, W3-T3/T4 surface): one-line append to `_REGISTRATIONS` with `{def: "res://resources/mobs/<id>.tres", scene: "res://scenes/mobs/<Id>.tscn"}`. Every existing spawn site picks it up via `MobRegistry.spawn` or `get_mob_def`/`get_mob_scene` with no further code changes — this is the load-bearing benefit of the W3-T5 refactor.

**Autoload-order independence.** `_REGISTRATIONS` and `_STRATUM_SCALING` are module-scope `const` dictionaries; `_def_cache` / `_scene_cache` are member init-time `Dictionary = {}`. Callers can invoke `get_mob_def` / `get_mob_scene` BEFORE the autoload's `_ready` runs (e.g. from another autoload's `_ready` if Godot resolves autoloads in a different order than the project.godot declarations). Pinned by `tests/test_mob_registry.gd::test_get_mob_def_before_ready_returns_correct_def`.

**MultiMobRoom integration.** `scripts/levels/MultiMobRoom.gd::_spawn_mob` was a per-mob match-block pre-W3-T5; it now delegates to `_instantiate_from_registry(mob_id)` which calls `MobRegistry.get_mob_scene` + `get_mob_def`. The legacy `@export_file` paths on MultiMobRoom (`grunt_scene_path` / `charger_mob_def_path` / etc.) remain **only** to preserve existing `.tscn` author-time values; the registry is the source of truth for dispatch. Behaviour is bit-identical pre-/post-refactor (same PackedScene instance via resource cache, same MobDef applied) — regression pinned by `tests/test_stratum1_rooms.gd` + `tests/test_stratum2_rooms.gd` staying green. **`Stratum1Room01._spawn_mob` is NOT yet refactored** (tutorial room, grunt + practice-dummy dispatch on a different surface); a follow-up can pull it into the registry if M2+ surfaces benefit from unified dispatch.

**Stratum-scaling NOT yet applied to live spawns.** `apply_stratum_scaling` is exposed on the API but the W3-T5 PR does NOT inject it into `MobRegistry.spawn`'s mob_def-apply path — that would silently change M1 / M2 mob HP-damage values mid-W3 and break the refactor's "no behavior change" promise. The wiring decision (which spawn sites become stratum-aware) deferred to W3-T1 AC4 balance pass or a dedicated follow-up ticket.

## Mob `_die` death pipeline

When a mob's HP reaches 0, the synchronous chain is:

1. `_set_state(STATE_DEAD)`
2. `mob_died.emit(...)` — listeners (notably `MobLootSpawner.on_mob_died`) run synchronously on the same frame
3. `_spawn_death_particles()` — adds a `CPUParticles2D` to the room
4. `_play_death_tween()` — alpha/scale tween over `DEATH_TWEEN_DURATION` (typically 0.4s); arms a parallel `SceneTreeTimer` of the same duration as a safety net
5. On either `tween.finished` OR the timer firing first: `_on_death_tween_finished` → `_force_queue_free()` (idempotent guard via `is_queued_for_deletion()`)

**The parallel SceneTreeTimer is critical** (PR #136). Without it, mobs become functionally immortal if the death tween hangs for any reason — the original P0 that surfaced in the M1 RC investigation.

`MobLootSpawner.on_mob_died` calls `parent_for_pickups.call_deferred("add_child", pickup)` (PR #142 fix) — Pickup root is an Area2D, and adding it during physics flush triggers the same `USER ERROR: Can't change this state while flushing queries` panic. The `_spawn_death_particles` adds in each of 4 mob types also use `room.call_deferred("add_child", burst)` defensively.

### Single MobLootSpawner per mob death — load-bearing rule (ticket `86c9uemdg`)

**Exactly ONE `MobLootSpawner` instance must process each mob_died/boss_died event.** Multiple spawners running in parallel each roll the loot table independently AND each produce their own set of `Pickup` Area2Ds — the resulting Pickup sets are spatially identical (same `death_pos + ring_offset(i)` arithmetic, with independent RNG only inside the roll) but **scenically distinct** Area2Ds. Critically, **only the spawner whose Array[Node] return value is fed into `Inventory.auto_collect_pickups` produces collectable pickups** — every other spawner's set has zero `picked_up` listeners and the player walking over them does nothing.

**The Stratum1BossRoom dual-spawn bug (Sponsor M2 RC, build `5bef197`).** Pre-fix, `Stratum1BossRoom._on_boss_died` owned its own `MobLootSpawner` and called `on_mob_died(boss, ...)` directly, discarding the return value. `Main._wire_mob` ALSO connected the boss's `boss_died` to `Main._on_mob_died`, which calls Main's `_loot_spawner.on_mob_died(...)` AND `Inventory.auto_collect_pickups(pickups)` on its return value. So **two pickup sets spawned per boss death** — Main's set was collectable; the BossRoom's set was a phantom litter of un-listened-to Area2Ds. Sponsor's user-visible report was "boss room 8 cannot loot dropped items" — half their attempts hit phantom pickups and produced no inventory delta. Headless GUT had a `test_boss_death_drops_loot_into_room` asserting `pickup_count > 0` — green. Headless tests had no integration coverage asserting `picked_up.get_connections().size() > 0` per pickup OR `pickup_count == loot_table.entries.size()` (the dual-spawn produced exactly 2x, but `> 0` is satisfied by 2x too). **Fix:** delete the BossRoom's `_loot_spawner` entirely; Main is the single boss-loot pipeline.

**Pattern check for any future loot-drop site.** Whenever a room script, mob script, or controller subscribes its OWN listener to `mob_died` / `boss_died` for loot purposes, audit whether `Main._wire_mob` already wires that signal. The current production audit:

- `Grunt.mob_died` / `Charger.mob_died` / `Shooter.mob_died` / `Stratum1Boss.boss_died` → wired by `Main._wire_mob` → `Main._on_mob_died` → Main's `_loot_spawner.on_mob_died` + `Inventory.auto_collect_pickups`. **All standard mob loot flows through this path.**
- `PracticeDummy.mob_died` → emits `mob_def == null`, so Main's `_on_mob_died` short-circuits (no loot rolled). `PracticeDummy._spawn_iron_sword_pickup` is a CUSTOM spawn path that wires `Pickup.picked_up` directly to `Inventory.on_pickup_collected`. **Bypasses MobLootSpawner entirely; collectability is intentional and load-bearing for the Stage-2b onboarding gate.**
- `Stratum1BossRoom` → post-fix: NO loot spawn. Boss loot rides on Main's `boss_died` subscription. The BossRoom only owns the StratumExit activation flip.

**Pickup-collectability test bar** (integration class, complement to the single-spawn rule above). Headless GUT must assert at least one of these per loot-spawn surface:

1. `pickup.picked_up.get_connections().size() > 0` after spawn — proves a listener is wired.
2. `pickup.is_connected("picked_up", Inventory.on_pickup_collected)` — proves the specific production listener is the one wired.
3. Drive `Pickup._on_body_entered(player)` and assert `Inventory.get_items()` grew OR `Inventory.get_equipped(&"weapon") != null` — proves end-to-end collectability.

`pickup_count > 0` is **NOT sufficient** — the dual-spawn produced a positive count of uncollectable pickups. See `tests/integration/test_boss_loot_integration.gd` (REGRESSION-86c9uemdg) for the canonical structural shape.

### Every loot-table item must be in `ContentRegistry.STARTER_ITEM_PATHS` (ticket `86c9uemdg` sibling)

**Inclusion rule:** any item appearing in `resources/loot_tables/*.tres` entries (i.e. an item that can land in a save via a live drop) must be listed in `ContentRegistry.STARTER_ITEM_PATHS`. The recursive + `KNOWN_ITEM_SUBDIRS` scans are best-effort in HTML5 / `gl_compatibility` packed builds (the DirAccess `current_is_dir()` quirk + `list_dir_begin()` behavior on .pck resources is unreliable — see `.claude/docs/html5-export.md` § "Resource enumeration on packed `.pck` resources"). Direct `load()` of a packed res:// path always works because it reads from the resource cache, not DirAccess.

Pre-fix only `iron_sword.tres` was direct-loaded; Sponsor's M2 RC soak (build `5bef197`) surfaced `USER WARNING: ItemInstance.from_save_dict: unknown item id 'leather_vest'` on boot because the previous run had picked up a `leather_vest` (a guaranteed drop from `boss_drops.tres` + 0.30 cumulative weight on `grunt_drops.tres`) into the save, and this run's HTML5 build failed to register it via DirAccess. **Fix:** added `leather_vest.tres` to `STARTER_ITEM_PATHS`. Future T2/T3 loot expansions must extend this list as new items ship.

The id-collision-from-different-instance guard in `_on_item_resource_found` lets the same item be registered multiple times across the three scan passes (recursive + subdir + STARTER_ITEM_PATHS direct-load) without warning — same-instance re-registration is a no-op because Godot's resource cache hands out the same `ItemDef` instance for the same path.

**Test bar.** Every item added to `STARTER_ITEM_PATHS` needs a paired drift-detector test in `tests/test_save_restore_resolver_ready.gd`:

1. `test_load_all_resolves_<item>_via_starter_paths` — registry resolves the item after `load_all()`.
2. `test_starter_item_paths_includes_<item>_drift_detector` — `STARTER_ITEM_PATHS.has("res://.../<item>.tres")` — surfaces a regression if someone removes the path thinking DirAccess covers it.
3. `test_restore_from_save_<item>_in_stash_resolves_silently` — save-roundtrip with the item in stash produces a non-null `ItemInstance.def`.

See `iron_sword` (ticket 86c9qah1f) + `leather_vest` (ticket 86c9uemdg) for the precedent.

**RoomGate uses `CONNECT_DEFERRED` for `mob_died` listeners** (ticket 86c9qcf9z). `RoomGate.register_mob` connects with `mob.mob_died.connect(_on_mob_died, CONNECT_DEFERRED)` so the `_mobs_alive` decrement queues to end-of-frame instead of running inside the mob's synchronous emit chain. **Why this matters:** `MultiMobRoom._register_mobs_with_gate` runs from `MultiMobRoom._ready`, which itself runs during a physics-flush window when `Main._load_room_at_index` is called from a previous room's `gate_traversed → _on_room_gate_traversed → room_cleared → _on_room_cleared` chain (rooted in a CharacterBody2D `body_entered` callback). Subsequent `mob_died.emit` calls reach the gate via this connection, and prior to the deferred fix the gate's decrement competed with other physics-flush mutations (Pickup adds, particle adds, room transitions). Tess's PR #172 AC4 trace empirically observed two grunts emitting `Grunt._die` but only ONE decrement landing on the gate, leaving `_mobs_alive=1, state=open` and blocking the gate from ever transitioning to UNLOCKED. CONNECT_DEFERRED sidesteps the entire race class — every mob_died emission queues an end-of-frame decrement that runs outside the flush window.

**Cross-tree signal-connection discipline (load-bearing).** Any signal-handler that:

1. is connected from a context running during physics flush (e.g. inside `_ready` of a node added via `add_child` from a prior room's death / traversal callback), AND
2. the connected handler mutates persistent state the receiver later inspects (counter, list, gate-state)

should be connected with `CONNECT_DEFERRED`. The synchronous-emit alternative is timing-sensitive and may lose decrements/increments under physics-flush re-entry. `Levels.subscribe_to_mob` already uses `CONNECT_ONE_SHOT` (a different concern — once-per-life XP); `Main._wire_mob` connects synchronously but only forwards to a deferred-add-child path. RoomGate is the canonical example of a counter-style listener that needs CONNECT_DEFERRED.

**Test-side consequence.** GUT tests that fire `mob_died` synchronously and then immediately inspect `gate.mobs_alive()` / `gate.is_unlocked()` must `await get_tree().process_frame` between the emit and the assertion. The pre-existing `test_room_gate.gd` / `test_room_advance_only_on_door_walk.gd` / `test_room_transition_requires_door_walk.gd` tests were updated alongside the CONNECT_DEFERRED migration to drain a frame between every `m.die()` call and the next assertion.

### `Player._die` + `Main.apply_death_rule` diagnostic-trace pair (ticket 86c9u397c)

`Player._die` (`scripts/player/Player.gd`) and `Main.apply_death_rule` (`scenes/Main.gd`) both emit `[combat-trace]` lines (HTML5-only via the existing shim). **These two lines are load-bearing for any future "mob freeze" investigation** — without them, a Player-death + M1-death-rule room reload presents the *exact same* trace shape as a sibling-mob `_physics_process` freeze:

| Symptom | Player-death + reload (real cause) | Sibling-mob `_physics_process` freeze (hypothetical) |
| --- | --- | --- |
| Mob `.pos` traces stop within 1-2 frames of a sibling `_die` | YES — mobs are freed by the room reload | YES — `_physics_process` literally stops |
| `Player.try_attack` traces continue uninterrupted | YES — Player respawned in Room 01 | YES — Player still in original room |
| `Player.pos` jumps to `(240, 200)` (`DEFAULT_PLAYER_SPAWN`) | YES — respawn teleport | NO — Player stays put |
| TutorialEventBus `wasd`/`dodge` beats fire | YES — Room 01 tutorial reset | NO |
| `RoomGate.register_mob` burst for the SAME room | YES — fresh room load | NO |
| `[combat-trace] Player._die` line in stream | **YES — diagnostic** | NO |
| `[combat-trace] Main.apply_death_rule` line | **YES — diagnostic** | NO |

The 86c9u397c bug brief is the cautionary tale: Devon's PR #198 instrumentation observed mob `.pos` going silent after a sibling `_die` in Room 05 (8/8 release-build runs) and the orchestrator hypothesised a death-path physics-flush sibling-freeze analogous to PR #191's load-path fix. Empirical investigation against a release build of `40a8a7d` proved the actual cause was **the Player dying** — Room 05's three concurrent chasers (2 grunts + 1 charger) deal damage faster than the harness's near-spawn click-spam can clear them, the M1 death rule reloads Room 01, and the surviving mobs are freed by the room transition. The hypothesis was unfalsifiable from the pre-fix trace stream because Player.gd's `_die` and Main.gd's `apply_death_rule` had no `[combat-trace]` lines — Player death was completely invisible, and the Player.pos teleport to `DEFAULT_PLAYER_SPAWN` was indistinguishable from "Player at center of Room N" to a harness scanning the stream.

The trace lines emit at the START of each function so they precede the cascade. `Player._die`'s line carries `hp=0 pos=(x,y)` so investigators can correlate against room geometry; `Main.apply_death_rule`'s line carries the death-rule semantics summary so the room-reload event is annotated.

**Pattern check for future "mob freeze" bug reports:** before declaring a physics-flush sibling-freeze hypothesis, grep the trace stream for `Player._die` and `Main.apply_death_rule`. If either line appears within ~3s of the suspected freeze frame, the cause is Player death — not a physics-flush mutation. Only if BOTH lines are absent does the physics-flush hypothesis warrant investigation. This rule is the harness-side of the harness's own diagnostic logic in `tests/playwright/fixtures/kiting-mob-chase.ts::chaseAndClearMultiChaserRoom` (the failure-path reframes "GAME-side freeze" as "PLAYER DIED" when the trace pair is present).

Paired tests: `tests/test_player_die_combat_trace.gd` (Player._die emit + one-shot + ordering) + `tests/integration/test_apply_death_rule_combat_trace.gd` (apply_death_rule emit + payload). Both pin the diagnostic contract — if the lines are removed in a future refactor, the tests fail before CI green and the misdiagnosis class re-opens.

## Mob hit-flash (PR #140 fix)

Each mob type ([`scripts/mobs/Grunt.gd`](scripts/mobs/Grunt.gd), `Charger.gd`, `Shooter.gd`, `Stratum1Boss.gd`) has `_play_hit_flash`. The current implementation:

1. Resolves `_hit_flash_target` on first hit: prefers child `Sprite` (a `ColorRect` per the mob's scene), falls back to `self.modulate` if no Sprite child (bare-instanced test mobs).
2. Tweens the target's color through `rest → white → hold → rest` over ~80ms (`HIT_FLASH_IN + HIT_FLASH_HOLD + HIT_FLASH_OUT`).

**Why child Sprite, not parent `self.modulate`:** the original PR #115 implementation tweened the parent CharacterBody2D's modulate from `(1,1,1,1)` to `(1,1,1,1)` and back — a multiplicative no-op cascading into the child sprite. PR #140 fixed this by tweening the visible-draw node's color directly. Per-mob rest colors:

- Grunt: `Color(0.55, 0.18, 0.22)` (red-brown)
- Charger: `Color(0.78, 0.42, 0.18)` (orange)
- Shooter: `Color(0.32, 0.45, 0.78)` (blue)
- Stratum1Boss: `Color(0.48, 0.12, 0.16)` (deep red)

Tier 1 invariant from `team/TESTING_BAR.md`: visual-primitive tests must assert observable color delta (`target != rest`), not just `tween_valid == true`. Test bar codified in PR #138 + post-mortem at `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md`.

**Tier 1 corollary — tween kill-and-restart pattern.** For any "second-event-during-active-tween-kills-and-restarts" pattern (hit-flash interrupted by a second hit, save-toast retriggered before fade-out completes, etc.), tests MUST assert **reference change** (`assert_ne(old_tween, new_tween)`), NOT `is_valid()` flip. Godot 4.3's `Tween.kill()` leaves the tween object in a valid-but-stopped state; `is_valid()` does not flip to false synchronously. Precedent: `tests/test_combat_visuals.gd::test_grunt_second_hit_during_flash_restarts_tween` and `tests/test_m2_w1_ux_polish.gd::test_t2_toast_throttle_reuses_single_widget` (PR #160 CI bounce — initial commit asserted `is_valid()` flip and CI flagged it; reference-change is the load-bearing invariant).

## Shooter state machine — engagement bands + cornered fallback (ticket 86c9uehaq)

[`scripts/mobs/Shooter.gd`](scripts/mobs/Shooter.gd) is the only Stratum-1 RANGED mob (Grunt + Charger + Stratum1Boss are melee). Its distance bands and engagement transitions encode a kiter-with-pursuit-and-cornered-fallback design that took two iterations to reach correctness — the constants are tightly coupled to projectile reach, and getting either band wrong manifests as one of three Sponsor-visible failure modes.

**The three bands (post-86c9uehaq):**

- `dist < KITE_RANGE` (120 px) → `STATE_KITING`: walk directly away from the player at `move_speed` (60 px/s).
- `KITE_RANGE..SHOOT_RANGE` (120..144 px) → the **sweet spot**: stand still, aim, fire. The band is intentionally narrow — its upper bound is **`SHOOT_RANGE = PROJECTILE_SPEED × PROJECTILE_LIFETIME`** (the effective projectile reach), so any projectile fired from inside the band can reach the player.
- `dist > SHOOT_RANGE` (144 px) → **close the gap**: walk toward the player at `move_speed` during both AIMING and POST_FIRE_RECOVERY. The aim timer still ticks during the walk so the shot fires when it expires.

**`AIM_RANGE` (300 px) is the outer AGGRO BOUND, not the close-the-gap threshold.** Pre-86c9uehaq, `AIM_RANGE` was BOTH (kept simple by design). Sponsor's M2 RC manual-soak surfaced three Room 04 failure modes that traced back to that conflation:

| Failure mode (Sponsor verbatim) | Root cause |
| --- | --- |
| "only fleeing, never chasing" | Folds out of the next two — once the shooter pursues out of range AND fires-when-cornered, the only-flee shape disappears. |
| "shoots from distance not able to reach the player" | Close-the-gap threshold was AIM_RANGE (300 px). For a player at dist 150–300, the shooter stood still firing projectiles whose 144 px reach fell 6–156 px short. **Sweet spot must equal projectile reach.** |
| "if back into a corner, doesnt attack when user is too close" | `_process_kiting` had no exit when the shooter was wall-blocked AND the player was still inside KITE_RANGE. `move_and_slide` produced zero net motion against a wall; STATE_KITING stayed forever. |

**The fix shape (ticket 86c9uehaq):**

1. **Introduce `SHOOT_RANGE = PROJECTILE_SPEED * PROJECTILE_LIFETIME`** (derived, not hard-coded — auto-tracks projectile tunings). Use SHOOT_RANGE as the close-the-gap threshold in `_process_aiming` and `_process_post_fire`; retain AIM_RANGE as the outer aggro band (post-fire recovery drops to IDLE beyond it). Sweet spot tightens from `120..300` to `120..144`.
2. **Cornered-kite fallback.** Two consecutive `is_on_wall()` ticks while the player is inside KITE_RANGE promote KITING → AIMING via `_promote_cornered_to_aiming` with a fast windup (`CORNERED_AIM_DURATION = 0.25 s` vs the normal `AIM_DURATION = 0.55 s`). Extracted as a helper so unit tests can pin the promotion payload (state, aim_left, velocity, telegraph emit) without simulating a CharacterBody2D wall collision in headless GUT.
3. **Diagnostic instrumentation:** every `_set_state` transition emits a `[combat-trace] Shooter._set_state | old -> new dist=N pos=(x,y)` line (HTML5-only via the existing combat_trace shim). Lets soak runs characterise the AI state at every transition, not just the throttled 0.25 s `Shooter.pos` pulse.

**Sweet-spot derivation rule (load-bearing):** any future tune to `PROJECTILE_SPEED` or `PROJECTILE_LIFETIME` automatically updates `SHOOT_RANGE`. The drift-detector test `tests/test_shooter_repositions_on_idle_player.gd::test_shoot_range_equals_projectile_reach` catches a hard-coded SHOOT_RANGE divergence. The corollary invariant — `SHOOT_RANGE > KITE_RANGE` so a non-empty sweet spot exists, and `SHOOT_RANGE < AIM_RANGE` so a non-empty close-the-gap region exists — is also pinned.

**Cornered constants discipline:** `CORNERED_KITE_TICKS_TO_FIRE = 2` (≈33 ms at 60 Hz) so the fallback fires within a single visible frame of the player cornering the kiter; `CORNERED_AIM_DURATION = 0.25 s` so the windup is shorter than normal AIM_DURATION but non-zero (a zero-windup point-blank fire is unfair). Tune-drift pinned by `test_shooter_cornered_constants_are_balanced`.

**Harness contract preserved:** the `Shooter.pos` trace shape (`pos=(x,y) state=... dist_to_player=...`) is unchanged. The Playwright `kiting-mob-chase` fixture still steers off it. The new bands DO mean a chase that previously had to roam (kiter stationary at dist 200) now sees the kiter converge toward the player — making the chase typically faster and cleaner.

**Pattern check for any future ranged-mob class:** the band-vs-reach invariant generalises. If a future mob's projectile reach is `R`, its sweet spot must be `(0, R]` (with whatever lower bound for kiting); its close-the-gap threshold must be `R`. Using a separate "aggro range" constant for both bands AND pursuit is the failure shape — the conflation is what bit Room 04.

## `[combat-trace]` diagnostic shim

[`scripts/debug/DebugFlags.gd`](scripts/debug/DebugFlags.gd) — `DebugFlags.combat_trace(tag, msg)` emits `[combat-trace]` console lines only when `OS.has_feature("web") == true`. Wired into:

- `Player.try_attack / swing_wedge / swing_flash`
- `Hitbox.hit`
- Per-mob `take_damage`, `_play_hit_flash`, `_die`, `_play_death_tween`, `_on_death_tween_finished`, `_force_queue_free`. **All five mob types emit `<Mob>._die` uniformly** (`Grunt._die`, `Charger._die`, `Shooter._die`, `PracticeDummy._die`, plus `Stratum1Boss`) — ticket `86c9tuh57` closed a gap where `Charger._die` / `Shooter._die` emitted `_force_queue_free | freeing now` but no `_die` line, breaking harness kill-counting + Sponsor-soak greps that count kills uniformly on the `<Mob>._die` trace. The line shape is `[combat-trace] <Mob>._die | starting death sequence`, emitted immediately after the `_is_dead = true` idempotency latch. **All mob types also emit `<Mob>.take_damage` uniformly** — `Grunt.take_damage` / `PracticeDummy.take_damage` / `Stratum1Boss.take_damage` carried the `amount=<N> hp=<before>-><after>` line from the start; ticket `86c9u2383` closed the sibling gap where `Charger.take_damage` / `Shooter.take_damage` emitted no line, making console-based hit verification non-uniform. The line shape is `[combat-trace] <Mob>.take_damage | amount=<N> hp=<before>-><after>`, emitted immediately after `hp_current` is decremented and before `damaged.emit`. For `Charger`, `amount` is the post-multiplier `final_amount` actually subtracted (armored 1x / recovery 2x), not the raw incoming `amount` — it mirrors what HP changed by. **The `_is_dead` early-return rejection path is also traced uniformly** — `Grunt` / `Charger` / `Shooter` each emit `[combat-trace] <Mob>.take_damage | IGNORED already_dead amount=<N>` on the dead-mob guard (ticket `86c9u2v7k` closed the gap where `Charger` / `Shooter` early-returned silently while `Grunt` already emitted the rejection line). This lets Sponsor-soak console greps tell a hit that landed on a corpse apart from a hit that never registered at the physics layer — the same Case-A-vs-Case-B diagnostic value as `Stratum1Boss`'s three-case rejection trace below.
- `Inventory.equip` (P0 86c9q96m8 + tickets 86c9qah0v / 86c9qbb3k) — `[combat-trace] Inventory.equip | item=<id> slot=<weapon|armor> source=lmb_click|auto_pickup damage_after=<N>` fires on every successful `equip()` call. `source` is a `StringName` enum: `lmb_click` (default) tags user-driven equips via `InventoryPanel._handle_inventory_click`; `auto_pickup` tags the system-driven auto-equip-first-weapon-on-pickup onboarding path via `Inventory.on_pickup_collected` (see "Onboarding: auto-equip-first-weapon-on-pickup"). `auto_starter` is a **deprecated tag with no current producer** — it was the PR #146 boot-equip bandaid's tag, retired in ticket `86c9qbb3k`; `equip()` still accepts it (no `source` whitelist) but nothing emits it. `restore_from_save` bypasses `equip()` entirely — so save-restore (F5 reload, save-load) does NOT fire this line at all. Future system-driven equip paths must add their own `source` tag rather than overloading `lmb_click`. The `damage_after` field reads from `Damage.compute_player_damage(Player.get_equipped_weapon(), Player.get_edge(), &"light")` — proves both Inventory and Player surfaces stayed in lockstep at the moment of equip.
- `TutorialEventBus.request_beat` (ticket `86c9qbmer`) — `[combat-trace] TutorialEventBus.request_beat | beat=<beat_id> anchor=<n>` fires at the top of every `request_beat()` call (before `tutorial_beat_requested.emit`). In Stage 2b (PR #169) the four beats fire in this order during Room01: `wasd` (room-entry deferred wire, player-independent) → `dodge` (player velocity > MOVEMENT_THRESHOLD_SQ) → `lmb_strike` (Player.iframes_started on dodge roll) → `rmb_heavy` (PracticeDummy.mob_died on dummy death). The trace is a no-op in headless GUT (not `OS.has_feature("web")`); `tests/playwright/specs/tutorial-beat-trace.spec.ts` is the binding HTML5 coverage.

`Stratum1Boss.take_damage` distinguishes the three rejection cases explicitly (M2 W1 P0 fix `86c9q96fv`): `IGNORED already_dead`, `IGNORED dormant ... (boss still in entry sequence)`, `IGNORED phase_transition ... (stagger-immune window)`. The `dormant` case is the load-bearing diagnostic — it's how Sponsor-soak debugging tells "hit didn't register at the physics layer" (Hitbox layer/mask issue) apart from "hit was rejected at the controller" (boss never woke up). Format on a successful hit: `Stratum1Boss.take_damage | amount=6 hp=600->594 phase=1`.

Sponsor's HTML5 soak surfaces these lines in DevTools console (F12 → Console). Trace-driven debugging is the load-bearing surface for combat regressions because most physics-flush bugs don't raise GDScript exceptions — Godot's `USER ERROR` macros log + return-early in C++. Tier 2 testing bar consequence (per PR #138 + `team/TESTING_BAR.md`): tests must assert downstream consequences (HP changes, queue_free reached, monitoring state per swing), not just method-was-called.

## Physics-flush rule (load-bearing)

In Godot 4, mutating an Area2D's monitoring state — including `add_child` of an Area2D-derived node, `set_monitoring`, `set_collision_layer/mask`, `disabled = true` on a CollisionShape2D — from inside a `body_entered` / `area_entered` callback (or any signal-handler chain rooted in a physics callback) panics with:

```
USER ERROR: Can't change this state while flushing queries.
Use call_deferred() or set_deferred() to change monitoring state instead.
```

Sustained spam of physics-tick spawn sites can also surface the panic when one spawn lands inside another's flush window. **Two M1 RC P0s** were caught from this — PR #142 (death-path: `MobLootSpawner` Pickup add) and PR #143 (spawn-path: Hitbox / Projectile monitoring activation).

**The rule is NOT Area2D-only — it covers `CollisionShape2D`-on-`PhysicsBody2D` adds too.** Splicing *any* node that owns a `CollisionShape2D` into the live tree mid-flush registers that shape with the physics server, and the server's per-shape state pushes — `body_set_shape_disabled` (`godot_physics_server_2d.cpp:654`) and `body_set_shape_as_one_way_collision` (`cpp:663`) — panic with the *same* "Can't change this state while flushing queries" message even though no `Area2D` and no `monitoring` flag is involved. A `CharacterBody2D` mob with a baked-in `CollisionShape2D` child entering the tree during a flush hits this. When the panic fires, the C++ early-returns and the shape is left **unregistered with the server**: the node renders + `_physics_process`-ticks normally, but it has *no physics-collision presence* — `Area2D.get_overlapping_bodies()` / `body_entered` never see it.

This was the **Room 05 3-concurrent-chaser freeze (ticket 86c9u1cx1, PR for branch `drew/room05-chaser-freeze`)**. `RoomGate.gate_traversed` is emitted from `RoomGate._on_body_entered` — a `body_entered` physics callback running synchronously inside `flush_queries()`. `MultiMobRoom` connected `_on_room_gate_traversed` with a **synchronous** connection, so the whole next-room load chain — `gate_traversed → MultiMobRoom._on_room_gate_traversed → room_cleared → Main._on_room_cleared → _load_room_at_index → _world.add_child(next_room) + next_room.add_child(_player)` — ran *inside* that flush window. The next room's `MultiMobRoom._build()` does `add_child(_assembly.root)`, splicing 3 mob `CharacterBody2D`+`CollisionShape2D` subtrees into the physics server mid-flush → `body_set_shape_*` panic → mob shapes unregistered → mobs un-hittable (player swings produced zero `Hitbox.hit` against them) → no mob died → RoomGate never unlocked → Room 05 unbeatable. (PR #183 had deferred the *RoomGate* Area2D fixture pass — but the deeper problem was that the entire room-load chain ran in the flush, not just the gate spawn.)

**The fix:** connect `RoomGate.gate_traversed` → `MultiMobRoom._on_room_gate_traversed` with `CONNECT_DEFERRED`. The entire downstream next-room load chain then runs at end-of-frame, **outside** `flush_queries()`, so every body/shape splice in the load (`_build`'s `add_child(_assembly.root)`, the player re-parent, the gate spawn) lands on a clean tick. `MultiMobRoom._build()` stays synchronous (the `get_spawned_mobs()` / `get_bounds_px()` / perimeter-wall contract that `Main._wire_room_signals` + `test_room_boundary_walls.gd` depend on) — it is flush-safe *because* the load chain that invokes `_ready` is now deferred.

The fix patterns:

1. **Receiver-side encapsulation (preferred for Area2D)** — make the Area2D-derived class's `_init` set monitoring off, re-enable in `_ready()` (Godot defers `_ready` automatically). All spawn sites get auto-protected.
2. **`CONNECT_DEFERRED` on the flush-rooted signal** — when a signal emitted inside `flush_queries()` (`body_entered`, `area_entered`, or any handler chain rooted in one — `RoomGate.gate_traversed`, `mob_died`) drives a handler that does physics-state mutations (body/shape/Area2D adds, monitoring toggles), connect that handler with `CONNECT_DEFERRED` so the *whole handler chain* runs at end-of-frame, outside the flush. This is the highest-leverage fix when the unsafe work is deep in a call chain — it moves the entire chain out at once. Precedents: `RoomGate.register_mob`'s `mob_died` connection (PR #173) and `MultiMobRoom`'s `gate_traversed` connection (ticket 86c9u1cx1).
3. **Caller-side defer** — `parent.call_deferred("add_child", child)` at the spawn site. Use for an isolated add that you can't route through a deferred signal.

**Pattern check for room-lifecycle code:** any room-load path rooted in a `body_entered` chain (`Main._load_room_at_index` is the canonical one — it runs from the prior room's gate traversal) must have that chain **deferred out of the flush** — either the room-lifecycle signal is `CONNECT_DEFERRED` (the `gate_traversed` fix) or the load call itself is `call_deferred`. `Stratum1Room01._build()` has the same synchronous-`add_child` shape, and the player-death reload path (`Player._die` from a Hitbox `body_entered` → `player_died` → `Main` reload) was the suspected route that would push Room 01's `_build()` through a flush — but that path was audited and **disproved**: see "`Stratum1Room01._build()` death-reload path — audited SAFE (ticket `86c9u2392`)" below for the verdict (`Main._on_player_died` does `call_deferred("apply_death_rule")`, so the reload chain runs outside `flush_queries()`).

Future bugs in this family: check the `_die` chain (death-path adds), all per-tick spawn sites (spawn-path adds), and any new Area2D class that's instantiated outside `_ready` of the parent scene. Memory rule: `godot-physics-flush-area2d-rule.md`.

**`Stratum1Room01._build()` death-reload path — audited SAFE (ticket `86c9u2392`).** PR #191's follow-up flagged a suspected latent instance: `Stratum1Room01._build()` runs synchronously from `_ready()` and splices mob `CharacterBody2D`+`CollisionShape2D` subtrees into the live tree via `add_child(_assembly.root)` — the same unsafe shape the `MultiMobRoom` fix addressed. The concern was the **player-death reload path**: `Player.take_damage` (from an enemy Hitbox `body_entered`, inside a physics flush) → `Player._die` → `player_died.emit` → `Main._on_player_died` → `apply_death_rule` → `_load_room_at_index(0)` → `Stratum1Room01._ready` → `_build()`. The trace audit **disproved the threat**: `Main._on_player_died` (`scenes/Main.gd`) does `call_deferred("apply_death_rule")` — the entire reload chain (`apply_death_rule` → `_load_room_at_index(0)` → `Stratum1Room01._ready` → `_build()`) runs at end-of-frame, **outside** `flush_queries()`. The `player_died` signal connection itself is synchronous (`scenes/Main.gd` `_spawn_player`), but the handler immediately defers, so the splice never lands inside the flush. Every other path that reaches `_load_room_at_index(0)` is also flush-safe: `Main._ready` boot (no flush), `load_room_index()` (test-only), and `_on_descend_restart_run` (driven by the `DescendScreen.restart_run` UI-button signal, not a physics callback). `Stratum1Room01` also owns **no Area2D fixtures of its own** (no `RoomGate`, no `HealingFountain`) — `_build()` only adds mob bodies — so even a hypothetical future flush-rooted entry would be the milder `CollisionShape2D`-on-`CharacterBody2D` class, not Area2D-monitoring. **No code change required**; the death-reload deferral in `_on_player_died` is the load-bearing guard and must be preserved — if a future refactor makes `_on_player_died` call `apply_death_rule` synchronously, the Room 01 mob-freeze becomes reachable.

## Engine.time_scale interactions — harness assumption-vs-game-clock rule (load-bearing for Playwright)

**Distinct from the physics-flush class, but the same shape — "game state visible to the engine drifts away from harness assumptions."** Whereas the physics-flush family is about Area2D / shape mutations from inside `flush_queries()`, this class is about **wall-clock vs game-clock divergence under `Engine.time_scale != 1.0`**.

**The pattern:** Godot's `Timer` nodes and tween animations accumulate scaled delta (game-time, not wall-time). Setting `Engine.time_scale = 0.10` makes every `Timer.start(0.65)` take 6.5 s of wall-clock. The game state machines remain correct — they just run 10× slower. Playwright wall-clock-based assertions (e.g. `GATE_SETTLE_WINDOW_MS = 2500`, fixed `keyboard.down("a"); waitForTimeout(2500)`) silently break when this happens.

**The Embergrave time-slow sources:**
- `InventoryPanel.open()` sets `Engine.time_scale = 0.10` on Tab-open, restores on close (`scripts/ui/InventoryPanel.gd` lines 169-170, 181).
- `StatAllocationPanel.open()` sets `Engine.time_scale = 0.10` on level-up auto-open + restores on close (`scripts/ui/StatAllocationPanel.gd` lines 138-139, 152). **Auto-opens on the first ever `Levels.level_up`** (LU-05 in `team/uma-ux/level-up-panel.md`) — the player crosses L1→L2 at 100 XP, which the current XP economy puts squarely in Room 05 of the AC4 boss-clear path.

**The Room 05 incident (ticket 86c9u6uhg, 2026-05-15 Drew investigation):** PR #206's iframes-on-hit balance pass made the player survive Room 05 deterministically (8/8 runs, mean clear 9.97 s). The harness expected the gate to unlock within `GATE_SETTLE_WINDOW_MS = 2500 ms` post mob-clear — `RoomGate._start_death_wait` arms a 0.65 s Timer, so the deadline holds at `time_scale = 1.0`. But the third Room 05 mob death is precisely the L1→L2 XP boundary (10 + 18 + 38 = 100 XP), so `StatAllocationPanel` auto-opens mid-Room-05 and pins `time_scale = 0.10`. The 0.65 s gate-unlock then takes 6.5 s wall (well past the 2.5 s settle), the helper reports `gateUnlocked=false`, and every subsequent `gateTraversalWalk` key-down at fixed wall-ms covers 10× less ground in game space. The harness has no concept of "allocate a stat point" so the panel stays open for the rest of the test — `gateUnlocked=false, gateTraversed=false` was deterministic across 8 release-build runs.

**The dispatch's diagnosis was incorrect** — the gate's state machine + `_on_mob_died` decrement chain + Timer arming all work fine; the gate state machine is correct under any `time_scale`. The bug is the harness's wall-clock-based settle assumption colliding with the game's auto-opened slow-mo panel.

**The fix shape (harness-side):** the multi-chaser helper, the kiting Shooter chase helper, AND the AC4 spec's fixed-position chaser loop **press Escape 4× after the kill loop exits**. `KEY_ESCAPE` is handled by `StatAllocationPanel._unhandled_input` and closes the panel (banking any unspent points). When no panel is open it's a no-op. This is applied in all three post-clear sites for defensive coverage of any current or future room that might auto-open a panel during combat. See `tests/playwright/fixtures/kiting-mob-chase.ts` `chaseAndClearMultiChaserRoom` and `chaseAndClearKitingMobs`, plus `tests/playwright/specs/ac4-boss-clear.spec.ts` `clearRoomMobs`.

**Why not a game-side fix:** the alternative — making the `RoomGate` death-wait Timer time-scale-independent (`SceneTree.create_timer(secs, false, false, true)` with `ignore_time_scale = true`) — would fix the gate-decrement clock under time-slow, but **not** the subsequent `gateTraversalWalk` Player movement that ALSO runs at 10× wall-clock under the slow-mo. Even if the gate unlocked on time, the player walking at `WALK_SPEED * 0.10` covers ~30 px instead of ~300 px in a 2500 ms key-down — never reaching the trigger. The harness-side fix dismisses the panel and restores `time_scale = 1.0` for both the gate AND the movement. **Game-side time-scale-decoupled Timers are still the right defensive move for any future state-machine that should NOT pause during stat-allocation slow-mo** (e.g. a real-time hazard that should keep ticking while the panel is open) — but RoomGate's death-wait is conceptually the visual "door opens after death animation," which SHOULD slow with the animation, so leaving it engine-time is correct.

**Pattern check for new harness specs:** any spec that drives the player past the L1→L2 XP threshold (100 XP) without explicit panel dismissal will hit this. M3+ specs that drive late-game level-ups will hit the L2→L3 (282 XP), L3→L4 (519 XP), etc. boundaries identically. **The Escape-press idiom from this fix should generalise to every post-clear seam in the harness.** If the AC4 XP economy is rebalanced, the Room boundary where this surfaces will shift but the bug class remains.

**Regression pin (game-side, defensive):** `tests/test_room_gate.gd::test_3mob_concurrent_death_with_death_wait_unlocks` — pins that the gate unlocks correctly when 3 mobs die concurrently AND `test_skip_death_wait = false` (i.e. the production death-wait Timer path runs). This wasn't the actual failure mode of ticket 86c9u6uhg, but the dispatch asked for a 3-mob-concurrent-death regression pin and this is it; future "did Drew break the gate?" investigations have a fast game-side answer ahead of any release-build characterisation.

## CharacterBody2D motion_mode rule (load-bearing for top-down 2D)

Godot 4 `CharacterBody2D` defaults to `motion_mode = MOTION_MODE_GROUNDED` with `up_direction = Vector2.UP = (0, -1)`. `move_and_slide()` in GROUNDED mode treats collisions whose normal aligns with `up_direction` as **floor** and applies floor-snap / floor-stop semantics — including suppressing post-collision velocity along the +up axis. **In a top-down 2D game with no floor / gravity / jump concept, this introduces a directional asymmetry that bites only along one axis.**

**Symptom (M1 RC re-soak 5, ticket `86c9q96jv`):** Stratum1Boss separated cleanly from the player on north / east / west melee-contact approaches but stuck on south approaches. Pushback velocity computed identically in all four cases — north-axis pushback was being silently dropped by the GROUNDED-mode floor branch because the player-from-south collision normal aligned with `up_direction`.

**Why the boss surfaced this and not Grunt:** the bug is universal to every CharacterBody2D in the project (no scene overrides motion_mode), but only manifests as visible "sticking" when the post-contact pushback can't out-run the player. Boss has CircleShape2D radius 24 px → player overlap depth up to 34 px from boss center, plenty of duration for the floor branch to suppress the 60 px/s pushback against the 120 px/s player walk. Grunt's radius is 12 px → 22 px overlap depth, smaller window for the asymmetry to show. PR #150's swing-fire pushback was correct on every axis; the bug was downstream in `move_and_slide()`'s axis-asymmetric resolution, not in the velocity computation.

**The fix (`Stratum1Boss._apply_motion_mode`):** call `motion_mode = CharacterBody2D.MOTION_MODE_FLOATING` from `_ready()`. FLOATING resolves all axes equally — no floor concept, no `up_direction` privilege. This is the canonical Godot 4 top-down 2D pattern and should be the default for every CharacterBody2D in this project.

**Generalization:** any new CharacterBody2D added to the project (mob, NPC, breakable, projectile-as-body) MUST set `motion_mode = MOTION_MODE_FLOATING` either in its scene file or via a `_apply_motion_mode()` helper called from `_ready()`. **Pattern check:** if you ever observe direction-asymmetric collision separation (works on three axes, fails on one — typically the +up or -up axis), suspect this rule first.

**M2 W1 generalization closure (ticket `86c9qanu1`):** the FLOATING fix shipped to all melee-engaging mob types — Stratum1Boss (PR #163), then Grunt + Charger (this PR). Shooter is exempt by design: it has no rooted-recovery state and no POST_CONTACT_PUSHBACK, its KITING / AIMING handlers reset velocity each tick, so the GROUNDED-mode floor branch has nothing to suppress. The `_apply_motion_mode()` helper is the canonical implementation surface; new CharacterBody2Ds added in M2+ should mirror it.

**Test bar consequence:** any "mob does not stick to player" regression test must cover **all four cardinal approach directions** (N / E / S / W). Single-axis tests miss the GROUNDED-mode floor-asymmetry surface. See `tests/integration/test_boss_does_not_stick_after_contact.gd::test_boss_separates_from_player_approached_from_*`.

## Equipped-weapon dual-surface rule (load-bearing)

Equipped weapon state lives on **two surfaces** that must stay in lockstep:

- `Inventory._equipped["weapon"]` — autoload-side; truth surface for the Tab UI (`InventoryPanel._refresh_equipped_row` reads it). The Stats panel BBCode (`InventoryPanel._refresh_stats` Damage / Defense lines, codified in M2 W1 polish) ALSO reads this surface via `_build_damage_line` / `_build_defense_line` — `Inventory.get_equipped(&"weapon").def.base_stats.damage`. **Panel-reads-Inventory** is the contract; combat-reads-Player is the other half. Don't conflate them — a panel that read `Player._equipped_weapon` would mask exactly the dual-surface drift that this rule exists to surface.
- `Player._equipped_weapon` — per-instance; truth surface for combat (`Player.try_attack` reads it; passed to `Damage.compute_player_damage`)

Linking is normally automatic: `Inventory.equip()` → `_apply_equip_to_player()` → `Player.equip_item()`. Any code path that bypasses `Inventory.equip` and mutates one surface without the other will produce a silent divergence — one surface is correct, the other is null. Symptom: combat reads `damage = 1` (FIST_DAMAGE) while Tab UI also reads empty (or vice versa).

**Three failure modes in this family bit M1 RC** (PR #145 → PR #146 → P0 86c9q96m8):

1. **Boot-order clobber.** `Save` autoload's `restore_from_save()` reset loop unconditionally calls `_apply_unequip_to_player(slot)` for every key in the equipped map, even on an empty save. Any code that pre-populates equipment MUST run AFTER `_load_save_or_defaults()` in `Main._ready()`. The `Inventory` autoload's `_ready()` print can fire before save-restore wipes it — boot prints are not proof of post-boot state. (This was the PR #146 `equip_starter_weapon_if_needed` bandaid's failure mode; the bandaid is now retired — see "Onboarding: auto-equip-first-weapon-on-pickup" below.)
2. **Stub-Node test silently skips Player surface.** `_apply_equip_to_player(target)` checks `target.has_method("equip_item")` and silently skips when false. A stub `Node.new()` test target returns false — the Player-side wiring path is never exercised. Inventory state assertions pass; the integration is silently broken in production.
3. **Equip-via-LMB-click swap leaks the previously-equipped item.** Pre-fix `Inventory.equip()` called `_unequip_internal(slot, push_back_to_inventory=false)` when a different item was already in the slot — silently discarding the previous weapon (Sponsor M1 RC re-soak attempt 5: pickup new sword + LMB-click → "item disappears, can't re-equip"). Fix: erase the new item from `_items` FIRST so the grid has a free slot, then call `_unequip_internal(slot, true)` to push the previously-equipped item back into the grid. Order matters because a 24/24 grid would otherwise refuse the push-back. **Combat-trace shim** (P0 86c9q96m8 + tickets 86c9qah0v / 86c9qbb3k): `Inventory.equip(item, slot, source = &"lmb_click")` emits `[combat-trace] Inventory.equip | item=<id> slot=<weapon|armor> source=<tag> damage_after=<N>` on every successful equip. The optional `source` parameter (default `&"lmb_click"`) tags the trace so the Playwright negative-assertion sweep can tell user-clicks from system-equips apart. **Scoping rule:** the trace fires ONLY through `equip()`. `lmb_click` = user-driven via `InventoryPanel._handle_inventory_click`; `auto_pickup` = system-driven via `Inventory.on_pickup_collected` (the auto-equip-first-weapon-on-pickup onboarding path); **no trace** = `restore_from_save` (F5 reload, save-load) which bypasses `equip()` and directly mutates `_equipped[slot] = inst` + calls `_apply_equip_to_player(inst)`. The Playwright `equip-flow.spec.ts` asserts the positives (`source=auto_pickup` when the player walks onto the dummy-dropped iron_sword, `source=lmb_click` after a real Tab→click) and the negatives (no `Inventory.equip` line of any source at cold boot before any pickup; no `lmb_click`/`auto_starter` after F5 reload).

> **Deprecated source tag — `auto_starter` (no current producer).** `auto_starter` was the source tag for the PR #146 boot-equip bandaid (`Inventory.equip_starter_weapon_if_needed`, called from `Main._ready` after `_load_save_or_defaults`). Ticket `86c9qbb3k` **retired that bandaid** — both `equip_starter_weapon_if_needed` and `Inventory._seed_starting_inventory` are deleted, and `Main._ready` no longer auto-equips anything. `equip()` has no `match`/branch on `source`, so the `auto_starter` `StringName` still type-checks as a valid input — it simply has **no producer** in the codebase any more. The tag is kept documented (not deleted) so a future re-introduction of a boot-time equip path has a named slot, and `tests/test_inventory_equip_source_enum.gd` pins that `equip(item, slot, &"auto_starter")` is still *accepted* (it would only break if someone added a `source` whitelist). Do not wire anything new to `auto_starter` — add a fresh tag instead.

## Onboarding: auto-equip-first-weapon-on-pickup (ticket 86c9qbb3k)

The player **boots fistless by design** — there is no boot-time starter-weapon seed or auto-equip (the PR #146 bandaid above is retired). The design-correct onboarding path is **auto-equip the first weapon the moment it is picked up**:

- `Inventory.on_pickup_collected(item)` (the `Pickup.picked_up` hook) does `add(item)`, then — **if the item is a weapon AND the weapon slot is empty** — immediately `equip(item, SLOT_WEAPON, &"auto_pickup")`. **First-weapon-only:** if a weapon is already equipped, a subsequently-collected weapon just lands in the grid; it does NOT auto-swap. Mid-run swaps stay user-driven (Tab → LMB-click).
- The Stage-2b Room01 `PracticeDummy` drops a guaranteed `iron_sword` Pickup on death. The dummy bypasses `MobLootSpawner` (its `mob_died` carries `mob_def == null`), so `Main._on_mob_died`'s `auto_collect_pickups` path never sees it — `PracticeDummy._spawn_iron_sword_pickup` therefore wires the Pickup's `picked_up` signal to `Inventory.on_pickup_collected` itself. Walk onto the drop → iron_sword auto-equips → `source=auto_pickup` trace fires.
- **`Pickup` initial-overlap check (load-bearing).** `Area2D.body_entered` only fires on the non-overlap → overlap *transition*. The dummy drops its Pickup at its own death position — the player is often standing on that exact tile from the killing blow, so `body_entered` would never fire and the Pickup could never be collected. `Pickup` now follows the encapsulated-monitoring pattern (`_init` monitoring-off → `_ready → call_deferred("_activate_and_check_initial_overlap")`): the deferred pass re-enables monitoring AND walks `get_overlapping_bodies()` to collect against a player already inside. Exact fix shape as `Hitbox._activate_and_check_initial_overlaps` (PR #143). An idempotency latch (`Pickup._collected`) prevents an initial-overlap collect + a later `body_entered` from double-emitting `picked_up`.
- **Room01 → Room02 advance gate (`Main._on_room01_mob_died`).** Because `_on_room_cleared → _load_room_at_index` `queue_free`s Room01 (and the Pickup with it) on the very next frame, an immediate advance on dummy death would destroy the drop before the player could reach it. So when the Room01 dummy dies **and the player is not yet equipped**, Main arms `_room01_awaiting_pickup_equip` and connects to `Inventory.item_equipped` instead of advancing; `_on_weapon_equipped` releases the gate (one-shot, disconnects immediately) and fires the deferred `_on_room_cleared` once the weapon slot is filled. **If the player is ALREADY equipped when the dummy dies** — a save-restored weapon, or a post-death respawn that preserved equipped state per the M1 death rule — the gate is skipped and Room01 advances immediately, exactly as before. `_load_room_at_index` defensively calls `_clear_room01_pickup_gate()` so the `item_equipped` connection never leaks across rooms.

**State-integration test bar** (analog of the visual-primitive test bar in `team/TESTING_BAR.md`):

- Tier 1 (mandatory): paired tests for equip / unequip / equip-swap / auto-equip-on-pickup paths must instantiate a **real `Player`** node, not a stub `Node`. Assert `Player.get_equipped_weapon() != null` AND `Inventory.get_equipped("weapon") != null` — one surface passing is not proof the other is wired. See `tests/test_inventory.gd::test_equip_swap_*`, `tests/test_inventory_panel.gd::test_lmb_click_equip_swap_drives_both_surfaces`, and `tests/test_starting_inventory.gd::test_pickup_auto_equip_drives_both_surfaces`.
- Tier 2 (mandatory for boot-order changes): integration test must drive the **actual `Main._ready` boot sequence** and assert the post-boot state survives. Since the boot-equip bandaid is retired, the boot-order surface to verify is now `_spawn_player → _load_save_or_defaults` (a save-restored weapon must survive) and the onboarding surface is `Inventory.on_pickup_collected → equip(&"auto_pickup")` driven from the dummy-drop Pickup. A test that calls `Inventory.equip` directly bypasses both. See `tests/integration/test_starter_weapon_damage_integration.gd` (boots `Main.tscn`, asserts fistless-at-boot + pickup-equip + save-restore-equip) and `tests/integration/test_stage_2b_tutorial_traversal.gd` (walks the player onto the dropped Pickup through the real Area2D overlap).
- Tier 3 (mandatory for damage-affecting changes): integration test must drive the **actual `Player.try_attack`** code path and assert the **damage delta on a real Grunt** (`grunt.hp` drops by weapon-scaled amount, not by 1). Not `Damage.compute_player_damage()` in isolation. See `tests/integration/test_starter_weapon_damage_integration.gd::test_lmb_click_equip_swap_real_main_drives_dual_surfaces` for the equip-swap variant.

This is the integration class of `team/TESTING_BAR.md` § "Product completeness ≠ component completeness." The Main.tscn-stub miss and PR #145's stub-Node miss are siblings.

## State-change signals vs. progression triggers — harness enforcement

The combat / level pattern surfaced by PR #155: a signal named `<noun>_<state-verb>` (e.g. `gate_unlocked`, `door_opened`) DOCUMENTS a state change. It MUST NOT be wired directly to a progression trigger (room counter advance, level transition). Progression must be gated on an explicit player-action event (CharacterBody2D `body_entered` on a trigger Area2D, an interact-press, etc.).

**The Playwright harness enforces this discipline at HTML5-build sign-off.** See `tests/playwright/specs/negative-assertion-sweep.spec.ts` (Test 3 — `gate_traversed never precedes gate_unlocked (causality invariant)` + same-tick auto-emission threshold check) and `tests/playwright/specs/ac4-boss-clear.spec.ts` (per-room gate-traversal negative assertions across all 7 multi-mob rooms). The static causality invariant — every `gate_traversed` line in the `[combat-trace]` stream must have a preceding `gate_unlocked emitting` line, with > 200 ms between them — catches PR #155-class regressions automatically.

**Open follow-up:** the Shooter `STATE_POST_FIRE_RECOVERY` state has no explicit ledger trace today (only `_process_post_fire | closing gap` recurrence). Adding `[combat-trace] Shooter.set_state | post_fire_recovery (entered)` is the prerequisite for adding a fourth negative-assertion test that asserts the recovery-state trace fires when expected (not "absence of state X means Y" — the anti-pattern this rule targets).

Future state-change/action-event pairs (aggro/attack, pickup/equip, dialog/advance, save/load) should land their `[combat-trace]` lines AND their negative-assertion test simultaneously. When introducing any `<noun>_<state-verb>` signal, ask: "is there a separate `<noun>_<action-verb>` event that commits to the next thing?" If yes, add both traces and an assertion for both.

### Negative-assertion buffer-scoping rule (PR #180 lesson)

**Root cause.** `tests/playwright/specs/negative-assertion-sweep.spec.ts` Test 2 asserted zero `RoomGate.*` console traces for Room01 by scanning the **entire unbounded console buffer** collected since the spec started. PR #174's Stage 2b roster-swap introduced a `clearRoom01Dummy` 8-direction aim sweep that runs past `PracticeDummy._die`; that death triggers room-advance to Room02, whose `RoomGate.register_mob` calls land in the same buffer. The spec mis-attributed Room02 traces as Room01 violations and failed (RED on main).

**Fix.** Scope the negative assertion to the sub-buffer captured **strictly before** the first `PracticeDummy._die` trace:

```typescript
const dieIndex = consoleLines.findIndex(l => /PracticeDummy\._die/.test(l));
const room01Window = dieIndex === -1 ? consoleLines : consoleLines.slice(0, dieIndex);
expect(room01Window.filter(l => /RoomGate/.test(l))).toHaveLength(0);
```

This is the canonical fix for any negative assertion whose truth window can be contaminated by a later phase of the same spec.

**Generalised rule — negative-assertion buffer discipline:**
1. **Anchor to a causal boundary.** Every negative assertion over a console buffer must define its truth window by finding a sentinel event (the first die-trace, the first room-transition trace, the first state-change line) and slicing to that boundary. An unbounded buffer scan is always wrong for multi-phase specs.
2. **Parallel-phase contamination is the failure mode.** Any spec phase that advances beyond the state the negative assertion guards will push traces into the shared buffer. Stage-gating with `dieIndex`-style slices is the fix pattern.
3. **New negative-assertion tests must declare their window.** Comment the sentinel expression explicitly — `// truth window: lines before first PracticeDummy._die` — so reviewers can verify the scope is correct without tracing the full spec flow.

**Stale docstring pointer note.** The `[combat-trace]` reference in `Main.gd:381` (a `push_error` call) is NOT the documentation site for the no-`RoomGate`-in-Room01 rule. The real annotation lives in `scenes/Main.gd::_wire_room_signals` (~lines 406, 461). If you are hunting for why Room01 is expected to emit zero `RoomGate.*` traces, read `_wire_room_signals`, not line 381.

## Save autoload signal contract (added M2 W1)

`Save.save_completed(slot: int, ok: bool)` (declared at `scripts/save/Save.gd`) is the project's first **global save-event signal** — emitted from every successful AND failed `save_game()` call on every entry point (autosave: `room_cleared`, `stratum_exit_unlocked`, quit; interactive: `StatAllocationPanel` allocation). Past-participle naming matches Inventory's `item_equipped` / `item_unequipped`.

**Subscriber contract:**
- M1 visible-state UI (e.g. `SaveToast` in `scripts/ui/SaveToast.gd`) connects from boot. The toast widget reacts to `ok=true` only; M1 surfaces failure via the existing `push_error` console line (no recovery-action UI for failure yet).
- Future M2+ patterns this opens: audio cue on save (one-shot SFX hook), persistent "saved 3s ago" indicator (poll `save_completed` timestamp), failure-recovery toast variant (`ok=false` branch).
- The signal fires unconditionally at every `save_game()` exit — listeners must handle the `ok=false` branch defensively (return early, do not assume `true`).

**Naming + scope discipline:** `save_completed` is past-participle, fires once per save attempt, carries `(slot, ok)` payload. Don't add a `save_started` event unless a use case appears that needs the "save in flight" interval (no current need; saves are single-frame). Keep the signal narrow.

### `ContentRegistry.items_resolved` — the second autoload-ready signal (added M2 W2, ticket 86c9qah1f)

The save-restore path has a sibling boot-order discipline: `Inventory.restore_from_save` consumes Callables (`item_resolver`, `affix_resolver`) that read from the `ContentRegistry`'s `_items` / `_affixes` maps. If the registry's `load_all()` hasn't populated `_items[&"iron_sword"]` by the time `from_save_dict` calls the resolver, the resolver returns null, `ItemInstance.from_save_dict` push_warnings `unknown item id 'iron_sword'`, and the entry is dropped. (Save-restore on the live build is rescued by the post-restore `equip_starter_weapon_if_needed` auto-equip path — Sponsor never lost gear — but the warning pollutes console-silence assertions.)

**Why the warning fired in HTML5 specifically (load-bearing — NOT a timing race):** in Godot 4.3 HTML5 / `gl_compatibility` exports, `DirAccess.list_dir_begin()` over a res:// path packed inside the .pck does not enumerate subdirectories reliably — `current_is_dir()` can return false for entries that ARE subdirs on desktop. Pre-fix, `ContentRegistry.load_all()` recursed from `resources/items/` and missed `weapons/iron_sword.tres` in the HTML5 build. Headless GUT + desktop both passed (DirAccess works there). The bug shipped because no test exercised the HTML5 `_items.has(&"iron_sword")` post-condition.

**Fix shape:** `ContentRegistry.load_all()` is now three-pronged:
1. Recursive `DirAccess` scan from the roots (works on desktop).
2. Explicit subdir scan of `KNOWN_ITEM_SUBDIRS` (`weapons/`, `armors/`) — quiet on open-fail because the recursive scan above usually covers them already.
3. Direct `load()` of `STARTER_ITEM_PATHS` (the always-works fallback — `load()` of a packed res:// path always succeeds because it reads from the resource cache, not DirAccess).

`_on_item_resource_found` is now instance-equality-deduped so re-registration across the three passes doesn't push_warning. `is_resolved()` flips false → true at the end of `load_all()` and `items_resolved` emits; future async-style awaiters should `if not registry.is_resolved(): await registry.items_resolved`.

**Subscriber contract (mirrors `Save.save_completed`):**
- Today: synchronous consumer is `Inventory.restore_from_save` via the `item_resolver` / `affix_resolver` Callables Main exposes via `get_item_resolver()` / `get_affix_resolver()`. Because Main constructs the registry with `.load_all()` synchronously BEFORE `_load_save_or_defaults()` in `_ready`, the registry is always resolved by the time a Callable fires. The signal is a forward-compat hook, not a current dependency.
- Future: a save-restore path that runs OUTSIDE `Main._ready` (deferred quick-load, mid-run save scrub, save-slot picker that pre-validates) must `await registry.items_resolved` before iterating saved items. The `is_resolved()` fast-path covers the synchronous-already-ready case; only the deferred branch awaits.

**Naming + scope discipline:** `items_resolved` is past-participle, fires once per `load_all()` call, carries no payload. Don't add a `resolution_started` event — the registry is single-frame in M1/M2. Future schema-v4 promotion (per `team/devon-dev/save-schema-v4-plan.md`) may shift the registry to an autoload + add per-content-domain signals (e.g. `affixes_resolved` separate from `items_resolved`) — keep the M2 surface narrow until that lands.

**Discipline on adding new save-critical content:** whenever a new item ships under `resources/items/` whose ID is referenced by saves OR by the starter-seed path (`Inventory._seed_starting_inventory`), append it to `STARTER_ITEM_PATHS` in `scripts/content/ContentRegistry.gd`. The DirAccess recursive scan still runs and will pick up the new path on desktop, but the explicit list is what guarantees HTML5 resolution. Ship a paired test in `tests/test_save_restore_resolver_ready.gd` that exercises a save with the new id through `Inventory.restore_from_save` + production resolvers.

## Room-load triggers vs. body_entered triggers

A related class of bug, surfaced by M2 W1 P0 `86c9q96fv` + `86c9q96ht`: the boss spawned `STATE_DORMANT` and only woke when the player crossed an `Area2D` door-trigger via `body_entered`. But `Main._load_room_at_index` **teleports** the player to `DEFAULT_PLAYER_SPAWN = (240, 200)` rather than sliding them through the room boundary — no physics overlap event ever fires. Result: boss stayed dormant forever, rejecting damage AND skipping AI in `_physics_process`. Both Sponsor-reported P0s collapsed to one root cause.

**The general pattern:** an entry-trigger `Area2D` whose `body_entered` is the only wake/start hook is fragile against any code path that places a body in the room without traversal — room-load teleport, save/load restore, debug-tool warp, future fast-travel. If the room is the unit of "player is now here," the room itself should fire the trigger from `_ready`.

**Fix shape (`Stratum1BossRoom._ready`)** — current form, after the ticket `86c9tv8uf` physics-flush defer:

```gdscript
func _ready() -> void:
    # Synchronous: boss is a CharacterBody2D (no monitoring mutation on
    # tree-entry) and Main._wire_room_signals reads get_boss() on the same tick.
    _spawn_boss()
    # Deferred: builds the door-trigger Area2D + spawns the StratumExit (which
    # builds its own Area2D), then auto-fires the entry sequence.
    call_deferred("_assemble_room_fixtures")

func _assemble_room_fixtures() -> void:
    if not is_inside_tree():
        return
    _build_door_trigger()
    _spawn_stratum_exit()
    if _boss != null:
        trigger_entry_sequence()  # idempotent — door-trigger fallback stays safe
```

Three reasons the fixture pass is `call_deferred` rather than synchronous: (a) `Main._load_room_at_index` re-parents the player into the room AFTER the room's `_ready` returns, so a deferred call lands in a tree where the player is correctly placed; (b) the door-trigger and StratumExit Area2D `add_child`s would otherwise panic — `Stratum1BossRoom._ready()` runs inside the physics flush of Room 08's `gate_traversed` callback (see "Physics-flush rule" above and the "Boss-room closure" note under "AC4 spec assertion pattern"); (c) `trigger_entry_sequence` arms a `SceneTreeTimer`, which is harmless deferred. `_spawn_boss` is deliberately kept OUT of the deferred pass — see the synchronous-reason comment above.

**The door-trigger fallback is preserved for two cases:** (a) future code that drags the player through a real boss-room doorway (corridor designs in M2+); (b) belt-and-suspenders against future regressions in the auto-fire path. Both fire `trigger_entry_sequence`, which is idempotent.

**Future bugs in this family:** any room with a wake/start trigger gated on physics overlap (boss rooms, ambush rooms, lock-then-unlock state machines). Pattern check: does the room have an entry-trigger Area2D whose `body_entered` handler is the ONLY production wake path? If yes, audit it against teleport-style player-entry. Memory rule candidate: `room-load-vs-body-entered-trigger.md`.

## body_entered semantics — single-event continuous-walk (load-bearing for harness specs)

A separate class of bug — surfaced when the Playwright harness tried to drive `RoomGate` traversal in `ac4-boss-clear.spec.ts` — is the **single-event continuous-walk** semantics of Godot 4's `Area2D.body_entered` signal.

**The mechanic:** `body_entered` fires on the **non-overlap → overlap transition**, not on every physics tick the body remains inside the trigger rect. A Player CharacterBody2D walking continuously through an Area2D fires `body_entered` exactly **once**, regardless of how long they remain inside or how slowly they cross. To re-fire it, the body must `body_exited` first (transition back to non-overlap), then re-enter (transition to overlap again).

**Why this bites state machines that need >1 entry event:** `RoomGate` (`scripts/levels/RoomGate.gd`) implements a three-state progression that requires two distinct `body_entered` events on the SAME gate node:

```
   OPEN
    │  body_entered #1 (CharacterBody2D enters trigger rect)
    ▼
   LOCKED  ── all mobs dead → DEATH_TWEEN_WAIT_SECS (0.65s) ──┐
                                                              │
                                                              ▼
                                                          UNLOCKED
                                                              │
                                                              │  body_entered #2
                                                              ▼
                                                         gate_traversed
```

A naïve "walk through the gate once" pattern produces only `body_entered #1` (lock event); the gate never reaches `gate_traversed`. The body must exit and re-enter for the second event.

**Production code path that works:** in real gameplay this is invisible because the player walks INTO the room (event #1: lock), then walks AROUND killing mobs (multiple body_exited / body_entered cycles as the player wanders the room — but those happen incidentally, not as a designed test sequence), then walks toward the exit door (event #N: traverse). The "two distinct events" requirement is satisfied by emergent gameplay movement.

**Harness code path that fails:** Playwright spec drives precise keyboard inputs that may produce a single continuous walk through the trigger; this only fires `body_entered` once and the gate sticks at LOCKED forever (or, if mobs are killed first while gate is OPEN, sticks at UNLOCKED — the lock-and-immediate-unlock condenses into one body_entered event). Either way the spec hangs waiting for `gate_traversed`.

**Canonical harness fix shape — two-part walk pattern:** the spec must drive the player IN → OUT → IN to produce two distinct `body_entered` events. See `tests/playwright/fixtures/gate-traversal.ts` (`gateTraversalWalk` helper) for the encoded pattern with full geometric and timing rationale. The helper combines this `body_entered` mechanic with another non-obvious harness gotcha — the trigger rect's geometric position relative to `DEFAULT_PLAYER_SPAWN` requires a **diagonal NW** walk (both X and Y must satisfy the rect bounds simultaneously; pure-west or pure-north walks both miss).

**Future bugs in this family:** any specs that need a state machine to advance through more than one `body_entered`-driven step on the same Area2D. Pattern check: does the spec drive the player into a trigger and assert state advances on a SECOND entry? If yes, the spec must explicitly walk the body out and back in. Memory rule candidate: `body-entered-single-event-rule.md`.

**Sibling lesson:** the Sponsor-soak path traverses these gates via natural emergent movement — kill mobs (wandering naturally produces body_exited/body_entered cycles), then walk to the door. Headless GUT tests bypass the issue by calling `RoomGate.trigger_for_test()` / `RoomGate.traverse_for_test()` (`scripts/levels/RoomGate.gd` lines 224, 328). Only the browser-driven Playwright harness — which simulates real input on a single deliberate path — needs to encode the discipline explicitly.

**Investigation conclusion (ticket 86c9qbhm5, Devon, 2026-05):** the suspected "body_entered does not fire under Playwright headless cadence" hypothesis was DISPROVEN. With instrumented release builds, an unconditional entry trace at the top of `_on_body_entered` (before the `is CharacterBody2D` filter) fired reliably 5/5 runs when the player walked from `DEFAULT_PLAYER_SPAWN = (240, 200)` into the Room02 gate via the documented two-segment `W 2000ms then N 1500ms` walk. The state-machine + mob_died-propagation chain also worked end-to-end (gate locked, mobs died, gate unlocked, gate_traversed emitted) when the player executed the walk **without prior combat drift**.

The PR #170 AC4 spec saw zero `RoomGate.*` traces because **the player drifted during long Room02 combat** (knockback + the spec's 8-direction aim sweep accumulated >100px of westward+northward displacement). The post-combat W+N walk pattern then started from a position FAR from spawn and never intersected the trigger. There was no Godot/Playwright signal-emission bug; the harness simply wasn't reaching the trigger geometry.

**Codified harness rules (lessons for future spec authors):**

1. **Don't aim-sweep during combat** if the spec needs to walk a precise post-combat path. Use NE-facing-only (or whatever single direction matches mob spawn geometry — Room01..Room08 grunts spawn NE/N of player) and click-spam without re-aiming. The player stays near spawn; subsequent walk geometry is reliable.
2. **The `gate-traversal.ts` helper assumes player at `DEFAULT_PLAYER_SPAWN`** — explicitly noted in its header. Specs that use the helper must keep combat tight (~6-15s) so the player is still near spawn when the helper runs. Pass `options.expectedSpawn = [240, 200]` to make drift-related failure messages self-explanatory.
3. **`tests/playwright/specs/room-gate-body-entered-regression.spec.ts`** is the permanent canary: it skips Room02 combat entirely (gate stays OPEN), walks from spawn, asserts body_entered fires. If this spec ever fails, the signal IS regressing — investigate Godot 4.x version bumps, gl_compatibility physics-server changes, or service-worker timing interference.
4. **Harness-side "no aim-sweep, no repositioning, no direction-key holds during combat"** rule applies to ANY spec whose post-combat phase walks a precise spawn-relative path. This rule was codified after AC4's harness-drift bug (PR `tess/m2-w1-ac4-drift-fix` — root cause: 8-direction aim cycle accumulated 100+px drift over 21s combat). Apply pre-emptively to new specs in this family — `room-traversal-smoke.spec.ts` documents an analogous risk in its own header.

**AC4 spec assertion pattern (PR `tess/m2-w1-ac4-drift-fix`):** the spec asserts on three traces per gate, in causal order: `_on_body_entered` (body reached the trigger — distinguishes drift from state-machine bugs) → `gate_unlocked` (state-machine accepted lock-and-unlock condensed) → `gate_traversed` (second body_entered fired and idempotency guard didn't double-emit). The `_on_body_entered` assertion is the load-bearing positive signal — it's what catches drift regressions before they cascade into harder-to-diagnose state-machine timeouts. **Empirical observation during PR `tess/m2-w1-ac4-drift-fix` validation:** the new helper correctly distinguished drift-vs-state-machine and surfaced a new game-side bug — the gate's `_mobs_alive` counter showed 1 after clearRoomMobs reported 2/2 deaths in Room02, blocking `lock()` → `_unlock()`. That bug is out of scope for the harness-drift PR and needs a follow-up game-side investigation (candidates: MultiMobRoom `_register_mobs_with_gate` ordering, knockback-into-wall corners dropping `mob_died.emit`, LevelAssembler `mobs.append` vs `add_child` race).

**AC4 blocker — confirmed root cause + fix (ticket 86c9tqvxx, PR `drew/multimobroom-gate-registration`).** The follow-up investigation reframed AC4: it is NOT a Room 03 combat-positioning problem (the PR #86c9qckrd harness iterations were chasing a red herring) — AC4 stalls at **Room 02, the first gated room**. The confirmed mechanism is **not** an empty `_assembly.mobs` and **not** the `mobs.append` vs `add_child` race: `LevelAssembler.assemble_single` populates `result.mobs` synchronously (the existing `test_stratum1_rooms.gd::test_room02_spawns_two_grunts` proves `get_spawned_mobs()` returns 2 right after `_ready`). The real cause is a **physics-flush-window panic** — the same class as the boss-room `_build_door_trigger` harmonization gap. `MultiMobRoom._spawn_room_gate()` did a synchronous `add_child` of a `RoomGate` (an **Area2D**) from `_ready`. For Rooms 02..08, `_ready` runs *inside* a physics flush — `Main._load_room_at_index` is invoked from the prior room's `RoomGate.gate_traversed → _on_room_gate_traversed → room_cleared → _on_room_cleared → _load_room_at_index → _world.add_child(room) → MultiMobRoom._ready()`, and `gate_traversed` itself emits from a `body_entered` physics callback. Adding the Area2D + activating its monitoring inside that flush panics (`USER ERROR: Can't change this state while flushing queries`); the C++ early-returns, leaving the gate improperly inserted. Consequence chain: `RoomGate.is_inside_tree()` reads false → the gate's `_combat_trace` shim no-ops → **zero `[combat-trace] RoomGate.register_mob` lines ever emit** (the empirical AC4 symptom), AND the gate's Area2D never monitors → `body_entered` never fires → the gate never locks/unlocks → traversal past Room 02 is impossible (a playable-looking but unwinnable build). `HealingFountain` (Room 06) is also an Area2D and shared the same latent gap. **Fix:** `MultiMobRoom._ready` keeps `_build()` synchronous (mobs are CharacterBody2D — no monitoring mutation — and `Main._wire_room_signals` reads `get_spawned_mobs()` on the same tick) but defers the Area2D-fixture pass — `_spawn_room_gate` + `_spawn_healing_fountain` + `_register_mobs_with_gate` — to `call_deferred("_assemble_room_fixtures")`, landing it after the physics flush closes. This is the exact `Stratum1Room01._ready → call_deferred("_wire_tutorial_flow")` precedent (same § "Room-load triggers vs body_entered triggers" rule). **Test consequence:** tests that inspect `get_room_gate()` / `get_healing_fountain()` must drain a frame after instantiating the room (the deferred pass lands next-frame) — see `test_stratum1_rooms.gd::_load_room_with_fixtures`; `get_spawned_mobs()` alone still works synchronously. **Generalization:** any room script that `add_child`s an Area2D-derived fixture from a `_ready` reachable via the room-load chain must defer that `add_child` — `_ready` of a room past Room 01 is always a physics-flush context.

**Boss-room closure (ticket 86c9tv8uf, PR `drew/stratum1bossroom-flush-audit`).** The PR #183 fix flagged `Stratum1BossRoom._build_door_trigger` as the last unaudited room script doing a synchronous Area2D `add_child` from a room-load `_ready`. The follow-up audit confirmed it: `Main._load_room_at_index(8)` reaches the boss room via the *same* `RoomGate.gate_traversed → _on_room_gate_traversed → room_cleared → _on_room_cleared → _load_room_at_index → _world.add_child(room) → _ready()` chain that Rooms 02–08 use — `Stratum1BossRoom._ready()` is a physics-flush context, and the old "zero panic risk" claim in § "Hitbox + Projectile encapsulated-monitoring rule" was unjustified. `_build_door_trigger` (door-trigger Area2D) **and** `_spawn_stratum_exit` (the `StratumExit` builds its own Area2D interaction area on `_ready`) are both now deferred via `Stratum1BossRoom._ready → call_deferred("_assemble_room_fixtures")`. `_spawn_boss` deliberately stays synchronous in `_ready` — the boss is a CharacterBody2D (no monitoring mutation on tree-entry) and `Main._wire_room_signals` reads `get_boss()` on the same tick the room is added (deferring it would null the wire-time `get_boss()` call and the boss would never get XP/loot wiring). **Test consequence (same as MultiMobRoom):** tests that inspect `get_door_trigger()` / `get_stratum_exit()` must drain a frame after instantiating the boss room — see `test_stratum1_boss_room.gd::test_door_trigger_enters_tree_and_monitors_after_deferred_pass` and `test_stratum_exit.gd::_make_room`; `get_boss()` alone still works synchronously.

**Lightweight ongoing trace:** `_on_body_entered` keeps a small `_combat_trace("RoomGate._on_body_entered", "body=... state=... mobs_alive=...")` line at function entry — HTML5-only via the existing `combat_trace` shim. This survives the diagnostic strip-down because it costs nothing in headless GUT and gives Playwright specs a "did the gate ever see a body?" datapoint when traversal fails. Use it to tell "gate never reached" (no trace) from "gate reached but state wrong" (trace fires, state machine diverges) — the same Case A vs Case B distinction the investigation used.

## Harness coverage gap — phase boundaries vs gameplay event ordering (ticket 86c9ugfzv)

A sibling-class harness gotcha to "body_entered semantics — single-event continuous-walk" above: **gameplay events can fire BEFORE the harness phase that's structured to detect them.** PR #221's surfacing finding + the 86c9ugfzv 8-run-sweep diagnostics empirically pinpointed the failure mode in Room 03 (the Grunt + Charger near-spawn chase-combat room):

**The sequence (release-build, deterministic across 8 runs):**

1. **Room-load / settle window** (between Room N-1's `gate_traversed` and Room N's first `clearRoomMobs` call): Room N loads, mobs spawn near the gate, the player's teleport-to-spawn combined with chase-knockback drifts the player INTO the trigger → `body_entered #1` fires → `_on_body_entered` traces `state=open mobs_alive=N` → `lock()` runs → gate state transitions to LOCKED.
2. **Combat phase** (`clearRoomMobs` running): mobs die one by one via `mob_died.emit` → deferred `RoomGate._on_mob_died` decrements `_mobs_alive` → when it hits 0 with state==LOCKED, the gate starts a 650ms `DEATH_TWEEN_WAIT` → fires `_unlock()` → gate state UNLOCKED, `gate_unlocked` emits.
3. **Helper entry**: `gateTraversalWalk` is invoked from the spec, but **the gate already went OPEN→LOCKED→UNLOCKED before the helper ran.**

**Why the old helper failed:** the pre-fix `gateTraversalWalk` snapshotted `preLineCount` at helper-entry and scanned only NEW lines (`[preLineCount, ...)`) for `gate_unlocked` events. The unlock trace was at index `< preLineCount` — outside the scan window. Phase 3's walk-in then fired `body_entered #2` against the already-UNLOCKED gate, immediately emitting `gate_traversed` — but the helper's assertion was structured as "phase 3 should fire gate_unlocked" (looking for the lock-and-unlock event during the walk). The unlock had already fired during combat, so the assertion threw with the misleading message "phase 3 fired _on_body_entered but gate_unlocked did NOT follow."

**The fix shape — case A/C resolution from caller's room-snapshot (PR #239 retired case B):** the helper now accepts `options.preRoomLineCount` (the trace-buffer line count captured BEFORE the spec's combat phase began). The helper expands the scan window to `[lastPreviousTraversedIndex + 1, preLineCount)` — covering both the room-load / settle period AND combat — and routes to one of two cases:

- **Case A (`already-traversed`):** scan slice contains a `gate_traversed` event → the gate fully transitioned during combat (chase + knockback drove the player through the trigger twice). Helper returns early; spec asserts the causal sequence and skips the two-part walk.
- **Case C (`open-walk`):** scan slice contains no `gate_traversed` → existing phase 3-5 two-part walk (the open-gate path).

**Case B retirement (PR #239, ticket `86c9ungc2`).** A third case originally existed — `unlocked-finish` for "gate UNLOCKED during combat but player not yet through the trigger" — using position-steered staging to walk the player west across the trigger. Drew's PR #230 (ticket `86c9ujg8c`) shipped the **game-side fix** in `RoomGate._unlock()`: when the unlock fires and `get_overlapping_bodies()` finds a CharacterBody2D inside the trigger, `_unlock` `call_deferred("_fire_traversal_if_unlocked")` to emit `gate_traversed` automatically (the "knockback-overlap" fix). Once that landed, case B's silent steer-and-finish became **load-bearing for HIDING regressions** of PR #230 — if the game-side fix ever broke, the harness would still pass via the steer workaround and Sponsor would only find out at soak.

Per the convention codified as §15 in `team/tess-qa/playwright-harness-design.md` ("Silent workarounds for fixed game-side bugs must fail loudly"), PR #239 converted case B to `expect.fail("CASE B HIT — PR #230 RoomGate._unlock knockback-overlap fix regressed")`. The dead steer/staging helpers (`finishTraversalFromUnlocked`, `steerPlayerToPoint`, `latestPlayerPos`, `keysForDelta`, `waitForNewLine`) were removed from `tests/playwright/fixtures/gate-traversal.ts`; a restoration-path comment at the removal site documents how to re-instate them if a future legitimate game-side regression needs the workaround.

**Generalisation — workaround-retirement convention (PR #239).** Any harness workaround for a known game-side bug must fail loudly once the game-side fix lands. Silent fallbacks turn the harness into a regression-hiding surface for the very class of bugs it was supposed to detect. The pattern: when a fix ships, audit the harness for workarounds that targeted the bug, convert them to hard throws with regression-signal error messages citing the fix PR, and remove now-dead workaround code. Track the convention in `team/tess-qa/playwright-harness-design.md` § 15.

The case is exposed on `GateTraversalResult.resolutionCase` (`"already-traversed" | "open-walk"` — the `"unlocked-finish"` literal was dropped) so the spec can scope assertions per-case (the phase-3 `bodyEnteredFiredOnPhase3` assertion only applies to case C; case A short-circuits before phase 3 runs).

**Harness mechanism note from the implementation:**

1. **`waitForLine` matches stale buffer entries** — `ConsoleCapture.waitForLine(/gate_traversed/)` scans the FULL buffer and returns immediately if ANY line matches, including stale `gate_traversed` events from previous rooms. Pattern check: any helper that asserts "X event fired after my action" must capture a baseline buffer index before the action and wait only for NEW matches above that index.

**Generalisation: harness coverage gaps come in pairs.** This is the second body_entered-family gap (the first was "single-event continuous-walk" above — fixed by the two-part walk pattern in case C; this one is "events fire before the harness phase that scans for them" — fixed by the case A/C resolution). Future harness fixtures that scan for gameplay events should:

1. **Snapshot a baseline buffer index** at the START of the room-scoped lifecycle (not at helper entry), so events fired during room-load / settle windows are captured.
2. **Look back as well as forward** — at minimum, use the previous gate's `gate_traversed` index as the scan-start lower bound. Room-scoped events can fire in either direction relative to the helper invocation.
3. **Match new events only** when asserting "this action caused this event" — never match stale buffer entries.

References:
- `tests/playwright/fixtures/gate-traversal.ts` § module header — full sequence diagram + case A/C semantics (post-PR-#239 retirement of case B)
- `tests/playwright/fixtures/kiting-mob-chase.ts` § "Post-chase gate resolution" — sibling fixture's case A/C resolution (predates this gate-traversal one; the mechanism is identical)
- `tests/playwright/fixtures/console-capture.ts` § `waitForLine` — the documented stale-match gotcha
- `team/tess-qa/playwright-harness-design.md` § 15 — workaround-retirement convention (PR #239)
- ticket 86c9ugfzv (Drew, M2 W3) — the empirical surfacing PR; 8-run-sweep diagnostics are the canonical evidence
- PR #230 (Drew, ticket 86c9ujg8c) — `RoomGate._unlock` knockback-overlap fix that made case B redundant
- PR #239 (Tess, ticket 86c9ungc2) — case B retirement to `expect.fail`

## GUI focus-consumption vs. Playwright keypresses — close a focus-holding panel with a test-only hook

A class of harness flake surfaced by `equip-flow.spec.ts` Phase 2.5 (tickets `86c9qb7f3` / `86c9qah0f`): **Godot's GUI input system consumes more keys than just `Tab`.** When a focusable `Control` (e.g. an inventory grid `Button` with the default `focus_mode = FOCUS_ALL`) holds keyboard focus, the GUI system intercepts UI-action keys *before* they reach `_unhandled_input`:

- `Tab` — the built-in focus-traversal key ("focus next neighbour").
- `Escape` — bound to the built-in `ui_cancel` GUI action.

Both are swallowed by the focus system while a Control is focused. A spec that clicks an inventory grid cell (grabbing focus on that Button) and then presses `Tab` *or* `Escape` to close the panel will find the panel **stays open** — the keypress never reaches `InventoryPanel._unhandled_input`'s toggle/close handler. The panel staying open means `Engine.time_scale = TIME_SLOW_FACTOR (0.10)` stays in effect and every subsequent spec action runs in 1/10th-speed slow-mo. **Picking a different key does not fix this** — `equip-flow.spec.ts` round-1 swapped `Tab → Escape` and reproduced the panel-stays-open failure 0/5 headed (Devon's peer review).

**The reliable pattern: a test-only direct-close hook handled in `_input()`.** `_input()` runs *before* the GUI focus system (unlike `_unhandled_input()`), so a focused Button cannot swallow the event. `InventoryPanel.force_close_for_test()` (in `scripts/ui/InventoryPanel.gd`, matching the existing `force_click_*_for_test` convention) closes the panel + restores `Engine.time_scale` directly, sidestepping the entire focus-consumption class. It is wired to **F9**, matched by `physical_keycode` in `InventoryPanel._input()` (the proven `DebugFlags._input` Ctrl+Shift+X pattern), with a `test_force_close_inventory` action as a secondary path. The whole handler is gated on `OS.has_feature("web")` — inert on desktop / headless GUT, mirroring the `DebugFlags.combat_trace` web-only gate. The hook emits a `[combat-trace] InventoryPanel.force_close_for_test | open=false time_scale=1` confirmation line so the spec can **positively assert the panel actually closed** (and `Engine.time_scale` was restored) before proceeding — never "press a key and hope it closed".

**Generalised rule:** any Playwright spec that needs to close (or otherwise dismiss) a focus-holding panel after a click landed on a focusable child Control must NOT rely on `Tab`/`Escape`/any GUI-action key reaching `_unhandled_input`. Add a test-only direct-action method on the panel, wire it to a dedicated key handled in `_input()` (gated on `OS.has_feature("web")`), and have the spec assert a confirmation trace. Pattern check: does the spec press a key to dismiss UI immediately after clicking a focusable Control? If yes, it needs the `_input()`-handled hook, not a key-picking lottery.

## Harness coverage gap — player-driven helpers + stale-trace consumption

Two classes of harness blindness surfaced during M2 W3 by Sponsor manual soak + Drew's diagnostic-via-trace work on PR #212 / PR #221. Both invalidate the naive "AC4 green = gameplay works" reading and define the contract that future fixture authors must respect.

### Class 1 — player-driven helpers don't validate mob self-engagement

The AC4 Playwright spec (`tests/playwright/specs/ac4-boss-clear.spec.ts`) uses helper `chaseAndClearKitingMobs` (in `tests/playwright/fixtures/kiting-mob-chase.ts`) to navigate rooms with kiting Shooters. The helper **drives the player toward the Shooter** — issues player-side movement commands to chase, attacks at close range, then returns to spawn (the PR #190 / #212 pattern).

When a mob is broken in a way that prevents IT from driving itself toward the player — always-flee logic, missing pursue state, no cornered-attack fallback, broken target acquisition — the AC4 spec **cannot detect it**. The harness covers the player's path to the mob; it does not cover the mob's path to the player.

**Empirical case (Sponsor M2 RC soak 2026-05-15, build `5bef197`):** Room 04 Shooter only flees, never engages; cornered = idle; out-of-range = no pursuit. AC4 spec had been green throughout this regression because the harness DROVE the player to the Shooter. Bug fixed in PR #221 (Shooter state-machine engagement bands + cornered fallback). The PASSIVE-PLAYER spec class `tests/playwright/specs/mob-self-engagement.spec.ts` (PR #215, Tess) is the canonical guard going forward — player stands still per room, harness asserts mob reaches and lands a hit within an expected window.

**Implication:** "AC4 green" means "the player can clear the rooms via the prescribed harness sequence." It does NOT mean "mobs engage the player as designed." This coverage gap applies to any mob behavior that requires mob initiative.

### Class 2 — stale-trace consumption in `latestPos`-style harness lookups

The harness reads mob position + state from `[combat-trace] <Mob>.pos | pos=... state=... dist_to_player=...` lines. Godot HTML5 frame-rate is volatile under Playwright load — `_physics_process` can pause for multi-frames, **freezing the trace's authoritative-distance field** at a snapshot from 1+ seconds ago. Harness consumers that prefer `latestPos.dist_to_player` over computed-from-live-readings get stuck in pursuit loops against ghost positions.

Two distinct failure shapes (Drew's PR #212 surfaced both):

1. **Frozen `dist_to_player` for a still-emitting mob:** Shooter pauses physics-tick mid-trace, dist_to_player reads stale, harness sees "mob is far" when mob is actually adjacent.
2. **Cross-room corpse leak:** without a `minTimestamp` lower bound on `latestPos` lookups, the prior room's last `Shooter.pos` line (emitted seconds ago, mob now destroyed) is treated as a live target.

**Convention (canonical):** future fixture authors using `latestPos`-style lookups MUST default to **staleness-bounded + cross-room-scoped** reads. See `team/tess-qa/playwright-harness-design.md` § 14 "Staleness-bounded latestPos lookup convention" for the full rule set:

- `minTimestamp` always set on mob-pos lookups (cross-room scope)
- `maxAgeMs` always set when reading authoritative trace fields (`dist_to_player`, etc.) — fall back to computed-from-live-readings if stale
- Player-pos is NOT scoped (single source, no destruction lifecycle)
- Soft `CHASER_POS_STALENESS_MS` is log-only — multi-chaser pursuit picks freshest reading across channels; do NOT extend into a rejection window

Reviewers should ding PRs that use raw `latestPos` without bounds.

### Mitigations

- **Manual soak remains essential** for mob-self-engagement validation and any other surface where mob initiative or visual-fidelity is load-bearing. Sponsor-soak is the first detection surface; it cannot be retired by harness coverage alone.
- **The "passive player" spec class** (`tests/playwright/specs/mob-self-engagement.spec.ts`, PR #215) closes Class 1 mechanically.
- **The staleness-bounded latestPos convention** (PR #212, codified in `playwright-harness-design.md` § 14) closes Class 2 mechanically — for future helper authors. Apply at code-review time.
- **Universal console-warning zero-gate** (PR #217, `tests/playwright/fixtures/test-base.ts`) catches the related class of latent `USER WARNING:` / `USER ERROR:` lines that previously slipped past as console-noise.

A future reader looking at "AC4 green ✓" should NOT conclude that mob behavior, mob-state-machine completeness, or visual fidelity is end-to-end validated. The harness validates the player's prescribed sequence; the rest is soak.

## Cross-references

- HTML5-renderer-specific quirks (HDR clamp, Polygon2D, service worker cache): `.claude/docs/html5-export.md`
- Orchestration conventions (worktrees, dispatch, ClickUp gates): `.claude/docs/orchestration-overview.md`
- Test bar codification: `team/TESTING_BAR.md`
- Wave post-mortem: `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md`
- Damage formula decision: `team/decisions/DECISIONS.md` `2026-05-02 — Damage formula constants locked`
- Playwright harness: `tests/playwright/` + design at `team/tess-qa/playwright-harness-design.md`
