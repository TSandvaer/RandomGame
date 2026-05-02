# Stash UI v1 — Death-Recovery Flow + Ember-Bag Pattern (M2 design)

**Owner:** Uma · **Phase:** M2 (design only; implementation lands in Devon's W3-B4 + downstream M2 work) · **Drives:** Devon's `StashRoom.tscn` + `StashGrid.tscn` + save schema v3→v4 bump, Drew's ember-bag pickup, Tess's M2 acceptance plan.

This doc extends the **2026-05-02 M1 death rule** into M2. It is design-only; nothing here ships in M1 and nothing here invalidates M1. If Sponsor's interactive 30-min soak surfaces M1 changes, this doc absorbs them in a v1.1 revision; the structural calls (binding, grid size, ember-bag variant) are independent of M1 outcomes.

## TL;DR (5-line summary)

1. **Stash UI** is a 12×6 = 72-slot grid in a between-runs **Stash Room** (chamber at every stratum entry); opens with **B** by default (rebindable), **never accessible mid-run**, **no time-slow** (between-runs context).
2. **Ember-bag variant chosen: pickup-at-death-location** — on death, all unequipped inventory packs into a single "Ember Bag" pickup that drops at the death tile; recovered by re-entering the same stratum and walking over it. **One bag only**: dying again before recovery replaces it. Lossy-auto-return rejected (kills agency).
3. **Death-recovery flow** = M1 death sequence (unchanged) → M2 run-summary adds an "EMBER BAG" line ("Recoverable in Stratum N · Room x/y") → next-run Stratum-Entry banner reminds the player → in-run HUD pip + minimap marker once they're in the right stratum.
4. **The M1 contract holds verbatim**: level + XP + equipped persist by default. Ember-bag is the *recovery channel for unequipped inventory only*. Equipped never goes through the bag.
5. **Save schema bumps v3 → v4**: adds `stash` array (revived from M1 stub), `pending_ember_bags` array (one entry per stratum, capped 1/stratum), `stash_room_seen` flag (first-visit tutorial gate). Migration is additive — older saves load with empty stash + zero bags.

## Source of truth

This doc extends the following entries in `team/DECISIONS.md`:

- **2026-05-02 — M1 death rule: keep level + equipped, lose unequipped inventory.** Quoted: *"M2 introduces a stash UI + an 'ember-bag' gear-recovery pattern at the death point."* This doc is the design call-up for that promise.
- **2026-05-02 — Visual direction lock** (480×270 internal, 96 px/tile, integer scaling, nearest-neighbour, ember-orange `#FF6A2A` accent). All UI here conforms.
- **2026-05-01 — Save schema additive vs. non-additive policy** (Devon's `save-format.md`): the v3→v4 bump for stash + ember-bag is a non-additive change in *category* (new top-level concept), additive in *field shape* (existing stash array stub becomes populated). Spec'd here for Devon, lands in his W3-B4 forward-compat doc.
- **2026-05-02 — Inventory & Stats Panel** (`team/uma-ux/inventory-stats-panel.md`): the stash UI reuses cell rendering, tier-color borders, +pip affix glyph, and tooltip rules verbatim. The visual language is *one panel system, two grids*.

The M1 death-restart-flow (`team/uma-ux/death-restart-flow.md`) is the parent surface for the run-summary screen modifications described in §4 below.

---

## §1 — Stash UI spec

### Where the stash lives

**Stash Room** = a small chamber at the entry of every stratum, accessible **only between runs**. Walking into it is how you transition from "in town" to "I'm starting a run."

- **First room of stratum 1** is the canonical stash room. M2 also gives stratum 2's entry chamber a stash (and so on at each stratum-entry as content grows).
- Stash rooms are **safe**: no mob spawns, no hazards, ambient music drops to the menu pad, vignette eases to 20%.
- The room has a literal **stash chest** sprite the player walks up to and presses **E** to open (mirrors loot-pickup affordance) **OR** simply hits **B** anywhere in the room to open. We give two affordances because the chest is the discoverable one and B is the fast one.
- Stash rooms are **NOT in-run rooms.** You can't enter them mid-run. Once you commit to descend, the door locks behind you (visual: the door dims and a glyph appears).

This honors the M1 death rule: the stash is between-runs by construction, so there's no in-run path that lets the player launder unequipped items into safety.

### Grid size: 12 × 6 = 72 slots (v1)

Justified against M2 build-variety needs:

- **8 strata × ~5 hero-tier items per stratum** = ~40 items the stash must accommodate at full M2 depth without forcing constant discards. 72 slots gives ~80% headroom over that worst case.
- **6 build archetypes** × ~5 keepsakes-per-build (alt weapons, alt armors, situational trinkets, relic seeds) = 30 slots of "build-swap stock" + 40 slots of "current-run stash." Player feels rich, not cramped.
- **Two-grid scan symmetry** — inventory panel is 8×3 (24 slots), stash is 12×6 (72 slots). Both are wider-than-tall and the proportion difference (3:1 vs. 2:1 aspect) reads as "this is the bigger pool."
- **One screen, no scrolling.** 480×270 internal canvas at 4× display gives us 1920×1080 of UI room; 72 cells at 24×24 internal (same as inventory cells) = 288×144 internal — fits with margin.

If M2 playtest shows 72 is too cramped or too generous, the next-step lever is **8×8 = 64 (tighter)** or **15×8 = 120 (looser)**. Don't go below 48 or above 144 — that's the readable range for non-paginated single-screen grids.

### Open / close pattern

- **Default key:** `B` (for "Bag" / "Bank"). Single keystroke, no chord.
- **In stash room only** — the binding is *context-sensitive*. Outside a stash room, B does nothing (or could be repurposed in M3 for emote/ping; design deferred).
- A state flag `Levels.in_stash_room: bool` drives the binding. Devon: enter/leave the room emits a signal; `InputManager` (or the existing input-action layer) registers/unregisters the action while inside.
- **Tab still opens the inventory panel** when in the stash room. Player can have *both* panels open at once (see drag semantics below). This is the primary affordance for moving items between inventory and stash.
- **Esc** closes whichever panel was opened most recently (LIFO close stack), matching the existing inventory-panel Esc behavior.

**No overlap with Tab.** Two distinct keys = two distinct surfaces. The downside (one extra binding) is dwarfed by the upside (no state-confusion when both panels need to coexist for the move-between operation).

### Slot semantics + drag/click model

Stash slots use the **same rendering as inventory cells** — 24×24 internal, 2 px tier border, +pip for affixes. Same hover behavior, same tooltip.

Interaction model (extends inventory's LMB-equip / RMB-inspect):

| Action | Mouse | Keyboard |
|---|---|---|
| Move item from inventory → stash | LMB on inventory cell with stash open | **S** with cell focused |
| Move item from stash → inventory | LMB on stash cell with inventory open | **S** with cell focused |
| Drag-equip from stash directly | LMB-drag from stash cell → equipped slot | — |
| Inspect item in stash | RMB | **I** with cell focused |
| Discard from stash | drag outside both panels + drop | **X** with cell focused (Y/N confirm at T2+) |

- **LMB single-click** in the stash room is "swap pool": clicking an inventory item moves it to the first empty stash cell; clicking a stash item moves it to the first empty inventory cell. **No confirm prompt for moves** (it's reversible by clicking again).
- **Drag-and-drop between grids** is the explicit-position path for users who care.
- **Stack semantics:** consumables (M2+) stack to 99 in a single cell. Gear is one-per-cell (no stacking).

### Time-slow on open?

**No.** Stash is between-runs, not in-combat. The stash room has no mobs and no hazards, so there's nothing to slow down. Engine `time_scale` stays at 1.0 throughout.

(Inventory's 0.10 time-slow rule still applies *in-run*; opening the inventory panel inside a stash room sees `time_scale = 1.0` because the room itself has no combat. Devon: the time-slow logic should key off "in-combat or in-hostile-stratum" rather than "panel-open," which is a small refactor — flagged for him below.)

---

## §2 — Ember-bag recovery pattern

### Variant chosen: **pickup-at-death-location**

When the player dies in M2:

1. All unequipped inventory items are extracted from `inventory[]` and packed into an **Ember Bag** entity.
2. The bag spawns as a world pickup at the player's death tile.
3. The bag persists in save data — `pending_ember_bags[stratum_id] = { room_id, x, y, items[] }`.
4. To recover: re-enter the same stratum on the next run, navigate to the room, walk over the bag.
5. Recovered items are *appended* to current inventory (or stash if inventory is full — overflow rule documented below).
6. Visual: the bag is a 24×24 cloth-wrapped bundle with ember-orange wisps drifting up; idle anim 12 fps, ~1 s loop. It does not despawn over time.

**One-bag-only rule:** if the player dies again *before* recovering the previous bag, the new bag **replaces** the old one — old bag's items are lost. This is harsh by design: it makes recovery a meaningful priority without being a checklist of every past death.

**Cap:** at most **one pending bag per stratum**, total cap = 8 (one per stratum). Cross-stratum bags don't replace each other — only same-stratum.

### Why pickup-over-lossy

Considered alternative: **lossy auto-return** (bag returns to stash automatically on death, items demoted to T1 quality / "scorched" tier). Rejected because:

- **Loses agency.** The player has no reason to ever return to a death location, which kills the second-best dramatic beat in the loop ("I died there; I will return to that exact place").
- **Lore inversion.** The "ember" in ember-bag is the player's flame holding their gear together. Auto-return undercuts the diegetic logic — *who carried it back?*
- **Punishes more in practice.** Tier demotion sounds soft but actually is harsh: a T3 sword drop becomes a T1 sword forever. Pickup-at-death-location preserves the original roll exactly.
- **Reference precedent.** Dark Souls / Hollow Knight / Hades-relics-on-Charon-rescue all use the pickup pattern. It's the genre's shared language; players know how to read it.

The pickup variant has its own friction (you might never recover a bag if you can't get back to that room), but that friction is *intentional* — it keeps "what you carried at death" a real stake without making it a bookkeeping burden.

### Equipped vs. inventory — the contract

The ember bag carries **only unequipped inventory items**. Equipped items are *never* in the bag — they persist with the character per the M1 death rule, full stop. This means:

- A player who dies with their best gear equipped and a stack of trash-tier inventory loses... the trash. Good.
- A player who dies with a great drop *unequipped* (because they hadn't decided yet) gets it back via the bag. Also good — that's the design intent.
- A player who *just* swapped their old armor into inventory before dying gets it back via the bag. The pre-swap UI moment IS the choice point; the bag is the safety net.

### UI surface — how the player knows there's a bag waiting

Three layered cues at increasing salience:

1. **Run-summary screen (M2 evolution):** the "LOST WITH THE RUN" section becomes "**EMBER BAG — RECOVERABLE**" if items went into the bag. Lists items as ember-tinted icons (not greyed-out — they're *recoverable*, not lost). Subtitle: `Recoverable in Stratum N · Room x/y`. (Old greyed-out section persists for *truly* lost items, e.g. consumables that don't survive the bag — design reserved for later.)
2. **Stratum-entry banner:** when entering a stratum that has a pending bag, a 2-second banner slides in from the top of the HUD: `Ember Bag pending — Stratum N · Room x/y`. Ember-orange text on dark slate, dismisses on any input.
3. **HUD pip + minimap marker:** while in the bag's stratum, a small ember-orange pip appears in the HUD (left of the HP bar), and the bag's room is marked on the minimap with the same pip glyph. Walking into the bag's room makes the pip pulse; standing on the bag plays the ember-pickup audio cue.

These three cues match the player's pacing: summary → run-start → in-run-discovery. Each cue is necessary but redundant enough that no single one is required to find the bag.

### Edge cases the bag must handle

| Case | Behavior |
|---|---|
| Player dies in a procedurally-generated room that doesn't exist next run | Bag spawns in the **stratum-entry stash room** as a fallback, with a tooltip note ("returned by the stratum's flame") |
| Player dies in the boss room | Bag spawns at the boss-arena entry (not on the boss arena itself — recovery shouldn't require re-fighting the boss) |
| Player dies on the same tile twice | Second bag replaces first; first bag's items are lost (one-bag rule) |
| Inventory is full when picking up the bag | Items overflow into stash; if stash is also full, items are *kept on the bag entity* and the bag stays in-world (player can return for the rest after stashing/discarding) |
| Bag's items reference deleted content (post-update item ID removed) | Migration step on save load drops unrecognized item IDs from the bag with a `push_warning` |
| Player picks up a corrupt save (HTML5/IndexedDB) | Bags absent → no recovery; equipped + level still safe per M1 rule. Don't let bag-state corruption nuke the character. |

---

## §3 — Death-recovery flow (screen-by-screen)

Extends `team/uma-ux/death-restart-flow.md` Beats A–G. M1 sequence is unchanged in M2; the only changes are summary-screen content and a new pre-run banner.

### Beat A–D (UNCHANGED from M1)

Lethal hit → embers gather → dissolve + bell → "You fell." → run summary slides up. M1 wordmark and audio cues hold.

### Beat E (M2 run-summary screen — modified)

The summary panel grows one section. New layout:

```
+----------------------------------------------------------------------------+
|                              YOU FELL.                                     |
|                       STRATUM 2 · ROOM 3 / 8                               |
|                                                                            |
|  --- THIS RUN ---                                                          |
|    Mobs felled         12                                                  |
|    Time in run         9:14                                                |
|    Deepest room        3 / 8                                               |
|                                                                            |
|  --- KEPT ---                                                              |
|    Character level     5   (no change)                                     |
|    XP                  +240  (180 → 420)                                   |
|    Equipped            Pyre-edged Shortsword · Worn Hauberk                |
|                                                                            |
|  --- EMBER BAG · RECOVERABLE ---                                           |
|        +--+ +--+ +--+                                                      |
|        |T2|*|T1|*|T3|     "Stratum 2 · Room 3 / 8"                         |
|        +--+ +--+ +--+     [3 items will return]                            |
|                                                                            |
|  --- LOST WITH THE RUN ---                                                 |
|    [grey-out shadow icons of consumable stubs / non-recoverable items]     |
|                                                                            |
|        [   D E S C E N D   A G A I N   ]   [ Return to Title ]            |
+----------------------------------------------------------------------------+
```

Section ordering changes: KEPT → EMBER BAG → LOST WITH THE RUN. The bag sits *between* the wins and the losses — it's the recoverable middle ground, and the player's eye reads it as such. Visual treatment: ember-orange section header (matches KEPT, not LOST), card icons at full saturation (not greyed). Subtitle in muted parchment tells the player exactly where to go.

If no items went into the bag (player died with a fully-equipped+empty-inventory loadout), the EMBER BAG section is omitted entirely — no empty placeholder.

### Beat F — Descend Again (M2 augmentation)

After the M1 fade-up sequence completes (ember-rising whoosh → "The flame remembers." → fade-up to S1 R1):

- If a pending bag exists in a stratum the player can reach, the **Stratum-Entry banner** triggers when the player crosses into that stratum's first room. (Stratum 1 banner triggers on respawn fade-up; stratum 2+ banners trigger when the player descends into them.)
- HUD pip appears the moment the player is in the bag's stratum. Pulses for 1 s on first appearance, then settles to a steady glow.

### New beat — Stash Room Entry (M2)

When the player enters a stash room (whether on first respawn or re-entering between runs):

```
+--------------------------------------------------------+
|                                                        |
|   [pixel art: stash chest, dim torchlight, ember motes]|
|                                                        |
|                                                        |
|                  STASH                                 |
|              Stratum 1 · The Outer Cloister            |
|                                                        |
|              [E] open chest    [B] open stash         |
|              [Tab] inventory   [Down] descend          |
|                                                        |
+--------------------------------------------------------+
```

- The room sprite is a small chamber, dim warm light, the chest center-stage.
- A *non-modal* hint-strip at the screen bottom shows the four key bindings. Fades out after 5 s of player movement (won't re-show in this session unless `stash_room_seen=false`, which only triggers on first-ever visit).
- Pending-bag indicator (if applicable): small ember-orange pip on the chest sprite + a banner.
- Player presses Down (or walks south to the descent-door tile + presses E) to leave for the run.

### Recovery prompt

When the player walks over an ember bag:

- Audio: 1.0 s ember-rise whoosh (same sample as Beat F's run-start whoosh), pitched up 2 semitones.
- Visual: the bag dissolves upward in ember particles, items appear briefly in a stack-of-cards burst above the player's head before sliding into their inventory icon (top-left of HUD).
- Toast notification, top-right of screen, 4 s: `Ember Bag recovered · 3 items returned`.
- If overflow: `Ember Bag recovered · 2 items to stash, 1 to inventory`.
- **No confirm prompt.** The bag is unambiguously yours; pickup is the right default.

### What the player does NOT see

The M1 contract holds — these are NOT changed by M2:

- Equipped items are not part of the bag, not part of the recovery flow, not greyed-out on the summary screen. They simply persist, silently, the way they did in M1.
- Character level, XP, stat allocations are not part of the bag. They persist per M1.
- "Stash" (the between-run pool) does NOT consume bag items automatically — the bag returns to *inventory* by default. Letting auto-stash happen would be the lossy variant we rejected.

---

## §4 — Visual direction (palette / pixel-art conformance)

All stash-UI surfaces conform to `team/uma-ux/visual-direction.md` and `team/uma-ux/palette.md`.

### Stash panel chrome

- **Background:** dark slate `#1B1A1F` at 92% opacity (matches inventory).
- **Top-edge bar:** 1 px ember-orange `#FF6A2A`.
- **Section header:** "STASH" small caps, ember-orange, 12 px font.
- **Cell border (default):** muted slate `#3A363D`, 1 px.
- **Cell border (hover/focus):** ember-orange, 1 px.
- **Tier-color cell strip:** 4 px bottom strip in tier color (T1–T6 from inventory-stats-panel palette table).

### Ember-bag pickup sprite

- **Size:** 24×24 internal (base), 32×32 internal at the recovery moment.
- **Idle anim:** 12 fps, 4 frames; the bag rocks slightly + ember motes drift up at 1 px/frame.
- **Recovery anim:** 24 fps, 8 frames; bag dissolves bottom-to-top into ember stream.
- **Colors:** cloth body in `#5A4A3A` (warm brown), ember motes in `#FF6A2A` and `#FFB066`. The ember accent matches the player's death-dissolve embers — visual rhyme.

### HUD pip

- **Size:** 8×8 internal, sits 12 px left of the HP bar.
- **Idle:** ember-orange `#FF6A2A`, 50% opacity.
- **In-stratum pulse:** opacity 50%↔100% over 1.0 s, looping.
- **In-room pulse:** color shifts to `#FFB066` (lighter ember), pulses faster (0.5 s cycle).

### Stash-room ambient

- **Vignette:** 20% opacity (vs. stratum 1's 30%) — safer-feeling rooms read brighter.
- **Light source:** torchlight from the stash chest itself, warm key (`#FFB066`).
- **Stash chest sprite:** 32×32 internal, dark wood with ember-orange wisps idling above the lid.

### Typography

- **Section headers:** 12 px small caps, ember-orange (matches inventory).
- **Body text:** 14 px off-white `#E8E4D6`.
- **Subtitles / location hints:** 12 px muted parchment `#B8AC8E`.
- **Wordmark "STASH":** if used as a title-card variant, same wordmark font as "You fell." for stylistic consistency.

---

## §5 — Implementation notes for Devon (M2)

### Save schema bump (v3 → v4)

Additive changes to `data{}`:

```json
{
  "stash": [ /* array of item dicts, same shape as M1 stub */ ],
  "pending_ember_bags": {
    "1": { "stratum": 1, "room_id": "s1_room04", "x": 184, "y": 96, "items": [...] },
    "2": null
  },
  "stash_ui_state": {
    "stash_room_seen": false
  }
}
```

- `stash` already exists as an empty array stub in v1+ (per `team/devon-dev/save-format.md`). v4 just *populates* it.
- `pending_ember_bags` is keyed by stratum (string-int keys to match Godot Dictionary ergonomics in JSON). One-bag-per-stratum cap enforced at write time.
- `stash_ui_state.stash_room_seen` gates the first-visit hint-strip behavior.

**Migration v3 → v4:** additive only. Older saves load with empty `stash`, empty `pending_ember_bags`, `stash_room_seen=false`. The migration step is `data["stash_ui_state"] = data.get("stash_ui_state", {"stash_room_seen": false})` and `data["pending_ember_bags"] = data.get("pending_ember_bags", {})`. No data loss path.

### New autoload? — No, extend existing

- **`Inventory` autoload** (existing) — add `stash: Array[ItemInstance]`, `move_to_stash(item)`, `move_from_stash(item)`. Single source of truth for both pools.
- **`StratumProgression` autoload** (existing) — add `pending_ember_bags: Dictionary[int, EmberBag]`, `pack_bag_on_death(stratum, room_id, pos, items)`, `recover_bag(stratum)`. Already owns stratum-keyed state.
- **`Levels` autoload** (existing) — add `in_stash_room: bool`, signals `entered_stash_room` / `left_stash_room`. Drives the binding context-sensitivity for the B key.

No new autoload is needed. Three additive methods across three existing autoloads.

### New scenes Devon owns

- `scenes/ui/StashPanel.tscn` — the 12×6 grid panel. Sibling to `InventoryStatsPanel.tscn`. Reuses `InventoryCell.tscn` verbatim.
- `scenes/levels/StashRoom.tscn` — the chamber scene. Stratum-1's instance is `Stratum1StashRoom.tscn`.
- `scenes/objects/StashChest.tscn` — the interactable chest sprite (Area2D + Sprite2D + AnimationPlayer for the ember motes).
- `scenes/objects/EmberBag.tscn` — the world pickup. Reuses `Pickup.tscn` collision pattern but with bag art + recover-on-touch logic.

### Signal surface

| Signal | Emitter | Args | Purpose |
|---|---|---|---|
| `entered_stash_room` | `Levels` | `(stratum_id: int)` | Enables B-binding, switches ambient music |
| `left_stash_room` | `Levels` | `(stratum_id: int)` | Disables B-binding, restores in-run state |
| `bag_packed` | `StratumProgression` | `(stratum_id: int, item_count: int)` | Death sequence consumes for summary screen |
| `bag_recovered` | `StratumProgression` | `(stratum_id: int, items: Array)` | HUD toast + inventory inflow animation |
| `stash_changed` | `Inventory` | `()` | UI panel re-render |

### Time-scale refactor (small)

Currently inventory time-slow keys off "panel open." Refactor to "panel open AND in-combat-context" so opening inventory inside a stash room sees `time_scale = 1.0`. Combat-context = `Levels.in_stash_room == false` for now; expand as M2 adds non-combat zones (hub town in M3+).

### Out of scope for v1 (call out for M3+)

- **Stash search / filter** (by tier, slot, affix) — wait until 60+ items are typical.
- **Multiple stash tabs** — single-tab is fine for 72 slots.
- **Sortable columns** (auto-sort by tier, etc.) — flagged as M3 polish.
- **Trade / give-to-NPC** — out of scope; we're not designing economy here.

---

## §6 — Tester checklist for Tess (M2 acceptance)

Per `team/TESTING_BAR.md`. M2-AC suite — these are the integration / acceptance shapes; unit-level coverage falls out of Devon's implementation.

| ID | Check | Pass |
|---|---|---|
| ST-01 | Stash room visible at stratum-1 entry; player can walk in/out freely between runs | yes |
| ST-02 | Stash room is **not** accessible mid-run (no door appears in any in-run room layout) | yes |
| ST-03 | Pressing **B** in stash room opens the stash panel; pressing B outside does nothing | yes |
| ST-04 | Stash grid is exactly 12×6 = 72 cells, single screen, no scrolling | yes |
| ST-05 | Tab still opens inventory inside the stash room; both panels can be open simultaneously | yes |
| ST-06 | Engine.time_scale == 1.0 throughout stash-room session, including with panels open | yes |
| ST-07 | LMB on inventory cell with stash open moves item to first empty stash cell | yes |
| ST-08 | LMB on stash cell with inventory open moves item to first empty inventory cell | yes |
| ST-09 | Drag-from-stash to an equipped slot equips directly (skips inventory) | yes |
| ST-10 | T2+ discard from stash prompts inline confirm; T1 discards immediately with undo toast | yes |
| ST-11 | On death with N unequipped inventory items: ember bag entity is created with all N items | yes |
| ST-12 | Equipped items are NEVER in the ember bag — they persist on the character | yes |
| ST-13 | Death summary shows "EMBER BAG · RECOVERABLE" section with item icons + location hint | yes |
| ST-14 | If inventory was empty at death: EMBER BAG section is omitted entirely | yes |
| ST-15 | Re-entering the death stratum: stratum-entry banner displays "Ember Bag pending" | yes |
| ST-16 | HUD pip appears while in the bag's stratum; pulses faster in the bag's room | yes |
| ST-17 | Walking over the bag plays the recovery audio + toast; items return to inventory | yes |
| ST-18 | Inventory full at recovery: overflow goes to stash (toast says "X to stash, Y to inventory") | yes |
| ST-19 | Inventory + stash both full at recovery: bag stays in-world, partial recovery happens | yes |
| ST-20 | Dying twice in same stratum without recovery: second bag replaces first, first's items lost | yes |
| ST-21 | Dying in stratum 2 while a bag is pending in stratum 1: both bags exist independently | yes |
| ST-22 | Save → quit → relaunch preserves: stash contents, pending bags, stash_room_seen flag | yes |
| ST-23 | Bag spawns at exact death tile in re-entered procedural room (or at stash-room fallback if room doesn't exist) | yes |
| ST-24 | Bag in boss room spawns at boss-arena entry, not on the arena itself | yes |
| ST-25 | M1 contract still holds: level, XP, equipped persist on death without bag involvement | yes |
| ST-26 | Schema v3 save loads cleanly under v4 runtime: empty stash, no bags, stash_room_seen=false | yes |
| ST-27 | Visual direction: stash UI conforms to palette + cell rendering rules from inventory panel | yes |
| ST-28 | Ember-bag pickup sprite uses `#FF6A2A` ember motes matching player death-dissolve | yes |

### Sponsor probe targets

When M2 RC reaches Sponsor's interactive soak, watch for:

- **"Where do I put my stuff?"** — stash discoverability. If the player misses the chest/B affordance for >2 minutes on first stash-room entry, the affordance is too quiet.
- **"Did I lose my [X]?"** — the EMBER BAG summary section's salience. If Sponsor doesn't notice it, ember-orange isn't strong enough vs. KEPT.
- **"Where's my bag?"** — pre-respawn navigation. If the banner+pip+minimap-marker stack still doesn't get Sponsor to the bag inside a normal run, we need a fourth cue.
- **"Why does my old gear disappear?"** — one-bag-per-stratum rule. If Sponsor double-dies and feels cheated, we may want to soften (allow N bags per stratum) or signal more clearly ("recovering a bag now will overwrite Stratum N's").

---

## §7 — Open questions

Flagged for Sponsor / orchestrator / Priya — not all need resolving before M2 implementation begins.

1. **Stash size cap of 72 — is the M2-content target right?** Drew's M2 stratum-2 content scope (W3-B2, W3-B3) determines actual loot density. If 72 feels cramped after 4-stratum playtest, bump to 8×12 = 96 or 10×12 = 120. **Owner:** Priya — sized in the M2 backlog.
2. **One-bag-per-stratum vs. N-bags-per-stratum.** Soft / hard recovery is the real lever. One-bag is the design intent; N-bags is the playtest fallback if one-bag feels punishing. **Owner:** Sponsor — first M2 soak feedback.
3. **Boss-room death bag location — at the door or at the corpse tile?** I've spec'd "at the door" to avoid forcing a re-fight, but a bolder design would put it at the corpse tile and use the bag as the lure that pulls the player back to the boss. **Owner:** Sponsor — narrative call.
4. **Hub town / non-combat zone in M3+** — does the stash room generalize into a town hub, or stay a per-stratum chamber? **Owner:** Priya — M3 scoping.
5. **Lossy-tier "scorched" gear as a stretch concept.** Not for v1, but: M3 could add a "True Ember" hard-mode where bags arrive *with* tier demotion. Worth keeping the variant alive in the design memory. **Owner:** Uma — M3 design concern, parked.
6. **Stack semantics for consumables** (M2+) — currently unspecified beyond "stack to 99." If consumables also become bag-recoverable, the bag schema may need stack-count fields. **Owner:** Drew + Devon — when consumables enter scope.
7. **Stash sharing across save slots (multi-character).** M2 save schema has slot reserved as a non-zero possibility. If M3 introduces multi-character, do siblings share a stash or each get their own? **Owner:** Priya + Sponsor — M3 design.
8. **Tab + B both held — what happens?** Spec is "both panels open." Edge case: if drag-from-stash targets an equipped slot while the inventory grid is also receiving keyboard focus, who wins the drop? Devon's call during impl. **Owner:** Devon.
9. **Discard-from-stash undo window** — inventory's undo toast is 3 s. Is the same right for stash, or longer (since stash items are higher-stakes)? Suggest 5 s for stash. **Owner:** Uma — to be confirmed in M2 polish pass.

---

## Hand-off

- **Devon (W3-B4 + M2 implementation):** save schema v3→v4 spec'd above; three signals + three autoload extensions; four new scenes; small time-scale refactor. The v3→v4 migration plan goes into Devon's W3-B4 forward-compat doc.
- **Drew (M2 content):** ember-bag pickup sprite (24×24 internal, idle + recovery anims), stash chest sprite (32×32 internal, idle), stash-room tilemap variant per stratum.
- **Tess (M2 acceptance):** ST-01 through ST-28 above. Coverage stacks on M1 acceptance — none of M1 should regress.
- **Priya (M2 backlog):** stash-size lever, one-bag-vs-N-bags lever, M3 hub-town consideration. Three open questions are Priya's call.

---

## Appendix — what we're NOT designing here

- M2 content itself (stratum-2 layouts, mob roster, boss design) — those are Drew + Priya's M2 backlog.
- M3 permadeath / "True Ember" mode — explicitly deferred per `death-restart-flow.md` "Pre-permadeath note".
- Trade / economy / NPC interactions — out of scope.
- Stash search / filter / sort — M3 polish.
- Multi-character stash sharing — M3 design (open question 7).
