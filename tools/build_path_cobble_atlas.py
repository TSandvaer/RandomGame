#!/usr/bin/env python3
"""
Build floor_path.png — the fine-cobble LANE atlas — from the Sponsor-approved AI weathered
cobble (floor_cobble_ai.png, seamless via tools/seamless_cobble.py). Sponsor explicitly
approved THIS cobble look for the lane this round (replaces the procedural lane stones).

The lane painter (S1YardChunk._paint_path_lane) addresses a 768x128 atlas = SIX 128px-square
seamless variant-blocks (the per-block scatter that breaks repeat). To reuse that machinery
unchanged, we pack 6 PHASE-SHIFTED crops of the seamless 256px AI cobble — each downsized to
128px — into the 768x128 atlas. Because the source is seamless (toroidal-ish after the
edge-blend), each phase-shifted-then-wrapped 128px crop is itself seamless, and the 6 variants
differ only by phase offset → the lane scatters them without any single repeating stamp.

SCALE: 256px source -> 128px variant means the 256px tile's ~16-stone grid renders ~8 stones
per 128 world-px period = each stone ~16 world-px. At the game zoom that reads as FINE dense
cobble (the Sponsor "small dense cobbles" note), distinctly finer than the dirt-cobble field.

Usage:
    python tools/build_path_cobble_atlas.py
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SRC = os.path.join(ROOT, "assets", "tilesets", "s1_cloister", "floor_cobble_ai.png")
OUT = os.path.join(ROOT, "assets", "tilesets", "s1_cloister", "floor_path.png")

VARIANT_PX = 128
N_VARIANTS = 6
# Phase offsets (in source px) for the 6 variants — spread so the scatter never realigns.
OFFSETS = [(0, 0), (43, 91), (128, 0), (0, 128), (91, 43), (160, 200)]


def main():
    src = np.array(Image.open(SRC).convert("RGBA"))
    sh, sw = src.shape[0], src.shape[1]
    atlas = np.zeros((VARIANT_PX, VARIANT_PX * N_VARIANTS, 4), dtype=np.uint8)
    for v, (ox, oy) in enumerate(OFFSETS):
        # Wrap-roll the seamless source by the phase offset, then downsample to 128.
        rolled = np.roll(np.roll(src, oy % sh, axis=0), ox % sw, axis=1)
        tile = Image.fromarray(rolled, "RGBA").resize((VARIANT_PX, VARIANT_PX), Image.LANCZOS)
        atlas[:, v * VARIANT_PX : (v + 1) * VARIANT_PX, :] = np.array(tile)
    Image.fromarray(atlas, "RGBA").save(OUT)
    print(f"[path-cobble] wrote {OUT}  ({VARIANT_PX * N_VARIANTS}x{VARIANT_PX}, {N_VARIANTS} variants)")
    print(f"[path-cobble] source AI cobble {SRC} ({sw}x{sh}) -> 6x 128px phase-shifted variants")


if __name__ == "__main__":
    main()
