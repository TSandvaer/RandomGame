#!/usr/bin/env python3
"""
IN-CONTEXT JUDGE RENDER for the v2 S1 GROUND COMPOSITION (86ca5hwmx, render-first gate).

After the ashlar slab path was soak-rejected a THIRD time, the ground + path were
re-specced (Uma s1-ground-composition-v2.md): the path is FINE-COBBLE pavers and the
ground is VARIED (worn DIRT majority + GRASS reclamation patches + COBBLE patches + the
fine-cobble lane). Per the dispatch brief's MANDATORY render-first gate, this composes
the FULL varied ground at game zoom with a char_scale=0.48 player + a 0.552 mob
reference, so the composition can be hard-judged against the 13 inspiration images
BEFORE any soak. De-risks a 4th bounce.

This mirrors the S1YardChunk painter's geometry EXACTLY (same atlas layout, same
block-variant scatter, same grass-noise placement, same lane geometry, same cobble-patch
footprints) so the render is a faithful proxy of what the game paints — NOT a hand mock.
Reads the SHIPPED atlases:
  assets/tilesets/s1_cloister/floor_dirt.png   (dirt majority,  768x128 = 6 variants)
  assets/tilesets/s1_cloister/floor_grass.png  (grass patches,  768x128 = 6 variants)
  assets/tilesets/s1_cloister/floor_cobble.png (cobble patches, 768x128 = 6 variants)
  assets/tilesets/s1_cloister/floor_path.png   (fine-cobble lane,768x128 = 6 variants)

Output: _yard_render/yard_ground_v2_judge.png
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
ATL = os.path.join(ROOT, "assets/tilesets/s1_cloister")
OUT = os.path.join(ROOT, "_yard_render", "yard_ground_v2_judge.png")

TILE = 32
VARIANTS = 6
BLOCK = 4
COBBLE_SEED = 1763   # matches S1YardChunk.cobble_seed
GRASS_SEED = 2207    # matches S1YardChunk.grass_seed

GW, GH = 40, 24
ZOOM = 2

# Mirror S1YardChunk.building_footprints (for grass south-base boost + lane guard).
BUILDINGS = [(8, 0, 12, 3), (6, 21, 14, 3), (18, 9, 6, 5), (33, 6, 3, 3)]
# Mirror S1YardChunk.cobble_patches.
COBBLE_PATCHES = [(15, 14, 10, 5), (24, 8, 5, 6), (1, 8, 5, 8), (8, 3, 7, 4), (30, 9, 6, 6)]
# Mirror S1YardChunk.well_footprint.
WELL = (20, 16, 2, 2)


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


def block_variant(bx, by):  # mirror _block_variant (ground)
    h = (bx * 73856093) ^ (by * 19349663) ^ (COBBLE_SEED * 83492791)
    return absi(h) % VARIANTS


def path_block_variant(bx, by):  # mirror _path_block_variant
    h = (bx * 49979693) ^ (by * 86028157) ^ (COBBLE_SEED * 6151)
    return absi(h) % VARIANTS


def in_rect(tx, ty, rect):
    x, y, w, h = rect
    return x <= tx < x + w and y <= ty < y + h


def _lattice(lx, ly):  # mirror _lattice
    h = ((lx * 374761393) ^ (ly * 668265263) ^ (GRASS_SEED * 1442695041)) & 0x7fffffff
    return (h % 1000) / 1000.0


def grass_blob(tx, ty):  # mirror _grass_blob
    period = 5.0
    gx = tx / period
    gy = ty / period
    x0 = math.floor(gx)
    y0 = math.floor(gy)
    fx = gx - x0
    fy = gy - y0
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    c00 = _lattice(x0, y0)
    c10 = _lattice(x0 + 1, y0)
    c01 = _lattice(x0, y0 + 1)
    c11 = _lattice(x0 + 1, y0 + 1)
    top = c00 * (1 - fx) + c10 * fx
    bot = c01 * (1 - fx) + c11 * fx
    return top * (1 - fy) + bot * fy


def reclamation_pull(tx, ty):  # mirror _reclamation_pull
    pull = 0.0
    ex = 1.0 - min(tx, GW - 1 - tx) / (GW * 0.5)
    ey = 1.0 - min(ty, GH - 1 - ty) / (GH * 0.5)
    pull += 0.14 * (ex * ey)
    for (bx, by, bw, bh) in BUILDINGS:
        base_y = by + bh
        if base_y <= ty <= base_y + 1 and bx <= tx < bx + bw:
            pull += 0.16
    if tx <= 9 and ty >= GH - 6:
        pull += 0.14
    return pull


def fine_dither(tx, ty):  # mirror _fine_dither
    h = ((tx * 2654435761) ^ (ty * 40503) ^ (GRASS_SEED * 2246822519)) & 0x7fffffff
    return (h % 1000) / 1000.0


def is_grass_cell(tx, ty):  # mirror _is_grass_cell
    field = grass_blob(tx, ty) + reclamation_pull(tx, ty)
    thresh = 0.72
    band = 0.05
    if abs(field - thresh) < band:
        d = fine_dither(tx, ty)
        bias = (field - (thresh - band)) / (2.0 * band)
        return d < bias
    return field > thresh


def ground_class(tx, ty):  # mirror _ground_class_for: 0=cobble,4=grass,3=dirt
    for p in COBBLE_PATCHES:
        if in_rect(tx, ty, p):
            px, py, pw, ph = p
            on_ring = tx == px or tx == px + pw - 1 or ty == py or ty == py + ph - 1
            if on_ring and fine_dither(tx, ty) < 0.42:
                return 4 if is_grass_cell(tx, ty) else 3
            return 0
    if is_grass_cell(tx, ty):
        return 4
    return 3


def spine_center_row(tx):  # mirror _spine_center_row
    t = tx / max(GW - 1, 1)
    dip = math.sin(t * math.pi) * 3.0
    return 12 + int(round(dip))


def lane_cells():  # mirror _compute_lane_cells
    cells = set()

    def add(tx, ty):
        if tx < 0 or tx >= GW or ty < 0 or ty >= GH:
            return
        for b in BUILDINGS:
            if in_rect(tx, ty, b):
                return
        cells.add((tx, ty))

    for tx in range(GW):
        cr = spine_center_row(tx)
        for dy in range(0, 2):
            add(tx, cr + dy)
    for ty in range(14, 16):
        for tx in range(20, 23):
            add(tx, ty)
    wx, wy, ww, wh = WELL
    for ty in range(wy - 1, wy + wh + 1):
        for tx in range(wx - 1, wx + ww + 1):
            on_ring = tx == wx - 1 or tx == wx + ww or ty == wy - 1 or ty == wy + wh
            if on_ring:
                add(tx, ty)
    for ty in range(15, wy):
        add(wx + 1, ty)
    return cells


def main():
    dirt = load_atlas("floor_dirt.png")
    grass = load_atlas("floor_grass.png")
    cobble = load_atlas("floor_cobble.png")
    path = load_atlas("floor_path.png")
    atlases = {0: cobble, 3: dirt, 4: grass}

    lanes = lane_cells()
    canvas = np.empty((GH * TILE, GW * TILE, 3), np.uint8)
    for ty in range(GH):
        for tx in range(GW):
            if (tx, ty) in lanes:
                v = path_block_variant(tx // BLOCK, ty // BLOCK)
                cell = path[v, ty % BLOCK, tx % BLOCK]
            else:
                src = ground_class(tx, ty)
                v = block_variant(tx // BLOCK, ty // BLOCK)
                cell = atlases[src][v, ty % BLOCK, tx % BLOCK]
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
              "v2 GROUND: dirt majority + grass edges + cobble patches + fine-cobble LANE @ game zoom (2x)",
              fill=(255, 235, 200))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"[judge] in-context yard-ground render -> {OUT} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
