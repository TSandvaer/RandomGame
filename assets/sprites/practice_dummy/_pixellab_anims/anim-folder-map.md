# PracticeDummy — PixelLab folder → semantic name reverse-map

The folders under `PracticeDummy/animations/` have been renamed from PixelLab's
UUID-laden native names to semantic state names so that `SpriteFrames.tres`
paths read clearly (`hit/south/frame_000.png` vs `taking_a_punch-1f45c4b5/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery.

## Reverse-map

| Semantic name | PixelLab native folder | PixelLab template_animation_id |
|---|---|---|
| `hit/` | `taking_a_punch-1f45c4b5/` | `taking_a_punch` (mannequin template) |
| `die/` | `falling_backward-26fe5a45/` | `falling_backward` (mannequin template) |

## Convention established by M3W-1

Every M3 character ships with:

1. PixelLab UUID-suffixed folders renamed to semantic state names (`hit/`, `die/`,
   `walk/`, `atk_light/`, etc.) at PR time.
2. `metadata.json` committed unmodified — preserves the UUID-history + template
   provenance for re-roll / debug.
3. `anim-folder-map.md` (this file) committed alongside — grep-discoverable
   reverse-map.

**Frame layout per anim:** 8 direction subfolders × N frames each (PixelLab
template-animation count). PracticeDummy's `hit` has 6 frames/direction (48
total); `die` has 7 frames/direction (56 total).

**Animation key convention in `.tres`:** `<state>_<dir>` where dir ∈
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
