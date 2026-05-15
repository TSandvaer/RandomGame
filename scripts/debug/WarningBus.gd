extends Node
## WarningBus autoload — observable shim around `push_warning` so GUT tests
## can assert "no warnings emitted" without source-modifying every call site.
##
## **Ticket 86c9uf0mm — universal warning gate Half B (GUT side).**
##
## ## The Godot 4.3 limitation this works around
##
## Godot 4.3's GDScript API does NOT expose a way to install a custom
## logger or intercept `push_warning` / `push_error` calls from within the
## GDScript process. Verified surfaces:
##
##   - `OS.add_logger()` — C++ only, no GDScript binding.
##   - `Engine.set_print_error_messages()` — boolean toggle (mute / unmute);
##     does not provide a hook callback.
##   - `EngineDebugger.register_message_capture()` — captures debugger
##     `my_message:` prefixed messages, NOT engine warnings / errors.
##   - No signal fires on `push_warning`; no `_log_message` virtual.
##
## So the only GDScript-accessible path is to **wrap `push_warning` at the
## call site** with a tiny shim that BOTH calls the real `push_warning` (so
## the warning still surfaces in Godot's console, HTML5's
## `console.warn`, and CI's stderr) AND records the event into an
## observable signal that tests can subscribe to.
##
## ## Surface
##
##   WarningBus.warn(text, category := "")
##       -> calls push_warning(text); emits warning_emitted(text, category).
##
##   WarningBus.error(text, category := "")
##       -> calls push_error(text); emits error_emitted(text, category).
##
## Existing direct `push_warning(...)` / `push_error(...)` calls remain
## valid and will continue to fire on the console — but those calls are
## INVISIBLE to `NoWarningGuard`. New code on save-load / content-registry
## / mob-registry surfaces (the load-bearing classes the 86c9uf0mm gate
## protects) MUST use `WarningBus.warn(...)` / `.error(...)` to gain test
## coverage.
##
## ## Why an autoload, not a static class
##
## Signals require an Object instance to live on. An autoload is the
## standard Godot pattern for "global emitter + global state holder."
## Static-only would force every caller into a `WarningBus.bus.warn(...)`
## stutter; the autoload lets us write `WarningBus.warn(...)` directly.
##
## ## Listener pattern (for tests)
##
##   func before_each():
##       WarningBus.warning_emitted.connect(_on_warning)
##       _captured.clear()
##   func _on_warning(text: String, category: String):
##       _captured.append({"text": text, "category": category})
##   func after_each():
##       WarningBus.warning_emitted.disconnect(_on_warning)
##       assert_eq(_captured.size(), 0, ...)
##
## Most tests use `tests/test_helpers/no_warning_guard.gd` rather than
## wiring this directly. See that helper for the GUT-friendly API + the
## `expect_warning(pattern)` opt-out for tests that deliberately exercise
## a warning path.
##
## ## Migration policy
##
## NOT every existing `push_warning` call site is migrated. The migration
## targets the **save-load + content-resolution** surface — the classes
## the M2 RC soak meta-finding (Sponsor 2026-05-15) identified as the
## load-bearing gap. Other call sites (audio, level assembler, mob
## telemetry) remain on direct `push_warning` until / unless a future
## ticket reveals an analogous gap.
##
## ## References
##
##   - ClickUp 86c9uf0mm (this ticket — Half B, GUT side)
##   - PR #217 (Tess's Phase 1 Playwright-side gate — Half A)
##   - `tests/test_helpers/no_warning_guard.gd` (the GUT helper that uses
##     this bus's signal)
##   - `.claude/docs/test-conventions.md` § "Warning gate (GUT)"


signal warning_emitted(text: String, category: String)
signal error_emitted(text: String, category: String)


## Emit a project-level warning. Calls Godot's native `push_warning` AND
## the observable `warning_emitted` signal. Use this in save-load /
## content-resolution code paths instead of bare `push_warning` so GUT's
## `NoWarningGuard` can detect the warning in tests.
##
## `category` is a free-form string the caller can use to subclass the
## warning (e.g. `"save_schema"`, `"unknown_item_id"`). Optional;
## `expect_warning(pattern)` matches against `text` not `category`.
func warn(text: String, category: String = "") -> void:
	# Native `push_warning` first — preserves console / stderr / HTML5
	# `console.warn` surface. Even if no listener is connected to the
	# signal, the warning still surfaces as before.
	push_warning(text)
	warning_emitted.emit(text, category)


## Emit a project-level error. Calls Godot's native `push_error` AND the
## observable `error_emitted` signal. Use this for save-load corruption
## paths and any error class GUT tests should be able to assert against.
func error(text: String, category: String = "") -> void:
	push_error(text)
	error_emitted.emit(text, category)
