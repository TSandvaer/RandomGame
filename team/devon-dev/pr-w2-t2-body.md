# feat(dialogue): production wiring + 3 hub-town trees + QuestActionRouter stub (W2-T2)

**Ticket:** [86c9y0zyv](https://app.clickup.com/t/86c9y0zyv) — W2-T2.
**W1 dialogue spike (parent):** [86c9xuab3](https://app.clickup.com/t/86c9xuab3) — landed via PR #319 (DialogueController + DialoguePanel + 3 spike .tres fixtures + GUT tests).
**Save-survey nit routing:** [PR #320 comment 4519855248](https://github.com/TSandvaer/RandomGame/pull/320) — Drew nit 1+2 folded as Part D below.

## Summary

W2-T2 is the production-wiring layer atop the W1 dialogue spike. Three discrete parts ship in this PR:

- **Part A — Consumer wiring.** `DialoguePanel` is now mounted on `Main.tscn` parallel to `InventoryPanel`. Panel self-subscribes to `DialogueController` from its own `_ready`; the new `_build_dialogue_panel()` in `Main.gd` matches the existing inventory mount pattern. `Player.gd` attack-input gating already lands via the dialogue-only seed in PR #319 + the modal-input-gate generalization in PR #323 — no Player-side change in this PR (the integration surface is already in place).

- **Part B — Three hub-town dialogue trees.** Three new `DialogueTreeDef.tres` resources under `resources/dialogue/hub_town/` for the canonical hub-town NPC trio per `team/priya-pl/m3-design-seeds.md §2`:
    - `hadda_vendor.tres` (`hub_hadda` — merchant)
    - `brother_voll_anvil.tres` (`hub_brother_voll` — smith)
    - `sister_ennick_storyteller.tres` (`hub_sister_ennick` — storyteller / bounty-giver)

    Each tree has 4–7 branches covering the canonical quest-state set (`flavor` / `pre_quest` / `quest_active` / `quest_completed` plus lore-branch interjections), and each carries at least one `quest_action` side-effect emit to exercise the `QuestActionRouter` listener stub. All text is plain ASCII (no Unicode glyphs) per `.claude/docs/html5-export.md` § Default-font glyph coverage.

    **NPC identity decision:** the dispatch brief allowed shipping with placeholder identities + flagging Drew for rename in a follow-up. I picked the canonical roster (Hadda / Brother Voll / Sister Ennick per Priya §2) directly because that roster is already pinned in design docs + integration scenarios (`team/tess-qa/m3-acceptance-plan-tier-3.md` Commitment 2 + Commitment 3 examples). Drew can re-author content if voice/tone needs adjustment, but the npc_ids are stable from this PR forward.

    Note: the W1 spike's `hub_vendor.tres` / `hub_anvil_keeper.tres` / `s1_warden_scholar.tres` (at root `resources/dialogue/`) are LEFT IN PLACE — they remain referenced by `tests/playwright/specs/dialogue-spike-smoke.spec.ts` and the W1-era GUT smoke tests, and removing them would be an unrelated cleanup. The W2 canonical trio lives under `resources/dialogue/hub_town/`.

- **Part C — QuestActionRouter listener stub** (NEW autoload `scripts/quests/QuestActionRouter.gd`). Subscribes to `DialogueController.quest_action_invoked` + `branch_opened` + `dialogue_closed`; records last-event state (`last_quest_action()`, `last_npc_id()`, `last_branch_key()`, `has_received_quest_action()`); emits `quest_action_received` echo signal for test verification. **No bounty-state mutation in this PR** — full `BountyController` integration is W2-T6 (Track 3 quest content).

- **Part D — Drew nit fold (PR #320 review-nit routing per `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.1).**

    - **Nit 1 corrected** — `DialogueController.dialogue_closed` IS single-arg `(npc_id: StringName)`. The survey doc had paper-shaped `(npc_id, branch_key)`. QuestActionRouter handler `_on_dialogue_closed(npc_id: StringName)` reflects the engine truth.
    - **Nit 2 corrected** — `DialogueController.close()` IS no-args. Survey had `close(npc_id, branch_key)`. No router-side impact (we connect a signal handler; we don't author a `close()` caller).
    - **Read-order discipline pinned.** Because `close()` calls `_reset_state()` (clears `_branch_key = &""`) BEFORE emitting `dialogue_closed`, any listener reading `DialogueController.current_branch_key()` from inside `_on_dialogue_closed` gets `&""` — silent regression class. The router design captures `_current_branch_key` continuously via `branch_opened`, snapshots it into `_action_branch_key` at `quest_action_invoked` time (BEFORE controller navigation overwrites `_current_branch_key`), and exposes that snapshot via `last_branch_key()`. The snapshot lives in this autoload's state, NOT the controller's — survives both navigation AND close.

## Files in play

### New files

- `scripts/quests/QuestActionRouter.gd` — listener stub autoload (241 lines).
- `resources/dialogue/hub_town/hadda_vendor.tres` — hub_hadda vendor tree.
- `resources/dialogue/hub_town/brother_voll_anvil.tres` — hub_brother_voll smith tree.
- `resources/dialogue/hub_town/sister_ennick_storyteller.tres` — hub_sister_ennick bounty-giver tree.
- `tests/test_quest_action_router_stub.gd` — autoload + signal capture + last-event pin (6 ACs).
- `tests/test_quest_action_listener_reads_branch_key_before_close.gd` — Drew nit Part D pins (4 ACs: behavioural read-order pin, source-scan pin against `current_branch_key()` in `_on_dialogue_closed`, signal-shape pin on `dialogue_closed` single-arg, method-shape pin on `close()` no-arg).
- `tests/test_dialogue_hub_town_trees.gd` — three hub-town tree smoke-loads + cross-tree invariants (unique-npc_ids, expected-roster, at-least-one-quest_action-per-tree).
- `tests/test_main_dialogue_panel_mounted.gd` — Main mount pin (behavioural + source-scan positional pin on `_ready()` call ordering).
- `tests/playwright/specs/dialogue-hub-town.spec.ts` — boot smoke against W2 autoload + new fixtures + DialoguePanel mount.

### Modified files

- `project.godot` — register `QuestActionRouter` autoload (under `DialogueController` line).
- `scenes/Main.gd` — `DIALOGUE_PANEL_SCENE_PATH` const + `_dialogue_panel` field + `_build_dialogue_panel()` method + `get_dialogue_panel()` accessor + `_build_dialogue_panel()` call in `_ready()` between `_build_inventory_panel()` and `_build_stat_panel()`.

## Cross-lane integration check

Surfaces adjacent to this PR's scope, audited for regression risk:

- **DialogueController autoload (PR #319 spike)** — unchanged. Signal contract preserved (verified by GUT pins on signal arg count). New `QuestActionRouter` subscribes at autoload-ready time; controller is registered earlier in the autoload list so the lookup is safe.
- **DialoguePanel scene (PR #319 spike)** — unchanged. Now mounted on Main.tscn via `_build_dialogue_panel()`; the panel self-subscribes on its own `_ready` (existing pattern from spike).
- **Player.gd modal input gate (PR #323)** — unchanged. `Player._dialogue_is_active()` already reads `DialogueController.is_active()`; no Player-side wiring needed for W2-T2.
- **InventoryPanel (existing)** — `PANEL_LAYER = 80` vs DialoguePanel's `PANEL_LAYER = 90`. No collision; layer ordering future-proofs a "dialogue during inventory" path (single-session guard prevents it today).
- **Save schema** — no save-write site touched. `active_dialogue_states` / `active_bounty` writes are Track 3 W2 + W2-T6 (NOT this PR).
- **CameraDirector / TimeScaleDirector** — no interaction. Per `.claude/docs/dialogue-system.md` § "What the spike does NOT do", dialogue does NOT integrate TimeScaleDirector at spike OR W2 layer (Sponsor's SI-2 deferred the time-scale call).
- **Audio** — no audio cue wired. `audio-architecture.md` HTML5 audio-playback gate does NOT fire on this PR (no `AudioDirector.play_sfx` from dialogue paths).
- **Existing W1 dialogue fixtures (root `resources/dialogue/*.tres`)** — left in place; `dialogue-spike-smoke.spec.ts` + W1 GUT tests still reference them. The W2 canonical trio lives in the new `hub_town/` subdir to avoid the cleanup ripple.

## Regression guard

If this PR's wiring breaks later:

- **Mount removal:** `test_main_dialogue_panel_mounted.gd` pin 2 fails (source-scan on `_build_dialogue_panel()` in `_ready()`).
- **dialogue_closed signal arity change:** `test_quest_action_listener_reads_branch_key_before_close.gd::test_dialogue_closed_signal_is_single_arg` fails (signal-shape pin via `Object.get_signal_list()`).
- **close() method arity change:** `test_quest_action_listener_reads_branch_key_before_close.gd::test_controller_close_is_no_arg` fails (method-shape pin via `Object.get_method_list()`).
- **Router reads branch_key post-close:** source-scan pin asserts `current_branch_key(` is NOT in `_on_dialogue_closed` body. A "simplification" refactor reintroducing the read fails loudly.
- **NPC roster rename:** `test_dialogue_hub_town_trees.gd::test_all_hub_town_trees_match_expected_npc_id_set` fails if an npc_id is renamed without updating the consumer pin.
- **Missing quest_action on a tree:** `test_dialogue_hub_town_trees.gd::test_at_least_one_branch_per_tree_has_a_quest_action` fails (dispatch-brief acceptance pin).

## HTML5 visual-verification escape clause

DialoguePanel's visible primitives are `Label` / `Button` / `ColorRect` / `RichTextLabel` — escape-clause-eligible per `.claude/docs/html5-export.md` § "Visual-verification escape clause" (no Polygon2D / CPUParticles2D / Area2D state / modulate-on-leaf-Control tween). **However, the panel is NOT exercised in production play in this PR** — there are no NPC scenes wired to call `DialogueController.open` yet (W3 sub-track 5b hub-town impl wires NPC interaction). So the only HTML5-visible surface in this PR is the **autoload boot smoke + the `_build_dialogue_panel()` instantiation** (CanvasLayer added to Main, hidden, awaiting signals that don't fire in normal production play).

Self-Test Report (separate comment) documents the author HTML5 release-build self-soak per `html5-visual-gated-author-self-soak` and enumerates probe targets for Sponsor's W3-era soak when NPC interaction lands.

## Out of scope

- **Full BountyController integration.** W2-T6 (Track 3 quest-content) owns it. This PR ships the listener STUB only.
- **NPC scene wiring** (NPC `body_entered` → `DialogueController.open(tree, quest_state)`). W3 sub-track 5b owns hub-town impl + NPC placement.
- **save-schema-v5-tier3 survey doc updates.** Routed to W2-T7 cleanup ticket per `team/priya-pl/post-wave3-sequencing.md` v1.2 §5.1.
- **TimeScaleDirector slow-mo on dialogue open.** Deferred — Sponsor's SI-2 left the call open.
- **Portrait/audio routing.** Uma owns cue authoring; the signal surface from W1 spike is the hook.

## Doc updates

- `.claude/docs/dialogue-system.md` § "What the spike does NOT do" should be amended in a follow-up to note "NPC scene wiring → W3 sub-track 5b" instead of "W2". (Not blocking; reflected in this PR body.)
- `.claude/docs/test-conventions.md` § "Source-scan structural pins" gains a new exemplar — the QuestActionRouter Drew-nit pin uses the same pattern as PR #323's `_modal_is_active()` line-ordering pin. Maintain-docs may capture this.

## ClickUp

`86c9y0zyv` flipped `to do → in progress` at dispatch; will flip `→ ready for qa test` on PR open per `clickup-status-as-hard-gate`.
