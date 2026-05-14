# M1 RC — Release Notes

**Released:** 2026-05-09 (final commit + artifact pending PR #155 merge)
**Status:** Path A scope-cut ship — known issues documented + deferred to M2 Week 1
**Soak coverage:** 5 attempts by Sponsor (manual) + Playwright harness skeleton AC1 + HP-regen smoke + Room-1-clear-and-walk

## What's in M1 RC

### Combat loop
- Player swing: light (LMB) + heavy (RMB) attacks with swing-wedge ColorRect + amber attack-flash visual
- Mob hit-flash on Sprite ColorRect (PR #140 — fixed white-on-white cascade no-op from PR #115/#122)
- Mob death pipeline: state → `mob_died.emit` → `_spawn_death_particles` → `_play_death_tween` → `_force_queue_free` (with parallel `SceneTreeTimer` safety net per PR #136)
- Hitbox / Projectile encapsulated-monitoring pattern (PR #143) — no physics-flush panics from sustained spawn-spam
- Sprite-color hit-flash respects per-mob rest colors (Grunt red-brown / Charger orange / Shooter blue / Boss deep-red)
- Mob attack telegraph (PR #153 Item 2): 0.4s warm-red flash on mob Sprite before swing lands. All 4 mob types.

### Onboarding / progression
- Iron sword auto-equipped on game-start (PR #145 / #146 bandaid; Stage 2b proper tutorial scaffold deferred to M2)
- Out-of-combat HP regen (PR #147 / #148): activates after 3.0s without taking damage AND 3.0s without landing a hit; rate 2.0 HP/s; warm-amber shimmer cue on HP bar; caps at HP_MAX
- Room transition requires player to walk through the door (Position B, PR #155)
- HP bar + XP bar + Level + Stat-allocation panel + Boot banner (BB-1 SHA stamp + BB-5 LMB/RMB lines)
- Save autoload — auto-saves on triggers, F5 / close-tab + reopen restores state

### Levels
- Stratum 1: 8 rooms (Room01 → Room07 → Stratum1BossRoom)
- Wall geometry (PR #129 — BB-3 / room boundary fix)
- Boss arena geometry (PR #129 LevelAssembler regression-fix — chunk_def.scene_path properly loaded)
- Door-trigger Area2D harmonization (PR #151 — CharacterBody2D guard, area_entered no-op, monitorable=false uniformly)

### Balance (PR #153 Item 3)
- Grunt damage_base: 5 → 3
- Charger damage_base: 8 → 5
- Shooter damage_base: 6 → 5
- Stratum1Boss damage_base: 15 → 12
- Damage formula constants UNCHANGED (locked per `team/DECISIONS.md` 2026-05-02): FIST_DAMAGE=1, EDGE_PER_POINT, HEAVY_MULT, VIGOR_PER_POINT, VIGOR_CAP

### Test infrastructure
- 700+ GUT tests covering combat / inventory / mobs / level / progression
- Playwright harness skeleton at `tests/playwright/`:
  - AC1 (boot + SHA + zero errors + zero 404s)
  - HP-regen smoke (3.0s out-of-combat → ~2 HP/s rise)
  - Room-traversal smoke (Room 1 clear-and-walk → Room 2)
  - Two consecutive green runs against M1 RC artifact
- HTML5 export build pipeline with single-unzip artifact format (PR #152)

## Known issues — deferred to M2 Week 1

These are documented gaps at M1 RC ship time. M2 Week 1 priority is to expand the harness coverage to Rooms 3-8 + Boss Room + equip flow so these regressions can't recur.

### P0 (gameplay-affecting, deferred per Path A)
1. **Stratum1Boss does NOT take damage** — ticket `86c9q96fv`. AC4 boss-clear unverifiable.
2. **Stratum1Boss does NOT attack** — ticket `86c9q96ht`. Boss reaches Room 8 but doesn't engage.
3. **Equip flow broken: equipping makes equipped slot disappear, can't re-equip** — ticket `86c9q96m8`. Player can't change loadout safely; iron sword bandaid persists if untouched.

### P1 (annoying, not run-ending)
4. **Mobs stick to player on movement (general case)** — ticket `86c9q96kk`. Devon's PR #150 push-back was contact-attack-tick specific; general body-overlap-while-moving still glues mobs to player.
5. **Stratum1Boss sticks to player from BOTTOM edge only** — ticket `86c9q96jv`. Asymmetric collision (push-from-N/E/W works; bottom-touch sticks).

### P2/P3 (UX polish, deferred to M2)
6. **Stats panel reads "Damage --" with iron_sword equipped** — ticket `86c9q5qyd`. Cosmetic; combat math correct, only the UI display gap.
7. **No explicit save-confirmation toast/indicator** — ticket `86c9q7p38`. Auto-save fires but no visible cue.
8. **Equipped vs in-grid items have no visual distinction in inventory** — ticket `86c9q7p48`. Sponsor request from soak attempt 2.
9. **Room01 missing tutorial scaffold (CU 028)** — `team/log/clickup-pending.md` ENTRY 028. Drew Stage 2b proper-fix; iron-sword bandaid is the M1 RC standby.
10. **Grunt recovery-velocity audit** — ticket `86c9q804q`. Inconsistent with Charger/Boss rooted-recovery contract from PR #150.

## Soak history

| Attempt | Build | Outcome |
|---|---|---|
| 1 (initial) | bbe7ae5 | P0 found: fistless start blocks combat → led to PRs #145 (iron sword bandaid) + #146 (boot-order fix) |
| 2 | 3937831 | P0 found: PR #145 broken at integration surface → led to PR #146 |
| 3 | deb0d21 | P0 found: 3 bugs (Bug 1 auto-advance, Bug 2 mob-stick, Bug 3 Shooter corner-camp) → led to PRs #150 + #151 |
| 4 | f45f991 | 3 new items: Position B confirmation, mob telegraph request, mob damage too high → led to PR #153 |
| 5 | 356086a | This soak surfaced 2 P0 regressions (PR #155 in flight) + 5 new bugs (deferred to M2 per Path A) |

## M2 Week 1 priorities

1. **Playwright harness expansion** — Rooms 3-8 + Boss Room coverage + equip-flow test + AC2/AC3/AC5/AC6 specs (per `team/tess-qa/playwright-harness-design.md` § 6 follow-ups). This is the meta-fix; it catches the regression class systematically.
2. **Boss damage path fix** (P0 from this soak)
3. **Boss attack AI fix** (P0)
4. **Equip flow fix** (P0)
5. **Mob-stick general-case fix** (P1)
6. **Boss-stick from bottom fix** (P1)
7. **Drew Stage 2b** — Room01 tutorial scaffold (CU 028)
8. **UX polish wave** — Stats panel "Damage --", save-toast, equipped distinction (3 tickets)
9. **Grunt recovery-velocity audit** (P3)

## Shipping artifact

**Tag:** `m1-rc-1` at commit `53a3412` (annotated, signed off 2026-05-09)
**GitHub Release page (PERMANENT):** https://github.com/TSandvaer/RandomGame/releases/tag/m1-rc-1
**Release asset:** `embergrave-html5-53a3412-m1-rc-1.zip`
**Build:** `embergrave-html5-53a3412` from run `25602268570` (post-PR-#155 merge)
**Direct download (Actions, expires 90 days):** https://github.com/TSandvaer/RandomGame/actions/runs/25602268570/artifacts/6895955326
**Tag-driven workflow run:** https://github.com/TSandvaer/RandomGame/actions/runs/25602572694
**Single-unzip format** (PR #152 active)

## Tag

(Open question for Sponsor: tag M1 RC milestone? `m1-rc-1`? `m1-rc-final`? Per the original session save's open question, the team hasn't tagged before. Decision pending.)
