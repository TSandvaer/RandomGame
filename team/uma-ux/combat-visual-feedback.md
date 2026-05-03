# Combat Visual Feedback — Embergrave M1 (placeholder fidelity)

**Owner:** Uma · **Phase:** M1 · **Decision authority:** Uma owns the call, logged in `DECISIONS.md`. **Implementers:** Devon (player side), Drew (mob side). **Tester:** Tess.

**Trigger:** Sponsor's mid-soak surfaced that combat is *invisible* — even after Devon's pending fix to land hits, there is no swing animation, no hit-flash, no death feedback. M1-blocking. This doc designs the placeholder-fidelity visual language so combat reads on-screen at programmer-art M1 fidelity (colored squares + tweens + simple particles). Real sprite-art animations are M3.

## TL;DR

1. **Player swing** — attack-direction wedge ColorRect (ember `#FF6A2A`) drawn for the hitbox lifetime (100 ms light / 140 ms heavy), plus a 60 ms ember modulate flash on the player. Two-layer cue, both inside the recovery window.
2. **Mob hit-flash** — white modulate `Color(1,1,1,1)` for **80 ms** then tween back to original. Single rule for grunt + charger + shooter + boss.
3. **Mob death** — scale-down to 0.6× + fade alpha to 0 over **200 ms** layered with a 6-particle ember burst (`CPUParticles2D`, palette-matched). `queue_free` happens at end of tween, NOT on `_die`.
4. **Knockback** — visible via the hit-flash + the existing knockback velocity; **no extra cue** for normal mobs. Boss adds a 1-frame screen-shake at 4 logical px (within VD-09 budget).
5. **Hitbox debug-render (P1)** — outlined Area2D shape drawn during hitbox lifetime, gated on new `DebugFlags.show_hitboxes()` flag. Devon adds the flag if implementing.

**Cue durations (one-line summary):** swing-wedge **100 ms light / 140 ms heavy** · player-flash **60 ms** · hit-flash **80 ms** · death-tween **200 ms** · particle-burst **300 ms decay**. All cues fit inside `LIGHT_RECOVERY=180 ms` / `HEAVY_RECOVERY=400 ms` recovery windows.

## Source of truth

- `team/uma-ux/visual-direction.md` — house style, ember accent `#FF6A2A`, camera-shake max 4 logical px (VD-09), pixel-art at 96 px/tile.
- `team/uma-ux/palette.md` — stratum-1 palette, ember-orange ramp `#FFB066` → `#FF6A2A` → `#E04D14` → `#A02E08`, mob-damage popup `#FFFFFF`.
- `team/uma-ux/audio-direction.md` — cue IDs `sfx-player-attack-light/heavy`, `sfx-player-hit-connect-light/heavy`, `sfx-grunt-hit/die`, `sfx-boss-hit/die` (cue-fire timestamps must align with visual-cue start frame).
- `scripts/player/Player.gd` — locked timing constants:
  - `LIGHT_RECOVERY = 0.18` s · `LIGHT_HITBOX_LIFETIME = 0.10` s · `LIGHT_REACH = 28` px · `LIGHT_HITBOX_RADIUS = 18` px
  - `HEAVY_RECOVERY = 0.40` s · `HEAVY_HITBOX_LIFETIME = 0.14` s · `HEAVY_REACH = 36` px · `HEAVY_HITBOX_RADIUS = 22` px
  - `attack_spawned(kind, hitbox)` signal already fires at attack-spawn — bind VFX here.
- `scripts/mobs/{Grunt,Charger,Shooter,Stratum1Boss}.gd` — all four call `_die() → call_deferred("queue_free")` today; the death tween must run **before** queue_free.

Every timing number below derives directly from these constants. No priors, no "typical action-game feedback" reasoning.

---

## 1. Player attack-swing indicator

**Choice (layered, 2 cues):**

**(a) Swing-wedge ColorRect** — most-readable cue. Spawn a child `ColorRect` (or `Polygon2D` triangle if Devon prefers) on the Player, oriented along `_facing`, sized to the hitbox circle radius:
- **Light:** wedge length **28 px** (= `LIGHT_REACH`), wedge half-width **18 px** (= `LIGHT_HITBOX_RADIUS`), color `#FF6A2A` at **alpha 0.55**.
- **Heavy:** wedge length **36 px** (= `HEAVY_REACH`), wedge half-width **22 px** (= `HEAVY_HITBOX_RADIUS`), color `#FF6A2A` at **alpha 0.70** (heavier punch reads stronger).
- **Lifetime:** matches `LIGHT_HITBOX_LIFETIME` (100 ms) / `HEAVY_HITBOX_LIFETIME` (140 ms) — wedge appears at attack spawn, fades out on a tween (`Tween.tween_property(wedge, "modulate:a", 0.0, LIFETIME)`), `queue_free` at tween end.
- **Z-index:** above floor, below player body — the wedge reads as a flash extending from the player, not stamped over them.
- **Heavy-attack hit-stop (60 ms, per VD-07):** when a hit lands, freeze the wedge frame-1 for 60 ms before resuming the fade. This is the M1 placeholder for the hit-stop animation budget.

**(b) Player ember-flash modulate** — punch layer, fires at attack spawn (independent of hit-connect):
- Tween `modulate` from `Color(1,1,1,1)` → `Color(1.4, 1.0, 0.7, 1)` (ember tint, slight luminance boost) over **30 ms**, then back to `Color(1,1,1,1)` over **30 ms**. Total **60 ms**.
- Snug inside both recovery windows; doesn't overlap with hit-flash on the *mob*.

**Rationale:** Wedge alone reads weak in playtest because the player's own ColorRect doesn't change — the eye misses the new sprite. The ember-flash on the player puts the cue *on the cursor* (where the player's eye is) and the wedge puts it *where the hit will land*. Two-layer composition — both cheap, both 100% within timing budget. The wedge is the "where," the ember-flash is the "now."

**Implementation hook (Devon):** subscribe to `Player.attack_spawned(kind, hitbox)` from a child VFX node. Spawn the wedge as a Polygon2D (cleaner than ColorRect for an arc-shape) parented to the Player; lifetime + fade driven by Tween. Player ember-flash is `tween.tween_property(self, "modulate", ember_tint, 0.03).then(...).back_to_white(0.03)`.

**Audio hook (M2):** `sfx-player-attack-light` / `sfx-player-attack-heavy` fire at the **same frame** the wedge spawns (per `audio-direction.md` AD-06).

## 2. Mob hit-flash on take_damage

**Choice: white modulate flash, 80 ms.**

- On every mob's `take_damage(amount, knockback, source)` (Grunt/Charger/Shooter/Stratum1Boss — same rule for all four), tween:
  - `modulate` → `Color(1, 1, 1, 1)` (full white, full alpha) over **20 ms**.
  - hold **20 ms**.
  - tween back to original modulate over **40 ms**.
  - **Total: 80 ms.**
- Only fires when `clean_amount > 0` (skip the i-frame / dead-state early returns at the top of `take_damage` — already there in `_die()` latch).

**Rationale:** Standard option from the dispatch (white-flash) chosen over shake (disorients on a 480×270 internal canvas with 4-logical-px shake budget; better reserved for boss death) and over darken (palette is already low-value; darkening reads as a tile-color shift, not a hit). 80 ms is short enough not to mask the hit-stop's 60 ms but long enough to register at 60 fps (~5 frames). Single rule across all four mob types per dispatch §6 cross-system consistency.

**Edge case:** the second hit before the flash completes — restart the tween from scratch. Each `take_damage` is its own 80-ms cue; flashes don't accumulate or extend. `Tween.kill()` + new tween if a previous flash is still active.

**Implementation hook (Drew):** add an `_on_hit_flash()` private helper to a shared `MobVisuals.gd` if it exists (or inline in each mob's `take_damage`). Tween via `create_tween()`, killed-and-restarted on overlapping hits.

**Audio hook (M2):** `sfx-grunt-hit` / `sfx-boss-hit` (etc.) fire at flash-frame-0 (per AD-09 / spam-fire-once-per-take_damage discipline).

## 3. Mob death feedback

**Choice (layered, 2 cues):** scale-down + fade-out tween + ember-burst particles.

**(a) Scale + fade tween, 200 ms, BEFORE `queue_free`:**

- On `_die()`, instead of `call_deferred("queue_free")`, spawn a death tween:
  - `scale` from current → `Vector2(0.6, 0.6)` over **200 ms** (parallel)
  - `modulate:a` from current → `0.0` over **200 ms** (parallel)
  - On tween-finished: `queue_free()` for real.
- Disable mob `take_damage` (idempotent on `_is_dead = true` latch — already in place per Grunt.gd:343 / Charger.gd:430 / Shooter.gd:354 / Stratum1Boss.gd:551).
- `mob_died` signal still emits at the *start* of `_die()` so `MobLootSpawner.on_mob_died` and room-clear logic fire on the existing frame — visual delay does not gate progression. **This is the critical contract.**

**(b) Ember-burst particles, parallel to (a):**

- `CPUParticles2D` spawned at mob position on `_die()`:
  - **6 particles**, one-shot.
  - Initial velocity 30–60 px/s, random direction in 360° spread.
  - Color ramp: start `#FFB066` (ember light), end `#A02E08` (ember deep) — full ramp from palette.md ember-orange row.
  - Particle lifetime **300 ms**, gravity 40 px/s² (slight upward — embers rise per visual-direction §lighting).
  - Scale: **2×2 logical px each** (stays inside the 4-px camera-shake budget for "discrete sprite" feel).
- Particle node parented to the room (NOT the mob), so it persists past mob `queue_free`. `queue_free` the particle node on `finished` signal.

**Boss death — additional cues (parity rule + climax bump):**

- Same scale-down + fade + ember-burst (above) — keep the language consistent.
- **+** ember-burst particle count bumps to **24 particles** (boss is the climax — same shape, 4× the volume).
- **+** screen-shake **4 logical px** for **150 ms** (within VD-09's 4-px max budget; one-frame impulse, not sustained shake).
- **+** an extra **400 ms** of slow-fade on the boss before queue_free (death-pose hold variant), so the kill registers as the cinematic moment per `boss-intro.md` Beat F.

**Rationale:** Scale-down + fade is the "minimum viable" option from dispatch — it gives the kill a frame of decay before the sprite vanishes, fixes the "they just disappear" complaint, and never delays gameplay (loot spawns on the existing frame via `mob_died`). Particle burst layers a discrete "death happened *here*" cue at the position. Boss gets a climax bump but not a different shape — the language is consistent across all four mob types per §6.

**Implementation hook (Drew):** modify each `_die()` to:
1. Set `_is_dead = true` (already present).
2. Emit `mob_died` (already present).
3. **NEW:** spawn `CPUParticles2D` at `global_position` parented to `get_parent()`.
4. **NEW:** create death tween on `self` (scale → 0.6, modulate.a → 0); on `tween_finished`, call `queue_free()`.
5. Remove the `call_deferred("queue_free")` line — the tween's `tween_finished` callback replaces it.
- Disable hurtbox `monitoring` on tween-start so corpses can't be hit again (belt for the `_is_dead` latch).

**Audio hook (M2):** `sfx-grunt-die` (etc.) fires at tween-start (per AD-09 — once per death, idempotent).

## 4. Knockback visibility

**Choice: no dedicated cue for normal mobs. Boss-only screen shake (already specced under §3 boss-death).**

**Rationale:** Knockback is already mechanically visible via the velocity bump in `take_damage` (`velocity = knockback` line in Player.gd:439 and the equivalent in each mob). Layering the **white hit-flash from §2** with the existing knockback motion is sufficient to read knockback as distinct from "mob walking" — the flash + velocity-spike combo reads as a hit-react. Speed-line trails or color-shifts during knockback would (a) cost authoring time we don't have at M1 fidelity, (b) compete with the §2 hit-flash which already owns the "you got hit" cue.

**Audit-pass guard:** if Tess's playtest shows knockback still doesn't read, the cheap fallback is to **extend the §2 hit-flash to 120 ms when `knockback.length() > 100`** (heavy-attack threshold). This is one extra `if` in the flash helper, not a new cue. Defer to M2 polish if §2 alone passes.

## 5. Hitbox debug-render mode (P1, optional)

**Choice: shipping in this design as a P1 stretch — Devon decides on implementation cost.**

- New flag `DebugFlags.show_hitboxes() -> bool` (Devon adds to `scripts/debug/DebugFlags.gd`):
  - Returns `OS.is_debug_build() and _show_hitboxes_enabled`.
  - Toggled by **Ctrl+Shift+H** (free chord; X is fast-XP, parallel to Hook 2 idiom).
  - Always returns `false` in release builds (compile-out guard, same idiom as `xp_multiplier`).
- When `true`, every Hitbox.gd Area2D draws a **1-px outline** of its CircleShape2D for the duration of `lifetime`:
  - Player attack hitboxes (team_player) → **outline color `#FF6A2A`** (ember; matches the swing-wedge in §1).
  - Enemy attack hitboxes (team_enemy) → **outline color `#D24A3C`** (HP-foreground / aggro red; matches the cross-stratum aggro contract per palette.md PL-11).
  - Outline only — no fill, so multiple overlapping hitboxes remain readable.
- Implementation: `_draw()` on Hitbox.gd plus `queue_redraw()` per physics tick while `lifetime > 0`. `Geometry2D` or `draw_arc(center, radius, 0, TAU, 32, color, 1.0)` — Godot 4 native.

**Rationale:** Cheap dev-utility. Useful for the §1 swing-wedge tuning pass (does the wedge align with the actual hitbox?) and for diagnosing the very class of bug Tess just caught (room-spawned mobs with `mob_def=null` on `mob_died`). Compile-out for release. **P1 — ship if implementation is < 30 min for Devon, otherwise defer.**

## 6. Cross-system consistency

All four mob types — **Grunt / Charger / Shooter / Stratum1Boss** — must use:
- The **same** hit-flash rule (§2: white, 80 ms).
- The **same** death-tween rule (§3a: 200 ms scale 0.6 + fade 0).
- The **same** ember-burst particles (§3b: 6 particles for normal mobs, **24 for boss**).
- The **same** mob_died-emits-at-die-start contract (loot + room-clear timing unchanged).

Boss adds **two** extra cues per §3 boss-death — bumped particle count + screen shake + 400 ms hold. **Shape is identical**, **volume is amplified**. This is the same rule as §3 of `palette.md` (ember accent unchanged, role amplifies per stratum).

**Anti-list:** do NOT give different mob types different death colors (e.g. shooter-blue particles, grunt-red particles). Death is ember for everything — diegetic claim per `palette.md` ember-orange-as-through-line. Stratum-2 (M2) will introduce per-biome death-particle hues, but stratum-1 ships the constant.

## 7. Audio integration hooks (cue-trigger flagging only — wiring is M2)

When audio sourcing lands, the following cue triggers attach at the listed visual-cue moments:

| Visual cue moment                              | Audio cue ID (audio-direction.md) | Notes                              |
|------------------------------------------------|-----------------------------------|------------------------------------|
| Swing-wedge spawn (§1a) light                  | `sfx-player-attack-light`         | Same frame; AD-06.                 |
| Swing-wedge spawn (§1a) heavy                  | `sfx-player-attack-heavy`         | Same frame.                        |
| Mob hit-flash start (§2), light hit            | `sfx-player-hit-connect-light`    | Player perspective.                |
| Mob hit-flash start (§2), heavy hit + hit-stop | `sfx-player-hit-connect-heavy`    | AD-07 hit-stop alignment.          |
| Mob hit-flash start (§2)                       | `sfx-grunt-hit` (or per-mob)      | Mob perspective.                   |
| Death-tween start (§3a)                        | `sfx-grunt-die` (or per-mob)      | AD-09 once-per-death idempotence.  |
| Boss death-tween start (§3 boss)               | `sfx-boss-die` + `sfx-bell-struck` + `sfx-boss-kill-horn` | Per `boss-intro.md` Beat F1/F2.    |
| Knockback (no extra audio)                     | —                                 | Bundled into hit cues.             |
| Player hit (§N/A — Devon already plans)        | `sfx-player-hit-light/heavy`      | Out of scope here; flagged for parity. |

## Implementation checklist

### Devon (player side)
1. Add child VFX spawner node to Player scene (or as a script-only VFX manager subscribed to `attack_spawned`).
2. Implement swing-wedge spawn (§1a) — Polygon2D oriented on `_facing`, lifetime per kind.
3. Implement player ember-flash modulate (§1b) — 60 ms total tween.
4. Add `DebugFlags.show_hitboxes()` flag + Ctrl+Shift+H toggle if shipping §5.
5. (If §5) implement `Hitbox._draw()` outline gated on the flag.

### Drew (mob side)
1. Add `_on_hit_flash()` helper to a shared mob VFX module (or inline in each mob's `take_damage`).
2. Modify `Grunt.gd` `_die()`, `Charger.gd` `_die()`, `Shooter.gd` `_die()`, `Stratum1Boss.gd` `_die()`:
   - Spawn `CPUParticles2D` at position parented to room.
   - Create death tween (scale 0.6 + fade-a 0 over 200 ms).
   - On `tween_finished` → `queue_free()` (replace existing `call_deferred("queue_free")`).
   - For Stratum1Boss: bump particles to 24 + 400 ms hold + 4-px shake.
3. Disable mob `monitoring` (hurtbox) at tween-start to prevent corpse-hit re-entry.

### Tess (acceptance)
1. Run `tests/integration/test_m1_play_loop.gd` post-implementation — must still pass (visual cues are paint-only, do not change `mob_died` contract).
2. Add visual-feedback paired tests (one per cue family): assert tween fires + duration + cleanup. Suggested file: `tests/test_combat_visuals.gd`.

## Tester checklist (yes/no, Tess to run)

| ID    | Check                                                                                                | Pass criterion |
|-------|------------------------------------------------------------------------------------------------------|----------------|
| CV-01 | Light attack spawns ember wedge for ~100 ms in front of player                                       | yes            |
| CV-02 | Heavy attack spawns wider/longer ember wedge for ~140 ms                                             | yes            |
| CV-03 | Player ember-flash modulate is visible for ~60 ms on every attack spawn                              | yes            |
| CV-04 | Grunt flashes white for ~80 ms on every `take_damage` call                                           | yes            |
| CV-05 | Charger flashes white for ~80 ms on every `take_damage` call                                         | yes            |
| CV-06 | Shooter flashes white for ~80 ms on every `take_damage` call                                         | yes            |
| CV-07 | Stratum1Boss flashes white for ~80 ms on every `take_damage` call                                    | yes            |
| CV-08 | Grunt death plays a 200 ms scale-down + fade tween before `queue_free`                               | yes            |
| CV-09 | Charger death plays a 200 ms scale-down + fade tween before `queue_free`                             | yes            |
| CV-10 | Shooter death plays a 200 ms scale-down + fade tween before `queue_free`                             | yes            |
| CV-11 | Stratum1Boss death plays a 200 + 400 ms tween + 24-particle burst + 4-px screen shake                | yes            |
| CV-12 | Ember-burst particles appear at every mob death (6 particles normal, 24 for boss)                    | yes            |
| CV-13 | `mob_died` signal still fires on the same frame as `_die()` start (loot + room-clear unaffected)     | yes            |
| CV-14 | Knockback is visibly distinguishable from walk via the hit-flash + velocity bump                     | yes            |
| CV-15 | (P1) `DebugFlags.show_hitboxes()` toggle (Ctrl+Shift+H) draws hitbox outlines in debug builds         | yes            |
| CV-16 | (P1) Hitbox outlines are ember `#FF6A2A` for player, aggro-red `#D24A3C` for enemy                   | yes            |
| CV-17 | All visual cues fit inside `LIGHT_RECOVERY=180 ms` / `HEAVY_RECOVERY=400 ms` recovery windows        | yes            |
| CV-18 | No visual cue causes a frame-drop on the HTML5 RC build (CPUParticles2D ≤24 particles is safe)      | yes            |
| CV-19 | Camera-shake never exceeds 4 logical px (VD-09)                                                      | yes            |

---

## Open questions

- **Q1 (Drew):** is a shared `MobVisuals.gd` helper preferred, or inline copies in each mob's `_die`? Trade-off is DRY vs. avoiding a new module-level dependency. **Uma's lean: inline copies (4 mobs, ~10 lines each); refactor in M2 if a 5th mob lands.**
- **Q2 (Devon):** is the wedge a Polygon2D or a ColorRect? Polygon2D handles a wedge shape natively; ColorRect needs a rotation hack. **Uma's lean: Polygon2D — cleaner, same render cost.**
- **Q3 (Devon):** ship §5 hitbox debug-render now or M2? Ticket says P1 optional. **Uma's lean: ship now if Devon estimates <30 min; useful for §1 wedge-tuning pass.**
- **Q4 (Tess):** is `tests/test_combat_visuals.gd` paired with this design ticket or with Devon/Drew's implementation tickets? **Uma's lean: paired with implementation tickets — design ticket is spec-only.**
