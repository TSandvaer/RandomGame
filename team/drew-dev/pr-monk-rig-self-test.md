## Self-Test Report — feat(player): install new monk sprite rig

### Summary
Frames-only swap of the Player rig to the doctrine-exempt monk hero. Anim
key/structure/UID preserved; Player.tscn unmodified. Verified GUT + HTML5
release-build self-soak.

### GUT (local, Godot 4.3 + vendored `addons/gut/`)
- `tests/test_player_monk_rig.gd` (new, 15 tests) — **PASS**
- `tests/test_player_animation_wire.gd` (existing contract, 23 tests) — **PASS**
- Both files together: **38/38 passing** (`-gtest` filtered run).
- Full suite: **1837/1838 passing**. The single failure —
  `test_stat_allocation.gd::test_stat_strings_resource_loads_with_12_strings` —
  is a **pre-existing** `inst_to_dict()` GUT quirk on a typed `StatStrings`
  Resource. Confirmed it fails identically on an unmodified checkout of that
  file in isolation (23 pass / 1 fail). This branch touches **no** stat code
  (`git status` shows only `assets/sprites/player/` + the two test files). NOT
  a regression.

### HTML5 visual-verification gate — PASS

Sprite swap is a render-path change → gate applies. (No local HTML5 export
templates installed, so verified against the **production CI release-build
artifact**, NOT a local export.)

**Artifact:** `embergrave-html5-61d8a8b` — run 26951686303 (SHA `61d8a8b`),
**release build green**. Direct download:
https://github.com/TSandvaer/RandomGame/actions/runs/26951686303/artifacts/7411407895

**Self-soak** (`drew-monk-rig-self-soak.spec.ts`, real headless Chromium +
COOP/COEP `artifact-server.ts`, booted the production artifact): **1 passed
(20.3s).** Captured `Player._play_anim` traces:

```
[combat-trace] Player._play_anim | PLAY anim=walk_s   (seed / rest)
[combat-trace] Player._play_anim | PLAY anim=walk_e
[combat-trace] Player._play_anim | PLAY anim=walk_s
[combat-trace] Player._play_anim | PLAY anim=walk_w
[combat-trace] Player._play_anim | PLAY anim=walk_n
[combat-trace] Player._play_anim | PLAY anim=attack_light_ne
[combat-trace] Player._play_anim | PLAY anim=attack_heavy_ne
```

- All 4 walked directions + light + heavy attack **PLAY** real SpriteFrames keys.
- **Zero `Player._play_anim | MISS`** — every consumed key resolves after the swap.
- **Zero `Can't change this state while flushing queries`** — no physics-flush panic.

**Screenshots (verified by Drew, in `C:\tmp\monk-soak-*.png`):**
- `monk-soak-idle.png` — Room 01 boot, BuildInfo `61d8a8b` (no cache). The
  player is the **bald, pale-skinned monk in a plain robe**, rendered correctly
  in WebGL2, sitting on the 32px floor grid at correct size next to the
  PracticeDummy. No distortion, no scale/offset artifact from the 68→92px
  canvas growth.
- `monk-soak-attack.png` — monk after walking N + attacking; pose renders
  cleanly, proportions correct.

**Bald/pale/blue-eye check:** the monk's head reads bald + pale and the robe
reads plain/undyed — the doctrine-exempt look is preserved (no doctrine-lock
pass run). At 16-px game zoom the eye-blue is a 1–2px accent; the silhouette +
bald head + robe are unmistakable. Recommend a brief Sponsor glance to confirm
the eye-blue reads at play zoom (subjective-feel slice only — mechanical
correctness is covered).

### Cross-lane integration check
- **`[combat-trace]` contract preserved** — `Player._play_anim` PLAY/MISS lines
  fire correctly in the soak; `Player.pos` / `Player.try_attack` shapes untouched.
- **Player iframes / Damage constants** — untouched (frames-only).
- **Resolver 3-branch + `_update_sprite_rotation` rotation=0 pin** — untouched;
  verified by running `player-walk-feel-decouple.spec.ts` (3 tests) against the
  monk artifact → **3 passed**.
- **RoomGate signal chain** — not touched; Room 01 boot + tutorial beats fire
  normally in the soak (seed walk_s + WASD beat).
- **No Area2D-state / physics-flush / new-mob-class surface** in scope.

### Escape-clause disclosure
Author cannot run a local HTML5 *export* (no web export templates installed),
but DID self-soak the **production CI release-build artifact** in real Chromium
+ captured screenshots — so this is full in-engine WebGL2 verification, not a
deferral. The only item routed to Sponsor is the **subjective** eye-blue
legibility-at-zoom glance (1 probe target).
