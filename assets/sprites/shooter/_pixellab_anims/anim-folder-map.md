# Shooter — PixelLab folder → semantic name reverse-map

The folders under `add_two_bright_glowi/animations/` have been renamed from
PixelLab's UUID-laden native names to semantic state names so that
`SpriteFrames.tres` paths read clearly (`walk/south/frame_000.png` vs
`walking_sadly-23954552/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery.

## Parent-folder choice — `add_two_bright_glowi/` (not `Shooter_S1_skeletal-archer/`)

The Shooter character's `_pixellab_anims/` root contains TWO subfolders:

1. `Shooter_S1_skeletal-archer/` — the original `create_character` root
   (template=`mannequin`, prompt establishes the bone-white archer base). Has
   `rotations/` populated but **NO `animations/` subfolder** — animations were
   never generated against this state.
2. `add_two_bright_glowi/` — a `create_character_state` variant adding the
   "two bright glowing red eyes" detail (per Sponsor's PR #263 art-pass sign-off
   on the eye-glow variant). Has `rotations/` AND the full 5-animation set.

This PR uses `add_two_bright_glowi/` because it is the canonical state that
ships the animations Sponsor approved at PR #263. The
`Shooter_S1_skeletal-archer/` folder is preserved untouched as the
provenance-of-record root state (`metadata.json` references both); the bare
`rotations/` PNGs there are unused by the SpriteFrames resource but kept for
PixelLab re-roll traceability.

## Reverse-map

Original PixelLab character_id: `10c0e95f-ab8b-434a-bb50-3e29429f2030`
Parent character: `08f1db02-d4e4-4b83-856f-4a38f92914e3` (Shooter S1 skeletal-archer)
Template: `mannequin`
Generated: 2026-05-17

| Semantic name | PixelLab native folder | PixelLab template_animation_id | frames/dir |
|---|---|---|---|
| `walk/` | `walking_sadly-23954552/` | `walking_sadly` (mannequin template — slow shamble fits an undead archer) | 8 |
| `telegraph/` | `animating-93cb8ac4/` | `animating` (custom — bow-knock/draw windup, **5 frames**) | 5 |
| `atk/` | `animating-69282048/` | `animating` (custom — bow-release/follow-through, **7 frames**) | 7 |
| `hit/` | `taking_a_punch-0d806db5/` | `taking_a_punch` (mannequin template) | 6 |
| `die/` | `falling_backward-9e9dd173/` | `falling_backward` (mannequin template) | 7 |

## Two `animating-*` folders — disambiguation by frame count

PixelLab dispatched two custom-named `animating-*` jobs against the
`add_two_bright_glowi` state. `metadata.json` does NOT carry the
`animation_name` parameter passed at dispatch time, so direct semantic resolution
was impossible. Brief recommended frame-count heuristic
(telegraph=picking-up=lower frame count vs throw-object=higher).

Per-direction frame counts (verified via `ls`):
- `animating-93cb8ac4/` → **5 frames per direction** (shorter — bow-draw/knock windup)
- `animating-69282048/` → **7 frames per direction** (longer — bow-release + arrow-loose follow-through)

Mapped accordingly: 93cb8ac4 → `telegraph/` (windup), 69282048 → `atk/`
(release). This matches `Shooter.gd`'s `STATE_AIMING` (windup, 0.55 s) vs
`STATE_FIRING` (one-tick spawn + POST_FIRE_RECOVERY release) lifecycle.

## Convention established by M3W-1 (PR #271)

Every M3 character ships with:

1. PixelLab UUID-suffixed folders renamed to semantic state names (`walk/`,
   `telegraph/`, `atk/`, `hit/`, `die/`) at PR time.
2. `metadata.json` committed unmodified — preserves the UUID-history + template
   provenance for re-roll / debug.
3. `anim-folder-map.md` (this file) committed alongside — grep-discoverable
   reverse-map.

**Frame layout per anim:** 8 direction subfolders × N frames each. Shooter
frame counts: `walk` 8, `telegraph` 5, `atk` 7, `hit` 6, `die` 7 (totals:
64 + 40 + 56 + 48 + 56 = 264 frames).

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

Shooter SpriteFrames key set: `walk_<dir>`, `telegraph_<dir>`, `atk_<dir>`,
`hit_<dir>`, `die_<dir>` across all 8 dirs = 40 anims. FPS=8 across all;
`walk_*` loop=true (sustained gait), rest loop=false (one-shot beats).
