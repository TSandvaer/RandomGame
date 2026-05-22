# M3-T2-W3-T13 — BossNameplate (480×56 top-center HUD banner) + T18 below-10% pulse

**Ticket(s):** `86c9wjz2d` (T13) + `86c9wjz5e` (T18, ship-with).
**Direction:** `team/uma-ux/boss-intro.md` § "Boss nameplate spec" (BI-07..BI-15).
**Scope:** `team/priya-pl/w3-dispatch-plan.md` §3 Brief 1 + Brief 6.

## Summary

A wider, more elaborate variant of the standard mob nameplate that anchors
to the HUD canvas and slides down from the screen top when the boss-room
entry sequence completes. Drives off `Stratum1Boss.damaged` (ghost-damage
drain) and `Stratum1Boss.phase_changed` (segment cascade + separator
flash). T18 ships in the same PR per Priya's recommendation to reduce
orchestrator round-trips — pulse uses the same nameplate scene + ColorRect
primitives; no risk delta vs separate PR.

## Surfaces touched

- **NEW** `scenes/ui/BossNameplate.tscn` — minimal scene root (CanvasLayer).
- **NEW** `scripts/ui/BossNameplate.gd` — 480×56 banner + 3-segment HP bar
  + ghost-drain + T18 below-10% pulse. ColorRect-only primitives
  (renderer-safe per `.claude/docs/html5-export.md`).
- **MOD** `scripts/levels/Stratum1BossRoom.gd` — spawn the nameplate in
  the deferred fixture pass + call `show_for(boss)` from
  `_complete_entry_sequence`.
- **NEW** `tests/test_boss_nameplate.gd` — 14 GUT tests (≥8 required).
- **MOD** `tests/test_stratum1_boss_room.gd` — +2 integration tests for
  the room→nameplate wiring (REGRESSION-86c9wjz2d).
- **NEW** `tests/playwright/specs/boss-nameplate.spec.ts` — HTML5 end-to-
  end via `?start_room=8&boss_hp_mult=0.05` URL params.

## Acceptance (BI-07 .. BI-15)

| BI    | Check | Implementation |
|-------|-------|---------------|
| BI-07 | Slide-in from screen top, 12 px margin, 0.4 s ease-out | `_start_slide_in_tween` (offset_top / offset_bottom + modulate.a) |
| BI-08 | 480×56, `#1B1A1F` α 0.92, 1 px ember `#FF6A2A` border | `PANEL_WIDTH/HEIGHT` + `PANEL_BG` + 4-strip ember-border ColorRects |
| BI-09 | Boss name `WARDEN OF THE OUTER CLOISTER` (caps from MobDef) | `_apply_boss_name` `.to_upper()` on `mob_def.display_name` |
| BI-10 | `THREAT: ELITE` muted parchment 12 px caps | `_threat_label` |
| BI-11 | 3 visually-equal segments + 2 px ember separators | `SEGMENT_WIDTH = (432 - 2*2) / 3` |
| BI-12 | `PHASE 1/2/3` labels above each segment | `_build_segment_row` |
| BI-13 | Active segment `#7A2A26` fg + ghost-damage drain 0.6 s | `_set_segment_fg_fill` + `_start_ghost_drain_tween` |
| BI-14 | Future-phase segments 100% fill at 60% brightness; completed at 0 | `_color_for_segment_phase` + `_paint_initial_segment_state` |
| BI-15 | <10% in active phase → 1 px ember outline pulse 1.5 Hz | T18 — `_pulse_outlines` + `_start_pulse_if_inactive` |

## Test bar

**14 GUT tests in `test_boss_nameplate.gd`** + 2 integration tests in
`test_stratum1_boss_room.gd` (REGRESSION-86c9wjz2d). Coverage:

1. Scene loads + composition primitive counts (3 fg + 3 ghost + 2
   separators + 3 pulse outlines).
2. CanvasLayer `layer = 10` (HUD band).
3. All locked colors HDR-clamp safe (every RGB ≤ 1.0).
4. Spec dimensions locked (480×56, 12 px margin, 0.4 s slide, 0.6 s
   ghost-drain).
5. Phase thresholds match `Stratum1Boss.PHASE_2_HP_FRAC` / `PHASE_3_HP_FRAC`
   (drift-detector).
6. `show_for` uppercases `display_name` from title-case MobDef.
7. `show_for` handles empty `display_name` → fallback.
8. `show_for` is idempotent (second call no-op).
9. Phase-label colors track active / completed / future states.
10. Ghost-drain tween kill-restarts on hit-spam (Tier 1 corollary —
    reference change, NOT `is_valid()` flip).
11. `phase_changed` is idempotent on replay-emit + backward emit.
12. T18 pulse engages when active-segment fill < 10%.
13. T18 pulse stops on phase transition.
14. `boss_died` dismisses pulse + ghost tweens + is idempotent.

Integration tests:

- `test_boss_nameplate_spawned_in_deferred_fixture_pass` — nameplate
  parented under room after `_assemble_room_fixtures` drains.
- `test_boss_nameplate_shown_on_entry_sequence_completed` — end-to-end
  wire from `room.complete_entry_sequence → nameplate.show_for → uppercase
  name rendered`.

## Cross-lane integration check (per PR #216 gates)

Adjacent surfaces audited:

- **Vignette** (layer 5, PR #295) — nameplate at layer 10 paints above the
  vignette as intended; tween scaling (both default `create_tween`)
  composes correctly under T2 hit-pause / T16 freeze. **NO drift.**
- **BossDefeatedTitleCard** (layer 50, PR #289) — title card paints over
  nameplate; nameplate's `_on_boss_died` dismisses its own tweens so no
  competing animation during the title-card hold. **NO drift.**
- **Main HUD** (layer 10) — nameplate is on the same CanvasLayer band but
  in a separate CanvasLayer instance (the nameplate is its own
  CanvasLayer, not a child of `_hud`). Same-layer paint order resolves
  via scene-tree order: nameplate is added after HUD by Stratum1BossRoom
  in the deferred fixture pass. HUD vitals top-left + nameplate top-center
  don't overlap geometrically. **NO drift.**
- **InventoryPanel** (layer 80) — paints over nameplate when opened;
  nameplate keeps animating underneath (tweens are scaled-process and
  pause naturally if InventoryPanel triggers freeze via TimeScaleDirector).
  **NO drift.**
- **Stratum1Boss state machine** — nameplate subscribes to `damaged`,
  `phase_changed`, `boss_died` signals; these are read-only subscriptions.
  No mutation of boss state. **NO drift.**

## Regression-guard line

A future PR that breaks the nameplate slide-in wire (moves the `show_for`
call out of `_complete_entry_sequence`, or removes the
`_spawn_boss_nameplate` call from `_assemble_room_fixtures`) is caught by
`test_boss_nameplate_shown_on_entry_sequence_completed`. A future PR that
breaks the multi-segment composition (regresses 3 fg + 3 ghost + 2
separators to a single bar) is caught by
`test_composition_primitives_count`. A future PR that drifts a locked
color above the HDR clamp is caught by
`test_all_colors_are_html5_safe_sub_one`.

## HTML5 visual-verification gate

This is a tween + modulate + multi-CanvasLayer composition. Per
`.claude/docs/html5-export.md` § "A renderer-safe primitives argument is
NOT a substitute for a screenshot" — Self-Test Report (separate comment)
invokes the per-surface escape clause: all primitives are ColorRect /
Label (renderer-safe class — same primitive class as Vignette + HUD +
BossDefeatedTitleCard which all shipped clean), modulate-alpha tweens on
sub-1.0 channels, no Polygon2D / CPUParticles2D / Area2D state. Routes
interactive visual verification to Sponsor-soak with concrete probe
targets.

## Doc updates

Likely no `.claude/docs/` capture warranted — nameplate is product-surface
not architecture. If the multi-CanvasLayer HUD composition surfaces a
non-obvious finding during QA (e.g. canonical HUD-root architecture
needs documenting), maintain-docs will route it.
