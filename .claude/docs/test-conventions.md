# Test Conventions

What this doc covers: the cross-layer test conventions for Embergrave's two test surfaces — GUT (headless Godot, runs in CI on every push/PR) and Playwright (browser-driven, runs against the HTML5 release-build artifact). Topic-specific tests still live in `team/tess-qa/` (acceptance plans, journey-probe procedure, soak rituals); this doc is the **load-bearing framework conventions** that every test author needs to know.

## Universal warning gate (ticket `86c9uf0mm`)

The Sponsor M2 RC soak meta-finding (2026-05-15) was that **3 of 4 user-visible findings would have been caught by a universal console-warning zero-assertion** — `leather_vest` unknown-id, DirAccess HTML5 recursion warnings, save-schema migration warnings. The fix shipped as a two-surface gate: Playwright Phase 1 (Tess, PR #217 — merged) covers HTML5 console; GUT Half B (Devon, this PR) covers headless engine.

### GUT side — `NoWarningGuard` + `WarningBus`

**The Godot 4.3 limitation that shapes this design.** Godot 4.3's GDScript API does NOT expose any way to install a custom logger or intercept `push_warning` / `push_error` calls from within the GDScript process. Verified surfaces:

- `OS.add_logger()` — C++ only, no GDScript binding.
- `Engine.set_print_error_messages()` — boolean toggle (mute / unmute); no hook callback.
- `EngineDebugger.register_message_capture()` — captures debugger-protocol messages, not engine warnings.
- No signal fires on `push_warning`; no `_log_message` virtual.

So the only GDScript-accessible path is **wrap `push_warning` at the call site** with a tiny shim that BOTH calls the real `push_warning` (so the warning still surfaces in Godot's console, HTML5's `console.warn`, and CI's stderr) AND records the event into an observable signal that tests can subscribe to.

**Components:**

- **`scripts/debug/WarningBus.gd`** — autoload registered as `WarningBus`. Exposes `warn(text, category)` and `error(text, category)`. Each call invokes the native `push_warning` / `push_error` AND emits a corresponding signal (`warning_emitted` / `error_emitted`).
- **`tests/test_helpers/no_warning_guard.gd`** — GUT helper class. Subscribes to the bus signals on `attach()`, asserts zero captured emissions on `assert_clean(self)`, supports `expect_warning(pattern)` opt-out for tests that deliberately exercise a warning path.

**Usage pattern (every save-load / content-resolution / mob-registry GUT test):**

```gdscript
const NoWarningGuard := preload("res://tests/test_helpers/no_warning_guard.gd")

var _warn_guard: NoWarningGuard

func before_each() -> void:
    _warn_guard = NoWarningGuard.new()
    _warn_guard.attach()

func after_each() -> void:
    _warn_guard.assert_clean(self)
    _warn_guard.detach()
    _warn_guard = null

func test_some_path_that_deliberately_warns() -> void:
    _warn_guard.expect_warning("substring of the expected warning text")
    # ... exercise the code path that emits the warning ...
```

`expect_warning(pattern)` is a per-emission opt-out — registering one pattern consumes one matching warning. Two matching warnings with one expectation = one violation. The substring match is intentionally simple (case-sensitive substring) — tests express intent inline rather than building regex matchers.

**Migration policy.** Source-side migration of `push_warning` → `WarningBus.warn` is targeted, not blanket. The **load-bearing surfaces** are migrated:

- `scripts/loot/ItemInstance.gd::from_save_dict` — unknown item id + unknown affix id paths
- `scripts/content/MobRegistry.gd` — load failures, null mob_def, unknown stratum, unknown mob_id (spawn path)
- `scripts/save/Save.gd::migrate` — schema-newer-than-runtime path

Other call sites (audio, level assembler, mob telemetry) remain on direct `push_warning` until / unless a future ticket reveals an analogous gap. **Adding a new save-load / content-resolution surface? Route warnings through `WarningBus.warn(...)` from day one** so the guard catches regressions automatically.

**Wired GUT test files** (every save-load + content-resolution surface):

- `tests/test_save.gd` — round-trip + migration
- `tests/test_save_roundtrip.gd` — death-rule + AC-shaped invariants
- `tests/test_save_migration.gd` — v0→v3 fixtures
- `tests/test_save_restore_resolver_ready.gd` — iron_sword resolver ready-ness
- `tests/test_mob_registry.gd` — mob registry surface + scaling
- `tests/test_content_factory.gd` — factory smoke + drift

**Paired test for the guard itself.** `tests/test_no_warning_guard.gd` pins:

1. `WarningBus` autoload is registered (boot-time).
2. The guard catches a deliberate `WarningBus.warn(...)`.
3. `expect_warning(pattern)` lets a matching warning pass.
4. The guard catches a deliberate `WarningBus.error(...)`.
5. A mismatched `expect_warning` pattern does NOT consume a real warning.
6. `detach()` is idempotent and clears state.
7. Multiple `expect_warning` patterns each consume one warning.
8. One `expect_warning` does NOT swallow two matching warnings.
9. An unattached guard captures nothing (no silent passes).

If the guard quietly stops working (e.g. a future refactor breaks the signal wiring), this file fails first — the canary that protects the gate.

### Playwright side — `test-base.ts` fixture

See `tests/playwright/fixtures/test-base.ts` for the Playwright-side gate. The TypeScript fixture extends Playwright's base `test` with an auto-attached `ConsoleCapture` and a teardown assertion that fails on `USER WARNING:` / `USER ERROR:` console lines (Godot HTML5's `push_warning` / `push_error` prefix shape).

Specs adopt the gate by changing one import line:

```diff
- import { test, expect } from "@playwright/test";
+ import { test, expect } from "../fixtures/test-base";
```

Opt-out semantics mirror the GUT side: `test.use({ expectedUserWarnings: [/regex/] })` for an allow-list, `test.use({ allowUserWarnings: true })` for whole-describe-block opt-out (last resort).

**Spec migration status (2026-05-15).** Phase 1 (Tess, PR #217) shipped the fixture infrastructure + one demonstration spec. Phase 2A (migrate the 11 existing specs to the new import) is a mechanical follow-up tracked separately — once the leather_vest fix landed (PR #214) and Devon's Half B GUT side ships, Tess picks up Phase 2A. Until then, existing specs still import from `@playwright/test` and run unaffected.

### The two surfaces complement each other

- **GUT** covers headless engine behavior: save-load round-trips, registry resolution, scaling math, AI state machines. Fast feedback (~1m20s in CI), but cannot exercise the WebGL2 renderer or browser-level concerns.
- **Playwright** covers the HTML5 release-build artifact: actual `gl_compatibility` rendering, service-worker cache behavior, real input events, canvas-to-DOM coordination. Slower (release-build + browser boot per spec), but the only surface that catches HTML5-specific divergences.

**A bug class is "covered" only when BOTH surfaces have a test for it** when the bug class can manifest in either lane. The Sponsor M2 RC meta-finding was that headless GUT and the Playwright suite both shipped green for 24 hours while the Sponsor's manual soak found three production warnings — every test path was scoped, none was universal. The two-surface warning gate is the structural answer.

## Visual primitives — see `team/TESTING_BAR.md` § "Visual primitives"

Tier 1 (mandatory): target color ≠ rest color (`assert_ne`). Tier 2 (mandatory for parented modulate cascades): assertion lands on the visible-draw node, not the parent CharacterBody2D. Tier 3 (aspirational): framebuffer pixel-delta — deferred pending a renderer-painting CI lane. Full detail + rationale in `team/TESTING_BAR.md`.

## Cross-references

- `team/TESTING_BAR.md` — Definition-of-Done, visual-primitive tiers, role-specific obligations
- `team/tess-qa/playwright-harness-design.md` — full Playwright harness design + spec authoring conventions
- `team/tess-qa/m2-acceptance-plan-week-3.md` — W3 acceptance plan, including the migration ticket scope
- `.claude/docs/combat-architecture.md` — combat-side testing patterns (hit-flash modulate, death tween, `[combat-trace]` shim)
- `.claude/docs/html5-export.md` — HTML5-specific failure modes that the Playwright surface is positioned to catch
- ClickUp `#86c9uf0mm` — the universal-warning gate ticket (Half A + Half B)
- PR #217 — Tess's Playwright Phase 1 scaffold (merged)
