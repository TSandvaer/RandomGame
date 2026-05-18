# Player — PixelLab folder → semantic name reverse-map (M3W-2)

The folders under `Player_re-queue/animations/` have been renamed from PixelLab's
UUID-laden native names to semantic state names so that `Player.tres` paths read
clearly (`walk/south/frame_000.png` vs `walking-c7d7ed28/south/frame_000.png`).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab
template + UUID provenance; this map exists for grep-from-game-state-name discovery.
Convention inherited from PracticeDummy M3W-1 (PR #271).

Original PixelLab character_id: `a6eddc72-3256-44c8-81e9-51065cd0e5ac`
Generated: 2026-05-17.

## Active reverse-map

| Semantic name | PixelLab native folder | template | frame count | dir coverage |
|---|---|---|---|---|
| `walk/` | `walking-afc9af0f/` (south) + `walking-c7d7ed28/` (7 others) | `walking` (mannequin) | 6 | 8 dirs (v3 re-roll composite) |
| `attack_light/` | `jab_attack-6e586140/` | `jab_attack` (mannequin) | 3 | 8 dirs |
| `attack_heavy/` | `cross_punch_attack-5d4c0925/` | `cross_punch_attack` (mannequin) | 6 | 8 dirs |
| `dodge/` | `animating-03b05e65/` | running-slide (UUID-only naming from PixelLab; matched by frame-count + dir-coverage per Priya's R-WIRE4 brief) | 6 | 8 dirs |
| `hit/` | `taking_a_punch-ad5db402/` | `taking_a_punch` (mannequin) | 6 | 8 dirs |
| `die/` | `falling_backward-6f5adaa2/` | `falling_backward` (mannequin) | 7 | 8 dirs |

## Archived (moved to `_pixellab_archive/Player_re-queue/`)

These folders were superseded or were cost-test orphans. Kept on disk for
re-roll / debug audit; **not referenced by `Player.tres`**.

| Folder | Reason archived |
|---|---|
| `walking-afc9af0f/` | Source for `walk/south/*` only (south re-roll). Contents copied into `walk/south/` before archive; original retained as audit trail. |
| `walking-c7d7ed28/` | Source for `walk/{rest of 8 dirs}/*`. Contents copied into `walk/{rest}/` before archive. |
| `animating-0db420ab/` | Early single-direction (south) cost-test from PixelLab Tier 1 calibration; 4 frames; superseded by `walking-*`. |
| `animating-59c262a9/` | Orphaned single-direction (south, 8 frames); no peer in metadata; superseded. |
| `animating-698b5818/` | 4-frame × 7-direction (no south) walk variant; superseded by `walking-afc9af0f`+`walking-c7d7ed28` v3 re-roll composite. |

## R-WIRE4 disambiguation method (per Priya's brief §M3W-2)

Three of the four `animating-<uuid>/` UUID-only folders did NOT carry a `template_animation_id` in the folder name. Disambiguation via filesystem inspection of `metadata.json`:

1. **`animating-03b05e65`** — 6 frames × full 8-direction coverage. Matches Priya's brief description: "One of the `animating-*` is running-slide → MAP TO `dodge` (~6 frames, 8 dirs)." This is the only `animating-*` folder with full 8-dir coverage, the rest are subsets / single-dir.
2. **`animating-698b5818`** — 4 frames × 7 dirs (missing `south`). Per session state, this was the original `walking-4-frames` 8-dir batch superseded by the `walking-*` v3 re-roll (which fixed the south facing-flip per the `pixellab-pipeline.md §"Template animations can flip character facing"` rule). Archived.
3. **`animating-59c262a9`** — 8 frames × south only. Orphan; no peer dirs in metadata. Archived.
4. **`animating-0db420ab`** — 4 frames × south only. The early single-direction cost-test per Priya's brief. Archived.

**Did not guess** per `[[diagnostic-traces-before-hypothesized-fixes]]` discipline: each disambiguation has a discrete observable (frame count + dir coverage). The `dodge` mapping is the load-bearing call — `03b05e65` is the only `animating-*` candidate that matches the brief's "6 frames × 8 dirs" shape. If Sponsor visual-inspect determines the `03b05e65` animation does not read as a dodge/slide, the fallback is a 1-gen PixelLab re-roll with `animation_name="dodge"` explicit.

## Convention reference

See `assets/sprites/practice_dummy/_pixellab_anims/anim-folder-map.md` for the M3W-1 baseline + the PixelLab → `.tres` dir-suffix mapping (`south → s`, `south-east → se`, ...).

**Animation key convention in `Player.tres`:** `<state>_<dir>` for state in {walk, attack_light, attack_heavy, dodge, hit, die}, dir in {n, ne, e, se, s, sw, w, nw}. 48 sub-animations total.

**Loop policy:**
- `walk_*` — `loop = true` (movement is cyclical)
- `attack_light_*`, `attack_heavy_*`, `dodge_*`, `hit_*`, `die_*` — `loop = false` (one-shots; state machine drives next anim)

**FPS:** 8 (M3W-1 convention, PixelLab template anims read cleanly at this rate).
