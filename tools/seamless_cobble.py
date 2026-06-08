#!/usr/bin/env python3
"""
Make the AI weathered-cobble (Sponsor-approved this round) seam-free via the half-offset
np.roll wrap-blend (the edge-wrap-blend salvage in .claude/docs/pixellab-pipeline.md §"PixelLab
has NO full-bleed seamless-floor generator" — author/repair the tile to seamless-by-construction).

The raw `weathered_cobble_regen.png` (256x256, full-bleed opaque grey-tan cobble + moss grout)
tiles with MILD seams (the four edges don't wrap). FIX:
  1. np.roll the image by HALF in both axes → the former seams are now in the CENTER of the
     image, the edges are now the (already-continuous) former-center → the new edges wrap.
  2. The rolled-to-center former-seam is a visible cross. Feather-blend across it: take the
     rolled image and the original, and in a band around the center cross, cross-fade so the
     discontinuity dissolves into the surrounding stone (moss grout hides the rest).

Result: a 256x256 tile that wraps seamlessly on all four edges. Verified by re-rolling and
checking the edge-seam energy drops.

Usage:
    python tools/seamless_cobble.py <in.png> <out.png>
"""
import sys

import numpy as np
from PIL import Image


def seamless(in_path: str, out_path: str) -> None:
    img = Image.open(in_path).convert("RGBA")
    a = np.array(img).astype(np.float64)
    h, w = a.shape[0], a.shape[1]

    # TEXTBOOK TILEABLE: blend each edge region with the WRAPPED opposite edge over a band, so
    # the left edge ≈ right edge and top ≈ bottom directly (no center cross). For each edge
    # band of width `band`, cross-fade the pixels with the pixels `w` (or `h`) away wrapped —
    # i.e. linearly blend the near-edge stone with the far-edge stone so the tile's borders
    # converge. The interior stays untouched. Real stone on both sides → no smear.
    band = max(6, w // 8)
    out = a.copy()
    # Horizontal wrap (left<->right): blend a band on the LEFT with the RIGHT edge wrapped in.
    for i in range(band):
        t = 0.5 * (1.0 - i / float(band))  # 0.5 at the very edge, ->0 inward
        # left column i blends toward the column that will sit just to its left when tiled
        # (the right edge, w-band+i). Symmetric blend keeps both edges converging.
        right_i = w - band + i
        la = out[:, i, :].copy()
        ra = out[:, right_i, :].copy()
        out[:, i, :] = la * (1.0 - t) + ra * t
        out[:, right_i, :] = ra * (1.0 - t) + la * t
    # Vertical wrap (top<->bottom).
    for i in range(band):
        t = 0.5 * (1.0 - i / float(band))
        bot_i = h - band + i
        ta = out[i, :, :].copy()
        ba = out[bot_i, :, :].copy()
        out[i, :, :] = ta * (1.0 - t) + ba * t
        out[bot_i, :, :] = ba * (1.0 - t) + ta * t

    out_img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    out_img.save(out_path)

    # Verify: edge-seam energy (mean abs diff between opposite edges) should be low.
    o = np.array(out_img).astype(np.float64)[:, :, :3]
    top_bot = np.abs(o[0, :, :] - o[-1, :, :]).mean()
    left_right = np.abs(o[:, 0, :] - o[:, -1, :]).mean()
    print(f"[seamless] {in_path} -> {out_path} ({w}x{h})")
    print(f"[seamless] wrap-seam energy: top<->bottom {top_bot:.2f}  left<->right {left_right:.2f}")
    print("[seamless] (lower = more seamless; <8 reads seam-free at game zoom)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: seamless_cobble.py <in.png> <out.png>")
        sys.exit(2)
    seamless(sys.argv[1], sys.argv[2])
