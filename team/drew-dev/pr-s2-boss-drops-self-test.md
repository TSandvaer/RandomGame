## Self-Test Report — s2_boss_drops.tres (ticket 86ca1m0e6)

### Surface classification

**Content-only `.tres` data change** (loot table + a mob-def ExtResource re-point) + a paired GUT test. No GDScript changes, no scene changes, no Tween/modulate/Polygon2D/CPUParticles2D/Area2D-state code.

### GUT — local headless (Godot 4.3.0, GUT 9.3.0)

New test `tests/test_s2_boss_drops.gd`: **6/6 passed, 2660 asserts, 0.318s.**

Regression set `test_archive_sentinel.gd` + `test_boss_loot_integration.gd` + `test_loot_affix_integration.gd` + `test_save_restore_resolver_ready.gd`: **80/80 passed, 508 asserts.** (Orphan/resource-leak-at-exit notices are pre-existing GUT-harness noise from the Main.tscn-instantiating boss-loot integration suite — present on main, not introduced here.)

CI run-id / SHA cited in the final report once CI completes on the pushed HEAD.

### HTML5 visual-verification gate — escape-clause routing

Per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate" + the escape-clause:

- **No rendered primitive is introduced or changed by this PR.** The change is loot-table DATA: which item id + tier_modifier the Archive Sentinel rolls on death. The downstream `Pickup` rendering, drop ring layout, and `MobLootSpawner` pipeline are all unchanged (PR #376 wiring). There is no new ColorRect / Tween / modulate / particle / Area2D-monitoring surface.
- **The only user-visible consequence is WHICH items land on the floor** when the S2 boss dies (now T3 sword + T3 vest instead of T3 sword + T2 vest). That difference is data, not rendering — invisible to the `gl_compatibility` divergence classes the gate guards against.
- **Author HTML5 self-soak:** reaching the live S2 boss death requires interactive traversal (descend → S2 zones → ArchiveSentinel kill); this is a CLI-agent-unsoakable late-game surface (per `test-conventions.md` § "CLI-agent unsoakable surfaces"). Honest disclosure: I did not interactively soak the live drop in a browser. The mechanical correctness (table loads, rolls valid T3 drops, registered affixes, no warning) is fully covered by GUT; the rendering path is unchanged from the already-shipped S1/S2 boss-loot pipeline.
- **Routing:** this is data-only with an unchanged render path → GUT + the existing boss-loot Playwright/integration coverage own correctness. No Sponsor visual gate needed for the data swap itself. If desired, a Sponsor soak probe target is simply: "kill the Archive Sentinel, confirm two pickups land + both are collectable" — but that exercises the unchanged PR #376 pipeline, not new code.

### Playwright e2e

No Playwright-covered surface changed (no scene/script/spec edit; the loot-table DATA swap does not alter any traced `[combat-trace]` line or DOM/canvas behavior). Will cite the auto-fired run verdict (green / red-but-pre-existing) in the final report after CI.

### Edge probes covered by the GUT test

- Reference swap pinned both ways (id == s2_boss_drops AND id != boss_drops; same-instance identity vs the on-disk table).
- OOS boundary: S1 boss still references `boss_drops` (untouched).
- Drop-rate invariant: N=200 rolls, every roll drops exactly 2 items (guaranteed-drop contract), aggregate count matches.
- Affix safety: every rolled affix over 200 rolls resolves to a registered affix (swift/vital/keen) with value inside its tier band — the ticket's "registered affix IDs only" flag.
