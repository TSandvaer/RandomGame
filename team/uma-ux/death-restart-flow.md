# Death & Restart-Run Flow (M1)

**Owner:** Uma · **Phase:** M1 · **Drives:** Devon's `DeathSequenceScene.tscn` and `RunSummaryScreen.tscn`, save-system hooks for stash + character-level persistence.

M1's loop is: player dies → run-progress lost (gear in stash kept, character level + XP kept) → straight back into a new run with one click. The whole flow has to feel like a story beat, not punishment, while still respecting that the player **lost something**. If we make it feel weightless, the next run feels weightless too.

## Design intent (one paragraph)

Death is a **comma**, not a full stop. The player's *flame* is what dies — the player as a person carries the level, the stash, and the lessons. The visual language is **embers gathering and rising**, not blood and ruin. Audio drops to a single sustained note and a single bell. The first thing the player sees after the death sequence is the **growth they kept**, not the failure that just happened.

## Sequence

### Beat A — Lethal hit lands (T+0.0 s)

- HP bar's red foreground hits 0.
- All input is locked.
- A 1-frame full-white screen flash, then snap to a **time-freeze** with the player avatar locked in the hit pose.
- Combat audio (mob shouts, swing whooshes) cuts hard. Ambient music drops in volume to 30%.

### Beat B — Embers gather (T+0.0 → T+0.8 s)

- Camera pushes in toward the player avatar — internal-pixel scale from 1.0× to 2.0× over 0.8 s, easing out.
- Vignette deepens to 90% opacity around the player.
- Ember particles (using `#FF6A2A` and `#FFB066` from `palette.md`) start drifting *up* from the player's feet, accelerating.
- The player sprite's outline glows ember for 1 frame, then begins to dissolve from the feet upward.
- Audio: ambient music fades to 0%; a single low sustained string note ramps in (~0.5 s).

### Beat C — Dissolve + bell (T+0.8 → T+1.6 s)

- The dissolve completes — player sprite fully replaced by an upward ember-stream that exits the top of the screen.
- World view desaturates to full B&W over 0.8 s.
- A single struck bell sounds at T+1.2 s — same bell sample as the splash and the title menu, intentionally rhyming.
- The on-screen title card **"You fell."** types in centered, in the Embergrave wordmark font, off-white `#E8E4D6`. Below it, in muted `#B8AC8E` 12 px caps: `Stratum 1 · Room 4 / 8`.

### Beat D — Hold + transition to summary (T+1.6 → T+2.4 s)

- "You fell." holds for 0.8 s.
- Background fades from desaturated world to pure panel-background `#1B1A1F` over 0.4 s.
- Run summary slides up from the bottom edge over 0.3 s.
- The title-card text moves from screen-center to the top of the summary panel.

### Beat E — Run summary screen (T+2.4 s onward — player-paced)

The summary screen has two functional jobs: (1) make the player feel the **growth that persisted**, (2) give a one-click path back into a new run.

```
+----------------------------------------------------------------------------+
|                                                                            |
|                              YOU FELL.                                     |
|                       STRATUM 1 · ROOM 4 / 8                               |
|                                                                            |
|  --- THIS RUN ---                                                          |
|    Mobs felled         7                                                   |
|    Time in run         6:42                                                |
|    Deepest room        4 / 8                                               |
|                                                                            |
|  --- KEPT ---                                                              |
|    Character level     3   (no change)                                     |
|    XP                  +180  (320 → 500)  *new level pending*              |
|    Stash               +1 item                                             |
|                                                                            |
|         +--+ +--+                                                          |
|         |T2|*|T1|     "Pyre-edged Shortsword"  +12 max HP                  |
|         +--+ +--+     "Worn Hauberk"            (no affix)                 |
|                                                                            |
|  --- LOST WITH THE RUN ---                                                 |
|    [grey-out shadow icons of items left in inventory at death]             |
|                                                                            |
|                                                                            |
|        [   D E S C E N D   A G A I N   ]   [ Return to Title ]            |
|                  (default focus)                                           |
+----------------------------------------------------------------------------+
```

Layout rules:

- **Panel** uses `#1B1A1F` at 100% opacity (not 92% — death is a stop-the-world moment).
- **Three sections, in this order:** *This Run* (neutral facts), *Kept* (the wins, large + bright), *Lost With The Run* (small, low-contrast — acknowledged but not dwelt-on).
- **Number animation:** every numeric value ticks up from 0 to its target over 0.6 s with a slight overshoot-and-settle. Ticks have a faint click-tick audio at 60 ms cadence. Ticks halt instantly if the player presses any key — autonomy first.
- **Stash items**: each gear card slides in from the left with a 100 ms stagger. The little `*` glyph between the cards is an ember pulse that dims-then-pulses once each card lands — it's the visual proof that those items moved into stash.
- **Lost-with-the-run** items are rendered as the same item icons but **desaturated to grey** and at 40% opacity. No tooltip on hover. No interaction. They are a deliberate small grief that gets the player nodding rather than raging.
- **Buttons:** *Descend Again* is the primary, ember-orange `#FF6A2A` background, off-white text, default focused. *Return to Title* is muted parchment `#B8AC8E` text on transparent background. **Enter** confirms the focused button. **Esc** also goes Descend Again — making "just keep playing" the lowest-friction action.

### Beat F — Descend Again (T+player-paced + 0.6 s)

- On confirm, audio plays the ember-rising whoosh from the splash screen.
- Summary panel fades to black over 0.3 s.
- Title card *"The flame remembers."* types in for 0.4 s on black (or skippable to 0.0 s).
- Black holds for 0.2 s.
- Fade up on stratum-1 first room — same first-room scene as the very first New Game, character has the same equipment + stash from immediately before the death (no inventory items kept by default unless we adopt the Uma-proposed M1 simplification).
- HUD slides in over 0.4 s (same as game start).
- Player has **full HP** at the new run's start.

### Beat G — Return to Title (alternative)

- Same audio: ember-rising whoosh, then the splash bell.
- Summary fades to black over 0.3 s.
- Title screen comes up. **Continue** is highlighted by default — hitting Enter takes the player back into a new run from there. A player who clicks Return to Title is making a "I'm done for now" gesture, and we don't make them re-navigate menus next launch.

## What persists, exactly

| Thing                            | Persists across run death? | Persists across quit? |
|----------------------------------|----------------------------|----------------------|
| Character level                  | yes                        | yes (save-system hook) |
| XP within current level          | yes                        | yes                  |
| Unspent stat points              | yes                        | yes                  |
| Allocated stat points (V/F/E)    | yes                        | yes                  |
| Stash contents                   | yes                        | yes                  |
| **Equipped items at time of death** | yes (M1 Uma proposal)   | yes                  |
| **Inventory items not in stash, at time of death** | yes (M1 Uma proposal — see below) | yes |
| Run-only counters (mobs felled, room reached) | no — reset             | no                   |
| Boss-defeated flag for the stratum | yes                      | yes                  |
| Lore notes / unlocked entries (M2+) | yes                     | yes                  |

### M1 inventory-on-death proposal (flag for Priya)

In *full* roguelite roguelite-like terms, inventory NOT in stash should be lost on death. But:

1. M1 has no stash UI (it's an M2 feature; the slot is a stub per `inventory-stats-panel.md`).
2. Teaching the *"move it to stash to keep it"* lesson without the stash UI is impossible.
3. M1 acceptance criterion #3 says *"a death does not lose character level or stashed gear"* — silent on inventory.

Uma's call: in M1, **all gear the player picked up persists across death** (equipped + inventory both feed into a virtual "stash" since there's no UI to manage it). The "Lost With The Run" section in the summary shows **gold and consumable stubs** (M2 content), keeping the visual language for when stash matters.

When stash UI lands in M2, the rule changes to roguelite-standard: equipped items + items moved to stash persist; unstashed inventory items are lost. The summary's Lost-With-The-Run section then shows real items.

**Logged as a decision in DECISIONS.md** when this doc commits.

## Failure modes the death flow must handle (test cases)

- **Player dies during inventory-open (Tab):** death sequence preempts the panel; panel closes instantly; sequence runs normally. Time-slow inside the panel does not slow the death sequence.
- **Player quits during the death sequence:** save the death state; on next launch, the player resumes at the run-summary screen (not the death sequence — they've seen that). Tess: explicit test case.
- **Player presses Esc before "You fell." card has typed in:** skip animations to the run-summary screen instantly.
- **Player rage-clicks Descend Again on first death:** still plays the audio cue and 0.3 s fade. Don't skip the cue — it's the rhythm that makes the loop feel intentional.
- **Two deaths back-to-back with bad luck (S1 boss kills you turn-1):** flow is the same. Run summary will read `Mobs felled 0`; that's fine — no negative messaging.
- **Player dies from environmental hazard (M2+):** same death sequence. The flow is hit-source-agnostic.

## Audio map (concrete cues for the placeholder pass)

| Beat | Cue | Asset placeholder name |
|------|-----|------------------------|
| A — lethal hit | Combat audio cuts | `audio_cut.ogg` (silence asset) |
| B — embers gather | Sustained low string fade-in | `death_string_low.ogg`, 0.8 s |
| C — dissolve | Held string continues | (same loop) |
| C — bell | Single struck bell | `bell_struck.ogg` (same as splash) |
| D — transition | Cross-fade to summary pad | `summary_pad.ogg`, 0.4 s in |
| E — number ticks | Soft click | `tick_soft.ogg`, 60 ms cadence |
| F — descend again | Ember-rising whoosh | `ember_rise.ogg` |
| F — fade-up | Stratum 1 ambient | `stratum1_ambient.ogg` (existing) |

All audio is M1 placeholder. Real scoring is M3.

## Copy spec

Every string the player sees in this flow:

| Where | String | Notes |
|-------|--------|-------|
| Title card | `You fell.` | Wordmark font, off-white `#E8E4D6`. Period included. |
| Subtitle | `Stratum 1 · Room 4 / 8` | Muted, 12 px caps. Updates from run state. |
| Summary section A | `THIS RUN` | Section header, ember-orange small caps. |
| Summary row labels | `Mobs felled`, `Time in run`, `Deepest room` | Sentence case, off-white. |
| Summary section B | `KEPT` | Section header, ember-orange small caps. |
| Summary row labels | `Character level`, `XP`, `Stash` | Sentence case, off-white. |
| Inline annotation | `(no change)` / `*new level pending*` | Italic, muted parchment `#B8AC8E`. |
| Summary section C | `LOST WITH THE RUN` | Section header, muted parchment small caps (NOT ember — quieter). |
| Primary button | `DESCEND AGAIN` | All caps, ember bg, off-white fg. |
| Secondary button | `Return to Title` | Sentence case, muted, transparent bg. |
| Title card on Beat F | `The flame remembers.` | Wordmark font; same as splash flavor line. |

## Pre-permadeath note (M2+)

Embergrave is **not** permadeath in v1. M3 may add a "True Ember" hard mode with permadeath. If that ships, this flow gets a new title-card variant ("Your flame is gone.") and a different summary that emphasizes the run rather than what was kept. We design for it now by keeping the flow's strings configurable through a single resource — no hardcoded copy in `DeathSequenceScene.tscn`.

## Hand-off

- **Devon:** `DeathSequenceScene.tscn` triggers on the player-HP-zero event. It owns input lock, camera push, dissolve VFX, audio cuts. On scene exit, hands to `RunSummaryScreen.tscn` which reads run-state from a singleton (`RunState.gd`) populated during gameplay. Buttons fire `EventBus.descend_again` and `EventBus.return_to_title`.
- **Drew:** the upward-drifting ember particle effect is reusable — also used in the level-up flow and the title-screen logo. Author once.
- **Tess:** the "Pre-summary save / quit / resume at summary" path is acceptance-critical. Add to the M1 test plan if not already there.

## Open questions

1. **Save schema for paused-at-death-summary state:** Devon's call. Uma flagged the requirement.
2. **Inventory persistence rule for M1:** Uma proposed all-gear-kept; awaiting Priya sign-off in `DECISIONS.md`.
3. **Music asset for the sustained string:** placeholder OK for M1; will be replaced with curated track in M3.

---

## Tester checklist (yes/no)

| ID    | Check                                                                                                | Pass criterion (yes/no) |
|-------|------------------------------------------------------------------------------------------------------|-------------------------|
| DR-01 | On HP=0, all player input is locked within 1 frame                                                  | yes                     |
| DR-02 | Beat A: combat audio cuts; ambient music drops to ~30% volume                                       | yes                     |
| DR-03 | Beat B: camera pushes in to 2× internal pixel scale over 0.8 s                                      | yes                     |
| DR-04 | Beat B: ember particles (`#FF6A2A`, `#FFB066`) drift upward from player                             | yes                     |
| DR-05 | Beat B: player sprite dissolves from feet upward                                                    | yes                     |
| DR-06 | Beat C: world desaturates to full B&W over ~0.8 s                                                   | yes                     |
| DR-07 | Beat C: single bell strike at ~T+1.2 s                                                              | yes                     |
| DR-08 | Beat C: "You fell." title card appears in wordmark font, off-white                                  | yes                     |
| DR-09 | Beat C: subtitle reads `STRATUM N · ROOM x/y` matching the actual death location                    | yes                     |
| DR-10 | Beat D: panel slides up from bottom over ~0.3 s                                                     | yes                     |
| DR-11 | Beat E summary contains three sections: THIS RUN, KEPT, LOST WITH THE RUN, in that order            | yes                     |
| DR-12 | Numeric values tick up from 0 to target over ~0.6 s with click-tick audio                           | yes                     |
| DR-13 | Number animation halts instantly on any key press                                                   | yes                     |
| DR-14 | Stash items slide in from left with 100 ms stagger, ember pulse on landing                          | yes                     |
| DR-15 | "Lost With The Run" items render desaturated grey at 40% opacity                                    | yes                     |
| DR-16 | Default button focus is on `DESCEND AGAIN`                                                          | yes                     |
| DR-17 | Pressing Enter triggers Descend Again; pressing Esc also triggers Descend Again                     | yes                     |
| DR-18 | After Descend Again confirm: ember-rising whoosh → fade to black → "The flame remembers." → S1 R1   | yes                     |
| DR-19 | After death, character level on new run matches level at time of death (M1 acceptance #3)           | yes                     |
| DR-20 | After death, items kept (per M1 inventory-persistence rule) are present on the new run              | yes                     |
| DR-21 | Quit during death sequence; relaunch resumes at run-summary screen, not the dissolve sequence       | yes                     |
| DR-22 | Death during inventory-open Tab: panel closes instantly; death sequence runs normally               | yes                     |
| DR-23 | Player can press any key to skip "You fell." card to the summary screen                             | yes                     |
| DR-24 | Two deaths back-to-back: each plays the full sequence; no state bleed between deaths                | yes                     |
| DR-25 | After Return to Title, next launch / Continue picks up character at level kept from death           | yes                     |
