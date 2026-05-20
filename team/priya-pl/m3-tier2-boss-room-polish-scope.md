# M3 Tier 2 — Boss-Room Polish: Scope + Ranked Tier 2 Cut

**Owner:** Priya · **Authored:** 2026-05-20 (M3 Tier 1 fully closed; Sponsor picked boss-room polish as Tier 2 direction) · **Status:** v1 — Sponsor-input pending on the cut at §4.

This doc inventories the Stratum1Boss + Stratum1BossRoom **as-shipped state**, lists every plausible polish-area candidate, ranks them as ticket-shaped dispatches with rationale, recommends a Tier 2 ship-cut, and surfaces the open questions Sponsor must answer before the cut locks.

**The headline finding:** the boss state machine is complete and the M3W-4 AnimatedSprite2D / hit-flash / attack-telegraph / self-shake pass landed clean, but **the cinematic layer Uma specified in `boss-intro.md` (door slam, ambient fade, nameplate, camera zoom, defeat title card, embers-rising dissolve) was never built.** The signals `entry_sequence_started`, `entry_sequence_completed`, `boss_defeated` fire to **zero subscribers** in production code (only tests subscribe). There is no `BossNameplate.tscn`, no `BossIntroSequence.tscn`, no `BossDefeatedSequence.tscn`, no `CameraShake` autoload. M1 shipped with the timing skeleton + boss combat + the SFX cues PR #278 wired — and not the cinematic surface that makes it feel like a boss.

This means **Tier 2 polish has a wide canvas**: anywhere from "small feel tweaks on what already works" to "build the missing cinematic layer Uma already designed." Choosing where to draw the line is the load-bearing call in §4.

---

## TL;DR

1. **§1 inventory** — boss combat (state machine, melee, slam, phase transitions, death pipeline) is wired clean. M3W-4 visual layer (AnimatedSprite2D + red attack-telegraph + soft-red hit-flash + 4-logical-px self-shake + 24-particle death burst) shipped end-to-end. PR #278 SFX cues fire (mob-hit, boss-die, attack-telegraph, attack-impact). **Nothing in the cinematic layer is wired** — boss-intro signals fire to nobody; no BGM crossfade to boss music; no time-slow on phase transition; no defeat title card; no door slam; no nameplate.
2. **§2 candidates** — 17 plausible polish-area candidates across 5 axes (feel/animation, telegraph clarity, intro beat, defeat beat, audio-visual coherence). Many are "Uma already designed this; nobody built it."
3. **§3 ranked tickets** — 10 dispatch-shaped tickets, P0 to P3. Top 5 deliver the biggest perceived-quality lift per dev-hour; bottom 5 are real polish but acceptable-deferral.
4. **§4 recommended cut — 4 tickets, ~2 weeks of dispatch:** boss-room BGM crossfade wiring (P0), hit-pause on player-on-boss hits (P0), phase-transition world-time-slow (P0), defeat title-card beat (P1). Defers door-slam, full nameplate, embers-rising dissolve, camera zoom to Tier 3 / backlog.
5. **§5 open questions** — 4 items. Biggest: do we ship Uma's full `boss-intro.md` spec as-designed (heavy lift but already-designed), or curate the 5-7 highest-impact beats and let the rest sit?

---

## Source of truth

- **`team/uma-ux/boss-intro.md`** — Uma's binding spec (30 acceptance criteria BI-01 through BI-30; full beat-by-beat for entry / phase transition / defeat). This is the canonical reference; Tier 2 either implements subsets of it or explicitly defers them.
- **`team/uma-ux/combat-visual-feedback.md`** §3 (boss-death climax additions) — currently implemented at the boss-self-shake + 24-particle + 400 ms hold layer.
- **`scripts/mobs/Stratum1Boss.gd`** — boss controller (1237 lines as-shipped); contains every constant + signal + state inventoried in §1.
- **`scripts/levels/Stratum1BossRoom.gd`** — room controller; signal-emitter for entry sequence + boss-defeated routing; loot pipeline wired through Main.
- **`.claude/docs/audio-architecture.md`** — `AudioDirector` autoload + S2 boss crossfade pattern (template for the S1 equivalent that doesn't exist yet).
- **`.claude/docs/combat-architecture.md`** § "M3W-1 realized implementation" + Hitbox encapsulated-monitoring contract — telegraph + hit-flash patterns Tier 2 work must preserve.
- **PR #278** — last shipped audio-feel pass; SFX cues only (no BGM crossfade). Sponsor-approved soak 2026-05-19.
- **`team/priya-pl/m3-design-seeds.md`** — broader M3 strategic seeds (multi-character, hub-town, persistent-meta, character-art); Tier 2 boss-room polish is a **lateral** lane to those tracks, not a substitute. The boss-room polish work does not block any §1-§4 design-seed track.

---

## §1 — Stratum1Boss / Stratum1BossRoom current-state inventory

Read directly from production source. **Unknown** marked where the answer needs Drew or Devon to spike.

### §1.1 Combat mechanics (FULLY WIRED)

| Surface | Implementation | Source |
|---|---|---|
| 3-phase state machine | Phase 1 / 2 / 3; transitions at 66% / 33% max HP; idempotent latch on each boundary | `Stratum1Boss.gd` §`_check_phase_boundaries`, §`PHASE_*_HP_FRAC` |
| Phase-transition window | 0.6 s stagger + damage immune window (`STATE_PHASE_TRANSITION`); cancels in-flight attacks; resets velocity | `Stratum1Boss.gd` §`_begin_phase_transition` / `_finish_phase_transition` |
| Phase 3 enrage | move speed × 1.5, recovery × 0.7 (30% shorter); applies on `_finish_phase_transition` for P3 | `Stratum1Boss.gd` §`ENRAGE_SPEED_MULT` / `ENRAGE_RECOVERY_MULT` |
| Melee attack | 0.55 s telegraph windup → swing → 0.65 s recovery; reach 44 px, radius 28 px, lifetime 0.14 s | `Stratum1Boss.gd` §`_begin_melee_telegraph` / `_fire_melee_swing` |
| Slam attack (P2+) | 0.50 s telegraph (marker hitbox) → omnidirectional slam (radius 80 px) → 0.85 s recovery; 4 s cooldown | `Stratum1Boss.gd` §`_begin_slam_telegraph` / `_fire_slam_hit` |
| Dormant intro fairness | `STATE_DORMANT` rejects damage + skips AI; only wakes via `wake()` (called by room's deferred `_assemble_room_fixtures` + 1.8 s timer) | `Stratum1Boss.gd` §`take_damage` dormant guard; `Stratum1BossRoom.gd` §`trigger_entry_sequence` |
| Player teleport-into-room fix | Room defers `_assemble_room_fixtures` out of physics-flush; auto-fires `trigger_entry_sequence` once `_boss != null` (no body_entered required) | `Stratum1BossRoom.gd` §`_ready` |
| Boss-died emission | Fires at START of death sequence (frame 0), payload `(mob, position, mob_def)` — same shape as Grunt/Charger so loot pipeline reuses | `Stratum1Boss.gd` §`_die` |
| Loot drop | Single pipeline via Main's `MobLootSpawner` subscribed to `boss_died` through `_wire_mob`. Room itself no longer spawns loot (PR fixed dual-spawn that produced uncollectable pickups) | `Stratum1BossRoom.gd` §class docstring "Boss loot single-pipeline rule" |
| Stratum-exit unlock | Deferred `_stratum_exit.activate()` post-`boss_died` (clears physics flush); emits `stratum_exit_unlocked` signal Main subscribes to | `Stratum1BossRoom.gd` §`_on_boss_died` |

### §1.2 Visual feedback (M3W-4 SHIPPED, partial)

| Surface | Status | Source |
|---|---|---|
| AnimatedSprite2D root sprite | Wired; `walk_s` / `walk_<dir>` state-driven; `atk_telegraph`, `atk`, `slam_telegraph`, `slam`, `hit_<dir>`, `die_<dir>` keyed per direction | `Stratum1Boss.gd` §`_play_anim` / `_compute_facing_dir_suffix` |
| Direction resolver | 8-octant `atan2`-based, mirrors Grunt's M3W-3 baseline; chases-toward-player for facing | `Stratum1Boss.gd` §`_vec_to_dir_suffix` |
| Hit-flash | 80 ms 3-stage tween (in/hold/out) using `HIT_FLASH_TINT` soft-red on AnimatedSprite2D `modulate`; resolver branches for ColorRect/sprite-less test paths | `Stratum1Boss.gd` §`_play_hit_flash` |
| Attack-telegraph red tint | 80 ms in → hold for telegraph duration → 80 ms out; vivid red `(1.0, 0.25, 0.25)`; same 3-branch resolver | `Stratum1Boss.gd` §`_play_attack_telegraph` |
| Death tween | 400 ms hold → 200 ms scale-to-0.6 + alpha-to-0 parallel tween; SceneTreeTimer safety-net | `Stratum1Boss.gd` §`_play_boss_death_sequence` |
| Death particles | 24-particle CPU ember burst, ember-light→ember-deep ramp, parented to room (persists past queue_free), deferred add_child for physics-flush safety | `Stratum1Boss.gd` §`_spawn_death_particles` |
| Climax shake | 150 ms three-leg jiggle on boss's own position (±4 logical px); inside VD-09 budget | `Stratum1Boss.gd` §`_play_climax_shake` |
| Slam telegraph marker | Zero-damage Hitbox spawned at slam-windup start (radius 80 px, lifetime = telegraph duration); visible only via `swing_spawned(SWING_KIND_SLAM_TELEGRAPH, ...)` | `Stratum1Boss.gd` §`_begin_slam_telegraph` |

### §1.3 Audio (PR #278 SHIPPED)

| Cue | Source signal | Wired |
|---|---|---|
| `sfx-mob-hit` | `damaged(amount>0)` | YES |
| `sfx-boss-die` | `boss_died` (distinct cue from `sfx-mob-die`) | YES |
| `sfx-attack-telegraph` | `swing_spawned(SWING_KIND_SLAM_TELEGRAPH)` | YES |
| `sfx-attack-impact` | `swing_spawned(SWING_KIND_MELEE \| SWING_KIND_SLAM_HIT)` | YES |
| BGM crossfade to boss music | (no S1 crossfade method exists; only `crossfade_to_boss_stratum2`) | **NO** |
| `door_slam_heavy.ogg` (Uma BI-01) | n/a — door-slam never wired | **NO** |
| `boss_wake_stratum1.ogg` (Uma BI-06) | n/a — boss-wake stinger never wired | **NO** |
| `bell_struck.ogg` on nameplate (Uma BI-04 / F1) | n/a — nameplate never built | **NO** |
| `phase_break_stratum1.ogg` (Uma BI-18) | n/a — phase-break sting never wired | **NO** |
| `boss_kill_horn.ogg` (Uma F2) | n/a — defeat horn never wired | **NO** |
| `door_unlock_chime.ogg` (Uma F3) | n/a — door unlock chime never wired | **NO** |

### §1.4 Cinematic layer (UNIMPLEMENTED — Uma designed, nobody built)

| Surface | Spec | Implementation | Source |
|---|---|---|---|
| Door slam behind player (BI-01, BI-02) | 0.4 s, screen-shake pulse, lock-bar ember-flash, locked-sprite swap | **NONE.** Boss room has no animated door; walls are static `ColorRect` blocks. There is a `WallSouth` static body but no door-slam visual / lock-state. | `Stratum1BossRoom.tscn` — only ArenaFloor + 4 walls + (deferred) door-trigger Area2D |
| Ambient cut over 0.6 s (BI-03) | Stratum-1 ambient fades to 0% on entry | **NONE.** No S1 ambient is ever started or stopped in M1 — S1 ambient cue doesn't exist as a runtime stream yet | `AudioDirector.gd` — only S2 ambient methods (`play_stratum2_ambient`); no S1 equivalent. The S1 ambient cue ID is mentioned in `audio-direction.md` but no asset / runtime wiring |
| Vignette deepening to 70% (BI-04) | Room vignette transitions 30% → 70% on entry | **NONE.** No global vignette layer exists; rooms render flat | n/a |
| Camera zoom to 1.25× (BI-05) | Camera eases in to 1.25× internal pixel scale, anchors midpoint player/boss | **NONE.** There is no `Camera2D` in the M1 play loop — every room renders without one. The boss self-shake exists *because* there's no camera (see `Stratum1Boss.gd._play_climax_shake` comment: "When Devon adds a real Camera2D in M2 this can be re-routed to a CameraShake autoload") | n/a |
| Boss wake animation + brass stinger (BI-06) | 0.5 s wake anim + `boss_wake_stratum1.ogg` at T+0.6 | **PARTIAL.** Wake state-transition happens (`STATE_DORMANT → STATE_IDLE`); `walk_s` plays. No dedicated wake animation key. No stinger. Boss "stands up" is just the same idle animation it had pre-wake. | `Stratum1Boss.gd` §`wake` |
| Boss nameplate (BI-07 through BI-15) | 480×56 top-anchored HUD nameplate with 3 phase segments + ghost-damage drain + pulse-at-low-HP | **NONE.** No `BossNameplate.tscn` exists; HUD has no boss-nameplate region. Phase progression is invisible to the player except through observable behavior (boss starts slamming = P2). | n/a |
| BGM crossfade to boss music (BI-Beat 5) | `boss_loop_stratum1.ogg` fades in over 0.6 s at T+1.8 | **NONE for S1.** S2 has `crossfade_to_boss_stratum2`; S1 boss-room never crossfades anything | `AudioDirector.gd` — S2-only |
| Phase-transition world-time-slow to 30% (BI-16, BI-17) | World time drops to 30% for 0.6 s on each phase boundary | **NONE.** Boss is stagger+damage-immune during the 0.6 s window (mechanic guard present) but `Engine.time_scale` is never modified. The world keeps moving at 100%. | `Stratum1Boss.gd` §`_begin_phase_transition` doctring: "world-time is conceptually slowed (Uma: 30% world-time, but the boss controller doesn't drive Engine.time_scale — that's Devon's BossDefeatedSequence / cinematic layer's job)" — i.e., Drew shipped the boss-side guarantee; Devon never shipped the cinematic-layer time-scale |
| Phase-break ember-flash outline + tritone sting (BI-18) | Boss sprite ember-flash + `phase_break_stratum1.ogg` | **NONE.** No phase-break visual / audio cue fires on `phase_changed`. The 0.6 s damage-immune window passes invisibly to the player. | n/a |
| Hit-pause / hitstop on player-hits-boss (`combat-visual-feedback.md` §1 "Heavy-attack hit-stop 60 ms" + boss-side) | 60 ms freeze on hit-connect to amplify weight | **NONE.** No `Engine.time_scale` modulation on player-hit-mob; the comment in `combat-visual-feedback.md §1 (a)` references a "M1 placeholder for the hit-stop animation budget" but nothing implements it. | n/a (searched `hit_pause`, `hitstop`, `hit_stop` — zero matches) |
| Time-freeze 0.3 s on final hit (Uma F1) | First true freeze in M1 design language; combat + music cut hard; bell strike at T+0.1 | **NONE.** `boss_died` fires synchronously; world continues at 100%. Boss music doesn't cut (because boss music isn't playing — see BGM row above). The 400 ms hold on the death tween creates a *visual* held moment but doesn't freeze the world. | `Stratum1Boss.gd` §`_play_boss_death_sequence` (visual hold only) |
| Embers-rising dissolve (Uma F2) | 0.9 s upward-rising ember dissolve + camera ease-in to 1.5× + sustained warm horn | **PARTIAL.** 24-particle CPU ember burst (300 ms lifetime, slight upward gravity, ember-light→ember-deep ramp) **plus** 400 ms hold + 200 ms scale/fade death-tween. **But:** no camera zoom (no camera), no horn cue, no vignette deepening, no "rising over 0.9 s" — the burst is a single explosive emission, not a sustained rise. | `Stratum1Boss.gd` §`_spawn_death_particles` |
| Defeat title card "The Warden falls." + "STRATUM 1 CLEARED" subtitle (Uma F3) | 12 px caps wordmark, 0.8 s hold | **NONE.** No title-card UI surface exists | n/a |
| Door unlock chime + lock-bar ember-flash (Uma F3) | `door_unlock_chime.ogg` + 1-frame ember-flash on lock-bar | **PARTIAL on mechanic.** StratumExit activates on `boss_died` (deferred) — but there's no door / lock-bar visual; the StratumExit is a separate portal node, not the entry-door. The entry-door is the door-trigger Area2D, which has no visual sprite. | `Stratum1BossRoom.gd` §`_on_boss_died` |
| Stratum-1 ambient resumes at 60% (Uma F4) | Post-defeat ambient resumes | **NONE.** No S1 ambient stream exists in M1 runtime audio (see BI-03 row). | `AudioDirector.gd` |
| Skip flag (BI-21, BI-22) | After first boss kill, intro skips on movement key; first-ever kill not skippable | **NONE.** No `Player.first_boss_kill_seen` flag exists; no skip handling | n/a |
| HUD top-right `STRATUM 1 · BOSS` red treatment (BI-20) | HUD flips to boss-treatment during fight | **NONE.** No HUD context-region in M1; the HUD scaffolding for `STRATUM` context never landed | n/a |

**Net read:** the cinematic layer's gap is **wide**. Uma specified 30 BI-criteria; ~6 are partially implemented (boss combat fairness during intro, death visual hold, particle burst, exit unlock, single-cue audio on hit/die, phase-transition stagger-immunity); ~24 are unimplemented. The boss is *defeatable* (M1 acceptance #6), but it does not currently *feel* like a boss.

### §1.5 Architectural readiness for Tier 2 work

What's **ready to receive polish work** without spike work:

- `entry_sequence_started` + `entry_sequence_completed` signals fire on Stratum1BossRoom at the correct moments (room load → 1.8 s timer → wake). Subscribers can hang cinematic-layer work off these signals without changing the controller. — Verified read of `Stratum1BossRoom._on_door_trigger_body_entered` + `_complete_entry_sequence`.
- `boss_died` fires synchronously on Stratum1Boss + `boss_defeated` re-emits from Stratum1BossRoom. Subscribers can hang defeat-beat work off either signal. — Verified read of `Stratum1Boss._die` + `Stratum1BossRoom._on_boss_died`.
- `phase_changed(new_phase: int)` fires exactly once per boundary with idempotent latch. Subscribers can hang phase-break VFX/audio off this without worrying about hit-spam re-fires. — Verified read of `Stratum1Boss._check_phase_boundaries` + `_finish_phase_transition`.
- `damaged(amount, hp_remaining, source)` already provides the data needed for a nameplate health-bar driver (current HP + max HP via `get_max_hp()`). — Verified.
- `AudioDirector.crossfade_to_boss_stratum2()` is the template; adding `crossfade_to_boss_stratum1()` is a single-method add + new S1 boss BGM asset.

What's **NOT ready** and would need a spike:

- **Camera2D** — there is no camera in the M1 play loop (rooms render in screen-space). Adding camera-zoom (BI-05, F2) or screen-shake-via-camera requires Devon to land a Camera2D autoload **first**. **unknown — needs Devon spike to confirm whether a Camera2D drop-in survives the existing room-load pipeline + HTML5 export, or whether it surfaces latent assumptions.**
- **Global vignette layer** — no CanvasLayer-based vignette exists. Adding vignette-deepening (BI-04, F2) requires Uma+Drew to author a vignette CanvasLayer surface. **unknown — needs Uma direction first (palette + opacity ramp), then Drew implementation.**
- **HUD context region** — no top-right HUD context-region for `STRATUM 1 · BOSS` (BI-20). Adding it requires Devon to extend the HUD scaffolding. **unknown — needs Devon spike on current HUD shape.**
- **S1 ambient stream** — no S1 ambient OGG exists in `audio/`. Uma's audio-direction.md references the cue ID but no asset shipped. **unknown — Sponsor would need to commission or generate the placeholder, mirroring the S2 ambient composer pattern.**
- **Door visual** — `Stratum1BossRoom.tscn` has 4 wall blocks but no animated door sprite. Adding a door-slam visual (BI-01, BI-02) requires Drew to author a door scene + sprite. **unknown — needs Uma direction first (door visual style), then Drew implementation.**

These "unknowns" gate four of the heavier Tier 2 / Tier 3 tickets in §3 below.

---

## §2 — Polish-area candidates (the full canvas)

Every plausible improvement axis grouped by Uma's design taxonomy.

### §2.1 Feel / animation

1. **Player-on-boss hit-pause (hitstop).** 60 ms `Engine.time_scale = 0.0` freeze on every successful player hit lands on the boss, restoring on a SceneTreeTimer. Amplifies weight; cheap. `combat-visual-feedback.md §1 (a)` calls this out as M1 placeholder for the hit-stop budget but never landed. **Per `engine-time-scale` consideration:** the freeze must not gate the death pipeline (the contract is `boss_died` fires at frame 0). One safe shape: freeze only while boss is alive + not in phase-transition.
2. **Slam aftershock.** Boss slam currently fires the omnidirectional hitbox and that's it. Adding a delayed (300-500 ms post-slam) ember-cracks ColorRect / Polygon2D burst on the slam's outer radius would communicate "the floor shook." Cheap (one Polygon2D per slam, fade-out tween). Sponsor-language match: "slam aftershock" was explicit in the candidate brief.
3. **Boss intro stand-up animation.** Currently the boss plays `walk_s` from `_ready` through wake. Adding a dedicated `wake_<dir>` animation key (4f or 8f stand-up) would give Beat 3 the "unfurls / lights its ember" tell Uma specified (BI-06). Asset work: Drew adds the animation key to `Stratum1Boss.tres` + plays it from `wake()` before transitioning to `walk_<dir>`.
4. **Phase-break ember-flash + boss step-back.** Uma BI-18 + "boss takes a step back, ember-pulses, takes a step forward." Currently the 0.6 s phase-transition window is mechanically present but visually invisible. Adding a 1-frame ember-flash outline tween + an optional 0.3 s step-back velocity nudge would communicate "boss responds to your pressure."
5. **Camera shake on slam impact.** Boss already self-shakes on death. Extending the same shake to the slam-fire moment (smaller magnitude, ~2 logical px) would make the slam feel weighty. Reuses existing `_play_climax_shake` shape.
6. **Hit-flash brightness escalation per phase.** P3 enraged boss hit-flash could read brighter / longer (e.g., 100 ms vs 80 ms, or a slightly more saturated red) to communicate "boss is hurting more." Cheap (constant swap based on `phase`).

### §2.2 Telegraph clarity

7. **Slam telegraph visible indicator.** Currently the slam telegraph fires a zero-damage Hitbox marker — invisible to the player without `DebugFlags.show_hitboxes()`. Uma BI / `combat-visual-feedback.md §1` implies a visible danger-zone read. Adding a Polygon2D-circle outline (ember-orange, fade-in over 80 ms, hold for telegraph duration, fade-out on slam-fire) would give the player the "back off" read. **High player-impact, low cost.**
8. **Melee telegraph wedge.** Boss melee is currently telegraphed by attack-telegraph red-tint on the sprite. Adding a directional swing-wedge ColorRect (like the player's, but reverse-color-coded — ember red rather than ember orange) on the telegraph would communicate "the swing is coming from this direction." Lower-impact than slam (melee is shorter range and reach is small) but visible cue improvement.
9. **Below-10% HP "imminent transition" pulse.** Uma BI-15 specifies a pulsing border at <10% HP within the current phase. Without a nameplate (BI-15 lives on the nameplate), the pulse could land on the boss sprite itself — an ember-orange outline tween that pulses at 1.5 Hz when the boss is <10% HP into the next phase boundary. Communicates "phase break is coming." Cheap.

### §2.3 Intro beat (Beats 1-5)

10. **BGM crossfade to S1 boss music on entry.** Add `crossfade_to_boss_stratum1()` to AudioDirector (mirror of S2 method); add `mus-boss-stratum1.ogg` asset (synthesis-placeholder per audio-direction.md §6 pattern); wire `Stratum1BossRoom.entry_sequence_completed` to fire the crossfade. Uma BI-Beat-5. **Largest single-cue uplift the boss room can receive.**
11. **Door slam visual + audio.** Author a door sprite scene (Drew + Uma direction); add it to `Stratum1BossRoom.tscn`; play door-slam animation + `door_slam_heavy.ogg` on `entry_sequence_started`. Heavy lift (new asset + new scene). Uma BI-01, BI-02.
12. **Boss nameplate (Uma BI-07 through BI-15).** Author `BossNameplate.tscn` (480×56, 3 phase segments, ember-orange separators, ghost-damage drain, low-HP pulse). Wire to `Stratum1BossRoom.entry_sequence_completed` to slide in over 0.4 s. Heavy lift; biggest visual surface in the canvas. Uma already specified the spec in `boss-intro.md`.
13. **Camera zoom 1.25× during intro (gated on Camera2D).** Requires Camera2D autoload to exist first. Uma BI-05. **Deferrable** without losing the rest of the intro beat.
14. **Vignette deepening.** Requires vignette CanvasLayer to exist first. Uma BI-04. **Deferrable.**
15. **HUD context-region red `STRATUM 1 · BOSS` treatment.** Requires HUD scaffolding extension. Uma BI-20. **Deferrable.**

### §2.4 Defeat beat (Beats F1-F4)

16. **Phase-transition world-time-slow + hit-pause "freeze on final hit".** Combined cue: `Engine.time_scale = 0.3` for 0.6 s on each `phase_changed`, scaling back over 0.2 s; `Engine.time_scale = 0.0` for 0.3 s on `boss_died` then restored. Uma BI-16, BI-17, F1. Big perceived-impact; one constant set + two signal handlers. Must respect "boss_died fires at frame 0" contract — Engine.time_scale is set AFTER `boss_died.emit()` returns. **High player-impact, low cost.**
17. **Defeat title card "The Warden falls."** Author `BossDefeatedTitleCard.tscn` (CanvasLayer with off-white wordmark text + "STRATUM 1 CLEARED" subtitle). Wire to `Stratum1BossRoom.boss_defeated`. Reads `MobDef.display_name`. 0.8 s hold + 0.4 s fade-in/out. Uma F3. **Medium lift, big perceived impact** — the kill currently lands without ceremony.

### §2.5 Audio-visual coherence

(All "audio-visual" candidates listed in §2.3 and §2.4 as they map to specific intro / defeat beats. Two extras:)

18. **Stratum-1 ambient stream wiring.** No S1 ambient stream exists in M1 runtime. Adding `play_stratum1_ambient()` + `stop_stratum1_ambient()` + the placeholder OGG would let the ambient-fade-out on boss entry (BI-03) and ambient-resume post-defeat (F4) ship. Foundation for several beats. Sponsor commission / placeholder composer required. **Spike-shaped — Uma direction first, then composer + integration.**
19. **Phase-break sting + tritone tension chord.** Uma BI-18. Single-cue add to `AudioDirector` (`play_sfx(SFX_PHASE_BREAK)`); placeholder synthesized via `compose_sfx_m3w7.py` extension pattern. Wires to `Stratum1Boss.phase_changed`. Cheap.

---

## §3 — Ranked ticket list

Tickets sized as P0 (must-have for Tier 2), P1 (high-impact polish), P2 (deferrable polish), P3 (Tier 3+ / spike-gated).

### P0 — high impact, low-to-medium cost, no spike gate

#### T1 — feat(audio|boss-room): wire S1 boss BGM crossfade on entry-sequence-completed

- **Working title:** `feat(audio|boss-room): wire S1 boss BGM crossfade on entry-sequence-completed`
- **One-line scope:** Add `AudioDirector.crossfade_to_boss_stratum1()` (mirror of S2 method); ship `mus-boss-stratum1.ogg` placeholder via composer extension; subscribe `Stratum1BossRoom.entry_sequence_completed` to fire the crossfade. Pre-fight, no BGM is playing; this kicks off the boss BGM at T+1.8 with a 0.6 s fade-in.
- **Suggested owner:** **Devon** (audio wiring + composer extension match his lane; light Uma touch on the placeholder direction if Uma cares to differentiate from S2). Could also be Drew if Devon is loaded.
- **Effort:** **M** — composer extension (~30 min following S2 pattern), `AudioDirector` method add (~30 min mirror of S2), wire (single line in Stratum1BossRoom), paired test (~1 hr — mirrors `test_s2_audio_triggers.gd`), Self-Test Report + HTML5 audio-playback gate per `.claude/docs/audio-architecture.md`.
- **Acceptance:**
  - `AudioDirector.crossfade_to_boss_stratum1(fade_ms)` method exists with S2-mirror semantics + idempotence + role-swap on finalize.
  - `mus-boss-stratum1.ogg` exists at `res://audio/music/stratum1/`; deterministic composer output (`compose_stratum1.py` or extension of existing).
  - `Stratum1BossRoom.entry_sequence_completed.connect(_on_entry_sequence_completed_audio)` wires the crossfade; idempotent on triple-wire.
  - Paired GUT test asserts crossfade fires on entry-sequence-completed emission + the right stream-path lands on `_last_bgm_path`.
  - HTML5 release-build Self-Test Report includes audible verification + console-clean confirmation.
- **Dependencies:** None.

#### T2 — feat(combat|boss|player): hit-pause on player-hits-boss and boss-died (Engine.time_scale freeze)

- **Working title:** `feat(combat|boss|player): hit-pause on player-on-boss hits and boss-died final-freeze`
- **One-line scope:** Add a 60 ms `Engine.time_scale = 0.0` hit-pause on every Player→Boss successful hit-connect; add a 300 ms time-freeze on `boss_died.emit()` (after the signal fires — payload subscribers run at full speed). Restore via SceneTreeTimer.
- **Suggested owner:** **Drew** (boss + combat lane; player-side Player.gd touch coordinates with Drew's combat side).
- **Effort:** **M** — add `hit_pause(duration)` method to a small autoload or to `Stratum1Boss` itself (~1 hr); subscribe to Hitbox-hits-boss path (~1 hr; will need to identify the hit-connect signal — `Hitbox._on_body_entered` chain → Boss.damaged or a dedicated hit-connect on Hitbox); subscribe to `Stratum1Boss.boss_died` for the longer freeze (~30 min); paired tests for both shapes (~1.5 hr — assert `Engine.time_scale` transitions + recovery + that mob loot still spawns at freeze-time-0). Coordinate with §1.5 unknowns on the boss-died ordering contract.
- **Acceptance:**
  - Player-light-hit on boss → `Engine.time_scale` drops to 0.0 for 60 ms, restores to 1.0 over 1 frame.
  - Player-heavy-hit on boss → same shape, 100 ms duration (heavy = longer hit-pause; mirrors VD-07 budget).
  - Boss-died → 300 ms freeze AFTER `boss_died` signal handlers complete; loot still spawns, exit-unlock still fires, no race.
  - Phase-transition (boss damage-immune) → no hit-pause (no hit lands).
  - Boss in `STATE_DORMANT` → no hit-pause (hit ignored anyway).
  - Paired GUT tests assert all four cases + recovery.
  - HTML5 Self-Test Report: subjectively feels "punchier"; no visible time-skips on subsequent player input.
- **Dependencies:** None.

#### T3 — feat(boss|cinematic): phase-transition world-time-slow

- **Working title:** `feat(boss|cinematic): phase-transition world-time-slow to 30% for 0.6 s on phase_changed`
- **One-line scope:** On `Stratum1Boss.phase_changed(new_phase)`, set `Engine.time_scale = 0.3` for 0.6 s, then ramp back to 1.0 over 0.2 s. The boss is already stagger+damage-immune during this window (existing mechanic). Add ember-flash outline tween on the boss sprite during the slow + `phase_break_stratum1.ogg` sting cue. Maps to Uma BI-16, BI-17, BI-18.
- **Suggested owner:** **Drew** (boss lane; cinematic-layer surface naturally bundles with T2's hit-pause work since both are `Engine.time_scale` modulation patterns).
- **Effort:** **M** — phase-break visual tween (~1 hr; uses existing `_play_attack_telegraph` 3-branch resolver pattern); SFX cue add (~30 min — extend `compose_sfx_m3w7.py` for the placeholder); paired tests (~1.5 hr — assert time-scale transitions + the existing damage-immune-during-transition mechanic still holds + cue fires once per boundary). Coordinate with T2 hit-pause to avoid `Engine.time_scale` collision (if a hit-pause is mid-fire when phase-transition starts, the phase-transition wins).
- **Acceptance:**
  - `phase_changed.emit(PHASE_2)` triggers 0.6 s of `Engine.time_scale = 0.3` followed by 0.2 s ramp to 1.0.
  - Same for `PHASE_3`.
  - Boss sprite ember-flash outline tween plays for the full 0.6 s window.
  - `sfx-phase-break` placeholder SFX cue fires once per boundary (no spam-fire from hit-spam thanks to existing idempotent latch).
  - Hit-pause (T2) is suppressed during phase-transition window (no time-scale collision).
  - Paired GUT tests; HTML5 Self-Test Report shows time-slow visually.
- **Dependencies:** T2 (for time-scale collision handling) — can land independently if T2 deferred but coordinate the time-scale ownership pattern.

### P1 — high impact, medium cost

#### T4 — feat(ui|boss): defeat title card "The Warden falls." + "STRATUM 1 CLEARED" subtitle

- **Working title:** `feat(ui|boss): defeat title card and stratum-cleared subtitle (Uma F3)`
- **One-line scope:** Author `BossDefeatedTitleCard.tscn` — CanvasLayer with two Labels (wordmark font, off-white #E8E4D6) — that reads `MobDef.display_name` to template `"{name} falls."`, sub-labeled `STRATUM 1 CLEARED`. Subscribes to `Stratum1BossRoom.boss_defeated`. Fades in over 0.4 s at T+1.2 post-death, holds 0.8 s, fades out over 0.4 s. Uma F3.
- **Suggested owner:** **Uma direction first** (font selection, copy review, layout sketch — 1-2 hr), **then Devon** (scene authoring + signal wiring — UI surface matches his HUD lane; ~3-4 hr).
- **Effort:** **M-L** — Uma direction ~2 hr; Devon scene + wiring ~4 hr; paired GUT test for "title card scene exists + reads display_name correctly" + Playwright spec for "title card visible post-defeat" ~2 hr; HTML5 visual-verification gate per `.claude/docs/html5-export.md`.
- **Acceptance:**
  - `BossDefeatedTitleCard.tscn` exists with two Labels (title + subtitle).
  - Title text templates `"{MobDef.display_name} falls."` — M1 stratum-1 boss `display_name` resolves to `"WARDEN OF THE OUTER CLOISTER"` per `boss-intro.md`. Subtitle reads `STRATUM 1 CLEARED`.
  - Fade-in / hold / fade-out timings match Uma F3 (0.4 / 0.8 / 0.4 s).
  - Subscribes to `Stratum1BossRoom.boss_defeated` signal; idempotent on triple-wire.
  - Paired GUT test asserts scene loads + reads `display_name`.
  - Playwright spec asserts title-card visible 1.2-2.0 s post-`boss_died` (HTML5).
  - HTML5 release-build Self-Test Report includes screenshot + audible verification.
- **Dependencies:** None (uses existing `MobDef.display_name`). Independent of T1/T2/T3.

#### T5 — feat(boss|telegraph): visible slam-telegraph danger-zone indicator

- **Working title:** `feat(boss|telegraph): visible slam-telegraph danger-zone Polygon2D circle`
- **One-line scope:** Currently the slam telegraph fires a zero-damage Hitbox marker invisible to the player. Add a visible Polygon2D circle outline (radius 80 px matching `SLAM_HITBOX_RADIUS`, ember-orange `#FF6A2A` at alpha 0.5, 2 px line width). Fade-in over 80 ms at telegraph start, hold for telegraph duration, fade-out on slam-fire. Communicates the "back off" read.
- **Suggested owner:** **Drew** (boss lane; mirrors `_play_attack_telegraph` shape).
- **Effort:** **S-M** — Polygon2D authoring ~1 hr; integration into `_begin_slam_telegraph` (~30 min); ensure parent-relative so the indicator follows boss position during telegraph (~30 min); paired GUT test (~1 hr); HTML5 visual-verification gate.
- **Acceptance:**
  - Slam-telegraph state spawns a visible circle indicator on the boss centered at slam-origin.
  - Indicator radius matches `SLAM_HITBOX_RADIUS` (80 px).
  - Indicator color ember-orange `#FF6A2A` at alpha 0.5; sub-1.0 channels per HTML5 HDR-clamp safety.
  - Fade-in / hold / fade-out tween matches the telegraph window.
  - Indicator disappears on slam-fire or boss-death.
  - Paired GUT test asserts indicator spawns + frees on slam state transitions.
  - HTML5 Self-Test Report shows the indicator visually.
- **Dependencies:** None.

### P2 — medium impact, medium-to-high cost

#### T6 — feat(boss|feel): slam aftershock — ember-cracks burst on slam-fire impact

- **Working title:** `feat(boss|feel): slam aftershock ember-burst on slam-fire`
- **One-line scope:** On slam-fire (after the damage hitbox spawns), emit a 12-particle CPUParticles2D burst at the slam's outer radius — ember-light to ember-deep ramp, 200 ms lifetime, outward velocity 40-80 px/s. Layered on top of the existing slam visual (no replacement). Mirrors the boss-death burst pattern at half-volume.
- **Suggested owner:** **Drew** (boss lane).
- **Effort:** **S** — mirror the `_spawn_death_particles` shape with smaller numbers; integration in `_fire_slam_hit` (~1 hr total).
- **Acceptance:**
  - Slam-fire spawns a 12-particle CPU ember burst centered at slam origin.
  - Ramp + lifetime + velocity values within `combat-visual-feedback.md §3` budget.
  - Parent is the room (not the boss) so the burst persists past slam-recovery.
  - Self-frees on `finished` signal.
  - Paired GUT test asserts burst spawns on `swing_spawned(SLAM_HIT)` emission.
- **Dependencies:** None.

#### T7 — feat(audio|boss): wire phase-break sting (sfx-phase-break) and boss-wake stinger (sfx-boss-wake)

- **Working title:** `feat(audio|boss): phase-break sting + boss-wake stinger SFX cues`
- **One-line scope:** Extend `compose_sfx_m3w7.py` (or sibling) to ship two placeholder cues: `sfx-phase-break` (~400 ms tritone tension chord) and `sfx-boss-wake` (~600 ms low brass + impact). Add to `AudioDirector.SFX_PATHS` map. Wire `Stratum1Boss.phase_changed` → `play_sfx(SFX_PHASE_BREAK)`; wire `Stratum1Boss.boss_woke` → `play_sfx(SFX_BOSS_WAKE)`. Maps to Uma BI-06 + BI-18.
- **Suggested owner:** **Devon** (audio composer + AudioDirector lane).
- **Effort:** **S-M** — composer extension ~1 hr; AudioDirector + boss wiring ~1 hr; paired tests ~1 hr; HTML5 audio gate Self-Test Report.
- **Acceptance:**
  - Two new `sfx-phase-break.ogg` + `sfx-boss-wake.ogg` placeholders ship via deterministic composer.
  - `SFX_PATHS` map updated.
  - `phase_changed.emit()` triggers `sfx-phase-break` once per boundary.
  - `boss_woke.emit()` triggers `sfx-boss-wake` once.
  - Paired GUT tests assert correct cue per signal.
  - HTML5 Self-Test Report audible verification.
- **Dependencies:** Independent of T3 (T3 covers visual phase-break; T7 covers audio). T3 + T7 ship together cleanly if both pick up.

#### T8 — feat(boss|feel): boss intro stand-up animation (Beat 3 wake-anim)

- **Working title:** `feat(boss|art|feel): boss stand-up wake animation (Uma BI-06)`
- **One-line scope:** Author `wake_<dir>` animation key in `Stratum1Boss.tres` SpriteFrames (~6-8 frames, ~0.5 s); play it from `Stratum1Boss.wake()` before state-transition to IDLE; transition state to IDLE on `AnimatedSprite2D.animation_finished` for the wake key.
- **Suggested owner:** **Sponsor (PixelLab generation) + Drew (integration)** — per the M3 art-pass collaboration shape memory: Sponsor executes AI generation + cleanup; Drew wires the frames into the .tres + the wake() state-handoff.
- **Effort:** **M** — Sponsor PixelLab generation ~1-2 hr; Drew integration ~2 hr (anim key add, wake-anim-finished signal handoff, paired test that asserts state transitions correctly). HTML5 visual-verification gate.
- **Acceptance:**
  - `wake_n`, `wake_e`, `wake_s`, `wake_w` (or 8-direction) animation keys exist in `Stratum1Boss.tres`.
  - `wake()` plays the wake anim; state transitions to IDLE only after `animation_finished` fires.
  - During wake anim, boss takes no damage (existing dormant-guard already covers this for the pre-`wake()` window; new guard or state extension needed for the wake-anim window itself — verify with Drew).
  - Paired GUT test asserts the wake-anim-then-IDLE transition.
  - HTML5 visual-verification Self-Test Report.
- **Dependencies:** **PixelLab art generation** — Sponsor-executed per `.claude/docs/pixellab-pipeline.md`.

### P3 — Tier 3 / Tier 4 / spike-gated (NOT recommended for Tier 2)

#### T9 — spike(camera): Camera2D autoload for boss-room (and broader) cinematic use

- **Working title:** `spike(camera): Camera2D autoload — survey + design`
- **One-line scope:** Devon spikes the question "can a Camera2D autoload land in the M1 play loop without breaking HTML5 export, room-load pipeline, or HUD anchoring?" Produces a design doc (`team/devon-dev/camera2d-spike.md`) + a sample PR that adds + removes a Camera2D so the diff is reviewable. Tier 2 work doesn't depend on Camera2D, but Uma BI-05 (camera zoom 1.25× during intro) and F2 (camera ease-in to 1.5× during dissolve) both require it. Tier 3 ticket for actual landing.
- **Suggested owner:** **Devon**.
- **Effort:** **S-M** — spike doc + sample PR. Should not actually land Camera2D in main.
- **Acceptance:** Design doc landed; identifies risks + integration shape.
- **Dependencies:** None.

#### T10 — feat(audio|s1-ambient): Stratum-1 ambient stream + entry-fade-out + defeat-resume

- **Working title:** `feat(audio|s1-ambient): Stratum-1 ambient stream + entry-fade-out + defeat-resume`
- **One-line scope:** Foundation for Uma BI-03 (ambient cuts to 0% on entry) + F4 (ambient resumes at 60% post-defeat). Composer ships `amb-stratum1-room.ogg` placeholder; AudioDirector adds `play_stratum1_ambient()` + `stop_stratum1_ambient()`. **Cross-cuts boss-room polish** — touches every Stratum-1 room, not just boss-room. Tier 3 because it goes beyond boss-room scope and should be scoped alongside Uma's overall S1 ambient direction.
- **Suggested owner:** **Uma direction first**, then Devon implementation.
- **Effort:** **L** — direction + composer + integration + paired tests + Self-Test Report.
- **Acceptance:** S1 ambient plays on all S1 room loads; fades on boss-room entry; resumes at 60% on boss-defeated; idempotent across room-cycle.
- **Dependencies:** Uma direction.

#### Plus additional Tier 3 backlog (not ticket-ized in detail here, listed for completeness):

- Door slam visual (new asset; needs Uma direction + Drew authoring + camera integration for the lock-bar ember-flash).
- Boss nameplate (`BossNameplate.tscn`, full BI-07 through BI-15 spec; ~3-5 days of UI/HUD work + heavy paired testing).
- Vignette layer (global CanvasLayer; Uma direction + Drew implementation).
- HUD context-region red-treatment (Devon HUD-scaffolding extension).
- Skip-after-first-kill flag (per-character save state; Devon save-schema touch).
- Embers-rising dissolve (full 0.9 s sustained rise + camera ease-in to 1.5×; gated on Camera2D spike).
- Below-10% HP pulsing border (on boss sprite without nameplate, or on nameplate if nameplate ships).

---

## §4 — Recommended Tier 2 cut

**Ship: T1 + T2 + T3 + T4. Defer everything else to Tier 3 / backlog.**

### Why this cut

These four tickets share three properties that make them the right Tier 2:

1. **No spike gate.** None of them depends on a Camera2D autoload, a global vignette layer, a HUD context-region scaffolding, or a new door visual. All four wire to **existing signals on existing scenes** with **existing audio infrastructure** (or trivial extensions of it).
2. **High perceived-quality lift.** Three of the four (T1 BGM crossfade, T2 hit-pause, T3 world-time-slow) are the cinematic-layer features Sponsors-of-action-games consistently flag as "this is what makes a boss feel like a boss." The fourth (T4 title card) is the moment-of-celebration Uma calls out as "the only place in M1 where the world stops to honor the player" — and currently the player kills the boss and the world keeps moving like a grunt died.
3. **Dispatch-shaped today.** Each ticket has a clear owner, scope, acceptance, and HTML5 verification path. None of them needs another design round before authoring starts. The author can pick it up and ship without back-and-forth.

### Effort estimate for the cut

| Ticket | Owner | Effort | Days |
|---|---|---|---|
| T1 — S1 boss BGM crossfade | Devon | M | ~1 day (dispatch + Self-Test) |
| T2 — Hit-pause on player-hits-boss + final-freeze | Drew | M | ~1.5 days |
| T3 — Phase-transition world-time-slow | Drew | M | ~1.5 days |
| T4 — Defeat title card | Uma direction (1 day) + Devon implementation (1.5 days) | M-L | ~2.5 days |

**Total Tier 2 cut: ~6-7 days of dispatch work** across Devon + Drew + Uma. Realistically calendar-week-and-a-half given parallel-dispatch (T1 + T2 + T3 + T4 can run mostly in parallel — T2 and T3 want to coordinate on `Engine.time_scale` ownership but otherwise no cross-ticket blocks).

### What this cut explicitly defers

**Deferred to Tier 3 / backlog (with rationale):**

- **T5 (slam telegraph visible indicator)** — high-impact but not as foundational as T1-T4. Worth shipping next milestone or as the first Tier 3 add-on.
- **T6 (slam aftershock)** — small lift; can pick up alongside T5 in Tier 3.
- **T7 (phase-break + boss-wake SFX)** — pairs naturally with T3's phase-transition work; if the dispatch round has Devon capacity after T1 + T4, fold T7 in. Otherwise Tier 3.
- **T8 (boss stand-up wake animation)** — gated on Sponsor PixelLab generation; not a fast-dispatch ticket. Backlog until Sponsor signals capacity.
- **T9 (Camera2D spike)** — foundation for later cinematic work but not Tier 2 itself.
- **T10 (S1 ambient stream)** — cross-cuts beyond boss-room; should be scoped with Uma's broader S1 audio direction.
- **Boss nameplate + door slam + vignette + HUD context-region + skip flag + embers-rising dissolve + below-10% HP pulse** — Tier 3+ heavy lifts. Each individually is medium-large effort with design dependencies that haven't been picked up yet.

### Honest grade on the cut

This cut delivers the **emotionally-load-bearing pieces of Uma's `boss-intro.md`** (boss music kicks in, hits feel weighty, phase transitions feel like beats, the kill lands as ceremony) **without taking on the heavy-lift design surfaces** (nameplate, door slam, camera-zoom, vignette, dissolve) that need separate art / direction passes.

It is **not the full `boss-intro.md` spec.** It is roughly 5-7 of the 30 BI-criteria. Uma's full vision is a Tier 3-5 commitment if Sponsor wants it. This cut is "biggest perceived-quality bang per dev-hour for a 1.5-week Tier 2."

If Sponsor wants the **full** boss-intro spec as Tier 2, the cut expands to ~3 weeks of dispatch (adding T7, T8, and the nameplate authoring at minimum). Flagged in §5 as the load-bearing open question.

---

## §5 — Open questions for Sponsor

1. **Scope: 4-ticket "feel-load-bearing" cut OR full `boss-intro.md` spec?** This doc recommends the 4-ticket cut (~1.5 weeks). Full spec is ~3+ weeks and lands the nameplate, door slam, wake animation, full audio map, phase-break sting + boss-wake stinger. Sponsor decides the scope envelope; the 4-ticket cut is what Priya can defend as "Tier 2 right-sized."

2. **T4 title card copy: ship Uma's "WARDEN OF THE OUTER CLOISTER" name OR rename?** Uma's `boss-intro.md` proposes the working title; Drew has authority to rename via `MobDef.display_name`. Currently the MobDef `display_name` field is not exposed in `stratum1_boss.tres` (would need a check + add). **Recommended:** ship Uma's working title; Drew can rename pre-implementation if he prefers.

3. **T2 hit-pause: does the 60 ms freeze extend to player-vs-Grunt / Charger / Shooter hits, or boss-only?** Hit-pause is universally valuable for combat feel; boss-only is the safer Tier 2 scope, but extending to all mob hits would be a holistic combat-feel pass. **Recommended:** Tier 2 = boss-only; defer all-mob hit-pause to a separate combat-feel ticket if Sponsor wants it.

4. **Tier 2 readiness for Sponsor-art-pass parallel work?** M3 design seeds Track 3 (character-art external estimate) is gated on Sponsor commissioning quotes. If Sponsor is mid-commission during Tier 2, are the boss-room polish dispatches still the right Tier-2 use of orchestrator + agent time, or should we hold Tier 2 dispatches and run a smaller "follow-up backlog" tick while the art-pass landscape clarifies? **Recommended:** Tier 2 boss-room polish + art-pass quote-commission run in parallel without conflict (different agents; different surfaces). Confirm.

---

## Cross-references

- `team/uma-ux/boss-intro.md` — Uma's binding 30-criteria spec (BI-01 through BI-30); this scope doc maps every Tier 2 ticket to specific BI criteria + flags the deferred ones.
- `team/uma-ux/combat-visual-feedback.md` §3 — boss-death climax additions; T2's hit-pause partially fulfills the "Heavy-attack hit-stop 60 ms" placeholder note.
- `team/priya-pl/m3-design-seeds.md` — broader M3 strategic seeds (multi-character / hub-town / persistent-meta / character-art). Tier 2 boss-room polish is **lateral** to those tracks; no cross-block.
- `team/priya-pl/m3-tier-1-plan.md` — Tier 1 plan (closed); Tier 2 picks up after.
- `team/DECISIONS.md` 2026-05-15 — boss-music UNIQUE per-stratum decision; T1 honors S1≠S2 (separate `mus-boss-stratum1.ogg` asset, not S2 reuse).
- `.claude/docs/audio-architecture.md` — `AudioDirector` autoload + S2 crossfade pattern; T1 is a direct mirror.
- `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation" — telegraph + hit-flash pattern Tier 2 work must preserve.
- `.claude/docs/html5-export.md` — visual-verification gate + audio-playback gate that every Tier 2 ticket's Self-Test Report must honor.
- `scripts/mobs/Stratum1Boss.gd` + `scripts/levels/Stratum1BossRoom.gd` — production source inventoried in §1.
- `scripts/audio/AudioDirector.gd` — S2 boss crossfade template T1 mirrors.

---

## Non-obvious findings

(For the maintain-docs Stop hook to consider for `.claude/docs/` capture if surface-worthy.)

1. **The boss controller already documents the cinematic-layer gap.** `Stratum1Boss.gd._begin_phase_transition` and `_play_climax_shake` both contain explicit `// when Devon adds the Camera2D / cinematic layer` comments. The controller is **architected for** a cinematic layer that was never built — signals fire to nobody, the time-slow comment exists with no time-scale modulation, the self-shake is documented as a Camera2D placeholder. This is a clean baseline for Tier 2: the surface contracts are stable; Tier 2 wires subscribers + new methods rather than reshaping the controller. Worth a note in `combat-architecture.md` § boss "intended subscribers exist but are not implemented in M1" so future tasks don't assume the lack of subscribers means the contract is broken — it means the cinematic-layer slot is open.

2. **The "Engine.time_scale ownership" pattern is implicit but unenforced.** T2 hit-pause and T3 phase-transition slow both want to mutate `Engine.time_scale`. There's no current owner of `Engine.time_scale` and no global "who set this last" tracker. If Tier 2 ships these as separate tickets without coordination, the second-applied transition can clobber the first. The fix is straightforward (one small `TimeScaleDirector` autoload that stacks/resolves transitions) but worth calling out as a Tier-2-internal contract. Worth a note in `combat-architecture.md` if T2 + T3 ship.

3. **No `Camera2D` exists in the M1 play loop.** Multiple Uma BI-criteria (BI-05 camera zoom, F2 camera ease-in) require it. The boss self-shake exists as a documented workaround. This is the biggest structural gap behind Uma's `boss-intro.md` — many cinematic beats land on the camera, and we don't have one. Tier 3+ work should treat "Camera2D autoload" as a foundational milestone, not just a polish add. Worth a note in `combat-architecture.md` or a fresh `.claude/docs/camera-layer.md` if Tier 3 picks it up.
