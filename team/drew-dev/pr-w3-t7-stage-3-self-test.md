# Self-Test Report — Stage 3 BoneCatalyst (W3-T7, ticket 86c9y7ygj)

## Scope claim

Stage 3 ships the BoneCatalyst (S2 melee bruiser) class + scene + .tres + MobRegistry registration + paired GUT tests. **No production play surface invokes the mob in this PR** — Stage 4 Part C will wire it into S2 chunks. This is the foundation drop.

## Done clause

- `scripts/mobs/BoneCatalyst.gd` — mob class with stationary channel-pose telegraph (`STATE_CHANNELING`, 0.60 s) — third readable melee silhouette vs S1 Grunt + S1 Charger per Uma §5.5.
- `scenes/mobs/BoneCatalyst.tscn` — placeholder ColorRect sprite (bone-corroded brown-rust `Color(0.30, 0.18, 0.16)`), CircleShape2D radius 13, collision_layer = enemy, collision_mask = world + player.
- `resources/mobs/bone_catalyst.tres` — 70 HP / 5 dmg / 50 move_speed / `ai_behavior_tag = &"melee_bruiser"` / 22 XP.
- `scripts/content/MobRegistry.gd` — `&"bone_catalyst"` appended to `_REGISTRATIONS`.
- `tests/test_bone_catalyst_mob_class.gd` — 19 tests covering mob-class smoke, state-machine path, channel direction re-resolves at strike time, killed-mid-channel-no-slam, S1-melee-differentiation pins (vs Grunt + Charger), Uma §5.5 channel-duration window pin.
- `tests/test_mob_registry_bone_catalyst_pin.gd` — 7 tests covering registry round-trip + scene/def resolves + S2 stratum-scaling math.
- `team/drew-dev/level-chunks.md` — § "Stage 3 — Bone-Catalyst (melee bruiser)" appended.

## Regression guard

- **`[combat-trace] BoneCatalyst.pos`** trace contract — instrumentation contract preserved from Grunt/Charger/Shooter/SunkenScholar family. Harness pursuit greps map 1:1.
- **Player iframes / Damage formula constants** — UNCHANGED. BoneCatalyst routes damage through `DamageScript.compute_mob_damage(mob_def, _player_vigor())` exactly like Grunt/Charger — same formula path, no new mitigation surface.
- **MobRegistry existing entries** — `&"grunt"` / `&"charger"` / `&"shooter"` / `&"sunken_scholar"` all unchanged. `test_registered_ids_includes_grunt_charger_shooter` baseline passes.
- **Stratum scaling math** — `MobRegistry.apply_stratum_scaling` unchanged. `&"s1"` baseline 1.0/1.0; `&"s2"` 1.2/1.15. Bone-Catalyst is the third mob with a registry-pin test validating the math on its own def (70 HP × 1.2 = 84; 5 dmg × 1.15 → 6).
- **Universal warning gate** — both new GUT test files use `NoWarningGuard` per `test-conventions.md` § "Universal warning gate." No new `push_warning` call-sites introduced.
- **Hit-flash 3-branch resolver** — BoneCatalyst routes through the ColorRect branch on the placeholder sprite (M3W-3 convention pinned by `test_hit_flash_resolves_color_rect_branch_for_placeholder_sprite`). HIT_FLASH_TINT matches Grunt verbatim (cross-stratum constant) — pinned by `test_hit_flash_tint_matches_cross_stratum_constant`.

## Cross-lane integration check

- **`[combat-trace] Mob.pos` trace contract preserved.** Bone-Catalyst emits the same shape as Grunt/Charger/Shooter/SunkenScholar (throttled 0.25 s, `pos=(x,y) state=<S> hp=<N> dist_to_player=<D>`). Future AC4-style multi-chaser greps will pick it up without harness changes.
- **Player iframes UNTOUCHED.** No changes to `Player.gd` / `Player._enter_iframes` / `Player._exit_iframes` / `Player.coll_diag` discrimination triad. Bone-Catalyst is a damage source, not a damage target — it never touches the player's collision_layer.
- **RoomGate signal chain UNTOUCHED.** Bone-Catalyst's `mob_died` signal matches the existing payload shape `(mob, death_position, mob_def)` used by Grunt/Charger/Shooter/SunkenScholar — RoomGate decrements via `register_mob` will work without any chain edits. CONNECT_DEFERRED contract preserved per `combat-architecture.md` § "RoomGate uses CONNECT_DEFERRED".
- **Adjacent specs probed.** No Playwright spec change in this PR (Stage 3 ships no production surface that activates Bone-Catalyst — Stage 4 Part C is where chunks consume the mob). The existing `tests/playwright/specs/universal-console-warning-gate.spec.ts` will pick up any boot-time `USER WARNING:` from the new registry entry; expected to stay green.
- **MobLootSpawner / Inventory pipeline.** Bone-Catalyst `mob_def.loot_table` is `null` for Stage 3 — `MobLootSpawner.on_mob_died` short-circuits cleanly on null loot table (same path as PracticeDummy). Loot will populate alongside S2 chunk authoring in Stage 4 Part C.

## HTML5 escape clause invocation (per `escape-clause-active-surface-test` memory)

- **Surface eligibility:** placeholder ColorRect sprite (sub-1.0 channels), ColorRect-targeted channel-telegraph tween (sub-1.0 channels), CPUParticles2D death-burst (room-parented via `call_deferred("add_child", burst)` per `combat-architecture.md` § "Room-parented CPUParticles2D burst — reusable idiom" — empirically renderer-safe across the M3 mob roster: Grunt, Charger, Shooter, Stratum1Boss, SunkenScholar all use the same shape verbatim).
- **Active-surface test:** PASSES. No production room consumes `&"bone_catalyst"` in this PR (verified by `grep -rn '"bone_catalyst"' resources/level_chunks/` returns no matches outside the new files in this PR). The mob class is reachable only via `MobRegistry.spawn(&"bone_catalyst", ...)` which no production code invokes yet. Same routing as Stage 2 PR #364 (SunkenScholar) — which Tess approved on this exact escape-clause analysis.
- **Visual gate routes to:** Stage 4 (S2 chunks land + first room consumes the mob) Sponsor soak. The first time this Bone-Catalyst placeholder sprite reaches the screen will be on Stage 4 PR's chunk-consume surface — visual gate routes there, not here.

## CI verdict

CI status: pending push. Will update Self-Test Report comment with run-id URL after `git push -u origin drew/w3-t7-stage-3-bone-catalyst`.

GUT tests authored:
- 19 tests in `tests/test_bone_catalyst_mob_class.gd`
- 7 tests in `tests/test_mob_registry_bone_catalyst_pin.gd`
- Both files use `NoWarningGuard` per universal-warning-gate convention.

Playwright check: AUTO-FIRES on PR push per `playwright-e2e.yml` `pull_request` trigger (post-PR #299). Expected to be green-or-pre-existing-on-main-chronic per `main-playwright-chronic-baseline` memory; will classify in PR comment after the run lands.

## Doc updates

`team/drew-dev/level-chunks.md` § "Stage 3 — Bone-Catalyst (melee bruiser)" appended (extends the Stage-2 § "S2 mob roster" with the new differentiation table, channel-windup contract, distinct-from-Charger / distinct-from-Shooter-family pins, trace contract, placeholder ship state, and out-of-scope list).
