# Dialogue System — schema, controller, panel

What this doc covers: the runtime topology for Embergrave's dialogue system — the `DialogueTreeDef` / `DialogueBranch` / `DialogueResponse` Resource schema, the `DialogueController` autoload that owns the active session, the `DialoguePanel` modal UI, and the load-bearing input-gating convention introduced by the spike (ticket `86c9xuab3`).

**Status — Spike landed (Wave 1).** This is the proof-of-pattern data shape + runtime topology. Production content authoring (more NPC trees, bounty-state wiring, audio/portrait integration) lands in W2+.

## Schema

Three Resource classes layered into a tree:

```
DialogueTreeDef        (one per NPC)
├── npc_id: StringName            ── e.g. &"s1_warden_scholar"
├── display_name: String          ── "The Warden-Scholar" (panel header)
├── branches: Dictionary          ── StringName key → DialogueBranch
│   ├── &"flavor"      → DialogueBranch
│   ├── &"pre_quest"   → DialogueBranch
│   ├── &"quest_active" → DialogueBranch
│   └── ... (any author-defined keys)
└── default_branch_key: StringName ── fallback when quest_state not in branches

DialogueBranch         (one per quest_state / sub-branch)
├── lines: Array[String]               ── sequential dialogue lines (may be empty)
└── responses: Array[DialogueResponse] ── player choices after last line (may be empty)

DialogueResponse       (one per player choice option)
├── text: String                  ── option label
├── next_branch_key: StringName   ── branch to navigate to (&"" closes)
└── quest_action: StringName      ── optional side-effect id (&"" = no action)
```

**Why `branches` is untyped `Dictionary` instead of `Dictionary[StringName, DialogueBranch]`.** Godot 4.3 GA had editor quirks with typed-Dictionary fields on Resource classes — inspector reset, sub-resource type-loss across save/reload. Test backstop pins the lost type-check: `test_all_fixture_branches_are_DialogueBranch` asserts every entry `is DialogueBranch` for every shipped fixture.

**State-branching shape locked.** The five quest-state keys (`pre_quest` / `quest_active` / `quest_completed` / `quest_failed` / `flavor`) are convention, not enforced by the schema — any StringName key is valid. The convention exists so the W2 BountyController has a stable lookup contract; the engine itself doesn't care what the keys are. `default_branch_key` is the fallback when the runtime's `quest_state` isn't in the tree (`flavor` typical).

## DialogueController autoload

Single global owner of the active dialogue session. Registered in `project.godot` as `DialogueController="*res://scripts/dialogue/DialogueController.gd"`.

### Why an autoload

Same shape as `AudioDirector` / `TimeScaleDirector` (see `audio-architecture.md` / `time-scale-director.md`): a single authoritative owner of a shared runtime resource, reachable from any node. NPCs trigger `DialogueController.open(tree, quest_state)`; the panel subscribes to `branch_opened` / `line_displayed` / `responses_presented` / `dialogue_closed`; `Player.gd` reads `DialogueController.is_active()` to gate attack input.

### Single-session guard

At most ONE dialogue may be active at a time. A second `open()` while one is active is rejected via `WarningBus.warn("DialogueController.open: rejected — session already active...")` and returns `false`. The spike does NOT model a queue of pending dialogues — that complexity belongs in a later milestone if the design needs it.

### Public API

```gdscript
DialogueController.open(tree, quest_state := &"flavor") -> bool
DialogueController.advance_line() -> void
DialogueController.select_response(idx) -> void
DialogueController.close() -> void            # idempotent
DialogueController.is_active() -> bool
DialogueController.current_branch_key() -> StringName
DialogueController.current_line_index() -> int
DialogueController.current_line_text() -> String
DialogueController.current_responses() -> Array
DialogueController.current_npc_id() -> StringName
DialogueController.current_display_name() -> String
```

### Signal surface

Fire order is load-bearing — keep this list in sync with the controller's docstring:

| Signal | When |
|---|---|
| `branch_opened(npc_id, branch_key)` | Per `open()` AND per `select_response` that navigates to a new branch |
| `line_displayed(line_index, line_text)` | Per `open()` (line 0) AND per `advance_line()` landing on a new line |
| `responses_presented(responses)` | When `advance_line()` passes the last line AND `responses.size() > 0` |
| `response_selected(idx, response)` | Per `select_response(idx)`, BEFORE navigation |
| `quest_action_invoked(action_id, npc_id)` | Per `select_response` whose response has `quest_action != &""`. Emits BEFORE navigation so listeners run with the originating branch context, not the destination |
| `dialogue_closed(npc_id)` | Per `close()` that transitions from active → idle. Idempotent close (already-idle `close()`) emits NOTHING |

### Branch resolution rule

`open(tree, quest_state)` walks:
1. If `tree.branches.has(quest_state)` → use that branch.
2. Else if `tree.branches.has(tree.default_branch_key)` → use that branch.
3. Else → push_warning via `WarningBus.warn` + return `false`. Panel never appears; player is never trapped in a soft-locked UI state.

`DialogueTreeDef.resolve_branch(quest_state)` exposes the resolution logic side-effect-free (returns `null` on unresolvable) for test smoke-loading.

### quest_action side-effect channel — spike-level only

The spike EMITS `quest_action_invoked(action_id, npc_id)` for every picked response with non-empty `quest_action`. It does NOT execute the action. W2 wires bounty-state mutations to this signal — e.g. `accept_bounty:s1_warden_scholar` resolves to a `BountyController.accept(npc_id)` call site.

Authoring convention for `quest_action` strings: `<verb>:<target>` colon-separated. Verbs introduced by spike fixtures:
- `accept_bounty:<npc_id>` — player accepts an NPC's bounty
- `complete_bounty:<npc_id>` — player turns in an NPC's bounty
- `open_vendor:<npc_id>` — player opens shop UI on a vendor NPC
- `reforge:<slot>` — player commits an anvil-keeper reforge

These are conventional only — the controller does not validate verb / target syntax. W2's BountyController defines the canonical list when it lands.

## DialoguePanel modal UI

`scenes/ui/DialoguePanel.tscn` + `scripts/ui/DialoguePanel.gd`. Pure view; reads from `DialogueController`, writes via `advance_line` / `select_response` / `close`. All UI built procedurally in `_ready` (consistent with InventoryPanel pattern).

### CanvasLayer + PANEL_LAYER ordering

`PANEL_LAYER = 90`. InventoryPanel uses `80`. DialoguePanel sits above inventory so a future "dialogue-during-inventory" interaction renders correctly. The controller's single-session guard prevents this today, but the layer ordering future-proofs.

### Input model

Per Uma `visual-direction.md` keyboard-first rule:

| Key | Effect |
|---|---|
| `E` | Advance to next line (controller is the authority — panel forwards unconditionally) |
| `Esc` | Close dialogue immediately |
| `1`–`4` | Quick-select the corresponding response (number prefix shown on each button) |
| `Enter` / `Space` | Activate focused button (Godot built-in `ui_accept`) |
| `Up` / `Down` | Cycle focus across response buttons (Godot built-in) |

**`E` must live in `_input()`, not `_unhandled_input()`.** A focused response Button during the response-prompt phase will swallow alphabetic keys via the GUI focus system before `_unhandled_input` fires. `_input` runs before the GUI focus system. Same trap class as InventoryPanel's Tab toggle — see `html5-export.md` § "Godot input handling order".

### Placeholder portrait

Spike ships a `ColorRect` portrait placeholder. Stratum NPC sprites land in Sub-track 5d (per Priya's W1 brief out-of-scope). Replacing the portrait is a one-field swap (`_portrait.color` → `Sprite2D.texture`).

## Player attack-input gating — pre-emptive convention seed

`Player._dialogue_is_active()` reads `DialogueController.is_active()`. `_process_grounded` returns early on the attack + dodge input branches when a dialogue is active.

**Why this matters.** Without the gate, LMB-clicking a response button would fire both the UI selection AND a player swing. Visually disconcerting + double-fires the player's attack at every dialogue choice. Same input-leak class as the InventoryPanel ticket `86c9xwxhu` flagged by Drew — Sponsor's larger design call on inventory input-gating is in flight; the dialogue gate ships now as the pre-emptive convention seed.

**Movement is intentionally NOT gated.** Player can walk away from a dialogue (Diablo convention — soft abort). Esc is the formal-exit channel. Walking off does NOT auto-close the controller in the spike — that's a behavior decision deferred to the W2 NPC-interaction wiring (NPC owns the proximity check + auto-close).

**Generalization for future modal panels.** Any modal UI that consumes LMB-click input on its surface (response buttons, inventory grid cells, vendor shop entries) should publish an `is_active() -> bool` method on a global controller / autoload. The Player's `_process_grounded` checks the union of those gates and suppresses attack input when ANY is active. The spike establishes the shape with one consumer (`DialogueController`); inventory follows as the Sponsor design call resolves.

## Test surface

**GUT (headless, CI on every push):**

- `tests/test_dialogue_tree_def.gd` — schema smoke, branch resolution, default fallback, unresolvable-returns-null, fixture-load drift pin (branches are `DialogueBranch`, responses are `DialogueResponse`).
- `tests/test_dialogue_controller.gd` — lifecycle pin (open → advance → select → navigate → close), branch resolution + default fallback, quest_action emit-before-navigation, choice-index bounds rejection, single-session guard, unknown-branch closes-with-warning, empty-lines branch presents responses immediately, `is_active()` round-trip drives Player gate.
- `tests/test_dialogue_panel.gd` — panel scene loads, opens on controller signal, closes on controller signal, `_exit_tree` safety closes active session, Player `_dialogue_is_active()` reads controller, panel renders N response buttons for N-response branch.

All three tests use `NoWarningGuard` per `test-conventions.md` § Universal warning gate. The controller routes warnings through `WarningBus.warn(text, "dialogue")` so the guard catches dialogue-resolution regressions automatically.

**Playwright (HTML5 release-build):**

- `tests/playwright/specs/dialogue-spike-smoke.spec.ts` — boot smoke: autoload chain reaches `[Main] M1 play-loop ready`, no `DialogueController.*` warnings, no parser errors on `res://scripts/dialogue/`, no fixture-load failures on `res://resources/dialogue/`.

**No Playwright interactive coverage in the spike.** NPC interaction → dialogue open is W2 wiring scope. The spike's Playwright surface is the warning-gate boot smoke only.

## HTML5 escape-clause eligibility

Per `html5-export.md` § "Visual-verification escape clause":

- **Eligible surface (spike-scope):** schema + autoload + panel UI. All visible elements are `Label` / `Button` / `ColorRect` / `RichTextLabel`. No Polygon2D, CPUParticles2D, Area2D state, modulate-on-leaf-Control tween, negative z_index, or U+2713-class non-ASCII glyphs.

- **Ineligible surface (none in spike):** no tweens, no particles, no Area2D state mutations.

The spike PR's Self-Test Report invokes the escape clause with explicit probe targets routed to Sponsor soak (panel rendering when NPC interaction lands in W2). No pre-merge Sponsor soak required for the spike PR itself because no playable surface depends on the panel rendering.

## What the spike does NOT do (deferred to W2+)

- **No NPC interact wiring.** NPC scenes (`scenes/npcs/NPC_*.tscn`) are not yet given dialogue. Sub-track 5b (hub-town impl) wires `body_entered → DialogueController.open(tree, resolved_quest_state)`.
- **No bounty-state integration.** `DialogueController.open(tree, quest_state)` takes `quest_state` as a parameter; the W2 BountyController resolves `Player.active_bounty` / `Player.completed_bounties` to a `quest_state` value and passes it through.
- **No save persistence.** Active-dialogue session is transient — F5 save mid-dialogue resets on load. Bounty state (the persisted side) flows through `Save` via the bounty system, not via `DialogueController`. Spike-scope acceptable because no playable content depends on mid-dialogue save resume.
- **No TimeScaleDirector integration.** Dialogue does NOT slow-mo the world. Sponsor's SI-2 left the time-scale call open; the spike defers so we don't pin a tonal decision that should be a Uma call. If a future ticket wants slow-mo, register a `TimeScaleDirector` request in `open()` and release in `close()` (NOT `freeze()` — wrong primitive for UI-blocked freeze).
- **No portrait/audio routing.** Portrait is a ColorRect placeholder; no audio cue fires on line-advance or response-select. Uma owns cue authoring; the signal surface (`branch_opened` / `line_displayed` / `response_selected` / `quest_action_invoked`) is the hook the W2 wiring subscribes to.
- **No dialogue tree authoring tooling (Godot editor plugin).** Backlog.
- **No multi-speaker dialogue (NPC ↔ NPC).** Backlog.
- **No voice acting / VO timing primitives.** M5+.

## Cross-references

- `team/priya-pl/post-wave3-sequencing.md` §1 Commitment 2 + §4 W1 pre-shape + §7 R-DIALOGUE
- Ticket `86c9xuab3` — this spike's brief
- Ticket `86c9xwxhu` — InventoryPanel input-leak (the analog the spike's input-gating convention pre-empts)
- `team/uma-ux/hub-town-direction.md` — 3 hub NPCs are first content consumers
- `team/priya-pl/m3-design-seeds.md` §2 — hub NPC roster (Hadda / Brother Voll / Sister Ennick)
- `.claude/docs/audio-architecture.md` — `AudioDirector` parallel autoload pattern
- `.claude/docs/time-scale-director.md` — `TimeScaleDirector` parallel autoload pattern
- `.claude/docs/html5-export.md` § "Godot input handling order" + § "Visual-verification escape clause"
- `.claude/docs/test-conventions.md` § "Universal warning gate"
