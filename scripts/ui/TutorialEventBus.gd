extends Node
## Tutorial event bus — autoload that decouples tutorial-beat *triggers*
## (room scripts emitting "the player just entered Room01") from tutorial-beat
## *rendering* (`TutorialPromptOverlay` showing the resolved text).
##
## **This is the empty stage** for Drew's Stage 2b dispatch (ticket
## `86c9qaj3u`). NO content is wired here at scaffold time — beat IDs are
## reserved + a default text dictionary exists, but no production code calls
## `request_beat`. Drew's room script will emit on Room01 entry / first-input
## / dummy-poof; this bus relays the request to the overlay.
##
## **Why an autoload (vs. a static helper):** signals can't be declared on
## static-only classes; the bus needs a `tutorial_beat_requested` signal so
## the overlay can subscribe in its own `_ready`. Autoload is the cheapest
## correct shape (one `Node` subclass, no per-scene instantiation). Wired
## in `project.godot` `[autoload]` block.
##
## **API surface for Drew Stage 2b:**
##   - `TutorialEventBus.request_beat(beat_id, anchor)` — fires the signal.
##     `beat_id: StringName` (one of `&"wasd"`, `&"dodge"`, `&"lmb_strike"`,
##     `&"rmb_heavy"` — see `BEAT_TEXTS` const). `anchor: int` (mirrors
##     `TutorialPromptOverlay.AnchorPos` — pass 0 for CENTER_TOP, 1 for
##     CENTER, 2 for BOTTOM).
##   - `TutorialEventBus.tutorial_beat_requested(beat_id, anchor)` signal —
##     subscribed by `TutorialPromptOverlay`; not called directly by content.
##   - `TutorialEventBus.resolve_beat_text(beat_id)` — pure lookup; returns
##     "" for unknown beat_ids. Drew can extend the dictionary or pass custom
##     text via `TutorialPromptOverlay.show_prompt` directly (escape-hatch).
##
## **Beat text resolution:** const dictionary `BEAT_TEXTS` ships with the four
## reserved beat IDs Uma's player-journey Beats 4-5 spec out:
##   - `&"wasd"`        → `"WASD to move."`
##   - `&"dodge"`       → `"Space to dodge-roll."`
##   - `&"lmb_strike"`  → `"LMB to strike."`
##   - `&"rmb_heavy"`   → `"RMB for heavy strike."`
##
## Drew can extend this dictionary in his Stage 2b PR if more beats land
## (e.g. Beat 8's `"Tab to view inventory."` toast, currently scoped to a
## different ticket). Or — for one-off beats — emit `request_beat` with an
## unregistered beat_id; the overlay no-ops, and Drew calls
## `TutorialPromptOverlay.show_prompt` directly with custom text.

# ---- Signals --------------------------------------------------

## Emitted when a tutorial beat is requested. Subscribed by
## `TutorialPromptOverlay`; receiver resolves text via `resolve_beat_text`
## and calls `show_prompt`.
##
## Payload:
##   - `beat_id` — symbolic beat name; `resolve_beat_text` maps it to text.
##   - `anchor` — int matching `TutorialPromptOverlay.AnchorPos` enum
##     ordinals (CENTER_TOP=0, CENTER=1, BOTTOM=2). Carried as int (not enum)
##     because autoload signals cross script-class boundaries; int is the
##     lowest-friction payload type.
signal tutorial_beat_requested(beat_id: StringName, anchor: int)


# ---- Beat text dictionary -----------------------------------------

## Reserved beat IDs for Drew's Stage 2b — text strings copied from Uma's
## `team/uma-ux/player-journey.md` Beats 4-5 spec verbatim. Drew may extend
## this dictionary in his Stage 2b PR if more beats are needed.
##
## **Why a const dict, not a `Tutorial.tres` Resource:** four entries with
## stable strings; a Resource would over-engineer the surface. If beat count
## crosses ~10 OR localization lands, refactor into a `Tutorial.tres` typed
## Resource. Documented in the M2 W1 design analog
## `team/uma-ux/m2-w1-ux-polish-design.md` § "Naming conventions" pattern
## (single-source-of-truth-when-cheap).
const BEAT_TEXTS: Dictionary = {
	&"wasd": "WASD to move.",
	&"dodge": "Space to dodge-roll.",
	&"lmb_strike": "LMB to strike.",
	&"rmb_heavy": "RMB for heavy strike.",
}


# ---- Public API ----------------------------------------------

## Fire a tutorial beat. Production trigger surface — Drew's Stage 2b room
## script calls this from Room01 entry / first-input / dummy-poof beats.
##
## Idempotent: emitting the same beat_id twice in rapid succession is the
## caller's responsibility (the overlay's replace-on-new-show throttle
## handles the visual side, but the bus does NOT dedupe). Drew's room
## script should latch on first-emission (e.g. via a one-shot
## connection or a `_emitted_beats` set).
func request_beat(beat_id: StringName, anchor: int = 0) -> void:
	tutorial_beat_requested.emit(beat_id, anchor)


## Resolve a beat_id to its display text. Returns `""` for unknown beat_ids
## (the overlay treats empty-string as "silently no-op," so unregistered
## beats don't render an empty plate).
##
## Pure function — no side effects. Tests can call this without standing up
## the overlay or the signal-receiver chain.
func resolve_beat_text(beat_id: StringName) -> String:
	if BEAT_TEXTS.has(beat_id):
		return String(BEAT_TEXTS[beat_id])
	return ""


## Returns true if the given beat_id is registered in `BEAT_TEXTS`. Drew can
## use this for invariants ("emit only registered beats" tests).
func is_beat_registered(beat_id: StringName) -> bool:
	return BEAT_TEXTS.has(beat_id)
