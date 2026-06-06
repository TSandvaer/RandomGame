# Shooter v3 brazier-warden — PixelLab folder → semantic name reverse-map

The folders under `Shooter_v3_brazier-warden/animations/` have been renamed from
PixelLab's UUID-laden native names to semantic state names (M3W-1 / PR #271
convention) so that `Shooter.tres` paths read clearly
(`walk/south/frame_000.png` vs `walking-4a06b94c/south/frame_000.png`).

The `_pixellab_anims/metadata.json` sibling is the authoritative upstream record
of the PixelLab character + template provenance; this map exists for
grep-from-game-state-name discovery and to document the telegraph/atk substitute.

## Provenance

- PixelLab character id: `1301b90c-4792-4687-8948-55b3f72ae2ce`
- Character name: `S1 shooter brazier-warden v3`
- Template: `mannequin`
- View: `low top-down`, 8 directions
- Canvas size: 124×124
- Created: 2026-06-05T06:10:02Z
- Prompt: _"hunched undead cloister monk brazier-warden, a glowing ember
  fire-bowl FUSED onto one forearm (not a held torch), deep dark hood with two
  glowing red eyes in the shadow, scorched tattered brown monk robe with a rope
  belt, hunched stooped penitent posture, aged and corrupted, solemn dark
  fantasy, dark stone and ash palette with ember-orange glow, bold dark outline,
  readable silhouette, NOT a rogue"_

## Reverse-map

| Game key (`<state>_<dir>`) | PixelLab native folder | template | frames/dir |
|---|---|---|---|
| `walk_*` | `walking-4a06b94c` | `walking` (mannequin) | 6 |
| `atk_*` | `casting_a_fireball-bd10942e` | `casting_a_fireball` (mannequin) | 6 |
| `telegraph_*` | **SUBSTITUTE ← `casting_a_fireball-bd10942e`** (no windup anim in rig) | `casting_a_fireball` | 6 |
| `hit_*` | `taking_a_punch-de409fd2` | `taking_a_punch` (mannequin) | 6 |
| `die_*` | `falling_backward-1ca72fc7` | `falling_backward` (mannequin) | 7 |
| `idle/` | `animating-f718f875` (4) — on-disk only, **not consumed** | `animating` | 4 |

## The `telegraph` substitute — why `casting_a_fireball` for both windup and release

`Shooter.gd`'s state machine (`scripts/mobs/Shooter.gd::_set_state`) requires a
**`telegraph`** key for `STATE_AIMING` — the projectile windup band — and an
**`atk`** key for `STATE_FIRING` / `STATE_POST_FIRE_RECOVERY` (the release +
follow-through). The brazier-warden rig ships **no dedicated windup/aim
animation** — the only attack-shaped template is `casting_a_fireball`, a single
cast cycle.

I mapped **both** `telegraph` and `atk` to the `casting_a_fireball` frames. The
cast windup reads as the aim telegraph under the existing red-glow tint overlay
that `Shooter._play_attack_telegraph` applies during `STATE_AIMING`
(`ATTACK_TELEGRAPH_TINT`, ~0.55s aim window per the 3-band design), so the
shooter "charges its fire-bowl" during aim, then the same cast frames play the
release. This mirrors the grunt PR #411 `atk_telegraph ← cross_punch_attack`
substitute (same rig-missing-windup pattern) and PR #271's PracticeDummy
substitute convention.

If a dedicated bow-knock / fire-bowl-charge windup is generated later, repoint
`telegraph/` to it — the `.tres` key (`telegraph_<dir>`) stays the same, so it is
a frames-only repoint with no game-side change.

## Why `Shooter_v3_brazier-warden/` (not the prior `add_two_bright_glowi/`)

The prior Shooter rig (`add_two_bright_glowi/`, a `create_character_state`
eye-glow variant of the `Shooter_S1_skeletal-archer` base) is **preserved
untouched on disk** for provenance — no other code, scene, or spec references it
once `Shooter.tres` is repointed. The brazier-warden v3 rig is the new
character-direction state Sponsor's art-pass moved to (ember fire-bowl monk,
replacing the skeletal-archer silhouette).

## Animation key convention in `.tres`

`<state>_<dir>` where dir ∈ {`n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw`}:

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

SpriteFrames key set: `walk_<dir>`, `telegraph_<dir>`, `atk_<dir>`, `hit_<dir>`,
`die_<dir>` across all 8 dirs = **40 anims**. FPS=8 across all; `walk_*`
loop=true (sustained gait), rest loop=false (one-shot beats). Total consumed
frames: (6 walk + 6 telegraph + 6 atk + 6 hit + 7 die) × 8 = **248** frame
`ext_resource`s.
