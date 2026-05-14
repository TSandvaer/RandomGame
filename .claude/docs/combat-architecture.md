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

## Mob `_die` death pipeline

When a mob's HP reaches 0, the synchronous chain is:

1. `_set_state(STATE_DEAD)`
2. `mob_died.emit(...)` — listeners (notably `MobLootSpawner.on_mob_died`) run synchronously on the same frame
3. `_spawn_death_particles()` — adds a `CPUParticles2D` to the room
4. `_play_death_tween()` — alpha/scale tween over `DEATH_TWEEN_DURATION` (typically 0.4s); arms a parallel `SceneTreeTimer` of the same duration as a safety net
5. On either `tween.finished` OR the timer firing first: `_on_death_tween_finished` → `_force_queue_free()` (idempotent guard via `is_queued_for_deletion()`)

**The parallel SceneTreeTimer is critical** (PR #136). Without it, mobs become functionally immortal if the death tween hangs for any reason — the original P0 that surfaced in the M1 RC investigation.

`MobLootSpawner.on_mob_died` calls `parent_for_pickups.call_deferred("add_child", pickup)` (PR #142 fix) — Pickup root is an Area2D, and adding it during physics flush triggers the same `USER ERROR: Can't change this state while flushing queries` panic. The `_spawn_death_particles` adds in each of 4 mob types also use `room.call_deferred("add_child", burst)` defensively.

**RoomGate uses `CONNECT_DEFERRED` for `mob_died` listeners** (ticket 86c9qcf9z). `RoomGate.register_mob` connects with `mob.mob_died.connect(_on_mob_died, CONNECT_DEFERRED)` so the `_mobs_alive` decrement queues to end-of-frame instead of running inside the mob's synchronous emit chain. **Why this matters:** `MultiMobRoom._register_mobs_with_gate` runs from `MultiMobRoom._ready`, which itself runs during a physics-flush window when `Main._load_room_at_index` is called from a previous room's `gate_traversed → _on_room_gate_traversed → room_cleared → _on_room_cleared` chain (rooted in a CharacterBody2D `body_entered` callback). Subsequent `mob_died.emit` calls reach the gate via this connection, and prior to the deferred fix the gate's decrement competed with other physics-flush mutations (Pickup adds, particle adds, room transitions). Tess's PR #172 AC4 trace empirically observed two grunts emitting `Grunt._die` but only ONE decrement landing on the gate, leaving `_mobs_alive=1, state=open` and blocking the gate from ever transitioning to UNLOCKED. CONNECT_DEFERRED sidesteps the entire race class — every mob_died emission queues an end-of-frame decrement that runs outside the flush window.

**Cross-tree signal-connection discipline (load-bearing).** Any signal-handler that:

1. is connected from a context running during physics flush (e.g. inside `_ready` of a node added via `add_child` from a prior room's death / traversal callback), AND
2. the connected handler mutates persistent state the receiver later inspects (counter, list, gate-state)

should be connected with `CONNECT_DEFERRED`. The synchronous-emit alternative is timing-sensitive and may lose decrements/increments under physics-flush re-entry. `Levels.subscribe_to_mob` already uses `CONNECT_ONE_SHOT` (a different concern — once-per-life XP); `Main._wire_mob` connects synchronously but only forwards to a deferred-add-child path. RoomGate is the canonical example of a counter-style listener that needs CONNECT_DEFERRED.

**Test-side consequence.** GUT tests that fire `mob_died` synchronously and then immediately inspect `gate.mobs_alive()` / `gate.is_unlocked()` must `await get_tree().process_frame` between the emit and the assertion. The pre-existing `test_room_gate.gd` / `test_room_advance_only_on_door_walk.gd` / `test_room_transition_requires_door_walk.gd` tests were updated alongside the CONNECT_DEFERRED migration to drain a frame between every `m.die()` call and the next assertion.

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

## `[combat-trace]` diagnostic shim

[`scripts/debug/DebugFlags.gd`](scripts/debug/DebugFlags.gd) — `DebugFlags.combat_trace(tag, msg)` emits `[combat-trace]` console lines only when `OS.has_feature("web") == true`. Wired into:

- `Player.try_attack / swing_wedge / swing_flash`
- `Hitbox.hit`
- Per-mob `take_damage`, `_play_hit_flash`, `_die`, `_play_death_tween`, `_on_death_tween_finished`, `_force_queue_free`. **All five mob types emit `<Mob>._die` uniformly** (`Grunt._die`, `Charger._die`, `Shooter._die`, `PracticeDummy._die`, plus `Stratum1Boss`) — ticket `86c9tuh57` closed a gap where `Charger._die` / `Shooter._die` emitted `_force_queue_free | freeing now` but no `_die` line, breaking harness kill-counting + Sponsor-soak greps that count kills uniformly on the `<Mob>._die` trace. The line shape is `[combat-trace] <Mob>._die | starting death sequence`, emitted immediately after the `_is_dead = true` idempotency latch. **All mob types also emit `<Mob>.take_damage` uniformly** — `Grunt.take_damage` / `PracticeDummy.take_damage` / `Stratum1Boss.take_damage` carried the `amount=<N> hp=<before>-><after>` line from the start; ticket `86c9u2383` closed the sibling gap where `Charger.take_damage` / `Shooter.take_damage` emitted no line, making console-based hit verification non-uniform. The line shape is `[combat-trace] <Mob>.take_damage | amount=<N> hp=<before>-><after>`, emitted immediately after `hp_current` is decremented and before `damaged.emit`. For `Charger`, `amount` is the post-multiplier `final_amount` actually subtracted (armored 1x / recovery 2x), not the raw incoming `amount` — it mirrors what HP changed by.
- `Inventory.equip` (P0 86c9q96m8 + ticket 86c9qah0v) — `[combat-trace] Inventory.equip | item=<id> slot=<weapon|armor> source=lmb_click|auto_starter damage_after=<N>` fires on every successful `equip()` call. `source` is a `StringName` enum: `lmb_click` (default) tags user-driven equips via `InventoryPanel._handle_inventory_click`; `auto_starter` tags system-driven equips via `equip_starter_weapon_if_needed` (boot-time auto-equip). `restore_from_save` still bypasses `equip()` entirely — so save-restore (F5 reload, save-load) does NOT fire this line at all. The scoping rule grew from binary (lmb_click vs no-trace-on-save-restore) to ternary (lmb_click vs auto_starter vs no-trace-on-save-restore). Future system-driven equip paths must add their own `source` tag rather than overloading `lmb_click`. The `damage_after` field reads from `Damage.compute_player_damage(Player.get_equipped_weapon(), Player.get_edge(), &"light")` — proves both Inventory and Player surfaces stayed in lockstep at the moment of equip.
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

The fix patterns:

1. **Receiver-side encapsulation (preferred)** — make the Area2D-derived class's `_init` set monitoring off, re-enable in `_ready()` (Godot defers `_ready` automatically). All spawn sites get auto-protected.
2. **Caller-side defer** — `parent.call_deferred("add_child", child)` at the spawn site. Use when you can't subclass the Area2D.

Future bugs in this family: check the `_die` chain (death-path adds), all per-tick spawn sites (spawn-path adds), and any new Area2D class that's instantiated outside `_ready` of the parent scene. Memory rule: `godot-physics-flush-area2d-rule.md`.

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

Linking is normally automatic: `Inventory.equip()` → `_apply_equip_to_player()` → `Player.equip_item()`. Any code path that bypasses `Inventory.equip` and mutates one surface without the other will produce a silent divergence — boot prints lie ("auto-equipped" fires), one surface is correct, the other is null. Symptom: combat reads `damage = 1` (FIST_DAMAGE) while Tab UI also reads empty (or vice versa).

**Three failure modes in this family bit M1 RC** (PR #145 → PR #146 → P0 86c9q96m8):

1. **Boot-order clobber.** `Save` autoload's `restore_from_save()` reset loop unconditionally calls `_apply_unequip_to_player(slot)` for every key in the equipped map, even on an empty save. Any code that pre-populates equipment (like `equip_starter_weapon_if_needed`) MUST run AFTER `_load_save_or_defaults()` in `Main._ready()`. The `Inventory` autoload's `_ready()` print can fire before save-restore wipes it three lines later — boot prints are not proof of post-boot state.
2. **Stub-Node test silently skips Player surface.** `_apply_equip_to_player(target)` checks `target.has_method("equip_item")` and silently skips when false. A stub `Node.new()` test target returns false — the Player-side wiring path is never exercised. Inventory state assertions pass; the integration is silently broken in production.
3. **Equip-via-LMB-click swap leaks the previously-equipped item.** Pre-fix `Inventory.equip()` called `_unequip_internal(slot, push_back_to_inventory=false)` when a different item was already in the slot — silently discarding the previous weapon (Sponsor M1 RC re-soak attempt 5: pickup new sword + LMB-click → "item disappears, can't re-equip"). Fix: erase the new item from `_items` FIRST so the grid has a free slot, then call `_unequip_internal(slot, true)` to push the previously-equipped item back into the grid. Order matters because a 24/24 grid would otherwise refuse the push-back. **Combat-trace shim** (P0 86c9q96m8 + ticket 86c9qah0v): `Inventory.equip(item, slot, source = &"lmb_click")` emits `[combat-trace] Inventory.equip | item=<id> slot=<weapon|armor> source=lmb_click|auto_starter damage_after=<N>` on every successful equip. The optional `source` parameter (default `&"lmb_click"`) tags the trace so the Playwright negative-assertion sweep can tell user-clicks from system-equips apart. `equip_starter_weapon_if_needed` overrides to `&"auto_starter"` so the boot-time auto-equip does not pollute the `lmb_click` channel. **Scoping rule (ternary):** the trace fires ONLY through `equip()`. `lmb_click` = user-driven via `InventoryPanel._handle_inventory_click`; `auto_starter` = system-driven via `equip_starter_weapon_if_needed`; **no trace** = `restore_from_save` (F5 reload, save-load) which bypasses `equip()` and directly mutates `_equipped[slot] = inst` + calls `_apply_equip_to_player(inst)`. The Playwright `equip-flow.spec.ts` asserts both positives (`source=auto_starter` at cold boot, `source=lmb_click` after a real Tab→click) and the negatives (no `source=lmb_click` at boot before any user click; neither tag after F5 reload).

**State-integration test bar** (analog of the visual-primitive test bar in `team/TESTING_BAR.md`):

- Tier 1 (mandatory): paired tests for equip / unequip / equip-swap / starter-seed paths must instantiate a **real `Player`** node, not a stub `Node`. Assert `Player.get_equipped_weapon() != null` AND `Inventory.get_equipped("weapon") != null` — one surface passing is not proof the other is wired. See `tests/test_inventory.gd::test_equip_swap_*` and `tests/test_inventory_panel.gd::test_lmb_click_equip_swap_drives_both_surfaces`.
- Tier 2 (mandatory for boot-order changes): integration test must drive the **actual `Main._ready` boot sequence** (or simulate the same `_spawn_player → _load_save_or_defaults → equip_starter_weapon_if_needed` ordering) and assert the post-boot state survives. Test that calls `Inventory.equip` directly bypasses the boot-order surface.
- Tier 3 (mandatory for damage-affecting changes): integration test must drive the **actual `Player.try_attack`** code path and assert the **damage delta on a real Grunt** (`grunt.hp` drops by weapon-scaled amount, not by 1). Not `Damage.compute_player_damage()` in isolation. See `tests/integration/test_starter_weapon_damage_integration.gd::test_lmb_click_equip_swap_real_main_drives_dual_surfaces` for the equip-swap variant.

This is the integration class of `team/TESTING_BAR.md` § "Product completeness ≠ component completeness." The Main.tscn-stub miss and PR #145's stub-Node miss are siblings.

## State-change signals vs. progression triggers — harness enforcement

The combat / level pattern surfaced by PR #155: a signal named `<noun>_<state-verb>` (e.g. `gate_unlocked`, `door_opened`) DOCUMENTS a state change. It MUST NOT be wired directly to a progression trigger (room counter advance, level transition). Progression must be gated on an explicit player-action event (CharacterBody2D `body_entered` on a trigger Area2D, an interact-press, etc.).

**The Playwright harness enforces this discipline at HTML5-build sign-off.** See `tests/playwright/specs/negative-assertion-sweep.spec.ts` (Test 3 — `gate_traversed never precedes gate_unlocked (causality invariant)` + same-tick auto-emission threshold check) and `tests/playwright/specs/ac4-boss-clear.spec.ts` (per-room gate-traversal negative assertions across all 7 multi-mob rooms). The static causality invariant — every `gate_traversed` line in the `[combat-trace]` stream must have a preceding `gate_unlocked emitting` line, with > 200 ms between them — catches PR #155-class regressions automatically.

**Open follow-up:** the Shooter `STATE_POST_FIRE_RECOVERY` state has no explicit ledger trace today (only `_process_post_fire | closing gap` recurrence). Adding `[combat-trace] Shooter.set_state | post_fire_recovery (entered)` is the prerequisite for adding a fourth negative-assertion test that asserts the recovery-state trace fires when expected (not "absence of state X means Y" — the anti-pattern this rule targets).

Future state-change/action-event pairs (aggro/attack, pickup/equip, dialog/advance, save/load) should land their `[combat-trace]` lines AND their negative-assertion test simultaneously. When introducing any `<noun>_<state-verb>` signal, ask: "is there a separate `<noun>_<action-verb>` event that commits to the next thing?" If yes, add both traces and an assertion for both.

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

## GUI focus-consumption vs. Playwright keypresses — close a focus-holding panel with a test-only hook

A class of harness flake surfaced by `equip-flow.spec.ts` Phase 2.5 (tickets `86c9qb7f3` / `86c9qah0f`): **Godot's GUI input system consumes more keys than just `Tab`.** When a focusable `Control` (e.g. an inventory grid `Button` with the default `focus_mode = FOCUS_ALL`) holds keyboard focus, the GUI system intercepts UI-action keys *before* they reach `_unhandled_input`:

- `Tab` — the built-in focus-traversal key ("focus next neighbour").
- `Escape` — bound to the built-in `ui_cancel` GUI action.

Both are swallowed by the focus system while a Control is focused. A spec that clicks an inventory grid cell (grabbing focus on that Button) and then presses `Tab` *or* `Escape` to close the panel will find the panel **stays open** — the keypress never reaches `InventoryPanel._unhandled_input`'s toggle/close handler. The panel staying open means `Engine.time_scale = TIME_SLOW_FACTOR (0.10)` stays in effect and every subsequent spec action runs in 1/10th-speed slow-mo. **Picking a different key does not fix this** — `equip-flow.spec.ts` round-1 swapped `Tab → Escape` and reproduced the panel-stays-open failure 0/5 headed (Devon's peer review).

**The reliable pattern: a test-only direct-close hook handled in `_input()`.** `_input()` runs *before* the GUI focus system (unlike `_unhandled_input()`), so a focused Button cannot swallow the event. `InventoryPanel.force_close_for_test()` (in `scripts/ui/InventoryPanel.gd`, matching the existing `force_click_*_for_test` convention) closes the panel + restores `Engine.time_scale` directly, sidestepping the entire focus-consumption class. It is wired to **F9**, matched by `physical_keycode` in `InventoryPanel._input()` (the proven `DebugFlags._input` Ctrl+Shift+X pattern), with a `test_force_close_inventory` action as a secondary path. The whole handler is gated on `OS.has_feature("web")` — inert on desktop / headless GUT, mirroring the `DebugFlags.combat_trace` web-only gate. The hook emits a `[combat-trace] InventoryPanel.force_close_for_test | open=false time_scale=1` confirmation line so the spec can **positively assert the panel actually closed** (and `Engine.time_scale` was restored) before proceeding — never "press a key and hope it closed".

**Generalised rule:** any Playwright spec that needs to close (or otherwise dismiss) a focus-holding panel after a click landed on a focusable child Control must NOT rely on `Tab`/`Escape`/any GUI-action key reaching `_unhandled_input`. Add a test-only direct-action method on the panel, wire it to a dedicated key handled in `_input()` (gated on `OS.has_feature("web")`), and have the spec assert a confirmation trace. Pattern check: does the spec press a key to dismiss UI immediately after clicking a focusable Control? If yes, it needs the `_input()`-handled hook, not a key-picking lottery.

## Cross-references

- HTML5-renderer-specific quirks (HDR clamp, Polygon2D, service worker cache): `.claude/docs/html5-export.md`
- Orchestration conventions (worktrees, dispatch, ClickUp gates): `.claude/docs/orchestration-overview.md`
- Test bar codification: `team/TESTING_BAR.md`
- Wave post-mortem: `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md`
- Damage formula decision: `team/decisions/DECISIONS.md` `2026-05-02 — Damage formula constants locked`
- Playwright harness: `tests/playwright/` + design at `team/tess-qa/playwright-harness-design.md`
