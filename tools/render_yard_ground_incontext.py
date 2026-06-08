#!/usr/bin/env python3
"""
IN-CONTEXT JUDGE RENDER for the #426 FINER-CELL + SEAMLESS-BLEND S1 GROUND (render-first
gate, Sponsor 2026-06-08 soak of 23ca119: "path corners/steps too chunky — finer cell
grid; and BLEND the materials — no hard tile seams between dirt/grass/cobble").

This mirrors the S1YardChunk painter's #426 fine-grid geometry EXACTLY (same 2x-finer
CELL_SUBDIV, same continuous 8-fine-cell atlas addressing keeping the stone size constant,
same feathered dirt↔grass / lane-edge / apron-edge dither blends, same hand-placed regions,
same finer-resolved lane dip) so the render is a faithful proxy of what the game paints.

Reads the SHIPPED atlases (UNCHANGED 768x128 — same stones; only the .tres cell got finer):
  assets/tilesets/s1_cloister/floor_dirt.png / floor_grass.png / floor_cobble.png / floor_path.png

Output: _yard_render/yard_ground_v4_judge.png  (game zoom; 0.48 player / 0.61 mob refs)
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
ATL = os.path.join(ROOT, "assets/tilesets/s1_cloister")
OUT = os.path.join(ROOT, "_yard_render", "yard_ground_v4_judge.png")

# LOGICAL tile + FINER-CELL revision (#426) — mirror S1YardChunk constants.
TILE = 32                  # logical tile px (world/spawn/ChunkDef contract)
CELL_SUBDIV = 2            # 2x-finer geometry grid
FINE_CELL = TILE // CELL_SUBDIV    # 16px fine cell
ATLAS_FINE_PERIOD = 8      # 128px variant / 16px fine cell (continuous-wrap period)
BLEND_BAND_CELLS = 3       # feathered dither band width (fine cells)

VARIANTS = 6
COBBLE_SEED = 1763
GRASS_SEED = 2207
DIRT_FIELD_VARIANT = 0
GRASS_FIELD_VARIANT = 0

GW, GH = 40, 24            # logical grid (world unchanged)
FW, FH = GW * CELL_SUBDIV, GH * CELL_SUBDIV   # 80 x 48 fine grid
ZOOM = 2

# Mirror S1YardChunk authored data (LOGICAL tiles).
BUILDINGS = [(8, 0, 12, 3), (6, 21, 14, 3), (18, 9, 6, 5), (33, 6, 3, 3)]
GRASS_REGIONS = [
    (0, 0, 7, 6), (33, 0, 7, 5), (0, 18, 9, 6),
    (34, 19, 6, 5), (20, 0, 10, 2), (22, 22, 11, 2),
]
WELL = (20, 16, 2, 2)
WELL_APRON = (19, 15, 4, 4)


def load_atlas(name):
    """Slice each 128px variant into an 8x8 grid of 16px FINE cells (mirror the .tres)."""
    img = np.asarray(Image.open(os.path.join(ATL, name)).convert("RGB"))
    P = ATLAS_FINE_PERIOD
    cells = np.empty((VARIANTS, P, P, FINE_CELL, FINE_CELL, 3), np.uint8)
    for v in range(VARIANTS):
        for cy in range(P):
            for cx in range(P):
                x0 = v * 128 + cx * FINE_CELL
                y0 = cy * FINE_CELL
                cells[v, cy, cx] = img[y0:y0 + FINE_CELL, x0:x0 + FINE_CELL]
    return cells


def absi(x):
    return abs(int(x))


def block_variant(bx, by):  # mirror _block_variant (cobble apron), per FINE block
    h = (bx * 73856093) ^ (by * 19349663) ^ (COBBLE_SEED * 83492791)
    return absi(h) % VARIANTS


def path_block_variant(bx, by):  # mirror _path_block_variant, per FINE block
    h = (bx * 49979693) ^ (by * 86028157) ^ (COBBLE_SEED * 6151)
    return absi(h) % VARIANTS


def in_rect(tx, ty, rect):
    x, y, w, h = rect
    return x <= tx < x + w and y <= ty < y + h


def logical_rect_has_fine(rect, fx, fy):
    x, y, w, h = rect
    return (x * CELL_SUBDIV) <= fx <= (x + w) * CELL_SUBDIV - 1 and \
           (y * CELL_SUBDIV) <= fy <= (y + h) * CELL_SUBDIV - 1


def fine_dither(fx, fy):  # mirror _fine_dither
    h = ((fx * 2654435761) ^ (fy * 40503) ^ (GRASS_SEED * 2246822519)) & 0x7fffffff
    return (h % 1000) / 1000.0


def grass_edge_depth(fx, fy):  # mirror _grass_edge_depth
    best = None
    for region in GRASS_REGIONS:
        rx, ry, rw, rh = region
        rx0, ry0 = rx * CELL_SUBDIV, ry * CELL_SUBDIV
        rx1, ry1 = (rx + rw) * CELL_SUBDIV - 1, (ry + rh) * CELL_SUBDIV - 1
        if fx < rx0 or fx > rx1 or fy < ry0 or fy > ry1:
            continue
        d = min(min(fx - rx0, rx1 - fx), min(fy - ry0, ry1 - fy))
        best = d if best is None else max(best, d)
    return best


def grass_blend_at(fx, fy):  # mirror _grass_blend_at
    depth = grass_edge_depth(fx, fy)
    if depth is None:
        return False
    if depth >= BLEND_BAND_CELLS:
        return True
    p_keep = (depth + 1) / (BLEND_BAND_CELLS + 1)
    return fine_dither(fx, fy) < p_keep


def spine_center_fine_row(fx):  # mirror _spine_center_fine_row
    t = fx / max(FW - 1, 1)
    dip_fine = math.sin(t * math.pi) * 2.0 * CELL_SUBDIV
    return 12 * CELL_SUBDIV + int(round(dip_fine))


def lane_cells():  # mirror _compute_lane_cells (fine grid, soft spine edge, spur)
    cells = set()
    half_w = (3 * CELL_SUBDIV) // 2  # 3

    def add(fx, fy):
        if fx < 0 or fx >= FW or fy < 0 or fy >= FH:
            return
        for b in BUILDINGS:
            if logical_rect_has_fine(b, fx, fy):
                return
        if logical_rect_has_fine(WELL, fx, fy):
            return
        cells.add((fx, fy))

    for fx in range(FW):
        cr = spine_center_fine_row(fx)
        for dy in range(-half_w, half_w + 1):
            # Soft path edge: outermost band feathers into dirt on the dither.
            if abs(dy) == half_w and fine_dither(fx, cr + dy) >= 0.65:
                continue
            add(fx, cr + dy)
    spur_fx = WELL[0] * CELL_SUBDIV + CELL_SUBDIV
    spur_top = spine_center_fine_row(spur_fx) + half_w - 1
    apron_top_fine = WELL_APRON[1] * CELL_SUBDIV
    for fy in range(spur_top, apron_top_fine):
        add(spur_fx, fy)
        add(spur_fx + 1, fy)
    return cells


def apron_keep(fx, fy):  # mirror _paint_well_apron feathered edge
    ax0 = WELL_APRON[0] * CELL_SUBDIV
    ay0 = WELL_APRON[1] * CELL_SUBDIV
    ax1 = (WELL_APRON[0] + WELL_APRON[2]) * CELL_SUBDIV - 1
    ay1 = (WELL_APRON[1] + WELL_APRON[3]) * CELL_SUBDIV - 1
    if fx < ax0 or fx > ax1 or fy < ay0 or fy > ay1:
        return False
    if logical_rect_has_fine(WELL, fx, fy):
        return False
    d = min(min(fx - ax0, ax1 - fx), min(fy - ay0, ay1 - fy))
    if d < BLEND_BAND_CELLS:
        p_keep = (d + 1) / (BLEND_BAND_CELLS + 1)
        if fine_dither(fx, fy) >= p_keep:
            return False
    return True


def field_cell(atlas, variant, fx, fy):
    lx = fx % ATLAS_FINE_PERIOD
    ly = fy % ATLAS_FINE_PERIOD
    return atlas[variant, ly, lx]


def main():
    dirt = load_atlas("floor_dirt.png")
    grass = load_atlas("floor_grass.png")
    cobble = load_atlas("floor_cobble.png")
    path = load_atlas("floor_path.png")

    lanes = lane_cells()
    # Canvas is the SAME 1280x768 world (FW*FINE_CELL == GW*TILE).
    canvas = np.empty((FH * FINE_CELL, FW * FINE_CELL, 3), np.uint8)
    for fy in range(FH):
        for fx in range(FW):
            if (fx, fy) in lanes:
                v = path_block_variant(fx // ATLAS_FINE_PERIOD, fy // ATLAS_FINE_PERIOD)
                cell = field_cell(path, v, fx, fy)
            elif apron_keep(fx, fy):
                v = block_variant(fx // ATLAS_FINE_PERIOD, fy // ATLAS_FINE_PERIOD)
                cell = field_cell(cobble, v, fx, fy)
            elif grass_blend_at(fx, fy):
                cell = field_cell(grass, GRASS_FIELD_VARIANT, fx, fy)
            else:
                cell = field_cell(dirt, DIRT_FIELD_VARIANT, fx, fy)
            canvas[fy * FINE_CELL:(fy + 1) * FINE_CELL,
                   fx * FINE_CELL:(fx + 1) * FINE_CELL] = cell

    img = Image.fromarray(canvas).resize(
        (canvas.shape[1] * ZOOM, canvas.shape[0] * ZOOM), Image.NEAREST
    )
    draw = ImageDraw.Draw(img)

    # char_scale=0.48 player ref (~22x38 source px) ON the lane near the west third, +
    # a 0.61 mob ref (MOB_SCALE_FACTOR 1.265 → 0.48*1.265 ≈ 0.61) a few tiles east on dirt.
    pw, ph = int(22 * ZOOM), int(38 * ZOOM)
    spine_y = (spine_center_fine_row(20) * FINE_CELL) * ZOOM
    px, py = 20 * FINE_CELL * ZOOM, spine_y - ph + FINE_CELL * ZOOM
    draw.rectangle([px, py, px + pw, py + ph], outline=(255, 80, 40), width=2)
    draw.text((px, max(2, py - 14)), "player ~0.48", fill=(255, 130, 70))
    mw, mh = int(28 * ZOOM), int(48 * ZOOM)  # ~0.61 (mob, 1.265x player)
    mx, my = 32 * FINE_CELL * ZOOM, py - 6
    draw.rectangle([mx, my, mx + mw, my + mh], outline=(80, 160, 255), width=2)
    draw.text((mx, max(2, my - 14)), "mob ~0.61", fill=(120, 180, 255))
    draw.text((6, 6),
              "v4 FINER CELL (16px, 2x) + FEATHERED dirt<->grass/path blends @ game zoom (2x)",
              fill=(255, 235, 200))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"[judge] in-context v4 yard-ground render -> {OUT} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
