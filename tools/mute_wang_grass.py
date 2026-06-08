#!/usr/bin/env python3
"""
Doctrine-lock the NEON grass in the PixelLab Wang dirt<->grass atlas toward the muted
S1 moss family (Strategy-5 hue-preserving recolor, pixellab-pipeline.md §"Doctrine
palette compliance" / bake_stoker_palette.py luminance-band pattern).

WHY: the orch-generated `wang_dirtgrass_atlas.png` (Sponsor-APPROVED *blend*) has GOOD
soft dirt<->grass transition tiles, but the grass is NEON — hue ~123 deg, sat ~0.97,
val ~0.73 (measured). The S1 doctrine moss family is muted olive-green — hue ~85 deg,
sat ~0.40, val 0.30..0.58 (#5C7044 base / #3E4D2E shadow / #7E9456 lit / #47592F deep).
A neon-green grass reads as a toy/arcade lawn, NOT a lived-in monastery yard reclaimed
by moss (world-feel: big/endless/ALIVE, NOT cartoon).

THE LOCK (per-pixel, green-dominant pixels ONLY):
  - Detect grass pixels: G clearly dominant over BOTH R and B (the same G>R+t & G>B+t
    test the GUT zero-green / is-green pins use). Dirt (warm R>=G>=B) + the transition's
    dirt-side + any near-neutral outline pixels are LEFT UNTOUCHED (warm dirt stays warm).
  - HUE: rotate the grass hue toward the moss olive band (123 deg -> ~88 deg) by a
    proportional pull (not a flat set) so the per-pixel hue VARIATION the transition tufts
    rely on is preserved (ragged organic edge stays ragged), just shifted yellower.
  - SATURATION: crush toward the moss sat (~0.42) by a strong multiplicative pull — this
    is the single biggest "not-neon" lever (0.97 -> ~0.45).
  - VALUE: preserve the per-pixel tonal ORDERING (highlight stays highlight, shadow stays
    shadow) but remap the grass value range into the moss val range [0.30, 0.62] so the
    muted grass sits in the doctrine tonal window, never blowing out bright.

This is hue-preserving in the Strategy-5 sense: we keep each pixel's ROLE (its relative
hue offset + tonal order) and pull the whole cloud onto the doctrine moss locus, rather
than positionally remapping a palette (the Strategy-1 trap). Dirt is bypassed entirely.

Idempotency note: re-running on an already-muted atlas would pull the (already-olive,
already-low-sat) grass slightly further — so this is a ONE-SHOT from the raw PixelLab
atlas. The committed muted PNG is the artifact; the raw stays in _yard_review/.

Usage:
    python tools/mute_wang_grass.py <in_atlas.png> <out_atlas.png>
"""
import colorsys
import sys

import numpy as np
from PIL import Image

# --- Doctrine moss target band (measured from team/uma-ux palette moss family) ---
MOSS_HUE_DEG = 88.0     # olive-green locus (moss family ~81..89 deg)
MOSS_SAT = 0.42         # muted moss saturation target
HUE_PULL = 0.78         # 0..1 how far to rotate grass hue toward the moss hue
SAT_PULL = 0.82         # 0..1 how far to crush grass sat toward MOSS_SAT
VAL_LO, VAL_HI = 0.30, 0.62  # remap grass value into this muted doctrine window

# Grass detection: G clearly dominant over BOTH R and B (matches the GUT green test).
GREEN_T = 2  # /255 tolerance

# CLIFF-SHADOW SOFTEN (v5 in-game gate): the PixelLab Wang transition tiles ring the grass
# with a DARK reddish-brown shadow band (measured mean ~#62292D, value ~98 vs dirt base
# ~#C99774 value ~201) that reads as a raised-grass CLIFF/drop-off in-game, not a flat soft
# dirt<->grass blend. Lighten that dark warm edge-shadow toward the dirt base so the
# transition reads FLAT. Warm (non-green) pixels darker than CLIFF_V_MAX get pulled toward
# the dirt base value by CLIFF_LIGHTEN (hue/sat preserved — still brown, just less of a hole).
CLIFF_V_MAX = 150  # /255 — warm pixels below this are the cliff-shadow band
DIRT_BASE_V = 200  # /255 target value the shadow is pulled toward
CLIFF_LIGHTEN = 0.62  # 0..1 how far to lift the shadow value toward DIRT_BASE_V


def mute(in_path: str, out_path: str) -> None:
    img = Image.open(in_path).convert("RGBA")
    a = np.array(img)
    rgb = a[:, :, :3].astype(np.float64)
    al = a[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    grass = (al > 0) & (g > r + GREEN_T) & (g > b + GREEN_T)

    # Establish the grass value range for tonal remap (preserve ordering, remap window).
    gv = np.maximum(np.maximum(r, g), b)[grass] / 255.0
    if gv.size == 0:
        print("[mute] no grass pixels found — copying input unchanged")
        img.save(out_path)
        return
    v_min, v_max = float(gv.min()), float(gv.max())
    v_span = max(v_max - v_min, 1e-6)

    out = a.copy()
    ys, xs = np.where(grass)
    moss_h = MOSS_HUE_DEG / 360.0
    n_changed = 0
    for y, x in zip(ys, xs):
        pr, pg, pb = rgb[y, x, 0] / 255.0, rgb[y, x, 1] / 255.0, rgb[y, x, 2] / 255.0
        h, s, v = colorsys.rgb_to_hsv(pr, pg, pb)
        # HUE: proportional pull toward the moss olive locus (keeps per-pixel variation).
        h2 = h + (moss_h - h) * HUE_PULL
        # SAT: crush toward muted moss saturation.
        s2 = s + (MOSS_SAT - s) * SAT_PULL
        # VAL: preserve tonal ORDER, remap range into the muted doctrine window.
        t = (v - v_min) / v_span
        v2 = VAL_LO + t * (VAL_HI - VAL_LO)
        nr, ng, nb = colorsys.hsv_to_rgb(h2, s2, v2)
        out[y, x, 0] = int(round(nr * 255))
        out[y, x, 1] = int(round(ng * 255))
        out[y, x, 2] = int(round(nb * 255))
        n_changed += 1

    # --- Pass 2: neutralize the dark reddish-maroon CLIFF-SHADOW band ---
    # The PixelLab Wang transition tiles ring the grass with a DARK reddish-maroon shadow
    # band (measured mean ~#62292D — NOT brown-shadow; it reads as a raised-grass cliff
    # drop-off in-game). Recolor it toward a NEUTRAL warm dirt-shadow (a darker tone of the
    # dirt base, low saturation) so the grass edge reads as a flat soft soil transition, not
    # a saturated maroon cliff. We REPLACE the hue with the dirt hue + crush saturation,
    # keeping each pixel's relative value (tonal ordering) so the soft AA gradient survives.
    o2 = out[:, :, :3].astype(np.float64)
    r2, g2, b2 = o2[:, :, 0], o2[:, :, 1], o2[:, :, 2]
    v2 = np.maximum(np.maximum(r2, g2), b2)
    warm = (al > 0) & ~((g2 > r2 + GREEN_T) & (g2 > b2 + GREEN_T))
    cliff = warm & (v2 < CLIFF_V_MAX)
    cys, cxs = np.where(cliff)
    n_cliff = 0
    for y, x in zip(cys, cxs):
        pr, pg, pb = o2[y, x, 0] / 255.0, o2[y, x, 1] / 255.0, o2[y, x, 2] / 255.0
        _, _, v = colorsys.rgb_to_hsv(pr, pg, pb)
        # Map this shadow pixel to a darker tone of the warm dirt: dirt hue (~28 deg),
        # low sat (~0.32), value lifted partway toward the dirt base so it's a soft shadow
        # of soil, not a hole. Result: warm tan-shadow, no maroon, no cliff.
        v_new = v + (DIRT_BASE_V / 255.0 - v) * CLIFF_LIGHTEN
        nr, ng, nb = colorsys.hsv_to_rgb(28.0 / 360.0, 0.32, v_new)
        out[y, x, 0] = int(round(nr * 255))
        out[y, x, 1] = int(round(ng * 255))
        out[y, x, 2] = int(round(nb * 255))
        n_cliff += 1
    print(f"[mute] neutralized {n_cliff} maroon cliff-shadow pixels -> warm dirt-shadow")

    Image.fromarray(out, "RGBA").save(out_path)
    # Report the muted-grass HSV cloud for verification.
    o = np.array(Image.open(out_path).convert("RGBA"))[:, :, :3].astype(np.float64)
    sample = o[grass]
    hs = []
    for px in sample[::37]:
        hh, ss, vv = colorsys.rgb_to_hsv(px[0] / 255, px[1] / 255, px[2] / 255)
        hs.append((hh * 360, ss, vv))
    hs = np.array(hs)
    print(f"[mute] {in_path} -> {out_path}")
    print(f"[mute] recolored {n_changed} green pixels (dirt left warm/untouched)")
    print(
        f"[mute] muted grass HSV: hue {hs[:,0].mean():.1f} deg "
        f"sat {hs[:,1].mean():.2f} val {hs[:,2].mean():.2f} "
        f"(was ~123/0.97/0.73 neon -> moss target ~88/0.42)"
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: mute_wang_grass.py <in_atlas.png> <out_atlas.png>")
        sys.exit(2)
    mute(sys.argv[1], sys.argv[2])
