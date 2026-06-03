# S1 Scroll Retrofit — Investigation + Staged Proposal (spike)

> **Spike — NO implementation.** Findings + staged retrofit plan only. Sponsor committed (2026-06-03) to retrofitting Stratum-1 from fixed single-screen rooms to bigger / scrolling rooms so a wide monitor shows MORE world content instead of a centered box surrounded by black void.
>
> Branch: `devon/s1-scroll-retrofit-spike`. Evidence is file:line against HEAD (`3ead714`).

---

## 1. ROOT CAUSE — the box-in-the-middle / black void

The symptom has **two independent, stacking mechanisms**. Both must be addressed; fixing one without the other leaves residual void.

### Mechanism A — `aspect="keep"` letterboxes the whole game to 16:9 (the actual "black bars" the Sponsor sees)

`project.godot` [display] (lines 50-53):

```
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

`aspect="keep"` (Godot 4.3) forces the rendered frame to preserve the **1280:720 = 16:9** ratio. On a monitor wider than 16:9 (21:9 ultrawide, or any window the player makes wider than 16:9), Godot **pillarboxes** — paints black bars left+right and scales the 16:9 frame to fit the height. On a taller window it letterboxes top+bottom. The black void around the play area is the `aspect="keep"` bar region. **No camera or world change can fill those bars while `aspect="keep"` is set** — the bars are outside the canvas-items projection entirely.

To make a wider monitor show MORE world (not a stretched/zoomed same-amount), the aspect policy must change to `"expand"` — which keeps the base height and **widens the visible logical region** to match the window's aspect ratio. `"expand"` is the canonical Godot answer to "bigger screen = more world." (See § 5 risk note — `expand` interacts with the HUD anchoring + the canvas_resize clobber.)

### Mechanism B — the camera bounds-clamp pins to a 480×270 box, and there is no world past it (the "small centered box")

Even within the 16:9 frame, the play area is a fixed 480×270 logical room scaled up ~2.667×. Why zooming OUT shows void rather than more world:

- **Logical room size = 480×270.** Every S1 room is authored at viewport-native 480×270 (`Main.DEFAULT_PLAYER_SPAWN` comment line 188-189; `Main.S1_ROOM_BOUNDS = Rect2(0,0,480,270)` line 213). The chunk geometry confirms it: `s1_room01_chunk.tscn` walls at WallNorth y=16, WallSouth y=240, WallWest x=16, WallEast x=464 — floor spans roughly x∈[32,448], y∈[32,238]. **There are no floor tiles authored past those walls.** Anything the camera reveals beyond ~480×270 is the project clear-color `Color(0.06,0.05,0.08)` (project.godot:131) — i.e. void.

- **Pre-T9 implicit zoom = the stretch ratio, not 1:1.** With `canvas_items` stretch, the 480×270 logical room was scaled to the 1280×720 viewport at an implicit `1280/480 = 2.6667×`. `CameraDirector.BASELINE_ZOOM = Vector2(2.6667, 2.6667)` (CameraDirector.gd:158) was calibrated to reproduce exactly that (camera-layer.md § "Default-zoom calibration").

- **The bounds-clamp math centers the camera and never scrolls.** `Main._engage_camera_for_room()` (line ~2200) calls `CameraDirector.set_world_bounds(S1_ROOM_BOUNDS)` = `Rect2(0,0,480,270)`. The clamp (`_clamp_to_world_bounds`, CameraDirector.gd:760-785) computes `viewport_world = LOGICAL_VIEWPORT_BASE / engine_zoom = (1280,720)/2.6667 = 480×270`. Then per-axis: `if bounds.size.axis <= viewport_world.axis: camera = bounds center`. Since `480 <= 480` AND `270 <= 270` on both axes, **both axes take the "narrower-or-equal than viewport → center the camera" branch** (camera-scroll.md § "Subtle case — bounds.size == viewport.size" documents this exact equality). The camera holds dead-center; it never scrolls because there is nothing wider than the viewport to scroll across.

- **Zooming OUT makes it worse, deliberately.** `request_zoom(0.75, …)` → engine zoom `2.0` → `viewport_world = (1280,720)/2.0 = 640×360`. Now `480 < 640` and `270 < 360`: still the "center" branch, but the viewport is now SHOWING a 640×360 world window of which only the inner 480×270 has floor — the surrounding ~80px margin on each side is void. So zoom-out reveals MORE VOID, not more world, precisely because no world exists past 480×270. This is why the recently-merged tunable-zoom soak control (PR #402, `?cam_zoom`) shows void when dialed below 1.0.

**One-liner:** The world is only 480×270; `aspect="keep"` pillarboxes the 16:9 frame on wide monitors (black bars), and the camera bounds-clamp centers on the 480×270 box (never scrolls) — so a bigger screen / zoom-out reveals engine clear-color void, not more authored content. The fix is (a) `aspect="expand"` to claim the wide pixels + (b) actually-wider authored/assembled S1 floors with bounds wider than the viewport so the existing scroll machinery engages.

---

## 2. How S1 rooms work TODAY

| Aspect | Reality (file:line) |
|---|---|
| Logical room size | 480×270 logical px. Chunk `size_tiles = Vector2i(15, 8)`, `tile_size_px = 32` (`resources/level_chunks/s1_room02.tres`) → 15×32=480 wide, 8×32=256 tall. The 270 is the viewport-height target; the playable floor is ~480×256 inside the 480×270 bounds. |
| Room scenes | `scenes/levels/Stratum1Room01.tscn` (script `Stratum1Room01.gd` — tutorial), `Stratum1Room02..08.tscn` (all script `MultiMobRoom.gd`). Each `.tscn` is a thin wrapper: script + `chunk_def` ExtResource + mob-scene paths + `room_gate_position/size`. |
| Floor/wall visual | Lives in the chunk scene `scenes/levels/chunks/s1_room01_chunk.tscn` (script `S1CloisterChunk.gd`): `FloorTiles` TileMapLayer + 4 `StaticBody2D` walls (N/S/W/E) with `RectangleShape2D` collision (480×32 horizontal, 32×256 vertical) + decorative `ColorRect` seams + props. **This is the node that defines the visible play box.** |
| Room array | `Main.ROOM_SCENE_PATHS` (lines 64-75): 8 S1 rooms + S1 boss room (index 8) + S2 boss room (index 9). Linear traversal Room01→…→Room08→S1Boss via `_on_room_cleared` → `_load_room_at_index`. |
| Camera per room | `Main._load_room_at_index` (line 664) re-parents player to `DEFAULT_PLAYER_SPAWN (240,200)` then calls `_engage_camera_for_room()` (line 711) → `follow_target(player, Vector2(40,24))` + `set_world_bounds(Rect2(0,0,480,270))`. Boss room ALSO engages in its deferred `_assemble_room_fixtures` (camera-scroll.md § "Stratum1BossRoom"). Net effect today: **zero visual change vs pre-T9** — camera centers, follow is inert because the deadzone never crosses (player can't leave the 480×270 box). |
| Bounds constant | `Main.S1_ROOM_BOUNDS = Rect2(0,0,480,270)` (line 213) — single source of truth, explicitly commented as the swap point for `AssembledFloor.bounding_box_px` when procgen lands. |

---

## 3. The REUSABLE infra S1 would inherit (already on main)

S2 traversal already drives the full continuous-scroll + procgen stack. S1 inherits ALL of it:

1. **`CameraDirector` continuous-scroll API** (camera-scroll.md). `follow_target(target, deadzone_px)` + `set_world_bounds(bounds: Rect2)`. The bounds-clamp is **viewport-aware** (recomputes vs live zoom every tick), so a wider bounds rect (e.g. `Rect2(0,0,1440,270)`) makes the clamp take the **scroll** branch instead of the center branch — the camera tracks the player across the floor and clamps at edges. This is exactly the spike scene's validated behavior (`scenes/spike/CameraScrollSpike.tscn`, 1440-wide, camera-scroll.md § "Spike scene").

2. **`FloorAssembler.assemble_floor(zone_def, seed) -> AssembledFloor`** (procgen-pipeline.md). Lays chunks left→right along +X (`FloorAssembler.gd:197-205`), unions their rects into `bounding_box_px` (line 205). S1 already has an authored zone: `resources/level/zones/s1_z1_outer_cloister.tres` (the W2-T3 retrofit covering the whole S1 arc).

3. **`Main` S2 traversal driver as the template** (PR #391, procgen-pipeline.md § "S2 production consumer"). The methods S1 would mirror, all live on `Main.gd`:
   - `_render_assembled_floor(assembled)` (line 1684): teardown + `_instantiate_chunks` + `_spawn_assembled_floor_mobs` + `_reparent_player_into` + `_engage_camera_for_assembled_floor`.
   - `_instantiate_chunks(assembled)` (line 1713): instantiate each chunk's `scene_path` at `placed.position_px`.
   - `_engage_camera_for_assembled_floor(assembled)` (line 1839): `follow_target` + `set_world_bounds(assembled.bounding_box_px)` — **this is the production consumer of `bounding_box_px` the S1 wiring's comment (line 206-211) anticipated.**
   - `_spawn_assembled_floor_mobs` (line 1745) + chunk-clear gate `_on_s2_mob_died` (line 1884) → CONNECT_DEFERRED decrement → `_advance_s2_zone`.

**Key inheritance:** S1's `_engage_camera_for_room()` currently feeds a hardcoded `Rect2(0,0,480,270)`. To get scrolling, S1 only needs to feed a **wider bounds rect** — either from a wider authored chunk or from `FloorAssembler.bounding_box_px`. The scroll machinery is already wired and tested; it is inert today *purely because the bounds equal the viewport.*

---

## 4. Cleanest STAGED retrofit path

Ordered smallest-shippable-first. Each stage is independently mergeable + soakable.

### Stage 0 — `aspect="expand"` + verify wide-monitor fill (SMALLEST FIRST SHIPPABLE — visibly "fills a big screen")

**Change:** `project.godot` `window/stretch/aspect="keep"` → `"expand"`. One line.

**Effect:** the 16:9 black bars vanish; on a wide window the engine widens the logical viewport (keeps height 720, grows width to match the window aspect), so the camera now sees MORE world horizontally. **Combined with Stage 1's wider bounds, a 21:9 monitor shows ~640+ logical px wide of world instead of a pillarboxed 480.**

**Caveat — order matters.** `expand` ALONE (without wider world content, Stage 1) will reveal void on the sides on a wide monitor, because the world is still only 480 wide. So Stage 0 is the *enabling* change but should ship **paired with Stage 1** (or behind the `?cam_zoom`/a feature flag) so the Sponsor soak shows world, not void. Recommend Stage 0+1 as ONE PR. This is the "smallest first shippable stage that visibly fills a big screen with more world."

**Verification:** HTML5 visual gate applies (stretch policy is renderer-visible). Soak on a wide window: confirm no black side-bars, HUD still anchored (CanvasLayer immunity holds — camera-layer.md § "HUD-not-zoom guarantee" — but `expand` changes the logical viewport size, so re-verify HUD offsets against `PRESET_TOP_RIGHT` anchoring which uses negative offsets).

### Stage 1 — widen S1 rooms to scroll-width + drive bounds from the room

Two viable sub-paths; **1A is the lower-risk first cut.**

- **Stage 1A (hand-authored widen):** widen the S1 chunk(s) from 15×8 tiles to e.g. 30×8 (960×256) or 45×8 (1440×256). Extend `FloorTiles` TileMapLayer, move WallEast, resize wall collision shapes, redistribute mob/gate positions. Change `Main.S1_ROOM_BOUNDS` to match (or read the new size from the chunk_def). The scroll machinery engages automatically once `bounds.size.x > viewport_world.x`. Lowest risk because it reuses the linear `ROOM_SCENE_PATHS` flow — no procgen wiring.

- **Stage 1B (procgen-driven, mirrors S2):** route S1 room loads through `FloorAssembler.assemble_floor(s1_z1_outer_cloister, seed)` + `_render_assembled_floor`, exactly like S2. Bounds come free from `bounding_box_px`. Higher value (random S1 maps per the Diablo-shape directive) but higher risk (S1's tutorial Room01 onboarding gate, RoomGate clears, healing fountain, the boss-room handoff all assume the authored `.tscn` flow). Defer to Stage 3.

**Where the tunable zoom plugs in:** PR #402's `?cam_zoom` is already the dial for "how much world fits." Once the world is wider than the viewport, dialing zoom OUT (normalized < 1.0) now shows MORE WORLD (not void) up to the bounds edge. The Sponsor's eventual locked default zoom (the PR #402 follow-up) becomes the S1 default once Stage 1 lands — this is the natural convergence point.

### Stage 2 — warm floor tiles + player/mob scale calibration (feel pass)

- **Warm floor tiles:** the wider floor needs the S1 cloister tileset (`resources/tilesets/s1_cloister.tres`) extended across the new width — the existing TileMapLayer + warm-sandstone palette (Uma's S1 direction) tiles the new area. This is a content/art-pass surface (Uma + Drew), not engine. It rides on Stage 1's wider chunk geometry.
- **Smaller player/mob scale:** at a wider field-of-view the 16px player reads large. A global sprite-scale reduction (or a zoom-out default) makes the bigger world feel proportionate. This is a **subjective-feel call → Sponsor gate**, tuned via `?cam_zoom` first, then locked. Plugs into the same scale/zoom dial as Stage 1's bounds.

### Stage 3 — procgen S1 (Stage 1B) + per-character random maps

Promote S1 to the S2 assemble_floor flow. Consumes `s1_z1_outer_cloister.tres`, fixes the known `s1_room01` EAST-seam mating gap (procgen-pipeline.md § "Known spike-era finding" — add EAST `&"exit"` port at `(14,4)`), and reconciles the Room01 onboarding gate + RoomGate clears + boss-room handoff with the assembled-floor path. Highest scope; ships the Diablo-shape "randomized maps per character" commitment for S1.

**Recommended first stage: Stage 0 + Stage 1A as ONE PR** — `aspect="expand"` + one hand-widened S1 chunk (e.g. Room02 → 30 tiles wide) + bounds driven from chunk size. This is the minimum that visibly fills a wide screen with real scrolling world, reuses the fully-tested camera-scroll infra, and avoids the procgen-integration risk surface. It is also directly Sponsor-soakable as a feel check for the eventual locked zoom.

---

## 5. Risks / unknowns

| # | Risk | Detail / mitigation |
|---|---|---|
| 1 | **`aspect="expand"` HUD + canvas-resize interaction** | `expand` changes the logical viewport WIDTH on wide windows. HUD CanvasLayers are camera-immune (camera-layer.md), but Controls anchored with negative `PRESET_TOP_RIGHT` offsets (e.g. `Main._build_hud` TopRightContext, `ctx.offset_left = -300`) reposition relative to the widened width — re-verify HUD layout on a wide window. Also re-verify the minimize/restore clobber re-assert (`html5-export.md` § "Canvas resize / minimize-restore") still holds with `expand`. |
| 2 | **Collision perimeter at bigger sizes** | Widening a room means moving WallEast + resizing wall `RectangleShape2D`s (chunk `.tscn`). Mob spawn positions, RoomGate position/size, healing-fountain placement all reference the old 480-wide coords and must be redistributed. A bigger floor with the same mob count feels emptier — balance pass needed (Uma/Drew). |
| 3 | **Procgen vs hand-authored S1 (Stage 1A vs 1B)** | S1's tutorial Room01 onboarding gate (`_room01_awaiting_pickup_equip`, Main 297-301), RoomGate-driven `room_cleared`, and the boss-room handoff all assume authored `.tscn` linear flow. The S2 assemble_floor path does NOT have these. Stage 1B/3 must reconcile both — defer the procgen flow, ship hand-authored widen first. |
| 4 | **Save-compat** | Low risk. Room bounds / chunk geometry are NOT persisted — save stores room INDEX + progression, not geometry. Widening a chunk does not change the save schema. The S1 zone-id discovery hook (`ROOM_INDEX_TO_ZONE_ID`, Main 163) is unchanged (still `s1_z1_outer_cloister`). If Stage 3 adds a per-character `world_seed` for S1 random maps, that rides the existing additive v5 `world_seed` save field (procgen-pipeline.md § "Save-schema binding") — already round-trips. |
| 5 | **HTML5 perf at larger floors** | A wider TileMapLayer + more props + more mobs increases draw + physics load under `gl_compatibility` (WebGL2). Likely fine at 2-3× width (S2 already runs multi-chunk assembled floors), but verify FPS on a release-build soak at the widest target. CPUParticles2D + Area2D counts scale with mob count (combat-architecture.md). |
| 6 | **HTML5 visual-verification gate** | Stage 0 (stretch policy), Stage 1 (camera bounds → scroll → wider viewport reveal), Stage 2 (tiles, scale) are ALL renderer-visible — `html5-export.md` § "HTML5 visual-verification gate" + author-self-soak (test-conventions.md) apply. Z-index at chunk seams is the highest residual render risk (camera-scroll.md § "gl_compatibility risk surface" — wider scroll viewport exposes seam draw-order). Use the spike scene's seam-marker pattern as the regression tell. Sponsor interactive soak is the gate of record for the feel + the wide-monitor fill. |
| 7 | **Tunable-zoom default still unlocked** | PR #402's `?cam_zoom` soak control shipped but the LOCKED default-zoom is a pending Sponsor decision. Stage 1's "more world" is only meaningful once that default is set (a zoom-out default shows the wider world; the current 1.0 default still frames ~480 wide). Sequence: land Stage 0+1A → Sponsor soaks with `?cam_zoom` → lock the default → that becomes the S1 default. |

---

## Cross-references

- `.claude/docs/camera-scroll.md` — `follow_target` + `set_world_bounds` + viewport-aware clamp + spike scene
- `.claude/docs/camera-layer.md` — BASELINE_ZOOM calibration + HUD immunity + minimize/restore clobber
- `.claude/docs/procgen-pipeline.md` — `assemble_floor` + `bounding_box_px` + S2 production consumer (the S1 template)
- `.claude/docs/html5-export.md` — stretch/canvas_resize_policy + visual-verification gate + diag-build pattern
- `scenes/Main.gd` — `_engage_camera_for_room` (~2200), `_render_assembled_floor` (1684), `S1_ROOM_BOUNDS` (213)
- `scripts/camera/CameraDirector.gd` — `_clamp_to_world_bounds` (760), `set_world_bounds` (634), `BASELINE_ZOOM` (158)
- `project.godot` [display] (50-53) — the `aspect="keep"` root cause
- `scenes/levels/chunks/s1_room01_chunk.tscn` — the 480×270 wall/floor box geometry
