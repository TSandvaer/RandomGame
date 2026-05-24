# feat(level|content): BoneCatalyst (S2 melee bruiser) — W3-T7 Stage 3 of ticket 86c9y7ygj

Stage 3 of W3-T7 (multi-stage ticket `86c9y7ygj` Part B). Stage 1 shipped S2 ZoneDef shells (PR #360). Stage 2 shipped SunkenScholar — the S2 ranged caster (PR #364). This Stage 3 ships **Bone-Catalyst** — the second of two new S2 mob archetypes, the melee bruiser.

## What this PR ships

- **`scripts/mobs/BoneCatalyst.gd`** — new mob class. Mechanically cloned from Grunt (chase → telegraph → strike → recover) but with a STATIONARY channel-pose telegraph (`STATE_CHANNELING`, 0.60 s) instead of Grunt's 1-frame raised-blade tilt + Charger's rear-back + dash-line. The brass-mask channel-pose IS the silhouette tell per Uma `palette-stratum-2.md` §5.5 Bone-Catalyst.
- **`scenes/mobs/BoneCatalyst.tscn`** — CharacterBody2D + CircleShape2D (radius 13, slightly larger than Grunt 12 — bruiser silhouette) + placeholder ColorRect sprite in bone-corroded brown-rust `Color(0.30, 0.18, 0.16)` (Uma §5.5 heat-corroded short tunic). Sub-1.0 channels HTML5-safe per `html5-export.md` HDR-clamp rule.
- **`resources/mobs/bone_catalyst.tres`** — MobDef with `id = &"bone_catalyst"`, 70 HP, 5 dmg, 50 move_speed, `ai_behavior_tag = &"melee_bruiser"`, 22 XP.
- **`scripts/content/MobRegistry.gd`** — append `&"bone_catalyst"` registration to `_REGISTRATIONS`.
- **`tests/test_bone_catalyst_mob_class.gd`** — 19 GUT tests (mob-class smoke + state-machine path + channel direction re-resolves at strike time + killed-mid-channel-no-slam + S1-melee-differentiation pins vs Grunt + Charger + Uma §5.5 channel-duration window pin).
- **`tests/test_mob_registry_bone_catalyst_pin.gd`** — 7 GUT tests (registry round-trip + scene/def resolves + S2 stratum-scaling math 70×1.2=84 HP, 5×1.15→6 dmg).
- **`team/drew-dev/level-chunks.md`** — extend § "S2 mob roster" with the Stage-3 Bone-Catalyst differentiation table.

## Why Bone-Catalyst is mechanically distinct from S1 Grunt + S1 Charger

Per Uma `palette-stratum-2.md` §5.5 verbatim:

> "Hunched bruiser humanoid, weaponless-but-armored-forearms — a third readable melee shape. The brass mask + bone forearms are the silhouette tells distinguishing them from any S1 silhouette at 32 px."
>
> "The channel-wind-up double-forearm-cross IS the telegraph. S1 Grunt telegraphs via raised-blade-1-frame; S1 Charger telegraphs via rear-back + dash-line. Bone-Catalyst telegraphs via stationary channel pose — player learns 'when the brass mask centers in the silhouette and both arms cross, the slam is coming.'"

Differentiation table (Stage-3 specific levers):

| Lever | S1 Grunt | BoneCatalyst (S2) | Why differentiate |
|---|---|---|---|
| Telegraph state | `STATE_TELEGRAPHING_LIGHT` (raised-blade mid-motion) | `STATE_CHANNELING` (stationary forearms-cross) | Uma §5.5 — stationary pose vs mid-motion swing windup. Reads as "gathering pressure," not "swinging." |
| Telegraph duration | 0.40 s | 0.60 s | Uma §5.5: "0.5-0.7 s windup window." Mid-band — long enough to dodge, short enough to avoid reading as "stunned." |
| Strike-hitbox spec | reach=24 / radius=16 / lifetime=0.10 | reach=30 / radius=20 / lifetime=0.14 | Slam is the routine attack-shape (no heavy fallback) — between Grunt LIGHT and Grunt HEAVY. |
| Heavy-telegraph fallback | yes (`HEAVY_TELEGRAPH_HP_FRAC = 0.30`) | NO | Channel-windup IS the bruiser's primary read — adding a second low-HP telegraph dilutes the silhouette grammar. |
| `hp_base` | 50 | 70 | Compensation for longer windup — bruiser eats more hits before going down. |
| `damage_base` | 2 | 5 | Hits hard but tells you it's coming. |
| `move_speed` | 60 | 50 | Uma §5.5 "bruiser plodding gait" — heavy mass reads as slow approach. |

| Lever | S1 Charger | BoneCatalyst (S2) | Why differentiate |
|---|---|---|---|
| Telegraph + strike shape | rear-back + DASHES in a charge-line (`STATE_CHARGING` moves at 180 px/s) | stationary channel-pose then hammer-arc slam | Channel is STATIONARY — pinned by `test_no_charge_dash_unlike_charger`. |
| API surface | `get_charge_dir()` + `charge_telegraph_started` + `charge_hit_spawned` | NO charge API — uses `channel_started` + `swing_spawned(&"slam")` | Bruiser doesn't dash. |

## Differentiation pins (loud-fail drift detectors)

The Bone-Catalyst mob-class test ships **5 explicit differentiation pins** so a future tune that quietly crosses BoneCatalyst into Grunt/Charger semantics fails fast in headless CI:

1. `test_channel_duration_is_longer_than_grunt_light_telegraph` — `CHANNEL_DURATION > LIGHT_TELEGRAPH_DURATION` (0.60 > 0.40 today).
2. `test_channel_duration_is_in_uma_spec_window` — `0.5 <= CHANNEL_DURATION <= 0.7` per Uma §5.5.
3. `test_no_projectile_state_unlike_shooter_family` — no `aim_started` signal, no `projectile_fired` signal, no `STATE_AIMING`/`STATE_FIRING`/`STATE_POST_FIRE_RECOVERY` reachable.
4. `test_no_charge_dash_unlike_charger` — no `charge_telegraph_started` signal, no `charge_hit_spawned` signal, no `get_charge_dir` method, velocity stays ZERO through CHANNEL_DURATION.
5. `test_move_speed_is_slower_than_grunt` + `test_hp_is_higher_than_grunt` — bruiser-specific balance levers.

## Trace contract (Drew persona rule "No new mob class without trace instrumentation")

- `[combat-trace] BoneCatalyst.pos | pos=(x,y) state=<S> hp=<N> dist_to_player=<D>` — throttled 0.25 s, mirrors Grunt.pos / Charger.pos / Shooter.pos / SunkenScholar.pos.
- `[combat-trace] BoneCatalyst._set_state | <old> -> <new> dist=<D> pos=(x,y)` — emits on every state transition.
- `[combat-trace] BoneCatalyst.{take_damage, _die, _force_queue_free, _play_attack_telegraph, _begin_channel}` — uniform with the Grunt family. Harness greps map 1:1.

## Stage-3 ship state (placeholder sprite)

Placeholder Sprite is a flat-color ColorRect (bone-corroded brown-rust, 18×16 px — wider than tall per Uma §5.5 "stocky proportions"). Hit-flash 3-branch resolver routes through the ColorRect branch (M3W-3 convention) — pinned by `test_hit_flash_resolves_color_rect_branch_for_placeholder_sprite`.

PixelLab sprite generation is **deferred to a follow-up PR** per ticket scope:
- Sponsor + orchestrator main-session executes via `mcp__pixellab__*` per `sub-agent-mcp-tool-surface-scope` memory.
- Bone-Catalyst's PixelLab prompt seed is `palette-stratum-2.md` §5.5 verbatim.
- Drop-in mechanic per M3W-1 PR #271 inheritance contract: replace the `Sprite` ColorRect node in `scenes/mobs/BoneCatalyst.tscn` with `AnimatedSprite2D` of the same name + assign `SpriteFrames`. Hit-flash 3-branch resolver branch-1 auto-picks it up — no script edit needed.

## Out of scope (deferred to later stages of `86c9y7ygj`)

- Archive Sentinel boss (Stage 5) — distinct boss-room topology + stationary-on-plinth shape per Uma §5.5 boss arena.
- S2 chunks consuming `&"bone_catalyst"` in `mob_spawns` (Stage 4 Part C).
- Stratum-scaling wired into spawn path (`apply_stratum_scaling` API pinned via the registry test, no spawn-path wire-up yet — cross-cutting follow-up).
- BoneCatalyst-specific bone-fragment death-burst frames — placeholder uses unified cross-stratum ember ramp.

## HTML5 visual-verification gate — escape clause invocation

This PR is **data + scaffolding** (mob class + scene + .tres + registry append + tests). The placeholder ColorRect sprite is a sub-1.0-channel rectangle and the placeholder-tinted channel-telegraph tween is also sub-1.0 — both renderer-safe surfaces per `html5-export.md`. **No production play surface invokes BoneCatalyst yet** (Stage 4 Part C wires it into S2 chunks). Per `html5-export.md` § "Visual-verification escape clause — active-surface test" and memory `escape-clause-active-surface-test`:

- **Eligible for escape clause:** ColorRect placeholder, ColorRect-targeted tween (sub-1.0 channels), CPUParticles2D death-burst uses the SAME shape as Grunt/Shooter/SunkenScholar (room-parented via `call_deferred("add_child", burst)` per `combat-architecture.md` § "Room-parented CPUParticles2D burst — reusable idiom") — empirically renderer-safe across the M3 mob roster.
- **Active-surface test:** PASSES — no production room consumes `&"bone_catalyst"` in this PR. Same routing as Stage 2 (PR #364 SunkenScholar).
- **Visual gate routes to:** Stage 4 (S2 chunks land + first room consumes the mob) Sponsor soak — that's where the actual visual surface activates.

## Cross-references

- `team/uma-ux/palette-stratum-2.md` §5.5 Bone-Catalyst (visual direction)
- `scripts/mobs/Grunt.gd` (canonical melee pattern source)
- `scripts/mobs/SunkenScholar.gd` (Stage 2 — sibling S2 mob class)
- `.claude/docs/combat-architecture.md` § "Adding a new mob class" + § "M3W-1 realized implementation"
- `.claude/docs/test-conventions.md` § "Universal warning gate"
- ClickUp `86c9y7ygj` — multi-stage ticket (stays `in progress`; Stage 3 complete comment on merge per `multi-stage-ticket-lifecycle` memory)

## Self-Test Report

Posted as PR comment after open per the testing-bar Self-Test Report gate.

Doc updates: `team/drew-dev/level-chunks.md` § "Stage 3 — Bone-Catalyst (melee bruiser)" appended.
