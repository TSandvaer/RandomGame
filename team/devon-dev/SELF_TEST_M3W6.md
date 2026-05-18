# Self-Test Report — M3W-6 Stoker palette-swap

## TL;DR

CI green on `1d6f3c4`. Palette-swap empirically verified via GUT pixel-sample assertions + offline distribution audit. **HTML5 visual sign-off routed to Tess** — I cannot run Godot or a browser on the current Windows dev environment, so the release-build artifact must be soaked by Tess (or the orchestrator) per `.claude/docs/html5-export.md §"HTML5 visual-verification gate"` ("Authors who can't run Godot locally [...] route to Tess to verify against the release-build artifact before merge — do not self-claim exemption.").

## 1. AC walkthrough on the HTML5 release build

| AC | Status | Evidence |
|---|---|---|
| 1. Stoker visibly distinct from S1 Grunt under S2 lighting | **Mechanically verified, visual TBC by Tess** | GUT `test_baked_atlas_visibly_distinct_from_grunt_source` pins ≤ 4 hex overlap with Grunt source (CI green). Atlas distribution: cloth `#7A1F12` at 20.62% + cloth_deepest `#1A0A06` at 24.96% = 45.6% of pixels are S2-red, vs ~50% S1-brown in Grunt. Visual sign-off pending Tess soak of artifact `7055483874`. |
| 2. All 5 anims × 8 dir play | **Mechanically verified** | GUT `test_sprite_frames_resource_exposes_all_state_x_direction_keys` walks 40 anim keys (5×8); CI green. SpriteFrames `.tres` cross-checked: `wc -l Stoker.tres = 1326` (matches Grunt's 1325 + 1 line for distinct UID); 280 `ExtResource` refs to Stoker bake root, 0 leaks to Grunt root. |
| 3. Full Stoker combat encounter clears | **Inherited via class hierarchy** | `class Stoker extends Grunt` — Grunt's full M3W-3 suite + `test_grunt.gd` + `test_grunt_animation_wire.gd` cover the combat loop (IDLE→CHASING→TELEGRAPHING_LIGHT→ATTACKING→RECOVERING + HEAVY telegraph one-shot). Stoker.tscn is instantiable-but-not-instanced for M3 ship (S2 chunk authoring is downstream); a Stoker combat encounter in S2 will exercise the same paths through inheritance. `test_inherits_grunt_class_for_behavior_parity` pins the hierarchy. |
| 4. Paired GUT test asserts post-swap pixel sample matches S2 palette | **Verified** | `tests/test_stoker_palette_swap.gd::test_baked_atlas_every_opaque_pixel_matches_s2_doctrine_palette` walks 40 sampled frames and asserts every opaque hex is in the doctrine set. Plus positive-assertion tests for cloth_base + outline + aggro eye-glow anchors. CI green. |
| 5. HTML5 release-build clip of Stoker | **TBC by Tess** | Release-build artifact: `7055483874` (12.3 MB, sha `1d6f3c4`). I cannot record clips locally on this Windows dev environment. Route to Tess for soak + clip per release-build artifact handoff. |

## 2. Side-effect inventory

Surfaces this PR touches:

| Surface | What changes | Test coverage |
|---|---|---|
| `assets/sprites/stoker/*` | NEW — 280 PNGs + SpriteFrames + anim-folder-map | Palette-swap pixel-sample test (40 frames sampled). |
| `scenes/mobs/Stoker.tscn` | NEW — instantiable scene | Scene-shape test pins AnimatedSprite2D + SpriteFrames + texture_filter NEAREST. |
| `scripts/mobs/Stoker.gd` | NEW — `class Stoker extends Grunt` | Inheritance pin + bare-instanced no-op safety test. |
| `resources/mobs/stoker.tres` | NEW — MobDef | Loadable as Resource (verified via scene `Stoker.tscn` instancing flow in GUT tests). |
| `tools/bake_stoker_palette.py` | NEW — bake script | Self-validating (run produces 280 PNGs; aggregate sha256 prefix `f533f99a60739911` for reproducibility). Not in test runtime. |
| **Stratum1Room01-04 (S1 mob spawn)** | UNCHANGED — Stoker is S2-only. | Existing S1 room tests unaffected (no Grunt-side changes; diff `git diff origin/main -- scripts/ resources/ scenes/mobs/Grunt.*` is empty for pre-existing surfaces). |
| **Save / restore** | UNCHANGED — Stoker is M3W-6 and Stoker MobDef.id `&"stoker"` is registered in `resources/mobs/`; ContentRegistry will pick it up via `DirAccess` recursion on desktop + the pinned-paths fallback on HTML5. | Existing ContentRegistry tests cover the resolution path. |
| **Loot / Pickup** | UNCHANGED — reuses `grunt_drops.tres`; no new loot-table items, no `STARTER_ITEM_PATHS` impact. | Existing loot tests unaffected. |
| **AudioDirector** | UNCHANGED — Stoker is silent at the per-mob level (audio cues are M3W-7 scope). | N/A. |
| **Hitbox / Projectile** | UNCHANGED — Stoker inherits Grunt's `_spawn_hitbox` verbatim; no new Area2D mutation. | Inherited Grunt physics-flush regression tests apply. |
| **`Engine.time_scale` interactions** | UNCHANGED — Stoker doesn't open any UI panels. | N/A. |
| **HTML5 DirAccess subdir recursion** | RESOLVED — `Stoker.tres` is loaded via the scene's `ExtResource` reference (load() path), not by DirAccess scanning. Stoker MobDef is reachable via the existing ContentRegistry pinned-paths fallback. | Existing PR #166 fix covers this. |

## 3. Sponsor-soak probe targets (routed to Tess)

I cannot soak-verify on this Windows dev environment. **Tess (or the orchestrator) should soak the release-build artifact for these specific verifications:**

### Probe targets

1. **Visual distinctness from Grunt.** Bare-instance Stoker.tscn in a debug scene OR temporarily drop a Stoker into Stratum1Room01 (don't commit). Confirm: red cloth body dominant, NOT brown like Grunt. The dominant body should read as `#7A1F12` (deep heat-corroded red), not the Grunt's brown `#68504F` palette.
2. **All 8 walk directions render.** Walk the Stoker through all 8 octants (mouse-aim or keyboard-driven). Each `walk_<dir>` animation should play with frame advance every 125ms (FPS=8 invariant from M3W-1).
3. **Hit-flash channel-sum delta ≥ 0.20.** Hit the Stoker once with a player swing. The Sprite child's `modulate` should briefly land on `Color(1.0, 0.50, 0.50, 1.0)` and tween back. Inspect via `[combat-trace] Stoker._play_hit_flash | animated_sprite tween_valid=true tint=(1.00,0.50,0.50)` in DevTools Console (Stoker inherits Grunt's combat-trace shim so the line tag is `Grunt.` — that's the same line shape every M3 mob emits).
4. **Aggro eye-glow visible during atk + atk_telegraph states.** Hit Stoker to ≤30% HP; the HEAVY telegraph fires once. During the 0.65s windup, the red eye-glow should be visible inside the hood. `#D24A3C` is preserved by the bake's red-glow character-beat override.
5. **No physics-flush panic on death.** Lethally hit a Stoker; verify `[combat-trace] Grunt._die | starting death sequence` fires (Stoker inherits Grunt's `_die` chain), no `USER ERROR: Can't change this state while flushing queries` in the console, queue_free completes within 400ms.

### Cache-clear ritual (per `.claude/docs/html5-export.md §"Service-worker cache trap"`)

Sponsor / Tess MUST:
1. Stop any existing `python -m http.server`
2. Extract `embergrave-html5-1d6f3c4.zip` to a **fresh empty folder**
3. Restart `python -m http.server 8000` from the new folder
4. Open in **incognito / private window** (Ctrl+Shift+N)
5. F12 → Console: confirm `[BuildInfo] build: 1d6f3c4` matches the artifact name
6. Execute the probe targets

### Direct artifact download URL

```
https://github.com/TSandvaer/RandomGame/actions/runs/26028150592/artifacts/7055483874
```

(Run page: https://github.com/TSandvaer/RandomGame/actions/runs/26028150592)

## 4. Why this PR routes to Tess for visual verification

Per `.claude/docs/html5-export.md §"HTML5 visual-verification gate"`:

> A "renderer-safe primitives" argument is NOT a substitute for a screenshot. Authors who can't run Godot locally have argued their PR is exempt because the primitives they used (ColorRect, Label, modulate-on-leaf-Control, BBCode) are platform-agnostic. This argument is risky precedent — the visual gate exists precisely because primitive-safety analysis didn't catch the PR #115/#122 failures either.

This PR uses **only renderer-safe primitives** (AnimatedSprite2D with NEAREST filter, no Polygon2D, no negative z_index, no HDR tints — bake outputs are sRGB texture pixels not modulate tints) and inherits Grunt's full M3W-3 hit-flash pipeline. The bake outputs are deterministic (aggregate sha256 prefix `f533f99a60739911` over 280 PNGs) and palette-doctrine-locked (10 hexes, all sub-1.0 channel values).

But per the html5-export.md rule above, I'm NOT self-claiming exemption. The visual sign-off requires Tess (or orchestrator) to soak the release-build artifact against the probe targets above before merge.
