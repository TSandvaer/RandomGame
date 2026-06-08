#!/usr/bin/env python3
"""
IN-CONTEXT JUDGE RENDER for the v3 HAND-PLACED STRUCTURED S1 GROUND (86ca5hwmx,
render-first gate, Sponsor 2026-06-08 "no structure ... just chaos" 4th bounce).

v3 DROPS the v2 procedural SCATTER (noise-grass across the whole grid + 5 mid-field
cobble patches → read as chaos). It HAND-PLACES every material to match the references
(Graveyard Keeper 11h18_12 + Stardew 11h19_36): a SMOOTH continuous dirt base field,
ONE clear deliberate fine-cobble PATH lane, GRASS only at the outer edges/corners.

This mirrors the S1YardChunk painter's v3 geometry EXACTLY (same continuous dirt-field
addressing, same hand-placed grass_regions + feathered border, same well apron, same
3-wide lane geometry) so the render is a faithful proxy of what the game paints — NOT a
hand mock. Reads the SHIPPED atlases:
  assets/tilesets/s1_cloister/floor_dirt.png   (dirt field,     768x128 = 6 variants)
  assets/tilesets/s1_cloister/floor_grass.png  (grass regions,  768x128 = 6 variants)
  assets/tilesets/s1_cloister/floor_cobble.png (well apron,     768x128 = 6 variants)
  assets/tilesets/s1_cloister/floor_path.png   (fine-cobble lane,768x128 = 6 variants)

Output: _yard_render/yard_ground_v3_judge.png
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
ATL = os.path.join(ROOT, "assets/tilesets/s1_cloister")
OUT = os.path.join(ROOT, "_yard_render", "yard_ground_v3_judge.png")

TILE = 32
VARIANTS = 6
BLOCK = 4
COBBLE_SEED = 1763   # matches S1YardChunk.cobble_seed
GRASS_SEED = 2207    # matches S1YardChunk.grass_seed
DIRT_FIELD_VARIANT = 0   # matches S1YardChunk.DIRT_FIELD_VARIANT
GRASS_FIELD_VARIANT = 0  # matches S1YardChunk.GRASS_FIELD_VARIANT

GW, GH = 40, 24
ZOOM = 2

# Mirror S1YardChunk.building_footprints (lane guard + brick overlay).
BUILDINGS = [(8, 0, 12, 3), (6, 21, 14, 3), (18, 9, 6, 5), (33, 6, 3, 3)]
# Mirror S1YardChunk.grass_regions (v3 hand-placed edge/corner grass).
GRASS_REGIONS = [
    (0, 0, 7, 6), (33, 0, 7, 5), (0, 18, 9, 6),
    (34, 19, 6, 5), (20, 0, 10, 2), (22, 22, 11, 2),
]
# Mirror S1YardChunk.well_footprint + well_apron.
WELL = (20, 16, 2, 2)
WELL_APRON = (19, 15, 4, 4)


def load_atlas(name):
    img = np.asarray(Image.open(os.path.join(ATL, name)).convert("RGB"))
    cells = np.empty((VARIANTS, 4, 4, TILE, TILE, 3), np.uint8)
    for v in range(VARIANTS):
        for by in range(4):
            for bx in range(4):
                x0 = (v * 4 + bx) * TILE
                y0 = by * TILE
                cells[v, by, bx] = img[y0:y0 + TILE, x0:x0 + TILE]
    return cells


def absi(x):
    return abs(int(x))


def block_variant(bx, by):  # mirror _block_variant (cobble apron)
    h = (bx * 73856093) ^ (by * 19349663) ^ (COBBLE_SEED * 83492791)
    return absi(h) % VARIANTS


def path_block_variant(bx, by):  # mirror _path_block_variant
    h = (bx * 49979693) ^ (by * 86028157) ^ (COBBLE_SEED * 6151)
    return absi(h) % VARIANTS


def in_rect(tx, ty, rect):
    x, y, w, h = rect
    return x <= tx < x + w and y <= ty < y + h


def fine_dither(tx, ty):  # mirror _fine_dither
    h = ((tx * 2654435761) ^ (ty * 40503) ^ (GRASS_SEED * 2246822519)) & 0x7fffffff
    return (h % 1000) / 1000.0


def is_grass_cell(tx, ty):  # mirror _is_grass_cell (v3 hand-placed regions)
    for region in GRASS_REGIONS:
        if not in_rect(tx, ty, region):
            continue
        rx, ry, rw, rh = region
        on_ring = tx == rx or tx == rx + rw - 1 or ty == ry or ty == ry + rh - 1
        if on_ring:
            return fine_dither(tx, ty) < 0.55
        return True
    return False


def spine_center_row(tx):  # mirror _spine_center_row
    t = tx / max(GW - 1, 1)
    dip = math.sin(t * math.pi) * 3.0
    return 12 + int(round(dip))


def lane_cells():  # mirror _compute_lane_cells (v3 3-wide spine + well spur)
    cells = set()

    def add(tx, ty):
        if tx < 0 or tx >= GW or ty < 0 or ty >= GH:
            return
        for b in BUILDINGS:
            if in_rect(tx, ty, b):
                return
        if in_rect(tx, ty, WELL):
            return
        cells.add((tx, ty))

    for tx in range(GW):
        cr = spine_center_row(tx)
        for dy in (-1, 0, 1):  # 3-wide legible lane
            add(tx, cr + dy)
    spur_x = WELL[0] + 1
    spur_top = spine_center_row(spur_x) + 1
    for ty in range(spur_top, WELL_APRON[1]):
        add(spur_x, ty)
    return cells


def dirt_coords(tx, ty):  # mirror _dirt_atlas_coords (continuous wrap, no block seam)
    return (DIRT_FIELD_VARIANT, ty % BLOCK, tx % BLOCK)


def main():
    dirt = load_atlas("floor_dirt.png")
    grass = load_atlas("floor_grass.png")
    cobble = load_atlas("floor_cobble.png")
    path = load_atlas("floor_path.png")

    lanes = lane_cells()
    canvas = np.empty((GH * TILE, GW * TILE, 3), np.uint8)
    for ty in range(GH):
        for tx in range(GW):
            if (tx, ty) in lanes:
                v = path_block_variant(tx // BLOCK, ty // BLOCK)
                cell = path[v, ty % BLOCK, tx % BLOCK]
            elif in_rect(tx, ty, WELL_APRON) and not in_rect(tx, ty, WELL):
                v = block_variant(tx // BLOCK, ty // BLOCK)
                cell = cobble[v, ty % BLOCK, tx % BLOCK]
            elif is_grass_cell(tx, ty):
                cell = grass[GRASS_FIELD_VARIANT, ty % BLOCK, tx % BLOCK]
            else:
                gv, gy, gx = dirt_coords(tx, ty)
                cell = dirt[gv, gy, gx]
            canvas[ty * TILE:(ty + 1) * TILE, tx * TILE:(tx + 1) * TILE] = cell

    img = Image.fromarray(canvas).resize(
        (canvas.shape[1] * ZOOM, canvas.shape[0] * ZOOM), Image.NEAREST
    )
    draw = ImageDraw.Draw(img)

    # char_scale=0.48 player ref (~22x38 source px) ON the lane near the west third, +
    # a 0.552 mob ref (15% bigger, MOB_SCALE_FACTOR) a few tiles east on the dirt.
    pw, ph = int(22 * ZOOM), int(38 * ZOOM)
    spine_y = (spine_center_row(10)) * TILE * ZOOM
    px, py = 10 * TILE * ZOOM, spine_y - ph + TILE * ZOOM
    draw.rectangle([px, py, px + pw, py + ph], outline=(255, 80, 40), width=2)
    draw.text((px, max(2, py - 14)), "player ~0.48", fill=(255, 130, 70))
    mw, mh = int(25 * ZOOM), int(44 * ZOOM)  # ~0.552 (15% bigger)
    mx, my = 16 * TILE * ZOOM, py - 6
    draw.rectangle([mx, my, mx + mw, my + mh], outline=(80, 160, 255), width=2)
    draw.text((mx, max(2, my - 14)), "mob ~0.552", fill=(120, 180, 255))
    draw.text((6, 6),
              "v3 STRUCTURED: smooth dirt field + ONE clear fine-cobble LANE + grass at EDGES @ game zoom (2x)",
              fill=(255, 235, 200))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"[judge] in-context v3 yard-ground render -> {OUT} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
