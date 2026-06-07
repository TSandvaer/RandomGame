#!/usr/bin/env python3
"""
S1 cloister-yard COBBLE FLOOR — procedural generator (T1, ticket 86ca5erva).

Sponsor decision 2026-06-07: procedural over PixelLab. PixelLab's seamless Wang
tool caps at 32px/tile; the Sponsor wants HIGHER-quality (higher-res + seamless +
genuinely varied). Procedural delivers all three.

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
def make_cobble_tile(seed, S=256, cool_bias=0.06, moss_amount=1.0, dirt_amount=1.0):
    """
    Generate ONE seamless varied-size cobble tile (S x S, RGB uint8).

    cool_bias: 0..~0.12 — shifts stone toward cooler/greyer per Sponsor reference
               (lower R, raise B slightly) without leaving sub-1.0.
    moss_amount / dirt_amount: scale the organic invasion (1.0 = doctrine default).
    """
    rng = np.random.default_rng(seed)

    # Varied stone-size plan, scaled to source res. Counts/radii tuned at 256px.
    # Large + medium + small + pebbles => chaotic natural mix, NO uniform sizing.
    k = S / 256.0
    # Fewer, BIGGER stones so the varied-size read survives the downsample to a
    # 32px in-engine tile. Still a chaotic mix (large+medium+small+pebble), no rows.
    radii_plan = [
        # (count, min_radius_px, weight)  weight feeds additively-weighted Voronoi
        (5,  58 * k, 30 * k),   # LARGE cobbles  (sparse, dominant set-stones)
        (11, 38 * k, 17 * k),   # MEDIUM cobbles
        (22, 25 * k,  9 * k),   # SMALL cobbles
        (40, 15 * k,  3 * k),   # PEBBLES packed into the gaps
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

    # --- base stone color, per-stone tone jitter + a few worn-lighter stones ---
    tone = rng.uniform(-0.10, 0.12, n).astype(np.float32)
    worn = (rng.random(n) < 0.20)                        # foot-worn lighter stones
    base = PAL["cobble_base"].copy()
    # cool/grey bias: pull red down, nudge blue up (stays sub-1.0)
    base = base + np.array([-cool_bias, 0.0, cool_bias * 0.6], np.float32) * 255.0
    base = np.clip(base, 0, 255)

    img = np.empty((S, S, 3), np.float32)
    stone_col = np.empty((n, 3), np.float32)
    for i in range(n):
        c = (PAL["cobble_lit"] if worn[i] else base) * (1.0 + tone[i])
        if worn[i]:
            c = c + np.array([-cool_bias, 0, cool_bias * 0.6], np.float32) * 200.0
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
    # stronger contrast so the domes survive the downsample to 32px tiles
    light = 0.80 + 0.34 * dome + 0.22 * np.clip(ndl, -1, 1)

    lit = PAL["cobble_lit"]
    shp = PAL["cobble_shadow"]
    # blend toward lit at the upper-left dome tops, toward shadow at the rims/bases
    t_lit = np.clip((light - 1.05) * 1.8, 0, 1)[:, :, None]
    t_shp = np.clip((0.92 - light) * 1.7, 0, 1)[:, :, None]
    img = img * light[:, :, None]
    img = img * (1 - t_lit) + lit * t_lit
    img = img * (1 - t_shp) + shp * t_shp

    # --- JOINTS between stones (recessed dark gaps, irregular width) -----------
    joint_w = 2.6 * k
    joint = border < joint_w
    deep = border < (joint_w * 0.55)
    img[joint] = PAL["cobble_shadow"] * 0.92
    img[deep] = PAL["joint_deep"]
    # ambient-occlusion darkening just inside each stone next to a joint
    ao = (border >= joint_w) & (border < joint_w * 2.4)
    img[ao] *= 0.90

    # --- ORGANIC INVASION: moss + dirt (clustered toroidal-noise driven) -------
    # Both are INVASION accents, not carpets: doctrine says moss CREEPS in joints
    # and clusters in damp patches; dirt is where stones have SUNK/gone missing.
    # Keep total coverage modest so the cobble material stays the dominant read.
    moss_field = toroidal_value_noise(S, np.random.default_rng(seed * 7 + 1), cells=3, octaves=4)
    dirt_field = toroidal_value_noise(S, np.random.default_rng(seed * 13 + 5), cells=2, octaves=4)

    # DIRT: rare sunk patches — only the strongest field peaks, biased to small stones.
    dirt_thresh = 0.84 - 0.07 * dirt_amount
    small_stone = w_own < (9 * k)                        # pebbles/small = more likely sunk
    dirt_mask = (dirt_field > dirt_thresh) & (small_stone | (dirt_field > dirt_thresh + 0.07))
    dd = dirt_mask & (joint | (dirt_field > dirt_thresh + 0.10))
    img[dirt_mask] = PAL["dirt"]
    img[dd] = PAL["dirt_deep"]
    spk = dirt_mask & (rng.random((S, S)) < 0.22)        # speckle so dirt isn't flat
    img[spk] = np.clip(PAL["dirt_deep"] * 1.10, 0, 255)

    # MOSS: confined to CLUSTERED damp zones (where the moss field is genuinely
    # high) so it reads as patches of invasion, NOT green grout in every joint.
    # Within a damp zone it creeps along the joints + spills a little onto stone.
    damp = moss_field > (0.70 - 0.10 * moss_amount)       # the damp-cluster gate
    moss_in_joint = joint & damp                          # joint creep WITHIN damp zones
    moss_cluster = (moss_field > (0.82 - 0.06 * moss_amount)) & (rng.random((S, S)) < 0.50)
    moss_mask = (moss_in_joint | moss_cluster) & (~dirt_mask)
    moss_deep_mask = moss_mask & (deep | (moss_field > 0.84))
    img[moss_mask] = PAL["moss"]
    img[moss_deep_mask] = PAL["moss_deep"]
    tuft = moss_mask & (rng.random((S, S)) < 0.22)       # lighter olive tuft tips
    img[tuft] = np.clip(PAL["moss"] * 1.16, 0, 255)

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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="output dir")
    ap.add_argument("--res", type=int, default=256, help="source tile resolution")
    ap.add_argument("--variants", type=int, default=6)
    ap.add_argument("--seed", type=int, default=1000)
    ap.add_argument("--cool", type=float, default=0.06, help="cooler/greyer bias 0..0.12")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    out = args.out or os.path.join(here, "..", "_tile_judge", "cobble_proc")
    out = os.path.abspath(out)
    os.makedirs(out, exist_ok=True)

    S = args.res
    print(f"[gen] generating {args.variants} seamless cobble variants @ {S}px ...")
    variants = []
    for i in range(args.variants):
        # vary moss/dirt amount per variant => repeat-breaker accents
        moss_a = 1.0 + (0.4 if i == args.variants - 1 else 0.0)   # last = heavy-moss accent
        dirt_a = 1.0 + (0.5 if i == args.variants - 2 else 0.0)   # 2nd-last = dirt-through accent
        t = make_cobble_tile(args.seed + i * 17, S=S, cool_bias=args.cool,
                             moss_amount=moss_a, dirt_amount=dirt_a)
        variants.append(t)
        Image.fromarray(t).save(os.path.join(out, f"cobble_v{i}_{S}.png"))
        print(f"  - cobble_v{i}_{S}.png")

    # SEAMCHECK: one variant tiled 3x3 — must show NO grid/seam.
    v0 = variants[0]
    seam = np.tile(v0, (3, 3, 1))
    Image.fromarray(seam).save(os.path.join(out, "cobble_proc_seamcheck.png"))
    print("[gen] cobble_proc_seamcheck.png (variant 0 tiled 3x3 — seam test)")

    # CONTACT SHEET: all variants at 2x for material judging.
    cs_cols = min(3, args.variants)
    cs_rows = (args.variants + cs_cols - 1) // cs_cols
    sheet = Image.new("RGB", (cs_cols * S, cs_rows * S), (20, 18, 16))
    for i, t in enumerate(variants):
        r, c = divmod(i, cs_cols)
        sheet.paste(Image.fromarray(t), (c * S, r * S))
    sheet.resize((cs_cols * S * 2, cs_rows * S * 2), Image.NEAREST).save(
        os.path.join(out, "cobble_proc_contactsheet.png"))
    print("[gen] cobble_proc_contactsheet.png")

    # LARGE NON-REPEATING FIELD: mix variants across a wide yard span.
    rng = np.random.default_rng(args.seed + 999)
    fcols, frows = 5, 4   # 5x4 source tiles = a wide yard span
    field = tile_field(variants, fcols, frows, rng)
    Image.fromarray(field).save(os.path.join(out, "cobble_proc_field.png"))
    print(f"[gen] cobble_proc_field.png ({fcols}x{frows} source tiles, "
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
    gz.save(os.path.join(out, "cobble_proc_field_zoom.png"))
    print("[gen] cobble_proc_field_zoom.png (1:1 yard crop at game zoom + player-scale ref)")

    print(f"\n[gen] DONE. Outputs in: {out}")


if __name__ == "__main__":
    main()
