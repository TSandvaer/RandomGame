# Charger — PixelLab folder → semantic name reverse-map

The folders under `Charger_S1_Embergrave/animations/` have been renamed from
PixelLab's UUID-laden native names to semantic state names so that
`SpriteFrames.tres` paths read clearly (`walk/south/frame_000.png` vs
`running-8142ff5e/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery.

## Reverse-map

Original PixelLab character_id: `a114419e-23e9-43c8-bb47-4ef8eb21cc61`
Template: `bear` (quadruped — explains the missing `hit` animation, see below)
Generated: 2026-05-17

| Semantic name | PixelLab native folder | PixelLab template_animation_id | frames/dir |
|---|---|---|---|
| `walk/` | `running-8142ff5e/` | `running` (bear template) | 4 |
| `telegraph/` | `acting_angry-060d0b5f/` | `acting_angry` (bear template — rear-up/growl windup pose) | 9 |
| `atk/` | `jump_attack-aa4e7c70/` | `jump_attack` (bear template — pounce on player) | 8 |
| `die/` | `going_to_sleep-4728493a/` | `going_to_sleep` (bear template — collapse + lie down) | 8 |

## NO `hit` animation — quadruped template constraint

Charger's PixelLab character uses the `bear` template, which does NOT ship a
take-a-hit / flinch animation analog. Per Priya's M3W-3 brief, the
post-take_damage hit-flash visual is preserved entirely via the modulate-fallback
path of the M3W-1 3-branch hit-flash resolver — `Charger.gd._play_hit_flash`
falls through the `_hit_flash_uses_animated_sprite` branch and tweens
`AnimatedSprite2D.modulate` rest → `HIT_FLASH_TINT` → rest (soft red wash).

The state machine never calls `play("hit_<dir>")` because the SpriteFrames
resource has no `hit_*` keys; the resolver-side defensive
`has_animation` check would no-op anyway, but the script skips the call
explicitly so the trace doesn't emit a `MISS anim=hit_<dir>` line every hit.
This is the documented exception to the otherwise-uniform M3W-3 per-mob anim
state mapping.

## Convention established by M3W-1 (PR #271)

Every M3 character ships with:

1. PixelLab UUID-suffixed folders renamed to semantic state names (`walk/`,
   `telegraph/`, `atk/`, `die/`) at PR time.
2. `metadata.json` committed unmodified — preserves the UUID-history + template
   provenance for re-roll / debug.
3. `anim-folder-map.md` (this file) committed alongside — grep-discoverable
   reverse-map.

**Frame layout per anim:** 8 direction subfolders × N frames each. Charger
frame counts: `walk` 4, `telegraph` 9, `atk` 8, `die` 8 (totals:
32 + 72 + 64 + 64 = 232 frames).

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

Charger SpriteFrames key set: `walk_<dir>`, `telegraph_<dir>`, `atk_<dir>`,
`die_<dir>` across all 8 dirs = 32 anims. FPS=8 across all; `walk_*` loop=true
(sustained gait), rest loop=false (one-shot beats).
