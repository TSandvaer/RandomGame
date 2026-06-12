# Godot Headless Tooling

Covers scripted, editor-free Godot operations useful for agent-side automation: bulk TileMap
painting, re-saving scenes, and the import precondition that must run first.

## Binary path (validated 2026-06-10)

```
C:\Users\538252\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe
```

Godot version: 4.6.3-stable. (Discoverable via `Get-Process` while the Sponsor's editor runs.)

## Canonical invocation

```powershell
# Import pass (run once before any --script pass on a fresh project copy)
& "<binary>" --headless --path "C:/Trunk/PRIVATE/RandomGame" --import

# Script pass
& "<binary>" --headless --path "C:/Trunk/PRIVATE/RandomGame" --script "res://tools/your_script.gd"
```

Use forward-slash paths inside `--path` / `res://` arguments (Windows backslashes are stripped
by the shell as escape sequences — see `bash-windows-path-escapes` memory entry).

## Pattern 1 — TileMap paint + re-save

Load a `.tscn`, mutate `TileMapLayer` cells, pack and save back to the same `res://` path.

```gdscript
# tools/paint_cells.gd
extends SceneTree

func _init() -> void:
    var packed: PackedScene = load("res://scenes/levels/your_level.tscn")
    var root: Node = packed.instantiate()
    var layer: TileMapLayer = root.get_node("YourTileMapLayer")
    var ts: TileSet = layer.tile_set

    # Resolve source id (use explicit type — see Pattern 3)
    var sid: int = ts.get_source_id(0)

    # Paint cells
    for y in range(16):
        for x in range(16):
            layer.set_cell(Vector2i(x, y), sid, Vector2i.ZERO, 0)

    var out: PackedScene = PackedScene.new()
    var pack_err: int = out.pack(root)
    var save_err: int = ResourceSaver.save(out, "res://scenes/levels/your_level.tscn")
    print("pack_err=%d save_err=%d" % [pack_err, save_err])
    # Success signal: pack_err=0 and save_err=0 in printed output.
    # Do NOT rely on process exit code — headless runs may exit non-zero on unrelated stderr.

    quit()
```

To clear instead of paint, call `layer.clear()` before packing. Validated: 1353 cells painted
on one run, then cleared (1353 → 0) on a second run; pack_err=0 save_err=0 both times; scene
reloaded correctly in the editor.

**Re-save side-effect:** `ResourceSaver.save` rewrites the `.tscn` in Godot's canonical text
format (format=4, unique_id attrs). All `; comment` lines in the original file are stripped.
Never put load-bearing comments in a `.tscn` that will be programmatically re-saved; treat the
re-saved file as authoritative.

## Pattern 2 — `--import` precondition

Never-imported PNGs (assets not yet in `.godot/imported/`) cause `--script` to fail with:

```
ERROR: No loader found for resource: res://assets/....png (expected type: Texture2D)
ERROR: [ext_resource] referenced non-existent resource ...
```

**Fix:** run `--headless --path <project> --import` once first. This is the agent-side
equivalent of the editor's "Reload Current Project" import pass. See also
`orchestration-overview.md` § Sponsor's design worktree → Import-order wrinkle for the
editor-side sibling of this problem.

## Pattern 3 — type-inference trap

```gdscript
# WRONG — parse error: "Cannot infer the type of 'sid' variable"
var sid := ts.get_source_id(i)

# CORRECT
var sid: int = ts.get_source_id(i)
```

This is a **parse error**: the script never starts. The engine prints the error before
`_init` runs. Prefer explicit type annotations throughout agent-authored headless scripts.

## Pattern 4 — cold-start noise (do not mistake for breakage)

On the first headless run against a project (before `--import` has been run or the cache is
cold), the engine prints class_name cross-reference errors such as:

```
ERROR: Could not find type "QuestState" in the current scope (QuestActionRouter.gd)
ERROR: Failed to instantiate an autoload, ...
```

These disappear after `--import` or on a warm-cache run. **Important:** in observed runs the
autoloads genuinely fail to instantiate during that cold run, but a script that does not
depend on those autoloads still completes its own `_init` work correctly. The verified
success signal is the script's own print output (`pack_err=0 save_err=0`), not the absence of
engine-bootstrap stderr.

## Pattern 5 — isometric terrain-set .tres wiring (hand-generated, validated 2026-06-10)

Godot 4 terrain auto-tiling for an isometric TileSet can be wired entirely by generating
the `.tres` (format 3) from a script — validated by `assets/iso_proof/make_iso_transitions.py`
(generates the full TileSet: 4 materials + 6×14 transition tiles). Key format facts:

```
[resource]
terrain_set_0/mode = 2                       # MATCH_SIDES
terrain_set_0/terrain_0/name = "grass"       # one name+color pair per terrain
terrain_set_0/terrain_0/color = Color(0.35, 0.55, 0.3, 1)

# per tile (inside the TileSetAtlasSource sub_resource):
<col>:0/0 = 0
<col>:0/0/terrain_set = 0
<col>:0/0/terrain = <terrain_index>          # the tile's center terrain
<col>:0/0/terrains_peering_bit/top_right_side = <terrain_index>     # screen NE edge
<col>:0/0/terrains_peering_bit/bottom_right_side = <terrain_index>  # screen SE edge
<col>:0/0/terrains_peering_bit/bottom_left_side = <terrain_index>   # screen SW edge
<col>:0/0/terrains_peering_bit/top_left_side = <terrain_index>      # screen NW edge
```

- **Iso side key names are the corner-direction `*_side` names** (`top_right_side` etc.),
  matching the diamond's NE/SE/SW/NW screen edges — not the square-shape `right_side`/
  `top_side` names.
- **Variant auto-scatter for free:** give EVERY variant of a pure material full peering bits
  (all 4 sides = its terrain). Terrain-paint then picks randomly among the matching variants —
  replaces the manual Scatter/dice workflow entirely.
- Existing painted cells are untouched by adding terrain metadata: source ids, atlas coords
  and alternatives are unchanged; terrain data is additive per-tile metadata.
- **NEVER renumber existing source ids when the material set grows.** Painted cells store
  `(source_id, atlas_coords)` — renumbering repoints every painted cell at the wrong source
  (near-miss 2026-06-11: appending a 5th material would have shifted the 6 pair-sources from
  4..9 to 5..14, corrupting all painted transition cells). Convention: new materials and new
  pair-atlases append at FRESH ids (5th material → 10, its pairs → 11..14; original pairs keep
  4..9); the generator (`make_iso_transitions.py`) carries an explicit `PAIR_IDS` stable map
  rather than computing ids from enumeration order. Variant-count GROWTH within an existing
  source is safe (painted coords stay valid); shrinkage or reorder is not.

## Pattern 6 — `set_cells_terrain_connect` erases rim cells unless `ignore_empty_terrains=false` (Godot 4.6.3)

Observed headless (and codified in the repo-root check script `_check_iso_terrain.gd`):

```gdscript
layer.set_cells_terrain_connect(cells, 0, terrain)         # default ignore_empty_terrains
# → painting a 12×6 region kept only the 40 interior cells; ALL 32 rim cells
#   (every cell bordering empty space) were ERASED. Diagnostic signature: survivors
#   = exactly the region interior.

layer.set_cells_terrain_connect(cells, 0, terrain, false)  # explicit false
# → all 72/72 cells painted AND transition tiles still auto-selected at material
#   borders (18 transition tiles across a grass/dirt boundary in the same test).
```

Always pass `false` explicitly in scripted terrain painting. (Why `true` — the documented
default — erases rim cells is unexplained; the doc text suggests the opposite. Observed
behavior wins.) Editor-side implication for the level designer: if terrain strokes bordering
empty cells vanish while painting, lay a full one-material base first, then carve other
materials on top — material-on-material always resolves.

Functional check pattern (from `_check_iso_terrain.gd`): build a `TileMapLayer` in a
`SceneTree` `--script`, assign the TileSet, `set_cells_terrain_connect` two adjacent
regions with different terrains, then assert `get_used_cells()` count equals the request
AND at least one cell's `get_cell_source_id()` is a transition atlas source.

## Pattern 7 — drag-and-drop building-prop scenes (base-origin + footprint collision, validated 2026-06-10)

Building sprites for the Sponsor's editor composition ship as one `.tscn` per building
(generated from Python, `scenes/levels/demo/buildings/*.tscn`), so placement is drag-onto-
`Structures`-node with depth-sorting and collision already working:

```
[node name="<Name>" type="StaticBody2D"]            # root = the y-sorted, colliding unit

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("1_tex")
centered = false
offset = Vector2(-w/2, -(h-10))                     # node ORIGIN = bottom-center ground line, 10px inset

[node name="Footprint" type="CollisionPolygon2D" parent="."]
polygon = PackedVector2Array(0,0, 0.4w,-0.2w, 0,-0.4w, -0.4w,-0.2w)   # iso diamond heuristic
```

- **Base-origin convention is load-bearing for y-sort:** the parent container
  (`Structures`) has `y_sort_enabled=true`; nodes sort by `position.y`, so the origin must
  sit at the ground-contact line (matches the existing iso_proof Building: offset
  `(-151,-255)` on a 302×265 sprite = same formula).
- Footprint diamond (`±0.4w` half-width, `0.2w` half-height, bottom tip at origin) is a
  heuristic — good default, Sponsor-tunable per building in the editor.
- Headless verification pattern (`_check_buildings.gd`): load each PackedScene, instantiate,
  assert root class + `Sprite.texture != null` + `Footprint.polygon.size() == 4`.
- **D2-style occlusion fade** ships in the same scene via a shared root script
  (`scripts/levels/BuildingFade.gd`): at `_ready` it auto-builds an `Area2D` zone from the
  sprite's dimensions (band `x ∈ ±0.45w`, `y ∈ [−0.80h, −0.10h]` — the wall region that
  would draw over an entity behind it) and tweens `Sprite.modulate:a` to 0.45 on
  `body_entered` (CharacterBody2D), back to 1.0 when the last body exits. Walking "into" a
  building reads as entering instead of vanishing under the wall.
- **Headless `--script` never fires `_ready`** — the main loop never starts, so nodes added
  to the root during a `SceneTree._init` check do NOT get `_ready` (a correct
  `_ready`-builds-children script will false-FAIL verification). Invoke `node._ready()`
  explicitly in the check after `add_child` when asserting on `_ready`-created children
  (`_check_fade.gd` pattern).

## Cross-references

- `orchestration-overview.md` § Sponsor's design worktree — Import-order wrinkle (editor-side sibling of Pattern 2)
- `pixellab-pipeline.md` § Scripted iso TRANSITION tiles — the mask construction whose output Pattern 5 wires into the terrain set
- `pixellab-pipeline.md` § Multi-gen building SETS — palette harmonization for the sprites Pattern 7 wraps into scenes
- Memory entry `bash-windows-path-escapes` — Windows path quoting in Bash/PowerShell
