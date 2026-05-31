## ArchiveSentinel attack visuals render in WebGL2 (invisible-attack soak fix)

**Ticket:** `86c9y7ygj` (W3-T7 — multi-stage, stays `ready for qa test`).
**Base:** `devon/archive-sentinel-v3-spriteswap` (stacked; not yet on main).
**Sponsor re-soak 2026-05-29:** "ArchiveSentinel deals damage with ZERO visible attack — HP just drops, nothing visible."

---

### Confirmed root cause (trace-confirmed, NOT a WebGL2 render divergence)

The cast attack — the **only** attack in phase 1, where the Sponsor engaged at full HP — spawned a bare `Hitbox` via `_spawn_hitbox()`. A `Hitbox` is an `Area2D` + `CollisionShape2D` with **no visual child node**. The construct's modulate-flare telegraph plays on its **own body** at the plinth, not at the cast impact point, and there was never a projectile. So the cast = an invisible Area2D materializes at the captured player position, deals 14 damage, and vanishes in 0.18 s. **Invisible on desktop too — this was an implementation gap, not a renderer bug.**

Contrast that proves the diagnosis: the Shooter's `Projectile.tscn` carries a `Sprite` ColorRect child (that is why Shooter shots are visible). ArchiveSentinel never used `Projectile`; it used the raw damage `Hitbox`.

Trace evidence from the production `?start_room=9` self-soak (build `c7023db`), pre-fix shape:
```
ArchiveSentinel._fire_cast | dir=(...) dmg=14 radius=18 lifetime=0.18 target_pos=(679,627) player_dist=294.5 phase=1
ArchiveSentinel._spawn_hitbox | id=... pos=(679,627) layer=16 mask=2 monitoring=false dmg=14 radius=18 lifetime=0.18
Player.take_damage | amount=14 hp=44->30 src=ArchiveSentinel
```
A `_fire_cast` + `_spawn_hitbox` + `Player.take_damage` chain with **no visual node anywhere** — that is the "HP just drops, nothing visible" the Sponsor saw.

### Phase-2 SLAM verdict — NOT a second invisible-attack regression

The slam telegraph (`ArchiveSentinelSlamIndicator`, `_draw()` + `draw_arc()`) **is** renderer-safe and **is** spawned BEFORE the damage hitbox — the player sees the AOE danger circle, then the (invisible) damage hitbox fires after the 0.55 s windup. The telegraph IS the visual; there is no "invisible damage" surface like the cast had. Slam is phase-2-only (HP ≤ 50%), so the Sponsor never reached it in the cast-only phase-1 soak — that is why it went unverified, not because it was broken.

**Verified rendering empirically** (diag build `85dd96a`, Sentinel hp_base nerfed 700→8 so phase 2 is reachable; see Self-Test Report): drove the boss to phase 2 + provoked the slam at short range. The `draw_arc` AOE circle renders cleanly in WebGL2 — screenshot in the Self-Test Report. Same primitive + z=1 + sub-1.0-channel + modulate-strobe pattern as the S1 boss `SlamTelegraphIndicator` that Sponsor already visually verified in PR #291.

---

### Fix

`ArchiveSentinelCastBolt` — a cosmetic ember bolt (`ColorRect` body, sub-1.0 channels `#FFB066`, `z=+1`, renderer-safe per PR #137) that travels book → captured target at cast-fire time, with a warm impact flash (`#FFF2BF`) on arrival. Room-parented + deferred-add per the physics-flush spawn convention.

**The damage hitbox + dodge model (snapshot-at-telegraph-start) are UNCHANGED** — the bolt is cosmetic, carries no damage / no collision, so the GUT `test_cast_hitbox_spawns_at_captured_player_position` contract holds.

### Test-gap close (Sponsor flagged Playwright should have caught this)

The original assertion gap: nothing asserted that a damage event is accompanied by a visible attack-visual node. Closed at two layers:

1. **`ArchiveSentinelCastBolt._ready` self-emits a renderer-observable trace** (`VISIBLE bolt ... visible=true alpha=N z=N color_rect=true`) AFTER the deferred add lands — so the values are on-screen truth, not spawn-intent. Production self-soak observed `visible=true alpha=1.00 z=1 color_rect=true`.
2. **`stratum2-boss-room.spec.ts`** now asserts:
   - `_fire_cast` present ⟹ `_spawn_cast_bolt` present (no invisible damage).
   - the `CastBolt._ready VISIBLE` trace is present with `alpha>0` (the node is *renderable*, not just spawned).
   - `_fire_slam_hit` present ⟹ `_spawn_slam_indicator` present (slam telegraph implication guard; fires only IF a slam occurs — no fabricated phase-2 harness drive per no-silent-harness-compensation).
3. **`test_archive_sentinel.gd`** new GUT pins:
   - cast bolt presence + visible + modulate.a>0 + z>=0 + ColorRect body + sub-1.0 channels at fire time.
   - the post-`_ready` render-state the visibility trace reports.
   - **phase-2 slam telegraph spawns a visible `draw_arc` indicator** (drive to phase 2 + assert node visible / z>=0 / `_draw` method / radius mirrors hitbox) — deterministic phase-2 render proof.
   - slam indicator color channels sub-1.0 (HDR-clamp safe).

Per `test-conventions.md` § headless≠perception: node-presence + visibility IS assertable headless (and was missed); human-perceptibility stays the Sponsor-soak gate.

---

### Cross-lane integration check (PR #216 gate)

- **`[combat-trace]` contract preserved** — all existing ArchiveSentinel trace lines unchanged; the cast-bolt + slam-indicator traces are additive. New `ArchiveSentinelCastBolt._ready` line uses the same `DebugFlags.combat_trace` shim.
- **Player iframes / Damage formula constants** — untouched. The bolt is cosmetic; the damage hitbox path (`_spawn_hitbox`, dmg, radius, lifetime, dodge snapshot) is byte-identical.
- **RoomGate signal chain** — untouched (boss room owns no RoomGate mob-count; boss_died rides Main's `_wire_mob`).
- **Adjacent specs probed** — `stratum2-boss-room.spec.ts` extended in-place; no other spec references ArchiveSentinel attack traces. No `resources/level_chunks/*.tres` `mob_spawns` mutated (roster-swap audit gate N/A).
- **Regression guard (Done clause)** — the invisible-attack bug class is now pinned at both GUT (node visibility at fire time) and Playwright (renderer-observable visibility trace + damage⟹visible-node implication) layers. A future refactor that drops the bolt or the trace fails CI before merge.

### Out of scope (follow-up filed, NOT bundled)

`boss_hp_mult` is honored by `Stratum1Boss` but **NOT by `ArchiveSentinel`** — so `?start_room=9&boss_hp_mult=0.1` does not nerf the Sentinel, which forced the diag-build approach for the phase-2 slam soak. Filing a follow-up to wire `boss_hp_mult` into ArchiveSentinel for soak parity. No mid-PR scope expansion.
