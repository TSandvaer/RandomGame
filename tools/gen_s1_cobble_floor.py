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
def make_cobble_tile(seed, S=256, warm_bias=0.05, lighten=1.20,
                     moss_amount=1.0, dirt_amount=1.0):
    """
    Generate ONE seamless varied-size cobble tile (S x S, RGB uint8).

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
    radii_plan = [
        # (count, min_radius_px, weight)  weight feeds additively-weighted Voronoi
        (70,  15 * k, 8.0 * k),   # LARGER cobbles  (still the dominant set-stones, but small)
        (150,  9 * k, 4.5 * k),   # MEDIUM cobbles
        (320,  6 * k, 2.2 * k),   # SMALL cobbles
        (650, 3.6 * k, 1.0 * k),  # PEBBLES packed into the gaps
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

    cobble_base_t = tune(PAL["cobble_base"])
    cobble_lit_t = tune(PAL["cobble_lit"])
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
    shp = tune(PAL["cobble_shadow"]) * 0.5 + cobble_base_t * 0.5
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
    joint_col = tune(PAL["cobble_shadow"]) * 0.55 + cobble_base_t * 0.45
    deep_col = tune(PAL["joint_deep"]) * 0.45 + cobble_base_t * 0.55
    img[joint] = joint_col
    img[deep] = deep_col
    # ambient-occlusion darkening just inside each stone next to a joint (gentler,
    # and a thinner band so the dense small stones don't read AO-heavy).
    ao = (border >= joint_w) & (border < joint_w * 1.8)
    img[ao] *= 0.97

    # --- ORGANIC INVASION: moss + dirt (clustered toroidal-noise driven) -------
    # Both are INVASION accents, not carpets: doctrine says moss CREEPS in joints
    # and clusters in damp patches; dirt is where stones have SUNK/gone missing.
    # Keep total coverage modest so the cobble material stays the dominant read.
    moss_field = toroidal_value_noise(S, np.random.default_rng(seed * 7 + 1), cells=3, octaves=4)
    dirt_field = toroidal_value_noise(S, np.random.default_rng(seed * 13 + 5), cells=2, octaves=4)

    # DIRT: rare sunk patches — only the strongest field peaks, biased to small stones.
    # v2: slightly rarer + tuned (lighter/warmer) so it sits in the lighter floor.
    dirt_thresh = 0.86 - 0.07 * dirt_amount
    small_stone = w_own < (9 * k)                        # pebbles/small = more likely sunk
    dirt_mask = (dirt_field > dirt_thresh) & (small_stone | (dirt_field > dirt_thresh + 0.07))
    dd = dirt_mask & (joint | (dirt_field > dirt_thresh + 0.10))
    img[dirt_mask] = tune(PAL["dirt"])
    img[dd] = tune(PAL["dirt_deep"])
    spk = dirt_mask & (rng.random((S, S)) < 0.22)        # speckle so dirt isn't flat
    img[spk] = np.clip(tune(PAL["dirt_deep"]) * 1.10, 0, 255)

    # MOSS: confined to CLUSTERED damp zones (where the moss field is genuinely
    # high) so it reads as patches of invasion, NOT green grout in every joint.
    # Within a damp zone it creeps along the joints + spills a little onto stone.
    # v2: damp gate raised slightly (a touch less moss so it doesn't dominate the
    # lighter floor). Moss stays olive-green (NOT warm-tuned) but lightened ~8% to
    # sit consistently in the lighter cobble.
    moss_c = np.clip(PAL["moss"] * 1.08, 0, 255)
    moss_deep_c = np.clip(PAL["moss_deep"] * 1.08, 0, 255)
    # FINE-COBBLE: raise the damp gate so moss stays a sparse CLUSTERED accent (the
    # dense joints would otherwise carry green grout everywhere, dominating the grey).
    damp = moss_field > (0.80 - 0.10 * moss_amount)       # the damp-cluster gate (raised)
    moss_in_joint = joint & damp                          # joint creep WITHIN damp zones
    moss_cluster = (moss_field > (0.88 - 0.06 * moss_amount)) & (rng.random((S, S)) < 0.40)
    moss_mask = (moss_in_joint | moss_cluster) & (~dirt_mask)
    moss_deep_mask = moss_mask & (deep | (moss_field > 0.86))
    img[moss_mask] = moss_c
    img[moss_deep_mask] = moss_deep_c
    tuft = moss_mask & (rng.random((S, S)) < 0.22)       # lighter olive tuft tips
    img[tuft] = np.clip(PAL["moss"] * 1.26, 0, 255)

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
    ap.add_argument("--warm", type=float, default=0.05,
                    help="warm-neutral grey bias 0..0.10 (kills the blue/cool cast)")
    ap.add_argument("--lighten", type=float, default=1.20,
                    help="overall brighten multiplier on cobble stone colors (1.0=v1)")
    ap.add_argument("--suffix", default="",
                    help="filename suffix for output set (e.g. v2) to keep prior renders")
    args = ap.parse_args()
    sfx = ("_" + args.suffix) if args.suffix else ""

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
        t = make_cobble_tile(args.seed + i * 17, S=S, warm_bias=args.warm,
                             lighten=args.lighten, moss_amount=moss_a, dirt_amount=dirt_a)
        variants.append(t)
        Image.fromarray(t).save(os.path.join(out, f"cobble{sfx}_v{i}_{S}.png"))
        print(f"  - cobble{sfx}_v{i}_{S}.png")

    # SEAMCHECK: one variant tiled 3x3 — must show NO grid/seam.
    v0 = variants[0]
    seam = np.tile(v0, (3, 3, 1))
    Image.fromarray(seam).save(os.path.join(out, f"cobble_proc_seamcheck{sfx}.png"))
    print(f"[gen] cobble_proc_seamcheck{sfx}.png (variant 0 tiled 3x3 — seam test)")

    # CONTACT SHEET: all variants at 2x for material judging.
    cs_cols = min(3, args.variants)
    cs_rows = (args.variants + cs_cols - 1) // cs_cols
    sheet = Image.new("RGB", (cs_cols * S, cs_rows * S), (20, 18, 16))
    for i, t in enumerate(variants):
        r, c = divmod(i, cs_cols)
        sheet.paste(Image.fromarray(t), (c * S, r * S))
    sheet.resize((cs_cols * S * 2, cs_rows * S * 2), Image.NEAREST).save(
        os.path.join(out, f"cobble_proc_contactsheet{sfx}.png"))
    print(f"[gen] cobble_proc_contactsheet{sfx}.png")

    # LARGE NON-REPEATING FIELD: mix variants across a wide yard span.
    rng = np.random.default_rng(args.seed + 999)
    fcols, frows = 5, 4   # 5x4 source tiles = a wide yard span
    field = tile_field(variants, fcols, frows, rng)
    Image.fromarray(field).save(os.path.join(out, f"cobble_proc_field{sfx}.png"))
    print(f"[gen] cobble_proc_field{sfx}.png ({fcols}x{frows} source tiles, "
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
    gz.save(os.path.join(out, f"cobble_proc_field_zoom{sfx}.png"))
    print(f"[gen] cobble_proc_field_zoom{sfx}.png (1:1 yard crop at game zoom + player-scale ref)")

    print(f"\n[gen] DONE. Outputs in: {out}")


if __name__ == "__main__":
    main()
