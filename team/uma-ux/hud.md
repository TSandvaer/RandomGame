# HUD — In-Combat Overlay (M1)

**Owner:** Uma · **Phase:** M1 · **Drives:** Devon's `HUD.tscn`, mob nameplates, in-world toast/popup conventions.

The HUD is the single most-seen surface in Embergrave. Adventurous feel demands the playfield breathes — the HUD never crowds the screen. Every element earns its pixels.

## Design constraints

- **Center 60% of screen is sacred.** No HUD element draws there during normal play.
- **Four corners + bottom rim only.** Top-left = player vitals, top-right = run context (depth + stratum), bottom-center = ability cooldowns, bottom-right = run-state badges (level-up pip, gold count later).
- **Always-on, never-flashing.** The HUD does not strobe. Flashes are reserved for *events* (hit-flash, level-up gleam) not idle state.
- **Readable at 720p HTML5.** Everything is a minimum 14 px font. Iconography wins over copy.

## Top-level mockup (1280 × 720 reference)

```
+-----------------------------------------------------------------------------------------+
| [PORTRAIT]  HP ████████████░░░░  82/110                          STRATUM 1  ·  ROOM 3/8|
| LV 3        XP ██████░░░░░░░░░░  320/500                                                |
|                                                                                         |
|                                                                                         |
|                                                                                         |
|                                                                                         |
|                          (   PLAYFIELD — no HUD draws here    )                        |
|                                                                                         |
|                                                                                         |
|                                                                                         |
|                                                                                         |
|                                                                                         |
|                                                                                         |
|                                                                              [+1 STAT] |
|                                                                                         |
|        +-------+   +-------+   +-------+                                                |
|        |  LMB  |   |  RMB  |   | SPACE |                                                |
|        | LIGHT |   | HEAVY |   | DODGE |                                                |
|        |  --   |   | 0.7s  |   |  --   |                                                |
|        +-------+   +-------+   +-------+                                                |
+-----------------------------------------------------------------------------------------+
```

## Element-by-element spec

### 1. Player vitals (top-left)

- **Portrait** — 48×48 of the avatar's face, ember-rim at 2 px. Quietly emotes when HP < 33% (eyes narrow, jaw set). Recovers calm when HP > 66%.
- **HP bar** — 220 px wide × 14 px tall.
  - Foreground (current HP): warm red `#D24A3C` with a 1 px highlight on the top edge.
  - "Ghost" damage layer: a paler `#F0A89B` that drains *behind* the foreground. When you take a hit, the foreground drops instantly; the ghost layer drains over ~0.6 s. This makes "I just lost 18 HP" legible at a glance.
  - Background empty: dark slate `#2A262C`.
  - Numeric `82/110` to the right of the bar in `#E8E4D6`, 14 px. Also legible if max HP changes from gear (max value ticks up in ember-orange briefly).
- **XP bar** — 220 px × 6 px (thinner than HP — it's secondary in combat).
  - Foreground: gold `#E0B040`.
  - Background: dark slate.
  - Numeric `320/500` in muted `#B8AC8E`. Smaller than HP numbers so it doesn't distract.
  - On level-up, the bar does a one-time horizontal gleam-sweep, fills to 100% briefly, then resets to overflow value.
- **LV label** — sits below the portrait, "LV 3" in 16 px ember-orange. Flashes once on level-up then stays static.

### 2. Run context (top-right)

- **STRATUM N · ROOM x/y** — small, 14 px, off-white. e.g. `STRATUM 1 · ROOM 3/8`. The room counter increments as the player clears each room.
- For M1 only stratum 1 exists, but the counter is built once and survives M2+.
- On entering a new room: the text gets a half-second glow-pulse. On entering a boss room: text changes to `STRATUM 1 · BOSS` in red `#D24A3C` with a slow heartbeat pulse.
- This corner is also where a small **save icon** flickers for 0.4 s on autosave (a quill-and-ember glyph). Reassurance, not alarm.

### 3. Ability cooldowns (bottom-center)

Three squares, 64×64 each, 16 px gap between, sitting 24 px above the bottom edge. Centered horizontally.

```
+-------+   +-------+   +-------+
|  LMB  |   |  RMB  |   | SPACE |
| LIGHT |   | HEAVY |   | DODGE |
|  --   |   | 0.7s  |   |  --   |
+-------+   +-------+   +-------+
   |__________ |__________ |
        |          |        |__ Dodge-roll. Stub for M1 — the actual i-frame
        |          |             window is on the player; the icon shows the
        |          |             *cooldown after the roll completes* (500 ms
        |          |             default per Priya).
        |          |__ Heavy attack — slower windup, bigger hit. ~1.0 s cooldown.
        |__ Light attack — fast, low cooldown (~0.2 s, often shows --).

```

For each cooldown square:

- **Default state**: ability icon centered (sword silhouette / heavy axe / dodge-roll glyph). Key hint along the top edge in tiny caps. Label along the bottom in 10 px caps.
- **On press**: icon dims to 40% and a *radial wipe* clockwise sweeps the square as cooldown drains. Time remaining `0.7s` shows in white in the center, replacing the icon.
- **Available again**: a 1-frame ember-flash on the square's border. Subtle. Not a fanfare.
- **Unusable** (e.g. dodge during stagger): square goes red-tinted and the icon shakes one tick.

The three-square layout scales linearly to four/five squares in M2 when off-hand and relic ability come online — same square, same conventions. Future-proof.

### 4. Run-state badges (bottom-right)

- **Stat-point pip** `[+1 STAT]` — appears when the player has unspent stat points. Ember-orange pill. Tooltip on hover: *"Tab → Stats. Spend at any time."* Doesn't pulse, doesn't blink. Just there.
- **Gold counter** (M2+ stub for now) — small grey rectangle showing `0G`, lined up below the stat pip slot so the layout is final.
- **Stash badge** (M2+ stub) — also reserved here.

### 5. Damage / XP popup numbers (in-world)

Spawned at the world position of the hit / kill, *not* on the HUD per se but follows the HUD's color rules.

- White: damage dealt to mob (e.g. `14`).
- Ember-orange: critical hit (e.g. `28!` with the exclamation glyph).
- Red: damage taken by player (e.g. `-12`).
- Gold: XP gained (e.g. `+12 XP`).
- All popups float up ~24 px and fade over 0.8 s.
- Stack sensibly — if multiple numbers spawn within 100 ms in the same area, they fan out 12 px apart so they don't perfectly overlap.

### 6. Mob nameplates (over each hostile mob)

```
   GRUNT                     <- 12 px caps, off-white, 2 px outline
  ████████████░░░░           <- 80 px × 4 px HP bar, dark red
```

- Only renders when the mob is **aggro'd** to the player or has been hit. Idle mobs at distance have no nameplate (less screen clutter, more mystery).
- Nameplate sits 24 px above the mob's sprite. Anchored in world space so it follows the mob.
- HP bar uses the same ghost-damage treatment as the player HP bar but in dark red `#7A2A26` foreground / `#3A1614` background.
- Elite mobs (M2 content): name in ember-orange + a small star pip.
- Boss: nameplate is centered at the **top of the screen** (not above the boss sprite), wider — 480 px HP bar, with the boss name and an underbar showing **phase 1 / 2** as the fight progresses.

## State transitions

- **HUD slide-in (game start):** the four HUD regions slide in from their respective edges over 0.4 s once the player is in control (per `player-journey.md` Beat 3).
- **HUD on Tab (inventory open):** the HUD remains visible but drops to 70% opacity behind the panel, except the HP bar which stays at 100% (vital — see `inventory-stats-panel.md` time-slow rule).
- **HUD on death:** every HUD element fades to 0% over 1.0 s in sync with the world desaturating (Beat 11). Death sequence + run summary use their own UI.
- **HUD on stratum boss room enter:** HP/XP unchanged, top-right region flips to `STRATUM 1 · BOSS` red treatment, and a wide boss nameplate slides in from the top.

## Color palette (cross-references `palette.md`)

| Element                  | Hex       | Notes                              |
|--------------------------|-----------|------------------------------------|
| HP foreground            | `#D24A3C` | warm red                           |
| HP ghost                 | `#F0A89B` | paler tint of HP                   |
| HP background            | `#2A262C` | dark slate                         |
| XP foreground            | `#E0B040` | gold                               |
| XP background            | `#2A262C` | dark slate                         |
| Stratum/Room text        | `#E8E4D6` | off-white                          |
| Boss tag                 | `#D24A3C` | warm red                           |
| Damage to mob            | `#FFFFFF` | pure white                         |
| Critical hit             | `#FF6A2A` | ember-orange                       |
| Damage to player         | `#D24A3C` | warm red                           |
| XP gained                | `#E0B040` | gold                               |
| Cooldown wipe            | `#3A3540` | mid slate (transparent overlay)    |
| Available-again flash    | `#FF6A2A` | ember-orange                       |
| Stat-point pip           | `#FF6A2A` | ember-orange                       |
| Mob HP foreground        | `#7A2A26` | dark red                           |
| Mob nameplate text       | `#E8E4D6` | off-white                          |

## What we are deliberately NOT putting in the M1 HUD

- **Mini-map.** Stratum 1 is 8 hand-arranged rooms — not enough to warrant a map. Reconsider in M2 when stratum 2+ exist.
- **Quest tracker.** Quests are M3 content.
- **Combat log / damage feed.** Floating numbers do this job at 1/10 the screen real-estate.
- **Buff/debuff icons.** No status effects in M1's three-affix pool.
- **Active relic ability.** No relic slot in M1.
- **Chat/social anything.** Single-player.

These are deliberately stubbed out of the layout. When M2 lights them up, they take known reserved positions (relic = 4th cooldown square, gold + stash + buffs = bottom-right badge stack).

## Hand-off

- **Devon:** `HUD.tscn` is one canvas-layer scene with the four region nodes (`TopLeftVitals`, `TopRightContext`, `BottomCenterCooldowns`, `BottomRightBadges`). Each region is independently positioned via anchors so resizing the window doesn't break the layout. HP bar's ghost-damage layer is two `TextureProgress` nodes stacked, the underneath one tweens its value down with a 0.6 s delay.
- **Drew:** Mob nameplates spawn from `MobNameplate.tscn`, parented to each mob node. Mob TRES exposes `display_name`, `is_elite`, `is_boss`. Boss nameplates use `BossNameplate.tscn` and parent to the HUD canvas, not the mob.
- **Tess:** the HUD must remain interactable / readable across 720p, 900p, 1080p HTML5 windows. Acceptance test: run the game at three resolutions, screenshot each, eyeball that nothing overlaps the playfield's center 60%.

## Open questions

1. Cooldown durations (`0.7s` heavy, `0.5s` dodge) are stubs — Priya/Devon balance call.
2. Save-icon flicker on autosave — confirm with Devon that the autosave hook fires the event Uma will listen for. If not, drop the flicker for M1 — the autosave is silent.

---

## Tester checklist (yes/no)

Per `team/TESTING_BAR.md`.

| ID    | Check                                                                                                       | Pass criterion (yes/no) |
|-------|-------------------------------------------------------------------------------------------------------------|-------------------------|
| HD-01 | Top-left shows portrait + HP bar (220 px × 14 px) + XP bar (220 px × 6 px) + LV label                       | yes                     |
| HD-02 | HP bar foreground color matches `#D24A3C`; ghost layer matches `#F0A89B`                                    | yes                     |
| HD-03 | Taking damage: HP foreground drops instantly; ghost layer drains over ~0.6 s                                | yes                     |
| HD-04 | XP bar foreground color matches `#E0B040`                                                                   | yes                     |
| HD-05 | Top-right shows "STRATUM 1 · ROOM x/8" with x updating each room transition                                 | yes                     |
| HD-06 | Boss room entry flips top-right to red `#D24A3C` "STRATUM 1 · BOSS" with a heartbeat pulse                  | yes                     |
| HD-07 | Bottom-center shows three 64×64 cooldown squares: LMB LIGHT, RMB HEAVY, SPACE DODGE                         | yes                     |
| HD-08 | On heavy-attack press, RMB square shows clockwise radial wipe and a `0.7s` countdown number                 | yes                     |
| HD-09 | Cooldown becoming available triggers single 1-frame ember-orange border flash                               | yes                     |
| HD-10 | After level-up, `[+1 STAT]` ember-orange pip appears in bottom-right                                        | yes                     |
| HD-11 | Damage-to-mob popup is white; crit popup is ember-orange `#FF6A2A` with `!`                                 | yes                     |
| HD-12 | Damage-to-player popup is red `#D24A3C` with negative sign                                                  | yes                     |
| HD-13 | XP-gain popup is gold `#E0B040` with `+N XP` text                                                           | yes                     |
| HD-14 | Popup numbers float up ~24 px and fade fully within 0.8 s                                                   | yes                     |
| HD-15 | Mob nameplate renders ONLY when mob is aggro'd or has been hit                                              | yes                     |
| HD-16 | Mob nameplate sits 24 px above sprite, follows mob in world space                                           | yes                     |
| HD-17 | Boss nameplate renders top-center of screen, 480 px wide, with phase 1/2 underbar                           | yes                     |
| HD-18 | HUD center 60% of screen contains zero HUD elements during normal play                                      | yes                     |
| HD-19 | On Tab open, HUD drops to 70% opacity except player HP bar (stays 100%)                                     | yes                     |
| HD-20 | On player death, HUD fades to 0% over 1.0 s in sync with world desaturation                                 | yes                     |
| HD-21 | HUD layout intact at 720p, 900p, 1080p HTML5 windows (no overlap into playfield center 60%)                 | yes                     |
| HD-22 | HUD slides in from edges within 0.5 s of player gaining control on game start                               | yes                     |
