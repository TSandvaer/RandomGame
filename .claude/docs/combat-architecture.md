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

`Stratum1BossRoom._build_door_trigger` is a known harmonization gap (zero current panic risk because it spawns from `_ready`, not a physics-tick path). Tracking ticket: `86c9p1fgf`. See `team/log/process-incidents.md` for the full history.

## Mob `_die` death pipeline

When a mob's HP reaches 0, the synchronous chain is:

1. `_set_state(STATE_DEAD)`
2. `mob_died.emit(...)` — listeners (notably `MobLootSpawner.on_mob_died`) run synchronously on the same frame
3. `_spawn_death_particles()` — adds a `CPUParticles2D` to the room
4. `_play_death_tween()` — alpha/scale tween over `DEATH_TWEEN_DURATION` (typically 0.4s); arms a parallel `SceneTreeTimer` of the same duration as a safety net
5. On either `tween.finished` OR the timer firing first: `_on_death_tween_finished` → `_force_queue_free()` (idempotent guard via `is_queued_for_deletion()`)

**The parallel SceneTreeTimer is critical** (PR #136). Without it, mobs become functionally immortal if the death tween hangs for any reason — the original P0 that surfaced in the M1 RC investigation.

`MobLootSpawner.on_mob_died` calls `parent_for_pickups.call_deferred("add_child", pickup)` (PR #142 fix) — Pickup root is an Area2D, and adding it during physics flush triggers the same `USER ERROR: Can't change this state while flushing queries` panic. The `_spawn_death_particles` adds in each of 4 mob types also use `room.call_deferred("add_child", burst)` defensively.

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

## `[combat-trace]` diagnostic shim

[`scripts/util/DebugFlags.gd`](scripts/util/DebugFlags.gd) — `DebugFlags.combat_trace(tag, msg)` emits `[combat-trace]` console lines only when `OS.has_feature("web") == true`. Wired into:

- `Player.try_attack / swing_wedge / swing_flash`
- `Hitbox.hit`
- Per-mob `take_damage`, `_play_hit_flash`, `_die`, `_play_death_tween`, `_on_death_tween_finished`, `_force_queue_free`

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

## Cross-references

- HTML5-renderer-specific quirks (HDR clamp, Polygon2D, service worker cache): `.claude/docs/html5-export.md`
- Orchestration conventions (worktrees, dispatch, ClickUp gates): `.claude/docs/orchestration-overview.md`
- Test bar codification: `team/TESTING_BAR.md`
- Wave post-mortem: `team/log/2026-05-html5-visual-feedback-no-op-postmortem.md`
- Damage formula decision: `team/decisions/DECISIONS.md` `2026-05-02 — Damage formula constants locked`
