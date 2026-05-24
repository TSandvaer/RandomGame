# feat(ui): world-map UI minimal — Diablo-II per-act parchment map (W2-T5)

**Ticket:** [`86c9y10fv`](https://app.clickup.com/t/86c9y10fv) — M3 Tier 3 W2-T5
**Direction:** [`team/uma-ux/world-map-direction.md`](../uma-ux/world-map-direction.md) (Uma W1 / PR #308)
**Save shape:** [`team/devon-dev/save-schema-v5-tier3-additions.md`](save-schema-v5-tier3-additions.md) §2.2 + §2.3

## Summary

Minimal world-map UI panel + discovery state + descent-portal integration per Uma's per-act parchment-map direction. Ship-floor scope: panel renders the shipped S1 zone and its lock state, the descent screen exposes an "Open Map" affordance, and zone-discovery state round-trips through the save schema.

## What lands

### Part A — `WorldMapPanel` (scenes/ui/WorldMapPanel.tscn + scripts/ui/WorldMapPanel.gd)
- CanvasLayer + `PANEL_LAYER = 70` (between InventoryPanel 80 and DialoguePanel 90 — verified against `.claude/docs/dialogue-system.md` §"CanvasLayer + PANEL_LAYER ordering").
- Parchment substrate is a **ColorRect** (`#D7C68F`); modal chrome is a **ColorRect** at `#1B1A1F` 92%; header / close hint / stratum-list / zone-list panes are **Labels + Buttons + VBoxContainers**. **No Polygon2D / CPUParticles2D / negative z_index** per `.claude/docs/html5-export.md` § Renderer rules.
- Zone-state markers rendered as **geometry primitives**, NOT Unicode glyphs:
  - Undiscovered = muted slate square (`#3A363D`).
  - Discovered = parchment square + 4 ink-edge ColorRect outline (`#1B1A1F`, 1px each).
  - Cleared = above + two rotated ColorRect strokes forming an X-cross (NOT `✓` U+2713; per `html5-export.md` § "Default-font glyph coverage" + Uma direction §6 primitive 4).
  - Boss room = `#7A2A26` mob-HP-foreground (NOT ember orange; ember is reserved for the future quest-target stamp).
- Stratum-list pane lists S1..deepest_stratum. Locked strata render in `#3A363D` slate + `Button.disabled = true`.
- All channel modulate targets ≤ 1.0 (HDR-clamp safe).

### Part B — Player save-state hooks
- `Player.discovered_zones: Dictionary` (per-character, keyed by `ZoneDef.zone_id: StringName`).
- `Player.discovered_waypoints: Dictionary` (per-character, M4 expansion deferred — field shipped with minimal consumer).
- `Player.to_save_dict()` extended: serialises both dicts as JSON-safe `Dictionary[String, bool]` (StringName keys stringified via new `_stringify_dict_keys` static helper).
- `Player.restore_from_save_dict()` extended: normalises String keys back to StringName via new `_normalise_dict_keys_to_stringname` static helper.
- `Player.mark_zone_discovered(zone_id)` / `mark_waypoint_discovered(waypoint_id)` — idempotent setters returning `true` on new discovery, `false` on re-entry.
- `Save._backfill_v5_tier3_quest_fields()` extended: same `has()`-guard additive pattern adds defaults `{}` for both new fields. **No schema bump** — rides additively on v5 per `save-schema-v5-tier3-additions.md §5`.
- `Save.DEFAULT_PAYLOAD["character"]` extended with the two new fields at empty defaults.

### Part C — DescendScreen integration (scripts/screens/DescendScreen.gd)
- **"Open Map" button** added to the descend screen above the "Return to Stratum 1" button (read-order: see map → choose to return).
- Lazy-loads `WorldMapPanel.tscn` on click; on the panel's `close_requested` signal the host frees the instance and refocuses the return button.
- Panel mounted as a sibling of DescendScreen (via `get_tree().root.add_child`) so its `layer=70` renders **between** the world (layer 0) and DescendScreen's own `layer=100` — return-to-stratum-1 stays the dominant affordance.
- `DescendScreen._exit_tree` cleans up an orphan map panel if DescendScreen itself is freed mid-open.

### Part D — Discovery write hook (scenes/Main.gd)
- New `ROOM_INDEX_TO_ZONE_ID` const array maps each S1 room index to `&"s1_z1_outer_cloister"` (the W2-T3 retrofit ships one zone covering the full S1 narrative arc).
- `Main._load_room_at_index(index)` calls `_mark_zone_discovered_for_room_index(index)` after wiring room signals.
- Fires `[combat-trace] Main.discover_zone | zone_id=<id> new=<bool>` — HTML5-only via the existing combat-trace shim. New=true on first entry, new=false on re-entry. Distinguished trace shape so Playwright + Sponsor soak can verify the hook empirically.
- Forward-compat: when W2-T3 procgen impl swaps `ROOM_SCENE_PATHS` traversal for `AssembledFloor` consumption, the lookup migrates to `AssembledFloor.zone_id`.

**Cross-lane integration check (PR #216 gate):**
- Adjacent integration surface: `Main._persist_to_save` + `Main._load_save_or_defaults` now call `Player.to_save_dict` / `restore_from_save_dict` to round-trip the new fields. This closes a pre-existing gap from PR #352 where the W2-T6 `active_bounty` / `completed_bounties` methods existed but weren't wired into Main's save path. **In-scope side benefit:** quest-state now round-trips end-to-end too.
- Adjacent surface: `s2_*` ZoneDef shells (just landed via PR #360) — my panel's DirAccess scan picks them up automatically, groups by `stratum_id=2`, and renders them under the locked Stratum-2 row.

### Part E — Paired tests

**GUT (4 new files / 23 tests):**
- `tests/test_world_map_panel_renders_stratum_list.gd` (8 tests) — panel instantiation, header render, stratum-list ≥1 row, zone-list renders shipped S1 zone, per-state marker composition, locked-stratum button disabled, cleared-state X-cross strokes, Esc-close signal.
- `tests/test_world_map_panel_geometry_glyphs_no_unicode.gd` (3 tests) — **structural regression-guard** walking every Label / Button / RichTextLabel under the panel asserting every text codepoint ≤127 (no non-ASCII). Covers initial render + discovered-state + cleared-state.
- `tests/test_discovered_zones_persists.gd` (9 tests) — Player.to_save_dict stringifies StringName keys, restore_from_save_dict normalises back, full round-trip preserves dict set, mark_zone_discovered idempotence, Save.gd backfill defaults to `{}`, backfill preserves existing fields, full save→migrate→restore round-trip.

**Playwright (1 new spec):**
- `tests/playwright/specs/world-map-panel-render.spec.ts` — HTML5 boot smoke. Asserts: Main-ready sentinel fires, no WorldMapPanel warnings, no scripts/ui|screens|save|player parser errors, no zone-fixture load failures, and the discovery hook trace `[combat-trace] Main.discover_zone | zone_id=s1_z1_outer_cloister new=true` empirically fires on first room load.

## Regression-guard (PR #216 gate)

| Bug class | Test that catches it |
|---|---|
| WorldMapPanel reverts to `✓` Unicode glyph for cleared marker | `test_world_map_panel_geometry_glyphs_no_unicode.gd::test_no_label_carries_non_ascii_glyph_with_cleared_stratum` |
| Future refactor uses Polygon2D for any marker shape | `test_discovered_zone_marker_has_outline_and_parchment_base` asserts `MarkerBase is ColorRect` |
| Discovery hook silently disconnects (zone-load fires but write never reaches Player) | Playwright spec asserts `[combat-trace] Main.discover_zone new=true` empirically; GUT `test_mark_zone_discovered_first_call_returns_true` pins the Player-side method behaviour |
| Save backfill drops or overwrites in-flight discovered_zones | `test_save_backfill_preserves_existing_discovered_zones` |
| `to_save_dict` / `restore_from_save_dict` lose StringName key normalisation | `test_round_trip_preserves_discovered_zones_set` walks both halves |
| Tier-3-naive v5 save crashes on missing `discovered_zones` key | `test_save_backfill_defaults_discovered_zones_to_empty_dict` |
| Locked-stratum button becomes clickable (cheat-unlock regression) | `test_locked_stratum_button_is_disabled` |

## Cross-references

- [`team/uma-ux/world-map-direction.md`](../uma-ux/world-map-direction.md) — Uma W1 direction doc (PR #308). My panel renders per §2 (visual shape), §3 (zone states), §6 (HTML5 primitives), §11 (tester checklist HT-01..HT-30 — many apply).
- [`team/uma-ux/hub-town-direction.md`](../uma-ux/hub-town-direction.md) §4 — descent-portal embryo. Open-Map affordance lives on DescendScreen until W3 hub-town impl moves the portal into hub-town.
- [`.claude/docs/html5-export.md`](../../.claude/docs/html5-export.md) § "Default-font glyph coverage" — extended PR #308 world-map direction scope. Pinned structurally by Part E geometry-glyph test.
- [`.claude/docs/dialogue-system.md`](../../.claude/docs/dialogue-system.md) § "CanvasLayer + PANEL_LAYER ordering" — PANEL_LAYER=70 verified against the established layer stack.
- [`team/devon-dev/save-schema-v5-tier3-additions.md`](save-schema-v5-tier3-additions.md) §2.2 + §2.3 — authoritative shape lock for both new fields.
- ClickUp [`86c9xubkj`](https://app.clickup.com/t/86c9xubkj) (W1 world-map direction, merged) + [`86c9xuap4`](https://app.clickup.com/t/86c9xuap4) (W1 ZoneDef spike, merged) — hard dependencies.

## Doc updates

Append to `team/uma-ux/world-map-direction.md` § "W2 minimal impl notes — production wiring + zone-state geometry primitives" (committed alongside this PR).
