# Cainos grass↔stone-path corner map — derivation record

Source: `assets/tilesets/cainos/tx_tileset_grass.png` (256×256 = 8×8 cells @ 32px).

The grass sheet packs, in rows 4–7 cols 0–7, a **stone-path-in-grass Wang block** —
cobble path tiles with grass edges. To drive Godot's corner-match (MATCH_CORNERS)
autotiler, each cell needs its 4 corners tagged as grass (terrain 0) or
stone_path (terrain 1).

The map in `build_cainos_tileset.gd` `PATH_CORNERS` was derived empirically by
classifying each 16×16 corner-quadrant of every cell as grass vs stone, using the
**blue channel** as the discriminator (cobble ≈ `(128,127,114)` blue≈114; olive
grass ≈ `(114,117,27)` blue≈27 — a clean split at blue>55). Result (S=path, G=grass,
[TL TR BL BR] per cell):

```
row4: 0:SSSS 1:SSSS 2:GSGS 3:SGSG 4:GGSS 5:GGSS 6:GGSS 7:GGSS
row5: 0:SSSS 1:SSSS 2:GSGS 3:SGSG 4:SSGG 5:SSGG 6:SSGG 7:SSGG
row6: 0:SSSS 1:SSSS 2:GSGS 3:SGSG 4:SGGG 5:GSGG 6:GGSG 7:GGGS
row7: 0:SSGG 1:SSGS 2:GSGG 3:SGSG 4:GSSS 5:SGSS 6:GGGG 7:GGGG
```

Cells in rows 0–3 are pure-grass field variants → all corners grass (terrain 0);
the builder defaults any cell not in `PATH_CORNERS` to all-grass.

`PATH_CORNERS` selects a clean, non-redundant subset that gives the autotiler one
tile for each needed corner pattern (solid fill, the 4 sides, the 4 outer corners,
the 2 inner corners). If a blend looks wrong while painting, the fix is to add/swap
a cell here and re-run `build_cainos_tileset.gd` — do NOT hand-edit the generated
`.tres` (the peering bits drop; see `procgen-pipeline.md`).

Re-derive command (one-off, not committed as a tool):
```python
from PIL import Image
im = Image.open('assets/tilesets/cainos/tx_tileset_grass.png').convert('RGBA')
def corner(cx,cy):
    out=[]
    for ox,oy in [(0,0),(16,0),(0,16),(16,16)]:
        s=g=0
        for dy in range(16):
            for dx in range(16):
                p=im.getpixel((cx*32+ox+dx,cy*32+oy+dy))
                if p[3]<30: continue
                (s:=s+1) if p[2]>55 else (g:=g+1)
        out.append('S' if s>g else 'G')
    return ''.join(out)
```
