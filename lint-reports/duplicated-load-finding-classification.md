# gdlint `duplicated-load` — HTML5 cache warmup finding classification

**Investigation ticket:** [`86c9y58mv`](https://app.clickup.com/t/86c9y58mv) (Stage-2 followup to PR #333)
**Branch:** `devon/lint-investigate-duplicated-load-html5-warmup`
**Date:** 2026-05-23

## Scope

Per ticket — capture the full `duplicated-load` finding list, classify each
as case (a) genuine duplicate vs case (b) intentional HTML5 ResourceCache
warmup idiom, then verdict whether gdlint's rule correctly handles any
warmup site.

## Tool invocation

```
python -m gdtoolkit.linter scripts/ tests/ 2>&1 | grep duplicated-load
```

(`gdlint` is exposed as the `python -m gdtoolkit.linter` entry point in this
environment — same gdtoolkit 4.5.0 the CI step uses.)

## Headline number

| Surface | `duplicated-load` findings |
|---|---|
| `scripts/` (production) | **0** |
| `tests/` (GUT) | **58** |
| **Total** | **58** |

## Verdict — NO-WARMUP-EXISTS

The HTML5 cache warmup hypothesis is **structurally inapplicable** to this
codebase as it currently stands:

1. **Zero `scripts/` findings.** Production code has no duplicate `load()`
   / `preload()` calls within any single file. The rule reports nothing
   that could be mistaken for an intentional warmup idiom.

2. **All 58 findings are in `tests/` files.** GUT tests run in
   headless-Godot CI, not in HTML5. The `gl_compatibility` service-worker
   cache trap documented in `.claude/docs/html5-export.md` § "Service-worker
   cache trap" exists only in the WebGL2 export — it cannot be mitigated
   by GUT test code, which never runs in that environment.

3. **Production preload sites already use the canonical pattern.** A
   `grep -rEn "preload\(" scripts/` audit returns 14 occurrences across 9
   scripts:

   - `scripts/content/MobRegistry.gd:64` — `const _MobDef := preload(...)`
   - `scripts/inventory/Inventory.gd:596` — `const DamageScript := preload(...)`
   - `scripts/loot/MobLootSpawner.gd:11` — `const PickupScene := preload(...)`
   - `scripts/mobs/Charger.gd:160-161` — `const HitboxScript` + `DamageScript`
   - `scripts/mobs/Grunt.gd:147-148` — same pair
   - `scripts/mobs/Shooter.gd:132-133` — same pair
   - `scripts/mobs/Stratum1Boss.gd:308-309` — same pair
   - `scripts/player/Player.gd:159-160` — same pair
   - `scripts/ui/InventoryPanel.gd:408` — `const DamageScript := preload(...)`

   Every site is **single-occurrence-per-file** assigned to a `const` —
   the canonical gdlint-endorsed pattern. The cross-file duplication
   (`Damage.gd` preloaded in 7 different files) is **out of `duplicated-load`'s
   scope**: the rule flags duplicates *within a single file*, not across
   files.

4. **Negative grep audit.** `grep -irE "warmup|warm_up|prime_cache|preload.*cache" scripts/`
   returns zero matches. No warmup idiom is implemented in production code.

## Per-finding classification — all 58 are case (a)

All 58 findings are **case (a) genuine duplicates** — GUT test method bodies
that each re-`load()` the same scene/script/resource rather than hoisting
to a top-of-file `const` or a `before_each` cached var.

### File breakdown (counts)

| File | Findings | Pattern |
|---|---|---|
| `tests/test_m3w7_audio_cues.gd` | 17 | Per-test `preload("res://scripts/player/Player.gd").new()` etc. |
| `tests/test_stratum1_room.gd` | 5 | Per-test `load("res://scenes/levels/Stratum1Room01.tscn")` |
| `tests/test_zone_def.gd` | 5 | Per-test `load("res://resources/level/zones/s1_z1_outer_cloister.tres") as ZoneDef` |
| `tests/test_floor_assembler.gd` | 3 | Same — per-test ZoneDef load |
| `tests/test_stat_allocation.gd` | 3 | Per-test load of `Player.tscn` + `stat_strings.tres` |
| `tests/integration/test_m1_play_loop.gd` | 3 | Per-test `iron_sword.tres` / `swift.tres` / `Main.tscn` loads |
| `tests/integration/test_starter_weapon_damage_integration.gd` | 2 | Per-test factory + Grunt loads |
| `tests/test_level_chunk.gd` | 2 | Per-test `s1_room01.tres` loads |
| `tests/test_mob_attack_telegraph.gd` | 2 | Per-test `Stratum1Boss.gd` + `MobDef.gd` loads |
| (others, 1 finding each) | 16 | Single-duplicate-per-file in 16 test files |

### Spot-check evidence

**`test_m3w7_audio_cues.gd:180,190,203,217,234,...`** — each test method
that needs a Player instance does:

```gdscript
func test_player_attack_spawned_heavy_plays_attack_heavy_cue() -> void:
    var player: Player = preload("res://scripts/player/Player.gd").new()
    add_child_autofree(player)
    # ...
```

Six adjacent test methods each preload Player.gd from scratch. Standard fix:
hoist to top-of-file `const PlayerScript := preload("res://scripts/player/Player.gd")`
+ use `PlayerScript.new()` in each method body. Per-test isolation is
preserved (each method still constructs a fresh instance); the load happens
once at script parse time.

**`test_stratum1_room.gd:27,38,50,65,76`** — five adjacent test methods each
`load("res://scenes/levels/Stratum1Room01.tscn")`. Same fix shape.

**`test_zone_def.gd:250,260,274,287,304`** — five adjacent test methods each
`load(... outer_cloister.tres) as ZoneDef`. Same shape.

No site reads as a deliberate cache warmup — every duplicate sits inside an
individual test method, fully replaceable by the canonical top-of-file
`const` pattern with no semantic change.

## Empirical verification — SKIPPED

The ticket's step 4 ("if any warmup-idiom site exists, run a release-build
of one of the affected scenes BEFORE and AFTER a test collapse + measure
boot-time `[BuildInfo]` -> first-room-render latency") is **not applicable**:

- No warmup-idiom site exists (verdict above).
- All 58 findings are in test code, which does not ship to the HTML5
  artifact. Collapsing or preserving them has zero HTML5 boot-time impact
  by construction.

## Recommendation

**No `gdlintrc` change.**

- Keep `duplicated-load` enabled (`gdlintrc` line 22 unchanged).
- The 58 case-(a) findings are legitimate code-quality issues; the matching
  bulk-sweep ticket should proceed against them as planned, with finding
  count **58** (unchanged from baseline).
- Standard sweep fix shape: hoist per-test `load()` / `preload()` to a
  top-of-file `const ... := preload(...)` per test file, or to a
  `before_each`-cached var if the file already has a fixture setup that
  needs the value. Per-test isolation (instantiation, mutation) is
  preserved; only the resource-resolution cost moves up to file parse
  time, where it belongs.

## Impact on sibling sweep ticket

The `duplicated-load` sweep ticket's acceptance count is unchanged at **58
findings to address**, all in `tests/`. The investigation produces no
disable + does not narrow the sweep's scope. The sweep ticket can land
purely as a test-code cleanup PR with zero production-code risk.

## What if a production warmup-idiom emerges in the future?

If a future PR introduces an intentional HTML5 ResourceCache warmup pattern
(e.g. an `_init_warmup()` block in a Main.gd scene that pre-touches several
heavy resources at boot), `duplicated-load` will fire on it. At that point
the right tool is the **per-call `# gdlint:disable=duplicated-load` pragma**
at the warmup site (single-line scope) rather than a global disable. The
ticket should include a comment citing the perf measurement that justifies
the duplicate.

This investigation does not pre-emptively configure for that case because
(a) no such site exists today, and (b) a pre-emptive disable would silently
allow accidental duplicates anywhere in `scripts/` to ship without notice.

## Cross-references

- `gdlintrc` line 21 (`disable: []` — UNCHANGED) + line 22 (`duplicated-load: null` enabled).
- `.claude/docs/html5-export.md` § "Service-worker cache trap" — the documented HTML5 cache concern; mitigated at the artifact-handoff layer (cache-clear ritual), not via in-engine preload duplication.
- PR #333 (merge commit `0758550`) — gdlint baseline (58-finding figure for this rule).
- Sibling investigation: `class-definitions-order` false-positive scope (`86c9y57g5`).
