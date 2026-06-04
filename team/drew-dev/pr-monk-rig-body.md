## feat(player): install new monk sprite rig (8-dir, 6 anims)

Replaces the old Player sprite rig with the Sponsor-locked new hero — the
**humble bald, pale-skinned, blue-eyed cloister monk**. PixelLab char
`32f647b7-d63a-4342-8a51-1ece6535912f` ("Player Monk v3 strict"), 92×92 canvas,
8 directions, `mannequin` template.

PixelLab prompt (from `metadata.json`): _"a dirt-poor humble cloister monk
wearing ONLY a plain simple undyed homespun wool robe, completely bald
clean-shaven smooth head, pale white skin, gentle blue eyes, absolutely no
armor … barefoot, frail gentle and penniless, solemn, dark-fantasy pixel art."_

### Scope — frames-only swap

Per the dispatch brief, this swaps the **frames**, not the structure. Preserved
verbatim so `Player.tscn`, `Player.gd`'s 3-branch anim resolver,
`_update_sprite_rotation`, and the `[combat-trace]` contract keep working
untouched:

- **SpriteFrames UID** `uid://b0embergrave_player_sprite_frames` (so the
  `Player.tscn` ext_resource reference is unchanged — **Player.tscn needs NO edit**).
- The **48 game-consumed anim keys** (`walk` / `attack_light` / `attack_heavy` /
  `dodge` / `hit` / `die` × 8 dirs).
- Loop policy (`walk_*` loop=true; one-shots loop=false), **8 fps**, the
  `"Sprite"` node name.

### Anim mapping (PixelLab folder → game state)

| Game state | PixelLab folder | frames |
|---|---|---|
| `idle` | `animating-9db04594` | 4 |
| `walk` | `walking-aa63b7be` | 6 |
| `attack_light` | `jab_attack-eb842ad8` | 3 |
| `attack_heavy` | `cross_punch_attack-d2676276` | 6 |
| `hit` | `taking_a_punch-04c0be52` (NE only) **MERGED** `taking_a_punch-56764fe0` (7 dirs) | 6 |
| `die` | `falling_backward-8dbdf2db` | 7 |
| `dodge` | **SUBSTITUTE from `walk/`** (rig has no dodge anim) | 6 |

Reverse-map: `assets/sprites/player/_pixellab_anims/Player_Monk_v3_strict/anim-folder-map.md`.
`metadata.json` kept byte-identical to the ZIP root (upstream provenance).

### Non-obvious findings (Drew — diagnose-via-trace discipline)

1. **Hit double-folder merge — brief's split was reversed.** The brief said
   `04c0be52` = 7 dirs + `56764fe0` = NE. **Empirically it is the reverse**:
   `04c0be52` holds **north-east ONLY**, `56764fe0` holds the other 7 dirs
   (verified by `find … -type d`). The merge result is identical either way:
   one 6-frame × 8-dir `hit/` set. Also: hit is **6 frames**, not the 7 the
   brief estimated (verified per-dir `ls | wc -l`).

2. **Dodge gap — rig ships no dodge animation.** The monk rig has no
   dodge/slide anim, but the game consumes `dodge_<dir>` (Player.gd
   `ANIM_PREFIX_DODGE`, invoked on `STATE_DODGE`). To keep the key contract
   intact I populated `dodge/` with a **copy of the `walk/` frames** (motion
   pose, doctrine-clean). Without this, `_play_anim(DODGE)` emits a `MISS`
   trace and no-ops — the sprite would freeze on the last frame during a dodge
   roll. **Follow-up candidate (NOT bundled — no mid-PR scope expansion):** a
   1-gen PixelLab `animate_character` re-roll with a roll/slide template for a
   proper dodge anim.

3. **Canvas 68→92px needs NO offset/scale change.** I checked the character
   bounding box across states: OLD char ≈ 20×49 px on a 68px canvas; NEW monk
   ≈ 23–25 × 45–46 px on a 92px canvas — **same physical size**, just more
   transparent padding. Both rigs center the character on their canvas, and
   AnimatedSprite2D centers the texture on the node origin, so the monk sits at
   the same screen position + size. The collision capsule (CircleShape2D r=10 at
   node origin) stays aligned. The brief's `char_scale=0.6` worry does not apply
   — **there is no `char_scale` in the player code** (mob-side concept). Confirmed
   visually in the HTML5 soak screenshots: monk sits correctly on the 32px floor
   grid, no distortion. Player.tscn is therefore unmodified.

4. **Idle is now additive.** The prior rig had NO `idle_*` keys (idle = "walk
   frame 0 hold" per the resolver). This rig ADDS real `idle_*` keys (4f × 8).
   **The resolver still maps STATE_IDLE → `walk` prefix** — the idle keys are
   present-and-available but not yet played. Flipping the resolver to consume
   `idle_*` is a separate change (out of scope for a frame-swap). Total keys:
   56 (48 consumed + 8 additive idle).

5. **Doctrine-EXEMPT — frames shipped RAW.** Per `pixellab-pipeline.md
   §"Doctrine-lock is per-character"`, the Player is a cross-stratum constant.
   NO `quantize_palette` / `set_palette` doctrine-lock was run (it erases the
   blue eyes — documented error). The bald/pale/blue-eye look is preserved.

6. **Missing identity doc.** The dispatch brief cited
   `team/uma-ux/character-monster-direction.md §1` for the locked monk identity
   — that file does not exist in the worktree. The monk identity is established
   in the PixelLab prompt (`metadata.json`, quoted above) + world lore
   (`hub-town-direction.md`, `boss-room-door-spec.md` reference the cloister
   monks). Proceeded on the brief's explicit doctrine-exempt + bald/pale/blue-eye
   constraint. Flagging for Uma to confirm the canonical identity-doc location.

### Tests

- **Paired GUT:** `tests/test_player_monk_rig.gd` (15 tests) — rig loads, 7×8
  keys present, per-state frame counts match PixelLab source, hit-merge 8-dir
  coverage, additive idle keys, doctrine-exempt raw-path marker (guards a
  regression to the old rig OR an accidental doctrine-lock pass).
- **Existing `tests/test_player_animation_wire.gd` (23 tests)** stays green —
  the AnimatedSprite2D wiring + resolver contract is preserved.
- **Local GUT run:** `38/38` on both player files. Full suite: `1837/1838`
  passing — the 1 failure is `test_stat_allocation.gd::test_stat_strings_resource_loads_with_12_strings`
  (a pre-existing `inst_to_dict()` GUT quirk on a typed `StatStrings` Resource;
  fails identically on an unmodified checkout of that file — NOT a regression
  from this branch, which touches no stat code).

### HTML5 visual-verification gate

Sprite swap = render-path change → gate applies. Verified against the
**production release-build artifact** (run 26951686303, SHA `61d8a8b`,
`embergrave-html5-61d8a8b`).

- **CI release build green** at HEAD SHA (HTML5 export succeeds with the new rig).
- **Author self-soak** (`tests/playwright/specs/drew-monk-rig-self-soak.spec.ts`,
  real Chromium + COOP/COEP server) — booted Room 01, drove walk (4 dirs) +
  light + heavy attack. **All `Player._play_anim | PLAY anim=<state>_<dir>`
  traces fired** (`walk_s/e/w/n`, `attack_light_ne`, `attack_heavy_ne`), **zero
  MISS traces**, **zero physics-flush panic**. 1 passed (20.3s).
- **Screenshots** (in Self-Test Report) confirm the bald/pale/blue-eyed monk
  renders in WebGL2 at correct size on the floor grid.
- **Adjacent cross-lane probe:** `player-walk-feel-decouple.spec.ts` (3 tests,
  sprite-rotation-pinned-at-0 + velocity-driven anim) passes against the monk
  artifact — the PR #274 walk-feel contract survives the swap.

### Cross-lane integration check

- `[combat-trace]` contract: `Player._play_anim` PLAY/MISS lines unchanged
  (traces fire correctly in the soak).
- Player iframes / Damage constants: untouched.
- Resolver 3-branch + `_update_sprite_rotation` (rotation=0 pin): untouched +
  verified by the walk-feel spec.
- No new mob class, no Area2D-state / physics-flush surface touched.

### Regression guard

`tests/test_player_monk_rig.gd::test_frame_textures_point_at_raw_monk_rig_not_doctrine_locked`
fails if a future change reverts to the old `Player_re-queue` rig OR routes the
frames through a doctrine-locked export path (the blue-eye-erasure trap).
