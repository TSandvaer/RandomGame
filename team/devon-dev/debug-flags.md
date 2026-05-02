# Debug & Testability Flags

This is the developer-facing reference for the testability hooks Devon
exposed for Tess's M1 acceptance plan (ClickUp `86c9kxnqx`). All flags
are **debug-build only** unless noted — release exports compile out the
toggle, so Sponsor never sees them.

The flags live on the `DebugFlags` autoload (`scripts/debug/DebugFlags.gd`),
registered in `project.godot`. Build identification lives on a sibling
autoload `BuildInfo` (`scripts/debug/BuildInfo.gd`).

---

## Hook 1 — Build SHA in main menu

| Surface | Detail |
|---|---|
| Render location | `scenes/Main.tscn` `BuildLabel` Label, bottom-left, dimmed grey. Updated by `Main.gd._ready()` from `BuildInfo.display_label`. |
| Format | `build: abcdef1` (7-char short SHA) or `build: dev-local`. |
| CI source | `.github/workflows/ci.yml` step `Stamp build SHA into project` writes `${GITHUB_SHA:0:7}` to `build_info.txt` before `--import`. The release workflow (`release-itch.yml`) does the same. |
| Local fallback | If `build_info.txt` is missing AND `GITHUB_SHA` env is unset, BuildInfo returns `dev-local`. |
| Gitignored | `build_info.txt` is gitignored — it's generated per-build, not committed. |

**Verification (Tess):** open the build, look at the bottom-left of the
main menu / Stratum 1 boot screen. Should match the GitHub SHA the
workflow ran on. For local dev runs the label reads `build: dev-local`.

---

## Hook 2 — Fast-XP debug toggle

| Surface | Detail |
|---|---|
| Trigger | **Ctrl + Shift + X** (physical keycode, layout-independent). |
| Effect | `DebugFlags.xp_multiplier()` returns `100` while enabled, `1` otherwise. |
| Default | Off at boot. |
| Console line | `[DebugFlags] fast_xp_enabled=true (multiplier now 100x)` printed to stdout / browser console on each toggle. |
| Signal | `DebugFlags.fast_xp_toggled(enabled: bool)` for HUD / debug overlays. |
| Release build | `OS.is_debug_build()` gate at `_input` AND `_toggle_fast_xp` AND `xp_multiplier`. The chord cannot fire, the flag cannot flip, the multiplier always returns 1. |

**Multiplier value**: 100x is a placeholder. Priya owns the level curve
(`team/priya-pl/week-2-backlog.md` ticket N1). If 100x conflicts with
the curve's intent, swap `FAST_XP_MULTIPLIER` in `DebugFlags.gd` —
single-source-of-truth.

**Verification (Tess):** in a debug build, press Ctrl+Shift+X. Console
should log the toggle. Kill a grunt (or invoke the XP-grant codepath
once it lands); player level should jump several levels in a single kill.

---

## Hook 3 — Save-dir README

| Surface | Detail |
|---|---|
| Trigger | Written by `Save.save_game()` after every successful save. |
| Path | `user://README.txt` (next to `save_<slot>.json`). |
| Content | One paragraph: location of saves, schema_version, three-step "delete to start fresh" procedure, warning about `.tmp` staging files. |
| Idempotent | Overwritten on every save — guarantees the schema_version line tracks the running build. |
| Failure mode | `push_warning` on file-open error; never blocks save_game. |

**Verification (Tess):** quit the game with at least one save slot
written. Open the user data dir for your OS:

| OS | user:// resolves to |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Embergrave\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Embergrave/` |
| Linux | `~/.local/share/godot/app_userdata/Embergrave/` |
| HTML5 | IndexedDB; not file-system inspectable. README still written, accessible via `FileAccess.open("user://README.txt", READ)` from a debug overlay if needed. |

The directory should contain `save_0.json` and `README.txt`. Cat the
README; the path printed inside should match the resolved dir above.

---

## Hook 4 — Stable mob-spawn seed in test mode

| Surface | Detail |
|---|---|
| Activation | Either: (a) launch with CLI flag `--test-mode`, or (b) set env var `EMBERGRAVE_TEST_MODE=1` before launch. CLI flag wins if both set. |
| Effect | `DebugFlags.mob_spawn_seed()` returns the fixed integer `0x7E57C0DE` (=2119571166) every call. Production behavior: returns `randi()` per call (free RNG). |
| Scope | **Mob spawning only.** Loot RNG is owned by Drew's `LootRoller` (per `team/drew-dev/level-chunks.md` and DECISIONS.md `2026-05-02 — Content schema`); DebugFlags intentionally does not touch the global RNG, `randomize()`, or any RNG outside mob spawn paths. |
| Default | Off at boot. |
| Release build | `OS.is_debug_build()` gate: CLI/env are ignored, `test_mode_enabled` stays false, `mob_spawn_seed()` always returns `randi()`. |

**Mob spawner integration**: when implementing the spawner (week-2 task),
do this:

```gdscript
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
rng.seed = DebugFlags.mob_spawn_seed()
# ... use rng for spawn-position picks, mob-archetype rolls, etc.
```

**Verification (Tess):** launch with `--test-mode`. The console line
`[DebugFlags] debug_build=true test_mode=true fast_xp=false` should
appear at boot. Run the AC4 setup twice; the mob layout should be
identical between runs. Without the flag, layouts should vary.

---

## Hook 5 — HTML5 console error surfacing

**Goal**: uncaught GDScript errors during HTML5 play must reach the
browser console so Tess (and the Sponsor's own browser, post-deploy)
can surface bug reports without re-running locally.

**Verification (Devon)**: I checked Godot 4.3's HTML5 export pipeline.
The default behavior — and confirmed by inspecting the upstream
`platform/web/js/engine/engine.js` source and the Godot 4.3 release
notes — is that:

1. `print()` calls go to `console.log()`.
2. `push_error()` and `push_warning()` go to `console.error()` and
   `console.warn()` respectively.
3. **Uncaught script errors** (assertion failures, null-deref crashes,
   "Invalid type in function" etc.) are formatted by the engine's error
   handler and routed through `printerr`, which the JS shim sends to
   `console.error()`. The browser DevTools console catches these natively.
4. The fatal-crash path (e.g. an unhandled exception that aborts the VM)
   is captured by Emscripten's `onAbort`, which also writes to
   `console.error()` before the WASM module unwinds.

There is no export-preset toggle that strips this — `application/run/console_wrapper`
in `export_presets.cfg` is a Windows-only setting that controls whether
the .exe spawns a separate console window; it has no HTML5 equivalent
and does not affect the JS shim's console plumbing.

**Conclusion**: no code or config changes needed. Godot's default HTML5
export is already correctly configured. When `export_presets.cfg` is
authored (week-2 task), no special setting is required for hook 5; the
default preset is correct.

**Verification procedure for Tess (manual):**

1. Build HTML5 export (CI or local).
2. Open the deployed page in Chrome / Firefox / Safari.
3. Open DevTools → Console.
4. Trigger a known crash path. Until gameplay can produce one organically,
   add a temporary `assert(false, "tess test")` in `Main.gd._ready` and
   rebuild. The DevTools console should show:
   `Embergrave/scenes/Main.gd:N - Assertion failed: tess test`
5. Remove the assert before merging.

If a future Godot upgrade or a custom export-preset changes this
default, the symptom is "HTML5 build silently swallows GDScript errors"
— would surface in Tess's smoke pass on the first HTML5 RC. Re-run this
procedure after every Godot version bump.

---

## Concurrent agent / future-work notes

- The `--test-mode` CLI flag is parsed by `DebugFlags._resolve_test_mode()`
  on autoload-ready. If a future test wants to toggle test mode mid-run,
  use `DebugFlags.set_test_mode_for_test(bool)`.
- The mob seed constant `0x7E57C0DE` is pinned by a test
  (`tests/test_test_mode_seed.gd::test_test_mode_seed_constant_is_stable`).
  Don't change it casually — Tess's AC4 layouts depend on it being stable.
- Hooks 2 and 4 share `DebugFlags.gd`. If a third debug toggle lands,
  add it here (single autoload, single doc), don't proliferate autoloads.
