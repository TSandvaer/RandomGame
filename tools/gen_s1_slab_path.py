#!/usr/bin/env python3
"""
S1 cloister-yard SLAB-PATH FLOOR — procedural generator (S1-YARD T8 soak-rev, #426).

Replaces the twice-rejected `floor_sandstone.png` reuse (Sponsor soak: "too big",
then "awful" = baked green moss-sprout DOTS in the joints + grid-regular identical
square pavers). Specced anew by `team/uma-ux/s1-slab-path-texture.md`:
the worn processional CUT-STONE path the monks laid + walked smooth over centuries.

WHY A DIFFERENT MODEL FROM THE COBBLE GENERATOR
  The cobble base (`gen_s1_cobble_floor.py`) uses additively-weighted toroidal
  VORONOI — the correct model for ROUNDED domed set-stones. SLABS are the opposite
  read: FLAT cut stones, fitted by hand. Per `pixellab-pipeline.md` §1102
  ("broken-ashlar flagstone" recipe, the one that broke the #407 wallpaper failure):
  *"the rectangular broken-course (ASHLAR) model is the correct shape for cut
  flagstone; Voronoi reads as angular shards/scales and is NOT."* So this script
  lays irregular rectangular pavers in jittered offset courses (ashlar), NOT Voronoi.
  Everything reusable from the cobble generator is reused: toroidal wrap (seamless by
  construction), doctrine-lock by construction, the multi-variant packed atlas.

HARD REQUIREMENTS (each prior attempt failed one)
  1. ZERO baked vegetation — joints are dirt-shadow #3D372F ONLY. The litmus test
     (spec §2): eye-dropper ANY pixel → warm-sandstone / dirt-shadow / grout, NEVER
     green. The green moss-sprout dots were the precise "awful" rejection. This
     generator has NO green field at all (PL-PATH-04 guard, GUT-pinned).
  2. IRREGULAR cut pavers, VARIED size + shape — NOT a grid of identical squares
     (the #1 rejected read). Jittered course heights + jittered stone widths +
     occasional cracked/split paver. No two adjacent pavers identical.
  3. SEAMLESS by construction — stone x-positions + course heights wrap toroidally
     (every paint op writes at (px % S, py % S)). Multi-screen processional spine
     never shows a seam.
  4. SCALE: a clear step UP from the fine cobble (~2.5-3x the largest cobble stone,
     ~45-55 screen px at game zoom) but NOT player-sized (spec §5.1). Tuned via
     `course_h` + `stone_w` against a 384px source tiled at period 4 → 32px game
     tile, so one paver renders ~2.5-3x a cobble.
  5. WARM-sandstone family, perceptibly WARMER than the cool cobble base #6E665A
     (spec §4 PL-PATH-02 "warm path through cool field" wayfinding contrast).

LOOK (spec §3)
  - Worn-smooth foot-polished CENTERS (#A89677 highlight) — where feet fell for
    centuries. Sunk/settled EDGES with a thin dirt-shadow rim (#3D372F) → each slab
    reads slightly recessed, never flush-and-new.
  - Multi-tone: each paver a slightly different warm-sandstone tone across the ramp
    (#7A6A4F base / #9A7A4E warm-trim drift), a few worn-lighter. The tonal drift IS
    the aged-and-walked-on read (village reference).
  - Carved relief: 1px lit lip on top+left of each paver, 1px shadow on bottom+right.
  - A few CRACKED/displaced pavers (a split line) tell the abandonment story.
  - Grout: thin IRREGULAR dirt-shadow lines (#3D372F deep, #5C4F38 bed), varied
    width — never a clean uniform mortar grid.

Outputs (under _tile_judge/slab_proc/ by default):
  slab_v<i>_<res>.png         — N seamless source variants
  slab_proc_seamcheck.png     — one variant tiled 3x3 (proves the wrap is seamless)
  slab_proc_contactsheet.png  — all variants side-by-side at 2x for judging
  slab_proc_field.png         — variants mixed across a wide span
  + shipped atlas via --atlas-out (the PNG the painter consumes).
"""
import argparse
import os
import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# S1_SLAB_PATH_DOCTRINE — team/uma-ux/s1-slab-path-texture.md §4 (sub-1.0 verified)
# ---------------------------------------------------------------------------
DOCTRINE = {
    "slab_base":   "#7A6A4F",  # warm sandstone, dominant paver tone (palette Floor-base)
    "slab_lit":    "#A89677",  # foot-polished worn-smooth paver center (Floor-highlight)
    "slab_deep":   "#5C4F38",  # cracks, recessed/sunk paver, grout bed (Floor-deep)
    "slab_warm":   "#9A7A4E",  # warmer paver tone for tonal drift (Trim/pillar; sparse)
    "grout":       "#3D372F",  # grout / dirt-shadow joint + sunk-edge rim (REUSE cobble joint-deep)
}


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


PAL = {k: hexrgb(v) for k, v in DOCTRINE.items()}


# ---------------------------------------------------------------------------
# Toroidal value noise (seamless) — reused from the cobble generator's approach.
# Used ONLY for subtle warm tonal drift across the field. NO green field exists.
# ---------------------------------------------------------------------------
def toroidal_value_noise(S, rng, cells, octaves=3):
    out = np.zeros((S, S), np.float32)
    amp = 1.0
    total = 0.0
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    for o in range(octaves):
        n = cells * (2 ** o)
        lattice = rng.random((n, n)).astype(np.float32)
        gx = xx / S * n
        gy = yy / S * n
        x0 = np.floor(gx).astype(int) % n
        y0 = np.floor(gy).astype(int) % n
        x1 = (x0 + 1) % n
        y1 = (y0 + 1) % n
        fx = gx - np.floor(gx)
        fy = gy - np.floor(gy)
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
# Ashlar broken-course paver layout — toroidal (seamless by construction).
# Returns a per-pixel integer "paver id" map (S,S) + a list of paver records.
# ---------------------------------------------------------------------------
def ashlar_layout(S, rng, course_h_px, stone_w_px, slab_scale=1.0):
    """
    Lay irregular rectangular pavers in jittered offset courses, wrapping toroidally.

    course_h_px / stone_w_px are the BASE paver dimensions at the source res; the
    actual per-course height and per-stone width are jittered around these. The
    `paver` map assigns each pixel to the owning paver index; grout pixels (the gaps
    between pavers) are -1. Course y-boundaries + stone x-boundaries are computed mod
    S so the pattern tiles perfectly.

    slab_scale: multiplies the base paver dims (the SCALE lever, spec §5.1).
    """
    ch = max(6.0, course_h_px * slab_scale)
    sw = max(8.0, stone_w_px * slab_scale)

    paver = np.full((S, S), -1, np.int32)
    records = []  # (cx, cy, half_w, half_h, tone_idx, worn, cracked)
    pid = 0

    # --- Build course y-boundaries that wrap toroidally. We walk y in jittered
    # steps; to wrap cleanly we force the last course to absorb the remainder so the
    # top course (y=0) and bottom course meet seamlessly. ---
    course_bounds = [0]
    y = 0.0
    while y < S - ch * 0.5:
        step = ch * rng.uniform(0.82, 1.22)
        y += step
        course_bounds.append(int(round(y)))
    # snap the last boundary to S so the field is fully covered and wraps
    course_bounds[-1] = S
    n_courses = len(course_bounds) - 1

    grout_w = max(1.0, 1.4 * slab_scale)  # thin mortar gap (px)

    for ci in range(n_courses):
        y0 = course_bounds[ci]
        y1 = course_bounds[ci + 1]
        cy = (y0 + y1) * 0.5
        hh = (y1 - y0) * 0.5

        # Per-course phase offset so courses are BROKEN (offset), never aligned grid.
        phase = rng.uniform(0.0, sw)
        # Walk x across the course in jittered stone widths, wrapping at S.
        x = -phase
        while x < S:
            w = sw * rng.uniform(0.72, 1.45)
            x0 = x
            x1 = x + w
            cx = (x0 + x1) * 0.5
            hw = w * 0.5

            tone_idx = int(rng.integers(0, 3))      # base / warm / (base again)
            worn = rng.random() < 0.22               # foot-polished lighter paver
            cracked = rng.random() < 0.14            # a split/displaced paver
            records.append((cx % S, cy, hw, hh, tone_idx, worn, cracked, pid))

            # Stamp this paver into the id map, inset by the grout gap, toroidally.
            yy0 = int(np.ceil(y0 + grout_w * 0.5))
            yy1 = int(np.floor(y1 - grout_w * 0.5))
            xx0 = int(np.ceil(x0 + grout_w * 0.5))
            xx1 = int(np.floor(x1 - grout_w * 0.5))
            for py in range(yy0, yy1):
                pym = py % S
                for px in range(xx0, xx1):
                    paver[pym, px % S] = pid
            pid += 1
            x = x1

    return paver, records


# ---------------------------------------------------------------------------
# The slab tile
# ---------------------------------------------------------------------------
def make_slab_tile(seed, S=384, slab_scale=1.0, warm_drift=0.06,
                   warm_push=0.10, lighten=1.16):
    """
    Generate ONE seamless ashlar slab-path tile (S x S, RGB uint8).

    ZERO green by construction: every color drawn is from S1_SLAB_PATH_DOCTRINE
    (warm-sandstone / grout dirt-shadow). There is NO vegetation field.

    warm_push / lighten (#426 in-context calibration): the SHIPPED cobble atlas was
    lightened+warmed to mean ~(150,127,95) warmth R-B=55 (well beyond its #6E665A
    doctrine base). To keep the spec §4 PL-PATH-02 "warm PATH through cool FIELD"
    wayfinding contrast against the REAL shipped cobble (not the doctrine-base
    assumption), the slab is pushed WARMER (raise R, drop B → R-B clearly exceeds the
    cobble's 55) and lifted in brightness so it reads as a distinct deliberate warm
    ribbon, not a dark cool trench. Stays inside the warm-sandstone ramp (no green —
    PL-PATH-04 still holds; only R/B balance + brightness shift).
    """
    rng = np.random.default_rng(seed)
    k = S / 384.0

    # Base paver dims tuned at 384px source / period-4 atlas so one paver renders
    # ~2.5-3x the largest cobble (~45-55 screen px) — the spec §5.1 scale step-up.
    # A 384px source over a period-4 32px tile = 3px source → 1px game; the largest
    # cobble is ~18 screen px, so a paver footprint of ~150-190 source px reads
    # ~45-55 screen px. course_h ~52 / stone_w ~64 hits that band.
    paver, records = ashlar_layout(
        S, rng, course_h_px=52.0 * k, stone_w_px=64.0 * k, slab_scale=slab_scale
    )

    # Subtle warm tonal-drift field (NOT green) so the field isn't one flat tone —
    # the village-reference "cream/tan/grey blended" read, kept inside the warm ramp.
    drift = toroidal_value_noise(S, rng, cells=2, octaves=2)  # 0..1

    # Apply the warm-push + lighten so the slab reads as a warm ribbon against the
    # bright-warm shipped cobble (see docstring). warm_vec raises R, drops B; lighten
    # lifts overall. Re-clamped sub-1.0 (HDR-safe). Grout is left near its doctrine
    # dirt-shadow (only mildly lifted) so the joints stay a believable recess.
    warm_vec = np.array([warm_push, warm_push * 0.18, -warm_push * 0.95], np.float32) * 255.0

    def tune(c, lift=lighten):
        return np.clip((c + warm_vec) * lift, 0, 255)

    base = tune(PAL["slab_base"])
    warm = tune(PAL["slab_warm"])
    lit = tune(PAL["slab_lit"])
    deep = tune(PAL["slab_deep"], lift=1.0)            # cracks stay dark
    grout = tune(PAL["grout"], lift=1.04)              # joints stay a recess

    img = np.empty((S, S, 3), np.float32)
    # Fill everything with grout first; pavers overwrite their interiors → the
    # remaining grout pixels are the irregular dirt-shadow joints (dirt-shadow ONLY).
    img[:, :] = grout

    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)

    # Per-paver fill with worn centers + sunk edges + carved relief, drawn paver by
    # paver. Build a center-distance falloff per paver for the foot-polish dome.
    for (cx, cy, hw, hh, tone_idx, worn, cracked, pid) in records:
        mask = paver == pid
        if not mask.any():
            continue
        # paver base tone (multi-tone drift)
        if worn:
            col = lit.copy()
        elif tone_idx == 1:
            col = warm.copy()
        else:
            col = base.copy()
        # tonal jitter per paver (within the warm ramp, never green)
        jit = rng.uniform(-0.07, 0.09)
        col = np.clip(col * (1.0 + jit), 0, 255)

        ys, xs = np.where(mask)
        # toroidal-aware local coords relative to paver center
        dx = ((xs - cx + S / 2) % S) - S / 2
        dy = ((ys - cy + S / 2) % S) - S / 2
        # normalized distance to paver edge (1 at center, 0 at rim). Use a SMOOTH
        # super-elliptical falloff (product of smoothstepped axes, NOT min) so the
        # foot-polish reads as a soft worn pool, NOT a stamped X/bowtie cross — the
        # min() falloff produced a visible diagonal artifact at every paver center.
        nxr = np.clip(1.0 - np.abs(dx) / max(hw, 1.0), 0, 1)
        nyr = np.clip(1.0 - np.abs(dy) / max(hh, 1.0), 0, 1)
        # smoothstep each axis then multiply → rounded-rectangle worn pool
        sx = nxr * nxr * (3 - 2 * nxr)
        sy = nyr * nyr * (3 - 2 * nyr)
        center_f = sx * sy  # 0 at rim, 1 at center, smoothly rounded

        # foot-polished worn center: the center is the BRIGHT highlight (where a
        # thousand feet polished the stone smooth, spec §3.1); the read is bright
        # CENTER fading to a sunk dark rim — NOT a dark blotch. Blend strongly toward
        # the lit tone over the worn pool.
        polish = np.clip((center_f - 0.12) / 0.88, 0, 1)[:, None]
        px_col = col[None, :] * (1 - polish) + lit[None, :] * polish

        # sunk edge: darken a thin rim toward grout (dirt-shadow), so each slab reads
        # recessed/settled, never flush. Threshold on the per-axis nearness (not the
        # product) so the rim is a uniform thin band on all four edges.
        rim = (nxr < 0.13) | (nyr < 0.13)
        px_col[rim] = px_col[rim] * 0.58 + grout[None, :] * 0.42

        # carved relief (settled, not new): a subtle SHADOW on the bottom+right edges
        # only (the paver sank that way). NO bright top-left lip — that fought the
        # worn-bright-center read and made edges read brighter than centers.
        sha = (dy > hh * 0.74) | (dx > hw * 0.80)
        px_col[sha] = px_col[sha] * 0.82

        # a cracked/displaced paver: a dark split line through it (story of abandonment)
        if cracked:
            # crack along a jittered diagonal in local coords
            ang = rng.uniform(0.3, 1.3)
            line = np.abs(dx * np.sin(ang) - dy * np.cos(ang))
            crack = line < (1.2 * k)
            px_col[crack] = deep[None, :]

        # apply subtle warm drift (raise/lower brightness a hair, hue stays warm)
        d = (drift[ys, xs] - 0.5) * 2.0 * warm_drift
        px_col = np.clip(px_col * (1.0 + d[:, None]), 0, 255)

        img[ys, xs] = px_col

    return np.clip(img, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------------------
# Preview assembly (mirrors the cobble generator's judge outputs)
# ---------------------------------------------------------------------------
def tile_field(variants, cols, rows, rng):
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


def assert_zero_green(variants):
    """Hard guard (PL-PATH-04): NO pixel may read green (G dominant over R and B).
    Mirrors the GUT regression guard so the gen self-fails before shipping a green
    pixel. Warm-sandstone always has R >= G >= B; grout is near-neutral-warm. A green
    pixel would have G > R — fail loudly."""
    for i, v in enumerate(variants):
        r = v[:, :, 0].astype(np.int32)
        g = v[:, :, 1].astype(np.int32)
        b = v[:, :, 2].astype(np.int32)
        # green = G clearly exceeds R (warm sandstone never does this)
        green = (g > r + 4) & (g > b + 4)
        n = int(green.sum())
        if n > 0:
            raise SystemExit(
                "PL-PATH-04 VIOLATION: variant %d has %d green pixel(s) — the rejected"
                " baked-vegetation class. Regen aborted." % (i, n)
            )
    print("[gen] PL-PATH-04 OK — zero green pixels across all variants.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="output dir")
    ap.add_argument("--res", type=int, default=384, help="source tile resolution")
    ap.add_argument("--variants", type=int, default=4)
    ap.add_argument("--seed", type=int, default=4200)
    ap.add_argument("--slab-scale", type=float, default=1.0, dest="slab_scale",
                    help="paver-size multiplier (spec §5.1 scale lever; 1.0 = tuned target)")
    ap.add_argument("--warm-push", type=float, default=0.10, dest="warm_push",
                    help="warm-ribbon push (raise R, drop B) so the slab reads WARMER than "
                         "the bright-warm shipped cobble (PL-PATH-02); 0.10 = calibrated")
    ap.add_argument("--lighten", type=float, default=1.16,
                    help="overall brightness lift so the slab reads a warm ribbon not a "
                         "dark trench against the lightened cobble; 1.16 = calibrated")
    ap.add_argument("--suffix", default="")
    ap.add_argument("--atlas-out", default=None, dest="atlas_out",
                    help="if set, also assemble the shipped <variants*128>x128 atlas PNG "
                         "(each source variant downsampled to 128px = a 4x4 atlas of 32px "
                         "cells, packed side by side) — the file the painter consumes")
    args = ap.parse_args()
    sfx = ("_" + args.suffix) if args.suffix else ""

    here = os.path.dirname(os.path.abspath(__file__))
    out = args.out or os.path.join(here, "..", "_tile_judge", "slab_proc")
    out = os.path.abspath(out)
    os.makedirs(out, exist_ok=True)

    S = args.res
    print(f"[gen] generating {args.variants} seamless ashlar slab variants @ {S}px "
          f"(slab_scale={args.slab_scale}) ...")
    variants = []
    for i in range(args.variants):
        t = make_slab_tile(args.seed + i * 17, S=S, slab_scale=args.slab_scale,
                           warm_push=args.warm_push, lighten=args.lighten)
        variants.append(t)
        Image.fromarray(t).save(os.path.join(out, f"slab{sfx}_v{i}_{S}.png"))
        print(f"  - slab{sfx}_v{i}_{S}.png")

    # PL-PATH-04 self-guard: abort if any green pixel slipped in.
    assert_zero_green(variants)

    # SEAMCHECK: variant 0 tiled 3x3 — must show NO grid/seam.
    v0 = variants[0]
    seam = np.tile(v0, (3, 3, 1))
    Image.fromarray(seam).save(os.path.join(out, f"slab_proc_seamcheck{sfx}.png"))
    print(f"[gen] slab_proc_seamcheck{sfx}.png (variant 0 tiled 3x3 — seam test)")

    # CONTACT SHEET: all variants at 2x for material judging.
    cs_cols = min(2, args.variants)
    cs_rows = (args.variants + cs_cols - 1) // cs_cols
    sheet = Image.new("RGB", (cs_cols * S, cs_rows * S), (20, 18, 16))
    for i, t in enumerate(variants):
        r, c = divmod(i, cs_cols)
        sheet.paste(Image.fromarray(t), (c * S, r * S))
    sheet.resize((cs_cols * S * 2, cs_rows * S * 2), Image.NEAREST).save(
        os.path.join(out, f"slab_proc_contactsheet{sfx}.png"))
    print(f"[gen] slab_proc_contactsheet{sfx}.png")

    # NON-REPEATING FIELD: mix variants across a span.
    rng = np.random.default_rng(args.seed + 999)
    field = tile_field(variants, 4, 3, rng)
    Image.fromarray(field).save(os.path.join(out, f"slab_proc_field{sfx}.png"))
    print(f"[gen] slab_proc_field{sfx}.png")

    # SHIPPED ATLAS: assemble the (variants*128)x128 packed atlas the painter consumes.
    # Each 384px source variant downsampled to 128px (a 4x4 atlas of 32px cells);
    # packed side by side: variant v = atlas columns [v*4 .. v*4+3] (same layout as
    # the cobble atlas, so S1YardChunk's block-variant scatter applies identically).
    if args.atlas_out:
        block = 128
        atlas = Image.new("RGB", (args.variants * block, block), (20, 18, 16))
        for i in range(args.variants):
            v_img = Image.fromarray(variants[i]).resize((block, block), Image.LANCZOS)
            atlas.paste(v_img, (i * block, 0))
        atlas_path = os.path.abspath(args.atlas_out)
        os.makedirs(os.path.dirname(atlas_path), exist_ok=True)
        atlas.save(atlas_path)
        print(f"[gen] shipped atlas -> {atlas_path} ({atlas.size[0]}x{atlas.size[1]}, "
              f"{args.variants} variants)")

    print(f"\n[gen] DONE. Outputs in: {out}")


if __name__ == "__main__":
    main()
