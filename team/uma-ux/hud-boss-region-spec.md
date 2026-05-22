# HUD Boss-Region Treatment — Visual Direction (W3-T15)

**Owner:** Uma · **Ticket:** `86c9wjzbc` · **Phase:** M3 W3 · **Drives:** Devon's HUD-context-region implementation (stage 3b).

This doc is the dispatch-ready visual specification for the HUD top-right context region's boss-fight treatment — the moment the run-context label flips from `STRATUM 1 · ROOM x/8` to `STRATUM 1 · BOSS` and back. Pairs with `boss-intro.md` § BI-20 (HUD top-right region flips to red `STRATUM 1 · BOSS` treatment during the fight) and §158 (returns to pre-fight state in F4 after defeat).

## 1. Tonal anchor

**The HUD context region is the player's persistent reminder of where they are in the descent narrative.** Default state: muted, off-white, "you are in stratum 1, room N of 8 — the cloister is still around you." Boss state: **the room counter goes silent and the world's color asserts itself in the HUD** — a single dark-red word, `BOSS`, becomes the only meaningful label on screen. The descent narrative's *pressure* lands in the HUD.

The transition shape is **a held breath**, not a flash. The room counter does not get crossed out, blanked, or animated — it is **superseded**. The boss label takes over the same pixel real-estate over a brief fade, signaling that the run's context has changed. On boss-defeated, the reverse fade restores the room counter, but **at 60% opacity for 1.5 s** — the room remembers the fight just happened. This is the HUD analogue of the F4 ambient-resume-at-60% in `audio-architecture.md` § "Stratum-1 ambient — wiring + curves": the world is quieter for a beat after, not snap-back-to-normal.

## 2. Palette lock — red hex decision

**Locked hex: `#7A2A26` (mob HP foreground / active-phase-segment red).**

Rationale:

- **Single tonal-red identity for "this is the boss fight."** The active phase segment on the nameplate (per `boss-intro.md` § "Phase-segmented health bar") fills at `#7A2A26`. The HUD-context region using the same hex creates **one red, one boss** — the player's eye registers the same color across both surfaces and reads them as a single "boss fight active" semantic.
- **`#D24A3C` is rejected.** That hex is the **player-HP-foreground / aggro-eye-glow / damage-to-player popup** color (per `palette.md` § Status / state colors). Using it for the HUD-context boss label would semantically conflict with damage feedback — every time the player took a hit, the popup color would echo the HUD label color, creating tonal noise.
- **Ember-orange `#FF6A2A` is rejected.** Ember is the **player's flame** (cross-stratum constant per `palette.md` § "Ember-orange — the through-line"). Reframing it as a "boss alert" color would dilute the ember's diegetic role. Ember is the *player's* identity, not the threat's.
- **Brighter alternatives (`#D24A3C` mid, `#FF4818` magma) are rejected** for the reasons above + tonal-direction discipline: the boss-region HUD is meant to read as **heavy, dark, ominous** — same as the boss music's perfect-fifth cello bed (per `audio-architecture.md` empirical anchor), not as a UI-flash alarm. Bright red would feel arcade; dark red feels dread.

Verified against `palette.md`:

| Role | Hex | Source | HTML5 HDR-clamp safe (sub-1.0 channels)? |
|---|---|---|---|
| Boss-region red | `#7A2A26` | `palette.md` § Status / state colors, "Mob HP foreground" | `(0.478, 0.165, 0.149)` — all channels sub-1.0 ✓ |
| Default room-context off-white | `#E8E4D6` | `palette.md` § Core neutrals, "HUD body text" | `(0.910, 0.894, 0.839)` — all channels sub-1.0 ✓ |

## 3. Default state — `STRATUM 1 · ROOM x/8`

**Renders as it does today.** No changes to the existing Main.gd top-right context implementation:

- Text: `STRATUM 1 · ROOM x/8` (x = current 1-indexed room number).
- Color: `#E8E4D6` off-white.
- Font size: 14 px.
- Anchor: top-right, 16 px from screen-top and 16 px from screen-right.
- Horizontal alignment: right.

**Note on prior-spec drift:** the W3 dispatch brief mentioned `#B8AC8E` muted parchment as the default. Re-grounding against `hud.md` § 2 (Run context top-right) and `scenes/Main.gd:786` (existing implementation), the canonical default is `#E8E4D6` off-white. **This doc preserves the canonical default.** If Sponsor or Priya later wants the default lowered to `#B8AC8E` for tonal contrast against the boss-state red, it becomes a separate single-line palette amendment — not in scope for T15.

## 4. Boss state — `STRATUM 1 · BOSS`

Fires on `entry_sequence_completed.emit()` (per `boss-intro.md` § "BI-20"). Reverts on `boss_defeated.emit()` (per `boss-intro.md` § F4).

- Text: `STRATUM 1 · BOSS` — the literal string, no boss-name substitution (the boss nameplate covers the name surface; the HUD region is the *stratum-level* identifier).
- Color: `#7A2A26` (locked per §2).
- Font size: 14 px (unchanged from default).
- Anchor / alignment: unchanged from default.

**No additional ornamentation.** No heartbeat pulse, no ember-orange underline, no glyph (`!` or `★`), no blink. The hud.md §2 mock mentioned "a slow heartbeat pulse" historically, but the W3 dispatch context (which threads `STRATUM 1 · BOSS` against the **already-pulsing nameplate** below-10% indicator, the active-phase-segment ghost-damage drain, AND the F2 climax cinematic) calls for the HUD-region to be **the quiet anchor** — the one HUD surface that does NOT animate during the fight. The label sits there, dark and still, while the rest of the HUD breathes around it. This is the "stone in the storm" tonal call.

## 5. Transition shape

### Entry (on `entry_sequence_completed.emit()`)

**0.2 s color-fade cross-blend.**

- T+0.000 s: text = `STRATUM 1 · ROOM x/8`, color = `#E8E4D6`.
- T+0.200 s: text = `STRATUM 1 · BOSS`, color = `#7A2A26`.

Two sub-operations chained:

1. **Text swap at T+0.000 s exact** (instant string change — `STRATUM 1 · ROOM x/8` → `STRATUM 1 · BOSS`). The text is the *content* change; the *visual* change is the color tween.
2. **Color tween from `#E8E4D6` to `#7A2A26` over 0.200 s, ease-in-out cubic.** The text is already showing `STRATUM 1 · BOSS` from T+0.000 s but in the off-white color, then desaturates and reddens to the boss-red over 0.2 s.

Why text-swap-then-color-fade (instead of crossfade-and-color): a crossfade requires two overlapping labels (alpha-blend old + new), which doubles the Control node count and adds an extra modulate-tween risk class. The instant text-swap + color-tween approach uses **one Label, one tween on one property** — minimal HTML5 risk surface. The 0.2 s color shift carries the perceptual "this changed" beat; the human eye doesn't notice the instant string swap because the color is moving.

### Exit (on `boss_defeated.emit()`)

**0.4 s color-fade revert + 1.5 s opacity-drop-then-restore (the "world remembers" beat).**

- T+0.000 s: text = `STRATUM 1 · BOSS`, color = `#7A2A26`, alpha = 1.0.
- T+0.000 s: text swap → `STRATUM 1 · ROOM x/8`. Color tween starts.
- T+0.400 s: text = `STRATUM 1 · ROOM x/8`, color = `#E8E4D6`, alpha = 0.6 (held).
- T+1.900 s: alpha tweens from 0.6 → 1.0 over 0.3 s.
- T+2.200 s: text = `STRATUM 1 · ROOM x/8`, color = `#E8E4D6`, alpha = 1.0. Default state restored.

Three sub-operations:

1. **Text swap at T+0.000 s** (instant string change — `STRATUM 1 · BOSS` → `STRATUM 1 · ROOM x/8`).
2. **Color tween from `#7A2A26` to `#E8E4D6` over 0.400 s, ease-out cubic.** Slower than the entry tween — same shape as `audio-architecture.md` § "Stratum-1 ambient — wiring + curves" (entry duck = 0.6 s ease-out cubic; resume = 0.8 s ease-in-out quadratic). Visual analogue: entry is *sharp* (0.2 s), exit is *softer* (0.4 s).
3. **Alpha hold-at-60% from T+0.400 s to T+1.900 s** (1.5 s held muted), then **alpha tween from 0.6 → 1.0 over 0.3 s, ease-in quadratic** to T+2.200 s. The label is dimmed for 1.5 s before fully restoring — the HUD analogue of the F4 ambient-at-60% beat.

Why the 60%-hold + delayed restore: the F4 ambient resumes at 60% per `audio-architecture.md`; the HUD-region matches that **as a tonal echo** — the world (audio + HUD) returns to its idle state at the same dimmed volume for the same beat, then restores together. This composes cleanly with the BossDefeatedTitleCard's silence-as-punctuation hold (which already lands the title-card silence beat in the F3 → F4 window).

**Coordination note for Devon stage 3b:** the F4 ambient-restore handler in `AudioDirector` fires on `BossDefeatedTitleCard.title_card_dismissed` — verify the HUD-region revert handler should fire on `boss_defeated` (immediate, before title card) OR on `title_card_dismissed` (after card dismiss, synced with ambient resume). **Recommendation:** wire to `boss_defeated` (immediate) for the text + color flip, so the HUD acknowledges the kill instantly; the 60%-alpha-hold then runs *through* the title-card lifetime, restoring to full opacity ~0.3 s after the card dismisses. This gives the player two layered "world resumes" cues — title card dismisses, then HUD-region brightens.

### Transition curve discipline

- **Entry color tween:** ease-in-out cubic (the boss-state arrives with momentum + lands authoritatively).
- **Exit color tween:** ease-out cubic (the boss-state releases gently — front-loaded "dive" toward default).
- **Exit alpha-restore tween:** ease-in quadratic (the HUD restores quietly — back-loaded approach to full opacity, no aggressive snap-up).

Curves picked to match the existing `audio-architecture.md` § Stratum-1 ambient curve discipline. Same shape, different medium.

## 6. Visual primitive discipline (HTML5 / WebGL2 safety)

This is **Label-node modulate-color tween** territory — same primitive class as the existing top-right context label (`scenes/Main.gd:786`). Per `.claude/docs/html5-export.md`:

- **No Polygon2D.** Text label, no shape primitives needed.
- **No CPUParticles2D.** No ornament, no flair.
- **Modulate tween on Label is renderer-safe** — same class as PR #289 BossDefeatedTitleCard color-modulate, which has shipped clean on HTML5. The HDR-clamp rule (sub-1.0 per channel) is satisfied by both hex endpoints (verified in §2).
- **Single Control, single property tween** — minimal renderer divergence surface area.
- **z_index discipline:** the label sits inside the existing TopRightContext Control (`scenes/Main.gd:777`), which lives on the same HUD CanvasLayer as the rest of the HUD overlays. No z-index changes needed.

**Self-Test Report obligation per `.claude/docs/test-conventions.md` § "Author HTML5 self-soak":** Devon stage 3b MUST self-soak the HTML5 release build in incognito + DevTools console + visually verify the color tween renders in WebGL2. Per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate," a screenshot of the boss-state HUD-region + a screenshot of the post-defeat reverted state are both required. Renderer-safety argument alone is NOT a substitute.

## 7. Audio coupling — none

T15 is **purely visual.** No new audio cues fire from the HUD-region transition. The existing audio cues at the same timing slots (boss-intro nameplate bell on entry; boss-kill horn + silence-as-punctuation on defeat) carry the audio side of the moment. Adding a UI tick or chime to the HUD-region transition would diffuse the existing audio choreography — per `audio-architecture.md` § "Tonal pattern — silence as punctuation," the absence of audio under the HUD recolor IS the right call. The transition is felt visually, not heard.

## 8. Cross-references

- `team/uma-ux/boss-intro.md` § BI-20 (HUD top-right flips to red `STRATUM 1 · BOSS` during fight) — this doc fulfills.
- `team/uma-ux/boss-intro.md` § F4 (HUD top-right `STRATUM 1 · BOSS` returns to pre-fight state after defeat) — this doc fulfills.
- `team/uma-ux/hud.md` § 2 (Run context top-right) — historical canonical default; preserved.
- `team/uma-ux/palette.md` § Status / state colors — `#7A2A26` mob HP foreground hex source.
- `team/uma-ux/palette.md` § Core neutrals — `#E8E4D6` HUD body text default source.
- `.claude/docs/audio-architecture.md` § "Stratum-1 ambient — wiring + curves" — curve-discipline shape (sharp entry / soft exit / 60% hold) precedent.
- `.claude/docs/audio-architecture.md` § "Tonal pattern — silence as punctuation" — no-cue justification for §7.
- `.claude/docs/html5-export.md` § "HTML5 visual-verification gate" — Devon stage 3b QA gate.
- `.claude/docs/test-conventions.md` § "Author HTML5 self-soak" — Devon mandatory pre-Tess self-soak.
- `scenes/Main.gd:774-791` — existing TopRightContext Control + `_room_label` Label that Devon extends in stage 3b.
- `team/priya-pl/w3-dispatch-plan.md` § Brief 3 — full T15 chain (Uma stage 3a → Devon stage 3b).

## 9. Open questions

None — all calls within Uma's delegated authority made and locked. Decision shape:

1. **Red hex:** `#7A2A26` locked (per §2).
2. **Transition curve:** 0.2 s ease-in-out cubic entry; 0.4 s ease-out cubic exit + 1.5 s alpha-hold-at-60% (per §5).
3. **No ornamentation.** No pulse, no glyph, no underline. Label is the quiet anchor (per §4).
4. **No audio coupling.** Transition is silent (per §7).
5. **Default preserved at `#E8E4D6` off-white** (not `#B8AC8E` muted-parchment as the brief proposed). Decision-draft for Priya weekly batch: brief-to-canonical alignment if Sponsor later wants the muted default.

## 10. Tester checklist (yes/no — for stage 3b QA)

| ID | Check | Pass criterion |
|---|---|---|
| T15-H-01 | Default state shows `STRATUM 1 · ROOM x/8` in `#E8E4D6` off-white | yes |
| T15-H-02 | On `entry_sequence_completed.emit()`, text flips to `STRATUM 1 · BOSS` within 1 frame | yes |
| T15-H-03 | Color tween from `#E8E4D6` to `#7A2A26` completes in ≈ 0.20 s | yes |
| T15-H-04 | Boss state holds `STRATUM 1 · BOSS` in `#7A2A26` during the entire fight (no pulse, no flicker) | yes |
| T15-H-05 | On `boss_defeated.emit()`, text reverts to `STRATUM 1 · ROOM x/8` within 1 frame | yes |
| T15-H-06 | Color tween from `#7A2A26` to `#E8E4D6` completes in ≈ 0.40 s | yes |
| T15-H-07 | Alpha holds at 0.6 for ~1.5 s before restoring to 1.0 over 0.3 s (total exit window ~2.2 s) | yes |
| T15-H-08 | Region renders screen-space (CanvasLayer; not zoomed by CameraDirector at 1.5× during F2) | yes |
| T15-H-09 | All label pixels eye-droppable to `#E8E4D6` (default) or `#7A2A26` (boss) — no off-doctrine intermediate colors visible in the tween | yes (color tween is engine-rendered linear interp between locked endpoints; intermediate values are not eye-dropper-testable but must NOT exceed channel-1.0) |
| T15-H-10 | HTML5 soak: color tween visibly renders in WebGL2 incognito build — no flash / no invisibility regression | yes |
| T15-H-11 | BI-20 passes end-to-end (full intro → boss state → kill → revert) | yes |
