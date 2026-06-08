#!/usr/bin/env python3
"""Prep S1 yard building raws for placement: strip baked matte bg, crop to content.

Two of the 256px create_map_object gens came back with an OPAQUE warm-grey matte
background (alpha 255) despite the API reporting transparent; the smaller gens are
properly transparent. This pass:
  1. Auto-detects a baked matte (opaque corner) and edge-floods it to transparent.
     Edge-flood (BFS from the border, small color tolerance) is safe — it only
     removes the contiguous border matte, never interior sandstone pixels that
     happen to match (the global color-replace trap).
  2. Crops to the non-transparent bbox so Drew's footprint maps to the visible
     building.
Raws preserved under _pixellab_raw/; exports land at assets/props/s1_yard/<name>.png.
"""
from PIL import Image
from collections import deque
from pathlib import Path

RAW = Path("assets/props/s1_yard/_pixellab_raw")
OUT = Path("assets/props/s1_yard")
NAMES = [
    "chapel_belltower.png",
    "dormitory_ruin_left.png",
    "dormitory_ruin_right.png",
    "cloister_central.png",
    "outbuilding_far.png",
]
TOL = 18  # RGB Euclidean-sq tolerance is TOL*TOL; matte is flat so this is generous-safe


def close(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2 <= TOL * TOL


for name in NAMES:
    im = Image.open(RAW / name).convert("RGBA")
    w, h = im.size
    px = im.load()
    tl = px[0, 0]
    removed = 0
    if tl[3] == 255:  # opaque corner => baked matte present
        bg = tl
        seen = [[False] * w for _ in range(h)]
        q = deque()
        for x in range(w):
            for y in (0, h - 1):
                if not seen[y][x] and close(px[x, y], bg):
                    seen[y][x] = True
                    q.append((x, y))
        for y in range(h):
            for x in (0, w - 1):
                if not seen[y][x] and close(px[x, y], bg):
                    seen[y][x] = True
                    q.append((x, y))
        while q:
            x, y = q.popleft()
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)
            removed += 1
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and close(px[nx, ny], bg):
                    seen[ny][nx] = True
                    q.append((nx, ny))
    bbox = im.getbbox()
    cropped = im.crop(bbox) if bbox else im
    cropped.save(OUT / name)
    print(f"{name:28s} {w}x{h} -> {cropped.size[0]}x{cropped.size[1]}  matte_removed={removed}px  bbox={bbox}")
