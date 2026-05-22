# World-Map UI Direction — Parchment Per-Stratum Map (M3 Tier 3)

**Owner:** Uma · **Phase:** M3 Tier 3 W1 (design only; implementation lands in Devon's `WorldMap.tscn` per `post-wave3-sequencing.md §3 M3 Tier 3 Track 4` and §5 W1 tickets) · **Drives:** Devon's W2 map-UI minimal impl, Drew's `ZoneDef` schema authoring (Track 3) — the map must render whatever Drew's zone schema exposes, Tess's M3 Tier 3 acceptance rows for the map surface · **Authority:** Sponsor signed SI-3 = (a) Diablo-II per-act map (`post-wave3-sequencing.md §6 SI-3`).

This doc extends `team/uma-ux/hub-town-direction.md §4` (the descent-portal stratum-picker is the embryo of this surface) and `team/uma-ux/palette.md` (Outer Cloister parchment hex set + ember through-line) into the M3 Tier 3 world-map UI. Doc-only — nothing here ships in code until Devon's W2 dispatch consumes it.

## TL;DR (5-line summary)

1. **Tonal anchor — "a scroll the cloister keeps."** The map reads as **a parchment scroll the monks unroll on the anvil between runs.** Diegetic: the cloister is a record-keeping order; one of their tasks is mapping the depths. The player borrows the scroll. Not a glowing screen-space HUD; not a god's-eye satellite view. **Ink-on-parchment, a hand-drawn record of a place that is being explored.**
2. **Per-stratum scope, no global overworld.** Each stratum is its own scroll. The hub-town descent-portal is the chain entry — picking a stratum from the portal opens that stratum's map. No "see all 8 strata on one screen" view; that would re-introduce the Diablo-IV maximalism Sponsor rejected at SI-3.
3. **4-6 nodes per stratum, directed-graph topology, hand-authored.** Each node is a zone (per Drew's `ZoneDef` schema, M3 Tier 3 Track 3). Edges are walkable paths. Map renders the **topology**, NOT a cartographic shape — node positions are author-laid, not derived from world geometry. Diablo-II-Act-1's "Den of Evil → Cold Plains → Stony Field" laddering, not Diablo-IV's painted world.
4. **Four node states, glyph + brightness + accent.** Undiscovered (dark silhouette + no glyph) / Discovered-not-cleared (parchment-tone at 50%) / Cleared (parchment-tone at 100% + cleared glyph) / Boss-room (skull-crown override on the boss-room node regardless of clear-state). Active-quest target stamps an ember-orange exclamation overlay on whichever node owns the active objective.
5. **Single zoom level + fast-travel for M3 Tier 3. M5 polishes everything else.** No multi-zoom, no fog-of-war shape variations, no lore-tooltip-on-hover, no animated zone-state transitions beyond the one newly-unlocked fade. Those are M5 polish per `post-wave3-sequencing.md §3 M5`. M3 Tier 3 ships the minimum that proves the Diablo-shape pattern.

## Source of truth

This doc extends:

- **`team/uma-ux/hub-town-direction.md` §4 — Descent-portal: south-edge ember arch.** The portal's stratum-picker UI is the navigation chain entry. From the portal: pick a stratum → enter stratum → world-map shows zones within stratum. The portal itself is unchanged; what it opens evolves from the M3 Tier 1 stratum-picker (list of strata) into the M3 Tier 3 picker → per-stratum map (zones within selected stratum).
- **`team/uma-ux/palette.md` — Outer Cloister accents + ember through-line.** Parchment `#D7C68F` is the map's substrate hex. Ember accent `#FF6A2A` is the active-quest stamp. HUD body text `#E8E4D6` is map labels. Panel background `#1B1A1F` at 92% opacity is the modal chrome behind the scroll. No new hexes needed.
- **`team/uma-ux/hud.md`** — parchment family + modal chrome conventions; the map's chrome inherits the inventory/death-panel modal language verbatim.
- **`team/uma-ux/visual-direction.md`** — 480×270 internal canvas, 12 fps animation pace, single warm light source. Map animations conform: 12 fps cadence for the newly-unlocked fade; modal open/close at standard 0.2 s ease.
- **`team/priya-pl/post-wave3-sequencing.md` §1 Commitment 4** — world-map UI is a first-class Diablo-shape commitment. Sponsor's SI-3 sign-off picked the per-act-map shape; this doc renders the choice into a buildable spec.
- **`.claude/docs/html5-export.md`** — HDR clamp + Polygon2D + WebGL2 rules shape the visual-primitive calls in §6. The map is screen-space CanvasLayer; the parchment is a TextureRect or a tiled ColorRect; node glyphs are ColorRect-rotated-rect or Label-text. **No Polygon2D, no CPUParticles2D required on this surface.**

---

## §1 — Tonal anchor: "a scroll the cloister keeps"

The world-map is **not a screen-space HUD overlay.** It is **a scroll** — specifically, a parchment scroll the monks of the Outer Cloister have been keeping, and which they unroll on the anvil when the player asks to see the depths. The diegetic claim is unambiguous: the cloister is a **record-keeping order**, and the world-map is the record. The player does not have map vision of their own; they borrow the monks' map.

**Why this framing carries:**

- **Diegetic continuity with hub-town.** The hub-town is the Outer Cloister populated by monks who tend the braziers, mind the anvil, and post the bounties. Adding "and keep a map of the depths" to the monks' job description costs zero net authoring — the bounty-board already establishes them as record-keepers. The world-map is **the same kind of artifact as the bounty parchments**, just larger.
- **Descent narrative.** Diablo II's Act 1 map is famously a parchment-and-ink artifact (Deckard Cain's voiceover sells it as "the road from Rogue Encampment"). Embergrave's descent narrative is solemn, not heroic; a parchment scroll fits the tone better than a glowing screen-space interface. The map's slowness — unroll, read, choose — IS the tonal beat.
- **Production-cheap.** Parchment `#D7C68F` already exists in `palette.md` Outer Cloister accents. The map's substrate is ONE TextureRect or one tiled ColorRect. Node glyphs are simple ColorRect + Label primitives. The modal chrome is the inventory-panel chrome already authored. **The only new authoring is the per-stratum-map texture (one per stratum) + four small glyph sprites.** See §9 asset list.
- **Rejects the Diablo-IV overworld density.** Diablo IV's map has fog-of-war, persistent overworld with NPC markers, point-of-interest icons, dynamic events. That's a pixel-art-budget-killer AND tonally wrong for Embergrave (Embergrave's depth narrative is intimate; the map should NOT feel like a fantasy-MMO interface). Sponsor's SI-3 fork from (b) was the right call.
- **Rejects the Crystal-Project room-tree.** Crystal Project's map is abstract — boxes-and-arrows showing screens visited. That's too abstract for "see the world on a map" framing per Sponsor's `game-concept.md` quote. The map should feel like **a place**, not a flowchart.

**Reads as:** **a hand-drawn record of an explored place.** Parchment texture. Ink-line zone borders. Hand-drawn-looking node markers (small icons, not perfect geometric shapes). Ember-warm light glints on cleared nodes (the cloister highlights what the player has finished). Undiscovered nodes are blank parchment — there is nothing for the monks to draw yet because the player hasn't been there.

**Tonal anti-references** (what the map must NOT read as):

- **Diablo-IV interactive world-map** — too maximalist; too modern; too much UI surface.
- **Pokémon Red town-map** — too cartoony, too cheerful, too point-and-click-adventure.
- **Crystal-Project room-tree flowchart** — too abstract; loses the "see the world" framing.
- **Dark Souls 3 / Elden Ring "no map at all"** — Embergrave's loop NEEDS the player to see where the active quest sends them; "no map" is hostile to the Diablo-shape directive.
- **Cyberpunk-style mini-map HUD overlay** — wrong tone, wrong genre, wrong everything.

The reference shelf is: **Diablo II Act 1 / Act 2 parchment-map screens** (the canonical model — Sponsor's SI-3 pick), **The Curse of Monkey Island world-map** (parchment-ink + ember-accent + hand-drawn feel), **Dragon's Lair II travel-map screens** (single-screen ink-and-color, no zoom).

---

## §2 — Per-stratum scope + navigation chain

Each stratum has its own map. **No global overworld view.** The navigation chain is:

```
[Hub-town] → press Down at descent-portal → [Stratum-picker]
                                                    ↓
                                              [Stratum-N selected]
                                                    ↓
                                              [World-map for Stratum-N]
                                                    ↓
                                              [Click a zone] → enter zone
```

The **stratum-picker** is the modal already specified in `hub-town-direction.md §4` — a list of unlocked strata. It is unchanged by this doc except for one evolution: after picking a stratum, instead of immediately descending to that stratum's first zone, the picker **transitions to the world-map for that stratum**. The player chooses the zone from the map.

The **world-map** is what this doc specifies.

**Why no global overworld:** the Diablo-IV alternative (b) is the global-overworld shape — paint all 8 strata on a single screen with the descent chain rendered as a vertical column. Sponsor rejected that at SI-3. Reasons documented in `post-wave3-sequencing.md §1 Commitment 4`: (1) cheapest to author, (2) matches Sponsor's "areas in strata" framing, (3) scales naturally to 8 strata without map complexity exploding.

**Tonal reason** (this doc's contribution): a global overworld breaks the **descent intimacy**. Each stratum is a discrete world the player commits to; seeing all 8 on one screen flattens the descent into a vertical scroll-bar. Per-stratum maps preserve the "you are inside this place right now" framing.

**Re-entry shape (M3 Tier 3):** when the player descends and dies, they return to the hub-town. If they want to re-enter the same stratum, they re-do the chain: portal → stratum-picker → stratum-N map → click zone. The default-selection logic in the stratum-picker already remembers the last-descended stratum (per `hub-town-direction.md §7` save field `hub_town_last_descended_stratum`); the world-map should likewise remember the last-visited zone within that stratum (see §7 save-state).

**Fast-travel scope:** fast-travel between zones via map click is permitted **only for cleared zones** within the current stratum. See §5 interaction shape. M5 polish lifts this to cross-stratum waypoint travel; M3 Tier 3 stays within one stratum.

---

## §3 — Zone discovery state (four states + active-quest overlay)

Every zone (node on the map) is in one of four discovery states. The map renders the state via a combination of **brightness + glyph + label visibility.**

### State 1 — Undiscovered

- **Brightness:** the node is **invisible** — no marker drawn at the node position. The parchment substrate shows through unmodified.
- **Glyph:** none.
- **Label:** none.
- **Edges:** edges leading from a discovered node TO an undiscovered node ARE drawn (so the player knows there's "something out there") but only as a faint ink-line at 30% opacity, fading toward the undiscovered end. Edges between two undiscovered nodes are not drawn.
- **Diegetic logic:** the monks have not drawn this place yet. There is nothing to render.

### State 2 — Discovered (visited, not cleared)

- **Brightness:** parchment-tone at 50% opacity over the substrate. The node circle is faintly visible.
- **Glyph:** a small open-circle marker (12 × 12 px, hollow, parchment-tone border).
- **Label:** the zone name in HUD body text `#E8E4D6` at 70% opacity, below the marker.
- **Edges:** edges from this node to other discovered/cleared nodes drawn at 100% opacity; edges to undiscovered nodes at 30% fading.
- **Diegetic logic:** the monks have been told this place exists, but the player has not finished it. The record is incomplete.

### State 3 — Cleared (all room-progression objectives complete)

- **Brightness:** parchment-tone at 100% opacity. The node marker is fully drawn.
- **Glyph:** a small **filled-circle-with-checkmark-cross** marker (12 × 12 px, parchment-tone fill, `#1B1A1F` panel-background X-cross drawn on top via two rotated ColorRect strokes — see §6 visual-primitive note, **NOT a `✓` Unicode character per `.claude/docs/html5-export.md` default-font-glyph rule**).
- **Label:** the zone name in HUD body text `#E8E4D6` at 100% opacity.
- **Edges:** edges drawn at 100% opacity.
- **Diegetic logic:** the monks have finished drawing this zone. The player has cleared it. The X-cross marker is a tally — the cloister keeps tallies.
- **Definition of "cleared" for M3 Tier 3:** all mobs in the zone are dead AND all zone-bound NPC objectives are complete. Drew owns the cleared-state schema (`ZoneDef.cleared_condition`); the map reads the boolean.

### State 4 — Boss-room (override on the boss-room node regardless of clear-state)

- **Brightness:** 100% — boss rooms are always drawn at full opacity once their owning zone is at-least Discovered.
- **Glyph:** **skull-and-crown** marker (16 × 16 px, slightly larger than the other glyphs). Drawn as a small composite of three rotated ColorRects + one Label "S" at top (skull placeholder until M5 polish authors a proper 16×16 boss-room icon sprite). **Color:** `#7A2A26` mob-HP-foreground hex over a `#1B1A1F` outline. **NOT ember-orange** — ember-orange is reserved for active-quest stamping; the boss-room glyph must read as "danger here," not "go here." Mob HP foreground reads as "the enemy lives here" diegetically.
- **Cleared boss-room override:** when the boss is dead, the skull-crown glyph is overlaid with the X-cross from State 3. The boss-room marker reads as "this place had a boss; you killed it." This is the **only** node-state composition (skull-crown + X-cross) — every other node has exactly one glyph at a time.
- **Diegetic logic:** the monks know where the bosses live. The cross is the tally.

### Active-quest overlay (orthogonal to discovery state)

When the player has an active quest objective bound to a specific zone (per Drew's quest schema + Devon's `quest-state-aware-dialogue-branching` from `post-wave3-sequencing.md §3 Track 3`), that zone gets an **ember-orange exclamation overlay** drawn on top of its discovery-state glyph.

- **Glyph:** a small ember-orange `!` glyph (drawn as **two stacked ColorRects** — a 2×8 vertical bar + a 2×2 dot beneath, **NOT a `!` font character — wait, actually `!` IS plain ASCII and IS in the default-font glyph subset per `.claude/docs/html5-export.md`**, so a Label with text "!" is acceptable here; cite the rule explicitly so Devon doesn't reach for `❗` Unicode). Color: `#FF6A2A` ember accent.
- **Position:** above-right of the existing node marker, 8 px offset.
- **Animation:** a slow 4 fps pulse — opacity 70% → 100% → 90% → 80% → repeat, ~1 s cycle. Re-uses the brazier-pulse cadence from `hub-town-direction.md §4` so the visual language is consistent across the project.
- **Diegetic logic:** the cloister has marked which zone holds the player's current task. **One ember-orange stamp at a time** (the active quest); multiple stamps would dilute the signal.

**Composition rules:**

- A node may be Undiscovered + Active-quest target (if the quest dialog tells the player about a zone they haven't found): in this case, the node IS drawn at State-2 brightness with State-2 glyph, AND the ember-orange exclamation. Diegetic: the monks told you about the place, even if you haven't been there yet.
- A node may be Discovered + Active-quest target: standard composition.
- A node may be Cleared + Active-quest target only briefly (e.g., a "return to NPC after quest objective" beat that places the active stamp on the hub-town's equivalent map-marker, which is always cleared). Briefly because the quest-state-aware dialogue should advance off "cleared + active" quickly.
- Boss-room + Active-quest target: standard composition (skull-crown + exclamation).

---

## §4 — Layout shape (per-stratum topology)

Per-stratum maps are **hand-laid directed graphs**, not procedural cartography.

### Zone count target per stratum (M3 Tier 3 baseline)

- **4-6 zones per stratum.** Both S1 and S2 ship with this density in M3 Tier 3.
- **Examples (illustrative; Drew owns the actual zone names + schema):**
    - S1 zones: Outer Cloister (hub adjacency) / Eastern Reliquary / Sunken Pillar Hall / Cracked Brazier-Walk / Stratum-1 Boss Room (Warden's Hold).
    - S2 zones: Mining Foreman's Anteroom / Collapsed Vein Tunnel / Hot-Slag Reservoir / Stoker's Forge / Stratum-2 Boss Room (Vault-Forged arena).

The 4-6 target is the **smallest count that proves the per-act-map shape works** without being so sparse the map feels empty (Diablo II Act 1 has ~6 areas; this is the model). Sponsor can dial up to 8-10 per stratum in M5 polish if a stratum's content warrants it.

### Edges (walkable paths between zones)

Edges represent navigable connections between zones. Diegetically, a path through the rock from one named place to another. **Edges are NOT terrain** — they are abstract connections. The player does not "walk along the edge" during gameplay; the edge tells the map-reader the zones connect, and the player traverses the connection via the in-zone exits Drew wires per `ZoneDef`.

**Edge gating:** some edges are gated. Gating reasons (Drew's schema lock):

- **NPC-dialog gate:** the player cannot reach Zone B from Zone A until they have completed a specific NPC dialogue (e.g., "the librarian must tell you about the back passage"). Map renders the gated edge **as a dashed ink-line at 50% opacity** until the gate clears, then upgrades to a solid 100% ink-line.
- **Boss-clear gate:** the player cannot reach Zone B from Zone A until they have killed the Zone-A boss. Map renders gated edge same as NPC-gated (dashed 50%).
- **Item gate (deferred to M4):** "the player must hold the iron key from the Stoker's Forge to enter the Vault." Not in M3 Tier 3 scope; flagged for M5.

**Edge rendering:**

- **Default edge** (no gate, both endpoints reachable): solid ink-line at 100% opacity, `#1B1A1F` panel-background hex (reads as dark ink on parchment).
- **Gated edge** (gate not cleared): dashed at 50%, same hex.
- **Unlocked-this-session edge** (gate just cleared): solid 100%, with a one-shot 0.6 s ember-orange glow tween that fades on first map-open after the unlock — see §7 animation feel.

### Topology shape (NOT cartographic)

The map renders the **graph topology**, NOT a literal cartographic projection of the world's geometry. Node positions are hand-laid by Uma + Drew (Drew owns the data, Uma owns the visual composition). The same zones in two different strata DO NOT have to share any layout convention — each stratum's map is its own composition.

**Why not cartographic:**

- The dungeon is procedurally chunk-filled within zones (per `post-wave3-sequencing.md §1 Commitment 3 + SI-8`); there is no "true" cartographic layout to render.
- Hand-laid topology lets Uma compose the map for **readability**, not realism. Diablo II's Act 1 map is famously NOT to scale; it's drawn to read clearly.
- A procgen-cartographic shape would change between runs (per `post-wave3-sequencing.md §6 randomized maps per character`). The map's hand-laid topology stays stable while the chunk-fill inside each zone varies — the **structure** is hand-authored, the **content** is procgen.

**Composition rules:**

- Boss-room node is always at one end of the stratum's longest chain — the player should perceive it as "the deepest point."
- Hub-adjacency node (the zone the descent-portal drops into) is always at the top/entry side.
- Branches are encouraged (a 4-6 node stratum should have at least one branch, not be a pure linear chain) so the map reads as a place with choices, not a corridor.
- Node spacing: nodes should be at least 48 px apart on the rendered map so labels don't collide.

**Per-stratum map canvas size:** the parchment substrate fills a 360 × 240 px region inside the modal chrome (modal is 480 × 270 with 60 px of chrome on the left/right + 30 px top/bottom). Nodes laid on this canvas. Coordinates per node are part of `ZoneDef` (`ZoneDef.map_anchor: Vector2`).

---

## §5 — Interaction shape

### Open / close

- **Open:** the player opens the world-map by selecting a stratum from the descent-portal stratum-picker (per `hub-town-direction.md §4`). The picker transitions into the world-map for that stratum.
- **Close:** pressing **Esc** closes the world-map and returns to the stratum-picker (one level up). Pressing **Esc** again from the picker returns to hub-town (per the LIFO close-stack rule in `hub-town-direction.md §6`).
- **Direct hotkey from in-stratum (deferred to M4):** Sponsor may want an in-stratum "press M to open map" hotkey to see progress mid-run. M3 Tier 3 does NOT ship this — the map is accessible only between runs from hub-town. If Sponsor surfaces "I want to check the map mid-run" during M3 Tier 3 soak, it lands as an M4 enhancement.
- **Devon's key-binding call:** the open-from-portal action is the only path in M3 Tier 3. **Hotkey binding for M4 is recommended `M`** but Devon owns the final choice when M4 ticket lands.

### Hover

- **Hover a discovered/cleared zone:** the zone label brightens to 100% (if not already there); a small **zone-info tooltip** appears below the node showing the zone's name + (if cleared) the last-run-result hint pulled from save data ("S1 Eastern Reliquary · last run: cleared 4/4 rooms").
- **Hover an undiscovered zone:** nothing happens. The cursor does not change; no tooltip appears. The zone is not interactable.
- **Hover an edge:** no tooltip in M3 Tier 3. (M5 polish may add edge-state tooltips like "requires Brother Voll dialog complete.")

### Click / select

- **Click a cleared zone:** initiates fast-travel. The map fades out (0.3 s), the in-game scene loads the selected zone, and the player spawns at the zone's entry point. **Fast-travel is permitted only between cleared zones within the current stratum, OR from the hub-town-adjacency entry zone to ANY discovered (cleared-or-not) zone within the stratum** (this special-case rule preserves the "descend into the place I'm working on" flow — without it the player can never enter a not-yet-cleared zone via the map).
- **Click a discovered-not-cleared zone, with the player at hub-adjacency entry zone:** fast-travel as above (special case).
- **Click a discovered-not-cleared zone, with the player NOT at hub-adjacency:** disallowed. The cursor flashes a small `#3A3540` cell-empty-border outline around the clicked node + a soft UI tick; the click does not commit. The player must return to the hub-adjacency entry zone first.
- **Click an undiscovered zone:** does nothing (per hover rules).
- **Click an active-quest zone:** treated as a normal zone click — the active-quest stamp is a visual hint, not a click target.

### Scroll / zoom

- **M3 Tier 3 = single zoom level.** No mouse-wheel zoom; no pinch-zoom. The 360 × 240 px canvas fits the whole stratum.
- **M5 polish = multi-zoom** (deferred per §10). When multi-zoom lands, it adds a per-zone room-tree view (per `post-wave3-sequencing.md §3 M5 Track`) as pane 3.

### Default-selected node

When the map opens, the **default-selected node** is the player's last-visited zone within this stratum (from save field — see §7). The selected node has a 1 px ember-orange `#FF6A2A` outline drawn around its glyph + a slightly brighter label. Arrow keys (or WASD) move selection between adjacent nodes; **Enter** commits the click. This dual-input (mouse + keyboard) parallels the inventory panel's keyboard-cursor convention from `inventory-stats-panel.md`.

---

## §6 — Visual primitives + HTML5 safety

**The map is screen-space CanvasLayer, HUD-immune to scroll.** It sits above the in-game canvas during open, blocks input to the in-game scene, and processes its own input. This is the same architecture as the inventory-panel modal.

### Primitive choices (Drew-level discipline; Devon implements)

Cite `.claude/docs/html5-export.md` § Renderer when implementing — these are the load-bearing primitive calls.

1. **Modal background:** `ColorRect` filling the 480 × 270 canvas, `#1B1A1F` at 92% opacity. Reuses the inventory-panel chrome.
2. **Parchment substrate:** `TextureRect` showing a 360 × 240 parchment texture (see §9 asset list — one shared texture across all strata, OR one per stratum if Sponsor wants per-stratum subtle variation; recommended single shared texture for M3 Tier 3). Alternative: tiled `ColorRect` at `#D7C68F` parchment hex if the texture pipeline isn't ready. **Recommendation: ship the ColorRect fallback first; add PixelLab-generated parchment texture as a follow-up polish PR after Sponsor sees the M3 Tier 3 baseline.**
3. **Node markers:** plain `ColorRect` for circle approximations (a 12 × 12 ColorRect with corner-radius via `theme_override_constants/corner_radius_*` — Devon's call on whether to use 12 × 12 squares for genuine pixel-art readability OR a circular `TextureRect` with a 12-px circle texture). **NOT `Polygon2D`** per `.claude/docs/html5-export.md` § Polygon2D rendering quirks (PR #137 precedent). **Recommendation: 12 × 12 ColorRect squares for M3 Tier 3** — reads as honest pixel-art-map glyphs, matches hub-town visual language, zero risk of rendering quirks.
4. **Cleared-state X-cross:** two `ColorRect`-rotated-rect strokes per `.claude/docs/html5-export.md` rule. Each stroke 2 px wide × 10 px long, rotated ±45°, centered on the node marker. Color `#1B1A1F` panel-background hex (reads as dark ink on parchment node fill). **NOT a `✓` Unicode glyph** — the Godot 4.3 default font doesn't reliably cover U+2713 in HTML5 (per the default-font-glyph-coverage rule). Two rotated ColorRects render identically across all renderers AND read as an X-cross-tally, which fits the "the cloister keeps tallies" diegetic.
5. **Boss-room skull-crown glyph:** **placeholder for M3 Tier 3** — three rotated ColorRects forming a chunky "S" (top horizontal bar + middle horizontal bar + bottom horizontal bar approximating a skull silhouette) OR a small 16 × 16 PixelLab-authored sprite if the Sponsor PixelLab batch has capacity. **Recommendation: 16 × 16 PixelLab boss-icon sprite** (Sub-track 5a addition, ~1 generation). Color `#7A2A26` mob-HP-foreground hex. The placeholder ColorRect-stack is acceptable for M3 Tier 3 W2 ship-floor if PixelLab capacity is tight.
6. **Active-quest exclamation overlay:** a `Label` with text `!` in `#FF6A2A` ember-accent. `!` IS plain ASCII per `.claude/docs/html5-export.md` default-font-glyph-coverage rule (the rule restricts non-ASCII glyphs like `✓` / arrows / box-drawing; basic punctuation is safe). Animate via `modulate.a` tween on the Label — 4 fps pulse (70% → 100% → 90% → 80% loop).
7. **Edge rendering:** `Line2D` nodes (NOT `Polygon2D`). Per `.claude/docs/html5-export.md` § Shape OUTLINES — "When `_draw()` is overkill: a single straight outline ... is simpler as a `Line2D` with `width = N` — same primitive layer, equally renderer-safe." Each edge is a 2-px-wide `Line2D` between two node-anchor points, color `#1B1A1F`. Dashed gated-edges: `Line2D` does not natively support dashed strokes; **recommended approach** = decompose the edge into 4-6 short `Line2D` segments with gaps (compute at scene-load time from `ZoneDef.edges[].gate` boolean). Alternative: a `Node2D` subclass with `_draw()` + `draw_dashed_line()` if Godot 4.3 exposes it; verify support in Devon's W2 spike.
8. **Unlocked-edge ember glow (one-shot animation):** a second `Line2D` overlaid on the unlocked edge, same width, `#FF6A2A` ember color, with a `modulate.a` tween from 1.0 → 0.0 over 0.6 s, deleted after the tween completes. Single-shot; not a persistent layer.
9. **HDR-clamp discipline:** any tween peak color stays **sub-1.0 on every channel** per the HDR-clamp rule. The parchment hex `#D7C68F` is already sub-1.0 (`0.843, 0.776, 0.561`); ember accent `#FF6A2A` is the only saturated hex at 1.0 on the R channel — modulate-tween targets that use ember should pin at `Color(0.97, 0.42, 0.16)` peaks, never `Color(1.0, X, X)`. PR #137 precedent.
10. **z_index discipline:** modal lives on a `CanvasLayer` (independent of world z-stack). Within the modal, parchment substrate at `z_index = 0`, edges at `z_index = 1`, nodes at `z_index = 2`, glyph overlays at `z_index = 3`, ember-stamp overlay at `z_index = 4`, hover-tooltips at `z_index = 5`. **NO negative z_index anywhere** per `.claude/docs/html5-export.md` (PR #137 precedent — `gl_compatibility` sinks negative z below room background).
11. **No CPUParticles2D required.** The active-quest stamp pulse is a modulate-tween on a Label, not a particle emitter. The unlocked-edge glow is a Line2D tween, not a burst. The entire surface is composed of ColorRect / Label / Line2D / TextureRect primitives — the **lowest-risk HTML5 surface** in the project apart from pure-text panels.

### Visual-verification gate consequence

Per `.claude/docs/html5-export.md` § HTML5 visual-verification gate: the map's primitive set (ColorRect + Label + Line2D + TextureRect + modulate-tween) is **standard low-risk visual-primitive class**. The gate still applies — Devon's Self-Test Report on the W2 PR includes HTML5 release-build screenshots showing the map opens, renders parchment, renders nodes, renders the active-quest pulse — but the gate is "standard," not "load-bearing animation analysis." If Sponsor's M3 Tier 3 soak finds the map renders correctly on HTML5, that signal generalizes for future map iterations.

---

## §7 — Animation feel

Match the existing UI tone (per `hud.md` + `inventory-stats-panel.md` + `visual-direction.md` 12 fps animation pace).

| Beat | Duration | Curve | Notes |
|---|---|---|---|
| **Modal open** (stratum-picker → world-map) | 0.2 s | ease-out quadratic | Parchment substrate fades in from 0 → 100%; nodes + edges + labels fade in over the same 0.2 s. Reuses the inventory-panel modal open cadence. |
| **Modal close** (world-map → stratum-picker, or → hub-town) | 0.2 s | ease-in quadratic | Reverse of open. |
| **Newly-unlocked zone fade-in** | 0.3 s | ease-in-out cubic | When a zone transitions Undiscovered → Discovered (player just walked into it for the first time), the node marker + label fade in over 0.3 s on the next map-open. **The fade happens once per state-change, NOT on every map-open thereafter.** Save-state tracks the "recently-unlocked, not yet displayed" flag — see §7 save-state below. |
| **Newly-cleared zone glyph swap** | 0.3 s | ease-in-out cubic | When a zone transitions Discovered → Cleared, the State-2 hollow-circle marker tweens into the State-3 X-cross marker via crossfade (the hollow circle fades 100% → 0% as the X-cross fades 0% → 100% simultaneously). Same one-shot semantics as the newly-unlocked fade. |
| **Newly-unlocked edge glow** | 0.6 s | ease-out cubic | The one-shot ember-orange glow described in §6 primitive 8. |
| **Active-quest stamp pulse** | 1.0 s loop | linear (4-frame stepped modulate) | Continuous as long as the stamp is on a node. 4-frame cadence at 4 fps — opacity 70% / 100% / 90% / 80% / repeat. Reuses brazier-pulse cadence convention. |
| **Hover-tooltip fade-in** | 0.15 s | ease-out quadratic | Fast; doesn't slow the read. |
| **Hover-tooltip fade-out** | 0.10 s | ease-in quadratic | Faster on out; the player should feel responsive. |
| **Disallowed-click flash** | 0.30 s | ease-in-out quadratic | The `#3A3540` outline around an illegal-click target fades in 0 → 100% then back to 0 over 0.30 s total; UI tick sound fires at peak. |
| **Fast-travel scene fade-out** | 0.3 s | ease-in cubic | Map → loading. The parchment + chrome fade out together. The receiving zone's scene fade-in is governed by Drew's scene-load convention. |

**Cadence reuse:** the 12 fps animation pace from `visual-direction.md` applies to any per-frame anim (the active-quest pulse). Tween-based animations (open/close/glow) run on continuous time, not stepped — same pattern as the inventory panel.

**HTML5-safe modulate targets:** all the listed tweens use `modulate` or `modulate.a` on screen-space Control nodes (CanvasLayer-parented). Per `.claude/docs/html5-export.md`, `modulate` on UI Control nodes is a known-safe path — same primitive class as the inventory hit-flash. Stays sub-1.0 on every channel.

---

## §8 — Save-state implications

Two additions to the save schema (additive only; layers on top of `hub-town-direction.md §7` fields):

```
data.characters[N]:
  world_map_discovered_zones: Dictionary<int, Array<String>>
      # key = stratum index (1, 2, ...)
      # value = list of zone-IDs the character has discovered in that stratum
  world_map_cleared_zones: Dictionary<int, Array<String>>
      # key = stratum index
      # value = list of zone-IDs cleared
  world_map_last_visited_zone: Dictionary<int, String>
      # key = stratum index
      # value = the zone-ID the player last entered in that stratum (default-selection on map open)
  world_map_pending_state_animations: Array<Dictionary>
      # transient queue of "show me the fade-in next time the map opens" events
      # populated on zone-state changes; consumed (cleared) on map-render completion
      # each entry: { stratum_id: int, zone_id: String, type: "newly_discovered" | "newly_cleared" | "edge_unlocked", edge_pair: [from_id, to_id] (only for edge_unlocked) }
```

All four fields are **per-character** (live under `characters[N]` in v5+). New character → all empty.

**Devon's implementation surface (W2):**

- `Save.gd` migration v(N) → v(N+1) adds the four fields with empty defaults.
- `WorldMap.gd` reads all four fields on `_ready`, renders the appropriate state, then on `_exit_tree` clears `world_map_pending_state_animations` for entries that have been shown.
- Zone-state transitions (discovered, cleared, edge unlock) are fired by Drew's `ZoneDef` runtime, which calls into `WorldMap.queue_pending_animation(...)` to enqueue the next-open fade.
- The data shape uses `Dictionary<int, Array<String>>` rather than per-stratum dedicated fields so adding S3-S8 in M5 requires zero schema-bumps — only data fills in the existing keys.

**Cross-stratum continuity:** the four fields persist across descents-and-deaths-and-respawns. Once a zone is discovered, it stays discovered. Once cleared, stays cleared. This is per the Diablo-II model — map state is character-persistent, not run-ephemeral.

---

## §9 — Asset list (consolidated)

| Category | Count | Items |
|---|---|---|
| New textures | 1 (deferrable to follow-up polish PR) | `assets/ui/world-map/parchment-substrate.png` 360 × 240, single shared across all strata. **PixelLab-generated** per §6 primitive 2; see PixelLab prompt template below. ColorRect fallback acceptable for M3 Tier 3 W2 ship-floor. |
| New sprite glyphs | 1 (deferrable to follow-up polish PR) | `assets/ui/world-map/boss-room-glyph.png` 16 × 16, the skull-crown. **PixelLab-generated** per §6 primitive 5. Three-ColorRect-stack placeholder acceptable for M3 Tier 3 W2 ship-floor. |
| New scenes | 1 | `scenes/ui/WorldMap.tscn` — the map modal. Owns parchment substrate, edge layer, node layer, glyph overlay layer, hover-tooltip layer, ember-stamp layer. **Devon's W2 ticket per `post-wave3-sequencing.md §5`.** |
| New scripts | 1 | `scripts/ui/WorldMap.gd` — reads `ZoneDef`s + save-state fields, lays out nodes per `ZoneDef.map_anchor`, handles input, fires fast-travel signals to `Main.gd`. |
| Reused UI hexes | 6 | `#D7C68F` parchment, `#1B1A1F` panel background / ink, `#E8E4D6` HUD body text, `#FF6A2A` ember accent, `#7A2A26` mob HP foreground (boss-room glyph), `#3A3540` cell-empty-border (illegal-click flash). **All in `palette.md` already** — no palette additions. |
| Reused anim cadences | 3 | 12 fps stepped modulate (active-quest pulse), 0.2 s ease (modal open/close), 0.3 s ease-in-out cubic (state-transition fade). Standard inventory/HUD cadences. |
| Save-state additions | 4 fields | Per §8. Devon owns the migration. |
| Tile-reuse anchors | 0 | The map surface uses no tilemap. All composed of UI Control primitives. |
| **Total new authoring** | **2 PixelLab generations + 1 scene + 1 script** | The cheapest M3 Tier 3 surface by design. |

### PixelLab prompt template (parchment-substrate texture)

If Sponsor wants the texture pipeline path (recommended polish PR after M3 Tier 3 W2 baseline), per `.claude/docs/pixellab-pipeline.md` conventions:

```
mcp__pixellab__create_character(
    description="aged parchment scroll texture, hand-drawn ink lines suggesting cartographic compass-rose and faint terrain hints, warm cream-brown #D7C68F dominant tone with subtle darker brown stains and creases #5C4F38, single-piece scroll laid flat, no characters or figures, no border, no text, top-down camera",
    body_type="prop",
    template="static-prop",
    size=64,
    n_directions=1
)
# Then crop-and-tile in pixel-mcp per the standard pipeline.
# Tile the 64×64 output across the 360×240 map canvas if seamless; otherwise
# generate 360×240 directly (PixelLab's canvas-size trap: actual canvas is
# ~size × 1.4 — verify dimensions with get_sprite_info post-import; crop_sprite
# to 360×240 with the parchment region centered).
```

**Doctrine-lock note:** the parchment substrate is **doctrine-exempt** per `palette.md` (it's a UI surface, not a stratum-bound environment asset). Ship PixelLab raw OR with a minimal `quantize_palette` to the parchment + dark-brown pair. Do NOT run the S1 doctrine-lock pipeline on it — that would map the parchment to S1 floor `#7A6A4F`, which is the wrong hex for UI parchment.

### PixelLab prompt template (boss-room glyph 16 × 16)

```
mcp__pixellab__create_character(
    description="tiny pixel-art skull-and-crown icon for a fantasy map marker, dark red #7A2A26 skull silhouette with simple crown on top, dark outline #1B1A1F, ink-on-parchment aesthetic, isolated icon on transparent background, head-on facing camera, prominent silhouette",
    body_type="prop",
    template="static-prop",
    size=16,
    n_directions=1
)
# 16-px target may produce a blob per pixel-mcp-pipeline.md dimension-floor rule;
# if so, bump to size=24, then crop_sprite to 16×16 centered.
```

---

## §10 — Future-defer items (M5 polish, NOT M3 Tier 3)

Explicitly out of scope. Logged here so Devon's W2 dispatch doesn't accidentally land them, and M5 planning can pick them up directly:

1. **Multi-zoom + per-zone room-tree (pane 3).** Per `post-wave3-sequencing.md §3 M5` and `§1 Commitment 4`. Adds mouse-wheel zoom + a third pane showing a tree of rooms within a clicked zone. **M5 polish.**
2. **Animated zone-state transitions beyond newly-unlocked / newly-cleared one-shot fades.** E.g., "pulsing glow on the active-quest zone" beyond the simple `!` stamp pulse. M3 Tier 3 stays minimal; M5 may add aesthetic flourishes.
3. **Fog-of-war shape variations.** Currently undiscovered = invisible. M5 could add "silhouette of the zone outline, not the marker" as an intermediate fog-of-war state ("the monks have heard rumors of this place"). Not in M3 Tier 3.
4. **Lore-tooltip-on-hover** ("Eastern Reliquary: the original cloister's bone-ossuary, abandoned 200 years before the seam was found"). Adds Diablo-IV-style lore depth. M5 narrative pass.
5. **Cross-stratum waypoint travel from the map.** Currently fast-travel is within-stratum only. M5 may add "fast-travel from S1 Eastern Reliquary directly to S2 Stoker's Forge" if both are cleared. M3 Tier 3 forces the hub-town round-trip.
6. **In-stratum hotkey ("press M during a run to see progress").** Per §5 — deferred to M4 if Sponsor surfaces the need during soak.
7. **Stratum-comparison view (show all strata side-by-side).** Sponsor rejected this at SI-3 as the (b) Diablo-IV alternative; M5 polish does NOT lift it back in — it stays rejected. Logged here to remind future M5 planning.
8. **Animated parchment unfurl on map-open.** A 0.6 s "scroll unrolls" anim would be tonally perfect but requires either a multi-frame texture animation OR a clipping-mask animation. Both are achievable but add 1-2 days of authoring. M5 polish if Sponsor likes the baseline.
9. **Per-zone "what's inside" preview on hover** (e.g., "this zone has 3 rooms, 1 NPC, 8 mob spawns"). Useful for player planning; not load-bearing for M3 Tier 3 ship-floor. M4 or M5.
10. **Map-state visibility to NPC dialog** (e.g., a monk's dialog reflects which zones the player has discovered). Cross-system integration; M4 dialog-content authoring picks up.

---

## §11 — Tester checklist for Tess (M3 Tier 3 acceptance)

Per `team/TESTING_BAR.md`. Acceptance rows for the world-map surface; locks at Devon's W2 PR landing.

| ID | Check | Pass |
|---|---|---|
| WM-01 | World-map opens from descent-portal stratum-picker (pick S1 → map for S1 opens) | yes |
| WM-02 | World-map is a screen-space modal (CanvasLayer; HUD/world-stack does NOT bleed through input) | yes |
| WM-03 | Modal background is `#1B1A1F` at 92% opacity (matches inventory-panel chrome) | yes |
| WM-04 | Parchment substrate fills the 360 × 240 canvas region with the parchment hex `#D7C68F` (or PixelLab texture if polished) | yes |
| WM-05 | 4-6 zone nodes visible at expected positions (per `ZoneDef.map_anchor`) | yes |
| WM-06 | Undiscovered zones: no marker drawn at the position; substrate visible through | yes |
| WM-07 | Discovered-not-cleared zones: hollow-circle 12 × 12 marker at 50% opacity + label at 70% | yes |
| WM-08 | Cleared zones: filled-marker + X-cross drawn from two rotated 2×10 px ColorRect strokes (NOT `✓` Unicode) | yes |
| WM-09 | Boss-room nodes: skull-crown glyph (PixelLab sprite OR placeholder ColorRect stack) in `#7A2A26` | yes |
| WM-10 | Boss cleared: skull-crown glyph composes with X-cross overlay | yes |
| WM-11 | Active-quest stamp: ember-orange `!` Label with 4 fps pulse (70% / 100% / 90% / 80% loop) on the active zone | yes |
| WM-12 | Active-quest stamp is single-instance (only one node shows the `!` at a time per stratum map) | yes |
| WM-13 | Edges drawn as 2-px Line2D in `#1B1A1F`; gated edges decomposed to dashed segments | yes |
| WM-14 | Newly-unlocked edge: 0.6 s ember-orange `#FF6A2A` glow tween one-shot on first map-open after unlock, then never replays | yes |
| WM-15 | Click a cleared zone → fast-travels (map fades out 0.3 s, zone loads, player spawns at zone entry) | yes |
| WM-16 | Click an undiscovered zone → does nothing (no flash, no tooltip, no commit) | yes |
| WM-17 | Click a discovered-not-cleared zone NOT from hub-adjacency → `#3A3540` outline flashes, UI tick fires, no commit | yes |
| WM-18 | Esc closes the map → returns to stratum-picker | yes |
| WM-19 | Default-selected node on open = `world_map_last_visited_zone[current_stratum]` (or hub-adjacency if empty) | yes |
| WM-20 | Arrow keys / WASD move selection between adjacent nodes; Enter commits the click | yes |
| WM-21 | Hover-tooltip on discovered/cleared zones: name + last-run hint; 0.15 s fade-in | yes |
| WM-22 | Hover-tooltip does NOT appear on undiscovered zones | yes |
| WM-23 | Save fields `world_map_discovered_zones` + `world_map_cleared_zones` + `world_map_last_visited_zone` + `world_map_pending_state_animations` persist across descent / death / restart | yes |
| WM-24 | Migration from v(N) → v(N+1) initializes all four fields to empty/default; no data loss | yes |
| WM-25 | HTML5 release-build: parchment + nodes + edges + active-quest pulse render correctly (visual-verification gate) | yes |
| WM-26 | HTML5 release-build: no `USER WARNING:` or `USER ERROR:` console lines on map-open / map-close / fast-travel | yes |
| WM-27 | All tween peak colors are sub-1.0 on every channel (HDR-clamp compliance, eye-dropper spot-check) | yes |
| WM-28 | No `Polygon2D` in the WorldMap scene (`grep -r Polygon2D scenes/ui/WorldMap.tscn` returns nothing) | yes |
| WM-29 | No `CPUParticles2D` in the WorldMap scene | yes |
| WM-30 | No negative `z_index` on any WorldMap child node | yes |

---

## §12 — Sponsor-input items + redirect windows

Per `m3-design-seeds.md` defaults and `post-wave3-sequencing.md §6 SI-3` lock, this doc authors against the recommended call shape. **No Sponsor escalation needed at PR-merge time** — but the redirect window is open until Devon's W2 dispatch.

### Defaults locked in this doc (within Uma's delegated authority)

1. **Modal scope:** per-stratum maps, NOT global overworld. Per SI-3 lock; this doc renders the choice.
2. **Visual style:** parchment-substrate + ink-line edges + small-pixel-art node glyphs. The "Diablo-II Act 1" tonal pick.
3. **Node count target:** 4-6 zones per stratum for M3 Tier 3 (S1 + S2).
4. **Four discovery states + active-quest overlay.** Defined in §3.
5. **Boss-room glyph:** skull-crown in `#7A2A26`. NOT ember-orange (ember-orange reserved for active-quest stamping).
6. **Active-quest stamp pulse:** 4 fps stepped modulate matching the brazier-pulse cadence (cross-surface consistency).
7. **Single zoom level.** Multi-zoom is M5.
8. **Fast-travel scope:** cleared zones within the current stratum + special-case hub-adjacency → any discovered zone in stratum.
9. **Open path:** from the descent-portal stratum-picker only; no in-stratum hotkey (M3 Tier 3). M4 may add hotkey.
10. **PixelLab parchment + boss-room glyph:** **DEFERRABLE follow-up polish PR** after M3 Tier 3 W2 ship-floor. The ColorRect-fallback path ships first; PixelLab textures polish second. Sponsor decides whether to spend the ~2 generations on the polish during the M3 Tier 3 PixelLab batch.

### Sponsor-redirect candidates (Uma flags for Sponsor review at this doc's PR merge)

1. **Parchment-vs-stone substrate.** Recommended: parchment `#D7C68F`. Sponsor alternative: dark cloister-stone `#4A3F2E` with ember-line carvings (the map AS a stone-carved relief in the cloister wall). Tonally heavier; visually riskier (high-contrast carved-line aesthetic is harder to land at 480×270). **Recommend parchment.** Sponsor can redirect at PR merge.
2. **Single shared parchment texture vs per-stratum substrate variation.** Recommended: single shared (cheapest; parchment IS parchment). Alternative: per-stratum substrate variants (S1 = clean parchment, S2 = soot-marked parchment showing the cinder vaults). Adds 7 generations (one per future stratum). **Recommend single shared.** Sponsor can redirect during the PixelLab batch.
3. **Edge gating visibility.** Recommended: dashed-line until gate clears, then upgrade to solid. Alternative: gated edges drawn as `#1B1A1F` ink at 30% opacity instead of dashed. Dashed reads as "this exists but is locked"; opacity-only reads as "this is faint." **Recommend dashed.** Sponsor can redirect at PR merge.
4. **Active-quest stamp animation speed.** Recommended: 4 fps stepped pulse (matches brazier). Alternative: smooth 1 Hz continuous tween (more elegant, slightly more processor work, slightly less "pixel-art honest"). **Recommend stepped pulse.** Sponsor can redirect at PR merge.
5. **Disallowed-click feedback.** Recommended: `#3A3540` outline flash + UI tick sound. Alternative: brief modulate flash of the whole map to `#3A3540` (more dramatic). **Recommend outline flash** (less disruptive). Sponsor can redirect at PR merge.

### Items deferred to v1.1 (post-Sponsor-review)

1. **Zone-name typography.** Default = HUD body text `#E8E4D6` at the standard 12 px size. Open question: should zone labels use a slightly larger font or a different weight to feel "map-like" rather than "panel-like"? **Recommend: stay with HUD body text for M3 Tier 3.** Devon's call on whether to add a Map-specific font size during W2; if added, v1.1 amendment to this doc.
2. **PixelLab parchment-substrate generation timing.** Sub-track 5a's PixelLab batch is the candidate slot. If batch capacity is tight, ship the ColorRect-fallback for M3 Tier 3 W2 and run the polish PR after. **Recommend: defer the PixelLab gen unless Sub-track 5a has clear capacity.** Sponsor decides at PixelLab-batch dispatch time.

### Redirect window timing

- **At PR-merge time (this doc landing on main):** Sponsor reviews the direction doc; redirect window open for: substrate hex (parchment vs stone), per-stratum substrate variation, edge gating visibility, active-quest pulse cadence, disallowed-click feedback shape. No Sponsor escalation routed by orchestrator — Sponsor reviews the merged doc.
- **At Devon's W2 dispatch:** Devon consumes this doc as authored. If Sponsor wants a redirect between merge-time and W2 dispatch, v1.1 amendment to this doc + DECISIONS.md entry per `team/DECISIONS.md` cadence.
- **At Devon's W2 PR-merge time:** Sponsor soaks the implementation. Redirect window open for: anything visible in-engine that doesn't match the spec.

---

## Cross-references

- **`team/uma-ux/hub-town-direction.md` §4** — descent-portal stratum-picker (the chain entry into the map).
- **`team/uma-ux/palette.md`** — Outer Cloister parchment `#D7C68F`, ember `#FF6A2A`, panel-background `#1B1A1F`, HUD body text `#E8E4D6`, mob HP foreground `#7A2A26`, cell-empty-border `#3A3540`. No new hexes needed.
- **`team/uma-ux/hud.md`** — parchment family + modal chrome conventions inherited.
- **`team/uma-ux/visual-direction.md`** — 480×270 canvas, 12 fps animation pace.
- **`team/uma-ux/inventory-stats-panel.md`** — modal chrome + keyboard-cursor conventions inherited.
- **`team/priya-pl/post-wave3-sequencing.md` §1 Commitment 4 + §6 SI-3** — Sponsor's lock that authorizes this doc.
- **`.claude/docs/html5-export.md`** — HDR clamp, Polygon2D rule, z_index rule, default-font-glyph-coverage rule. Cited in §6.
- **`.claude/docs/pixellab-pipeline.md`** — PixelLab tool sequence + canvas-size trap; cited in §9 PixelLab prompt templates.
- **Drew (M3 Tier 3 W1 Track 3):** `ZoneDef` schema extension to `level-chunks.md`. This doc consumes the schema (`ZoneDef.map_anchor`, `ZoneDef.cleared_condition`, `ZoneDef.edges[].gate`); Drew owns the schema lock.
- **Devon (M3 Tier 3 W2 Track 4):** `WorldMap.tscn` + `WorldMap.gd` impl + save-state migration. This doc is Devon's W2 input.

---

## Non-obvious findings

1. **The map's biggest tonal risk is "feeling like a UI HUD"** rather than "feeling like a parchment scroll." The defense is **substrate texture + ink-line edges + small-pixel-art node glyphs** all in concert; missing any one of the three lets the map slip back into screen-space-HUD territory. Devon's W2 ship-floor MAY be the ColorRect-fallback parchment, but the polish PR with the PixelLab texture is what locks the tone.
2. **The four discovery states need to compose with the active-quest stamp orthogonally, NOT replace each other.** A common pitfall is treating "active quest" as a fifth state; the right framing is state + stamp (state is the discovery progression; stamp is the player's current task). The composition rules in §3 are load-bearing.
3. **Diablo-II's per-act map is famously NOT to scale** — Drew + Uma should compose the per-stratum topology for **readability**, not realism. The procgen-chunk-fill inside zones makes any pretense of cartographic fidelity meaningless; embrace the hand-laid topology.
4. **The boss-room glyph color choice (`#7A2A26` mob HP foreground, NOT `#FF6A2A` ember)** is a load-bearing tonal call. Ember-orange is reserved for the player's task-marker; using ember on the boss-room would conflate "the player's current task" with "where the boss lives." Mob-HP-foreground reads as "the enemy lives here," which is the right diegetic frame.
5. **The default-font-glyph coverage rule bites the cleared-state X-cross.** A natural first design is `✓` Unicode; that rendering-fails as tofu in HTML5 per the rule. Two rotated ColorRect strokes is the safe + diegetically-correct fix (the cloister keeps tallies, not check-marks).
6. **The PixelLab parchment texture is the easiest "polish later" decision in the project so far.** ColorRect-fallback ships M3 Tier 3 W2 in 0 generations; polish PR adds 1-2 generations + ~30 min of pipeline work. Sponsor can decide based on M3 Tier 3 W2 soak — if the ColorRect fallback reads convincingly, the polish PR is optional.
