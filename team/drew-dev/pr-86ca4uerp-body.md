## What

Frames-only `SpriteFrames` swap of the new PixelLab grunt rig
**S1_grunt_cloister-penitent_v3** (88×88, 8-dir, `mannequin` template) into
`assets/sprites/grunt/Grunt.tres`. Mirrors the cloister-monk Player rig install
(PR #409, branch `drew/monk-rig-install`).

Ticket: **86ca4uerp** — `feat(mobs): install grunt cloister-penitent rig into Grunt.tres`.

PixelLab prompt (from `metadata.json`): _"hooded cloister penitent undead monk,
deep dark hood with two glowing red eyes in the shadow, tattered brown monk robe
with a rope belt, a short bronze censer-blade (a thurible-censer reforged into a
blade) gripped in one hand, hunched stooped penitent posture, aged and corrupted,
solemn dark fantasy, dark stone and ash palette, bold dark outline, readable
silhouette."_

## Rig → game-key map

Semantic-renamed folders (M3W-1 / PR #271 convention) + `anim-folder-map.md`
reverse-map:

| Game key (`<state>_<dir>`) | Rig source | Frames |
|---|---|---|
| `walk_*` | `walking-7291846c` | 6 |
| `atk_*` | `cross_punch_attack-ac8f904b` | 6 |
| `hit_*` | `taking_a_punch-75436a4e` | 6 |
| `die_*` | `falling_backward-0ae43a58` | 7 |
| `atk_telegraph_*` | **SUBSTITUTE ← `cross_punch_attack`** (no windup anim in rig) | 6 |
| `idle/` | `animating-fe00a480` (4) — on-disk only, **not** consumed | — |

**40 anim keys** total = `{walk, atk, atk_telegraph, hit, die} × 8 dirs`, key names
**byte-identical** to the prior Grunt.tres contract, so all downstream consumers
(`Grunt.gd` state→anim map, `tests/test_grunt_animation_wire.gd`, Playwright specs)
are unchanged. 248 frame `ext_resource`s.

## Diagnose-before-naming — the ticket's anim map was incomplete

Per my trace-first discipline I verified the rig→key map against the **game-side
contract** before naming keys, rather than trusting the dispatch brief verbatim.
The brief listed `{idle, walk, attack, hit, death}`. Empirically (pinned by
`tests/test_grunt_animation_wire.gd:26` + `scripts/mobs/Grunt.gd::_set_state`):

1. The attack key is **`atk`**, not `attack`.
2. The state machine requires an **`atk_telegraph`** key (light/heavy windup) — the
   rig ships **no** windup/telegraph animation, so I substituted it from the
   `cross_punch_attack` frames. It reads as the cross-punch wind-up under the
   existing red-tint overlay (`Grunt._play_attack_telegraph`). Mirrors the
   `dodge ← walk` substitute in PR #409 — same rig-missing-anim pattern.
3. **`idle`** is **not** consumed — `STATE_IDLE` plays `walk_<dir>`. Idle frames are
   kept on-disk for rig provenance/future use but `Grunt.tres` does not reference them.

Naming `idle`/`attack`/`death` (the brief's words) would have produced a `.tres`
that fails the wire test (`atk_telegraph_*` missing, `atk_*` missing). Caught at
key-naming time, not at CI.

## OOS honored

NO collision / AI / spawn / scale changes — frames only. `scenes/mobs/Grunt.tscn`
**untouched**; the `Sprite` AnimatedSprite2D carries no `scale` (1.0), so the
68×68 → 88×88 canvas change renders the grunt **~29% larger on screen**. This
matches the PR #409 larger-rig-no-scale-compensation precedent. The collision
shape (12 px radius) is unchanged and decoupled from the cosmetic sprite.
**Visual-scale delta flagged for Sponsor soak** (see Self-Test Report).

## Cross-lane integration check

- **`[combat-trace]` contract preserved** — no trace lines touched; the
  `Grunt._play_anim | PLAY anim=<key>` / `MISS anim=<key>` traces still emit with the
  identical key shapes (key names unchanged).
- **Player iframes / Damage constants** — untouched (frames-only).
- **RoomGate signal chain** — untouched; `mob_died`/`CONNECT_DEFERRED` wiring
  unaffected by a SpriteFrames swap.
- **Adjacent specs probed** — grep confirms no external refs to the old
  `Grunt_v2_S1_Embergrave_red-eyes` rig path outside its own folder; only
  `Grunt.tres` referenced it. Playwright specs match on `Grunt.pos` / `Grunt._set_state`
  / anim-key traces — all unchanged.

## Regression guard

`tests/test_grunt_animation_wire.gd` is the regression pin: it asserts the
40-key `{walk, atk, atk_telegraph, hit, die} × 8 dirs` SpriteFrames contract,
loop flags (walk loops, rest one-shot), FPS=8, and the state→anim playback
(`take_damage → hit_<dir>`, `_die → die_<dir>`, `chase → walk_<dir>`). If a future
rig swap drops a key or mis-names one, this test fails before CI green. Test is
unchanged — the swap keeps the keys it pins.

## Tests

- **GUT full suite:** 1937/1937 passing, 67 pre-existing W3-T2 pending stubs,
  **0 failing** — local run on `f8ac7e3`.
- **`test_grunt_animation_wire.gd` + `test_grunt.gd` + `test_combat_visuals.gd`:**
  67/67 passing locally.
- **CI / Playwright:** see Self-Test Report comment.
