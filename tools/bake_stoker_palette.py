#!/usr/bin/env python
"""Bake Stoker palette-swap atlas from Grunt v2 source frames.

Implements M3W-6 Path A (pre-bake separate atlas) per
`team/DECISIONS.md` 2026-05-18 + `team/priya-pl/m3-scene-wiring-scope.md
§M3W-6`. Reads every PNG under
`assets/sprites/grunt/_pixellab_anims/Grunt_v2_S1_Embergrave_red-eyes/animations/`
and writes a doctrine-locked S2 retint to the mirror path under
`assets/sprites/stoker/_pixellab_anims/Stoker_S2_Cinder_Vaults/animations/`.

Mechanism: per-source-color nearest-neighbor mapping (Euclidean RGB
distance) against the Stoker S2 doctrine palette below. The Grunt v2
atlas is NOT doctrine-locked at source (501 distinct colors in raw); we
build a fixed source→target map once, then walk every pixel.

Doctrine palette ANCHORS (Uma `team/uma-ux/palette-stratum-2.md §2 +
§5 line 191`):
    cloth: #7A1F12   (heat-corroded smock)
    skin:  #7E5A40   (sun-scorched mid)
    aggro: #D24A3C   (UNCHANGED — cross-stratum tester pin PL-11)
    iron:  #9C9590   (UNCHANGED — same metalwork era)

Extension hexes below add per-role shadow + highlight tones so the
nearest-neighbor map preserves tonal structure. Per
`.claude/docs/pixel-mcp-pipeline.md §"Per-sprite palette extension rule"`
extensions trace to the stratum ramp; file a palette amendment if the
nearest existing hex doesn't cover the needed dark.

Character-beat override (per
`.claude/docs/pixellab-pipeline.md §"Strategy 3 refinement — manual
override for character-beat preservation"`): pure Euclidean would route
the dim red-shadow cluster (#6B1114, #270B08-ish reds) to a brown — we
force-route the red cluster to `#D24A3C` aggro-glow to preserve the
eye-glow beat. Reds are detected by R > 1.5 * max(G, B) so the routing
fires on the eye-glow family and nothing else.

HTML5 HDR-clamp rule per `.claude/docs/html5-export.md §"HDR modulate
clamp"`: every target hex has all channels in [0, 1] sub-1.0 (max R is
0xFF=255, but only as one channel; this is a TEXTURE pixel value not a
modulate tint — Sprite.modulate stays Color.WHITE at rest, so the
HDR-clamp rule on tints doesn't bind us here, but the bake values
themselves are safe sRGB pixels).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from PIL import Image

# Project paths — forward slashes per `.claude/docs/pixel-mcp-pipeline.md
# §"Windows path escape"`.
REPO_ROOT = Path("C:/Trunk/PRIVATE/RandomGame-devon-wt")
SRC_ROOT = (
    REPO_ROOT
    / "assets/sprites/grunt/_pixellab_anims/Grunt_v2_S1_Embergrave_red-eyes/animations"
)
DST_ROOT = (
    REPO_ROOT
    / "assets/sprites/stoker/_pixellab_anims/Stoker_S2_Cinder_Vaults/animations"
)

# Stoker S2 doctrine palette — sRGB hex anchors + role-specific extensions.
# Each entry is (hex, role) for traceability.
STOKER_DOCTRINE = [
    # Outlines + deep shadow — keep cross-stratum dark anchors (S2 vignette is
    # `#0A0404` warm-black per palette-stratum-2.md §2). Pure black retained
    # for outline since the Grunt source uses #000000 as line art.
    ("#000000", "outline"),
    ("#0A0404", "deep_shadow_warm"),
    ("#1A0A06", "cloth_deepest"),       # darker than cloth_shadow, warmer than pure black
    # Cloth family — heat-corroded smock
    ("#3D0A06", "cloth_shadow"),        # extension darker than cloth base
    ("#5A1108", "cloth_mid_shadow"),    # extension mid-shadow
    ("#7A1F12", "cloth_base"),          # ANCHOR — S2 mob cloth
    ("#A93020", "cloth_highlight"),     # extension lit cloth
    # Skin family — sun-scorched mid
    ("#4A2F1E", "skin_shadow"),         # extension darker than skin base
    ("#7E5A40", "skin_base"),           # ANCHOR — S2 mob skin
    ("#B08660", "skin_highlight"),      # extension lit skin
    # Aggro eye-glow — cross-stratum constant per palette.md PL-11
    ("#D24A3C", "aggro_eye_glow"),
    # Weapon edge — iron
    ("#9C9590", "iron_weapon"),
]

DOCTRINE_RGB = [
    (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), role)
    for h, role in STOKER_DOCTRINE
]

# Threshold for "this source pixel is part of the red eye-glow family"
# per character-beat override rule. Detect saturated red dominance.
def is_red_glow(r: int, g: int, b: int) -> bool:
    # Reds where R clearly dominates and source is not near-black.
    if r < 80:
        return False
    return r > 1.5 * max(g, b)


def is_iron_neutral(r: int, g: int, b: int) -> bool:
    """Iron weapon-edge pixels are near-grey neutrals — R≈G≈B in mid-tone.
    Source palette: weapon edges sit at #9C9590-#B8AEB2 range. Detection:
    channels within 16 of each other AND mid-value (R between 120 and 200).
    """
    if not (120 <= r <= 200):
        return False
    spread = max(r, g, b) - min(r, g, b)
    return spread < 16


def role_for_source(r: int, g: int, b: int) -> str:
    """Classify a source pixel by luminance into a doctrine ROLE bucket.

    Pure Euclidean nearest-neighbor breaks the doctrine-ramp intent for
    Grunt → Stoker because the source's dominant brown clusters are
    perceptually closer to S2 skin (#7E5A40) than S2 cloth (#7A1F12) —
    but the Grunt is HOODED, so those browns ARE cloth, not skin. Per
    `pixellab-pipeline.md §"Nearest-neighbor breaks doctrine-ramp intent
    for mid-tones — bias toward dark"`, we route by role-via-luminance
    instead of pure RGB distance for the dominant body clusters.

    Returns a role tag matching STOKER_DOCTRINE; the caller picks the
    hex from the role.
    """
    # Character-beat: red eye-glow family. Force to aggro hex.
    if is_red_glow(r, g, b):
        return "aggro_eye_glow"
    # Weapon edge — neutral grey in the mid-luminance band.
    if is_iron_neutral(r, g, b):
        return "iron_weapon"
    # Luminance per Rec. 601 (matches `pixellab-pipeline.md §"Strategy 2"`).
    Y = 0.299 * r + 0.587 * g + 0.114 * b
    # Ramp routing — the Grunt source is HOODED, so the dominant
    # body-color clusters are cloth (smock + hood), not skin. Route by
    # luminance bands matched to S2 cloth ramp.
    #
    # Source distribution (Grunt v2 atlas):
    #   #000000  Y=  0   outline           (36.80%)
    #   #392F32  Y= 49   cloth deep shadow (24.95%)
    #   #1D1C1E  Y= 29   pure deep shadow  ( 6.02%)
    #   #574445  Y= 70   cloth mid-shadow  ( 3.95%)
    #   #68504F  Y= 86   cloth base        (20.60%)
    #   #896B64  Y=112   cloth highlight   ( 3.71%)
    #   #AB8271  Y=143   skin mid          ( 0.27%)
    #   #B19585  Y=156   skin highlight    ( 0.24%)
    #
    # Skin is exposed-only on small face fragments visible through the
    # hood; cloth dominates. Use luminance bands tuned to this layout:
    if Y < 12:
        return "outline"            # #000000 outline — keep darkest
    if Y < 40:
        return "deep_shadow_warm"   # #1A0A06 — was #1D1C1E pure-dark
    if Y < 60:
        return "cloth_deepest"      # #1A0A06 / #3D0A06 — was #392F32 dark cloth
    if Y < 80:
        return "cloth_mid_shadow"   # #5A1108 — was #574445 cloth mid-dark
    if Y < 100:
        return "cloth_base"         # #7A1F12 — was #68504F cloth base (DOMINANT)
    if Y < 125:
        return "cloth_highlight"    # #A93020 — was #896B64 cloth highlight
    if Y < 150:
        return "skin_base"          # #7E5A40 — was #AB8271 skin mid (exposed face)
    return "skin_highlight"          # #B08660 — was #B19585 skin highlight


ROLE_TO_RGB: dict[str, tuple[int, int, int]] = {
    role: (r, g, b) for (r, g, b, role) in DOCTRINE_RGB
}
# Map collapse: ramp roles can share a target hex if two consecutive
# bands route to the same doctrine entry (e.g. deep_shadow_warm and
# cloth_deepest both at the dark end). Done via the doctrine table
# above — verify by lookup.
assert "outline" in ROLE_TO_RGB
assert "cloth_base" in ROLE_TO_RGB
assert "skin_base" in ROLE_TO_RGB
assert "aggro_eye_glow" in ROLE_TO_RGB
assert "iron_weapon" in ROLE_TO_RGB


def nearest_doctrine(r: int, g: int, b: int) -> tuple[int, int, int]:
    """Return the (R, G, B) of the doctrine color for source (r, g, b)
    via role-via-luminance routing (preserves Grunt's hooded cloth body
    as Stoker red cloth, not skin). Character-beat override for the red
    eye-glow + iron-neutral detection take precedence over the luminance
    bands.
    """
    role = role_for_source(r, g, b)
    return ROLE_TO_RGB[role]


def bake_image(src: Path, dst: Path) -> tuple[int, int]:
    """Bake a single PNG. Returns (opaque_in, opaque_out) pixel counts."""
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    pixels_in = im.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels_out = out.load()
    opaque = 0
    # Cache source→target mapping per-image (small dict; speedup vs
    # recomputing for every pixel — most images have <100 distinct
    # opaque colors).
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels_in[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = nearest_doctrine(r, g, b)
            nr, ng, nb = cache[key]
            pixels_out[x, y] = (nr, ng, nb, a)
            opaque += 1
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, format="PNG")
    return (opaque, opaque)


def main() -> int:
    if not SRC_ROOT.exists():
        print(f"ERR: source not found: {SRC_ROOT}", file=sys.stderr)
        return 1
    png_count = 0
    total_pixels = 0
    for src_png in SRC_ROOT.rglob("*.png"):
        rel = src_png.relative_to(SRC_ROOT)
        dst_png = DST_ROOT / rel
        opaque_in, _ = bake_image(src_png, dst_png)
        png_count += 1
        total_pixels += opaque_in
    print(f"baked {png_count} PNGs, {total_pixels} opaque pixels mapped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
