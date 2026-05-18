# NPC_AnvilKeeper — PixelLab folder → semantic name reverse-map

The folders under `NPC_AnvilKeeper/animations/` have been renamed from PixelLab's
UUID-laden native names to semantic state names so that `SpriteFrames.tres`
paths read clearly (`idle/south/frame_000.png` vs
`animating-a86e35c1/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery.

## Reverse-map

Original PixelLab character_id: `2a2da74d-c6c0-4a60-a0e3-ae6b50fa74ff`
Generated: 2026-05-17

| Semantic name | PixelLab native folder | PixelLab template_animation_id | animation_name | direction |
|---|---|---|---|---|
| `idle/` | `animating-a86e35c1/` | `breathing-idle` (mannequin template) | `idle` | 8 dirs |

Outer folder rename: `NPC_Anvil-keeper_re-queue/` → `NPC_AnvilKeeper/`.

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
