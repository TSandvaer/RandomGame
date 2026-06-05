# Grunt v3 cloister-penitent — PixelLab folder → semantic name reverse-map

The folders under `Grunt_v3_cloister-penitent/animations/` have been renamed from
PixelLab's UUID-laden native names to semantic state names so that `Grunt.tres`
paths read clearly (`walk/south/frame_000.png` vs
`walking-7291846c/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
character + template + UUID provenance; this map exists for
grep-from-game-state-name discovery. Convention inherited from PracticeDummy
M3W-1 (PR #271), Grunt v2 M3W-3, and the cloister monk Player rig (PR #409).

This rig REPLACES the prior `Grunt_v2_S1_Embergrave_red-eyes` rig (68×68). The new
art is the Sponsor-locked **S1 grunt cloister-penitent** — PixelLab prompt (from
`metadata.json`): _"hooded cloister penitent undead monk, deep dark hood with two
glowing red eyes in the shadow, tattered brown monk robe with a rope belt, a short
bronze censer-blade (a thurible-censer reforged into a blade) gripped in one hand,
hunched stooped penitent posture, aged and corrupted, solemn dark fantasy, dark
stone and ash palette, bold dark outline, readable silhouette."_

Original PixelLab character_id: `1245d6aa-c30d-43be-9567-8f3f0b564e86`
Generated: 2026-06-04. Canvas: 88×88, 8 directions, `mannequin` template, low top-down.

## Active reverse-map

| Semantic name | PixelLab native folder | template | frame count | dir coverage |
|---|---|---|---|---|
| `idle/` | `animating-fe00a480/` | (UUID-only; `animating` idle/breathe) | 4 | 8 dirs |
| `walk/` | `walking-7291846c/` | `walking` (mannequin) | 6 | 8 dirs |
| `atk/` | `cross_punch_attack-ac8f904b/` | `cross_punch_attack` (mannequin) | 6 | 8 dirs |
| `atk_telegraph/` | **SUBSTITUTE — copied from `cross_punch_attack-ac8f904b/`** (no windup anim in this rig) | (atk reuse) | 6 | 8 dirs |
| `hit/` | `taking_a_punch-75436a4e/` | `taking_a_punch` (mannequin) | 6 | 8 dirs |
| `die/` | `falling_backward-0ae43a58/` | `falling_backward` (mannequin) | 7 | 8 dirs |

## Non-obvious notes

### `atk_telegraph` substitute (no PixelLab windup animation)

The game's Grunt state machine plays an `atk_telegraph_<dir>` key during the
light/heavy pre-swing windup window (see `scripts/mobs/Grunt.gd::_set_state` —
`STATE_TELEGRAPHING_LIGHT` / `STATE_TELEGRAPHING_HEAVY` → `_play_anim(&"atk_telegraph")`).
The cloister-penitent rig was generated WITHOUT a dedicated windup/telegraph
animation, so `atk_telegraph/` is a verbatim copy of the `cross_punch_attack`
(`atk/`) frames. This reads correctly: the telegraph window shows the cross-punch
swing-up under a red-tint overlay (`Grunt._play_attack_telegraph`), which is exactly
"the grunt winding up its punch." Mirrors the cloister-monk Player rig's
`dodge ← walk` substitute (PR #409) — same rig-missing-anim pattern.

The prior `Grunt_v2` rig HAD a distinct `atk_telegraph` PixelLab anim (8 frames);
this rig does not, so the substitute is a net behavior-preserving change at the
SpriteFrames-key level (the `atk_telegraph_<dir>` keys still exist; only their
source frames changed).

### `idle/` retained for provenance, not consumed by the game

The Grunt state machine never plays an `idle_<dir>` key — `STATE_IDLE` plays
`walk_<dir>` (a grunt standing still still uses the gait frames). The `idle/`
frames are kept on-disk for rig completeness + future use, but are NOT referenced
by `Grunt.tres`. (The ticket's brief listed `idle ← animating-fe00a480`; empirically
the game-side anim contract is `{walk, atk, atk_telegraph, hit, die}` — verified
against `tests/test_grunt_animation_wire.gd` which pins exactly those 5 states ×
8 dirs = 40 keys.)

### Canvas-size change: 68×68 → 88×88

The new rig's native canvas is 88×88 vs the old v2 rig's 68×68. The Grunt scene
(`scenes/mobs/Grunt.tscn`) `Sprite` AnimatedSprite2D carries NO explicit `scale`
(defaults to 1.0), so the grunt renders ~29% larger on screen. This matches the
cloister-monk Player rig precedent (PR #409 shipped a larger-canvas rig with no
scale compensation). Collision shape (12 px radius) is unchanged per ticket OOS —
the sprite is purely cosmetic and decoupled from the collider. Flagged for
Sponsor soak as a visual-scale note.
