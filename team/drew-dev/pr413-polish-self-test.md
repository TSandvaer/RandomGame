## Self-Test Report — fire-casting polish (86ca5agrd) — commit `5295dbd`

Sponsor soak #413 (build 5fd9f45, `?start_room=3` Room 04) raised three brazier-warden fire-casting findings. **This commit lands fix #1 (tint) + fix #2 (projectile). Fix #3 (single-bowl cast) is escalated to orch pixel-mcp** — empirical evidence below proves a sub-agent PIL erase is not cleanly viable, matching the ticket's own "orch decides cast approach / pixel-mcp surgical edit" note.

### Per-fix status

| # | Fix | Status |
|---|---|---|
| 1 | Drop red telegraph tint | ✅ DONE — code |
| 2 | Real fireball projectile + rotation | ✅ DONE — asset + code |
| 3 | Single-bowl cast (erase conjured raised-hand flame) | ⛔ BLOCKED on tooling — escalated to orch (pixel-mcp / PixelLab re-gen) |

### Fix #1 — red telegraph wash removed

Root cause (diagnosed, not assumed): post-M3W-3 the Shooter `Sprite` child is an `AnimatedSprite2D`. `_play_attack_telegraph` had only a `ColorRect` branch + an `else` that tinted `self` (the CharacterBody2D). So the vivid red `ATTACK_TELEGRAPH_TINT = Color(1.0, 0.30, 0.30)` was multiplied across the WHOLE warden sprite (hood + robe + brazier) — Sponsor's "red highlight on the character."

Fix: 3-branch resolver mirroring `_play_hit_flash` (AnimatedSprite2D → tween `Sprite.modulate`; ColorRect → `.color`; bare → `self.modulate`) so the telegraph never tints the parent body, AND reduced the tint to a barely-perceptible warm ember glaze `Color(1.0, 0.97, 0.92)`. The `casting_a_fireball` windup frames now carry the aim read; the colour wash is redundant. (`scripts/mobs/Shooter.gd:179` const + `:653` `_play_attack_telegraph`.)

### Fix #2 — fireball projectile + travel-direction rotation

Placeholder was an 8px yellow `ColorRect` (`Projectile.tscn` `Sprite` child). Pulled the generated 96×96 fireball, cropped to the alpha bbox, rotated so the comet **head points +X / east** (intrinsic head dir was ~138° down-left — measured by bright-core vs opaque centroid), scaled to 20×20 → `assets/sprites/projectiles/fireball.png`. `Projectile.tscn` `Sprite` is now a `Sprite2D` (texture_filter=nearest) bound to it. `Projectile._orient_sprite_to_velocity` (called from `_ready`) sets `Sprite.rotation = velocity_vec.angle()` once on spawn (straight-line travel — no per-tick re-orient), so the trail trails correctly in all 8 directions.

**Author-side visual verification of the rotation (PIL render of the asset at the 8 octant angles the game applies):** head leads + trail trails correctly in E/SE/S/SW/W/NW/N/NE. (Render generated locally during dev; not committed.)

### Fix #3 — single-bowl cast: BLOCKED, escalated to orch (with evidence)

The brief asked to erase the conjured raised-hand flame from the `casting_a_fireball` frames (8 dirs × 6 frames, copied into both `atk/` and `telegraph/`). I diagnosed-via-trace before editing (per `diagnostic-traces-before-hypothesized-fixes`) and found the naive "erase the second flame" framing is **not cleanly executable with the pixel tooling available to a sub-agent (PIL only — pixel-mcp/PixelLab are orch-only per `pixellab-pipeline.md` § Execution context):**

1. **No stable spatial separator.** The held brazier and the conjured flame **swap relative position and overlap in both x and y across the 6-frame gesture**. A fixed clip (e.g. `x<62`, or upper-left `x<60 ∧ y<58`) erased brazier pixels in frames 000/005 (single-flame frames that should be untouched: 5–12 px chewed off the brazier) while *under*-erasing the conjured flame (8 px of a ~40 px cluster) in frame 002. Preview renders confirmed a damaged brazier + a still-visible second flame.
2. **Flame mask is contaminated direction-dependently.** Connected-component clustering of the ember mask is clean only for `south` (clear far cluster at dist ~17 px from the brazier anchor). For `east/west/north/north-east/north-west` the brazier flame itself fragments into 6–14 small clusters (red eye-glow + ember speckle bleed in), so a "erase clusters far from the brazier anchor" rule would erase legitimate brazier fragments — exactly the "clip the bowl / orphan pixels" failure the brief warns against.
3. **The two-bowl read is direction-dependent.** It is clearest in the camera-facing `s`/`se`/`sw` frames (which Sponsor saw in Room 04); in `n`/`e`/`w` the conjured flame is largely self-occluded and already reads as ~single.

Clean removal requires per-frame, per-region manual pixel painting **with inpaint of the robe/hand underneath the erased flame** — true pixel-art editing, not algorithmic masking. Per the ticket ("pixel-mcp surgical edit of the harvested cast frames... Orch decides approach"), this routes to the orch's pixel-mcp surface. **No partial/blind edit shipped** (no-silent-compromise).

### HTML5 visual-verification gate — escape clause invoked (author cannot launch browser)

Fixes #1 (modulate-tween routing) + #2 (Sprite2D + Texture2D render) are HTML5-visual-gated surfaces. As a CLI sub-agent I cannot launch an interactive browser against a release-build artifact. Per `html5-export.md` § "Visual-verification escape clause," I honest-disclose and list probe targets for the **integ-build Sponsor re-soak** the orch is already planning for the #413+#414 convergence:

- **Probe A (tint):** aim a shooter (Room 04) — the warden shows his natural dark-hood/brown-robe/ember colours during the AIMING windup; NO red wash on the character. The `[combat-trace] Shooter._play_attack_telegraph | ... tint=(1.00,0.97,0.92)` line confirms the new tint value loaded (vs old `tint=(1.00,0.30,0.30)`).
- **Probe B (projectile art):** the fired projectile is a fireball sprite (not a yellow square).
- **Probe C (projectile rotation):** kite the shooter to several angles — the fireball's comet head points along travel in every direction (trail behind).

`tests/playwright/specs/drew-shooter-rig-self-soak.spec.ts` (already on-branch, `test.skip`) is the harness vehicle for an artifact self-soak — flip to `test` with `RELEASE_BUILD_ARTIFACT_PATH` once the integ artifact builds.

### Tests (paired, catch the bug class)

- `tests/test_projectile.gd` +3: `test_sprite_rotation_matches_velocity_angle` (6 octants), `test_orient_sprite_no_op_on_zero_velocity`, `test_orient_sprite_safe_with_no_sprite_child`.
- `tests/test_mob_attack_telegraph.gd` +1: `test_shooter_telegraph_tint_is_not_a_vivid_red_wash` (g,b ≥ 0.85 regression guard). Existing Shooter telegraph tests (tween-created-on-aiming, not-white, html5-safe) re-verified to pass with the new tint.
- gdlint: clean (only the pre-existing `max-file-lines` warning on Shooter.gd, baseline 1041 lines, warnings-only in CI). gdformat: 4 files unchanged.

### Cross-lane integration check (PR #216 gate)

- **`[combat-trace]` contract preserved:** `Shooter.pos`, `Shooter._set_state`, `Shooter._play_anim` untouched. `Shooter._play_attack_telegraph` trace keeps the `tween_valid=%s tint=(%.2f,%.2f,%.2f)` shape (only the tint VALUE changed) — `test_playwright_trace_string_contract.gd` prefix greps unaffected.
- **Player iframes / Damage constants:** untouched (projectile damage still routed via `DamageScript.compute_mob_damage`; no formula change).
- **RoomGate signal chain:** untouched (`mob_died` payload unchanged).
- **PR #414 (Devon, cornered-aim) overlap:** my edits to `Shooter.gd` are confined to the telegraph const + `_play_attack_telegraph` body — disjoint from the kiting/cornered-aim state-machine lines #414 touches. Orch handles convergence at integ-build.
- **Adjacent specs probed:** `test_projectile.gd` (extended), `test_shooter*.gd` / `test_mob_attack_telegraph.gd` (telegraph), projectile is bare-instanced in most Shooter tests so the Sprite2D swap is a no-op there.

### Regression guard (Done clause)

`test_shooter_telegraph_tint_is_not_a_vivid_red_wash` fails if a future edit re-introduces a saturated-red telegraph tint; `test_sprite_rotation_matches_velocity_angle` fails if the projectile rotation wiring regresses.
