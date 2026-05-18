# Grunt v2 — PixelLab folder → semantic name reverse-map

The folders under `Grunt_v2_S1_Embergrave_red-eyes/animations/` have been renamed
from PixelLab's UUID-laden native names to semantic state names so that
`SpriteFrames.tres` paths read clearly
(`walk/south/frame_000.png` vs
`walking_menacingly-9f6281f2/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery.

## Reverse-map

Original PixelLab character_id: `e92d6924-44b3-4968-a3fd-ee5aecfe5ea5`
Generated: 2026-05-17

| Semantic name | PixelLab native folder | PixelLab template_animation_id | frames/dir |
|---|---|---|---|
| `walk/` | `walking_menacingly-9f6281f2/` | `walking_menacingly` (mannequin template) | 8 |
| `atk/` | `cross_punch_attack-5b669f52/` | `cross_punch_attack` (mannequin template) | 6 |
| `hit/` | `taking_a_punch-88d385af/` | `taking_a_punch` (mannequin template) | 6 |
| `die/` | `falling_backward-27df2dbf/` | `falling_backward` (mannequin template) | 7 |
| `atk_telegraph/` | `animating-62b12920/` | `animating` (custom — Grunt heavy-telegraph windup pose) | 8 |

Grunt v2 carries the M3 heavy-telegraph state from `Grunt.gd`'s
`STATE_TELEGRAPHING_HEAVY` — `atk_telegraph/` (PixelLab `animating-*`) is the
low-HP windup pose, distinct from the per-swing red-glow telegraph that
`_play_attack_telegraph` already drives on the `STATE_TELEGRAPHING_LIGHT` window.

## Convention established by M3W-1 (PR #271)

Every M3 character ships with:

1. PixelLab UUID-suffixed folders renamed to semantic state names (`walk/`,
   `atk/`, `hit/`, `die/`, `atk_telegraph/`) at PR time.
2. `metadata.json` committed unmodified — preserves the UUID-history + template
   provenance for re-roll / debug.
3. `anim-folder-map.md` (this file) committed alongside — grep-discoverable
   reverse-map.

**Frame layout per anim:** 8 direction subfolders × N frames each (PixelLab
template-animation count varies). Grunt's frame counts: `walk` 8, `atk` 6,
`hit` 6, `die` 7, `atk_telegraph` 8 (totals: 64 + 48 + 48 + 56 + 64 = 280 frames).

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

Grunt SpriteFrames key set: `walk_<dir>`, `atk_<dir>`, `hit_<dir>`, `die_<dir>`,
`atk_telegraph_<dir>` across all 8 dirs = 40 anims. FPS=8 across all;
`walk_*` loop=true (sustained gait), rest loop=false (one-shot beats).
