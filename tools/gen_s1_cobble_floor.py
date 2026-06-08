#!/usr/bin/env python3
"""
S1 cloister-yard GROUND generator — procedural (T1 86ca5erva; v2 ground-composition
RE-DO 86ca5hwmx, 2026-06-08).

Sponsor decision 2026-06-07: procedural over PixelLab. PixelLab's seamless Wang
tool caps at 32px/tile; the Sponsor wants HIGHER-quality (higher-res + seamless +
genuinely varied). Procedural delivers all three.

V2 GROUND-COMPOSITION RE-DO (Uma s1-ground-composition-v2.md, after the ASHLAR SLAB
PATH was soak-rejected a THIRD time). The EXECUTION INSIGHT (spec §0): Sponsor LOVED
this Voronoi cobble tech and REJECTED the fresh-procedural ashlar slab. So the new
surfaces LEAN ON THIS LOVED TECH — they are one-parameter VARIANTS of this generator,
NOT new models, NOT PixelLab. `--profile` selects which surface to emit:

  --profile cobble  (default) — the LOVED ground cobble (LOCKED): warm-grey domed
                    set-stones, ~18px largest at game zoom ≈ 1/3 the player. The
                    ground's surviving-paving PATCHES reuse this unchanged.
  --profile path    — the FINE-COBBLE LANE (the v2 path, replacing the dead slab):
                    the SAME Voronoi tech with (1) a FINER radii plan (~25-40%
                    smaller stones, more of them → largest renders ~10-14px, finer
                    than the ground cobble) + (2) S1_PATH_COBBLE_DOCTRINE (a touch
                    WARMER + LIGHTER) for the "walk here" path-vs-ground contrast
                    (spec §2). Still rounded-domed cobble (the loved read), NEVER
                    ashlar (the rejected model). ZERO baked green.
  --profile dirt    — the WORN-DIRT FIELD (the new MAJORITY ground, ~55-65%): the
                    same toroidal value-noise scaffolding emits a STONE-FREE worn
                    earth field — `#6B5A41`/`#54452F` with worn-lighter (foot-trodden)
                    + damp-darker (shadow) organic variation (spec §3.3). ZERO green.
  --profile grass   — the GRASS RECLAMATION ground tile (~20-30%, edges/corners): a
                    clean noise-driven green-tonal GROUND tile (the deliberate-planting
                    foundation, painted as PATCHES, never baked into the walking tiles
                    per spec §5). This is a SEPARATE ground material (a tile-class the
                    painter places at chosen cells), NOT the rejected spiky moss_patch
                    prop. The ONLY profile that is green (it IS the grass layer).

All four are seamless-by-construction (toroidal), doctrine-locked, multi-variant —
the proven recipe. The painter (S1YardChunk) composes them per spec §3 (dirt majority
+ grass patches + cobble patches + the fine-cobble lane), one tile-class per cell (AC9).

HARD REQUIREMENTS (each prior PixelLab attempt failed one of these):
  1. Genuinely VARIED stone sizes — chaotic natural mix of large + medium + small
     cobbles + pebbles filling the gaps. NO uniform sizing, NO rows/grid.
  2. SEAMLESS by construction — toroidal wrap so the tile repeats PERFECTLY across
     the whole scrolling yard. Every distance is computed on the torus.
  3. Higher-res than PixelLab's 32px Wang cap — author at 256px source res.

TECHNIQUE
  - Stones are placed by Poisson-disk sampling with VARIED minimum radii: a few
    LARGE stones (big exclusion radius => sparse), then MEDIUM, then SMALL, then
    PEBBLES packed into the remaining gaps. Each seed carries a "weight" ~ its
    target size.
  - Cell ownership uses ADDITIVELY-WEIGHTED toroidal distance  d(p,s) - w_s , so
    a large-weight seed claims a genuinely larger territory than a small one. This
    is what produces the chaotic VARIED stone sizes a plain (equal-cell) Voronoi
    cannot.
  - All distances are toroidal ( min(|dx|, S-|dx|) per axis ) => SEAMLESS by
    construction. The same seed set wraps across the tile edge with zero seam.
  - Rounded DOMED look: within a cell, brighten toward the cell centroid and bias
    the light upper-left (lit dome top `cobble_lit`), darken the lower-right base
    (`cobble_shadow`). The gap between cells is the recessed JOINT (`joint_deep`).
  - Organic invasion: low-frequency TOROIDAL value-noise fields drive moss (creeps
    in joints + damp clusters) and dirt (replaces sunk/missing stones). Clustered,
    never uniform.

Palette: Uma's S1_YARD_FLOOR_DOCTRINE (team/uma-ux/s1-cloister-yard.md §3.2).
All channels sub-1.0 (HDR-clamp safe) — biased a touch COOLER/greyer per Sponsor's
reference (cobbles read as set-stone, not warm sandstone).

Outputs (under _tile_judge/cobble_proc/ by default):
  cobble_v<i>_256.png        — N seamless 256px source variants
  cobble_proc_seamcheck.png  — one variant tiled 3x3 (proves the wrap is seamless)
  cobble_proc_field.png      — large non-repeating yard preview (variants mixed)
  cobble_proc_field_zoom.png — the field at game zoom (downsample to 32px tiles, 2x)
  cobble_proc_contactsheet.png — all variants side-by-side at 2x for judging
"""
import argparse
import os
import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# S1_YARD_FLOOR_DOCTRINE — team/uma-ux/s1-cloister-yard.md §3.2 (sub-1.0 verified)
# ---------------------------------------------------------------------------
DOCTRINE = {
    "cobble_base":  "#6E665A",  # warm-gray set-stone, dominant tile
    "cobble_lit":   "#857C6C",  # domed cobble top catching light
    "cobble_shadow":"#544C42",  # cobble base shadow / deep joint
    "joint_deep":   "#3D372F",  # recessed gap where dirt+shadow collect
    "moss":         "#5C7044",  # olive moss creeping in joints
    "moss_deep":    "#47592F",  # shadowed moss in wettest joints
    "dirt":         "#6B5A41",  # bare earth where cobbles missing/sunk
    "dirt_deep":    "#54452F",  # damp packed soil, shadowed
}

# ---------------------------------------------------------------------------
# S1_PATH_COBBLE_DOCTRINE — Uma s1-ground-composition-v2.md §2.3 (sub-1.0 verified).
# The fine-cobble LANE: the SAME cobble material, shifted a touch WARMER + LIGHTER
# for the walked-lane "walk here" read (a real walked lane wears lighter/smoother).
# Subtle — NOT a jarring material swap. The path-vs-ground contrast (PL-PATH-02) is
# the wayfinding payload: path base #7E7460 is perceptibly warmer+lighter than the
# ground cobble #6E665A AND the stones are finer.
# ---------------------------------------------------------------------------
PATH_DOCTRINE = {
    "cobble_base":  "#7E7460",  # path base — warm-grey set-stone, WARMER+LIGHTER than ground
    "cobble_lit":   "#988C76",  # path lit — domed top of a walked-smooth path stone
    "cobble_shadow":"#5E564A",  # path stone base shadow / joint (slightly warmer)
    "joint_deep":   "#3D372F",  # joint deep — SHARED dirt-shadow gap (one joint hex yard-wide)
}

# ---------------------------------------------------------------------------
# S1_DIRT_DOCTRINE — Uma s1-ground-composition-v2.md §3.1/§3.3 (sub-1.0 verified).
# The worn-DIRT field (the new MAJORITY ground). Reuses the cobble doctrine's dirt
# hexes as a worn-earth surface: bare trodden earth, foot-worn lighter where walked,
# damp darker in shadow. ZERO green (PL-PATH-04 class). Graveyard-Keeper ground ref.
# ---------------------------------------------------------------------------
DIRT_DOCTRINE = {
    "dirt_base":   "#6B5A41",  # bare trodden earth, dominant
    "dirt_lit":    "#82704F",  # foot-worn lighter dirt (where feet wore it smooth/dry)
    "dirt_deep":   "#54452F",  # damp packed soil, shadowed
    "dirt_dark":   "#453825",  # wettest/deepest shadow earth (organic dark variation)
}

# ---------------------------------------------------------------------------
# S1_GRASS_DOCTRINE — Uma s1-ground-composition-v2.md §3.1/§3.3 (sub-1.0 verified).
# The grass RECLAMATION ground tile (edges/corners — where feet DIDN'T fall). A clean
# noise-driven green-tonal GROUND material (the deliberate-planting foundation),
# painted as PATCHES with feathered borders, NOT the rejected spiky moss_patch prop,
# NOT baked into the walking tiles. Olive-to-mid greens, sub-1.0 (HDR-clamp-safe),
# NEVER pure-saturated (a worn monastery-yard reclaiming-grass, not a lawn). This is
# the ONE profile that is intentionally GREEN — it IS the grass layer.
# ---------------------------------------------------------------------------
GRASS_DOCTRINE = {
    "grass_base":  "#5C7044",  # olive reclaiming grass, dominant (= the cobble moss hue)
    "grass_lit":   "#6E8451",  # sun-caught lighter grass blade tops
    "grass_deep":  "#47592F",  # shadowed grass in the thickest clumps
    "grass_dark":  "#3A4A28",  # darkest damp grass-root shadow (organic dark variation)
}


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


PAL = {k: hexrgb(v) for k, v in DOCTRINE.items()}


# ---------------------------------------------------------------------------
# Toroidal helpers
# ---------------------------------------------------------------------------
def torus_delta(a, b, S):
    """Signed shortest delta a-b on a torus of period S, result in (-S/2, S/2]."""
    d = a - b
    d = (d + S / 2.0) % S - S / 2.0
    return d


def toroidal_poisson_varied(S, rng, radii_plan):
    """
    Poisson-disk sample on the torus with VARIED minimum radii.

    radii_plan: list of (target_count, min_radius, weight) tiers, large-first.
      A candidate is accepted only if it is >= min_radius (toroidal) from EVERY
      already-placed point. Large tiers (big radius) are placed first so they get
      the room they need; later small tiers pack into the gaps.

    Returns (pts Nx2 float, weights N float). The weight feeds the additively-
    weighted Voronoi so a big-radius stone also claims a big cell.
    """
    pts = []
    weights = []
    for target_count, min_r, weight in radii_plan:
        placed = 0
        attempts = 0
        max_attempts = target_count * 80
        while placed < target_count and attempts < max_attempts:
            attempts += 1
            c = rng.uniform(0, S, 2)
            ok = True
            for p in pts:
                dx = torus_delta(c[0], p[0], S)
                dy = torus_delta(c[1], p[1], S)
                if dx * dx + dy * dy < min_r * min_r:
                    ok = False
                    break
            if ok:
                pts.append(c)
                weights.append(weight)
                placed += 1
    return np.array(pts, np.float32), np.array(weights, np.float32)


def toroidal_value_noise(S, rng, cells, octaves=3):
    """
    Seamless (toroidal) fractal value noise in [0,1], shape (S,S).
    Built by tiling a low-res lattice with periodic wrap and bilinear upsample,
    summed over octaves. Wraps perfectly because the lattice itself wraps.
    """
    out = np.zeros((S, S), np.float32)
    amp = 1.0
    total = 0.0
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    for o in range(octaves):
        n = cells * (2 ** o)
        lattice = rng.random((n, n)).astype(np.float32)
        # bilinear sample with periodic wrap
        gx = xx / S * n
        gy = yy / S * n
        x0 = np.floor(gx).astype(int) % n
        y0 = np.floor(gy).astype(int) % n
        x1 = (x0 + 1) % n
        y1 = (y0 + 1) % n
        fx = gx - np.floor(gx)
        fy = gy - np.floor(gy)
        # smoothstep for less blocky interpolation
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        top = lattice[y0, x0] * (1 - fx) + lattice[y0, x1] * fx
        bot = lattice[y1, x0] * (1 - fx) + lattice[y1, x1] * fx
        out += amp * (top * (1 - fy) + bot * fy)
        total += amp
        amp *= 0.5
    out /= total
    return out


# ---------------------------------------------------------------------------
# The cobble tile
# ---------------------------------------------------------------------------
def make_cobble_tile(seed, S=256, warm_bias=0.05, lighten=1.20,
                     moss_amount=1.0, dirt_amount=1.0, fine_scale=1.0,
                     doctrine=None, path_fine=False):
    """
    Generate ONE seamless varied-size cobble tile (S x S, RGB uint8).

    doctrine: the palette dict (DOCTRINE for ground cobble, PATH_DOCTRINE for the
              fine-cobble lane). Defaults to the ground-cobble DOCTRINE.
    path_fine: when True (the v2 PATH profile), drop the radii-plan tier sizes ~30%
               + raise counts so the path stones render FINER than the ground cobble
               (~10-14px largest vs ~18px) — the spec §2.2 "fine, deliberately-laid
               pavement of small set stones" read. Same Voronoi model + tone treatment;
               only the radii plan + palette differ from the ground cobble.

    TONE (Sponsor feel-gate v2, 2026-06-07): lighter + warmer-neutral mid-grey.
    The v1 cool-bias read too dark + blue/teal-grey; Sponsor's reference is a
    lighter, warmer mid-grey cobble path. The varied-size Voronoi + toroidal
    seamlessness are UNCHANGED — this is tone/palette/lighting only.

    warm_bias: 0..~0.10 — nudges stone toward NEUTRAL-WARM grey (raise R a hair,
               drop B a hair) to kill the blue/cool cast. (Replaces v1 cool_bias.)
    lighten:   overall brighten multiplier on the cobble stone colors (1.0 = v1
               doctrine value; >1.0 = lighter floor). Result is re-clamped sub-1.0.
    moss_amount / dirt_amount: scale the organic invasion (1.0 = doctrine default).
    """
    rng = np.random.default_rng(seed)

    # Local palette from the chosen doctrine (ground cobble vs warm path cobble).
    doc = doctrine if doctrine is not None else DOCTRINE
    LP = {k: hexrgb(v) for k, v in doc.items()}

    # Varied stone-size plan, scaled to source res. Counts/radii tuned at 256px.
    # Large + medium + small + pebbles => chaotic natural mix, NO uniform sizing.
    k = S / 256.0
    # FINE-COBBLE plan (Sponsor scale fix, 2026-06-07): the prior plan's stones
    # rendered ~player-sized at game zoom ("tiles 10x bigger than supposed to be").
    # Rendered stone size = source_radius * (period*32 / source_res) * cam_zoom, so
    # the ONLY scale lever at a fixed atlas period is SMALLER SOURCE RADII (NOT
    # downsampling a coarse source — that re-flattens the relief). Radii dropped ~4x
    # + counts up ~15x => MANY small cobbles; the 4-tier mix keeps genuine size
    # VARIATION (the locked v2 read) and the toroidal Poisson keeps it SEAMLESS.
    # Authored against a 384px source (gives the ~3.6px pebbles real pixels) tiled
    # at period 4: a large cobble now renders ~18 screen px ≈ 1/3 the 0.6 player,
    # so the player walks on a FINE cobble ground (`tile-scale-small-player-large-world`).
    # fine_scale (#426 SOAK-REVISION, Sponsor 2026-06-08): "cobble base ~20% SMALLER
    # (finer stones)". Multiplies every tier's min_radius + weight by fine_scale and
    # bumps counts by ~1/fine_scale^2 so coverage holds at the finer stone size. The
    # Voronoi cell area scales ~radius^2, so count ∝ 1/scale^2 keeps the field packed.
    # fine_scale=1.0 = the locked T8 (#424) read; 0.8 = the 20%-finer soak-revision.
    fs = fine_scale
    # PATH profile (v2 §2.2): the lane is FINER than the ground cobble — drop tier
    # radii ~30% (0.70) on top of fine_scale so the largest path stone renders
    # ~10-14px (vs the ground cobble's ~18px) and the lane reads as a deliberately-
    # laid fine pavement of small set stones (village-street ref 08h00_28). count ∝
    # 1/scale^2 keeps the field packed at the finer stone size.
    if path_fine:
        fs = fs * 0.70
    cinv = 1.0 / max(fs * fs, 1e-3)
    radii_plan = [
        # (count, min_radius_px, weight)  weight feeds additively-weighted Voronoi
        (int(70 * cinv),  15 * k * fs, 8.0 * k * fs),   # LARGER cobbles (dominant set-stones)
        (int(150 * cinv),  9 * k * fs, 4.5 * k * fs),   # MEDIUM cobbles
        (int(320 * cinv),  6 * k * fs, 2.2 * k * fs),   # SMALL cobbles
        (int(650 * cinv), 3.6 * k * fs, 1.0 * k * fs),  # PEBBLES packed into the gaps
    ]
    pts, weights = toroidal_poisson_varied(S, rng, radii_plan)
    n = len(pts)

    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)

    # Additively-weighted toroidal distance to every seed -> ownership + relief.
    # d_eff = euclid_toroidal - weight  (bigger weight => claims more area).
    d_eff = np.empty((n, S, S), np.float32)
    d_geo = np.empty((n, S, S), np.float32)
    for i in range(n):
        dx = torus_delta(xx, pts[i, 0], S)
        dy = torus_delta(yy, pts[i, 1], S)
        g = np.sqrt(dx * dx + dy * dy)
        d_geo[i] = g
        d_eff[i] = g - weights[i]

    order = np.argsort(d_eff, axis=0)
    nearest = order[0]                                   # owning stone per pixel
    e0 = np.take_along_axis(d_eff, order[0:1], 0)[0]
    e1 = np.take_along_axis(d_eff, order[1:2], 0)[0]
    border = e1 - e0                                     # small => near a joint

    # geometric distance to the OWNING stone's centroid (for the dome shading)
    g_own = np.take_along_axis(d_geo, nearest[None], 0)[0]
    w_own = weights[nearest]                             # owning stone "radius"-ish

    # --- TONE TREATMENT (v2): lighter + warmer-neutral mid-grey ----------------
    # Apply a warm-neutral nudge (raise R, drop B) + an overall lighten to the
    # cobble stone colors. Doctrine hexes are the SOURCE; this is the lighter,
    # warmer mid-grey path the Sponsor's reference asked for. Re-clamped sub-1.0.
    warm_vec = np.array([warm_bias, warm_bias * 0.20, -warm_bias * 0.85],
                       np.float32) * 255.0

    def tune(c):
        return np.clip((c + warm_vec) * lighten, 0, 255)

    cobble_base_t = tune(LP["cobble_base"])
    cobble_lit_t = tune(LP["cobble_lit"])
    # joints lightened separately (less heavy shadow) — see joint block below.

    # --- base stone color, per-stone tone jitter + a few worn-lighter stones ---
    tone = rng.uniform(-0.10, 0.12, n).astype(np.float32)
    worn = (rng.random(n) < 0.20)                        # foot-worn lighter stones
    base = cobble_base_t

    img = np.empty((S, S, 3), np.float32)
    stone_col = np.empty((n, 3), np.float32)
    for i in range(n):
        c = (cobble_lit_t if worn[i] else base) * (1.0 + tone[i])
        stone_col[i] = np.clip(c, 0, 255)
    img = stone_col[nearest]

    # --- DOMED rounded shading -------------------------------------------------
    # dome factor: 1 at the stone centroid, falling toward its rim. Normalize each
    # pixel's geometric centroid-distance by its owning stone's size (w_own) so big
    # and small stones both read as full domes (not big=flat).
    rim = (w_own * 1.25) + 7.0 * k
    dome = np.clip(1.0 - (g_own / rim), 0.0, 1.0)        # 0 rim .. 1 center
    dome = dome ** 0.55                                  # fuller, rounder top
    # directional light: lit upper-left, shadowed lower-right
    lx, ly = -0.6, -0.6
    # gradient of centroid-distance approximates the local surface normal direction
    gy, gx = np.gradient(g_own)
    gmag = np.sqrt(gx * gx + gy * gy) + 1e-3
    ndl = (gx / gmag) * lx + (gy / gmag) * ly           # -1..1 facing-light term
    # Raised light FLOOR (0.80 -> 0.90) so rims/bases read mid-grey not gloomy-dark,
    # with slightly gentler dark pull. Keeps dome relief; lifts overall brightness.
    light = 0.90 + 0.30 * dome + 0.18 * np.clip(ndl, -1, 1)

    lit = cobble_lit_t                                    # tuned (lighter+warmer) lit
    # base-shadow is lightened toward the base tone (was full doctrine shadow) so
    # cobble bases read mid-grey, not heavy dark.
    shp = tune(LP["cobble_shadow"]) * 0.5 + cobble_base_t * 0.5
    # blend toward lit at the upper-left dome tops, toward shadow at the rims/bases
    t_lit = np.clip((light - 1.08) * 1.8, 0, 1)[:, :, None]
    t_shp = np.clip((0.90 - light) * 1.4, 0, 1)[:, :, None]   # gentler dark blend
    img = img * light[:, :, None]
    img = img * (1 - t_lit) + lit * t_lit
    img = img * (1 - t_shp) + shp * t_shp

    # --- JOINTS between stones (recessed gaps, irregular width) -----------------
    # v2: LIGHTER joints so the floor doesn't read dark/gloomy. The joint is still
    # the darkest part (reads as a recess) but mid-grey-dark, not near-black.
    # FINE-COBBLE (Sponsor scale fix): with ~15x more, much SMALLER stones the joint
    # is a far larger fraction of each tiny cobble, so a fixed joint_w darkened +
    # warmed the overall mean (dropped from the locked ~152,132,99 toward ~132,113,81).
    # THIN the joints (1.5px vs 2.6px) so the dense floor keeps the locked v2 lighter
    # warm-neutral GREY read — the stones stay the dominant surface, not the gaps.
    joint_w = 1.5 * k
    joint = border < joint_w
    deep = border < (joint_w * 0.5)
    # joint = tuned shadow lifted FURTHER toward base (lighter) so dense joints don't
    # darken the floor; deep = a touch darker still.
    joint_col = tune(LP["cobble_shadow"]) * 0.55 + cobble_base_t * 0.45
    deep_col = tune(LP["joint_deep"]) * 0.45 + cobble_base_t * 0.55
    img[joint] = joint_col
    img[deep] = deep_col
    # ambient-occlusion darkening just inside each stone next to a joint (gentler,
    # and a thinner band so the dense small stones don't read AO-heavy).
    ao = (border >= joint_w) & (border < joint_w * 1.8)
    img[ao] *= 0.97

    # --- NO BAKED VEGETATION: CLEAN GREY COBBLE ONLY ---------------------------
    # Sponsor approval-gating lock (2026-06-07): "drop the grass in the cobblestone."
    # ALL moss/green/grass is stripped from the floor tiles — the cobble base is now
    # CLEAN grey cobblestone, no green at all. (Earlier: dirt puddles were cut; now
    # the moss field too.) Vegetation returns LATER as a deliberate decoration /
    # composition LAYER on top of the ground, NOT baked into the tile.
    #
    # Everything else is preserved exactly: the loved cobble stone scale/shape/tone,
    # the 6-variant non-repeating block scatter (painter side), no brown puddles,
    # toroidal seamlessness, grey tone. `moss_amount` / `dirt_amount` are retained as
    # inert CLI args for back-compat but no longer paint anything.

    return np.clip(img, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------------------
# The STONE-FREE field tile (worn dirt / reclaiming grass) — v2 §3.3.
# ---------------------------------------------------------------------------
def make_field_tile(seed, doctrine, S=384, var_amount=1.0):
    """
    Generate ONE seamless STONE-FREE field tile (S x S, RGB uint8) — the worn-DIRT
    majority ground OR the reclaiming-GRASS patch tile, depending on `doctrine`.

    There is NO Voronoi stone structure here (a field is not paved): the look is
    driven entirely by TOROIDAL value noise (seamless by construction) blending across
    the doctrine's 4 tones — base / lit (worn-lighter / sun-caught) / deep (damp
    shadow) / dark (deepest shadow). The result is an organic, never-flat earth/grass
    surface that tiles perfectly across the wide yard (anti-repeat, spec §1 BIG/ENDLESS).

    doctrine keys expected: "<x>_base", "<x>_lit", "<x>_deep", "<x>_dark" (the dirt or
    grass ramp). var_amount scales the noise contrast (multi-variant spread).

    ZERO green for the DIRT doctrine (warm-earth ramp, R>=G>=B); the GRASS doctrine IS
    green by design (it is the grass layer). The painter places grass as PATCHES only,
    never baked into the walking dirt/cobble/path tiles (spec §5).
    """
    rng = np.random.default_rng(seed)
    keys = list(doctrine.keys())
    base = hexrgb(doctrine[keys[0]])
    lit = hexrgb(doctrine[keys[1]])
    deep = hexrgb(doctrine[keys[2]])
    dark = hexrgb(doctrine[keys[3]])

    # THREE toroidal noise fields: a broad one (large damp/worn zones), a mid one
    # (patch grain), and a FINE one (trodden-earth/blade speckle so the surface reads
    # TEXTURED, not smooth fog — the prior cloudy look exposed the cross-tile seam).
    # All seamless. Combine into a 0..1 elevation across the 4-tone ramp.
    broad = toroidal_value_noise(S, rng, cells=2, octaves=3)     # large zones
    mid = toroidal_value_noise(S, rng, cells=7, octaves=3)       # patch grain
    fine = toroidal_value_noise(S, rng, cells=18, octaves=2)     # fine speckle
    elev = (0.46 * broad + 0.34 * mid + 0.20 * fine)
    # contrast-stretch around the MEAN (centred at 0.5) for shape variation per variant,
    # then NORMALIZE the per-variant mean to a fixed target. Equalizing the mean across
    # variants is what kills the cross-tile BRIGHTNESS GRID (adjacent cells from different
    # variant-blocks must read the same average tone — Sponsor repeat-stamp class). Only
    # the *texture/shape* differs per variant, not the overall brightness.
    elev = 0.5 + (elev - elev.mean()) * (1.15 * var_amount)
    elev = np.clip(elev, 0.0, 1.0)
    # renormalize the post-clip mean back to 0.5 so EVERY variant has the same average
    # elevation → same average tone → no brightness step at variant-block seams.
    elev = elev - elev.mean() + 0.5
    elev = np.clip(elev, 0.0, 1.0)

    # 4-stop ramp: [0..0.30] dark->deep, [0.30..0.62] deep->base, [0.62..1.0] base->lit.
    img = np.empty((S, S, 3), np.float32)

    def lerp(a, b, t):
        return a[None, None, :] * (1 - t[:, :, None]) + b[None, None, :] * t[:, :, None]

    seg0 = elev < 0.30
    seg1 = (elev >= 0.30) & (elev < 0.62)
    seg2 = elev >= 0.62
    t0 = np.clip(elev / 0.30, 0, 1)
    t1 = np.clip((elev - 0.30) / 0.32, 0, 1)
    t2 = np.clip((elev - 0.62) / 0.38, 0, 1)
    ramp = lerp(dark, deep, t0)
    ramp = np.where(seg1[:, :, None], lerp(deep, base, t1), ramp)
    ramp = np.where(seg2[:, :, None], lerp(base, lit, t2), ramp)
    img = ramp

    # per-pixel grain so the surface reads as TEXTURED earth/grass, not a smooth gradient
    # (the cloudy/foggy look exposed the cross-tile seam + read flat). A high-freq dither,
    # hue-preserving (brightness only). Stronger than the prior 0.06 for real grit.
    grain = (rng.random((S, S)).astype(np.float32) - 0.5) * 0.11
    img = np.clip(img * (1.0 + grain[:, :, None]), 0, 255)

    return np.clip(img, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------------------
# Preview assembly
# ---------------------------------------------------------------------------
def tile_field(variants, cols, rows, rng):
    """Lay variants in a cols x rows grid, randomly choosing a variant per cell,
    avoiding the same variant twice in a row, to break repeat across a wide yard."""
    S = variants[0].shape[0]
    field = np.empty((rows * S, cols * S, 3), np.uint8)
    last_row = [-1] * cols
    for r in range(rows):
        last = -1
        for c in range(cols):
            choices = [i for i in range(len(variants)) if i != last and i != last_row[c]]
            if not choices:
                choices = list(range(len(variants)))
            vi = rng.choice(choices)
            field[r * S:(r + 1) * S, c * S:(c + 1) * S] = variants[vi]
            last = vi
            last_row[c] = vi
    return field


def assert_zero_green(variants, label):
    """Hard guard (PL-PATH-04): NO pixel may read green (G clearly exceeds R and B).
    The walking surfaces (cobble / path / dirt) are warm/neutral — R >= G >= B always.
    A green pixel = the rejected baked-vegetation class — fail loudly. NOT called for
    the grass profile (grass IS green by design)."""
    for i, v in enumerate(variants):
        r = v[:, :, 0].astype(np.int32)
        g = v[:, :, 1].astype(np.int32)
        b = v[:, :, 2].astype(np.int32)
        green = (g > r + 4) & (g > b + 4)
        n = int(green.sum())
        if n > 0:
            raise SystemExit(
                "PL-PATH-04 VIOLATION (%s): variant %d has %d green pixel(s) — the "
                "rejected baked-vegetation class. Regen aborted." % (label, i, n)
            )
    print("[gen] PL-PATH-04 OK (%s) — zero green pixels across all variants." % label)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", default="cobble",
                    choices=["cobble", "path", "dirt", "grass"],
                    help="which ground surface to emit (v2 §0): cobble=ground cobble "
                         "(LOCKED); path=fine-cobble lane (finer+warmer); dirt=worn-earth "
                         "majority field; grass=reclamation green tile (the only green one)")
    ap.add_argument("--out", default=None, help="output dir")
    ap.add_argument("--res", type=int, default=256, help="source tile resolution")
    ap.add_argument("--variants", type=int, default=6)
    ap.add_argument("--seed", type=int, default=1000)
    ap.add_argument("--warm", type=float, default=0.05,
                    help="warm-neutral grey bias 0..0.10 (kills the blue/cool cast)")
    ap.add_argument("--lighten", type=float, default=1.20,
                    help="overall brighten multiplier on cobble stone colors (1.0=v1)")
    ap.add_argument("--suffix", default="",
                    help="filename suffix for output set (e.g. v2) to keep prior renders")
    ap.add_argument("--fine-scale", type=float, default=1.0, dest="fine_scale",
                    help="stone-size multiplier (#426 soak-rev: 0.8 = 20%% finer/smaller "
                         "cobbles; 1.0 = locked T8 read)")
    ap.add_argument("--atlas-out", default=None, dest="atlas_out",
                    help="if set, also assemble the shipped 768x128 6-variant atlas PNG at "
                         "this path (each 384px source variant downsampled to 128px, packed "
                         "side by side) — the file the painter consumes")
    args = ap.parse_args()
    sfx = ("_" + args.suffix) if args.suffix else ""

    here = os.path.dirname(os.path.abspath(__file__))
    out = args.out or os.path.join(here, "..", "_tile_judge", "%s_proc" % args.profile)
    out = os.path.abspath(out)
    os.makedirs(out, exist_ok=True)

    S = args.res
    profile = args.profile
    # Profile → output filename stem + which generator + (for cobble/path) the doctrine.
    stem = {"cobble": "cobble", "path": "path", "dirt": "dirt", "grass": "grass"}[profile]
    print(f"[gen] profile={profile}: generating {args.variants} seamless {stem} "
          f"variants @ {S}px ...")
    variants = []
    if profile in ("cobble", "path"):
        # COBBLE / PATH — the loved Voronoi domed-stone tech. PATH uses PATH_DOCTRINE
        # (warmer+lighter) + path_fine (finer radii) for the "walk here" lane read.
        doc = PATH_DOCTRINE if profile == "path" else DOCTRINE
        path_fine = (profile == "path")
        moss_spread = [0.55, 0.80, 1.0, 1.0, 1.25, 1.5]
        for i in range(args.variants):
            moss_a = moss_spread[i % len(moss_spread)]
            t = make_cobble_tile(args.seed + i * 17, S=S, warm_bias=args.warm,
                                 lighten=args.lighten, moss_amount=moss_a, dirt_amount=0.0,
                                 fine_scale=args.fine_scale, doctrine=doc, path_fine=path_fine)
            variants.append(t)
            Image.fromarray(t).save(os.path.join(out, f"{stem}{sfx}_v{i}_{S}.png"))
            print(f"  - {stem}{sfx}_v{i}_{S}.png")
    else:
        # DIRT / GRASS — the stone-free toroidal-noise field. var_amount spread gives
        # each variant a different contrast (the multi-variant repeat-breaker).
        field_doc = DIRT_DOCTRINE if profile == "dirt" else GRASS_DOCTRINE
        # Tight spread: variants differ in TEXTURE/shape, NOT brightness (the mean is
        # equalized in make_field_tile). A narrow range keeps every variant's contrast
        # similar so no single block reads anomalously busy/flat at a seam.
        var_spread = [0.92, 1.00, 1.08, 0.96, 1.04, 1.00]
        for i in range(args.variants):
            va = var_spread[i % len(var_spread)]
            t = make_field_tile(args.seed + i * 17, field_doc, S=S, var_amount=va)
            variants.append(t)
            Image.fromarray(t).save(os.path.join(out, f"{stem}{sfx}_v{i}_{S}.png"))
            print(f"  - {stem}{sfx}_v{i}_{S}.png")

    # PL-PATH-04 self-guard: the walking surfaces (cobble/path/dirt) must be ZERO green.
    # Grass is exempt (it IS the green layer).
    if profile in ("cobble", "path", "dirt"):
        assert_zero_green(variants, profile)

    # SEAMCHECK: one variant tiled 3x3 — must show NO grid/seam.
    v0 = variants[0]
    seam = np.tile(v0, (3, 3, 1))
    Image.fromarray(seam).save(os.path.join(out, f"{stem}_proc_seamcheck{sfx}.png"))
    print(f"[gen] {stem}_proc_seamcheck{sfx}.png (variant 0 tiled 3x3 — seam test)")

    # CONTACT SHEET: all variants at 2x for material judging.
    cs_cols = min(3, args.variants)
    cs_rows = (args.variants + cs_cols - 1) // cs_cols
    sheet = Image.new("RGB", (cs_cols * S, cs_rows * S), (20, 18, 16))
    for i, t in enumerate(variants):
        r, c = divmod(i, cs_cols)
        sheet.paste(Image.fromarray(t), (c * S, r * S))
    sheet.resize((cs_cols * S * 2, cs_rows * S * 2), Image.NEAREST).save(
        os.path.join(out, f"{stem}_proc_contactsheet{sfx}.png"))
    print(f"[gen] {stem}_proc_contactsheet{sfx}.png")

    # LARGE NON-REPEATING FIELD: mix variants across a wide yard span.
    rng = np.random.default_rng(args.seed + 999)
    fcols, frows = 5, 4   # 5x4 source tiles = a wide yard span
    field = tile_field(variants, fcols, frows, rng)
    Image.fromarray(field).save(os.path.join(out, f"{stem}_proc_field{sfx}.png"))
    print(f"[gen] {stem}_proc_field{sfx}.png ({fcols}x{frows} source tiles, "
          f"{field.shape[1]}x{field.shape[0]}px)")

    # FIELD AT GAME ZOOM: a 1:1 crop of the field at TRUE source-pixel scale, so the
    # Sponsor judges real stone size against a player-scale reference (no flattening
    # downsample). char_scale=0.6 player ~= 22px wide x 38px tall in source pixels;
    # a large cobble is ~55-65px => a large stone reads ~2.5 player-widths = the
    # "small player, large world" target. Crop a ~screen-sized region and 2x it.
    from PIL import ImageDraw
    crop_w, crop_h = 480, 360            # roughly a screen of the yard at source scale
    cx, cy = S // 2, S // 2              # offset crop so it straddles tile seams
    crop = Image.fromarray(field).crop((cx, cy, cx + crop_w, cy + crop_h))
    gz = crop.resize((crop_w * 2, crop_h * 2), Image.NEAREST)
    draw = ImageDraw.Draw(gz)
    pw, ph = 22 * 2, 38 * 2             # player silhouette (2x view)
    pxp, pyp = 40, 40
    draw.rectangle([pxp, pyp, pxp + pw, pyp + ph], outline=(255, 80, 40), width=3)
    draw.text((pxp, max(2, pyp - 16)), "player ~0.6", fill=(255, 130, 70))
    gz.save(os.path.join(out, f"{stem}_proc_field_zoom{sfx}.png"))
    print(f"[gen] {stem}_proc_field_zoom{sfx}.png (1:1 yard crop at game zoom + player-scale ref)")

    # SHIPPED ATLAS (#426): assemble the 768x128 6-variant atlas the painter consumes.
    # Each variant source (authored at --res, typically 384px) is downsampled to 128px
    # (a 4x4 atlas of 32px cells) and packed side by side: variant v = cols [v*4..v*4+3].
    # This makes the regen fully reproducible end-to-end (was a manual pack step in #424).
    if args.atlas_out:
        atlas_variants = args.variants
        block = 128
        atlas = Image.new("RGB", (atlas_variants * block, block), (20, 18, 16))
        for i in range(atlas_variants):
            v = variants[i] if i < len(variants) else variants[-1]
            v_img = Image.fromarray(v).resize((block, block), Image.LANCZOS)
            atlas.paste(v_img, (i * block, 0))
        atlas_path = os.path.abspath(args.atlas_out)
        os.makedirs(os.path.dirname(atlas_path), exist_ok=True)
        atlas.save(atlas_path)
        print(f"[gen] shipped atlas -> {atlas_path} ({atlas.size[0]}x{atlas.size[1]}, "
              f"{atlas_variants} variants, fine_scale={args.fine_scale})")

    print(f"\n[gen] DONE. Outputs in: {out}")


if __name__ == "__main__":
    main()
