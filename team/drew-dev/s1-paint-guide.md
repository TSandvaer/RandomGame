# Painting the S1 yard in the Godot editor — how-to (Sponsor)

This is the new workflow: **you** design + paint S1 in the Godot editor using the
sourced Cainos tileset, with real-time in-engine feedback. The team set up a
paintable scene, a tileset with autotiling, and a prop palette — the level itself
is yours to compose.

Everything is 32px and uses the Cainos "Pixel Art Top Down – Basic" pack.

---

## 1. Open the scene

In the Godot editor (FileSystem dock, bottom-left), open:

> `scenes/levels/s1_yard_authored.tscn`

It opens with a small **starter patch** already painted — a grass field with a
stone-path strip running through it — plus a Player and a follow-camera. That
starter patch is just to prove it works; erase/extend it however you like.

The Scene tree (top-left) shows:

- **Ground** — the autotiling grass↔stone-path layer (paint here most of the time)
- **StoneGround** — a layer for the solid stone-slab courtyard floor
- **Walls** — a layer for brick walls
- **Props** — a container for free-placed prop sprites (buildings, braziers, …)
- **Player** — where you spawn (drag it to move the spawn point)

---

## 2. Paint the ground (the autotile magic)

1. Click the **Ground** node in the Scene tree.
2. A **TileMap** panel appears at the bottom of the editor. Click the
   **Terrains** tab (next to "Tiles").
3. You'll see two terrains: **grass** and **stone_path**.
4. Pick **grass**, then paint (left-drag) a big area — that's your yard floor.
5. Pick **stone_path** and draw a path/courtyard ON TOP of the grass. The edges
   **auto-blend** — Godot picks the right grass↔cobble transition tile for every
   cell automatically. Draw freely; the blend follows.
6. Right-drag (or pick the eraser) to remove cells.

> Tip: if you want a plain grass field with no path, just paint grass everywhere.
> If you want a stone courtyard, paint stone_path in a block — it fills solid in
> the middle and blends at the edges.

### Solid stone slabs / walls

- **StoneGround** layer → **Tiles** tab → pick a stone slab tile → paint. Good
  for a hard courtyard floor distinct from the cobble path.
- **Walls** layer → **Tiles** tab → pick brick wall pieces → paint your building
  outlines / yard perimeter.

(StoneGround and Walls are plain tile-painting — no terrain auto-blend. Just pick
a tile and stamp it.)

---

## 3. Place buildings + props

Two ways:

### A. Copy from the prop palette (best for buildings + big landmarks)

1. Open `scenes/levels/s1_prop_palette.tscn` — a tray of every placeable prop
   with name labels. Two groups:
   - **TOP ROW = the 5 BUILDING landmarks** (warm-sandstone PixelLab buildings,
     from `assets/props/s1_yard/`): **ChapelBelltower**, **CloisterCentral** (lit
     ember window), **DormitoryRuinLeft**, **DormitoryRuinRight**,
     **OutbuildingFar**. These are the real yard landmarks — place them first to
     frame the space.
   - **Below = DECORATION props** (smaller, from `assets/props/s1_cloister/`):
     pillars, braziers, banners, rubble, parchment — plus a few Cainos props
     (barrel, crate, signpost, gravestone, statue). Dress the yard with these
     around the buildings.
2. In its Scene tree, click the prop you want (e.g. **ChapelBelltower**), press
   **Ctrl+C**.
3. Switch back to `s1_yard_authored.tscn`, click the **Props** node, press
   **Ctrl+V**.
4. The prop appears — drag it where you want it. Scale/rotate in the Inspector
   (right panel) if needed.

### B. Drag a texture straight in

1. In the FileSystem dock, browse `assets/props/s1_yard/` (the 5 BUILDING
   landmarks), `assets/props/s1_cloister/` (the smaller decoration props), or
   `assets/tilesets/cainos/` (the Cainos sheets).
2. Drag a `.png` onto the **Props** node in the Scene tree → choose **Sprite2D**.
3. Position it. For the Cainos prop SHEETS (tx_props/tx_plant/tx_struct), set the
   Sprite2D's **Region → Enabled** and drag a region box over the single prop you
   want (each sheet packs many props).

> The Cainos props/plant/struct sheets are ALSO available as paintable tiles on a
> TileMapLayer (sources in the tileset) if you'd rather stamp them like ground —
> but for big landmark objects, free-placed Sprite2Ds read better.

---

## 4. Save + run to see it live

- **Save:** Ctrl+S.
- **Run the scene:** press **F6** (Play Current Scene) — NOT F5 (F5 runs the whole
  game from Main.tscn). You'll spawn as the Player and can walk (WASD) around the
  yard you painted; the camera follows.
- When it looks right, that's your S1 yard. (Wiring the authored map into the live
  game flow is a follow-up the team handles — your job is the look.)

---

## What's where (reference)

| Thing | Path |
|---|---|
| Paintable scene | `scenes/levels/s1_yard_authored.tscn` |
| Prop palette | `scenes/levels/s1_prop_palette.tscn` |
| Cainos tileset | `resources/tilesets/cainos_s1.tres` |
| Cainos textures | `assets/tilesets/cainos/` |
| 5 BUILDING landmarks (chapel / central / 2 dormitory ruins / outbuilding) | `assets/props/s1_yard/` |
| Decoration props (pillars / braziers / banners / rubble / parchment) | `assets/props/s1_cloister/` |

If you want more terrains (e.g. a dirt↔grass blend, water edges), or more props
pre-sliced into the palette, just ask — the team adds them to the tileset/palette
and you keep painting.

---

## Maintenance note — Godot version + the corner terrain (team)

`cainos_s1.tres` is a **generated** resource — do NOT hand-edit it. The corner
peering bits (the grass↔stone-path auto-blend) silently drop or go malformed if
the `.tres` is hand-authored, and the serialization is **engine-version-sensitive**:
a tileset built under one Godot version can trip the next version's stricter
`is_valid_terrain_peering_bit` validation.

It was regenerated for **Godot 4.6.3** (ticket 86ca67aj0; the original 4.3 build,
#432, was malformed for 4.6's terrain system and SIGSEGV'd the headless suite).
If a future engine bump breaks the autotile again, the fix is to **re-run the
builder on the new engine**, not to edit the `.tres`:

```
<godot-4.x-binary> --headless --path . --script res://tools/build_cainos_tileset.gd
```

The corner-quadrant classification lives in `tools/build_cainos_tileset.gd`
(`PATH_CORNERS`) + `tools/_cainos_corner_map.md`; `tests/test_cainos_tileset.gd`
pins the peering-bit count + the scene-opens gate. Note: the excluded notch cells
(6,7)/(7,7) carry `terrain_set == -1` — any code that loops all tiles reading
corner bits must guard `terrain_set >= 0` first or 4.6 raises a peering-bit error.
