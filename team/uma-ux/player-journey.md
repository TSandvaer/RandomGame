# Player Journey — Title to First Death

**Owner:** Uma · **Phase:** M1 · **Drives:** Devon's UI scenes, Drew's mob/loot timing, Tess's acceptance script.

This is the moment-by-moment cold-open journey of a brand-new Embergrave player. The acceptance bar is *cold launch to first mob killed in ≤ 60 seconds* (M1 criterion #2), so every beat is timing-aware.

## Design north stars

- **Adventurous, not punishing.** First death must feel like a story beat, not a wall.
- **Read the screen in one second.** HUD never makes the player squint.
- **The two ladders are visible.** Run progress (depth, this-run gear) vs. permanent progress (character level, stash) are always told apart.
- **No tutorial blocking.** Teach by what's on-screen plus a single non-modal prompt at a time. WASD/space/LMB/RMB are the only verbs.

## Key for each beat

- **Beat:** what's happening on screen.
- **Player feels:** target emotion (one or two words).
- **System feedback:** visual / audio / haptic (we have no haptic on web; "haptic" here = controller rumble in M2+, harmless to spec early).
- **UI surfaces:** anything Devon needs to build for this beat.
- **Time budget:** elapsed-from-launch target.

---

## Beat 1 — Cold-open splash (0:00 – 0:03)

- **Beat:** Black screen → ember-glow logo fades up → "Embergrave" wordmark + a single line of flavor: *"The flame remembers."*
- **Player feels:** intrigued, oriented.
- **System feedback:**
  - Visual: 1.5 s logo fade-in, ember particles drift upward. Wordmark settles, flavor line types in.
  - Audio: deep low brass swell + a single struck bell.
  - Haptic: n/a.
- **UI surfaces:** `SplashScene` — logo image, particle layer, flavor-line label. Skippable on any input.
- **Time budget:** 0:00 – 0:03 (3 s; skippable to 0:01).

## Beat 2 — Title menu (0:03 – 0:08)

- **Beat:** Background fades to a painted vignette of the buried city's mouth. Menu items appear vertically: **New Game**, **Continue** (greyed out if no save), **Settings**, **Quit**. Default focus is the safe choice — "New Game" on first launch, "Continue" on subsequent launches.
- **Player feels:** in control, ready.
- **System feedback:**
  - Visual: cursor on default item glows ember-orange. Menu items fade in staggered (40 ms apart). The version + build hash sit in the bottom-right corner in muted grey for QA.
  - Audio: ambient wind loop + faint distant bell tolls (~30 s loop).
- **UI surfaces:** `TitleMenu` — vertical list, ember-cursor, audio loop, version label. Mouse hover and arrow keys both work; **Enter** or **LMB** confirms.
- **Time budget:** 0:03 – 0:08 (~5 s for the player to read and click).

## Beat 3 — New-game stinger + drop-in (0:08 – 0:14)

- **Beat:** On "New Game" click, screen fades to black for ~0.5 s. A single-paragraph title card types in over black: *"Eight strata down, the flame still burns. Find it."* Then fade up on the player avatar standing in the first room of stratum 1, cursor blinking on the avatar for half a second to draw the eye. **No name-entry, no class-pick.** Save slot is created automatically.
- **Player feels:** dropped in, curious.
- **System feedback:**
  - Visual: ~0.5 s black, then 1.5 s typewriter card (skippable on any input, total cap 2.5 s), then 0.5 s fade-up on the room. The avatar idle-breathes; a soft glow pulses on the player sprite for the first second only — gone before any prompt.
  - Audio: title card has wind only. On fade-up: ambient stratum-1 loop starts (low drum + dripping water).
- **UI surfaces:** `IntroCardScene` (text label + skip-prompt) → `WorldRoot` enters with `Stratum1.tscn`. HUD slides in from edges over 0.4 s.
- **Time budget:** 0:08 – 0:14 (skippable to 0:10).

## Beat 4 — First input prompt (0:14 – 0:20)

- **Beat:** Player is standing in a small chamber. Across the room, a non-threatening **practice dummy** stands lit by a brazier. A single ghost-text prompt appears centered low: **"WASD to move."** Once the player moves any direction for ~0.3 s, the prompt fades and is replaced by **"Space to dodge-roll."** After one successful roll, that fades and **"LMB to strike."** appears.
- **Player feels:** capable, learning by doing.
- **System feedback:**
  - Visual: prompts are bottom-center, white text with 60% opacity, no panel background. Prompt advances when the input is performed *once*. If the player ignores a prompt for 8 s, it gently pulses but never escalates.
  - Audio: footsteps on stone; dodge-roll has a cloth-whoosh. Sword swing has a clean steel-cut.
  - Animation feel: the avatar's first three actions get a subtle 1-frame freeze on contact for emphasis; this fades after the tutorial loop.
- **UI surfaces:** `TutorialPromptOverlay` — single non-modal label, fades in/out over 0.2 s, never blocks input. Driven by an event bus so Devon can fire it from any beat.
- **Time budget:** 0:14 – 0:20 (~6 s).

## Beat 5 — First room cleared, doorway opens (0:20 – 0:26)

- **Beat:** The dummy takes hits and harmlessly poofs into ember-dust on the third strike. A **stone door** at the far end audibly grinds open. A new prompt: **"RMB for heavy strike."** The room is otherwise empty — the player can practice if they want, ignore if they don't, and walk through the door to the next room.
- **Player feels:** small win, agency, momentum.
- **System feedback:**
  - Visual: dummy explosion is a 0.4 s ember-poof; door-open is a slow grind with dust. Camera does a tiny push-in (~5%) toward the door for 0.5 s to direct the eye.
  - Audio: dummy poof = soft whump, door = stone grind + bell tone.
- **UI surfaces:** none new — same HUD, same overlay, room transition handled by `RoomConnector` resource.
- **Time budget:** 0:20 – 0:26.

## Beat 6 — First mob encounter (0:26 – 0:40)

- **Beat:** Through the door, a slightly bigger room. A **grunt mob** patrols a short path. It sees the player at ~6-tile range, telegraphs (raises weapon, eyes light up red) for ~0.4 s, then charges and swings.
- **Player feels:** alert, assessed, slightly tense.
- **System feedback:**
  - Visual: mob has a **nameplate** above it (small, grey-on-dark, only on aggro). Its HP bar appears under the nameplate. The aggro telegraph is a brief red glow on the mob's silhouette + a small red triangle pip pointing at the mob's intended target. Player hit-flash is a 1-frame white flash + a 4-pixel screen-shake.
  - Audio: mob aggro hiss; weapon-clang on player block/dodge whiff; pain-grunt on player hit; small ducking of ambient music for ~1 s on aggro.
- **UI surfaces:** `MobNameplate.tscn` (procedurally spawned per mob, only renders when mob is in aggro state). Hit-flash + camera-shake are effects, not UI.
- **Time budget:** 0:26 – 0:40 (mob fight ~14 s, allowing 2–3 hit exchanges).

## Beat 7 — First hit taken (within Beat 6, ~0:32)

- **Beat:** Most players will eat one hit while learning the dodge timing.
- **Player feels:** "ow — but I get it now."
- **System feedback:**
  - Visual: HP bar on the HUD takes a clear *delayed-damage* treatment — the white "ghost" portion drains over ~0.6 s after the red portion has dropped, so the player can read how much they lost. Player sprite hit-flash + 6 px nudge in hit direction. Vignette pulses red briefly when HP < 33%.
  - Audio: thud + grunt + a low heart-thump if HP < 33%.
- **UI surfaces:** HUD HP bar handles the delayed-damage style natively. See `hud.md`.
- **Copy-side:** No tutorial text on first hit. We don't break the moment to explain.

## Beat 8 — First kill + loot drop (0:40 – 0:50)

- **Beat:** Mob HP hits zero. It staggers, sparks, and bursts into ember-dust. A **gear drop** lands on the floor with a satisfying clang and a vertical beam of light in the gear's tier color (T1 = bone white, T2 = warm bronze, T3 = cold steel-blue). An XP popup floats up from the corpse — `+12 XP` in soft gold.
- **Player feels:** rewarded, hungry for more.
- **System feedback:**
  - Visual: 0.3 s death animation, ember burst, beam-of-light over the dropped item that pulses once per second (so it's always visible). Camera does a tiny zoom-out (3%) over 0.4 s to "exhale." A new prompt **"E to pick up."** appears when the player walks within pickup range.
  - Audio: soft "shink" on item drop, XP popup has a high chime that pitches up with kill streaks (M2 polish, stub for M1).
  - Animation feel: 1-frame hit-stop on the killing blow.
- **UI surfaces:** `LootBeam` particle effect + `ItemPickupPrompt` overlay (E to grab; auto-prompt only when in range). The first item the player ever picks up triggers a one-time **toast**: *"Tab to view inventory."*
- **Time budget:** 0:40 – 0:50.

## Beat 9 — First inventory open (optional, 0:50 – 1:05 if taken)

- **Beat:** Player presses Tab. Time slows to ~10% (does not pause — adventurous feel) while the inventory & stats panel slides in from the right edge over 0.2 s. The new item glows in its grid slot. Hovering the item shows a tooltip with name, tier, base stats, and any rolled affixes (M1: weapon and armor only, T1–T3, up to 3 affixes total in pool).
- **Player feels:** nerdy joy of a new item.
- **System feedback:**
  - Visual: dim background to ~60% on panel open. New-item glow loops until first hover. Equip/unequip is a single click on the item, or drag-to-slot.
  - Audio: panel-open swoosh; item-hover soft tap; equip click is a satisfying steel-snap.
- **UI surfaces:** `InventoryStatsPanel` — full spec in `inventory-stats-panel.md`.

## Beat 10 — First level-up (somewhere 1:30 – 4:00, after a few kills)

- **Beat:** XP bar fills to 100%. A celebratory pulse of gold light rings the player; an unobtrusive **+1 STAT POINT** badge slides into the top-right of the HUD. The player can keep fighting or hit Tab → "Stats" tab to spend the point on Vigor / Focus / Edge.
- **Player feels:** noticed, rewarded, autonomy-respected (no forced modal).
- **System feedback:**
  - Visual: full-body player glow for 0.5 s; XP bar gets a one-time gleam sweep.
  - Audio: rising chord, three-note motif (becomes the Embergrave level-up signature across the project).
- **UI surfaces:** stat-point badge on HUD; spending happens inside the inventory & stats panel. **No mid-fight modal popup, ever.**

## Beat 11 — First death (anywhere 5:00 – 15:00 in)

- **Beat:** Player HP hits zero. Time freezes for a beat — the player avatar locks into the hit pose, ember-light gathers around them, and the camera pushes in for ~0.8 s. Then the avatar dissolves into embers that rise and drift upward off-screen. Screen desaturates (full B&W) and slowly fades to black behind a clean **"You fell."** title card. Beneath it: a quiet run summary.
- **Player feels:** sober but not punished. *"I lost the run, not the character."*
- **System feedback:**
  - Visual: time-freeze on lethal hit, push-in, dissolve. Desaturation ramps over 1.0 s. Title card "You fell." in the same wordmark font as the Embergrave logo.
  - Audio: combat audio cuts; one held string note; a single bell at the title-card moment. Ambient stops entirely.
- **UI surfaces:** `DeathSequenceScene` then `RunSummaryScreen`. Full beats and copy in `death-restart-flow.md`.
- **Time budget:** 4–6 s of death sequence + however long the player reads the summary.

## Beat 12 — Path back into a new run (immediately after summary)

- **Beat:** Run summary screen shows: depth reached, mobs killed this run, gear earned (with what's now in stash highlighted), XP gained, **character level kept**. Two buttons: **Descend Again** (primary, ember-orange) and **Return to Title** (secondary, muted). Default focus is **Descend Again**.
- **Player feels:** forward momentum > grief.
- **System feedback:**
  - Visual: panel slides up from bottom over 0.3 s. Numbers tick up rapidly (counting animation) over 0.6 s — feels generous and earned. The "stash kept" gear pieces glow and slide a few pixels into a stash icon to *show* persistence.
  - Audio: respectful low pad. On "Descend Again," a rising whoosh; back to title, the same bell as the splash.
- **UI surfaces:** `RunSummaryScreen` (full spec in `death-restart-flow.md`).

---

## Cross-cutting feedback rules (Devon, build these once)

1. **No modal during combat.** Level-up, item pickup, quest popups, anything — non-modal toasts/badges only.
2. **Damage-and-XP popups float up and fade in 0.8 s.** Numbers are off — color-coded (white = damage to mob, red = damage to player, gold = XP, ember-orange = crit).
3. **Hit-flash on player and mobs is a single 60 ms white frame** plus a directional 4–8 px nudge. No long stuns on whiffs.
4. **All toasts come through one event bus.** `EventBus.toast(msg, duration, kind)` so Tess can intercept for tests and Uma can rewrite copy without code changes.
5. **HUD elements never overlap the playfield's center 60%.** Combat is always visible.
6. **One prompt at a time, ever.** Tutorial overlay is FIFO — never two ghost prompts on screen.
7. **Skippable everywhere.** Splash, title card, death sequence — any input dismisses or fast-forwards.

## Hand-off

- **Devon:** scenes named in this doc are your scaffold. Build the event bus first (Beat 6 onward depends on it).
- **Drew:** the grunt mob's aggro telegraph (0.4 s red glow + targeting pip), death poof, and item-drop beam are content-side. Spec lives in `team/drew-dev/` once Drew picks them up.
- **Tess:** the 0:00 → first-kill timing budget here matches M1 acceptance criterion #2 (≤ 60 s). Use the per-beat times as the script.
- **Open question for Priya:** XP value `+12` is a mockup stub. Real number is Priya/Devon's call.

---

## Tester checklist (yes/no per beat)

Per `team/TESTING_BAR.md`. Each row is something a tester can verify by playing through the cold-open without instrumentation. All times measured from "click New Game."

| ID    | Beat | Check                                                                                | Pass criterion (yes/no)                          |
|-------|------|--------------------------------------------------------------------------------------|--------------------------------------------------|
| PJ-01 | 1    | Splash logo + flavor line render within 3 s of cold launch                           | yes                                              |
| PJ-02 | 1    | Any input during splash skips it, total elapsed ≤ 1 s                                | yes                                              |
| PJ-03 | 2    | Title menu shows 4 items: New Game, Continue, Settings, Quit                         | yes                                              |
| PJ-04 | 2    | First launch: "Continue" is greyed out and not selectable                            | yes                                              |
| PJ-05 | 2    | Second launch with save present: "Continue" focused by default                       | yes                                              |
| PJ-06 | 2    | Build hash visible in bottom-right corner                                            | yes                                              |
| PJ-07 | 3    | "New Game" → black screen ≤ 0.6 s → typewriter card → fade to room (≤ 6 s total)     | yes                                              |
| PJ-08 | 3    | HUD slides in from edges within 0.5 s of player gaining control                      | yes                                              |
| PJ-09 | 4    | "WASD to move" prompt visible, bottom-center, white 60% opacity, no panel            | yes                                              |
| PJ-10 | 4    | Moving any direction for ≥ 0.3 s replaces prompt with "Space to dodge-roll"          | yes                                              |
| PJ-11 | 4    | One successful dodge replaces prompt with "LMB to strike"                            | yes                                              |
| PJ-12 | 4    | Only one tutorial prompt is on screen at any time                                    | yes                                              |
| PJ-13 | 5    | Hitting the dummy 3 times triggers ember-poof and door grind; door opens             | yes                                              |
| PJ-14 | 5    | "RMB for heavy strike" prompt appears after dummy poof                               | yes                                              |
| PJ-15 | 6    | Grunt mob aggros at ≤ 6 tile range, telegraphs ~0.4 s before charge                  | yes                                              |
| PJ-16 | 6    | Mob shows nameplate + HP bar above sprite ONLY when aggro'd                          | yes                                              |
| PJ-17 | 7    | Player taking damage causes 1-frame white flash + 4–8 px directional nudge           | yes                                              |
| PJ-18 | 7    | HUD HP bar shows delayed-damage ghost layer that drains over ~0.6 s                  | yes                                              |
| PJ-19 | 7    | Vignette pulses red when HP < 33% of max                                             | yes                                              |
| PJ-20 | 8    | Mob death produces ember-burst + item drop with tier-color beam                      | yes                                              |
| PJ-21 | 8    | "+XP" popup floats up from corpse and fades within 0.8 s                             | yes                                              |
| PJ-22 | 8    | Pickup prompt "E to pick up" appears only when player is in pickup range             | yes                                              |
| PJ-23 | 8    | First-ever pickup triggers one-time toast "Tab to view inventory"                    | yes                                              |
| PJ-24 | 9    | Tab opens panel within 0.3 s; world time-slows to ~10% (does not freeze)             | yes                                              |
| PJ-25 | 10   | XP bar reaching 100% triggers gold body-glow ≤ 0.5 s + 3-note motif                  | yes                                              |
| PJ-26 | 10   | After level-up, `[+1 STAT]` pip appears in bottom-right of HUD                       | yes                                              |
| PJ-27 | 10   | Level-up does NOT pause the game or open a modal                                     | yes                                              |
| PJ-28 | 11   | Player HP=0 triggers time-freeze, push-in, dissolve, B&W desaturation, "You fell." card | yes                                          |
| PJ-29 | 11   | Death sequence is ≤ 6 s before run summary appears                                   | yes                                              |
| PJ-30 | 12   | Run summary defaults focus on "Descend Again" button                                 | yes                                              |
| PJ-31 | 12   | Run summary shows numbers ticking up over ~0.6 s on appear                           | yes                                              |
| PJ-32 | end-to-end | Cold launch → first mob killed in ≤ 60 s with default skip-rates (M1 acceptance #2) | yes                                       |

Failure of any row is a `bug(ux)` filing per Tess's severity rubric.
