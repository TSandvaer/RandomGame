## Summary

Wires animation-beat audio cues to existing combat signals on Player + S1 mob roster + Stratum1Boss per ClickUp [`86c9va3d0`](https://app.clickup.com/t/86c9va3d0). Ships 9 algorithmic placeholder SFX cues (per `audio-direction.md §6` disclosure pattern, with explicit M4 promotion path).

This is the **final M3 Tier 1 follow-up** after M3W-1/2/3/4/5/6 landed the AnimatedSprite2D wiring. Combat now has audio identity.

## Approach — signals, not `frame_changed`

The dispatch brief described `AnimatedSprite2D.frame_changed`-routed cues. After reading the existing combat code I went with the cleaner alternative: **route cues from the existing gameplay signals** (`attack_spawned`, `mob_died`, `damaged`, `swing_spawned`, `light/heavy_telegraph_started`, `charge_telegraph_started`, `charge_hit_spawned`, `aim_started`, `projectile_fired`, `iframes_started`, `boss_died`).

Why:

- These signals already fire at the exact gameplay beats animation frames are paced for.
- Signal routing decouples audio from per-character anim-frame index tuning (no hardcoded "frame 3 of 6").
- Survives future SpriteFrames re-authoring without per-character audio wire updates.
- Aligns with the "one source of truth — Hitbox/Projectile/Player signal contracts" pattern in `.claude/docs/combat-architecture.md`.

## Routes

| Source | Signal | Cue |
|---|---|---|
| Player | `attack_spawned(ATTACK_LIGHT)` | `sfx-player-attack-light` |
| Player | `attack_spawned(ATTACK_HEAVY)` | `sfx-player-attack-heavy` |
| Player | `damaged(>0)` | `sfx-player-hit` |
| Player | `damaged(0)` | **silent** (i-frame absorb pin) |
| Player | `iframes_started` | `sfx-player-dodge` |
| Grunt + Stoker | `damaged(>0)` | `sfx-mob-hit` |
| Grunt + Stoker | `mob_died` | `sfx-mob-die` |
| Grunt + Stoker | `light_telegraph_started` / `heavy_telegraph_started` | `sfx-attack-telegraph` |
| Grunt + Stoker | `swing_spawned` | `sfx-attack-impact` |
| Charger | `damaged(>0)` | `sfx-mob-hit` |
| Charger | `mob_died` | `sfx-mob-die` |
| Charger | `charge_telegraph_started` | `sfx-attack-telegraph` |
| Charger | `charge_hit_spawned` | `sfx-attack-impact` |
| Shooter | `damaged(>0)` | `sfx-mob-hit` |
| Shooter | `mob_died` | `sfx-mob-die` |
| Shooter | `aim_started` | `sfx-attack-telegraph` |
| Shooter | `projectile_fired` | `sfx-attack-impact` |
| Stratum1Boss | `damaged(>0)` | `sfx-mob-hit` |
| Stratum1Boss | `boss_died` | `sfx-boss-die` (heavier than mob-die) |
| Stratum1Boss | `swing_spawned(SWING_KIND_SLAM_TELEGRAPH)` | `sfx-attack-telegraph` |
| Stratum1Boss | `swing_spawned(SWING_KIND_MELEE` or `SWING_KIND_SLAM_HIT)` | `sfx-attack-impact` |

**Stoker** inherits from Grunt — wiring is automatic, no Stoker-side code added.

**PracticeDummy** intentionally NOT wired — tutorial entity, no combat-feel value from audio.

**NPCs (Vendor, Anvil-keeper, Bounty-poster)** intentionally NOT wired in this PR — the brief's "low-frequency ambient cue per idle frame" pattern needs duty-cycle control and per-character authoring. Deferred to a follow-up M4 audio polish ticket.

## AudioDirector additions

- `SFX_PATHS` cue_id → resource path dictionary (9 entries — adding M4 cues is a single-line map edit).
- `play_sfx(cue_id)` public API.
- Round-robin `AudioStreamPlayer` pool (size 8) so concurrent cues don't truncate each other.
- Lazy stream cache (`_sfx_streams`) — first `play_sfx` pays decode, subsequent reuse.
- Test surface: `get_last_sfx_id()`, `get_sfx_pool_size()`, `reset_sfx_pool_index_for_test()`.
- Boot trace updated to include `sfx_pool=N`.
- WarningBus-routed warning if an SFX path fails to load (catches a moved/missing asset at soak time without bypassing the universal warning gate).

## SFX assets — algorithmic placeholders (M4 promotion required)

9 OGG-Vorbis mono cues at `audio/sfx/{player,mobs}/`, peak-normalized to -3 dBFS, total ~50 KB. Generated deterministically (seeded numpy RNGs) by `audio/_src/composer/compose_sfx_m3w7.py` — the composer follows Uma's S2-placeholder pattern (`compose_stratum2.py`) with the same disclosure shape and reproducibility ritual.

**Disclosure (per `audio-direction.md §6`):** these are filtered-noise + low-body-sine + bell-partial syntheses. They satisfy the M3W-7 ship-acceptable bar per `audio-sourcing-pipeline.md §Route 5` ("placeholder loop explicit-acceptable when authoring latency exceeds dispatch window"). M4 promotes to freesound + hand-Foley sourced finals. The composer script is committed alongside so future audits can regenerate the placeholders before promotion.

## Paired tests — `tests/test_m3w7_audio_cues.gd` (25 tests)

- AudioDirector public API + SFX pool boot-ok
- `SFX_PATHS` covers every wired cue id (regression guard for cue typos / renames)
- Every SFX asset `load()`s as AudioStream (HTML5 resource-cache safety, mirrors STARTER_ITEM_PATHS rule)
- Per-character signal to cue-id routing (16 tests across Player/Grunt/Charger/Shooter/Boss)
- `Player.damaged(0)` silent (i-frame absorb contract)
- `Boss.boss_died` plays `sfx-boss-die` not `sfx-mob-die` (cue-collapse guard)
- `Boss.swing_spawned` branches `slam_telegraph` → telegraph, else → impact
- `_wire_audio_cues` is idempotent across triple-wire (no double-connect)
- WarningBus / NoWarningGuard clean across every test (universal warning gate)

## Regression guards (per PR #216 contract)

1. `test_sfx_paths_covers_every_required_cue` — typo / cue-rename catcher
2. `test_every_sfx_asset_loads_as_audio_stream` — missing-file catcher
3. `test_grunt_re_ready_does_not_double_connect` — handler-duplication catcher
4. `test_player_damaged_zero_is_silent` — i-frame absorb regression catcher
5. `test_boss_died_plays_boss_die_not_mob_die` — cue-collapse catcher

## Cross-lane integration check

| Lane | Surface | Touched? | Impact |
|---|---|---|---|
| Inventory | `Inventory.equip` / pickup / save-restore | No | Audio purely additive |
| Pickup | `Area2D.body_entered` / Pickup.gd | No | No physics-flush risk |
| RoomGate | `gate_traversed` / mob-clear | No | No room-load chain change |
| Loot | `MobLootSpawner.on_mob_died` | No | New `mob_died` audio listener is independent |
| Combat physics | Hitbox / Projectile | No | Read-only signal subscriber |
| HTML5 visual gate | tween / modulate / Polygon2D / Area2D state | No | No visual primitives changed |
| Save-load | `Save.save_completed` / `restore_from_save` | No | Audio listeners don't persist |

The audio layer is a strictly additive read-only subscriber on existing signals. No physics-flush risk (no Area2D adds, no monitoring mutations, no body-shape mutations from signal handlers).

## HTML5 audio-playback gate

Every cue site is a gameplay signal that fires AFTER user input (combat input = keyboard / mouse press = user gesture). AudioContext unlocks on first emission; subsequent cues inherit the unlocked context. No `_ready`-time emit path. Verified in code review of each `_wire_audio_cues` call site.

## Self-Test Report

See follow-up PR comment for the HTML5 release-build verification per `.claude/docs/audio-architecture.md` "Verification gate".

## Doc updates

None in this PR — `audio-architecture.md` already documents the SFX bus + HTML5 audio-playback gate. The cue_id convention this PR establishes is self-documented in `AudioDirector.SFX_PATHS` and mirrors the BGM stream-path constants pattern. If M4 promotion surfaces a non-obvious finding (e.g. WebAudio decode latency divergence between placeholder OGG and freesound OGG), the `maintain-docs` Stop hook picks it up then.

## Test plan

- [ ] CI green (GUT + parse-failure scan)
- [ ] HTML5 release-build artifact downloads + extracts clean
- [ ] BuildInfo SHA matches `feat/m3w7-audio-cues` HEAD
- [ ] Console clean (no `USER WARNING:` / `USER ERROR:` / AudioContext warnings)
- [ ] Audible verification: walk to Room 02, hit grunt → mob-hit cue plays; kill grunt → mob-die plays; player swings → attack-light cue plays; player dodges → dodge whoosh plays
- [ ] Boss-fight: boss melee → impact cue; boss slam-telegraph → telegraph cue; boss death → boss-die (distinct from mob-die)
- [ ] Cross-lane sanity: pickup still auto-equips iron_sword, room-clear still gates correctly, save round-trip still works (none of these touched)

ClickUp [`86c9va3d0`](https://app.clickup.com/t/86c9va3d0).
