# M3 Tier 2 — Boss-Room Polish: Full Uma Spec, Wave-Ordered Ship Plan

**Owner:** Priya · **Authored:** 2026-05-20 (M3 Tier 1 fully closed; Sponsor picked boss-room polish as Tier 2 direction; Sponsor expanded scope to full `boss-intro.md` spec same day) · **Status:** v1.1 — full-spec, wave-ordered, dispatch-ready.

This doc inventories the Stratum1Boss + Stratum1BossRoom **as-shipped state**, lists every plausible polish-area candidate, and lays out a **wave-ordered ship plan** to deliver the full Uma `boss-intro.md` cinematic layer (30 BI-criteria + F1–F4 climax + skip rule) over three parallelizable waves.

**The headline finding:** the boss state machine is complete and the M3W-4 AnimatedSprite2D / hit-flash / attack-telegraph / self-shake pass landed clean, but **the cinematic layer Uma specified in `boss-intro.md` (door slam, ambient fade, nameplate, camera zoom, defeat title card, embers-rising dissolve, skip-after-first-kill) was never built.** The signals `entry_sequence_started`, `entry_sequence_completed`, `boss_defeated` fire to **zero subscribers** in production code (only tests subscribe). There is no `BossNameplate.tscn`, no `BossIntroSequence.tscn`, no `BossDefeatedSequence.tscn`, no `Camera2D` in the M1 play loop. M1 shipped with the timing skeleton + boss combat + the SFX cues PR #278 wired — and not the cinematic surface that makes it feel like a boss.

**Sponsor decision 2026-05-20 (this doc's scope-driver):** ship the **full** cinematic layer. Not the 4-ticket "feel-load-bearing" subset; the whole spec. ~3 weeks of dispatch work across Devon + Drew + Uma + Sponsor PixelLab generation, organized as three fan-out-friendly waves so the team is never blocked on a single role.

---

## TL;DR

1. **§1 inventory** — boss combat (state machine, melee, slam, phase transitions, death pipeline) is wired clean. M3W-4 visual layer (AnimatedSprite2D + red attack-telegraph + soft-red hit-flash + 4-logical-px self-shake + 24-particle death burst) shipped end-to-end. PR #278 SFX cues fire (mob-hit, boss-die, attack-telegraph, attack-impact). **Nothing in the cinematic layer is wired** — boss-intro signals fire to nobody; no BGM crossfade to boss music; no time-slow on phase transition; no defeat title card; no door slam; no nameplate; no Camera2D.
2. **§2 candidates** — 19 plausible polish-area candidates across 5 axes (feel/animation, telegraph clarity, intro beat, defeat beat, audio-visual coherence). Many are "Uma already designed this; nobody built it."
3. **§3 ticket catalogue** — 16 dispatch-shaped tickets covering the full Uma spec. Each ticket: title + scope + owner + effort + AC + wave assignment + dependencies.
4. **§4 wave plan** — 3 waves, ~2.5–3 weeks total dispatch. **Wave 1 (no spike gates, ~1 week):** T1 BGM crossfade, T2 hit-pause, T3 phase-transition slow, T4 defeat title card, T7 phase-break + boss-wake SFX, T11 `TimeScaleDirector` autoload (foundational). **Wave 2 (spike-resolved + design-direction items, ~1 week):** T5 slam telegraph indicator, T6 slam aftershock, T8 boss wake animation, T9 Camera2D autoload land, T10 S1 ambient stream, T12 vignette CanvasLayer. **Wave 3 (heavy lifts gated on Wave 2, ~1 week):** T13 boss nameplate, T14 door slam visual + audio, T15 HUD context-region red-treatment, T16 embers-rising sustained dissolve + camera ease-in, T17 skip-after-first-kill flag, T18 phase-imminent pulse.
5. **§5 open questions** — 3 items (Sponsor-input still pending on tonal / direction calls — Uma boss name, hit-pause scope, vignette opacity ramp).

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

## §3 — Ticket catalogue (full Uma spec)

Tickets organized by their wave assignment in §4. Wave 1 = no spike gates, fan-out ready today. Wave 2 = spike-resolved foundations + design-direction items. Wave 3 = heavy lifts gated on Wave 2 foundations. Each ticket carries its own owner / effort / AC / dependencies; the wave plan in §4 is the dispatch sequence.

### Wave 1 — foundational, no spike gates

#### T1 — feat(audio|boss-room): wire S1 boss BGM crossfade on entry-sequence-completed

- **Working title:** `feat(audio|boss-room): wire S1 boss BGM crossfade on entry-sequence-completed`
- **One-line scope:** Add `AudioDirector.crossfade_to_boss_stratum1()` (mirror of S2 method); ship `mus-boss-stratum1.ogg` placeholder via composer extension; subscribe `Stratum1BossRoom.entry_sequence_completed` to fire the crossfade. Pre-fight, no BGM is playing; this kicks off the boss BGM at T+1.8 with a 0.6 s fade-in.
- **Suggested owner:** **Devon** (audio wiring + composer extension match his lane; light Uma touch on the placeholder direction if Uma cares to differentiate from S2). Could also be Drew if Devon is loaded.
- **Effort:** **M** — composer extension (~30 min following S2 pattern), `AudioDirector` method add (~30 min mirror of S2), wire (single line in Stratum1BossRoom), paired test (~1 hr — mirrors `test_s2_audio_triggers.gd`), Self-Test Report + HTML5 audio-playback gate per `.claude/docs/audio-architecture.md`.
- **Wave:** 1.
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
- **Effort:** **M** — refactor to use **T11 `TimeScaleDirector`** (no direct Engine.time_scale writes); subscribe to Hitbox-hits-boss path (~1 hr; will need to identify the hit-connect signal — `Hitbox._on_body_entered` chain → Boss.damaged or a dedicated hit-connect on Hitbox); subscribe to `Stratum1Boss.boss_died` for the longer freeze (~30 min); paired tests for both shapes (~1.5 hr — assert `Engine.time_scale` transitions + recovery + that mob loot still spawns at freeze-time-0). Coordinate with §1.5 unknowns on the boss-died ordering contract.
- **Wave:** 1.
- **Acceptance:**
  - Player-light-hit on boss → `Engine.time_scale` drops to 0.0 for 60 ms, restores to 1.0 over 1 frame.
  - Player-heavy-hit on boss → same shape, 100 ms duration (heavy = longer hit-pause; mirrors VD-07 budget).
  - Boss-died → 300 ms freeze AFTER `boss_died` signal handlers complete; loot still spawns, exit-unlock still fires, no race.
  - Phase-transition (boss damage-immune) → no hit-pause (no hit lands).
  - Boss in `STATE_DORMANT` → no hit-pause (hit ignored anyway).
  - Paired GUT tests assert all four cases + recovery.
  - HTML5 Self-Test Report: subjectively feels "punchier"; no visible time-skips on subsequent player input.
- **Dependencies:** **T11 `TimeScaleDirector`** (Wave 1 foundational). Can land in parallel with T3.

#### T3 — feat(boss|cinematic): phase-transition world-time-slow

- **Working title:** `feat(boss|cinematic): phase-transition world-time-slow to 30% for 0.6 s on phase_changed`
- **One-line scope:** On `Stratum1Boss.phase_changed(new_phase)`, set `Engine.time_scale = 0.3` for 0.6 s, then ramp back to 1.0 over 0.2 s. The boss is already stagger+damage-immune during this window (existing mechanic). Add ember-flash outline tween on the boss sprite during the slow + `phase_break_stratum1.ogg` sting cue. Maps to Uma BI-16, BI-17, BI-18.
- **Suggested owner:** **Drew** (boss lane; cinematic-layer surface naturally bundles with T2's hit-pause work since both are `Engine.time_scale` modulation patterns).
- **Effort:** **M** — phase-break visual tween (~1 hr; uses existing `_play_attack_telegraph` 3-branch resolver pattern); SFX moved to T7 (decoupled); time-slow via **T11 TimeScaleDirector** (no direct Engine.time_scale writes); paired tests (~1.5 hr — assert time-scale transitions + the existing damage-immune-during-transition mechanic still holds + visual tween fires once per boundary).
- **Wave:** 1.
- **Acceptance:**
  - `phase_changed.emit(PHASE_2)` triggers 0.6 s of `Engine.time_scale = 0.3` followed by 0.2 s ramp to 1.0 (via T11 director).
  - Same for `PHASE_3`.
  - Boss sprite ember-flash outline tween plays for the full 0.6 s window.
  - `sfx-phase-break` placeholder SFX cue fires once per boundary (no spam-fire from hit-spam thanks to existing idempotent latch).
  - Hit-pause (T2) is suppressed during phase-transition window (T11 stack resolution: phase-transition request wins over hit-pause request).
  - Paired GUT tests; HTML5 Self-Test Report shows time-slow visually.
- **Dependencies:** **T11 `TimeScaleDirector`** (Wave 1 foundational). Can land in parallel with T2.

#### T4 — feat(ui|boss): defeat title card "The Warden falls." + "STRATUM 1 CLEARED" subtitle

- **Working title:** `feat(ui|boss): defeat title card and stratum-cleared subtitle (Uma F3)`
- **One-line scope:** Author `BossDefeatedTitleCard.tscn` — CanvasLayer with two Labels (wordmark font, off-white #E8E4D6) — that reads `MobDef.display_name` to template `"{name} falls."`, sub-labeled `STRATUM 1 CLEARED`. Subscribes to `Stratum1BossRoom.boss_defeated`. Fades in over 0.4 s at T+1.2 post-death, holds 0.8 s, fades out over 0.4 s. Uma F3.
- **Suggested owner:** **Uma direction first** (font selection, copy review, layout sketch — 1-2 hr), **then Devon** (scene authoring + signal wiring — UI surface matches his HUD lane; ~3-4 hr).
- **Effort:** **M-L** — Uma direction ~2 hr; Devon scene + wiring ~4 hr; paired GUT test for "title card scene exists + reads display_name correctly" + Playwright spec for "title card visible post-defeat" ~2 hr; HTML5 visual-verification gate per `.claude/docs/html5-export.md`.
- **Wave:** 1.
- **Acceptance:**
  - `BossDefeatedTitleCard.tscn` exists with two Labels (title + subtitle).
  - Title text templates `"{MobDef.display_name} falls."` — M1 stratum-1 boss `display_name` resolves to `"WARDEN OF THE OUTER CLOISTER"` per `boss-intro.md`. Subtitle reads `STRATUM 1 CLEARED`.
  - Fade-in / hold / fade-out timings match Uma F3 (0.4 / 0.8 / 0.4 s).
  - Subscribes to `Stratum1BossRoom.boss_defeated` signal; idempotent on triple-wire.
  - Paired GUT test asserts scene loads + reads `display_name`.
  - Playwright spec asserts title-card visible 1.2-2.0 s post-`boss_died` (HTML5).
  - HTML5 release-build Self-Test Report includes screenshot + audible verification.
- **Dependencies:** None (uses existing `MobDef.display_name`). Independent of T1/T2/T3.

#### T7 — feat(audio|boss): wire phase-break sting (sfx-phase-break) and boss-wake stinger (sfx-boss-wake)

- **Working title:** `feat(audio|boss): phase-break sting + boss-wake stinger SFX cues`
- **One-line scope:** Extend `compose_sfx_m3w7.py` (or sibling) to ship two placeholder cues: `sfx-phase-break` (~400 ms tritone tension chord) and `sfx-boss-wake` (~600 ms low brass + impact). Add to `AudioDirector.SFX_PATHS` map. Wire `Stratum1Boss.phase_changed` → `play_sfx(SFX_PHASE_BREAK)`; wire `Stratum1Boss.boss_woke` → `play_sfx(SFX_BOSS_WAKE)`. Maps to Uma BI-06 + BI-18.
- **Suggested owner:** **Devon** (audio composer + AudioDirector lane).
- **Effort:** **S-M** — composer extension ~1 hr; AudioDirector + boss wiring ~1 hr; paired tests ~1 hr; HTML5 audio gate Self-Test Report.
- **Wave:** 1.
- **Acceptance:**
  - Two new `sfx-phase-break.ogg` + `sfx-boss-wake.ogg` placeholders ship via deterministic composer.
  - `SFX_PATHS` map updated.
  - `phase_changed.emit()` triggers `sfx-phase-break` once per boundary.
  - `boss_woke.emit()` triggers `sfx-boss-wake` once.
  - Paired GUT tests assert correct cue per signal.
  - HTML5 Self-Test Report audible verification.
- **Dependencies:** Pairs naturally with T3 (visual phase-break) and T8 (wake animation). T3 + T7 + T8 share signal subscribers but no code-level block.

#### T11 — feat(autoload|combat): TimeScaleDirector — global Engine.time_scale ownership + stacking

- **Working title:** `feat(autoload|combat): TimeScaleDirector autoload — stacked time-scale ownership`
- **One-line scope:** Author `TimeScaleDirector.gd` autoload that owns `Engine.time_scale` mutations through a small stack-based API (`request(reason, value, duration)` / `release(reason)` / `freeze(duration)`). Single owner means T2 hit-pause + T3 phase-transition slow + T16 boss-defeated freeze + future inventory/level-up slows all coordinate without clobbering each other. Highest-priority active request wins; on release, falls back to next-highest, finally back to 1.0.
- **Suggested owner:** **Drew** (combat lane; pairs naturally with T2 + T3 which are also Drew).
- **Effort:** **M** — autoload skeleton ~1 hr; stack + reason-keyed API ~1.5 hr; paired GUT tests covering stack push/pop, collision (hit-pause during phase-transition), and auto-release on timer ~2 hr; integration with T2 + T3 (refactor both to use the director) ~1 hr.
- **Wave:** 1.
- **Acceptance:**
  - `TimeScaleDirector` registered in `project.godot` autoloads.
  - API: `request(reason: String, scale: float, duration: float)`, `release(reason: String)`, `freeze(duration: float)` (sugar for scale=0.0).
  - Stack semantics: lowest-scale-among-active-requests wins; on release, recompute from remaining stack.
  - Auto-release on duration expiry via SceneTreeTimer; idempotent on double-release.
  - Paired GUT tests assert stack behavior, collision resolution, auto-release.
  - T2 + T3 + T16 refactored to use the director (no direct `Engine.time_scale =` writes outside the director).
- **Dependencies:** Land BEFORE T2 + T3 + T16 (or land first PR with director + T2; subsequent tickets adopt). Recommended: T11 dispatches first in Wave 1, then T2 / T3 / T16 layer on top.

### Wave 2 — spike-resolved foundations + design-direction items

#### T5 — feat(boss|telegraph): visible slam-telegraph danger-zone indicator

- **Working title:** `feat(boss|telegraph): visible slam-telegraph danger-zone Polygon2D circle`
- **One-line scope:** Currently the slam telegraph fires a zero-damage Hitbox marker invisible to the player. Add a visible Polygon2D circle outline (radius 80 px matching `SLAM_HITBOX_RADIUS`, ember-orange `#FF6A2A` at alpha 0.5, 2 px line width). Fade-in over 80 ms at telegraph start, hold for telegraph duration, fade-out on slam-fire. Communicates the "back off" read.
- **Suggested owner:** **Drew** (boss lane; mirrors `_play_attack_telegraph` shape).
- **Effort:** **S-M** — Polygon2D authoring ~1 hr; integration into `_begin_slam_telegraph` (~30 min); ensure parent-relative so the indicator follows boss position during telegraph (~30 min); paired GUT test (~1 hr); HTML5 visual-verification gate.
- **Wave:** 2.
- **Acceptance:**
  - Slam-telegraph state spawns a visible circle indicator on the boss centered at slam-origin.
  - Indicator radius matches `SLAM_HITBOX_RADIUS` (80 px).
  - Indicator color ember-orange `#FF6A2A` at alpha 0.5; sub-1.0 channels per HTML5 HDR-clamp safety.
  - Fade-in / hold / fade-out tween matches the telegraph window.
  - Indicator disappears on slam-fire or boss-death.
  - Paired GUT test asserts indicator spawns + frees on slam state transitions.
  - HTML5 Self-Test Report shows the indicator visually.
- **Dependencies:** None.

#### T6 — feat(boss|feel): slam aftershock — ember-cracks burst on slam-fire impact

- **Working title:** `feat(boss|feel): slam aftershock ember-burst on slam-fire`
- **One-line scope:** On slam-fire (after the damage hitbox spawns), emit a 12-particle CPUParticles2D burst at the slam's outer radius — ember-light to ember-deep ramp, 200 ms lifetime, outward velocity 40-80 px/s. Layered on top of the existing slam visual (no replacement). Mirrors the boss-death burst pattern at half-volume.
- **Suggested owner:** **Drew** (boss lane).
- **Effort:** **S** — mirror the `_spawn_death_particles` shape with smaller numbers; integration in `_fire_slam_hit` (~1 hr total).
- **Wave:** 2.
- **Acceptance:**
  - Slam-fire spawns a 12-particle CPU ember burst centered at slam origin.
  - Ramp + lifetime + velocity values within `combat-visual-feedback.md §3` budget.
  - Parent is the room (not the boss) so the burst persists past slam-recovery.
  - Self-frees on `finished` signal.
  - Paired GUT test asserts burst spawns on `swing_spawned(SLAM_HIT)` emission.
- **Dependencies:** None.

#### T8 — feat(boss|feel): boss intro stand-up animation (Beat 3 wake-anim)

- **Working title:** `feat(boss|art|feel): boss stand-up wake animation (Uma BI-06)`
- **One-line scope:** Author `wake_<dir>` animation key in `Stratum1Boss.tres` SpriteFrames (~6-8 frames, ~0.5 s); play it from `Stratum1Boss.wake()` before state-transition to IDLE; transition state to IDLE on `AnimatedSprite2D.animation_finished` for the wake key.
- **Suggested owner:** **Sponsor (PixelLab generation) + Drew (integration)** — per the M3 art-pass collaboration shape memory: Sponsor executes AI generation + cleanup; Drew wires the frames into the .tres + the wake() state-handoff.
- **Effort:** **M** — Sponsor PixelLab generation ~1-2 hr; Drew integration ~2 hr (anim key add, wake-anim-finished signal handoff, paired test that asserts state transitions correctly). HTML5 visual-verification gate.
- **Wave:** 2 (Drew integration); art-gen can start in Wave 1 if Sponsor capacity allows.
- **Acceptance:**
  - `wake_n`, `wake_e`, `wake_s`, `wake_w` (or 8-direction) animation keys exist in `Stratum1Boss.tres`.
  - `wake()` plays the wake anim; state transitions to IDLE only after `animation_finished` fires.
  - During wake anim, boss takes no damage (existing dormant-guard already covers this for the pre-`wake()` window; new guard or state extension needed for the wake-anim window itself — verify with Drew).
  - Paired GUT test asserts the wake-anim-then-IDLE transition.
  - HTML5 visual-verification Self-Test Report.
- **Dependencies:** **PixelLab art generation** — Sponsor-executed per `.claude/docs/pixellab-pipeline.md`.

#### T9 — feat(camera): Camera2D autoload — land in M1 play loop

- **Working title:** `feat(camera): Camera2D autoload — survey, design, land`
- **One-line scope:** Devon surveys the question "can a Camera2D autoload land in the M1 play loop without breaking HTML5 export, room-load pipeline, or HUD anchoring?" Produces a brief design doc (`team/devon-dev/camera2d-spike.md`) **AND** lands the Camera2D autoload itself. This unlocks Wave 3 work that needs it (T16 embers-rising + camera ease-in to 1.5×) and the intro-camera-zoom subset of T13 (BI-05). Wave 2 lands the camera + a minimal `request_zoom(target, duration)` API; T13/T16 layer on top.
- **Suggested owner:** **Devon**.
- **Effort:** **M-L** — spike doc ~1 hr; Camera2D autoload + room-load integration ~2-3 hr; minimal `request_zoom` API ~1.5 hr; HUD anchoring verification ~1 hr; HTML5 export verification (critical — Camera2D + gl_compatibility has been a historical sharp edge; see `.claude/docs/html5-export.md`); paired GUT tests + Playwright spec ~2 hr.
- **Wave:** 2 (foundational for Wave 3 T16 + the camera-zoom subset of T13).
- **Acceptance:**
  - `Camera2D` registered as autoload OR added to Main scene with global access pattern; Devon picks the shape.
  - Default behavior: player-anchored at 1.0× zoom (no behavior change from pre-Camera2D).
  - `request_zoom(target_scale: float, duration: float, anchor: Vector2)` API exists; idempotent.
  - HUD anchors continue rendering at screen-space (not world-space) — HUD does not zoom with camera.
  - HTML5 release-build Self-Test Report confirms camera renders cleanly + no z-index / polygon regressions.
  - Paired GUT test asserts zoom request + anchor shift + return-to-player.
- **Dependencies:** None. Land BEFORE T16 (Wave 3). Coordinates with `_play_climax_shake` self-shake — Devon decides if the self-shake redirects to a `CameraShake` autoload or stays boss-side for now (low priority; not blocking).

#### T10 — feat(audio|s1-ambient): Stratum-1 ambient stream + entry-fade-out + defeat-resume

- **Working title:** `feat(audio|s1-ambient): Stratum-1 ambient stream + entry-fade-out + defeat-resume`
- **One-line scope:** Foundation for Uma BI-03 (ambient cuts to 0% on entry) + F4 (ambient resumes at 60% post-defeat). Composer ships `amb-stratum1-room.ogg` placeholder; AudioDirector adds `play_stratum1_ambient()` + `stop_stratum1_ambient()`. Cross-cuts boss-room polish — touches every Stratum-1 room, not just boss-room. Uma direction first on the ambient texture (tone-match S2 ambient or distinct stratum identity?), then Devon implementation.
- **Suggested owner:** **Uma direction first**, then Devon implementation.
- **Effort:** **L** — direction ~1 hr; composer ~2 hr; integration ~2 hr; paired tests ~1.5 hr; Self-Test Report.
- **Wave:** 2.
- **Acceptance:** S1 ambient plays on all S1 room loads; fades on boss-room entry; resumes at 60% on boss-defeated; idempotent across room-cycle. Paired GUT test asserts fade-out → 0% on `entry_sequence_started`; fade-in → 60% on `boss_defeated`.
- **Dependencies:** Uma direction.

#### T12 — feat(ui|vignette): global vignette CanvasLayer with opacity-ramp API

- **Working title:** `feat(ui|vignette): vignette CanvasLayer + opacity-ramp API`
- **One-line scope:** Author global vignette CanvasLayer (radial dark-fade to room edges, palette-locked per `palette.md`). Default stratum-1 vignette opacity 30%. API: `set_vignette_opacity(value, duration)` ramps over duration. Used by T13 boss intro (ramp to 70% on entry) and T16 boss-defeated (ramp to 80% during dissolve, return to 30% post-titlecard). Uma direction first on the vignette shape, color, and opacity curve.
- **Suggested owner:** **Uma direction first**, then Drew implementation.
- **Effort:** **M** — Uma direction ~1.5 hr; Drew CanvasLayer + shader/gradient + API ~3 hr; paired GUT test (~1 hr); HTML5 visual-verification gate (vignette is rendering-stack-sensitive; see `.claude/docs/html5-export.md`).
- **Wave:** 2.
- **Acceptance:**
  - `Vignette.tscn` CanvasLayer registered in Main; renders ABOVE world but BELOW HUD/UI canvases.
  - Default opacity matches `palette.md` stratum-1 spec (30%).
  - `set_vignette_opacity(value, duration)` ramps smoothly; idempotent across rapid calls.
  - HTML5 release-build Self-Test Report confirms vignette renders without HDR-clamp / z-index regressions.
  - Paired GUT test asserts opacity transitions.
- **Dependencies:** Uma direction.

### Wave 3 — heavy lifts, gated on Wave 2 foundations

#### T13 — feat(ui|boss): boss nameplate (BI-07 through BI-15)

- **Working title:** `feat(ui|boss): BossNameplate.tscn — 480×56 top-center, 3-phase segmented HP bar`
- **One-line scope:** Author the full nameplate per Uma `boss-intro.md` § "Boss nameplate spec" — 480×56 px, top-center anchored 12 px from screen edge, `#1B1A1F` at 92% with 1 px ember-orange `#FF6A2A` border, threat glyph `[!]`, boss name from `MobDef.display_name` (16 px caps off-white), `THREAT: ELITE` muted parchment, 3-segment 432×12 HP bar with 2 px ember separators, phase labels (10 px caps active=bright, completed=muted, future=disabled). Segments are visually equal (each 1/3 width) — phase HP weights internal to the boss controller. Active segment uses `#7A2A26` with ghost-damage drain. Slides down from screen top over 0.4 s on `entry_sequence_completed`. Subscribes to `phase_changed` + `damaged` signals. Uma BI-07 through BI-14.
- **Suggested owner:** **Devon** (HUD scaffolding lane).
- **Effort:** **L** — Devon authoring + signal wiring + ghost-damage drain + 3-segment driver ~6-8 hr; paired GUT tests for slide-in, segment fill, phase-transition flash, ghost-drain timing ~3-4 hr; Playwright spec for HTML5 visibility ~1 hr; HTML5 visual-verification gate.
- **Wave:** 3.
- **Acceptance:** All BI-07 through BI-14 in Uma's tester checklist pass (see `team/uma-ux/boss-intro.md`). Plus: ghost-damage drain reads identical to regular mob nameplate; idempotent across phase-transition spam; HTML5 Self-Test Report.
- **Dependencies:** **T18** (below-10% pulse — BI-15 — naturally lands on the nameplate; ship T18 in same PR or immediate follow-up). No dep on T9 Camera2D (nameplate is HUD-anchored).

#### T14 — feat(level|boss-room): door slam visual + audio + lock-state

- **Working title:** `feat(level|boss-room|audio): door slam visual + ember-flash + door_slam_heavy.ogg`
- **One-line scope:** Replace the current door-trigger Area2D (which has no visual) with a `BossRoomDoor.tscn` — animated door sprite with `unlocked` / `slamming` / `locked` / `unlocking` animation keys. Plays slam animation + `door_slam_heavy.ogg` SFX on `entry_sequence_started`. 1-frame ember-flash on lock-bar at end of slam. Plays unlock + `door_unlock_chime.ogg` on `boss_defeated`. Uma BI-01, BI-02, F3 door-unlock.
- **Suggested owner:** **Uma direction first** (door visual style, palette-lock per `palette.md`), **then PixelLab art generation by Sponsor** (door sprite + lock-bar + 4 animation states; per `.claude/docs/pixellab-pipeline.md`), **then Drew integration** (scene authoring, signal wiring, room-tscn replacement of the trigger-only Area2D), **then Devon audio cues** (composer extension for door_slam_heavy + door_unlock_chime).
- **Effort:** **L** — Uma direction ~2 hr; Sponsor PixelLab ~2-3 hr; Drew integration ~4 hr; Devon audio composer + wiring ~2 hr; paired tests ~2 hr; HTML5 visual + audio verification.
- **Wave:** 3.
- **Acceptance:** BI-01, BI-02 pass; F3 door-unlock pass. Door visually slams + locks on entry; unlocks + chimes on defeat; no regression to the existing `entry_sequence_started` trigger (door is now visible-state, not the gate).
- **Dependencies:** Sponsor PixelLab generation (per `m3-art-pass-collaboration-shape`).

#### T15 — feat(ui|hud): HUD context-region red `STRATUM 1 · BOSS` treatment

- **Working title:** `feat(ui|hud): HUD top-right context-region — red boss treatment`
- **One-line scope:** Extend HUD scaffolding with a top-right context-region label. Default state: `STRATUM 1` in muted parchment. On `entry_sequence_completed`: swap to `STRATUM 1 · BOSS` with red treatment (per Uma direction; palette-lock). On `boss_defeated`: return to default. Uma BI-20.
- **Suggested owner:** **Uma direction first** (red palette swatch + treatment shape — current HUD-disabled-color `#605C50` is too muted, the active-phase-segment red `#7A2A26` may be the right anchor), **then Devon implementation**.
- **Effort:** **M** — Uma direction ~1 hr; Devon HUD-scaffolding extension + signal wiring ~3 hr; paired tests + Playwright ~2 hr; HTML5 visual-verification gate.
- **Wave:** 3.
- **Acceptance:** BI-20 passes. Region transitions on `entry_sequence_completed` + `boss_defeated`. Region renders at screen-space (no zoom interaction with T9 Camera2D).
- **Dependencies:** Uma direction.

#### T16 — feat(boss|cinematic): embers-rising sustained dissolve + camera ease-in to 1.5× + warm horn

- **Working title:** `feat(boss|cinematic): embers-rising sustained dissolve + camera ease-in (Uma F2)`
- **One-line scope:** Replace the current 24-particle single-emission death-burst with a 0.9 s **sustained** ember rise (continuous emitter, brighter + faster than the death-flow player-dissolve, ember-orange + ember-light); camera eases in to 1.5× over 0.9 s centered on boss's last position (uses T9 Camera2D API); vignette deepens to 80% (uses T12 vignette API); sustained warm horn note `boss_kill_horn.ogg` rises across the 0.9 s. Uma F2.
- **Suggested owner:** **Drew** (boss death pipeline + cinematic-layer surface) + **Devon** (audio composer for `boss_kill_horn.ogg`).
- **Effort:** **L** — refactor `_spawn_death_particles` to sustained emitter ~2 hr; camera ease-in integration ~1.5 hr; vignette deepening integration ~1 hr; warm horn composer ~1.5 hr; integration with boss-died freeze (T2/T11) timing ~1 hr; paired tests ~2 hr; HTML5 visual + audio verification (this is the cinematic climax — Sponsor will judge it directly).
- **Wave:** 3.
- **Acceptance:** F2 + BI-24 pass. Embers rise sustained over 0.9 s (not single explosive emission); camera at 1.5× zoom; vignette at 80%; horn peaks as embers exit screen; on completion, camera returns to player-anchored over 0.4 s (per Uma F3 ramp-out) and vignette returns to default.
- **Dependencies:** **T9 Camera2D** (foundational), **T12 vignette** (foundational), **T11 TimeScaleDirector** (death freeze coordination). All Wave 2.

#### T17 — feat(save|boss): skip-after-first-kill flag (BI-21, BI-22)

- **Working title:** `feat(save|boss): per-character first-boss-kill flag + intro skip`
- **One-line scope:** Add `Player.first_boss_kill_seen: bool` to save schema. Set to `true` on first-ever `boss_defeated.emit()` per character. On subsequent boss intros, allow movement-key press during Beats 2-4 to collapse the intro to door-slam + nameplate-fast-slide + boss-music-fast-fade (per Uma "Skip rule"). First-ever fight is NOT skippable (flag is false).
- **Suggested owner:** **Devon** (save-schema lane).
- **Effort:** **M** — save schema migration ~1.5 hr (with backward-compat for existing saves: missing field = false = first kill not seen); skip-handler in `Stratum1BossRoom` intro sequence ~2 hr; paired tests (first kill non-skippable, second kill skippable, save persistence) ~2 hr.
- **Wave:** 3.
- **Acceptance:** BI-21 + BI-22 pass. First-ever kill not skippable; subsequent kills skippable on movement key during Beats 2-4. Save survives reload.
- **Dependencies:** None directly, but stacks with T13 nameplate timing (the skip collapses the nameplate slide).

#### T18 — feat(ui|boss-nameplate): below-10% HP pulse on active phase segment (BI-15)

- **Working title:** `feat(ui|boss-nameplate): below-10% pulse + phase-imminent visual cue`
- **One-line scope:** When the active phase segment drops below 10% of that phase's HP allocation, render a 1 px ember-orange outline pulse at 1.5 Hz on the active segment. Telegraphs "phase transition imminent." Tied to the nameplate surface from T13. Uma BI-15.
- **Suggested owner:** **Devon** (HUD lane; pairs with T13).
- **Effort:** **S-M** — pulse driver + threshold detection ~2 hr; paired test (~1 hr); HTML5 visual-verification.
- **Wave:** 3 (ship in same PR as T13 if Devon prefers, or as immediate follow-up).
- **Acceptance:** BI-15 passes. Pulse fires at 1.5 Hz when active segment <10%; stops on phase-transition; idempotent across hit-spam.
- **Dependencies:** **T13** (nameplate surface).

---

## §4 — Wave plan (full Uma spec, fan-out-friendly)

**Sponsor decision 2026-05-20:** ship the full `boss-intro.md` spec. ~2.5–3 weeks of dispatch organized into three waves of 4–6 tickets each, designed so multiple agents can land Wave-N work in parallel without cross-ticket blocks.

### Wave 1 — foundational, no spike gates (target ~1 week)

| # | Ticket | Owner | Effort | Notes |
|---|---|---|---|---|
| T11 | `feat(autoload|combat): TimeScaleDirector` | Drew | M | **Land FIRST** in Wave 1; T2/T3 adopt it on top |
| T1 | `feat(audio|boss-room): S1 boss BGM crossfade` | Devon | M | Independent; ships in parallel |
| T2 | `feat(combat|boss|player): hit-pause + final-freeze` | Drew | M | Depends on T11 |
| T3 | `feat(boss|cinematic): phase-transition world-time-slow` | Drew | M | Depends on T11 |
| T4 | `feat(ui|boss): defeat title card` | Uma direction → Devon | M-L | Independent; Uma direction can start day 1 |
| T7 | `feat(audio|boss): phase-break + boss-wake SFX` | Devon | S-M | Independent; pairs with T3 on phase-changed signal |

**Wave 1 total:** 6 tickets, ~7–9 days of distributed work; ~1 calendar week given parallel-dispatch (T11 lands day 1; T1 + T4 direction run parallel; T2/T3 land day 2–4 atop T11; T7 fills Devon capacity day 3–5).

**Wave 1 cinematic delivery:** boss music kicks in, hits feel weighty, phase transitions feel like beats, the kill lands as ceremony, phase-break + boss-wake audio cues fire. Closes Uma BI-06 (audio), BI-16, BI-17, BI-18, F1 (title-card subset), F3 (title-card subset). The "emotionally-load-bearing subset" of the spec.

### Wave 2 — spike-resolved foundations + design-direction (target ~1 week)

| # | Ticket | Owner | Effort | Notes |
|---|---|---|---|---|
| T9 | `feat(camera): Camera2D autoload — land` | Devon | M-L | Foundational for Wave 3 T16; spike + land same ticket |
| T12 | `feat(ui|vignette): vignette CanvasLayer + API` | Uma direction → Drew | M | Foundational for Wave 3 T16 + intro vignette |
| T10 | `feat(audio|s1-ambient): S1 ambient stream` | Uma direction → Devon | L | Foundation for BI-03 + F4 |
| T8 | `feat(boss|art|feel): boss stand-up wake animation` | Sponsor PixelLab + Drew | M | Sponsor PixelLab can start Wave 1 |
| T5 | `feat(boss|telegraph): visible slam-telegraph indicator` | Drew | S-M | Independent; mirrors existing attack-telegraph pattern |
| T6 | `feat(boss|feel): slam aftershock ember-burst` | Drew | S | Independent; small particle-system add |

**Wave 2 total:** 6 tickets, ~10–12 days of distributed work; ~1 calendar week given parallel-dispatch + Wave 1 wrap-overlap (T9 + T12 + T10 are direction-then-implement, naturally absorb 2–3 day calendar slip).

**Wave 2 cinematic delivery:** S1 ambient ducks on entry + resumes on defeat (BI-03, F4); vignette deepens (BI-04 partial); Camera2D in M1 play loop (foundational for BI-05 + F2); slam telegraph + aftershock (combat-feel polish); boss stand-up wake animation (BI-06 visual).

### Wave 3 — heavy lifts gated on Wave 2 (target ~1 week)

| # | Ticket | Owner | Effort | Notes |
|---|---|---|---|---|
| T13 | `feat(ui|boss): BossNameplate.tscn` | Devon | L | Largest single surface; BI-07 through BI-14 |
| T18 | `feat(ui|boss-nameplate): below-10% HP pulse` | Devon | S-M | Ships in T13 PR or immediate follow-up; BI-15 |
| T14 | `feat(level|boss-room|audio): door slam visual + audio` | Uma → Sponsor PixelLab → Drew → Devon | L | BI-01, BI-02, F3 |
| T15 | `feat(ui|hud): STRATUM 1 · BOSS HUD treatment` | Uma → Devon | M | BI-20 |
| T16 | `feat(boss|cinematic): embers-rising sustained dissolve + camera ease-in` | Drew + Devon | L | F2 climax beat; depends on T9 + T12 + T11 |
| T17 | `feat(save|boss): skip-after-first-kill flag` | Devon | M | BI-21, BI-22 |

**Wave 3 total:** 6 tickets (incl. T18 ship-with-T13), ~11–14 days of distributed work; ~1 calendar week given parallel-dispatch + that T14 + T15 + T17 absorb Sponsor PixelLab + Uma direction in parallel with Devon/Drew implementation.

**Wave 3 cinematic delivery:** full nameplate (BI-07 through BI-15); door slam visual (BI-01, BI-02); HUD context-region (BI-20); cinematic climax (F2 sustained ember rise + camera ease-in); intro skip (BI-21, BI-22). At Wave 3 close, all 30 BI-criteria + F1–F4 are wired.

### Total effort + risk

| Wave | Tickets | Distributed days | Calendar (parallel) |
|---|---|---|---|
| 1 | 6 (T11, T1, T2, T3, T4, T7) | ~7–9 | ~1 week |
| 2 | 6 (T9, T12, T10, T8, T5, T6) | ~10–12 | ~1 week |
| 3 | 6 (T13, T18, T14, T15, T16, T17) | ~11–14 | ~1 week |
| **Total** | **18 tickets** | **~28–35 days** | **~3 weeks** |

**Highest-risk surfaces (where the wave plan could slip):**
- **T9 Camera2D in HTML5** — gl_compatibility has been a historical sharp edge (see `.claude/docs/html5-export.md`); if the spike surfaces a z-index / scaling regression, Wave 3 T16 slips by a week. Mitigation: T9 ticks first in Wave 2; if blocked, T16 falls back to no-camera-ease-in variant (boss self-shake remains the placeholder).
- **T13 nameplate ghost-damage drain** — visually-load-bearing; HTML5 visual-verification will be the gate. Mitigation: paired GUT tests assert timing; Playwright spec asserts visibility; Sponsor soak is the final word.
- **T14 door visual + Sponsor PixelLab** — sequential dependency (Uma direction → PixelLab → Drew integration → Devon audio). 4-link chain; longest critical path in Wave 3. Mitigation: Uma direction can start in Wave 1 so PixelLab queues during Wave 2.
- **T11 TimeScaleDirector adoption refactor** — T2 + T3 + T16 all refactor onto it; T11 must land cleanly first or the wave-1 dispatch order breaks. Mitigation: T11 is the first Wave 1 dispatch; T2/T3 wait one day.

### Honest grade on the wave plan

This plan ships the **full** cinematic layer Uma designed — 30 BI-criteria + F1–F4 closure + skip-rule. Calendar-week-per-wave is **achievable but optimistic**: realistically the team should plan for ~3 weeks calendar with 1–2 days of slip absorbed across the chain. The waves are **parallelization-shaped** — every wave fans out to 5–6 agents in flight at peak, matching the team-roster + sub-agent dispatch pattern. No single role is the bottleneck for an entire wave (Wave 1 spreads across Drew + Devon + Uma; Wave 2 same; Wave 3 same).

This is the spec ship. Sponsor's call to expand is the right call; the cinematic layer is what makes a boss feel like a boss, and shipping the full spec rather than the 5-7-criteria subset closes the M1 quality story properly.

---

## §5 — Open questions remaining (tonal / direction, not scope)

The scope-envelope question (4-ticket cut vs full spec) is **resolved 2026-05-20: full spec**. The remaining open items are tonal / direction calls that don't block Wave 1 dispatch but want Sponsor input before the relevant wave lands:

1. **T4 title card copy: ship Uma's "WARDEN OF THE OUTER CLOISTER" name OR rename?** Uma's `boss-intro.md` proposes the working title; Drew/Sponsor has authority to rename via `MobDef.display_name`. Currently the MobDef `display_name` field is not exposed in `stratum1_boss.tres` (would need a check + add). **Recommended:** ship Uma's working title; Sponsor can rename pre-Wave-3 if he prefers a different name. Lockable in Wave 1 (T4) without affecting downstream waves.

2. **T2 hit-pause: does the 60 ms freeze extend to player-vs-Grunt / Charger / Shooter hits, or boss-only?** Hit-pause is universally valuable for combat feel; boss-only is the safer Tier 2 scope, but extending to all mob hits would be a holistic combat-feel pass. **Recommended:** Tier 2 = boss-only; defer all-mob hit-pause to a separate combat-feel ticket if Sponsor wants it. Confirm with Drew in Wave 1.

3. **T12 vignette palette + opacity curve.** Uma direction needed before T12 ships in Wave 2. Specifically: vignette tint (cooler boss-room tone vs neutral darken), opacity ramp shape (linear vs eased), and whether the 80% Wave 3 deepening (F2) feels right or wants a different peak. Defer to Uma direction; not Sponsor-blocking but Uma needs a sketch before Wave 2 dispatch.

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

(For the maintain-docs Stop hook to consider for `.claude/docs/` capture. With the full spec in scope, all three findings now have concrete in-flight tickets — defer capture until the implementation PRs land and surface the architectural shapes, then capture from the as-built code rather than from the scope doc.)

1. **The boss controller already documents the cinematic-layer gap.** `Stratum1Boss.gd._begin_phase_transition` and `_play_climax_shake` both contain explicit "when Devon adds the Camera2D / cinematic layer" comments. The controller is **architected for** a cinematic layer that was never built — signals fire to nobody, the time-slow comment exists with no time-scale modulation, the self-shake is documented as a Camera2D placeholder. **Capture timing:** capture in `combat-architecture.md` § boss when **Wave 1 closes** — once T2/T3/T4 wire subscribers, the doc can read "subscribers added in M3 Tier 2; pre-T2 the cinematic-layer slot was open and the comments referred to it" as a closed loop rather than an open question.

2. **`Engine.time_scale` ownership pattern.** T11 `TimeScaleDirector` autoload IS the documented contract. **Capture timing:** capture in `combat-architecture.md` when **T11 lands** (Wave 1 day 1). The director's API contract + stack semantics + reason-keyed release pattern are the kind of cross-system contract `.claude/docs/` exists for; future combat-feel work (level-up time-slow, inventory pause, all-mob hit-pause) will adopt it. Likely a fresh `.claude/docs/time-scale-director.md` rather than a section in combat-architecture.

3. **`Camera2D` in M1 play loop.** T9 lands the Camera2D autoload + API in Wave 2. **Capture timing:** capture in a fresh `.claude/docs/camera-layer.md` when **T9 closes** — the HTML5 export quirks (gl_compatibility + camera + HUD anchor patterns) are non-obvious enough that the doc justifies its own file, and a fresh implementation is the right moment to document.

All three captures are **in-implementation-PR scope**; not orphan doc work. The maintain-docs Stop hook on each of T11 / T9's merge PR is the right capture moment.
