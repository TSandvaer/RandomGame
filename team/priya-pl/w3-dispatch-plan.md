# M3 Tier 2 Wave 3 — Dispatch Plan

**Author:** Priya · **Date:** 2026-05-21 · **Scope source:** `team/priya-pl/m3-tier2-boss-room-polish-scope.md §3 Wave 3` (T13/T14/T15/T16/T17/T18) · **Direction source:** `team/uma-ux/boss-intro.md`.

Pre-shape only. Orchestrator dispatches these on Sponsor "go." No code commitment in this PR.

## §0 — Status snapshot (2026-05-21)

| Ticket | ID | Status | Wave-2 dep | Dep landed? |
|---|---|---|---|---|
| T13 BossNameplate | `86c9wjz2d` | to do | — (HUD-only) | n/a |
| T14 Door slam | `86c9wjz80` | to do | — | n/a |
| T15 STRATUM 1 · BOSS HUD | `86c9wjzbc` | to do | — | n/a |
| T16 Embers-rising + camera ease-in | `86c9wjzgh` | to do | T9 CameraDirector, T12 Vignette, T11 TimeScaleDirector | **YES — PR #293 (T9), #295 (T12), #285 (T11) all on `main`** |
| T17 Skip-after-first-kill | `86c9wjzjf` | to do | T8 wake-anim (soft) | **NO — T8 `86c9wjyp9` still `to do`** |
| T18 Below-10% HP pulse | `86c9wjz5e` | to do | T13 nameplate surface | n/a (sibling, ship in T13 PR or follow-up) |

W2 foundations landed: **TimeScaleDirector** (PR #285, `scripts/combat/TimeScaleDirector.gd`), **CameraDirector** (PR #293, `scripts/camera/CameraDirector.gd`, `request_zoom(target_scale, duration, anchor)` + `reset_to_player(duration)` — exactly the shape T16 needs), **Vignette** (PR #295, `scripts/ui/Vignette.gd`, locked `F2_BOSS_DEFEAT_TARGET=0.80 / DURATION=0.9` constant + named convenience method per Uma vignette-spec — T16 calls into the named method, not the generic API), **AudioDirector S1 ambient** (PR #296, paired with T10 — independent of W3 but proves AudioDirector composer pattern T14 audio needs).

**Wave-2 gap:** T8 (boss stand-up wake animation) is still `to do`. The W2 §4 table calls it a Wave-2 item but it never dispatched because it has a Sponsor-PixelLab dependency. T17 skip-collapse mentions "the wake animation" in Uma's spec but the skip-flag itself is purely a save-schema + intro-sequence-handler — T17 does NOT block on T8 art shipping; the skip-collapse references the wake-anim *timing slot*, not the wake-anim sprite asset. **Recommendation: T17 can fire without T8.** Document this explicitly in the dispatch brief so Devon doesn't second-guess.

## §1 — Dependency graph (parallelism shape)

```
  Already landed (Wave 2):
  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐
  │ TimeScaleDir │  │ CameraDir    │  │ Vignette             │
  │ (T11 PR285)  │  │ (T9 PR293)   │  │ (T12 PR295)          │
  └──────────────┘  └──────────────┘  └──────────────────────┘
        ▲                  ▲                    ▲
        └──────────────────┼────────────────────┘
                           │
                ┌──────────┴────────────┐
                │                       │
        ┌───────▼────────┐    ┌─────────▼──────┐
        │ T16 cinematic  │    │ (no W3 nameplate dep on CameraDir
        │ (Drew+Devon)   │    │  per scope doc §3 T13 — HUD-anchored)
        └────────────────┘    └────────────────┘

  Wave-3-internal coupling:
  ┌────────────────┐
  │ T13 Nameplate  │ ◀─── T18 below-10% pulse (sibling — ships in T13 PR
  │ (Devon)        │                            or immediate follow-up)
  └────────────────┘

  No-dep parallelizable (fire day 1):
  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
  │ T13 Nameplate  │  │ T14 Door slam  │  │ T15 HUD region │
  │ (Devon)        │  │ (Uma → PixelLab│  │ (Uma → Devon)  │
  └────────────────┘  │   → Drew → Dev)│  └────────────────┘
                      └────────────────┘
  ┌────────────────┐  ┌────────────────┐
  │ T16 cinematic  │  │ T17 skip flag  │
  │ (Drew + Devon) │  │ (Devon)        │
  └────────────────┘  └────────────────┘
```

**Hard deps:**
- **T16 → T9 CameraDirector, T12 Vignette, T11 TimeScaleDirector** — all merged. **Cleared.**
- **T18 → T13 surface** — T18 lands on the nameplate `BossNameplate.gd`. Ship in same PR as T13 (Devon's choice) OR immediate follow-up PR off T13's merge SHA.

**Soft deps:**
- **T13 + T15 + T18** all HUD-canvas-layer surfaces. Soft-coordinate the CanvasLayer index (T13/T15 both want `layer = 10`; Vignette already pinned at `layer = 5`; BossDefeatedTitleCard at `layer = 50`). Devon resolves in T13 PR by reading the current HUD-canvas tree; T15 + T18 inherit. No hard block.
- **T17 → T8 wake-anim (soft)** — Uma's skip-rule references the wake animation visually; T17 implementation is save-schema + skip-handler in `Stratum1BossRoom._run_entry_sequence()`. T17 can fire now and the skip-collapse will be tested against whatever wake-anim placeholder is shipping (self-shake today; T8 art when it lands).

**No-dep parallelizable:** T13, T14, T15, T16, T17. Five of six can fire day-1. T18 follows T13.

## §2 — Recommended dispatch order

**Day 1 (5 parallel dispatches):**
1. **T13** → Devon (HUD lane; largest single surface — start first so Tess QA cycle is in flight by mid-week)
2. **T14** → Uma direction first (door visual style + palette-lock + animation-state list for Sponsor PixelLab). Uma's brief is a 1-day direction doc; PixelLab generation chains after; Drew + Devon integration is the back-half. Uma direction dispatched day-1; the chain absorbs across W3 calendar.
3. **T15** → Uma direction first (red treatment palette swatch + HUD-region layout). Devon implementation chains after Uma's direction lands. Uma dispatched day-1.
4. **T16** → Drew + Devon (Drew owns the ember-rise refactor + camera/vignette wiring; Devon owns the `boss_kill_horn.ogg` composer). Dispatched day-1 as a paired-dispatch — both authors work in their own worktrees against the W2-landed `CameraDirector.request_zoom(1.5, 0.9, last_boss_position)` + `Vignette.tween_to_f2_boss_defeat()` + `TimeScaleDirector.freeze(0.3)` APIs.
5. **T17** → Devon (save-schema lane). Pure schema migration (v3→v4) + skip-handler. Independent of T8 wake-anim. Dispatched day-1.

**Day 2 (T13's PR ~mid-day):**
6. **T18** → Devon, queued as immediate follow-up on T13's branch OR ship-with-T13. Devon's call.

**Sequencing constraints:**
- **Devon load:** T13 (L) + T15 (M, paired with Uma) + T17 (M) + T18 (S-M, ships-with-T13) = ~3 dispatches landing on Devon over W3. Stagger within Devon's worktree by completing T13 first (largest), then T15 + T17 in parallel via fresh dispatches after T13 lands (sub-agent context-load-discipline memory). **T18 ships inside T13's PR if Devon prefers** — recommended path to reduce orchestrator round-trips.
- **Drew load:** T16 (L) only — clean.
- **Uma load:** T14 direction + T15 direction. Two direction docs, both can ship day-1 in one Uma dispatch (the memory `m3-art-pass-collaboration-shape` shape — Uma does direction docs, Sponsor executes PixelLab).
- **Tess load:** five W3 PRs to QA. Stagger QA dispatches by PR-merge order — Tess can't self-QA test-only PRs (memory `tess-cant-self-qa-peer-review`) but every W3 PR is feat-class so no peer-review escape needed.

## §3 — Per-ticket dispatch briefs

Each brief below is dispatch-ready. Orchestrator pastes the relevant brief into the Agent() call when firing.

---

### Brief 1 — T13 BossNameplate (Devon, L)

- **Ticket:** `86c9wjz2d` — flip to `in progress` on dispatch.
- **Branch:** `devon/w3-t13-boss-nameplate` off `origin/main`.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-devon-wt`.
- **Scope:** Author `scenes/ui/BossNameplate.tscn` + `scripts/ui/BossNameplate.gd` per `team/uma-ux/boss-intro.md §"Boss nameplate spec"`. 480×56 px, anchored top-center 12 px from screen edge, `#1B1A1F` at 92% with 1 px ember-orange `#FF6A2A` border, `[!]` threat glyph, boss name from `MobDef.display_name` (16 px caps off-white `#E8E4D6`), `THREAT: ELITE` muted parchment, 3-segment 432×12 HP bar with 2 px ember separators. Phase labels: `PHASE 1` / `PHASE 2` / `PHASE 3` (10 px caps; active brightens to `#E8E4D6`, completed mutes, future at `#605C50`). Segments visually equal (each 144 px = 1/3 of 432). Active segment uses `#7A2A26` with ghost-damage drain (foreground drops instantly on hit, ghost layer drains over 0.6 s — same shape as regular mob HP bar). Slide down from screen top over 0.4 s on `entry_sequence_completed`. Subscribe to `Stratum1Boss.phase_changed` + `Stratum1Boss.damaged` signals.
- **Surface (files):**
  - NEW: `scenes/ui/BossNameplate.tscn`, `scripts/ui/BossNameplate.gd`
  - MOD: `scenes/levels/Stratum1BossRoom.tscn` or `scripts/levels/Stratum1BossRoom.gd` (instantiate BossNameplate at room load; signal-wire to `entry_sequence_completed`)
  - MOD: `assets/sprites/boss/Stratum1Boss.tres` if `MobDef.display_name` isn't already set to "WARDEN OF THE OUTER CLOISTER" (verify; add if missing)
- **Acceptance:**
  - Uma BI-07 through BI-14 all pass.
  - Slide-in over 0.4 s tween (eased) on `entry_sequence_completed`.
  - Ghost-damage drain visually identical to regular mob HP bar (same 0.6 s drain duration).
  - Idempotent across phase-transition spam — re-firing `phase_changed` while a previous transition is animating doesn't double-flash or de-sync the segments.
  - Phase HP weights are internal to `Stratum1Boss._begin_phase_transition`; the nameplate reads only the segment-relative HP and renders 1/3-width segments regardless.
  - **Paired GUT tests** (`tests/test_boss_nameplate.gd`, ≥8 tests): slide-in tween fires on signal, segment-fill driver tracks `damaged` correctly, phase-transition flashes separator + brightens next label, ghost-drain timing pin (0.6 s), idempotent re-signal, phase label colors match active/completed/future spec, threat label string equals `THREAT: ELITE`, name from `MobDef.display_name`.
  - **Playwright spec** (`tests/playwright/specs/boss-nameplate.spec.ts`): assert HTML5 visibility post-entry-sequence using `test-base.ts` fixture (universal warning gate); use the BI-07 / BI-09 / BI-11 / BI-13 sub-criteria as discrete assertions.
  - **HTML5 Self-Test Report** with screenshot of nameplate visible during boss fight at full + post-first-phase-transition states. Per `.claude/docs/html5-export.md § "A renderer-safe primitives argument is NOT a substitute for a screenshot"` — TextureRect / ColorRect / Label primitives still require visible-output evidence.
- **Dependencies:** None (HUD-anchored, no Camera2D / Vignette dep). T18 pulse will ship in same PR or immediate follow-up.
- **HTML5 visual-verification gate:** **YES.** Nameplate is tween + modulate + multi-CanvasLayer composition. Standard gate applies. If Devon cannot HTML5-verify locally, invoke the established escape-clause: honest-disclose + Sponsor-soak probe targets per `.claude/docs/html5-export.md § "Visual-verification escape clause"`.
- **Doc updates expected:** none required (nameplate is product-surface, not architecture). If a non-obvious finding surfaces during implementation — e.g. how the multi-CanvasLayer HUD index resolved between Vignette/Nameplate/HUD-region/InventoryPanel — Devon should include a `Non-obvious findings` section in the final report so maintain-docs can route into `html5-export.md` or a new doc.
- **Owner / size / priority:** Devon · L · normal.
- **Self-Test Report:** required pre-Tess (UX-visible PR on `ui/boss` surface per `self-test-report-gate`).

---

### Brief 2 — T14 Door slam visual + audio (Uma → Sponsor PixelLab → Drew → Devon, L)

This is a **multi-link chain ticket**, not a single dispatch. Orchestrator fires the chain in stages.

#### Stage 2a — Uma direction (Day 1)

- **Ticket:** `86c9wjz80` — flip to `in progress` on Uma dispatch.
- **Branch:** `uma/w3-t14-door-direction` off `origin/main`.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-uma-wt`.
- **Scope:** Direction doc `team/uma-ux/boss-room-door-spec.md` covering:
  - Door visual style (palette-lock per `team/uma-ux/palette.md` — S1 iron + ember). Reference for Sponsor PixelLab generation.
  - 4 animation states: `unlocked` (default), `slamming` (0.4 s slam animation), `locked` (post-slam static), `unlocking` (0.3 s unlock animation on `boss_defeated`).
  - 1-frame ember-flash on lock-bar at end of slam (per Uma `boss-intro.md` Beat 1).
  - 1-frame ember-flash on lock-bar at end of unlocking (per Uma `boss-intro.md` F3 — reverse of Beat 1).
  - Door dimensions (recommend matching room-entry threshold visual budget; Uma picks).
  - PixelLab prompt template (for Sponsor to copy-paste into the PixelLab MCP per `.claude/docs/pixellab-pipeline.md`).
- **Acceptance:** Direction doc is dispatch-ready for Sponsor PixelLab generation. Includes prompt + reference palette swatches + per-state visual description.
- **Dependencies:** None — Uma can ship direction day-1.
- **Owner / size:** Uma · M (direction-only, ~2 hr).

#### Stage 2b — Sponsor PixelLab (between Uma stage 2a merge and Drew stage 2c dispatch)

- **Sponsor-executed** per memory `m3-art-pass-collaboration-shape`. Orchestrator posts the PixelLab prompt to Sponsor with cleanup guidance (doctrine palette lock per `.claude/docs/pixellab-pipeline.md` Strategy 3 if needed). Sponsor returns 4 animation atlases (or single sprite with 4 anim frames depending on Uma direction).
- **Asset target:** `assets/sprites/world/boss_door/<state>_<dir>/frame_NNN.png` or a single `boss_door.tres` SpriteFrames — Drew picks the resource shape during Stage 2c.

#### Stage 2c — Drew integration (after PixelLab asset lands)

- **Branch:** `drew/w3-t14-door-integration` off `origin/main`.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-drew-wt`.
- **Scope:** Author `scenes/world/BossRoomDoor.tscn` + `scripts/world/BossRoomDoor.gd`. Replace the current door-trigger-Area2D in `scenes/levels/Stratum1BossRoom.tscn` with the new visible-door scene. Wire to `entry_sequence_started` (plays slam animation + sets locked state) and `boss_defeated` (plays unlock animation). The Area2D trigger logic itself stays — the door is now visible-state on top of the existing trigger, not the trigger replacement.
- **Surface:**
  - NEW: `scenes/world/BossRoomDoor.tscn`, `scripts/world/BossRoomDoor.gd`
  - MOD: `scenes/levels/Stratum1BossRoom.tscn` — add door instance at the room-entry threshold.
- **Acceptance:** BI-01, BI-02 visuals pass (door visibly slams + locks on entry); F3 unlock pass (door visibly unlocks + ember-flash on defeat). No regression to `entry_sequence_started` trigger (door is now visible-state, not the gate).
- **Dependencies:** Uma direction (stage 2a) + Sponsor PixelLab asset (stage 2b).
- **HTML5 visual-verification gate:** **YES.** Sprite + animation + ember-flash modulate. Standard gate. Drew honest-discloses if HTML5-unable; routes to Sponsor probes per established escape clause.

#### Stage 2d — Devon audio (after Drew stage 2c PR opens)

- **Branch:** `devon/w3-t14-door-audio` off Drew's stage-2c branch OR `origin/main` if Drew merges first.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-devon-wt`.
- **Scope:** Extend `scripts/audio/AudioDirector.gd` with `play_sfx("sfx-door-slam-heavy")` + `play_sfx("sfx-door-unlock-chime")` cue routing per `team/uma-ux/audio-direction.md` AD-XX entries. Compose / source `door_slam_heavy.ogg` (~0.5 s) + `door_unlock_chime.ogg` (~0.3 s). Wire `BossRoomDoor.gd` to fire these on slam-start + unlock-start respectively.
- **Surface:**
  - NEW: `assets/audio/sfx/door_slam_heavy.ogg`, `assets/audio/sfx/door_unlock_chime.ogg`
  - MOD: `scripts/audio/AudioDirector.gd`, `team/uma-ux/audio-direction.md` (add AD entries), `scripts/world/BossRoomDoor.gd` (call `AudioDirector.play_sfx(...)`)
- **Acceptance:** Audio plays in HTML5 audibly verified (per `.claude/docs/audio-architecture.md § "HTML5 audio-playback gate"`); `[combat-trace] AudioDirector.play_sfx | cue_id=sfx-door-slam-heavy` line emits on slam; `cue_id=sfx-door-unlock-chime` emits on unlock. Paired GUT test for cue-fire (via WarningBus + AudioDirector mock).
- **HTML5 audio-playback gate:** **YES** — door slam fires immediately on Player-stepping-through-trigger (user gesture already happened by movement input, so AudioContext is unlocked). Audible verification required.
- **Owner / size:** Devon · S-M (composer + wiring + paired tests ~3-4 hr).

#### T14 overall

- **Doc updates expected:** Uma stage may want to update `team/uma-ux/audio-direction.md` AD-XX entries for door SFX. Drew stage potentially adds a finding about how the visible-door coexists with the existing trigger-Area2D pattern (route to `combat-architecture.md` if structural).
- **Priority:** normal · longest critical-path chain in W3 (4 links). Mitigation: Uma direction fires day-1 so PixelLab queues during day 2-3.

---

### Brief 3 — T15 STRATUM 1 · BOSS HUD treatment (Uma → Devon, M)

#### Stage 3a — Uma direction (Day 1)

- **Ticket:** `86c9wjzbc` — flip to `in progress` on Uma dispatch.
- **Branch:** `uma/w3-t15-hud-region-direction` off `origin/main` (or co-located with Uma's stage 2a if Uma prefers single direction doc; recommend separate doc for clean ownership).
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-uma-wt`.
- **Scope:** Direction doc `team/uma-ux/hud-boss-region-spec.md` covering:
  - HUD top-right context-region default treatment (`STRATUM 1` in muted parchment `#B8AC8E`).
  - Red boss treatment palette swatch — Uma picks: `#7A2A26` (active-phase-segment red, scope-doc-recommended) OR a brighter ember-orange `#D24A3C` OR another red. Lock the hex.
  - Transition shape: swap text + recolor on `entry_sequence_completed`; revert on `boss_defeated`. Animation curve (instant snap or 0.2 s fade — Uma picks).
  - Layout dimensions (font size, padding, screen-edge offset matching existing HUD anchor).
- **Acceptance:** Direction doc dispatch-ready for Devon.
- **Owner / size:** Uma · S (direction-only, ~1 hr).

#### Stage 3b — Devon implementation

- **Branch:** `devon/w3-t15-hud-region` off `origin/main`.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-devon-wt`.
- **Scope:** Extend HUD scaffolding with a top-right context-region label per Uma's direction. Default `STRATUM 1` muted; swap to `STRATUM 1 · BOSS` red treatment on `entry_sequence_completed`; revert on `boss_defeated`. Region renders at screen-space (CanvasLayer; not zoomed by CameraDirector — automatic per CanvasLayer semantics).
- **Surface:**
  - Audit current HUD scene/script in `scripts/ui/` (may need a NEW `HUDContextRegion.tscn` or extension of an existing HUD root). Devon's call.
  - MOD: `scenes/levels/Stratum1BossRoom.tscn` or main HUD wiring to subscribe to `entry_sequence_completed` + `boss_defeated`.
- **Acceptance:** BI-20 passes. Region transitions on `entry_sequence_completed` + `boss_defeated`. Renders screen-space (no zoom interaction with CameraDirector — paired GUT test asserts CanvasLayer is properly above the world camera transform). Paired tests + Playwright spec.
- **Dependencies:** Uma stage 3a direction lock.
- **HTML5 visual-verification gate:** **YES** (text label + color modulate on Label). Standard gate.
- **Doc updates expected:** none baseline. If Devon's audit surfaces a non-obvious finding about HUD-canvas-layer architecture (currently no canonical HUD root in the project), route into `.claude/docs/` via a new `hud-architecture.md` or a section in `html5-export.md`.
- **Owner / size:** Devon · M.

---

### Brief 4 — T16 Embers-rising + camera ease-in + horn (Drew + Devon paired, L)

This is the **cinematic climax beat**. Single ticket, two-author paired-dispatch. Both authors work in their own worktrees on the same branch shape — coordinate via PR-comments.

#### T16a — Drew (boss death pipeline + cinematic-layer integration)

- **Ticket:** `86c9wjzgh` — flip to `in progress` on Drew dispatch (single ticket, single status flip on first author dispatch).
- **Branch:** `drew/w3-t16-embers-rising` off `origin/main`.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-drew-wt`.
- **Scope:** Refactor `Stratum1Boss._spawn_death_particles` (current: single-emission 24-particle burst) into a **sustained 0.9 s ember-rise** emitter (continuous emission, brighter + faster + more particles than the player-death-flow dissolve; ember-orange `#FF6A2A` + ember-light `#FFB066`). Compose with the existing PR #287 T2 final-freeze + PR #288 boss-defeated audio cuts. On `boss_defeated.emit`:
  1. `TimeScaleDirector.freeze(0.3)` — the 0.3 s F1 freeze (already wired in PR #287 T2; verify the call path or wire here if not yet).
  2. Sustained ember emitter spawns at boss's last position, runs for 0.9 s.
  3. `CameraDirector.request_zoom(1.5, 0.9, last_boss_position)` — slow ease-in over 0.9 s to F2 1.5× zoom centered on last-known boss position. After 0.9 s, the BossDefeatedTitleCard fades in (already wired in PR #289); after title-card hold (~0.8 s) + dismiss, Drew calls `CameraDirector.reset_to_player(0.4)` to return per Uma F3 ramp-out.
  4. `Vignette.tween_to_f2_boss_defeat()` — calls the locked F2 named method on Vignette (0.80 target, 0.9 s, ease-in-out-cubic). After title-card dismiss, `Vignette.tween_to_f3_post_titlecard()` returns to S1 default.
- **Surface:**
  - MOD: `scripts/mobs/Stratum1Boss.gd` (`_spawn_death_particles` refactor; signal wiring for camera/vignette calls — likely from `_die` or `_finish_death_sequence` chain)
  - MOD: `scenes/mobs/Stratum1Boss.tscn` (CPUParticles2D emitter config — sustained emission, lifetime, etc.)
  - Potentially MOD: `scripts/levels/Stratum1BossRoom.gd` (subscribe to `boss_defeated` to orchestrate vignette + camera if Drew prefers room-level orchestration over boss-level — Drew's call).
- **Acceptance:** F2 + BI-24 pass. Sustained ember rise over 0.9 s (NOT single explosive emission — verify by reading `Stratum1Boss.gd` emitter mode after refactor). Camera at 1.5× by T+0.9. Vignette at 80%. On title-card dismiss, camera returns to player-anchored over 0.4 s; vignette returns to S1 default (30%). Paired GUT tests assert: emitter switches to sustained mode on `_die`, camera reaches 1.5× within tolerance, vignette reaches 0.80, return-to-player completes within 0.4 s.
- **Dependencies:** **CameraDirector** (PR #293 — landed), **Vignette** (PR #295 — landed), **TimeScaleDirector** (PR #285 — landed). **All clear.**
- **HTML5 visual-verification gate:** **YES — heightened.** CPUParticles2D refactor (Polygon2D + CPUParticles2D are the empirically-demonstrated HTML5 sharp-edges per `.claude/docs/html5-export.md`) + camera-at-1.5× (T9 noted "T16 is the gate for non-1.0 zoom visual verification") + Vignette at peak 0.80. This is the cinematic climax — Sponsor will judge it directly. **Author screenshot + Sponsor soak probe targets are both required.** Probe targets: "ember rise is sustained for 0.9 s (not a single flash)", "camera reaches 1.5× cleanly without z-index regression", "vignette 0.80 doesn't crush the HUD readability", "title-card fade-in lands as the embers finish exiting screen".
- **Doc updates expected:** **YES.** This is the first non-1.0 CameraDirector zoom use; if it reveals any z-index / scaling regression on HTML5, capture into `html5-export.md`. The CPUParticles2D sustained-emitter pattern is a candidate for `combat-architecture.md` if novel (verify whether the player-death-flow already uses sustained emission — if yes, this is precedent; if no, this is the first instance and worth a section).

#### T16b — Devon (audio composer)

- **Branch:** Devon coordinates with Drew — fold audio into Drew's `drew/w3-t16-embers-rising` branch OR ship audio as separate `devon/w3-t16-horn` branch and merge first. Recommend: separate Devon branch lands first (Drew's PR depends on the `boss_kill_horn.ogg` asset existing), then Drew's PR opens against `main` after Devon's audio merge.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-devon-wt`.
- **Scope:** Compose / source `assets/audio/sfx/boss_kill_horn.ogg` — sustained warm horn note, 0.9 s, rising. Per `team/uma-ux/audio-direction.md` and `team/uma-ux/boss-intro.md` F2. Add AudioDirector cue routing (`AudioDirector.play_sfx("sfx-boss-kill-horn")`) — fires from Drew's `_spawn_death_particles` refactor.
- **Surface:**
  - NEW: `assets/audio/sfx/boss_kill_horn.ogg`
  - MOD: `scripts/audio/AudioDirector.gd` (cue routing — likely just an AD-XX entry in the dispatch table per the existing patterns)
  - MOD: `team/uma-ux/audio-direction.md` (add AD entry)
- **Acceptance:** Audio plays in HTML5 audibly verified; `[combat-trace] AudioDirector.play_sfx | cue_id=sfx-boss-kill-horn` emits on `boss_defeated`. Audible per `.claude/docs/audio-architecture.md § "HTML5 audio-playback gate"`. Honors `audio-architecture.md § "Tonal pattern — silence as punctuation"` — the horn IS the audio event; the silence after IS the punctuation. (BossDefeatedTitleCard from PR #289 already lands the silence; verify the horn-tail-into-silence timing matches Uma's intent.)
- **Dependencies:** None directly (Devon can compose ahead of Drew's PR).
- **HTML5 audio gate:** **YES** — same as T14 audio.
- **Owner / size:** Devon · S-M (compose + cue routing + paired tests ~2-3 hr).

#### T16 overall coordination

- Drew + Devon both work in their own worktrees on T16 simultaneously. Devon ships audio first (no game-side dependency on Drew); Drew's PR rebases onto the post-Devon-merge tip.
- Single ticket `86c9wjzgh`; flipped to `complete` only when both PRs merge.
- Tess QA covers the integration — Drew's PR is the "feature ships" surface; Devon's audio PR alone is a partial.

---

### Brief 5 — T17 Skip-after-first-kill flag (Devon, M)

- **Ticket:** `86c9wjzjf` — flip to `in progress` on dispatch.
- **Branch:** `devon/w3-t17-skip-first-kill` off `origin/main`.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-devon-wt`.
- **Scope:**
  1. Add `character.first_boss_kill_seen: bool` to save schema. Bump `Save.SCHEMA_VERSION: 3 → 4`. Add `_migrate_v3_to_v4(data)` migration step in `scripts/save/Save.gd` — backward-compat: missing field defaults to `false` (= first kill not seen).
  2. On first-ever `boss_defeated.emit()` per character, set `Player.first_boss_kill_seen = true` and snapshot to save.
  3. On subsequent boss intros, allow movement-key press (any of WASD / arrow keys per `_input` action map) during Beats 2-4 of `Stratum1BossRoom._run_entry_sequence()` to collapse the intro. Collapsed shape per Uma `boss-intro.md § "Skip rule"`: door slam (always plays), nameplate slides in fast (0.2 s instead of 0.4), boss music fades in fast (0.3 s instead of 0.6). First-ever fight is NOT skippable.
  4. The skip-collapse references the wake-anim timing slot (Uma's Beat 3); T8 wake-anim sprite asset is not yet shipping. **The skip collapses regardless of the wake-anim asset state** — Devon's handler reads the boss's current wake-anim duration (which today is self-shake placeholder), not a hard-coded value.
- **Surface:**
  - MOD: `scripts/save/Save.gd` — schema bump + migration step + character payload default
  - MOD: `scripts/player/Player.gd` (or `scripts/save/Save.gd` if first_boss_kill_seen lives in the save envelope rather than Player state — Devon's call; precedent is `first_level_up_seen` which lives on the save side per the PR #52 stat-allocation pattern)
  - MOD: `scripts/levels/Stratum1BossRoom.gd` — `_run_entry_sequence()` skip-handler. Subscribe to `_input` (or use an action) for movement detection during Beats 2-4.
  - MOD: `tests/test_save_migration.gd` — add `_test_v3_migration_chains_through_to_v4` test (precedent: `test_v0_migration_chains_through_to_v3`).
- **Acceptance:**
  - BI-21 + BI-22 pass. First-ever kill not skippable (`first_boss_kill_seen == false`); subsequent kills skippable on movement key during Beats 2-4. Save round-trip preserves `first_boss_kill_seen` across reload.
  - Paired GUT tests (`tests/test_first_boss_kill_skip.gd`, ≥6 tests): first kill not skippable, second kill skippable, save persistence across reload, migration v3→v4 default-false, migration chain v0→v4 idempotent, skip collapses intro timing to ~0.5 s (door-slam + fast-nameplate-slide).
  - Playwright spec optional; the skip-on-movement-key is a UX-visible flow worth one spec if Devon prefers (`tests/playwright/specs/boss-intro-skip.spec.ts`).
- **Dependencies:** None hard. Soft-dep on T8 wake-anim (skip-collapse references the wake-anim timing slot but T17 handler reads boss-side current wake duration, not T8 art). **T17 can fire now without T8.**
- **HTML5 visual-verification gate:** **N/A** — pure save-schema + input-handler. No tween / modulate / Polygon2D / CPUParticles2D / Area2D-state mutation in the scope.
- **HTML5 audio gate:** **N/A** — skip-collapse re-uses existing audio (door slam, nameplate bell, boss music) on a faster timeline; no new cues.
- **Doc updates expected:** if the skip-handler interacts with the existing `Stratum1BossRoom._run_entry_sequence()` sequencer in a way that becomes non-obvious (e.g. skip-collapse needs to cancel in-flight tweens vs. fast-forward them), capture the pattern into `combat-architecture.md § boss` or a new section.
- **Owner / size:** Devon · M.
- **Self-Test Report:** required (UX-visible PR — even though no visual primitives, the skip-flow is observable).

---

### Brief 6 — T18 Below-10% HP pulse (Devon, S-M)

- **Ticket:** `86c9wjz5e` — flip to `in progress` on dispatch.
- **Branch:** ship-with-T13 (`devon/w3-t13-boss-nameplate`) OR `devon/w3-t18-below-10-pulse` off T13's merge SHA. **Recommend ship-with-T13** to reduce orchestrator round-trips and Tess QA cycles.
- **Worktree:** `C:/Trunk/PRIVATE/RandomGame-devon-wt`.
- **Scope:** When the **active phase segment** drops below 10% of that phase's HP allocation, render a 1 px ember-orange `#FF6A2A` outline pulse at 1.5 Hz on the active segment. Telegraphs "phase transition imminent." Pulse stops on phase-transition (the new active segment starts un-pulsed; pulse re-engages if THAT segment drops below 10%). Idempotent across hit-spam.
- **Surface:** All edits in `scripts/ui/BossNameplate.gd` (T13's new file). Adds:
  - Threshold detection in the `damaged` signal handler (re-check after each damage event).
  - Pulse driver: a tween or `_process` modulator on the active-segment outline modulate-alpha at 1.5 Hz (~0.67 s period).
  - Phase-transition reset: on `phase_changed`, stop the pulse tween and reset the outline.
- **Acceptance:**
  - BI-15 passes. Pulse fires at 1.5 Hz when active segment <10%; stops on phase-transition; idempotent across hit-spam (re-firing `damaged` while pulsing doesn't double-start the tween).
  - Paired GUT tests (`tests/test_boss_nameplate.gd` extension or new file): pulse engages at <10% threshold, stops on `phase_changed`, no double-tween on hit-spam, pulse modulates alpha (visible-output assertion per `test-conventions.md § "Visual primitives — Tier 1"`).
  - Playwright spec optional; BI-15 visible behavior is screenshotable but the 1.5 Hz pulse is hard to capture cleanly — Devon's call.
- **Dependencies:** **T13 surface** (`scripts/ui/BossNameplate.gd` must exist). If shipped-with-T13, T18 is part of T13's PR; if separate, branches off T13's merge SHA.
- **HTML5 visual-verification gate:** **YES** — pulse is modulate-alpha tween on a ColorRect. Standard gate; Self-Test Report should include a screenshot showing the outline at peak alpha.
- **Doc updates expected:** none.
- **Owner / size:** Devon · S-M (if ship-with-T13, +~2-3 hr on T13's effort; if separate, ~3-4 hr standalone including PR cycle).

---

## §4 — Cross-cutting QA + risk register

**HTML5 visual-verification gate applies to:** T13, T14 (Drew stage), T15, T16 (Drew side), T18. **N/A for:** T14 (Uma direction stage — doc-only), T14 (Devon audio — audio gate not visual), T17 (save-schema + input-handler), T16 (Devon audio side — audio gate not visual). Five of six W3 tickets cross the visual gate; T16 is the heightened-risk one (CPUParticles2D + camera-at-1.5× + Vignette-at-peak).

**HTML5 audio-playback gate applies to:** T14 (Devon stage), T16 (Devon stage).

**Self-Test Report gate (UX-visible, author-posted before Tess):** all six W3 PRs (all are feat-class on ui/combat/integration/level/audio surfaces). No exemptions.

**Highest-risk surface this wave:** **T16 cinematic climax.** Heightened-gate from above; Sponsor will judge directly; cinematic-climax-beat. Mitigation: Drew + Devon paired dispatch; Devon audio merges first so Drew's branch can integrate; HTML5 Self-Test Report explicit screenshot + Sponsor probe targets.

**Calendar shape:** day-1 fires 5 dispatches (T13 / T14-Uma / T15-Uma / T16-Drew + T16-Devon paired / T17). Day-2/3 Uma direction docs land + chain into Sponsor PixelLab (T14) and Devon impl (T15). Day 3-5: T13 + T16 + T17 merge cycles. Day 5-7: T18 ship-with-T13 OR follow-up; T14 final integration after PixelLab + Drew. Realistic close: ~5-7 calendar days assuming Sponsor PixelLab turnaround on T14 is same-day.

## §5 — Doc-update flags (for orchestrator awareness)

Per `sub-agent-doc-update-reporting` memory, each W3 dispatch brief requires an explicit `Doc updates: ...` line in the sub-agent's final report. Briefs above include the expected-doc-update column. Two architectural captures are high-likelihood from W3 implementation:

1. **CameraDirector at non-1.0 zoom on HTML5** — T16 is the first consumer of `request_zoom(1.5, ...)`. If HTML5 reveals any z-index / scaling regression, capture into `.claude/docs/html5-export.md § "Camera2D + gl_compatibility"` or a new section in a fresh `camera-layer.md`. Maintain-docs Stop hook should fire on T16's merge PR.

2. **HUD canvas-layer architecture** — T13 + T15 + T18 all land HUD surfaces; T15 may need to spike the current HUD root architecture (the project does not have an obvious canonical HUD root scene per the existing `team/uma-ux/hud.md` doc — Devon may need to author one). If a canonical HUD root scene lands, capture into a new `.claude/docs/hud-architecture.md` via maintain-docs.

Neither is doc-orphan work; both are in-PR-scope. Orchestrator should expect maintain-docs to fire on T13 / T15 / T16 merge PRs.

## §6 — Cross-references

- `team/priya-pl/m3-tier2-boss-room-polish-scope.md §3 — Wave 3` — full T13-T18 scope detail.
- `team/uma-ux/boss-intro.md` — binding 30-criteria spec (BI-01 through BI-30 + F1-F4); W3 tickets map to BI-01, BI-02, BI-07 through BI-15, BI-20, BI-21, BI-22, BI-24, F2, F3 door-unlock.
- `team/uma-ux/vignette-spec.md` — Uma's vignette direction (T12 base; T16 calls `tween_to_f2_boss_defeat()` named method).
- `team/uma-ux/audio-direction.md` — AD-XX cue table; T14 + T16 audio extend this.
- `scripts/camera/CameraDirector.gd` — `request_zoom(target_scale, duration, anchor)` API; T16 consumer.
- `scripts/ui/Vignette.gd` — locked F2/F3 named methods; T16 consumer.
- `scripts/combat/TimeScaleDirector.gd` — `freeze(duration)` API; T16 (already wired in PR #287 T2).
- `scripts/save/Save.gd` — `SCHEMA_VERSION = 3` at HEAD; T17 bumps to 4.
- `.claude/docs/html5-export.md § "Visual-verification escape clause"` — escape-clause workflow Drew/Devon/Tess invoke if HTML5-unable.
- `.claude/docs/audio-architecture.md § "HTML5 audio-playback gate"` — T14 + T16 audio gate.
- `.claude/docs/test-conventions.md § "Universal warning gate"` — every paired test must use `NoWarningGuard` / `test-base.ts`.
- `.claude/docs/time-scale-director.md § "Scaled tweens — intentional pause during freeze"` — T13 nameplate slide-in is cinematic tween (scaled); behaves correctly under T2 hit-pause.
