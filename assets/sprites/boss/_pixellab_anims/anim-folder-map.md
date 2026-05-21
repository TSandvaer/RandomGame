# Stratum1Boss — PixelLab folder → semantic name reverse-map

The folders under `Stratum1Boss/animations/` have been renamed
from PixelLab's UUID-laden native names to semantic state names so that
`SpriteFrames.tres` paths read clearly
(`atk/south/frame_000.png` vs
`animating-7691a7fc/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery.

## Canonical variant — `Stratum1Boss/` (formerly `add_bright_glowing_r/`)

Per `team/priya-pl/m3-scene-wiring-scope.md §M3W-4`, the boss
`_pixellab_anims/` directory shipped TWO variants at PR #263 sign-off:

- `Stratum1Boss_S1_Warden/` — initial generation (rotations only, no animations).
- `Stratum1Boss/` — `create_character_state` variant adding glowing red eyes,
  with the full 7-animation set (was `add_bright_glowing_r/` in PR #263).

The eye-variant (`Stratum1Boss/`) was Sponsor-accepted at PR #263 soak and is
the canonical M3W-4 source. The Warden folder is retained for PixelLab traceability
(metadata.json carries both states) but is NOT referenced by `Stratum1Boss.tres`.

## Reverse-map

Original PixelLab character_id: `80a555b9-a2cc-4b81-b66b-f9de61415e4c` (eye-variant)
Group id: `7ec6fc5b-f83f-49f4-8225-ca1151b697c4`
Generated: 2026-05-17 (PR #263 batch)

| Semantic name | PixelLab native folder | PixelLab template_animation_id | frames/dir |
|---|---|---|---|
| `walk/` | `animating-08e307cd/` | `animating` (custom — wide-stance idle / movement) | 6 |
| `atk/` | `animating-7691a7fc/` | `animating` (custom — heavy melee swing) | 8 |
| `atk_telegraph/` | `animating-227a1442/` | `animating` (custom — windup pose) | 8 |
| `slam/` | (multi-UUID, see below) | `surprise-uppercut` (mannequin template — upward strike) | 7 |
| `slam_telegraph/` | `uppercut-1a9f12cd/` | `uppercut` (mannequin template — upward windup) | 7 |
| `hit/` | `taking_a_punch-749388de/` | `taking_a_punch` (mannequin template — hit reaction) | 6 |
| `die/` | `falling_backward-c0134300/` | `falling_backward` (mannequin template — death fall) | 7 |

Frame counts per anim (across all 8 directions): 6+8+8+7+7+6+7 = 49 frames/dir
× 8 dirs = **392 frames total** in `Stratum1Boss.tres`.

### `slam/` source — `surprise-uppercut` per-direction UUIDs (2026-05-21 B3 swap)

The original `slam/` shipped at PR #263 was sourced from PixelLab template
`roundhouse_kick` (folder `roundhouse_kick-4d533f1e/`). Sponsor's 2026-05-21
soak iteration on PR #291 surfaced the visual as a kick rather than the
intended weapon-uppercut slam (B3 finding). Replaced 2026-05-21 with
`surprise-uppercut` template frames pre-existing from the 2026-05-17
generation batch — zero new gens consumed.

Per-direction PixelLab animation UUIDs (sourced from `get_character` output
saved to orchestrator tool-result file 2026-05-21):

| Direction | `surprise-uppercut` UUID |
|---|---|
| `north-east` | `89b6c052-3be4-4082-86ac-eaf817674de7` |
| `north` | `c08a4f34-90dd-4d8c-a5a6-0a8a14123de5` |
| `south-west` | `9ca8f456-f078-4820-b62d-345ee510de59` |
| `south-east` | `e74c6755-2989-4798-a0b6-a16ec02d2cbe` |
| `south` | `e524e0f9-633c-4360-adaf-84e26e9a243b` |
| `north-west` | `10d5df34-26a8-4a3f-8de6-18c8a154253f` |
| `east` | `fc3041d4-9ee5-463b-a5d9-0205434bde52` |
| `west` | `b35b22dd-71ee-40be-9100-d6dba5a46aa8` |

Each UUID maps to 7 frames (`0.png`–`6.png` from PixelLab CDN, renamed to
`frame_000.png`–`frame_006.png` on import to match the existing M3W-4
SpriteFrames path contract). Frame canvas: 80×80 RGBA, same as all other
boss animations. Palette: at parity with the existing un-doctrine-locked
boss frames — same iron/grey/red family, no doctrine remap required (see
2026-05-21 palette spot-check via Pillow inspection — old slam frame_003
and new slam frame_003 share the iron ramp `#EBEEF7`/`#D7D6E6`/`#C5C4D4`
/.../`#585767`).

## State-machine mapping (per `scripts/mobs/Stratum1Boss.gd`)

The boss has a 9-state machine; 7 of those states drive animation playback,
2 are no-anim (DORMANT, PHASE_TRANSITION — boss frozen):

| State | Anim key | Notes |
|---|---|---|
| `STATE_DORMANT` | `walk` (frame 0, stop()) | Pre-wake hold pose |
| `STATE_IDLE` | `walk` | Sustained loop — boss is awake but no target |
| `STATE_CHASING` | `walk` | Sustained loop — pursuing player |
| `STATE_TELEGRAPHING_MELEE` | `atk_telegraph` | One-shot windup (0.55 s) |
| `STATE_ATTACKING` | `atk` | One-shot melee swing |
| `STATE_TELEGRAPHING_SLAM` | `slam_telegraph` | One-shot slam windup (0.50 s) — phase 2/3 only |
| `STATE_SLAM_RECOVERY` | `slam` | One-shot AoE strike — phase 2/3 only |
| `STATE_PHASE_TRANSITION` | (none — anim freezes) | 0.6 s damage-immune window between phases |
| `STATE_DEAD` | `die` | One-shot fall — drives `_die()` |

Plus `hit` plays on `take_damage()` directly (interrupts the state anim, same
shape as Grunt's hit anim per M3W-3 convention).

**Phase note:** the boss has 3 phases (1/2/3) but anim choice is state-driven,
NOT phase-driven. Phase 1 only uses melee + telegraph + hit + die + walk; phases
2/3 add the slam pair. Enrage phase 3 shortens recoveries via `ENRAGE_RECOVERY_MULT`
— same anims, just faster timer windows. No per-phase anim split required.

## Convention established by M3W-1 (PR #271) + extended by M3W-3 (#275)

Every M3 character ships with:

1. PixelLab UUID-suffixed folders renamed to semantic state names at PR time.
2. `metadata.json` committed unmodified — preserves UUID-history + template
   provenance for re-roll / debug.
3. `anim-folder-map.md` (this file) committed alongside — grep-discoverable
   reverse-map.

**Frame layout per anim:** 8 direction subfolders × N frames each.

## Animation key convention in `.tres`

Per M3W-1: `<state>_<dir>` where dir ∈
{`n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw`}. Mapping from PixelLab folder names:

| PixelLab folder | `.tres` dir suffix |
|---|---|
| `south/` | `s` |
| `south-east/` | `se` |
| `east/` | `e` |
| `north-east/` | `ne` |
| `north/` | `n` |
| `north-west/` | `nw` |
| `west/` | `w` |
| `south-west/` | `sw` |

Stratum1Boss SpriteFrames key set: `walk_<dir>`, `atk_<dir>`, `atk_telegraph_<dir>`,
`slam_<dir>`, `slam_telegraph_<dir>`, `hit_<dir>`, `die_<dir>` across all 8 dirs
= **56 anims**. FPS=8 across all; `walk_*` loop=true (sustained), rest loop=false
(one-shot beats).
