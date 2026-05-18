## Summary

M3W-6 lands the S2 Stoker mob as a Path A (pre-bake separate atlas) palette-swap retint of the Grunt v2 silhouette per `team/DECISIONS.md` 2026-05-18 + `team/uma-ux/palette-stratum-2.md §5` line 191.

Phase-1 ship-state: hooded Grunt silhouette + S2 cloth/skin retint (`#7A1F12` cloth, `#7E5A40` skin, `#D24A3C` aggro eye-glow). Phase-2 miner-cap re-authoring is the M4 backlog item (`86c9uze5j`).

- **Closes:** ClickUp [`86c9v799g`](https://app.clickup.com/t/86c9v799g)
- **Depends on:** M3W-3 (PR #275, merged) — Grunt v2 atlas is the bake source.

## What lands

- **Atlas (280 PNGs):** `assets/sprites/stoker/_pixellab_anims/Stoker_S2_Cinder_Vaults/animations/<state>/<dir>/frame_NNN.png` — deterministically baked from Grunt v2 frames via `tools/bake_stoker_palette.py`. Mirror layout: 5 anims (walk/atk/atk_telegraph/hit/die) x 8 dirs x N frames.
- **SpriteFrames:** `assets/sprites/stoker/Stoker.tres` — mirrors `Grunt.tres` shape; 280 path refs to the Stoker bake root; distinct `uid://b0embergrave_stoker_sprite_frames`.
- **Scene:** `scenes/mobs/Stoker.tscn` — `class_name Stoker extends Grunt`, AnimatedSprite2D + CircleShape2D(12), `texture_filter = NEAREST`, initial `walk_s` frame-0 hold per M3W-1 convention.
- **Script:** `scripts/mobs/Stoker.gd` — inherits Grunt AI verbatim; Phase-2 extension surface in doc header.
- **MobDef:** `resources/mobs/stoker.tres` — id `&"stoker"`, display "Stoker", same HP/damage/speed/loot as Grunt for M3 phase-1 (reuses `grunt_drops.tres`).
- **Paired GUT test:** `tests/test_stoker_palette_swap.gd` per Priya's acceptance criterion #4 — animation-wire parity + palette-swap pixel-sample assertion + visibly-distinct-from-Grunt assertion.
- **Bake tool:** `tools/bake_stoker_palette.py` — committed for reproducibility.

## Mechanism — Path A pre-bake (locked per DECISIONS.md 2026-05-18)

The bake script uses **role-via-luminance band routing** instead of pure Euclidean nearest-neighbor. Why: the Grunt v2 source has 501 raw colors dominated by brown clusters (`#68504F` at 20.60%, `#392F32` at 24.95%). Pure RGB distance routes the dominant body brown to S2 skin (`#7E5A40`) because brown→brown wins over brown→red — but the Grunt is HOODED so those browns are ALL cloth. Luminance routing maps the dominant body cluster (Y in [80, 100]) directly to `#7A1F12` cloth_base. This is the applied case of the trap documented in `.claude/docs/pixellab-pipeline.md` Nearest-neighbor-breaks-doctrine-ramp-intent-for-mid-tones rule.

Character-beat overrides preserved per `.claude/docs/pixellab-pipeline.md` Strategy-3 refinement:
- **Red eye-glow override** — `R > 1.5 * max(G,B) AND R >= 80` routes to `#D24A3C` aggro before luminance binning.
- **Iron-weapon override** — near-grey mid-tones (R≈G≈B in [120, 200]) route to `#9C9590` weapon edge.

### Output palette distribution (full atlas, 179,220 opaque pixels)

| Output hex | Role | % of opaque pixels |
|---|---|---|
| `#000000` | outline | 36.80 |
| `#1A0A06` | cloth_deepest | 24.96 |
| `#7A1F12` | cloth_base (S2 anchor) | 20.62 |
| `#0A0404` | deep_shadow_warm | 6.33 |
| `#5A1108` | cloth_mid_shadow | 3.96 |
| `#A93020` | cloth_highlight | 3.82 |
| `#D24A3C` | aggro_eye_glow (PL-11) | 1.46 |
| `#B08660` | skin_highlight | 1.39 |
| `#7E5A40` | skin_base (S2 anchor) | 0.49 |
| `#9C9590` | iron_weapon | 0.16 |

Cloth + outline + shadow = ~96.4% → hooded silhouette reads as red-corroded cloth. Skin = 1.88% → exposed face fragments through hood, preserved. 10 distinct doctrine hexes (down from 501).

## Acceptance criteria coverage

Per `team/priya-pl/m3-scene-wiring-scope.md §M3W-6`:

1. **Stoker visibly distinct from S1 Grunt under S2 lighting** — `test_baked_atlas_visibly_distinct_from_grunt_source` pins ≤ 4 hex overlap with Grunt source. HTML5 release-build clip required for visual sign-off — see Self-Test Report.
2. **All 5 anims × 8 dir play** — `test_sprite_frames_resource_exposes_all_state_x_direction_keys` + scene shape test pin 40 anim keys + AnimatedSprite2D wiring.
3. **Full Stoker combat encounter clears** — Stoker inherits Grunt AI verbatim; full Grunt test suite + S1 mob-trio precedent already pin combat loop. Stoker.tscn is instantiable-but-not-instanced for M3 ship (S2 chunk authoring is downstream).
4. **Paired GUT test asserts post-swap pixel sample matches S2 palette** — `test_baked_atlas_every_opaque_pixel_matches_s2_doctrine_palette` walks 40 sample frames and asserts every opaque hex is doctrine. Plus positive-assertion tests for cloth_base + outline + aggro eye-glow anchors.
5. **HTML5 release-build clip of Stoker** — see Self-Test Report.

## Regression-guard line

- **Palette-swap pixel assertion** catches any direct PNG edit that re-introduces off-doctrine pixels AND any bake-script regression.
- **Visibly-distinct assertion** catches the regression where `Stoker.tscn` forgets to swap SpriteFrames and accidentally points at `Grunt.tres` (overlap would jump from ≤4 hexes to ~500).
- **Inheritance pin** (`test_inherits_grunt_class_for_behavior_parity`) catches a Phase-2 refactor that splits Grunt→Stoker hierarchy and silently breaks AI parity.

## Cross-lane integration check

- **Inventory + Loot:** Stoker reuses `grunt_drops.tres` → no new loot-table items → no `STARTER_ITEM_PATHS` impact per combat-architecture.md.
- **RoomGate / Multi-mob:** Stoker.tscn is instantiable-but-not-instanced (mirrors M3W-5 NPC pattern); when S2 chunk authoring lands, mob instances inherit Grunt's existing `RoomGate.register_mob` CONNECT_DEFERRED path unchanged.
- **Pickup:** unaffected — uses Grunt's existing `MobLootSpawner` pipeline.
- **AudioDirector:** Stoker is silent at the per-mob level (audio cues are M3W-7).
- **Hitbox / Projectile:** inherited verbatim from Grunt's encapsulated `_init` deferred-monitoring pattern; no new Area2D mutation surface.

## Test plan

- [ ] CI green (GUT headless suite + parse-failure scan)
- [ ] HTML5 release-build verification: trigger workflow, soak in Chromium/incognito with cache-clear per html5-export.md. Verify Stoker visibly-distinct from Grunt (red cloth dominant), all 8 walk dirs, hit-flash channel-sum delta, aggro eye-glow visible during atk states.
- [ ] Self-Test Report comment posted before Tess review

## Self-Test Report

Forthcoming — release-build trigger initiated (run `26028150592`). Will land as a follow-up comment per `[[self-test-report-gate]]` before Tess review.
