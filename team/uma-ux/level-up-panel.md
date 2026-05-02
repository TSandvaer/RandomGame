# Level-Up Panel & Tooltip Language (M1)

**Owner:** Uma · **Phase:** M1 · **Drives:** Devon's `LevelUpPanel.tscn` + `StatTooltip.tscn`, level-up VFX/audio cue, the canonical tooltip voice for stat copy. Pairs with Devon's level-up math + XP curve work (`86c9kxx2t`) and stat-allocation task (`86c9kxx2y`).

This doc lives downstream of `inventory-stats-panel.md` (the Tab panel already shows Vigor/Focus/Edge with stat-points-unspent). The level-up panel is the **moment-to-moment celebratory beat** the player sees the **instant** the threshold is hit; the inventory stat-allocation block on Tab is the calmer, any-time alternative path. Both must allocate to the same V/F/E pool — single source of truth lives on the player resource (Devon's call).

## Design intent (one paragraph)

A level-up is the loudest "you got better" signal in Embergrave's two-ladder treadmill. It must feel **earned and adventurous**, not a bureaucratic interrupt. The flame brightens, the world quiets for a beat, three doors open — pick one, the world resumes. Reading the tooltips is **optional in this moment** but rewarded with clear, voicy copy when the player does pause. The whole interaction can be completed in **under 2 seconds of player-time** if they already know what they want, but never auto-allocates — autonomy first, every level.

## Beat-by-beat: the level-up moment

The instant the XP-bar fill crosses a level threshold (Devon's `Player.xp_changed` → `Player.level_up` signal):

### Beat 1 — Threshold gleam (T+0.0 → T+0.4 s)

- XP bar's gleam-sweep animates per `hud.md` §1 (one-time horizontal sweep, fills to 100%, resets to overflow).
- A **soft ember-burst particle** spawns at the player's world position (reuses Drew's upward-ember particle from `death-restart-flow.md` Beat B — same emitter, **brighter and outward** instead of upward, 0.4 s burst).
- **Audio:** rising chime (`level_up_chime.ogg`, 0.4 s) — major sixth, warm, single voice. Sits over ambient music, doesn't replace it. **Combat audio keeps playing** — the moment is celebratory, not interrupting.
- LV label in HUD top-left **flashes once** (per `hud.md` §1) and the number ticks up: `LV 3` → `LV 4` over 0.2 s with a brief ember-flash on the final number.
- `[+1 STAT]` pip in the bottom-right HUD (`hud.md` §4) appears with a short ember-pulse-in if it wasn't already visible.

This 0.4 s beat plays **even if the player won't open the panel right now**. It's the irreducible "you leveled up" cue. If the player keeps fighting and ignores the pip, the unspent point sits patiently — exactly the inventory panel's existing behavior.

### Beat 2 — World slows + panel slides up (T+0.4 → T+0.7 s)

If the player **chose** to engage with the level-up (auto-trigger on first level only — see "Auto-open rule" below):

- **World time slows to 10%** — same convention as `inventory-stats-panel.md` §"Time-slow behavior on open". Music ducks to 60%, combat audio cuts to 30%. HP bar stays 100% opacity behind the panel (mob-hit-while-reading is the same risk it was on Tab).
- Camera **does not push in** (unlike the death sequence) — the playfield stays visible and the player keeps spatial awareness of the room.
- Panel slides up from the bottom edge over 0.3 s, easing out. Panel is a **bottom-anchored band**, not a full-screen takeover — playfield is visible above.
- Faint vignette deepens to 40% so the panel reads cleanly without burying the world.

### Beat 3 — Allocation (player-paced)

Player picks one of three stats. Numbers and stat preview update inline (see "Stat-allocation panel mockup" below).

### Beat 4 — Confirm + dismiss (T+confirm → T+confirm + 0.3 s)

- On confirm, a **second smaller ember-burst** spawns on the chosen stat tile (visual closure on the picked stat).
- **Audio:** soft "settle" tone (`stat_allocate.ogg`, 0.2 s — same family as the level-up chime, lower note).
- Panel slides back down over 0.3 s.
- World time ramps back to 100% over 0.2 s, music restores.
- HUD `[+1 STAT]` pip disappears if no points remain. If the player banked points and hit a level that gave +2 (M2+ — see "Multi-level catch-up" below), the pip stays.

### Auto-open rule (M1)

- **Level 2 (first level-up) auto-opens the panel** — teach the system once. The player never has to discover the pip exists.
- **Levels 3+ do NOT auto-open** — the pip is enough. Players who want to keep fighting through a level-up are not yanked out of combat. Players who want to allocate **press P** (or click the pip) to open.
- Rationale: same philosophy as `inventory-stats-panel.md` §"Time-slow behavior on open" — one beat of friction at the right time, then trust the player.

## Stat-allocation panel mockup (1280 × 720 reference)

Bottom-anchored band, ~280 px tall, full screen width, `#1B1A1F` at 92% opacity with a 1 px ember-orange top-edge bar (matches the inventory panel chrome).

```
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|                                                                                         |
|                          (   PLAYFIELD — visible, time at 10%   )                       |
|                                                                                         |
|                                                                                         |
|=========================================================================================|
|                                                                                         |
|                  LEVEL UP — Spend 1 stat point                                          |
|                                                                                         |
|     +----------------+        +----------------+        +----------------+              |
|     |                |        |                |        |                |              |
|     |     [V]        |        |     [F]        |        |     [E]        |              |
|     |    VIGOR       |        |    FOCUS       |        |    EDGE        |              |
|     |     8 → 9      |        |     4 → 5      |        |     6 → 7      |              |
|     |  HP 110 → 115  |        |  Dodge .30→.32 |        |  Crit  6% → 7% |              |
|     |    [ + 1 ]     |        |    [ + 1 ]     |        |    [ + 1 ]     |              |
|     |     <1>        |        |     <2>        |        |     <3>        |              |
|     +----------------+        +----------------+        +----------------+              |
|                                                                                         |
|       Hover any stat for details.                                                       |
|       <1/2/3> pick   <Enter> confirm   <Esc> close (point banked)                       |
+-----------------------------------------------------------------------------------------+
```

### Layout rules

- **Three stat tiles**, side-by-side, equal width. Tile is 240 × 180 px with 24 px gap between, centered horizontally.
- **Stat glyph** (top of tile, 32×32): `V` `F` `E` rendered in ember-orange caps inside a circle outline. Quick-read glyph for non-text-readers.
- **Stat name** (under glyph, 16 px ember-orange small caps): `VIGOR` / `FOCUS` / `EDGE`.
- **Current → next preview** (under name, 18 px off-white): `8 → 9`. The arrow is rendered with a 1-frame ember-flash on hover. Numbers are large because **this is the load-bearing data**.
- **Derived stat preview** (under that, 12 px muted parchment `#B8AC8E`): the most player-visible derived stat changes inline. `HP 110 → 115` for Vigor, `Dodge .30 → .32` for Focus, `Crit 6% → 7%` for Edge. Only **one derived line per tile** to keep the band readable at-a-glance — full breakdown lives in the hover tooltip.
- **`[ + 1 ]` button** (bottom of tile, 80 × 28 px, ember-orange fill, off-white text). Clicking allocates immediately to that stat — no second confirm needed for the +1. Confirm-key flow exists for keyboard users (see keymap).
- **Keybind hint** (bottom-corner of each tile, 10 px muted parchment): `<1>` `<2>` `<3>`.

### Tile states

- **Default:** 1 px panel-border `#2F2A33` outline, body content as above.
- **Hover / keyboard-focused:** 1 px ember-orange outline (same hover language as the inventory grid). The stat tooltip panel pops up **above the tile** (see "Stat tooltip" below).
- **Selected via 1/2/3 (preview, not yet confirmed):** 2 px ember-orange outline + 8% brightness lift on the glyph. The `[ + 1 ]` button reads `[ ENTER ]`. This is the keyboard-only path — preview the choice, hit Enter to confirm.
- **Disabled (M1: never; M2: stat at cap):** dimmed to 25%, button greyed, tooltip explains why.

### Multi-level catch-up (M1+)

If the player gains multiple levels before opening the panel (boss kill spike, fast-XP debug toggle), the panel reads `LEVEL UP — Spend N stat points` and stays open until N=0. Each click decrements. Holding the panel open at N=0 is fine — Esc/Enter dismisses.

### Stat tooltip (hover or keyboard-focus)

Pops up **above the focused tile**, anchored to the top edge with a 12 px gap. Tooltip is the same chrome as `inventory-stats-panel.md` §"Item tooltip spec" — `#1B1A1F` at 92%, 1 px panel-border, `#FF6A2A` top-edge bar, 12 px padding. Roughly 320 × 140 px.

```
+----------------------------------------------+
|  VIGOR                                       |
|  --- toughness · health pool · stamina ---   |
|                                              |
|  +5 max HP per point                         |
|  +1 HP regen / 10 s per point                |
|                                              |
|  "Vigor is what stands between you and the   |
|   next bell. Stack it when the floor bites." |
|                                              |
+----------------------------------------------+
```

Layout:

- **Header** = stat name in ember-orange, 16 px caps.
- **Sub-header** = three-word vibe label, italic muted parchment, lowercase. (`toughness · health pool · stamina`.)
- **Numeric body** = each per-point effect on its own line, ember-orange `+` prefix. Mirrors the inventory tooltip's affix-list rule (affixes get the bright color because they're the dopamine).
- **Flavor line** = 2-line italic muted parchment quote. Tone-matches the death-flow voice (adventurous, second-person, never sterile). See "Tooltip language standard" below for the canonical strings.

The tooltip lifecycle matches the inventory item-tooltip rule: appears within **200 ms** of focus, dismisses instantly on un-focus.

## Keymap

| Action                        | Mouse                       | Keyboard                                       |
|-------------------------------|-----------------------------|------------------------------------------------|
| Open panel manually           | LMB on `[+1 STAT]` HUD pip  | **P**                                          |
| Move focus between tiles      | mouse hover                 | **Left / Right** arrows or **Tab** / **Shift+Tab** |
| Allocate to Vigor             | LMB on tile / `[ + 1 ]`     | **1**                                          |
| Allocate to Focus             | LMB on tile / `[ + 1 ]`     | **2**                                          |
| Allocate to Edge              | LMB on tile / `[ + 1 ]`     | **3**                                          |
| Confirm previewed selection   | —                           | **Enter** (when a tile is selected via 1/2/3) |
| Close panel (bank point(s))   | LMB outside band            | **Esc**                                        |

Notes:
- **1/2/3 allocates immediately** in the mouse-equivalent flow — single keystroke, single allocation, panel closes if all points spent. This is the speedrun path.
- **Enter requires a prior preview** — pressing Enter with no tile selected is a no-op (no accidental allocation).
- **Esc banks the point(s)** — never auto-allocates. Matches the autonomy-first design.

## Tooltip language standard

Reference set for Devon to inline as `tooltip_text` strings on the player-stat resources. Tone notes:

- **Second person.** Always *you*. Never *the player*.
- **Adventurous, not sterile.** "Vigor is what stands between you and the next bell" reads. "Vigor: increases health pool" doesn't.
- **One vibe sub-header per stat.** Three words, lowercase, dot-separated. (`toughness · health pool · stamina`.)
- **Numerics in the affix-style:** `+5 max HP per point`. Always per-point, never compounded — let the player do the math.
- **Flavor line is 1–2 lines max.** Truncate gracefully if missing.
- **No game-design jargon.** "DPS" never appears in a tooltip. "Damage" does.

### The 12 strings (canonical)

#### Stat tooltips (3)

| Key                  | Header  | Sub-header                               | Body                                                                 | Flavor                                                                       |
|----------------------|---------|------------------------------------------|----------------------------------------------------------------------|------------------------------------------------------------------------------|
| `vigor`              | VIGOR   | `toughness · health pool · stamina`      | `+5 max HP per point` `+1 HP regen / 10 s per point`                 | `"Vigor is what stands between you and the next bell. Stack it when the floor bites."` |
| `focus`              | FOCUS   | `dodge · cooldowns · steady hands`        | `+0.02 s dodge i-frame per point` `–1% ability cooldown per point`   | `"Focus narrows the world to the next strike. The flame burns truer for it."` |
| `edge`               | EDGE    | `damage · crit · bite`                    | `+1 damage per point` `+1% crit chance per point`                    | `"Edge is the cruelty in your swing. Sharper, faster, more often."`         |

#### Confirmation / state strings (3)

| Key                       | String                                    | Where it appears                                |
|---------------------------|-------------------------------------------|-------------------------------------------------|
| `level_up_header`         | `LEVEL UP — Spend 1 stat point`           | Top of allocation panel; pluralizes for N>1.    |
| `level_up_header_multi`   | `LEVEL UP — Spend {N} stat points`        | Replaces above when N>1.                        |
| `points_banked_toast`     | `Stat point saved. Spend on Tab anytime.` | 3 s toast on Esc-close from the level-up panel. |

#### Inventory-panel "+ Stat" mirror (3)

These also appear in `inventory-stats-panel.md` §"Equipment / Stats" panel where the same V/F/E are spent at any time. Use the **same three stat tooltip strings** above. New ones for the inventory mirror:

| Key                            | String                                            | Where it appears                                                |
|--------------------------------|---------------------------------------------------|-----------------------------------------------------------------|
| `inventory_alloc_hint`         | `1 unspent — Tab → press 1, 2, or 3 to spend.`    | Below `STAT POINTS UNSPENT: 1` row in inventory.                |
| `inventory_alloc_zero_hint`    | `Earn XP. Level up. Spend.`                       | Replaces the line when unspent = 0.                             |
| `inventory_alloc_multi_hint`   | `{N} unspent — every level matters. Spend them.` | Replaces when unspent ≥ 2.                                      |

#### HUD pip + first-level-up toast (3)

| Key                            | String                                          | Where it appears                                            |
|--------------------------------|-------------------------------------------------|-------------------------------------------------------------|
| `hud_pip_tooltip`              | `Tab → Stats. Or press P. Spend any time.`      | Hover the `[+1 STAT]` pip in HUD bottom-right.              |
| `first_levelup_subtle_hint`    | `Press 1, 2, or 3 — or hover for details.`      | Tiny 12 px hint at the bottom of the level-up panel **only on Level 2** (first-level teaching beat). |
| `cap_reached_hint` *(M2+ stub)* | `This stat is at cap. Try another.`            | Reserved string. M1 has no caps.                            |

## Decision: level-up does NOT pause the game

Logged here so Devon's animation budget reflects it: the level-up moment is **time-slowed (10%), not paused**. Same as inventory open. Combat continues at slow speed; mob projectiles still travel; HP can still drop. This costs Devon zero animation budget (no pause-state to author) and keeps the design language consistent across all "modal" interrupts in the game.

If playtest reveals this is too punishing during a boss fight, the fallback is **time-freeze on level-up only during boss rooms** — not a global change. Holds the line on time-slow until tested.

## Cross-references

- `team/uma-ux/inventory-stats-panel.md` — Tab panel, where the same V/F/E stats are also visible and the same allocation mirror exists.
- `team/uma-ux/hud.md` §4 — `[+1 STAT]` pip in bottom-right; the pip is the at-rest reminder when the panel isn't open.
- `team/uma-ux/death-restart-flow.md` — voice / tone reference for flavor lines.
- `team/uma-ux/palette.md` — every hex used here.

## Hand-off

- **Devon:** `LevelUpPanel.tscn` is a CanvasLayer scene with three `StatTile.tscn` children. Triggered by `Player.level_up` signal. Auto-open is gated by a one-shot flag on `Player` (`first_level_up_seen: bool` — saves to disk so it persists across runs but only fires once for the character's lifetime). The 12 tooltip strings are pulled from a single `StatStrings.tres` resource so M2 localization is a one-file swap. The inventory-mirror strings live in the same resource. **Do not** inline strings in the panel scene.
- **Devon (XP curve, `86c9kxx2t`):** the per-point numbers in the tooltip body (`+5 max HP per point`, etc.) are stubs aligned with `mvp-scope.md`. Final per-point values are Devon's call once the curve calibration lands; **the tooltip resource is the only place these numbers live** so updating one place updates the panel + inventory + tooltips simultaneously.
- **Drew:** the ember-burst particle for Beat 1 (level-up moment) is a **horizontal/outward burst** variant of the upward-ember particle from `death-restart-flow.md`. Same emitter, different shape parameter — author once, parameterize in `EmberBurst.tscn`.
- **Tess:** acceptance maps to the M1 ladder check (`AC4` boss reachability via fast-XP toggle). The level-up panel must be reachable in <1 minute of fast-XP play for the test plan to fit its time budget. Tester checklist below covers the M1 sign-off rows.

## Open questions

1. **Per-point stat values** (`+5 max HP`, `+0.02 s i-frame`, `+1 damage`, `+1% crit`): stubs aligned with the existing inventory mockup. Devon's final pin via XP curve task `86c9kxx2t` and damage formula `86c9kxx33`.
2. **Auto-open on Level 2 only** vs. auto-open every level: Uma's call is once (this doc). Reversible after first playtest.
3. **`P` keybind** for manual open: chosen because Tab is already the inventory key and 1/2/3 are stat-allocation keys when the panel is already open. **L** was rejected (collides with future "log/lore" key in M2).

---

## Tester checklist (yes/no)

Per `team/TESTING_BAR.md`.

| ID    | Check                                                                                                       | Pass criterion (yes/no) |
|-------|-------------------------------------------------------------------------------------------------------------|-------------------------|
| LU-01 | XP threshold crossing fires `Player.level_up` and plays Beat 1 audio (`level_up_chime.ogg`) within 1 frame  | yes                     |
| LU-02 | LV label in HUD top-left ticks up (e.g. `LV 3` → `LV 4`) over 0.2 s with ember-flash on the new number      | yes                     |
| LU-03 | `[+1 STAT]` pip in HUD bottom-right appears or persists with ember-pulse-in if newly visible                | yes                     |
| LU-04 | Outward ember-burst particle spawns at player world position, 0.4 s burst, uses `#FF6A2A` and `#FFB066`     | yes                     |
| LU-05 | First level-up of the character (Level 1 → 2) auto-opens the level-up panel                                 | yes                     |
| LU-06 | Levels 3+ do NOT auto-open the panel; the pip is the only persistent cue                                    | yes                     |
| LU-07 | Pressing **P** opens the panel manually when at least one unspent stat point exists                         | yes                     |
| LU-08 | Pressing P with zero unspent points is a no-op (no panel, no audio)                                         | yes                     |
| LU-09 | While panel is open, world time runs at ~10% (matches inventory time-slow); HP bar stays at 100% opacity     | yes                     |
| LU-10 | Panel slides up from bottom over 0.3 s; slides back down over 0.3 s on dismiss                              | yes                     |
| LU-11 | Three tiles visible: VIGOR (1), FOCUS (2), EDGE (3) — left to right, equal width                            | yes                     |
| LU-12 | Each tile shows: glyph, name, current → next preview (e.g. `8 → 9`), one derived-stat preview line          | yes                     |
| LU-13 | Hovering or keyboard-focusing a tile pops the stat tooltip above it within 200 ms                           | yes                     |
| LU-14 | Stat tooltip header is in ember-orange caps; sub-header is italic muted parchment                           | yes                     |
| LU-15 | Stat tooltip body lines start with `+` in ember-orange and use `per point` phrasing                         | yes                     |
| LU-16 | Pressing **1** allocates to Vigor immediately and updates the inventory stat row                            | yes                     |
| LU-17 | Pressing **2** allocates to Focus immediately and updates the inventory stat row                            | yes                     |
| LU-18 | Pressing **3** allocates to Edge immediately and updates the inventory stat row                             | yes                     |
| LU-19 | LMB on a tile's `[ + 1 ]` button allocates to that stat (mouse-equivalent of 1/2/3)                         | yes                     |
| LU-20 | Keyboard preview (arrow + 1/2/3 select) does NOT allocate until **Enter** is pressed                        | yes                     |
| LU-21 | After allocation, second small ember-burst on the chosen tile + `stat_allocate.ogg` plays                   | yes                     |
| LU-22 | Pressing **Esc** banks the unspent point(s) and closes the panel; toast `Stat point saved. ...` shows 3 s   | yes                     |
| LU-23 | If multi-level catch-up (N>1), header reads `LEVEL UP — Spend {N} stat points` and panel stays open         | yes                     |
| LU-24 | After all points spent, panel auto-dismisses; `[+1 STAT]` HUD pip disappears                                | yes                     |
| LU-25 | Allocated stat persists across run-death (per `death-restart-flow.md` rules) and across save → quit → reload | yes                    |
| LU-26 | Level-up moment plays Beat 1 even if the player is mid-attack — does NOT interrupt input or movement        | yes                     |
| LU-27 | Tooltip strings render the canonical 12 strings from `StatStrings.tres` — no inline string literals in scene | yes                    |
| LU-28 | Inventory `STAT POINTS UNSPENT` line shows `inventory_alloc_hint` / `_zero_` / `_multi_` per point count    | yes                     |
