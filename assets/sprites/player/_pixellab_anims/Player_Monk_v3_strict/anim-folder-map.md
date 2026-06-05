# Player Monk v3 — PixelLab folder → semantic name reverse-map

The folders under `Player_Monk_v3_strict/animations/` have been renamed from
PixelLab's UUID-laden native names to semantic state names so that `Player.tres`
paths read clearly (`walk/south/frame_000.png` vs
`walking-aa63b7be/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name
discovery. Convention inherited from PracticeDummy M3W-1 (PR #271) and the
prior Player rig (M3W-2).

This rig REPLACES the prior `Player_re-queue` rig (the old 68×92→removed). New
hero is the Sponsor-locked **humble bald blue-eyed cloister monk** — PixelLab
prompt (from `metadata.json`): _"a dirt-poor humble cloister monk wearing ONLY a
plain simple undyed homespun wool robe, completely bald clean-shaven smooth head,
pale white skin, gentle blue eyes, ... barefoot, frail gentle and penniless,
solemn, dark-fantasy pixel art."_

**Player is doctrine-EXEMPT** (per `pixellab-pipeline.md §"Doctrine-lock is
per-character"`). These frames are shipped RAW from PixelLab — NO
`quantize_palette` / `set_palette` doctrine-lock was run, because the S1
doctrine-lock erases the blue eyes and pale skin (documented error). The
bald/pale/blue-eye look is the cross-stratum-constant character beat.

Original PixelLab character_id: `32f647b7-d63a-4342-8a51-1ece6535912f`
Group_id: `4b542afc-f7d0-43b8-89e5-50ee28f869c4`
Generated: 2026-06-04. Canvas: 92×92, 8 directions, `mannequin` template, low top-down.

## Active reverse-map

| Semantic name | PixelLab native folder | template | frame count | dir coverage |
|---|---|---|---|---|
| `idle/` | `animating-9db04594/` | (UUID-only; `animating` idle/breathe) | 4 | 8 dirs |
| `walk/` | `walking-aa63b7be/` | `walking` (mannequin) | 6 | 8 dirs |
| `attack_light/` | `jab_attack-eb842ad8/` | `jab_attack` (mannequin) | 3 | 8 dirs |
| `attack_heavy/` | `cross_punch_attack-d2676276/` | `cross_punch_attack` (mannequin) | 6 | 8 dirs |
| `hit/` | `taking_a_punch-04c0be52/` (north-east only) **MERGED WITH** `taking_a_punch-56764fe0/` (other 7 dirs) | `taking_a_punch` (mannequin) | 6 | 8 dirs (merge) |
| `die/` | `falling_backward-8dbdf2db/` | `falling_backward` (mannequin) | 7 | 8 dirs |
| `dodge/` | **SUBSTITUTE — copied from `walk/`** (no dodge anim in this rig) | n/a (walk reuse) | 6 | 8 dirs |

## Non-obvious notes

### Hit double-folder merge
The hit animation was split across TWO PixelLab folders because the re-fire
during generation split the direction set:
- `taking_a_punch-04c0be52/` → **north-east only** (6 frames)
- `taking_a_punch-56764fe0/` → the other **7 directions** (south / south-east /
  east / north / north-west / west / south-west, 6 frames each)

(NOTE: the dispatch brief stated the split was the reverse — 7 dirs in `04c0be52`
+ NE in `56764fe0`. Empirically it is as recorded above; verified by
`find monk_extracted -type d`. The merge result is identical either way: a single
6-frame × 8-dir `hit/` set.)

All hit frames are **6 frames** (brief estimated 7; actual is 6 — verified by
per-dir `ls | wc -l`).

### Dodge substitute (no PixelLab dodge animation)
This rig has NO dodge/slide animation. The prior `Player_re-queue` rig sourced
`dodge` from an `animating-03b05e65` running-slide. To preserve the
`dodge_<dir>` animation-key contract the game consumes (`Player.gd`
`ANIM_PREFIX_DODGE`, invoked on `STATE_DODGE`), `dodge/` is populated with a
**copy of the `walk/` frames** (motion pose) — doctrine-clean, no distortion.
Without this the `_play_anim(DODGE)` resolver would emit a `MISS` trace and
no-op (the sprite would freeze on the last frame during a dodge roll).

**Follow-up candidate:** a 1-gen PixelLab `animate_character` re-roll with an
explicit dodge/roll template would give a proper dodge anim. Filed as a
follow-up rather than bundled (no mid-PR scope expansion).

### Idle is now a real animation
The prior rig had NO `idle_*` keys — idle was "walk frame 0 hold" (per
`Player.gd` `ANIM_PREFIX_IDLE_AND_WALK = "walk"`). This rig ADDS `idle_*` keys
(8 dirs, 4 frames) for future use, but **the resolver still maps STATE_IDLE →
`walk` prefix** — the idle keys are present-and-available but NOT yet played.
Flipping the resolver to consume `idle_*` is a separate change (out of scope for
a frame-swap PR).

## Convention reference

See `assets/sprites/practice_dummy/_pixellab_anims/anim-folder-map.md` for the
M3W-1 baseline + the PixelLab → `.tres` dir-suffix mapping (`south → s`,
`south-east → se`, ...).

**Animation key convention in `Player.tres`:** `<state>_<dir>` for state in
{walk, idle, attack_light, attack_heavy, dodge, hit, die}, dir in
{n, ne, e, se, s, sw, w, nw}. 56 sub-animations total (48 game-consumed + 8 idle additive).

**Loop policy:**
- `walk_*`, `idle_*` — `loop = true`
- `attack_light_*`, `attack_heavy_*`, `dodge_*`, `hit_*`, `die_*` — `loop = false`
  (one-shots; state machine drives next anim)

**FPS:** 8 (M3W convention; PixelLab template anims read cleanly at this rate).
