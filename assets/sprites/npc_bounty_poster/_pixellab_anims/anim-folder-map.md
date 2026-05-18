# NPC_BountyPoster — PixelLab folder → semantic name reverse-map

The folders under `NPC_BountyPoster/animations/` have been renamed from
PixelLab's UUID-laden native names to semantic state names so that
`SpriteFrames.tres` paths read clearly (`idle/south/frame_000.png` vs
`animating-2f589481/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery.

## Reverse-map

Original PixelLab character_id: `70806893-cd64-4e7d-b8ae-d01954e2cced`
Generated: 2026-05-17

| Semantic name | PixelLab native folder | PixelLab template_animation_id | animation_name | direction |
|---|---|---|---|---|
| `idle/` | `animating-2f589481/` | `breathing-idle` (mannequin template) | `idle` | 8 dirs |

Outer folder rename: `NPC_Bounty-poster_simplified_doctrine-hex_test/` →
`NPC_BountyPoster/`.

## Frame layout

- 1 animation (`idle`) × 8 direction subfolders × 4 frames each = 32 PNGs.
- Direction subfolders: `south/`, `south-east/`, `east/`, `north-east/`,
  `north/`, `north-west/`, `west/`, `south-west/` (matches PracticeDummy
  convention).
- Frames are zero-padded `frame_000.png` … `frame_003.png`.

## Animation key convention in `.tres`

Per M3W-1 (PR #271): `<state>_<dir>` where dir ∈
{`n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw`}. Mapping from PixelLab folder
names:

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

NPC SpriteFrames key set: `idle_n`, `idle_ne`, `idle_e`, `idle_se`, `idle_s`,
`idle_sw`, `idle_w`, `idle_nw` (8 anims total, all `loop = true`, FPS = 8).
