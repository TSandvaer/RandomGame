# M3-T4 — Defeat Title Card Direction Brief

**Owner:** Uma (direction) → Devon (implementation). **Ticket:** `86c9wjy8h`.
**Source-of-truth:** `team/uma-ux/boss-intro.md` Beat F3. This brief is the **production spec** for the title-card sub-beat; the full F1–F4 defeat sequence (time freeze, embers dissolve, horn, door unlock, ambient resume) is tracked by sibling tickets (T16 for embers + horn; T14 for door; T10 for ambient resume). T4 is **the wordmark**.

## Tonal anchor — one sentence

> The kill is the only moment in M1 where the world stops to honor the player. The title card is the silence that lets the kill land — two lines of off-white text breathing against a darkened room, no audio, no flourish on the type itself. The horn carries from F2; the card stays out of its way.

If the implementation feels theatrical, it is wrong. The card is the **comma after the climax**, not a fanfare. Embergrave is a stone room with one lit fire. The title card is that fire reflected in the player's eye after they have stopped fighting.

---

## 1. Visual spec

### Copy (lock — Sponsor-input candidate listed under §6)

| Element  | Text                                  | Source            |
|----------|---------------------------------------|-------------------|
| Title    | `The Warden falls.`                   | Templated: `"The %s falls." % MobDef.display_name.split(" ")[0]` — see §6 note 1 |
| Subtitle | `STRATUM 1 CLEARED`                   | Hard-coded for M1; M2+ templates by current stratum id |

**Period at the end of the title is intentional.** It is a declarative sentence, not a banner. Without the period the line reads as a banner ("THE WARDEN FALLS"); with the period it reads as narration — the difference between a sports broadcast and a eulogy. Embergrave is the latter.

### Typography & color anchors

| Element     | Value                                   | Rationale |
|-------------|-----------------------------------------|-----------|
| Title font size | **40 px**                           | One step below DescendScreen's 48 px title (`scripts/screens/DescendScreen.gd:159`). The descend screen is "you survived a stratum and chose to keep going" — bigger frame. The defeat card is "this boss is over" — single beat, more intimate. |
| Title color | `#E8E4D6` (HUD body off-white, per `palette.md:24`)        | Off-white wordmark. **NOT ember-orange.** Ember is for "the player's flame still burns" cues — descend, level-up, item-drops. The boss's death is not the player's flame; it is the absence of the boss's. Hold ember in reserve. |
| Title alpha | 1.0 (sub-1.0 channel safe — see §5)     | |
| Subtitle font size | **14 px caps**                   | Two steps below title (40 → 18 → 14). 14 px is the HUD body minimum from `hud.md:12` — readable at 720p HTML5. |
| Subtitle color | `#B8AC8E` (muted parchment, per `palette.md:25`) | The subtitle is the *context tag*, not the *headline*. Muted parchment recedes; off-white leads. |
| Subtitle letter spacing | normal Label default; rely on CAPS to telegraph "label not narration" | |
| Font face   | Godot 4.3 `gl_compatibility` default font (no custom `.ttf`) | Same as DescendScreen + every other M1/M2 UI text. Custom-font import is **out of scope** for T4; flag for M3 polish if Sponsor wants a wordmark face for the title. |
| Horizontal alignment | Center on both labels                  | |
| Vertical positioning | Title baseline at `viewport_h / 2 - 12 px`; subtitle baseline at `viewport_h / 2 + 24 px` (12 px gap between them) | Slightly above geometric center — reads as "rising" not "settling," tonally consistent with the embers in F2. |

### Background / scrim treatment

**No dedicated scrim.** The title card sits over the room as the vignette (T12, Wave 2) deepens to 80% during F2's dissolve. By F3 the room is already darkened to a dim periphery + a center where the embers were. Adding an additional scrim under the text would compete with the vignette and read as a UI panel — wrong.

**If T12 vignette is not yet landed at T4 ship time** (likely — T12 is Wave 2), use a **transient, text-only background**:
- A single ColorRect behind the two labels, sized to text bounds + 24 px padding, color `#1B1A1F` at **0% alpha**. The labels sit on the live game canvas.
- This is a load-bearing call: **the card is not a panel.** It is two lines of text appearing in the darkened space.
- If readability fails Sponsor soak (text fights room background), Devon may add a subtle drop-shadow on the Labels via `theme_override_constants/shadow_offset_x/y = 1` + `theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.6)`. **Drop-shadow only; no rect scrim.** Tess can verify shadow ≠ scrim during HTML5 visual-verification.

### CanvasLayer & node structure

The card is a CanvasLayer (z above HUD, z above world). Suggested scene shape — Devon may restructure freely so long as the timing and the visual outcome match:

```
BossDefeatedTitleCard (CanvasLayer, layer = 50)
└── Root (Control, anchor PRESET_FULL_RECT, mouse_filter = IGNORE)
    ├── TitleLabel (Label, centered)
    └── SubtitleLabel (Label, centered)
```

`mouse_filter = IGNORE` on the root so the card never absorbs clicks (player can still pick up loot beneath it once it shows — though in F3's timing window the loot has not dropped yet; see §3).

### Fade-in / hold / fade-out timing

Per Uma F3 (`boss-intro.md:147`): the card fades in at T+1.2 post-`boss_died`, holds, fades out. T4 commits these:

| Phase     | Duration | Property | Curve |
|-----------|----------|----------|-------|
| Fade-in   | **0.4 s** | `modulate.a: 0 → 1` on the Root Control | `Tween.EASE_OUT, Tween.TRANS_QUAD` — quick start, soft landing |
| Hold      | **0.8 s** | `modulate.a = 1`                         | flat |
| Fade-out  | **0.4 s** | `modulate.a: 1 → 0`                      | `Tween.EASE_IN, Tween.TRANS_QUAD` — soft start, quick exit |

**Total on-screen time: 1.6 s.** Both labels share the Root's modulate — fade them together; do not tween the labels individually (multiplying alphas can cause WebGL2 banding on the fade-in mid-frames).

After fade-out completes, the CanvasLayer should `queue_free()` itself so a re-trigger on a New Game + run instantiates a fresh node. Idempotency guard: a second `boss_defeated` emit while the card is on-screen is a **no-op** (the room emits exactly once — `Stratum1BossRoom.gd:427` — but pin it).

---

## 2. Audio spec

### The cue is silence.

Per Uma F3 audio map row (`boss-intro.md:183`): **no audio fires with the title card.** The card lands in the natural silence after `sfx-boss-kill-horn` (F2 cue, 0.9 s, fires at T+0.3 post-death, peaks as embers exit). The horn ends right as the card begins to fade in.

This is **load-bearing.** If a sting / chime / bell were added under the card, it would compete with the wordmark and break the "kill landed; world stops to honor" beat. The horn IS the title-card audio — the silence that follows is the punctuation. Hold the line on no-cue under the card.

### Audio routing dependencies (for Devon to verify wiring, NOT implement)

T4 does not source or wire any new cue. It depends on **F1 + F2 cues already firing in the runtime** to set up the silence the card sits in:

- F1 final-hit beat: combat SFX + boss music cut hard, single `sfx-bell-struck` at T+0.1 → covered by sibling ticket T2 (hit-pause/freeze) + T1 (S1 boss BGM crossfade — `boss_music_should_cut_here`). If T1/T2 are not yet landed at T4 ship time, the card still works tonally (silence is silence whether the music cut hard or simply was never playing), but Tess should flag the gap in the Self-Test Report.
- F2 horn: `sfx-boss-kill-horn` fires at T+0.3 for 0.9 s → covered by sibling ticket T16 (embers + horn). If T16 is not yet landed at T4 ship time, the card lands in **complete silence** (no horn rising into it). Tonally **acceptable** — silence-into-silence reads as gravity, not absence. Document the deferral in the PR body; do not block T4 on T16.

### What does NOT fire under the card (negative spec)

- No bell strike under the title text.
- No UI cue (`sfx-ui-tab-open` is a `Tab`-key panel cue, not a defeat cue — do not reuse).
- No `sfx-ember-rise` reuse. Ember-rise is the descend-confirm cue and the level-up flourish; it carries the player's flame forward. The boss-defeat card is about the boss being *gone*, not the player ascending. Wrong tonal register.

### Future M3 audio polish — flag, do not block

If Sponsor soak surfaces the silence as "too dead" (possible — silence is bold), an M3 follow-up could add a **very low sustained cello drone** (4-5 s, peaks at -30 dB, layered under the card fade-in then fading with the card). Spec it as `sfx-string-low-defeat` (mirror of `sfx-string-low-death` from death-flow Beat B). **Not in T4 scope.** Add the cue ID + asset placeholder to `audio-direction.md` only if Sponsor explicitly requests post-soak.

---

## 3. Timing relative to `boss_died` signal

### Anchor: `Stratum1BossRoom.boss_defeated(boss, death_position)` signal at T+0.0

This is the signal `BossDefeatedTitleCard` subscribes to. Per `scripts/levels/Stratum1BossRoom.gd:73,427` it fires synchronously inside the boss's `_die` chain. The card subscribes once at `_ready` (or wherever it is instantiated — see §6 note 2 on instantiation site).

### Timeline (T+0.0 = `boss_defeated` emit)

```
T+0.0    boss_defeated emits.
         T16 embers dissolve starts; T2 freeze starts (if landed).
         (T4 does nothing yet — wait 1.2 s.)

T+0.3    F2 horn fires (T16).
T+0.3 → +1.2  Embers dissolve, horn rises.

T+1.2    [T4 START] Title card fade-in begins (0.4 s).
         Horn is nearly out by this point — silence settling in.

T+1.6    Title card fully visible. Hold (0.8 s).
         T16 camera ease to 1.5x has reached peak; vignette at 80%.
         **THE CARD IS ON SCREEN FOR 0.8 s OF SILENCE.**

T+2.4    Title card fade-out begins (0.4 s).
         Per Uma F3: at T+1.6 (i.e. mid-hold of the card),
         loot drops at boss's last position with the standard
         pickup audio + light-beam VFX. THIS HAPPENS UNDER THE CARD,
         not after it. Player sees loot beam appear during the hold
         phase. Camera returns to player-anchored over 0.4 s starting at T+2.0.

T+2.8    Title card fully gone. queue_free().
         Door unlock chime + ambient resume kick in (T14, T10 — sibling tickets).
```

### Gating semantics — `boss_died` chain and downstream actors

**T4 does NOT gate any downstream actor.** The card is decorative. Specifically:

- **Loot drop:** fires at T+1.6 (per Uma F3 `boss-intro.md:149`) **under** the visible card. Loot is interactable as soon as it drops; the player can pick it up through the card (the card has `mouse_filter = IGNORE`). This is intentional — the player has *agency during the card*, not after it.
- **Door unlock (T14):** the entry-door's lock-bar unlock fires at T+2.4 (Uma F3) or whenever T14 schedules it. T4 does not block this.
- **Stratum-exit activation:** `StratumExit.activate()` is already deferred per PR #232 / #241 (see `.claude/docs/combat-architecture.md` Class A bug-class). T4 does not interact with this path.
- **Ambient resume (T10):** fires at T+2.4 onward. T4 does not block.

In short: **T4 is a visual-only side-effect of `boss_defeated`.** It does not change the existing signal chain. Devon should NOT add `await` or signal-chains that downstream actors wait on.

### `Engine.time_scale` interaction (important for HTML5)

If T2 (hit-pause / freeze) ships first, the card's tweens MUST survive a 0.3 s freeze at scale=0.0 spanning T+0.0 → T+0.3. T4's tweens fire after the freeze releases (T+1.2 ≫ T+0.3), so the natural pattern is fine: schedule the fade-in tween at T+0.0 with a built-in 1.2 s delay via `Tween.tween_interval(1.2)`. **Tweens default to scaled-process** — they will be paused during the freeze and resume after. The 1.2 s wall-clock target becomes ~1.5 s wall-clock if a 0.3 s freeze interrupts. **This is correct.** The card should appear 1.2 s of *game time* after `boss_defeated`, not 1.2 s of wall time — synchronised with the embers and horn (which also run on game time via T16's Tween).

If Devon prefers explicit wall-time control, use `process_mode = PROCESS_MODE_ALWAYS` on the CanvasLayer **only if** the tween should ignore the freeze. **Default to scaled-tween (`Tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)` with the node on `PROCESS_MODE_INHERIT`)** — this is the right tonal call: the card "feels" the freeze and lands after it.

GUT regression pin (suggested): `test_title_card_appears_one_two_seconds_after_boss_defeated_game_time` — uses `simulate_n_frames` against scaled delta to verify card visibility at game-time T+1.2.

---

## 4. Skip rule

### Per the boss-intro.md skip rule (`boss-intro.md:54`), the **intro** is skippable after the player's first boss kill. The **defeat card is NOT subject to the same rule.**

Uma's lock: **the defeat card is unskippable on every kill.** Rationale:

- The intro is theatre the player has already seen. Skipping it serves veteran replays.
- The defeat card is **0.4 + 0.8 + 0.4 = 1.6 s** of payoff after a ~30-60 s fight. There is nothing here to skip — the cost is bounded and the content is the climax of the run.
- More importantly: making the card skippable adds a UX surface (key-listener competing with whatever movement / pickup keys the player is hitting under the card) that creates a real risk of accidental skip. The card is dismissed by the fade timer; the player should not be able to skip it by hitting Enter while reaching for the dropped item.

**Negative spec:** Devon must NOT wire Esc / Enter / Space / movement keys to skip the card fade. Input falls through to the player (the card's `mouse_filter = IGNORE` is the structural enforcement).

**Exception — debug builds:** if Devon wants a `?fast=1` URL-param hook (per `html5-export.md` debug-tooling pattern) that collapses the card timing to 0.05 + 0.10 + 0.05 = 0.2 s for soak-iteration speed, that is fine. Not required; mention only if Devon finds the 1.6 s cycle slows his self-test loop.

---

## 5. HTML5-export caveats (pre-flagged for Devon)

Per `.claude/docs/html5-export.md`, three constraints apply:

### 5.1 HDR clamp on tween-target colors

**Rule (memory-codified):** every channel of every tween-target Color must be **strictly sub-1.0**. The two colors above already comply:

- `#E8E4D6` = `(0.910, 0.894, 0.839, 1.0)` — alpha is 1.0 but only the alpha; per PR #137 the alpha channel does not clamp the way RGB does. Safe.
- `#B8AC8E` = `(0.722, 0.675, 0.557, 1.0)` — safe.

**Devon: do not modulate the labels to a color brighter than their rest color during fade-in.** The fade is on `Root.modulate.a` (alpha-only, 0 → 1); RGB stays at `(1, 1, 1)` on the modulate. **Do not** tween the labels' `font_color` from a bright value down to the rest color — that pattern has the HDR clamp bite path.

### 5.2 Default-font glyph coverage

`The Warden falls.` + `STRATUM 1 CLEARED` are **plain ASCII only**. No glyph-coverage risk. Safe.

If Sponsor ever renames the boss to a name containing non-ASCII (e.g. `Ördgar`, `Vël'thor`) the title-card-render would land on the Godot 4.3 `gl_compatibility` default-font tofu trap (per `html5-export.md` § Default-font glyph coverage, PR #179). **Pre-flag for Devon:** if Sponsor renames the boss via `MobDef.display_name` to anything non-ASCII, the title card must import a custom `.ttf`. For now, lock the open question by sticking to ASCII names — see §6 note 1.

### 5.3 Visual-primitive discipline

The card uses **Label nodes only**. No Polygon2D. No CPUParticles2D. No Area2D state mutation. The Tween modulates `Control.modulate.a` — a Control-level draw property identical across all renderers (parallel to PR #140 mob hit-flash, which was platform-agnostic).

**This PR still requires HTML5 visual-verification** per the gate (`html5-export.md` § "A 'renderer-safe primitives' argument is NOT a substitute for a screenshot"). Devon's Self-Test Report must include a screenshot or screen-recording showing the card fading in over the post-embers room state. **No primitive-class self-exemption.**

### 5.4 No Tween.tween_callback into _physics_process side-effects

The card's fade-out completion handler should call `queue_free` (or set a flag). **It must NOT** call into any Area2D monitoring mutation or `add_child` that affects collision. T4 is purely cosmetic; the only path the fade-out callback should hit is `queue_free()`. (This is hygiene — there is no obvious surface that would tempt a wrong call here, but flagging it for completeness given `combat-architecture.md` § "Physics-flush rule" surrounding `boss_died` chains.)

### 5.5 Service-worker cache trap reminder

Devon: when iterating on the visual locally via HTML5 release-build, use the cache-clear ritual from `html5-export.md` § "Service-worker cache trap" — fresh extract + incognito + verify `BuildInfo` SHA. The card's text strings will appear unchanged across builds and obscure stale-cache bugs the worst.

---

## 6. Implementation handoff — concrete spec for Devon

### Files Devon will create

- `scenes/ui/BossDefeatedTitleCard.tscn` — the CanvasLayer + Root Control + two Labels per §1 node structure.
- `scripts/ui/BossDefeatedTitleCard.gd` — class extending `CanvasLayer`. Public API:

```gdscript
class_name BossDefeatedTitleCard
extends CanvasLayer

# Suggested constants (Devon to validate names against codebase style):
const FADE_IN_DURATION: float = 0.4
const HOLD_DURATION: float = 0.8
const FADE_OUT_DURATION: float = 0.4
const PRE_FADE_DELAY: float = 1.2  # game-time, scaled

const TITLE_COLOR: Color = Color("e8e4d6")
const SUBTITLE_COLOR: Color = Color("b8ac8e")
const TITLE_FONT_SIZE: int = 40
const SUBTITLE_FONT_SIZE: int = 14
const SUBTITLE_TEXT: String = "STRATUM 1 CLEARED"
const TITLE_TEMPLATE: String = "The %s falls."

# `boss` parameter type matches Stratum1BossRoom.boss_defeated signature.
func show_for(boss: Node, _death_position: Vector2) -> void:
    # ... templates title from boss.mob_def.display_name (see §6 note 1)
    # ... constructs tween: interval(PRE_FADE_DELAY) → fade-in → interval(HOLD) → fade-out → queue_free
```

### Files Devon will modify

- `scenes/Main.tscn` (or `scenes/levels/Stratum1BossRoom.tscn`, Devon's call on which CanvasLayer parent makes sense) — instantiate `BossDefeatedTitleCard` and wire its `show_for` to `Stratum1BossRoom.boss_defeated`. **Suggested:** instantiate lazily inside `Main._on_boss_defeated` so the node only exists when needed; `queue_free` on fade-out completes the lifecycle. The card does **not** live in the scene tree across the run; it instantiates per kill.

### Note 1 — copy templating, `display_name`, and "The Warden falls."

Current `resources/mobs/stratum1_boss.tres:9` has `display_name = "Warden of the Outer Cloister"`. The title needs `"The Warden falls."`, not `"The Warden of the Outer Cloister falls."` — the long form breaks the line cadence.

**Recommended templating logic for Uma-call (Sponsor-input candidate):**

```gdscript
# Take the first word of display_name. Works for "Warden of the Outer Cloister"
# → "Warden". Future bosses: "Stoker of Vault Forge" → "Stoker". Single-word
# names like "Vorgath" → "Vorgath". Always prepend "The".
var short_name: String = boss.mob_def.display_name.split(" ")[0]
title_label.text = "The %s falls." % short_name
```

This is Uma's call and is **lockable now** — it is a fallback rule that produces the right output for every boss across M1-M3 as currently named. If Sponsor wants per-boss override (some bosses might prefer `"Vorgath has fallen."` or `"The Stoker is undone."`), the cleanest path is to add an optional `short_defeat_name: String` to `MobDef` that overrides the splitting rule. **Not in T4 scope** — flag for M3 if soak surfaces the need.

### Note 2 — instantiation site

The card is a transient UI overlay. Two reasonable patterns:

1. **Lazy-instantiate in `Main._on_boss_defeated`** (or wherever Main wires the room's `boss_defeated` signal) → load PackedScene, instantiate, add as Main's child, call `show_for(boss, death_position)`. Card `queue_free`s itself on fade-out.
2. **Static instance in Main scene tree, normally hidden** → `show_for` makes it visible and runs the tween. Less GC churn but more state-management hassle.

**Uma recommends Pattern 1.** Lower static state surface; simpler GUT regression. The PackedScene `preload` cost is negligible (two Labels).

### Note 3 — GUT pin

Minimum paired test:

- `tests/test_boss_defeated_title_card.gd` — instantiates the card, calls `show_for(mock_boss, Vector2(0,0))`, verifies labels exist + text is `"The Warden falls."` / `"STRATUM 1 CLEARED"`. **Not a tween-timing test** (those are HTML5-renderer-fragile); a structural test only.
- Playwright pin (per scope doc T4 AC): assert title-card text visible in DOM/canvas snapshot 1.2-2.0 s post-`boss_died` trace line.

### Note 4 — defer-to-T16 compatibility check

If T16 (embers + horn + camera ease) lands AFTER T4 (likely — both are Wave 1 but independent), the card must visibly read against the **post-T16 background state** (vignette at 80%, camera at 1.5x zoom, boss sprite gone). Pre-T16, the card reads against the existing M2-ish background. **Both must be acceptable.** Devon: do a Self-Test soak with T16 not-yet-landed AND a soak after T16 lands; verify the card reads in both states. Uma will do a tonal-eye check on the second.

---

## 7. Sponsor-input items (queue for orchestrator-Sponsor surface)

These are direction calls Uma is making within delegated authority. **None block T4 dispatch.** Sponsor can reject any of them post-merge and we will respin.

1. **Copy lock — `The Warden falls.` (period included).** Per §1. Alternative: `THE WARDEN FALLS` (banner) — Uma rejects per tonal-anchor rationale.
2. **Defeat card silence (no audio).** Per §2. Alternative: low cello drone — Uma defers to M3 polish if Sponsor wants it post-soak.
3. **Unskippable defeat card.** Per §4. Alternative: skippable after first kill (mirror the intro) — Uma rejects per accidental-skip risk.
4. **Off-white wordmark, not ember-orange.** Per §1. Alternative: ember-orange title — Uma rejects per "hold ember in reserve for the player's flame" rationale.
5. **Templating rule — first word of `display_name`.** Per §6 note 1. Alternative: per-boss override field — Uma defers.

---

## 8. Cross-references

- `team/uma-ux/boss-intro.md` — full F1-F4 beat-by-beat. T4 is the F3-card subset.
- `team/uma-ux/palette.md:24-25` — off-white `#E8E4D6` + muted parchment `#B8AC8E`.
- `team/uma-ux/audio-direction.md:183` — defeat-card row (silence).
- `team/priya-pl/m3-tier2-boss-room-polish-scope.md` §3 T4 + §3.5 wave plan — sibling-ticket relationships.
- `.claude/docs/html5-export.md` — HDR clamp, default-font, visual-verification gate.
- `.claude/docs/audio-architecture.md` — `AudioDirector` for the cues that BRACKET the card (F1 cut, F2 horn).
- `.claude/docs/combat-architecture.md` — `boss_died` chain hygiene.
- `.claude/docs/time-scale-director.md` — game-time vs wall-time tween scheduling under freeze.
- `scripts/screens/DescendScreen.gd:140-208` — existing pattern reference for full-screen Label overlays (do not copy verbatim — that's a `Control` + button surface; T4 is a transient CanvasLayer).

---

## Non-obvious findings (for `.claude/docs/` maintainer)

- **Title-card "silence is the cue" pattern** — boss-defeat card audio spec is explicitly *no cue*. The preceding horn IS the title-card audio. If a future cue is added under the card, it competes with the wordmark and breaks the beat. Worth capturing as a tonal-coherence convention for any future "moment lands here" UI surface.
- **First-word display_name templating fallback** — `"The %s falls." % display_name.split(" ")[0]` is a rule that produces good output across the bosses currently in scope without per-boss copy fields. If M3+ bosses break the pattern, an optional MobDef override field is the cleanest extension. Pre-flag for the registry doc.
- **Tween game-time vs wall-time under freeze interaction with T11 TimeScaleDirector** — defeat sequences spanning a `freeze(0.3)` window should default to scaled tweens so visuals stay synchronised with the game-time beats (embers, horn). Wall-time tweens are right for the freeze-timer itself, wrong for downstream visuals. Worth capturing as a TimeScaleDirector usage convention for future cinematic-sequence specs.
