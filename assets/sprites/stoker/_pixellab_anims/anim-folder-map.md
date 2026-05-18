# Stoker — Path A retint of Grunt v2 atlas (M3W-6)

The Stoker character is M3 Tier 1's S2 mob, shipping as a **palette-swap
retint of Grunt v2** per `team/DECISIONS.md` 2026-05-18 (Path A locked)
and `team/uma-ux/palette-stratum-2.md §5` line 191 (Grunt mob/Stoker
row: "RETINT OK (M3 ship) / NEW AUTHORING deferred to Phase 2"). The
hooded-novice silhouette is the M3 doctrinal compromise; the miner-cap
silhouette is the Phase 2 backlog item.

No PixelLab generation was used for Stoker. The atlas under
`Stoker_S2_Cinder_Vaults/animations/` is **deterministically baked**
from Grunt v2's `Grunt_v2_S1_Embergrave_red-eyes/animations/` PNGs via
`tools/bake_stoker_palette.py` (per-source-color role-via-luminance
mapping to the S2 Stoker doctrine palette).

## Reverse-map — source folder → bake folder

Source root:
  `assets/sprites/grunt/_pixellab_anims/Grunt_v2_S1_Embergrave_red-eyes/animations/`

Bake root:
  `assets/sprites/stoker/_pixellab_anims/Stoker_S2_Cinder_Vaults/animations/`

| Semantic name | Frames/dir | Source folder (Grunt v2) | Notes |
|---|---|---|---|
| `walk/`           | 8 | `walk/`           | Walking-menacingly template, doctrine retinted. |
| `atk/`            | 6 | `atk/`            | Cross-punch attack, doctrine retinted. |
| `hit/`            | 6 | `hit/`            | Taking-a-punch flinch, doctrine retinted. |
| `die/`            | 7 | `die/`            | Falling-backward death, doctrine retinted. |
| `atk_telegraph/`  | 8 | `atk_telegraph/`  | Custom heavy-windup pose, doctrine retinted. |

Direction subfolders mirror Grunt's exactly:
`{north, north-east, east, south-east, south, south-west, west, north-west}`.

Total: 5 anims × 8 dirs × N frames each = 280 PNGs (same as Grunt v2).

## Baking mechanism

`tools/bake_stoker_palette.py` walks every source PNG and remaps each
opaque pixel to its **doctrine role-via-luminance** target:

1. **Red eye-glow override** — pixels where `R > 1.5 × max(G, B)` and
   `R >= 80` force-route to `#D24A3C` (cross-stratum aggro eye-glow per
   `palette.md` PL-11), regardless of Euclidean distance. Preserves the
   eye-glow character beat per the rule in
   `.claude/docs/pixellab-pipeline.md §"Strategy 3 — manual override for
   character-beat preservation"`.
2. **Iron-weapon detection** — near-grey mid-tones (R≈G≈B, 120 ≤ R ≤ 200)
   route to `#9C9590` weapon edge (unchanged from S1 per
   `palette-stratum-2.md §2` mob accents — "same era of metalwork").
3. **Luminance bands for the rest** — Rec.601 Y rolls source pixels into
   the S2 cloth/skin/outline ramp. The Grunt is HOODED, so the dominant
   browns in the source are ALL cloth (smock + hood), NOT skin. Pure
   Euclidean nearest-neighbor would route source browns to S2 skin
   (`#7E5A40`) because brown→brown wins over brown→red — this is the
   trap documented in `.claude/docs/pixellab-pipeline.md §"Nearest-neighbor
   breaks doctrine-ramp intent for mid-tones — bias toward dark"`.
   Luminance routing fixes this by mapping the dominant body cluster
   (~`#68504F`, Y≈86) directly to `#7A1F12` cloth_base.

The result is 10 doctrine-locked output colors (down from 501 raw source
colors in Grunt v2's PixelLab output). Dominant distribution:

| Output hex | Role | % of opaque pixels |
|---|---|---|
| `#000000` | outline | 36.80 |
| `#1A0A06` | cloth_deepest | 24.96 |
| `#7A1F12` | cloth_base (S2 mob cloth anchor) | 20.62 |
| `#0A0404` | deep_shadow_warm | 6.33 |
| `#5A1108` | cloth_mid_shadow | 3.96 |
| `#A93020` | cloth_highlight | 3.82 |
| `#D24A3C` | aggro_eye_glow (PL-11) | 1.46 |
| `#B08660` | skin_highlight | 1.39 |
| `#7E5A40` | skin_base (S2 mob skin anchor) | 0.49 |
| `#9C9590` | iron_weapon | 0.16 |

Cloth + outline + shadow = ~96.4% of pixels; the hooded silhouette
reads as red-corroded cloth. The small skin (1.88%) is the exposed face
fragment glimpsed through the hood — preserved by the luminance routing.

## Provenance — no PixelLab metadata

Because Stoker is a deterministic retint and not a generation, this
directory carries NO `metadata.json` (no PixelLab `character_id`, no
template, no UUIDs). The PixelLab traceability for the silhouette /
animation provenance lives in `assets/sprites/grunt/_pixellab_anims/
anim-folder-map.md` + `metadata.json` (Grunt v2 is the upstream).

To re-bake (e.g. after a doctrine palette adjustment):

```
python tools/bake_stoker_palette.py
```

Then commit the regenerated PNGs.
