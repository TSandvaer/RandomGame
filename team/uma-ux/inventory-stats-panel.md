# Inventory & Stats Panel — Mockup (M1)

**Owner:** Uma · **Phase:** M1 · **Drives:** Devon's `InventoryStatsPanel.tscn`, copy + tooltip layout, item-affix rendering rules.

This is the panel the player sees on **Tab**. M1 surfaces only — M2 stubs are visible-but-disabled so the spatial layout is final.

## Layout principles

- **Left third = character + stats.** Right two-thirds = gear panel.
- **Single screen, no scrolling on M1.** Inventory grid is sized to fit M1's drop pool.
- **Stats are always-on, never collapsed.** Player must never hunt for them.
- **Equipped slots match the human silhouette** so the eye knows where each slot lives without reading.
- **Color tells tier; iconography tells slot type.** Both must be readable in a one-second glance.

## Top-level mockup (1280 × 720 reference)

```
+---------------------------------------------------------------------------------------------------+
|  EMBER-KNIGHT · LV 3                                                                  [Tab close] |
|  +---------------------+  +-----------------------------------------------------------------+    |
|  |   AVATAR PORTRAIT   |  | EQUIPMENT                                                        |    |
|  |  (idle 2-frame loop)|  |                                                                   |    |
|  |                     |  |    [WEAPON]    [ARMOR]    [OFF-HAND*]   [TRINKET*]   [RELIC*]    |    |
|  |                     |  |     T2 sword    T1 hide    -- locked --  -- locked --  -- locked  |    |
|  |                     |  |                                                                   |    |
|  +---------------------+  |  *grey, captioned "Unlocks at M2"                                 |    |
|                            +---------------------------------------------------------------+      |
|  +---------------------+  +-----------------------------------------------------------------+    |
|  | STATS               |  | INVENTORY                                                        |    |
|  |---------------------|  |                                                                   |    |
|  | Vigor      8 (+12HP)|  |  +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+                          |    |
|  | Focus      4        |  |  |  | |  | |  | |  | |  | |  | |  | |  |                          |    |
|  | Edge       6 (+6%C) |  |  +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+                          |    |
|  |---------------------|  |  +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+                          |    |
|  | HP        82 / 110  |  |  |  | |  | |  | |  | |  | |  | |  | |  |                          |    |
|  | Damage    14         |  |  +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+                          |    |
|  | Defense    6         |  |  +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+                          |    |
|  | Dodge i-fr 0.30s    |  |  |  | |  | |  | |  | |  | |  | |  | |  |                          |    |
|  | Crit       6%       |  |  +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+                          |    |
|  +---------------------+  |                                                                   |    |
|                            |  Capacity: 7 / 24       [STASH >]  (M1: stash kept on death)     |    |
|  +---------------------+  +-----------------------------------------------------------------+    |
|  | XP   ████████░░ 320/500                                                                       |
|  +-----------------------------------------------------------------------------------------+      |
|                                                                                                   |
|  STAT POINTS UNSPENT: 1     [+ Vigor]  [+ Focus]  [+ Edge]                                       |
|  [Tab] close   [E] equip/unequip   [X] discard   [Right-click] inspect                            |
+---------------------------------------------------------------------------------------------------+
```

Notes on the mockup:

- **Equipped slots** sit horizontally above inventory. Five slots reserved; only **WEAPON** and **ARMOR** are interactive in M1. Off-hand / trinket / relic are dimmed to ~25% with the caption *"Unlocks at M2"* — the box is still visible so the player learns the silhouette early.
- **Stats** are split into two groups by a thin divider: **Primary stats** (Vigor / Focus / Edge with their per-point effect in faint parens) and **Derived stats** (HP, damage, defense, dodge i-frame window, crit). Anything an affix can change shows the change inline (e.g. armor with `+12 max HP` makes the HP row read `82 / 122` and the `122` is highlighted ember-orange while equipped).
- **XP bar** stretches the whole panel width at the bottom of the stats column for a sense of "I am a person, this is how much further I have to go."
- **Stat-points-unspent** is its own row, clearly clickable and clearly optional. Three buttons, not a dropdown — autonomy and visible affordance.
- **Capacity counter** (`7 / 24`) is small but always visible, so a hoarder learns early.
- **Stash** is a sub-screen, not a slot. Tab on it (M2). For M1 it's a closed door labeled *"Stash (M2)"* with a tooltip *"Items moved to stash survive death."* M1 deferred behavior: any item still in inventory at death is **also kept** for M1 simplicity (this is a UX-side proposal — flag for Priya in DECISIONS).
- **Footer hints** are kept short, action-key first. Right-click "inspect" opens an extended tooltip pinned to the screen edge.

## Equipped-slot visual spec

Each slot is a 64×64 square with:

- A **slot icon glyph** (faint, behind the item) so empty slots still telegraph what they're for: sword silhouette for WEAPON, breastplate for ARMOR, shield for OFF-HAND, ring for TRINKET, ember-flame for RELIC.
- The **item icon** (32×32 pixel art) centered with a 3 px tier-color border.
- A **tier strip** along the bottom 4 px of the slot in tier color (see palette spec below).
- A **+ pip** in the top-right corner if the item has any rolled affixes (ranges 1–3 in M1; pip count = affix count).

## Inventory grid

- 8 columns × 3 rows = 24 slots in M1 (cap fits the loot density in stratum 1; gives room for 4–5 unequipped items + consumable stubs).
- Each cell is 48×48 with a 1 px outer border (muted slate). Empty cells render the border at 40% opacity.
- An item in the grid uses the same slot-rendering rules as equipped slots, but smaller: 24×24 icon, 2 px tier border, +pip in corner.

## Tier color palette (referenced from `palette.md`)

| Tier | Display name | Hex      | Notes                                |
|------|--------------|----------|--------------------------------------|
| T1   | Worn         | `#C9C2B2`| Bone white. M1.                      |
| T2   | Common       | `#B58657`| Warm bronze. M1.                     |
| T3   | Fine         | `#5A8FB8`| Cold steel-blue. M1.                 |
| T4   | Rare         | `#8B5BD4`| Royal violet. M2+.                   |
| T5   | Heroic       | `#E0B040`| Gold. M2+.                           |
| T6   | Mythic       | `#FF6A2A`| Ember-orange (matches HUD accent).   |

These are used three places consistently: **slot border**, **tier strip**, **item-name color in the tooltip**. They are *not* used for background panel fills — the panel is neutral so tier color reads instantly.

## Item tooltip spec

When the player hovers an item (any context — equipped, inventory, drop on the ground via Beat 8 of `player-journey.md`):

```
+--------------------------------------------+
|  PYRE-EDGED SHORTSWORD          T2 Common  |
|  --- weapon · sword ---                    |
|  Damage  10–14                             |
|                                            |
|  + 8% crit chance                          |
|  + 12 max HP                               |
|                                            |
|  "Pulled from a Knight in the second       |
|   strata's anteroom."                      |
|                                            |
|  [LMB equip]  [right-click compare]        |
+--------------------------------------------+
```

Tooltip layout rules:

- **Header** = item name (in tier color) + tier label (bone-white).
- **Sub-header** = slot type · weapon class. Italic, muted.
- **Base stats** = damage range or armor value, white.
- **Affixes** = each on its own line, prefixed `+` or `-`, in **ember-orange** so they're visually distinct from base stats. (Affixes are the dopamine hit — they get the bright color.)
- **Flavor text** = italic, muted, max two lines. M1 has a tiny pool — Uma writes 3–4 flavor lines for the M1 affix rolls; gracefully truncates if missing.
- **Footer hints** = action keys.
- **Compare-mode** (M1 stretch / M2 confirmed): right-click pins a second tooltip beside the first, showing the currently-equipped item in the same slot. Stat deltas appear in green/red.

Tooltip is built by `ItemTooltip.tscn` and reads from the item's TRES resource (Drew's schema). Affix list comes from the item's rolled affix array.

## Color & iconography conventions

- **Panel background:** dark slate `#1B1A1F` at 92% opacity, with a 1 px ember-orange top-edge bar.
- **Section headers:** "EQUIPMENT", "STATS", "INVENTORY" in small caps, ember-orange `#FF6A2A`, 12 px font.
- **Body text:** off-white `#E8E4D6`, 14 px.
- **Disabled/locked text (M2 stub slots):** muted `#605C50`.
- **Highlight on hover:** 1 px ember-orange border around the cell, plus 8% brightness lift on the icon.
- **Selected/equipped item:** persistent 2 px tier-color outline around the equipped-slot square.
- **Discard confirmation:** any tier ≥ T2 prompts a small inline confirm (*"Discard? [Y/N]"* under the cell). T1 discards instantly with an undo toast.

## Keyboard + mouse interaction model

| Action                          | Mouse                   | Keyboard                                              |
|---------------------------------|-------------------------|-------------------------------------------------------|
| Open / close panel              | —                       | **Tab**                                               |
| Move cursor between cells       | mouse hover             | **Arrow keys** / **WASD**                             |
| Equip item                      | LMB on item             | **E** with cell focused                               |
| Unequip item                    | LMB on equipped slot    | **E** with equipped slot focused                      |
| Drag-equip (alt path)           | LMB-hold from cell to slot | —                                                  |
| Inspect (extended tooltip)      | RMB on item             | **I** with cell focused                               |
| Discard item                    | drag to outside panel + drop | **X** with cell focused                          |
| Spend stat point                | LMB on `[+ Stat]` button | **1 / 2 / 3** for Vigor / Focus / Edge               |
| Compare equipped vs hovered     | RMB-hold (M2)           | **C**-hold (M2)                                       |

Focus indicator (for keyboard nav) is the same 1 px ember-orange border used for hover, so the two visual languages are unified.

## Time-slow behavior on open

When the panel opens, **the world keeps running at ~10% time** (matches `player-journey.md` Beat 9). This is the adventurous-feel call: you can technically be hit while reading affixes. Two consequences:

1. The HUD HP bar stays visible *behind* the panel at 70% opacity in the upper-left so the player isn't ambushed. Devon — please don't blank the HUD when the panel opens.
2. The **Esc** key closes the panel instantly (faster than Tab) for emergency closing. Add this hint in tiny text at the bottom-right corner of the panel: `Esc — quick close`.

If playtest reveals this is too punishing, fallback is **time-freeze on panel open** — but we hold the line on time-slow until tested.

## Open questions for Priya / Devon

1. **Inventory cap of 24 in M1**: stub. Real cap is a balance call.
2. **M1 inventory persistence on death**: Uma proposes "all carried items also persist on M1 death" to avoid teaching loss before stash exists. Flag for Priya — her call.
3. **XP curve numbers** (`320 / 500` in mockup): stub.
4. **Affix names + values** (`+8% crit chance`, `+12 max HP`): pulled from M1's 3-affix pool. Final wording aligns with Drew's TRES schema.

## Hand-off

- **Devon:** `InventoryStatsPanel.tscn` + `ItemTooltip.tscn` + `EquippedSlot.tscn` + `InventoryCell.tscn`. Use the keymap table verbatim. Time-slow on open, not freeze.
- **Drew:** item icons can be 24×24 (grid) and 32×32 (equipped) sourced from one 32×32 master — Aseprite will downscale cleanly. Affix data lives in the item TRES.
- **Tess:** acceptance criterion #7 (two visibly different gear drops in stratum 1) maps to two distinct affix rolls — visible on tooltip.

---

## Tester checklist (yes/no)

Per `team/TESTING_BAR.md`.

| ID    | Check                                                                                       | Pass criterion (yes/no) |
|-------|---------------------------------------------------------------------------------------------|-------------------------|
| IS-01 | Tab opens panel; Tab again closes it                                                        | yes                     |
| IS-02 | Esc closes panel from any sub-state within 1 frame                                          | yes                     |
| IS-03 | Equipment row shows 5 slot squares: WEAPON, ARMOR, OFF-HAND, TRINKET, RELIC                  | yes                     |
| IS-04 | OFF-HAND, TRINKET, RELIC are dimmed to ~25% with caption "Unlocks at M2"                    | yes                     |
| IS-05 | Stats panel shows Vigor, Focus, Edge with per-point effect in muted parens                  | yes                     |
| IS-06 | Stats panel shows derived stats: HP cur/max, Damage, Defense, Dodge i-fr seconds, Crit %    | yes                     |
| IS-07 | Equipping armor with `+12 max HP` raises HP max value, shown in ember-orange briefly        | yes                     |
| IS-08 | Inventory grid is exactly 8 columns × 3 rows = 24 cells                                     | yes                     |
| IS-09 | Capacity counter (e.g. "7 / 24") updates immediately on pick-up or discard                  | yes                     |
| IS-10 | Each item shows tier-color border (T1 bone-white, T2 bronze, T3 steel-blue per palette)     | yes                     |
| IS-11 | Items with affixes show `+pip` count in top-right of cell matching affix count (1–3 in M1)  | yes                     |
| IS-12 | Hovering an item opens tooltip within 200 ms                                                | yes                     |
| IS-13 | Tooltip header shows item name in tier color, tier label in bone-white                      | yes                     |
| IS-14 | Tooltip lists each affix on its own line, prefixed with `+` or `-`, in ember-orange         | yes                     |
| IS-15 | Equipping via LMB on inventory cell moves item into slot and removes from grid              | yes                     |
| IS-16 | Unequipping via LMB on equipped slot moves item back to first empty grid cell                | yes                     |
| IS-17 | Drag-and-drop from cell to slot also equips                                                 | yes                     |
| IS-18 | Tier ≥ T2 discard prompts inline confirm "[Y/N]" before removing                            | yes                     |
| IS-19 | T1 discard removes immediately and shows undo toast for 3 s                                 | yes                     |
| IS-20 | Pressing 1/2/3 with stat points unspent allocates to Vigor/Focus/Edge respectively          | yes                     |
| IS-21 | Stat points unspent counter decreases to 0 after spending all points                        | yes                     |
| IS-22 | While panel open, world time runs at ~10%; player HP bar still visible at 100% opacity      | yes                     |
| IS-23 | Two visibly distinct gear drops in stratum 1 each render correct affix list (M1 #7)         | yes                     |
| IS-24 | Save → quit → reload preserves: equipped items, inventory contents, unspent stat points     | yes                     |
