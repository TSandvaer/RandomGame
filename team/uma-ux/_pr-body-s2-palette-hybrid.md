# S2 palette doctrine reconciliation — hybrid framing (Cinder Vaults + Sunken Archive)

Doc-only amendment to `team/uma-ux/palette-stratum-2.md` reconciling the W3-T7 Stage 1 finding (PR #360, merged `14d7c83` 2026-05-24) where Sponsor-locked S2 mob/boss names (Sunken-Scholar / Bone-Catalyst / Archive Sentinel) carry library/archive aesthetic that conflicted with this doc's Cinder Vaults mining-doctrine framing.

Sponsor decision 2026-05-24: **path (c) hybrid framing** — Stratum 2 IS Cinder Vaults at the stratum level; Drew's four S2 zones (`s2_z1_entry_hall` / `s2_z2_reading_chamber` / `s2_z3_archive_vault` / `s2_z4_inner_sanctum`) land as a **Sunken-Archive sub-region** built INSIDE the abandoned mining tunnels by a scholarly order; mob/boss iconography blends both substrates.

## Structure

Amendment is **additive**. Every pre-2026-05-24 paragraph (TL;DR, §1 biome theme, §2 Cinder-Rust ramp palette, §3 content beats, §4 lighting, §5 sprite-reuse table, §6 daltonization, §7 tester checklist) holds verbatim. Four insertions:

- **§1.5 — Hybrid framing narrative** (`palette-stratum-2.md:139-155`) — pre-cataclysm scholar-order descended into the abandoned Vaults, post-collapse current state, why mobs/boss carry archive iconography, what doesn't change.
- **§1.6 — Sub-region Sunken Archive palette** (`palette-stratum-2.md:157-185`) — scholarly-overlay palette (archive-wood, parchment, brass) layered ON TOP of §2 Cinder anchors; per-zone substrate/overlay distribution (80/50/40/70%) per zone.
- **§5.5 — W3 character archetype visual prompt seeds** (`palette-stratum-2.md:281-385`) — Sunken-Scholar (ranged caster, lantern-staff silhouette), Bone-Catalyst (melee bruiser, bone-fetish forearms + brass skull-mask), Archive Sentinel (boss, stone-bone composite with glowing-book "eye"). Each archetype includes tonal anchor, silhouette description, animation-state list for Drew, distinct-from-S1 silhouette analysis, PixelLab prompt seed for Sponsor.
- **§8 open question 8** — first-soak tonal gate for the §1.6 per-zone overlay weighting.

Plus a closing **Coordination note** documenting the amendment trigger (PR #360 + Sponsor decision 2026-05-24 + Sponsor-locked names) and the additive-not-rewrite convention for future amendments.

## Honors existing decisions

- **Boss-music UNIQUE** (DECISIONS.md 2026-05-15) — Archive Sentinel uses `mus-boss-stratum2.ogg` distinct composition, NOT cross-stratum reuse. Section explicitly cites.
- **§2 Cinder-Rust palette unchanged** — scholarly overlay is *additive secondary palette*, not replacement.
- **Ember through-line preserved** — `#FF6A2A` still doubles as player flame + vein cores + Sunken-Scholar lantern-flame + Archive Sentinel book-cast projectile.
- **Cross-stratum mob aggro eye-glow constant** — `#D24A3C` for all three S2 archetypes (S1 PL-11 holds).
- **Stoker M3-phase-1 grunt-retint** (DECISIONS.md 2026-05-18) — referenced from §5.5 as the precedent for "scholarly-corruption silhouette" treatment.
- **No Polygon2D for cones/sweeps** — uma persona hard rule cited explicitly in §5.5 (per PR #137 precedent + html5-export.md HDR clamp rule). Archive Sentinel slam AOE specified as `_draw()` + `draw_arc()` per html5-export.md § "Shape OUTLINES."
- **M3W-1 PR #271 3-branch resolver + `HIT_FLASH_TINT = Color(1.0, 0.50, 0.50, 1.0)`** — all three archetypes inherit this convention; explicitly cited.
- **AnimatedSprite2D state-anim wiring** — all three archetypes follow the M3W-1 SpriteFrames layout + `<state>_<dir>` anim-key shape.

## What this PR does NOT do

- Does NOT author character sprites — Sponsor + PixelLab MCP path runs `mcp__pixellab__create_character` per `.claude/docs/pixellab-pipeline.md`; the prompt seeds in §5.5 are the inputs Sponsor consumes.
- Does NOT change Drew's zone `display_name`s — they're already merged at `14d7c83`.
- Does NOT write code, edit `resources/`, or modify any non-doc file.
- Does NOT fold in `audio-direction.md` cue work — that's a separate Uma surface (§8 q6 standing).
- Does NOT edit `team/DECISIONS.md` — per uma persona hard rule. The Sponsor 2026-05-24 hybrid-framing decision should be drafted into DECISIONS.md by Priya's weekly batch; final report carries a `Decision draft:` line for that purpose.

## Sponsor-input items

(For Sponsor's information; not blocking merge — these are queued downstream.)

1. **§8 q8 — first-soak tonal gate for hybrid framing weighting** — at first populated S2 chunks (ticket `86c9y7ygj` Part C ship), Sponsor soak determines whether §1.6's 80/50/40/70% substrate-vs-overlay-per-zone ratio reads tonally as designed. If middle zones (z2/z3) feel insufficiently scholarly OR z4 feels insufficiently *reclaimed by fire*, the weighting tunes in §1.6 (no code change; only prop-distribution brief Drew consumes). Owner: Sponsor at first S2-content soak.
2. **PixelLab generation gate** — §5.5 prompt seeds are authored intuitions. When Sponsor runs them through `mcp__pixellab__create_character`, the per-archetype seeds may need iteration if PixelLab doesn't honor a specific prompt-engineering token (per `pixellab-pipeline.md` § "Prompt engineering"). The seeds use the prompt-literalism rules (lead with positive feature, demote constraints to setting context, sub-1.0 hex throughout) but PixelLab's tokenization isn't deterministic — first-gen results may surface seeds-need-revision findings.
3. **Existing §8 q7 (ember dual-role) and §8 q1 (Sunken Library aesthetic future-stratum repurpose)** — unchanged by this amendment; standing items.

## Cross-references

- **PR #360** (merged `14d7c83`, 2026-05-24) — W3-T7 Stage 1 S2 ZoneDef shells; Drew's Part-A handoff flagged the doctrine drift.
- **Sponsor decision 2026-05-24** — path (c) hybrid framing + locked names (Sunken-Scholar / Bone-Catalyst / Archive Sentinel).
- `team/uma-ux/palette-stratum-2.md` — this PR's amendment surface.
- `team/uma-ux/visual-direction.md` § "Stratum visual progression" — 8-stratum hue-temperature arc (S2 cited as warm-yellow→warm-red shift; hybrid framing preserves this).
- `team/uma-ux/palette.md` — global ramp / ember accent + cross-stratum constants (UI panel, HP foreground, tier ramp).
- `.claude/docs/combat-architecture.md` § "M3W-1 realized implementation" — 3-branch hit-flash resolver + `HIT_FLASH_TINT` + SpriteFrames layout — inherited by all three §5.5 archetypes.
- `.claude/docs/html5-export.md` § "HDR modulate clamp" + § "Polygon2D rendering quirks" + § "Shape OUTLINES" + § "Burst contrast against high-hue-saturation same-z sprites" — visual-primitive constraints cited throughout §5.5.
- `.claude/docs/pixellab-pipeline.md` § "Prompt engineering" + § "Folder-rename + reverse-map" — Sponsor's PixelLab execution path.
- `.claude/docs/audio-architecture.md` § "Tonal pattern — cross-stratum distinct ambient" — confirms S2 boss music UNIQUE composition per DECISIONS.md 2026-05-15.
- `.claude/docs/camera-layer.md` — `request_zoom(1.25, 0.9, ...)` normalized API for Archive Sentinel BI-05 reveal.
- `team/uma-ux/boss-intro.md` — BI-01 reveal beat shape (Archive Sentinel-specific notes in §5.5).
- `team/drew-dev/level-chunks.md` § "S2 zone roster" — Drew's W3-T7 Stage 1 doc capturing the locked-name zone roster.
- `team/DECISIONS.md` — 2026-05-15 boss-music UNIQUE, 2026-05-18 Stoker phase-1 retint (both referenced in this amendment).

## Decision drafts (for Priya's weekly batch)

```
Decision draft 2026-05-24 — Stratum 2 hybrid framing (Cinder Vaults + Sunken Archive sub-region)

- Decided: Stratum 2 anchors as Cinder Vaults (collapsed ember-ore mining complex);
  the four S2 zones (s2_z1_entry_hall / s2_z2_reading_chamber / s2_z3_archive_vault /
  s2_z4_inner_sanctum) land as a SUNKEN-ARCHIVE sub-region built INSIDE the abandoned
  tunnels by a scholarly order. Sponsor-locked W3 mob/boss names
  (Sunken-Scholar / Bone-Catalyst / Archive Sentinel) gain diegetic grounding via
  the scholarly-order narrative. Mob/boss iconography blends miner-substrate +
  scholar-overlay + corruption-overlay. Visual direction shipped in
  team/uma-ux/palette-stratum-2.md §1.5 (hybrid narrative), §1.6 (scholarly overlay
  palette + per-zone weighting), §5.5 (W3 character archetype visual prompt seeds).
- Affects: Uma (palette-stratum-2.md amendment); Drew (W3-T7 Part B/C/D consumes
  §5.5 character seeds + §1.6 per-zone weighting); Sponsor (PixelLab MCP path
  consumes §5.5 prompt seeds via orchestrator main session); Priya (post-wave3-
  sequencing aligns with the hybrid frame; no scope change). Boss-music UNIQUE
  decision (DECISIONS.md 2026-05-15) unaffected — Archive Sentinel uses
  mus-boss-stratum2.ogg distinct composition.
- Reversibility: reversible — palette-stratum-2.md amendment is additive and
  documented under a "Coordination note" with audit-trail discipline. Future
  amendments land in the same format. Sponsor's first S2-content soak (§8 q8)
  is the gate-of-record for whether the per-zone weighting tunes correctly;
  weighting tunes are doc-only edits to §1.6.
- Detail: PR <to fill in after `gh pr create`> amending team/uma-ux/palette-stratum-2.md.
  Trigger: PR #360 (merged 14d7c83 2026-05-24) Drew Part-A handoff flagging
  doctrine drift; Sponsor reconciliation 2026-05-24 path (c).
```
