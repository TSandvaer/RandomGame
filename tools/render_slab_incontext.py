#!/usr/bin/env python3
"""
IN-CONTEXT JUDGE RENDER for the NEW S1 ashlar slab path (#426 soak-rev).

Per TESTING_BAR.md "judge art in context" + the dispatch brief's judge-first-of-class
gate: compose the NEW slab spine threaded THROUGH the fine cobble field at GAME ZOOM,
with a char_scale=0.48 player-size reference rect, so orch can eyeball the slab-to-
cobble scale step-up + the warm-path-through-cool-cobble contrast + zero-green BEFORE
relying on the full release-build soak. De-risks a 3rd path bounce.

This mirrors the S1YardChunk painter's geometry EXACTLY (same atlas layout, same
block-variant scatter, same period) so the render is a faithful proxy of what the game
paints — NOT a hand-arranged mock. Reads the SHIPPED atlases:
  assets/tilesets/s1_cloister/floor_cobble.png  (cobble base, 768x128 = 6 variants)
  assets/tilesets/s1_cloister/floor_slab.png    (NEW slab,    512x128 = 4 variants)

Output: _yard_render/slab_incontext_judge.png
"""
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
COBBLE = os.path.join(ROOT, "assets/tilesets/s1_cloister/floor_cobble.png")
SLAB = os.path.join(ROOT, "assets/tilesets/s1_cloister/floor_slab.png")
OUT = os.path.join(ROOT, "_yard_render", "slab_incontext_judge.png")

TILE = 32              # game tile px
COBBLE_VARIANTS = 6
SLAB_VARIANTS = 4
BLOCK = 4             # 4x4 game tiles per variant-block
COBBLE_SEED = 1763   # matches S1YardChunk.cobble_seed

# Render a region of the yard around the spine: cols 0..GW, rows 6..18 (the spine band).
GW = 40
ROW0, ROW1 = 6, 19   # rows to render (the spine dips around row 12-15)
ZOOM = 2             # game-zoom view multiplier for judging


def load_atlas(path, variants):
    """Return a (variants, 4, 4) array of 32x32 RGB cells from a packed atlas PNG."""
    img = np.asarray(Image.open(path).convert("RGB"))
    cells = np.empty((variants, 4, 4, TILE, TILE, 3), np.uint8)
    for v in range(variants):
        for by in range(4):
            for bx in range(4):
                x0 = (v * 4 + bx) * TILE
                y0 = by * TILE
                cells[v, by, bx] = img[y0:y0 + TILE, x0:x0 + TILE]
    return cells


def absi(x):
    return abs(int(x))


def cobble_block_variant(bx, by):
    h = (bx * 73856093) ^ (by * 19349663) ^ (COBBLE_SEED * 83492791)
    return absi(h) % COBBLE_VARIANTS


def slab_block_variant(bx, by):
    h = (bx * 49979693) ^ (by * 86028157) ^ (COBBLE_SEED * 6151)
    return absi(h) % SLAB_VARIANTS


def spine_center_row(tx):
    """Mirror S1YardChunk._spine_center_row: gentle south dip across the mid-yard."""
    import math
    t = tx / max(GW - 1, 1)
    dip = math.sin(t * math.pi) * 3.0
    return 12 + int(round(dip))


def is_slab_cell(tx, ty):
    """Mirror the spine portion of S1YardChunk._compute_slab_cells (2-wide ribbon).
    (The building-link + well-apron spurs are omitted from this judge crop — the spine
    is what threads through the open cobble and is the read we're judging.)"""
    cr = spine_center_row(tx)
    return ty == cr or ty == cr + 1


def main():
    cob = load_atlas(COBBLE, COBBLE_VARIANTS)
    slab = load_atlas(SLAB, SLAB_VARIANTS)

    rows = ROW1 - ROW0
    canvas = np.empty((rows * TILE, GW * TILE, 3), np.uint8)
    for ty in range(ROW0, ROW1):
        for tx in range(GW):
            if is_slab_cell(tx, ty):
                v = slab_block_variant(tx // BLOCK, ty // BLOCK)
                cell = slab[v, ty % BLOCK, tx % BLOCK]
            else:
                v = cobble_block_variant(tx // BLOCK, ty // BLOCK)
                cell = cob[v, ty % BLOCK, tx % BLOCK]
            ry = (ty - ROW0) * TILE
            rx = tx * TILE
            canvas[ry:ry + TILE, rx:rx + TILE] = cell

    img = Image.fromarray(canvas).resize(
        (canvas.shape[1] * ZOOM, canvas.shape[0] * ZOOM), Image.NEAREST
    )
    draw = ImageDraw.Draw(img)

    # char_scale=0.48 player reference. The player sprite is ~46px native; at 0.48 it
    # renders ~22px wide x ~38px tall (matching the cobble generator's player-ref math
    # at the 0.48 production default). Draw it ON the spine so the slab-paver-to-player
    # ratio is directly judgeable (a paver should read "a stone you could stand on",
    # not player-sized).
    pw, ph = int(22 * ZOOM), int(38 * ZOOM)
    # place it on the spine near the west third
    spine_y = (spine_center_row(10) - ROW0) * TILE * ZOOM
    px, py = 10 * TILE * ZOOM, spine_y - ph + TILE * ZOOM
    draw.rectangle([px, py, px + pw, py + ph], outline=(255, 80, 40), width=2)
    draw.text((px, max(2, py - 14)), "player ~0.48", fill=(255, 130, 70))
    draw.text((6, 6), "NEW ashlar slab spine threading fine cobble @ game zoom (2x)",
              fill=(255, 235, 200))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"[judge] in-context slab render -> {OUT} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
