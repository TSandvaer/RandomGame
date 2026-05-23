# gdlint `class-definitions-order` — Director-pattern finding classification

**Investigation ticket:** [`86c9y57g5`](https://app.clickup.com/t/86c9y57g5) (Stage-2 follow-up to PR #333)
**Branch:** `devon/lint-investigate-director-class-order`
**Date:** 2026-05-23

## Scope

Per ticket — run gdlint against the four Director-pattern autoloads, classify
each `class-definitions-order` finding as case (a) genuine violation or case
(b) intentional cohesion ordering, then verdict whether the rule correctly
handles the Director shape.

## Tool invocation

```
python -m gdtoolkit.linter \
  scripts/audio/AudioDirector.gd \
  scripts/camera/CameraDirector.gd \
  scripts/combat/TimeScaleDirector.gd \
  scripts/dialogue/DialogueController.gd
```

(`gdlint` is exposed as the `python -m gdtoolkit.linter` entry point in this
environment — same gdtoolkit 4.5.0 the CI step uses.)

## Per-Director summary

| File | `class-definitions-order` findings |
|---|---|
| `scripts/audio/AudioDirector.gd` | **0** |
| `scripts/camera/CameraDirector.gd` | **6** (lines 180, 185, 190, 194, 237, 262) |
| `scripts/combat/TimeScaleDirector.gd` | **2** (lines 157, 163) |
| `scripts/dialogue/DialogueController.gd` | **0** |
| **Director total** | **8** |

AudioDirector + DialogueController follow strict gdlint ordering
(const → var → func / signal → var → func respectively) and trip zero
class-definitions-order findings. The pattern is NOT a Director-shape
universal; it's a per-file authoring choice that two of the four Directors
made for code-comprehension cohesion.

## Per-finding classification

### CameraDirector.gd:180, 185, 190, 194 — signals after consts

```
146 # ---- Constants -------------------------------------------------------
158 const BASELINE_ZOOM
162 const DEFAULT_NORMALIZED_ZOOM
167 const MIN_NORMALIZED_ZOOM
168 const MAX_NORMALIZED_ZOOM
172 const DEFAULT_RESET_DURATION
175 # ---- Signals ---------------------------------------------------------
180 signal zoom_changed(...)            ← FLAGGED
185 signal zoom_requested(...)          ← FLAGGED
190 signal follow_target_changed(...)   ← FLAGGED
194 signal world_bounds_changed(...)    ← FLAGGED
```

gdlintrc declares the order `signals → enums → consts → ... → pubvars → ...`.
The file ships `consts → signals` instead, with section-header comments.

**Classification: case (b) intentional cohesion ordering.**

Rationale: the file uses `# ---- Section ----` headers to chunk the
top-of-file by topic. Constants come first because most of them
(BASELINE_ZOOM, MIN/MAX_NORMALIZED_ZOOM) are domain values a reader needs
context for BEFORE the signal payload types (`zoom_changed(new_normalized_zoom: float)`)
make sense. Reordering signals to the top would force the reader to read
signal signatures referencing un-defined constants. The cohesion choice is
about reader comprehension, not arbitrary stylistic preference.

### CameraDirector.gd:237 — const placed between vars

```
227 ## Throttle accumulator for the HTML5-only CameraDirector.state trace ...
232 var _state_trace_accum: float = 0.0
237 const STATE_TRACE_INTERVAL: float = 0.25       ← FLAGGED
244 var _follow_target: Node2D = null
```

**Classification: case (b) intentional cohesion ordering.**

Rationale: `STATE_TRACE_INTERVAL` (the cadence) is placed adjacent to its
companion `_state_trace_accum` (the accumulator). The two participate in
a single mechanism — when reading `_state_trace_accum`, the cadence
constant is the immediately-relevant context. Hoisting `STATE_TRACE_INTERVAL`
up to the constants block (line 158 region) would separate the pair across
~80 lines and lose the lookup-locality benefit.

### CameraDirector.gd:262 — const inside state section

```
239 ## ---- M3 Tier 3 W1 — continuous-scroll follow + bounds-clamp state ----
244 var _follow_target: Node2D = null
249 var _follow_deadzone: Vector2 = Vector2.ZERO
255 var _world_bounds: Rect2 = Rect2()
262 const LOGICAL_VIEWPORT_BASE: Vector2 = Vector2(1280.0, 720.0)   ← FLAGGED
```

**Classification: case (b) intentional cohesion ordering.**

Rationale: `LOGICAL_VIEWPORT_BASE` is part of the M3 Tier 3 W1
continuous-scroll mechanism. It participates in the world-bounds-clamp
computation alongside `_world_bounds`. Same pair-locality argument as :237.

### TimeScaleDirector.gd:157, 163 — signals after consts

```
134 # ---- Constants -------------------------------------------------------
140 const MIN_NON_FREEZE_SCALE
144 const MAX_SCALE
148 const PRIORITY_DEFAULT
149 const PRIORITY_NARRATIVE
150 const PRIORITY_FREEZE
153 # ---- Signals ---------------------------------------------------------
157 signal scale_changed(new_scale: float)               ← FLAGGED
163 signal request_changed(reason: String, op: String)   ← FLAGGED
```

**Classification: case (b) intentional cohesion ordering.**

Rationale: identical pattern to CameraDirector:180/185/190/194. The PRIORITY_*
constants must precede the signals because the doc-block on `request_changed`
implicitly references priority semantics. Hoisting signals to the top would
require duplicating priority context in the signal docstring or forcing
forward references.

## Verdict

**MIXED.**

All 8 Director-pattern findings are case (b) — every flagged line corresponds
to a deliberate cohesion-ordering choice (signals-after-consts, or const-paired-
with-var). The author's intent is code-comprehension locality, codified through
`# ---- Section ----` comment headers.

The naive bulk-sweep — reordering each Director's top-of-file to match the
strict gdlint order — would lose:
- The `consts → signals` reading-order semantics (signal docstrings can
  reference already-defined constants by name).
- The const-var pair-locality for `STATE_TRACE_INTERVAL` / `_state_trace_accum`
  and `LOGICAL_VIEWPORT_BASE` / `_follow_target` mechanism groupings.

However, the broader pattern is NOT Director-unique. A `python -m gdtoolkit.linter
scripts/ tests/` cross-check shows 20 distinct files trip
class-definitions-order findings (Inventory.gd, RoomGate.gd, Stratum1Boss.gd,
Player.gd, Save.gd, etc.) — the cohesion-ordering convention exists across
the codebase, not solely in the four Directors. Sample empirical confirmation:

- `scripts/inventory/Inventory.gd:88-93` — signal block placed AFTER consts
  with `# ---- Signals ----` header (identical shape to CameraDirector:180).
- `scripts/levels/RoomGate.gd:119` — `@export var test_skip_death_wait` placed
  AFTER an unrelated pubvar (export-after-pubvar; same class of cohesion
  ordering, different rule sub-clause).

## Recommendation

**Globally disable `class-definitions-order`** in `gdlintrc` line 21
(`disable: [class-definitions-order]`), with a YAML comment citing this
investigation and the project's documented cohesion-ordering convention.

Reasoning:

1. Of the 8 Director-pattern findings, **0 are case (a)**. The rule produces
   100% false-positives on the Director shape.
2. The Stage-2 sweep ticket assumes ~92 findings to fix. Per-finding manual
   classification across 20 files would be high-cost (likely many more (b)
   than (a) given the spot-check pattern).
3. Project documentation (`.claude/docs/audio-architecture.md`,
   `camera-layer.md`, `time-scale-director.md`, `dialogue-system.md`)
   references the file structure of these autoloads. Reordering would
   produce doc drift on the architectural-reference layer.

Per-file pragma (alternative we considered): gdtoolkit supports
`# gdlint: ignore=class-definitions-order` per-line; a per-file scope would
require 20+ pragma additions. Less surgical than a global disable when 100%
of inspected findings are case (b).

## Impact on the sweep ticket

The matching `class-definitions-order` sweep ticket (sibling to this
investigation) should be **closed out / re-scoped to zero work** if the
global disable lands. Post-disable finding count: **0**.

The sweep ticket's body should be updated to cite this investigation's
verdict + the gdlintrc edit. If the sweep ticket has already started any
work-in-flight, that work should be reverted (the cohesion ordering is the
intended shape).

## Cross-references

- gdlintrc lines 1-15 (class-definitions-order rule order) + line 21 (disable list)
- `.claude/docs/audio-architecture.md` — AudioDirector topology (no findings)
- `.claude/docs/camera-layer.md` — CameraDirector topology (6 findings)
- `.claude/docs/time-scale-director.md` — TimeScaleDirector topology (2 findings)
- `.claude/docs/dialogue-system.md` — DialogueController topology (no findings)
- PR #333 (merge commit `0758550`) — gdlint baseline (92 findings repo-wide)
- Sibling investigation: `duplicated-load` false-positive scope (`86c9y58mv`)
