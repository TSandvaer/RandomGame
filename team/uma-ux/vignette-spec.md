# Global Vignette Direction Brief (M3 Tier 2 — T12)

**Owner:** Uma · **Phase:** M3 Tier 2 Wave 2 — direction-only · **Drives:** Drew's T12 implementation (Vignette.tscn CanvasLayer + opacity-ramp API), Drew's T13 nameplate boss-entry consumer (ramp to 70%), Drew/Devon's T16 boss-defeated cinematic consumer (ramp to 80%), and Tess's validation against BI-04 + F2 + new T12 checks.

This doc is the tonal direction for the **global vignette CanvasLayer** that lands as foundation for Uma BI-04 (vignette deepens 30%→70% on boss-room entry) and Uma F2 (vignette deepens to 80% during boss-death dissolve, returns to 30% post-titlecard). The opacity numbers are already locked in [`boss-intro.md`](boss-intro.md); this brief locks the **tint**, the **opacity curve shape**, and the **rendering-layer + primitive choices** that turn those numbers into a HDR-clamp-safe, WebGL2-compatible Drew-implementable surface.

Closes [`palette-stratum-2.md §8 q3`](palette-stratum-2.md) (T12 vignette palette + opacity curve) — within Uma's delegated direction authority. Resolves the open question text in [`m3-tier2-boss-room-polish-scope.md §5 q3`](../priya-pl/m3-tier2-boss-room-polish-scope.md).

## Tonal anchor (lead with this)

> **The vignette is the room's attention. Default is "the room is watching the player." Boss-entry deepens it to "the room is closing on the player." Boss-defeat F2 deepens it to "the room is narrowing to a single point — the dissolution."**

The vignette is not a "darken the screen" UI effect. It is a **focus instrument** — it tells the player where the room's attention sits. The tonal anchor for every choice below is: *what is the room paying attention to right now, and how tight is that attention?* Default (30%) is wide attention (the player can see periphery; the room is a place to move through). 70% is constricted attention (the room narrows; the boss centers; the periphery dims). 80% is collapsed attention (only the dissolution event matters; the room *is* that event for 0.9 s).

This anchor is **single-cross-stratum** — the same vignette object handles every stratum, with the only stratum-shift being the opacity baseline (S1 30% → S8 60% per the [`palette.md`](palette.md) ramp). The vignette is a UI-layer instrument with a stratum-dependent baseline, NOT a stratum-flavored object. This matters for the **tint decision** below.

## Tint decision

**Uma call: neutral warm-black, sub-1.0 RGB per channel, cross-stratum single tint.**

**Locked hex: `Color(0.04, 0.024, 0.024, opacity)` — equivalent to `#0A0606` at the spec'd opacity.**

### Rationale (and why I'm rejecting "cooler boss-room tone")

The dispatch flagged the vignette-tint question as: "cooler boss-room tone vs neutral darken — Uma's call, with rationale."

**Rejecting cooler-boss-tone.** Three reasons:

1. **Stratum-identity creep.** A cooler-tinted vignette in the boss room would read as "this room has a different palette than the rest of S1." But the S1 boss room IS S1 — it's the climax of stratum-1 architecture, not a cool-counterpoint sub-biome. The room is *darkened* on boss-entry (BI-04), not *recolored*. Cooler tint conflicts with the stratum identity established in [`palette.md`](palette.md) ("warm cloister" — anti-list explicitly rejects cool teals/cyans for S1).
2. **Cross-stratum object discipline.** The vignette object handles every stratum. If S1 boss-room tints cooler, then by symmetry S2 boss-room should tint cooler-still (because S2's already warm-red); S3 (Drowned Reliquary, cool teal field) should tint warmer to counterpoint; the cross-stratum object inverts into stratum-specific behavior. That breaks the cross-stratum single-tint contract that lets one CanvasLayer serve all 8 strata. **Stratum tonality belongs to the ambient-tint overlay** (per [`palette-stratum-2.md §4`](palette-stratum-2.md) — S2's `#FF5A1A` 8% multiply-blend overlay handles warm-tonal-shift); the vignette is the *darkness instrument*, not the *tonality instrument*. Keep the responsibilities separate.
3. **F2 climax compositional clarity.** During boss-defeat F2 (80% vignette + sustained ember rise), the screen reads as "near-black field with bright ember motes rising." If the vignette tints cool, the ember motes shift hue against a cool field — the player perceives the embers as slightly *less warm* than they are. The neutral warm-black `#0A0606` lets the ember stay full-ember `#FF6A2A` against the dark — maximum compositional separation for the climactic moment. The F2 beat is the most-cinematic moment in M1's combat layer; the vignette must serve it, not compete.

### Why `#0A0606` specifically (HDR-clamp safety)

Per [`.claude/docs/html5-export.md`](../../.claude/docs/html5-export.md) § "Renderer / HDR modulate clamp": **WebGL2's sRGB pipeline clamps `Color` channels to `[0, 1]`. Keep tween target colors strictly sub-1.0 on every channel.** A vignette hex of pure black `#000000` (= `Color(0.0, 0.0, 0.0, opacity)`) is *technically* sub-1.0 on every channel (zero is fine), and the HDR-clamp issue is only the upper bound — but pure black has a separate problem flagged in [`palette.md`](palette.md) S1 anti-list:

> "Pure black (`#000000`) — too contrasty, breaks the 'warm cloister' mood. Reserved for stratum 7-8."

The palette.md vignette row currently lists `#000000` as the vignette color (legacy from before the S1 anti-list landed; latent inconsistency). **This brief resolves that inconsistency by specifying `#0A0606` for the S1 baseline vignette** — slight warm-black bias (a touch redder than pure black), matches the S2 vignette tint pattern (`#0A0404` per [`palette-stratum-2.md §2`](palette-stratum-2.md)) but a single point warmer to match S1's warmer baseline.

Channel breakdown: `R = 0.04 (10/255)`, `G = 0.024 (6/255)`, `B = 0.024 (6/255)`. All sub-1.0. All sub-0.05. The slight R-bias gives the warm-cloister mood the S1 anti-list calls for, without being visibly *colored* — it reads as black with a hint of warmth, not as a tinted overlay.

### Stratum-baseline opacity ramp (cross-doc check)

The cross-stratum opacity ramp is already locked in [`palette.md`](palette.md) line 30 ("Vignette `#000000` 30% (S1) → 60% (S8)") and refined per-stratum in the indicative entries (S2 = 40%, [`palette-stratum-2.md §2`](palette-stratum-2.md)). T12 ships the **S1 baseline = 30%**, with the same hex `#0A0606` for the S1 baseline. The 30%→60% cross-stratum ramp stands; the hex changes from the legacy `#000000` to the sub-1.0 + S1-anti-list-honoring `#0A0606`. Cross-stratum amendment to `palette.md` line 30 to be batched by Priya alongside this PR's decision draft.

## Opacity curve shape

**Uma call: eased — ease-in-out cubic (`Tween.EASE_IN_OUT`, `Tween.TRANS_CUBIC`).**

### Rationale (and why I'm rejecting linear)

The dispatch flagged the opacity-curve question as: "linear vs eased — YOUR call."

**Rejecting linear.** Linear opacity ramps read as **mechanical** — the player perceives the change as "something is animating a value" rather than as "the room is responding." Eased ramps read as **organic** — the room *settles* into the deeper opacity rather than *being adjusted* to it.

**Why ease-in-out cubic specifically:**

- **Ease-in start** = subtle takeoff. The first 20% of the duration produces almost no perceptible change. This creates a tiny "wait, is something happening?" moment that primes the player's attention before the main movement.
- **Cubic middle = quick traverse** of the bulk of the opacity change in the middle 60% of the duration. The room *does* close; the change is observable.
- **Ease-out end = soft landing.** The final 20% glides into the target opacity. The room doesn't *slam* into the new state.

The shape rhymes with the S1 ambient fade-out shape (ease-out cubic per [`s1-ambient.md`](s1-ambient.md) BI-03 spec) and with the boss-defeat freeze-then-tween rhythm in [`.claude/docs/time-scale-director.md`](../../.claude/docs/time-scale-director.md) § "Scaled tweens — intentional pause during freeze". The vignette deepening is the visual cousin of those rhythms.

### Duration locks per consumer

The opacity-ramp API (`set_vignette_opacity(value, duration)`) is general; consumers pass their own durations. The locked durations per consumer:

| Consumer | Trigger | From | To | Duration | Curve |
|---|---|---|---|---|---|
| BI-04 boss-entry | `Stratum1BossRoom.entry_sequence_started` | 30% | 70% | 600 ms | ease-in-out cubic |
| F2 boss-defeat dissolve | `boss_defeated` (T+0.3 s offset to match Beat F2 start) | 70% | 80% | 900 ms | ease-in-out cubic |
| F3 boss-defeat post-titlecard | `boss_defeated_card_dismissed` (or T+2.4 s timer) | 80% | 30% | 400 ms | ease-out cubic |

Note F3 uses **ease-out cubic** (not ease-in-out): the post-climax return-to-default should feel like the room *exhaling* — a brisk takeoff that settles softly. Ease-in-out would feel hesitant; ease-out reads as "OK, the moment is over, we're back."

## Peak choice for Wave 3 F2 deepening

**Uma call: 80% locks. Do NOT revise.**

The dispatch flagged the peak as "80% suggested in scope; revise if Uma sees better feel." I considered higher (90%) and lower (70%) and locked 80% for these reasons:

- **90% is too dark.** At 90% vignette over a near-black `#0A0606` tint, the screen is functionally black in the periphery — the player cannot see the room edges at all. The F2 beat is supposed to *narrow attention* to the dissolution, not *eliminate* the room. The boss's last position needs to remain legible against a visible (if heavily dimmed) room context.
- **70% is too similar to BI-04.** If F2 peaks at the same 70% as boss-entry, the deepening from "fight is on" to "boss is dying" loses its visual punch — the player perceives F2 as "still in the fight" rather than as "the climax has begun." The opacity *jump* from 70% to 80% is the visual analogue of the boss-music cut and the camera ease-in to 1.5×.
- **80% is the established lock from [`boss-intro.md`](boss-intro.md) Beat F2** ("Vignette deepens to 80% — the room narrows to just the dissolution"). Revising would break the locked F2 beat that the scope doc, Uma's boss-intro spec, and Drew's T16 ticket all reference. The 80% was Uma's original call; the dispatch's "revise if Uma sees better feel" is a courtesy revisit, and the answer is "the original call is right."

The deepening **rhythm** is the load-bearing direction: 30% → 70% (boss enters; the room watches) → 80% (boss dies; the room narrows to the moment) → 30% (the player has the room back). Each step is a tonal beat; the 10-percentage-point step from 70% to 80% is the smallest *legible* deepening that still reads as "this moment is more intense than the fight."

## Rendering layer + visual primitive guidance

### Layer ordering (CanvasLayer indexing)

The vignette must render **ABOVE the world layer** (so it darkens the world) **BELOW the HUD / UI canvas layers** (so the HUD remains fully readable at all vignette opacities, including 80% F2). Concrete:

- Vignette CanvasLayer index: **between world and HUD**. If world is layer 0 and HUD is layer 10 (typical Godot convention), the vignette sits at layer 5.
- Vignette does NOT inherit camera transform — it is screen-space (anchored to viewport), not world-space. A Camera2D zoom (T9 / T16 1.5× ease-in) does NOT change the vignette's screen coverage. This is the HUD-anchor-pattern from `m3-tier2-boss-room-polish-scope.md` T9 acceptance: "HUD anchors continue rendering at screen-space (not world-space) — HUD does not zoom with camera." The vignette follows the same pattern.

### Visual primitive — ColorRect, NOT Polygon2D

Per [`.claude/docs/html5-export.md`](../../.claude/docs/html5-export.md) § "Renderer / Polygon2D rendering quirks": **Polygon2D shapes that render correctly on `forward_plus`/`mobile` may not render in `gl_compatibility` — empirically demonstrated by the swing wedge invisibility bug (PR #137 precedent). Rule: prefer ColorRect / NinePatchRect for simple shapes.**

Even though the vignette has a *gradient* shape (darker at edges, falling off toward center), **author the vignette as a ColorRect with a custom shader or as a textured TextureRect with a pre-baked radial-gradient PNG** — NOT as a Polygon2D with vertex colors. The radial-gradient PNG approach is the lowest-risk path:

1. **Pre-bake a 256×256 radial-gradient PNG** in Aseprite or any image editor. Center = `Color(0.04, 0.024, 0.024, 0.0)` (transparent warm-black at center); edges = `Color(0.04, 0.024, 0.024, 1.0)` (opaque warm-black at corners). Smooth radial interpolation.
2. **Apply as a `TextureRect`** stretched to viewport size with `EXPAND_KEEP_ASPECT_COVERED` stretch mode (handles aspect-ratio differences across resolutions).
3. **Animate opacity via `modulate.a`** on the TextureRect — Tween targets `modulate:a` from `0.30` to `0.70` etc. The base color stays sub-1.0; only the alpha animates.

**Why NOT Polygon2D + vertex colors:** the PR #137 wedge-invisibility bug demonstrated that `gl_compatibility` (WebGL2) can silently fail to render Polygon2D shapes that render fine on desktop. The vignette is a load-bearing screen-space element — a silent-fail in HTML5 would mean the boss-entry deepening is invisible to web players while passing all desktop GUT tests. Use ColorRect (with custom shader for gradient if desired) or pre-baked TextureRect; never Polygon2D for cones/sweeps/gradients per the codified rule.

**Why NOT custom shader for first ship:** Drew's T12 implementation lane is bounded at "M effort, ~3 hr." A pre-baked TextureRect radial gradient ships in ~30 min of authoring; a custom-shader radial gradient adds shader-debug-on-HTML5 risk (gl_compatibility shader quirks are their own sharp edge). Ship the TextureRect first; promote to shader in an M4 polish ticket if the pre-baked artifact develops a visible compression edge.

### HDR-clamp recap

The locked tint `Color(0.04, 0.024, 0.024, opacity)` is sub-1.0 on every channel (well below 1.0; far from clamp). The animated property is `modulate.a` which has its own [0, 1] semantics (alpha clamps to 1 = fully opaque, no HDR risk). Both the static color and the animated opacity are safe across `forward_plus` / `mobile` / `gl_compatibility` renderers.

The pre-baked radial-gradient PNG should be authored in 8-bit-per-channel sRGB (the standard PNG export); do NOT use HDR PNG / EXR / 16-bit. The PNG's per-pixel alpha values implicitly stay within [0, 1] by the PNG format constraint; no HDR-clamp risk in the source artifact either.

## API surface (Drew's T12 implementation contract)

```gdscript
# Set vignette opacity directly (no tween).
# value clamped to [0.0, 1.0].
Vignette.set_opacity(value: float) -> void

# Tween vignette opacity over duration with specified curve.
# curve_preset: 0 = ease-in-out cubic, 1 = ease-out cubic (default = 0)
# Idempotent: rapid calls reuse the same Tween instance; previous tween is killed.
Vignette.set_opacity_tween(value: float, duration: float, curve_preset: int = 0) -> void

# Convenience used by T16 + T13 + (later) S2/S3 callers.
# Equivalent to set_opacity_tween(value, duration, curve_preset)
# with the boss-entry / boss-defeat / post-titlecard defaults baked in.
Vignette.boss_entry_deepen()        # 30% → 70%, 600 ms, ease-in-out cubic
Vignette.boss_defeat_climax()       # current → 80%, 900 ms, ease-in-out cubic
Vignette.boss_defeat_return()       # current → 30%, 400 ms, ease-out cubic
```

Drew's call on whether the curve_preset is an int enum, a Curve resource, or three named-method paths (`boss_entry_deepen` style). The brief locks the **three duration + curve combinations**; the method-shape is Drew's freedom.

### Idempotence

Rapid calls — e.g. boss-entry-and-then-immediately-defeat (edge case but possible if a debug-skip is used) — must NOT stack multiple Tweens on the same `modulate.a` property. Drew's implementation should kill any existing tween before starting a new one. Pattern: `if _active_tween != null and _active_tween.is_valid(): _active_tween.kill()`.

### Default boot state

On scene-tree boot, the vignette CanvasLayer initializes with `modulate.a = 0.30` (S1 baseline). The 30% default is visible from the first frame of Stratum-1 Room 01.

When a stratum transition lands (M3+ post-S1 work), the baseline opacity ramps per the `palette.md` line 30 cross-stratum ramp (S1 = 30%, S2 = 40%, S3 = 45%, S4 = 50%, S5 = 52%, S6 = 55%, S7 = 58%, S8 = 60% — interpolating the locked 30→60 endpoints). Cross-stratum baseline shift is a separate ticket; T12 ships the S1 baseline + the API only.

## Tester checklist (yes/no)

| ID | Check | Pass criterion |
|---|---|---|
| T12-VIG-01 | `Vignette.tscn` registered in Main; renders ABOVE world, BELOW HUD/UI canvases | yes |
| T12-VIG-02 | Default boot opacity is 30% (S1 baseline) | yes |
| T12-VIG-03 | Vignette color is `Color(0.04, 0.024, 0.024, opacity)` (= `#0A0606` warm-black with sub-1.0 RGB on every channel) | yes |
| T12-VIG-04 | Visual primitive is `TextureRect` (or `ColorRect` with custom shader) — NOT `Polygon2D` | yes |
| T12-VIG-05 | Vignette is screen-space (does NOT zoom with Camera2D) | yes |
| T12-VIG-06 | `set_opacity(value)` sets opacity instantly within `[0, 1]` clamp | yes |
| T12-VIG-07 | `set_opacity_tween(value, duration, curve_preset)` tweens with the specified curve | yes |
| T12-VIG-08 | `boss_entry_deepen()` ramps 30%→70% over 600 ms with ease-in-out cubic | yes |
| T12-VIG-09 | `boss_defeat_climax()` ramps current→80% over 900 ms with ease-in-out cubic | yes |
| T12-VIG-10 | `boss_defeat_return()` ramps current→30% over 400 ms with ease-out cubic | yes |
| T12-VIG-11 | Idempotent across rapid calls: two `set_opacity_tween()` within 100 ms produce one continuous tween, not two overlapping (previous killed) | yes |
| T12-VIG-12 | HTML5 release-build Self-Test Report confirms vignette renders cleanly + no z-index / HDR-clamp regressions | yes |
| T12-VIG-13 | HUD/UI canvas (top-left HP/XP, top-right context region, nameplate) remains fully readable at vignette = 80% (F2 peak) | yes |
| T12-VIG-14 | Paired GUT test asserts `set_opacity_tween()` reaches target value at end of duration | yes |
| T12-VIG-15 | Sponsor probe: subjective "the room is closing on me" feel on boss-entry; subjective "the room is collapsing to the dissolution" feel on F2 | yes (Sponsor soak) |

T12-VIG-12 is the HTML5 visual-verification gate per [`.claude/docs/html5-export.md`](../../.claude/docs/html5-export.md) — Drew's PR must include screenshot/video evidence (or honest-disclose escape clause + Sponsor-soak routing per the same doc).

T12-VIG-15 is the Sponsor-soak signal — not a unit test, but the design's primary user-facing acceptance.

## How to validate the direction

A reviewer (Drew implementing or Tess validating) should:

1. **HDR-clamp pre-check.** Inspect the locked color `Color(0.04, 0.024, 0.024, opacity)` and confirm every RGB channel is sub-1.0. Confirm the pre-baked radial-gradient PNG is 8-bit sRGB (not HDR / EXR / 16-bit). Confirm no shader code multiplies the color above sub-1.0 anywhere in the render path.
2. **Polygon2D-rejection check.** Confirm the implementation uses `TextureRect` or `ColorRect` — NOT `Polygon2D`. This is the load-bearing primitive choice (PR #137 precedent).
3. **Layer-order check.** In Godot editor, walk the CanvasLayer tree: world < vignette < HUD < InventoryPanel < title-card. The vignette darkens world; the HUD reads through.
4. **Curve-shape A/B.** Run boss-entry with the locked ease-in-out cubic curve, then temporarily swap to linear, and compare. The eased version should feel like the room *settling into* the new opacity; the linear version should feel like a fader. If they feel the same to the reviewer, the easing is implemented incorrectly (likely a Tween.TRANS_LINEAR default).
5. **F2-climax compositional check.** Trigger boss-defeat F2 in-game with sustained-ember-rise active (T16 dependency). The 80% vignette + ember motes should read as "ember on near-black field," not as "ember on tinted field." If the embers look cool or muted, the vignette tint is wrong (cool bleed) and the spec's tint decision needs revisit.
6. **HUD readability at 80%.** Open inventory + activate F2 simultaneously (debug-only) and confirm the HUD HP / XP / nameplate / inventory grid all remain readable through the 80% vignette. If anything goes invisible, the layer-order is wrong (vignette above HUD instead of below).

## Cross-references

- [`boss-intro.md`](boss-intro.md) Beat 2 (BI-04) — vignette deepens 30%→70% on boss-entry; 600 ms locked.
- [`boss-intro.md`](boss-intro.md) Beat F2 — vignette deepens to 80% during dissolve; F3 returns to 30%.
- [`palette.md`](palette.md) line 30 — vignette cross-stratum opacity ramp (S1 30% → S8 60%); legacy `#000000` color amended to `#0A0606` by this brief.
- [`palette-stratum-2.md §2`](palette-stratum-2.md) — S2 vignette spec (`#0A0404` at 40%); S1 mirrors the warm-black sub-1.0 pattern one-step-warmer.
- [`palette-stratum-2.md §8 q3`](palette-stratum-2.md) — open question this brief closes (palette + opacity curve).
- [`m3-tier2-boss-room-polish-scope.md §5 q3`](../priya-pl/m3-tier2-boss-room-polish-scope.md) — Tier 2 open question this brief closes.
- [`.claude/docs/html5-export.md`](../../.claude/docs/html5-export.md) — HDR clamp + Polygon2D rule (PR #137 precedent); visual-verification gate.
- [`.claude/docs/time-scale-director.md`](../../.claude/docs/time-scale-director.md) — scaled-tween pattern (the vignette tween should be a default scaled tween so it pauses during T2 hit-pause / T16 freeze).
- [`s1-ambient.md`](s1-ambient.md) — sister direction brief (T10); the ambient fade-out and vignette deepening are coupled tonal beats.
- [`visual-direction.md`](visual-direction.md) line 35 — original cross-stratum vignette spec (30–60% opacity; this brief refines for T12).

## Hand-off

- **Drew (T12 implementation):** §"API surface" + §"Rendering layer + visual primitive guidance" + §"Tester checklist". Ship the Vignette.tscn + the API methods + the pre-baked radial-gradient PNG + paired GUT tests. HTML5 visual-verification gate Self-Test Report required (per html5-export.md).
- **Drew (T13 nameplate consumer):** call `Vignette.boss_entry_deepen()` from `Stratum1BossRoom.entry_sequence_started` handler — the nameplate slide-in is the same beat as the vignette deepening.
- **Drew/Devon (T16 consumer):** call `Vignette.boss_defeat_climax()` from `boss_defeated` handler at T+0.3 offset (Beat F2 start), and `Vignette.boss_defeat_return()` from end-of-title-card.
- **Tess (T12 validation):** §"Tester checklist" (T12-VIG-01 through T12-VIG-15); §"How to validate the direction" for subjective items.
- **Sponsor (soak):** T12-VIG-15 is the Sponsor-probe item.

## Decision draft

(For Priya's weekly DECISIONS.md batch. Not for direct edit to `team/DECISIONS.md` per Uma role rules.)

- **Decision draft (2026-05-20):** **Vignette is a single cross-stratum object with stratum-baseline opacity ramp + cross-stratum single tint `#0A0606` (sub-1.0 RGB warm-black).** Boss-entry deepens 30%→70% (600 ms ease-in-out cubic); boss-defeat F2 deepens to 80% (900 ms ease-in-out cubic); post-titlecard returns to 30% (400 ms ease-out cubic). Rejects cooler-boss-tone in favor of cross-stratum-object discipline (stratum tonality lives in the ambient-tint overlay, not the vignette). Resolves `palette-stratum-2.md §8 q3` and `m3-tier2-boss-room-polish-scope.md §5 q3`. Amends `palette.md` line 30 legacy `#000000` to `#0A0606` (S1 anti-list compliance + HDR-clamp safety). Affects: T12 (Drew impl), T13 (nameplate consumer), T16 (defeat-climax consumer), all future strata (S2+ consume the same API with stratum-baseline-only shifts). Reversibility: API + scene are isolated to Vignette.tscn; opacity-curve change is a single Tween parameter swap; tint change is a single Color literal swap.

## Non-obvious findings

(For the maintain-docs Stop hook to consider for `.claude/docs/` capture.)

1. **Vignette as single cross-stratum object discipline.** The decision that the vignette is a single cross-stratum CanvasLayer with stratum-baseline-opacity-only shifts (NOT stratum-tinted) is a pattern worth capturing. The companion discipline: stratum tonality belongs to the ambient-tint overlay (per `palette-stratum-2.md §4` S2 `#FF5A1A` 8% multiply), not to the vignette. Two-overlay separation: tint overlay = stratum identity; vignette = darkness/focus instrument. **Capture timing:** when T12 ships and a second stratum's ambient-tint overlay lands (M3+ S2 content surface), the two-overlay pattern becomes load-bearing for cross-stratum work and is worth a section in `.claude/docs/html5-export.md` or a fresh `.claude/docs/visual-overlay-layers.md`. Not yet doc-worthy from one brief.

2. **Pre-baked radial-gradient PNG vs custom shader for HTML5 vignette.** The decision to ship a pre-baked TextureRect first (vs custom shader) is a recurring HTML5 risk-management pattern: when a visual element can be authored as a static artifact + transform, prefer the static artifact over runtime shader code, because `gl_compatibility` shader quirks are a separate failure surface. **Capture timing:** if a second visual element ships under this discipline (e.g. a fade-overlay, a depth-of-field layer, a heat-shimmer effect), the pattern is worth `.claude/docs/html5-export.md` § "Static artifacts preferred over runtime shaders" capture. Not yet doc-worthy from one brief — but flagged for future maintain-docs runs.
