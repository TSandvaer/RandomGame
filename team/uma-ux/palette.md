# Palette — Embergrave (M1 + 8-stratum forward plan)

**Owner:** Uma · **Phase:** M1 (stratum 1 authoritative; strata 2–8 indicative).

A palette is only useful if every other role can paste a hex code without picking. This doc is that paste-board. All values are sRGB hex.

## Ember-orange — the through-line

| Use                       | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Ember accent (primary)    | `#FF6A2A` | The brand. UI accent, level-up glow, item drops, player flame. |
| Ember accent (mid)        | `#E04D14` | Hover/pressed state of ember UI.       |
| Ember accent (deep)       | `#A02E08` | Border / drop-shadow of ember UI.      |
| Ember light (highlight)   | `#FFB066` | Particle highlights, tiny pip flashes. |

The ember-orange ramp is constant across **all 8 strata**. It is the player's flame and never changes.

## Core neutrals (UI, fonts, panel chrome)

| Use                       | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Panel background          | `#1B1A1F` | At 92% opacity for inventory/death/run summary panels. |
| Panel border              | `#2F2A33` | 1 px rim under top ember-bar.          |
| HUD body text             | `#E8E4D6` | Off-white, 14 px default.              |
| HUD caption / hint        | `#B8AC8E` | Muted parchment, for hint copy.        |
| HUD disabled              | `#605C50` | Locked M2 stub slots, etc.             |
| Section header            | `#FF6A2A` | Small caps; ember.                     |
| Cell empty border         | `#3A3540` | At 40% opacity for empty inventory cells. |
| Cell hover border         | `#FF6A2A` | Ember at 100%.                         |
| Vignette                  | `#000000` | Dark overlay, 30% (S1) → 60% (S8).     |

## Status / state colors

| State                     | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| HP foreground             | `#D24A3C` | Warm red.                              |
| HP ghost (delayed damage) | `#F0A89B` | Pale red.                              |
| HP background empty       | `#2A262C` | Dark slate.                            |
| XP foreground             | `#E0B040` | Gold.                                  |
| Mob HP foreground         | `#7A2A26` | Dark red.                              |
| Mob HP background         | `#3A1614` | Deeper dark red.                       |
| Damage to mob (popup)     | `#FFFFFF` | Pure white.                            |
| Damage to player (popup)  | `#D24A3C` | Warm red.                              |
| Crit popup                | `#FF6A2A` | Ember.                                 |
| XP popup                  | `#E0B040` | Gold.                                  |
| Heal popup (M2+)          | `#7AC773` | Soft green; reserved.                  |

## Gear-tier ramp (used as borders, tier-strip, item-name in tooltip)

| Tier | Display name | Hex       | Notes                                |
|------|--------------|-----------|--------------------------------------|
| T1   | Worn         | `#C9C2B2` | Bone white.                          |
| T2   | Common       | `#B58657` | Warm bronze.                         |
| T3   | Fine         | `#5A8FB8` | Cold steel-blue.                     |
| T4   | Rare         | `#8B5BD4` | Royal violet.                        |
| T5   | Heroic       | `#E0B040` | Gold (same hex as XP — intentional: heroic gear feels XP-flavored). |
| T6   | Mythic       | `#FF6A2A` | Ember-orange — the highest tier matches the player's flame. |

These six are also used in the gear-drop **light-beam** particle when an item lands on the ground.

---

## Stratum 1 — Outer Cloister (M1 authoritative)

The only stratum that ships in M1. Every Drew tile and Devon prop must come from these hex codes.

### Environment ramp — sandstone

| Role                      | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Floor — base              | `#7A6A4F` | Warm sandstone.                        |
| Floor — deep              | `#5C4F38` | Cracks, recessed tiles.                |
| Floor — highlight         | `#A89677` | Lit edges, polished stones.            |
| Wall — base               | `#4A3F2E` | Heavy cloister stone.                  |
| Wall — moss accent        | `#5C7044` | Olive green moss; sparse use.          |
| Trim / pillar             | `#9A7A4E` | Bronzed trim around door arches.       |

### Environment accents — parchment + warm light

| Role                      | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Parchment / paper         | `#D7C68F` | Banners, scattered scrolls.            |
| Brazier flame core        | `#FFB066` | Inner flame.                           |
| Brazier flame outer       | `#FF6A2A` | Outer flame, sparks.                   |
| Brazier base              | `#2C261C` | Iron + soot.                           |
| Doorway ember-glow        | `#FF6A2A` | At 60% opacity, soft falloff.          |

### Mob accents — Stratum 1 grunt

| Role                      | Hex       | Notes                                  |
|---------------------------|-----------|----------------------------------------|
| Grunt cloth               | `#5A4738` | Tattered brown.                        |
| Grunt skin                | `#A0856B` | Wash-out mid tone.                     |
| Grunt aggro eye-glow      | `#D24A3C` | Same as HP foreground.                 |
| Grunt weapon edge         | `#9C9590` | Worn iron.                             |

The aggro-eye-glow color is the **only** color a grunt has in common with the player-damage system. This is on purpose — when a mob's eyes go red, you know you're about to take that color of damage.

### Stratum 1 — anti-list (do NOT use in S1)

- Pure black (`#000000`) — too contrasty, breaks the "warm cloister" mood. Reserved for stratum 7-8.
- Cyan / turquoise — wrong stratum (those are S2 + S6).
- Bright purple — reserved for T4+ rare drops.
- White-hot ember (`#FFE6C0`) — reserved for late strata.

---

## Strata 2–8 — directional palettes (indicative, not authoritative)

These are not buildable yet; they exist so M1 doesn't accidentally use a color the team needs to differentiate later. M2+ palettes get their own commit when those strata enter scope.

### Stratum 2 — Sunken Library

- Floor: `#3F4D52` muted teal stone
- Wall: `#2C3438` deeper teal-grey
- Accent: `#A88E5E` weathered bronze leaf
- Accent dark: `#1A1F22`
- Mob accent: `#5C8FA0` waterlogged blue

### Stratum 3 — The Foundry

- Floor: `#3A3530` iron grit
- Wall: `#2A2520` soot
- Accent (forge glow): `#FF8B2A` warmer ember
- Accent dark: `#10080A` near-black
- Mob accent: `#B85016` molten red

### Stratum 4 — Caverns of Echo

- Floor: `#3D4348` cold blue-grey
- Wall: `#272B30` shadow stone
- Accent: `#7C8F9A` pale moonlight
- Accent dark: `#0F1216`
- Mob accent: `#9CB0BC` ghost-blue

### Stratum 5 — The Bone Market

- Floor: `#7A6F4D` sickly tan
- Wall: `#4A3D40` dirty plum-grey
- Accent: `#C9B66A` jaundice yellow
- Accent (sigil): `#7438AC` deep violet
- Mob accent: `#B89E5A` bone

### Stratum 6 — Glasswound

- Floor: `#0F1014` near-black obsidian
- Wall: `#161820`
- Accent (cyan-glass): `#35C2D0` cold cyan
- Accent dark: `#000000`
- Mob accent: `#9CE3EA` glass-shard pale cyan

### Stratum 7 — The Ember Vein

- Floor: `#28100A` charred earth
- Wall: `#0E0506`
- Accent: `#FF6A2A` ember (saturated, expansive use)
- Accent (deep red): `#9A1A12`
- Mob accent: `#FF8B2A` blazing

### Stratum 8 — Heart of Embergrave

- Floor: `#0A0606` near-black
- Wall: `#000000` true black
- Accent (white-hot ember): `#FFE6C0` near-white
- Accent (saturated ember): `#FF6A2A`
- Mob accent: `#FFFFFF` blinding white

---

## Color-blind & low-vision considerations

- **Tier rendering** never uses red-vs-green to differentiate. T1 bone-white, T2 bronze, T3 steel-blue gives high contrast for protan/deutan/tritan vision.
- **HP-loss feedback** is multi-channel: color (red), shape change (bar shrinks), motion (ghost-layer drain), audio (heart-thump < 33%), vignette (red pulse < 33%). A player who can't see red still gets the message.
- **Affixes in tooltip** use ember-orange (`#FF6A2A`), which is the most-saturated color in the palette and remains distinguishable across the three common color-blindness types.
- **Critical hits** use ember-orange + a `!` glyph. Color is not the only signal.
- **Settings menu (M2)** will offer a high-contrast UI mode that swaps panel background to `#000000` and bumps body text to pure white. M1 is dark-but-readable.

---

## Tester checklist (yes/no)

| ID    | Check                                                                                              | Pass criterion (yes/no) |
|-------|----------------------------------------------------------------------------------------------------|-------------------------|
| PL-01 | Every hex code referenced from `hud.md` appears in this file                                      | yes                     |
| PL-02 | Every hex code referenced from `inventory-stats-panel.md` appears in this file                    | yes                     |
| PL-03 | Stratum 1 floor color in-game matches `#7A6A4F` (eye-dropper a screenshot)                        | yes                     |
| PL-04 | Tier T1 border color in-game matches `#C9C2B2`                                                    | yes                     |
| PL-05 | Tier T6 border color in-game matches `#FF6A2A`                                                    | yes                     |
| PL-06 | HUD HP foreground color in-game matches `#D24A3C`                                                 | yes                     |
| PL-07 | XP popup color in-game matches `#E0B040`                                                          | yes                     |
| PL-08 | Crit popup color in-game matches `#FF6A2A` and includes a `!` glyph                               | yes                     |
| PL-09 | Stratum 1 contains zero pure-black (`#000000`) tiles in environment                               | yes                     |
| PL-10 | No environment pixel uses tier-T4 violet (`#8B5BD4`) — reserved for items only                    | yes                     |
| PL-11 | Mob aggro eye-glow color is the same `#D24A3C` as player HP foreground                            | yes                     |
| PL-12 | HP-loss feedback uses at least 4 channels (color, shape, motion, audio, vignette)                 | yes (audio in M1 stub OK)|
