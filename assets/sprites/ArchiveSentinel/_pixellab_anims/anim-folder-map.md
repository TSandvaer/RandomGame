# ArchiveSentinel PixelLab anim folder map

Original PixelLab character_id: ca44536c-e033-4d02-a104-3f7f3df1d4cc (v3 — Archive-Sentinel-v3)
Generated: 2026-05-29
Harvested by: orchestrator main-session (PixelLab generation runs in orch main per
`.claude/docs/pixellab-pipeline.md` § "Execution context")

## What this character ships

The Archive Sentinel (Stratum-2 boss) is a STATIONARY frontal construct
(Uma `palette-stratum-2.md` §5.5 "head-on facing camera"). Its telegraphs
(cast flare / slam-AOE circle / phase-transition) are CODE-DRAWN
(`_draw()` / `draw_arc()` / CPUParticles2D / modulate tween), NOT sprite-frame
animations. So the wired-into-the-scene art is a SINGLE static south-facing
rotation, not a SpriteFrames animation set.

Only `rotations/` were generated (8 idle rotations). NO `animations/` folder
exists for this character — there are no `wake` / `idle_active` / `cast` /
`die` frame-animations, and none are required (see
`scripts/mobs/ArchiveSentinel.gd::_play_anim` — fully defensive, no-ops when
the Sprite child is not an AnimatedSprite2D).

## Rotation set (v3 — the Sponsor-approved generation)

| File | Direction | Wired into scene? |
|---|---|---|
| `Archive-Sentinel-v3/rotations/south.png` | south (head-on) | YES — copied to `assets/sprites/ArchiveSentinel/south.png`, wired as the static Sprite2D in `scenes/mobs/ArchiveSentinel.tscn` |
| `Archive-Sentinel-v3/rotations/south-east.png` | south-east | kept in-repo for future use |
| `Archive-Sentinel-v3/rotations/east.png` | east | kept in-repo for future use |
| `Archive-Sentinel-v3/rotations/north-east.png` | north-east | kept in-repo for future use |
| `Archive-Sentinel-v3/rotations/north.png` | north | kept in-repo for future use |
| `Archive-Sentinel-v3/rotations/north-west.png` | north-west | kept in-repo for future use |
| `Archive-Sentinel-v3/rotations/west.png` | west | kept in-repo for future use |
| `Archive-Sentinel-v3/rotations/south-west.png` | south-west | kept in-repo for future use |

Source canvas: 140×140 RGBA, low top-down. Content bbox ~70×70 centered.
Scene wires `south.png` at Sprite2D scale 0.57 → ~80px effective canvas,
matching the S1 boss frame canvas (80×80) for cross-boss scale consistency.

## Superseded generation (DO NOT USE)

- PixelLab char `a230a0bb...` ("Archive-Sentinel", non-v3) — the earlier weak
  standard base. SUPERSEDED by v3 per the dispatch brief. NOT committed to this
  branch (only the v3 set ships); recorded here for provenance so a future
  auditor knows v3 is the canonical generation.

## Doctrine note

The v3 was prompted with the S2 doctrine hexes but was NOT run through a
pixel-mcp doctrine-lock pass (per the dispatch brief). See the PR body for the
doctrine verdict vs `team/uma-ux/palette-stratum-2.md` §5.5. If a doctrine-lock
pass is later run, the locked output replaces `south.png` (and optionally the
other rotations) and this map's "wired" row updates accordingly.
