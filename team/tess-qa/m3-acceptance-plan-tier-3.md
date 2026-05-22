# M3 Tier 3 Acceptance Plan — Embergrave (Diablo-shape vertical slice)

**Owner:** Tess (QA) · **Phase:** parallel-acceptance scaffold (drafted at M3 Tier 3 W1 day-1, mirrors the `m3-acceptance-plan-tier-1.md` idiom) · **Drives:** Tess sign-off gate for the 5 Tier 3 commitments + W1 spike PRs once they dispatch.

This is the M3 Tier 3 analogue of `team/tess-qa/m3-acceptance-plan-tier-1.md` — per-commitment + per-spike acceptance criteria, edge probes, risk-register linkage, and Self-Test Report obligations, layered onto Priya's `post-wave3-sequencing.md` v1.1 (which locks the Diablo-shape vertical slice with 5 commitments + procgen). **Nothing here ships executable code in this PR**; this is the QA contract Tess flips green when each Tier 3 impl PR reaches `ready for qa test`.

Priya v1.1 (file `team/priya-pl/post-wave3-sequencing.md`) signs SI-1 through SI-5 (Sponsor 2026-05-22) and adds Commitment 5 (randomized maps per character). This scaffold pins the 5-commitment vertical slice + the 4 W1 spikes (camera-scroll / dialogue / zone schema / procgen) it sits on. Rows are marked `[PENDING-SPEC]` where they depend on a W1 spike doc landing (Devon's camera-scroll spike / Devon's dialogue schema / Drew's zone schema / Devon+Drew's procgen spike); the row text locks when each spike doc lands.

## TL;DR

1. **Coverage:** **5 commitments** scaffolded (AC-C1 continuous-scroll camera; AC-C2 dialogue system; AC-C3 quest-driven exploration; AC-C4 world-map UI; AC-C5 randomized maps per character) + **4 W1 spikes** (AC-S1 camera-scroll / AC-S2 dialogue / AC-S3 zone schema / AC-S4 procgen).
2. **Placeholder rows:** **35 commitment-AC rows** (C1: 6, C2: 8, C3: 7, C4: 7, C5: 7) + **16 spike-AC rows** (4 spikes × 4 proof-pillars each) + 3 QA-SCAFFOLD-* meta-rows.
3. **Cross-cutting concerns:** **6** — save-schema additive-only `world_seed` field, AC4 spec regression-pin (M3 Tier 3 changes mustn't break M2 AC4 green), universal-warning gate (every new Tier 3 spec inherits `test-base.ts` fixture per `.claude/docs/test-conventions.md`), drift-pin HARD RULE for engine-emit strings (§17 of `team/tess-qa/playwright-harness-design.md`), HTML5 visual-verification gate for procedural-seam + scroll-transition rendering, journey-probe at Tier 3 RC boundary per `team/TESTING_BAR.md`.
4. **Risk-register linkage (5):** AC-C1 closes R-SCROLL, AC-C2 closes R-DIALOGUE, AC-C4 closes R-MAP, AC-C5 + AC-S4 close R-PROCGEN (3 sub-risks), Sub-track 5a/5d closes R-ART. Each AC row names the risk it closes; Tier 3 RC sign-off requires every named risk closed or explicitly carried forward.
5. **Self-Test Report routing is per-surface, not per-PR.** The HTML5 visual-verification gate splits AC-C1 (scroll-transition + chunk-seam rendering = ineligible for escape clause → pre-merge Sponsor-soak), AC-C2 (modal UI text rendering = renderer-safe primitives → escape clause), AC-C4 (HUD-immune CanvasLayer = renderer-safe → escape clause), and AC-C5 (procedural-seam rendering = ineligible → pre-merge Sponsor-soak). The PR #291 per-surface enumeration precedent applies.
6. **Spec authoring is `test.fail()`-pre-emptive** per AC4 spec convention — Tess can scaffold Tier 3 Playwright specs against the design-doc-stated behavior NOW with `test.fail()` annotations; flip to `test()` when each spike lands the impl.

---

## Source of truth

This acceptance plan validates implementation against:

1. **`team/priya-pl/post-wave3-sequencing.md` v1.1** (Priya, 2026-05-22 amended, `main` HEAD `3a1a3ca`) — the load-bearing source. v1.1 amendment block §1–§8 locks the 5 commitments, the 4 W1 spikes (camera-scroll / procgen / dialogue / zone schema), the 7-10 week calendar shape, R-PROCGEN, the SI-1..SI-5 sign-off, SI-8 procgen-scope open question.
2. **`team/uma-ux/hub-town-direction.md`** (Uma, M3 Tier 1) — the hub-town visual + audio + NPC + descent-portal direction. Hub-town is the canonical between-runs venue the vertical slice routes through; its `HT-01..HT-27` checks (`§11 Tester checklist`) carry forward into Tier 3 as integration-floor checks (the hub-town must keep working under continuous-scroll camera + dialogue system + world-map UI).
3. **`team/drew-dev/level-chunks.md`** § "Why ports, not free-form transitions" + § "Out of scope for M1" + § "Schema decisions" — the chunk + port schema that pre-shapes Commitment 5 (procgen) and Commitment 1 (chunk-stitching for continuous-scroll). `assemble_floor(chunks, zone_def, seed)` is the W1 procgen-spike API target named in `post-wave3-sequencing.md §1` Commitment 5.
4. **`team/devon-dev/save-schema-v5-plan.md`** — the v5 spike that Commitment 5's `world_seed` field rides on top of as an **additive per-character key** (`data.characters[N].world_seed: int`), not a v5-non-additive lift.
5. **`team/tess-qa/m3-acceptance-plan-tier-1.md`** — structural template (M3 Tier 1's scaffold; 27 acceptance rows for 3 pillars). This Tier 3 scaffold mirrors its shape: per-commitment criteria + verification methods + edge probes + integration scenario + Sponsor-soak target + cross-cutting concerns + Sponsor probe targets + risk-register cross-reference.
6. **`team/tess-qa/playwright-harness-design.md` §14, §15, §16, §17** — staleness-bounded latestPos (§14), harness-workaround-fail-loud (§15), `test.fail()` canary semantics (§16), drift-pin HARD RULE for engine-emit strings (§17). All four apply to new Tier 3 specs.
7. **`team/priya-pl/ac4-white-whale-retro.md`** — four structural gaps (sample-size ≥8, instrument-first, retrospective-pause-at-N=3, spec-string-vs-engine-emit drift) that this scaffold inherits from Tier 1 + applies to Tier 3's new spec surfaces.
8. **`team/priya-pl/risk-register.md`** — R-SCROLL / R-DIALOGUE / R-MAP / R-PROCGEN / R-ART. Each Tier 3 AC names the risk it closes; Tier 3 RC sign-off requires all five closed (or explicitly carried forward as M4 deferred risk).
9. **`.claude/docs/test-conventions.md`** — universal warning gate (GUT `NoWarningGuard` + `WarningBus` + Playwright `test-base.ts`). Every new Tier 3 spec MUST import from `test-base`.
10. **`.claude/docs/html5-export.md`** § "HTML5 visual-verification gate" + § "Visual-verification escape clause — honest-disclose + Sponsor-soak routing" + § "When a PR bundles eligible + ineligible surfaces — invoke the clause per-surface" — the per-surface routing precedent from PR #291 governs how Tier 3 PRs invoke the gate.
11. **`.claude/docs/combat-architecture.md`** § "Engine.time_scale interactions" + integration surface — Tier 3's dialogue modal must respect the time-scale director per Tier 1's TimeScaleDirector contract (`.claude/docs/time-scale-director.md`).
12. **`.claude/docs/audio-architecture.md`** § "HTML5 audio-playback gate" — Tier 3 dialogue-open audio cues (UI ticks, NPC voice-stings) must fire after a user gesture; the dialogue-modal first-open is itself a gesture site.

The M1 + M2 + M3 Tier 1/Tier 2 acceptance contracts are the floor. Every Tier 3 acceptance row implicitly carries "and prior milestones' ACs still pass." AC4 green (Playwright `ac4-boss-clear.spec.ts` clean release-build run) is the canonical regression gate for the M2 play-loop and remains so through Tier 3.

---

## §1 — Scope summary

**What M3 Tier 3 delivers** (per `post-wave3-sequencing.md` v1.1 §1 + v1.0 §3 M3 Tier 3 calendar):

> A **2-stratum Diablo-shape vertical slice** (S1 + S2 polished). Sponsor downloads the build, walks through S1 with **continuous-scroll camera**, talks to per-stratum NPCs via the **dialogue system**, accepts an exploration **quest** tied to a named zone, descends to S2 via the **world-map UI**, fights a Sunken Library NPC's quest objective in **procedurally-arranged-per-character** rooms, returns to hub-town to turn in. All with PixelLab character art (not squares), all HTML5-release-build clean.

**Five first-class commitments** locking the vertical slice (`post-wave3-sequencing.md §1`):

- **Commitment 1 — Continuous-scroll camera-follow per stratum.** Rooms become wider-than-screen volumes; `CameraDirector` follow-scroll API + bounds-clamp + `assemble_floor` runtime chunk-stitch.
- **Commitment 2 — Talk-to-NPCs dialogue system.** First-class system, not hub-town flavor. `DialogueTreeDef.tres` schema + `DialogueController` autoload + modal `DialoguePanel.tscn` UI. State-branching by quest state (`pre_quest_offer / quest_active / quest_completed / quest_failed`).
- **Commitment 3 — Quest-driven exploration tied to geography.** Quests reference `zone_id`; `level-chunks.md` schema extends with `ZoneDef` layer (named zones containing chunk sequences); player travels to named zone to solve quest.
- **Commitment 4 — World-map UI.** Per-act (Diablo-II-style) map showing stratum + zones-within-stratum + waypoint travel between visited zones. Evolution of hub-town descent-portal's stratum-picker.
- **Commitment 5 — Randomized maps per character.** Per-character `world_seed: int` (rolled on character creation, additive on v5 save schema); `assemble_floor(chunks, zone_def, seed)` procedurally arranges chunks WITHIN zones between hand-authored anchors (zone entry/exit / NPC rooms / boss rooms / quest-target rooms / story-beat rooms / hub-town).

**Four W1 spikes** the vertical slice sits on (`post-wave3-sequencing.md §3` v1.1 calendar):

- **AC-S1 (camera-scroll spike)** — Devon. `CameraDirector` follow-scroll API extension + bounds-clamp design + first-room HTML5 scroll-transition proof.
- **AC-S2 (dialogue system spike)** — Devon. `DialogueTreeDef.tres` schema design + `DialogueController` autoload sketch + modal `DialoguePanel.tscn` skeleton + 1 proof-of-pattern dialogue tree.
- **AC-S3 (zone schema spike)** — Drew. `level-chunks.md` schema extension proposal: `ZoneDef` layer + anchor-room id taxonomy (`entry / npc_room / boss_room / quest_target / exit / story_beat`).
- **AC-S4 (procgen spike)** — Devon + Drew. `assemble_floor(chunks: Array[LevelChunkDef], zone_def: ZoneDef, seed: int)` impl + per-character `world_seed` save round-trip + hand-authored-anchor composition with procedural fill + HTML5 procedural-seam visual verification.

**What's deferred to M4 / M5:**

- S3-S8 strata content (M5).
- Full bounty roster (M3 ships 3-5 exploration quests; M4 fills to 5-8 archetype-tagged quests).
- Multi-character UI + persistent meta currency + Paragon (M4 per `post-wave3-sequencing.md §3` M4 calendar).
- Per-zone room-tree (world-map pane 3) — M5 polish.

Cross-reference: `team/priya-pl/post-wave3-sequencing.md` v1.1 §1 + §2 + §3 (calendar) + §4 (ticket pre-shape) + §6 (Sponsor-input items).

---

## §2 — Acceptance criteria per commitment

Five commitments. Each has a row group with ID-prefixed criteria, verification methods, edge probes, integration scenario, Sponsor-soak target, and the risk-register entry it closes. Rows tagged `[PENDING-SPEC]` lock when the corresponding W1 spike doc lands.

### Commitment 1 — Continuous-scroll camera-follow per stratum (closes R-SCROLL)

**Risk closed:** R-SCROLL (continuous-scroll architecture risk per `post-wave3-sequencing.md §7` v1.0 — HTML5 z-index seams between chunks, tilemap edge rendering, follow-scroll-bounds-clamp edge cases).

**Acceptance criteria (6):**

- **AC-C1-1 — Camera follows player smoothly across multi-screen chunk-stitched tilemaps.** Player walks east through a wider-than-screen room (e.g. a 3-screen zone); `CameraDirector` follow-scroll keeps player on-screen with no visible jitter, no snap-to-edge, no frame-drop. Verified via paired GUT in `tests/test_camera_director_follow_scroll.gd::test_follow_scroll_smooth_across_chunk_seam` + Playwright spec `tests/playwright/specs/m3-camera-scroll.spec.ts`. **`[PENDING-SPEC]` — gated on AC-S1 camera-scroll spike landing.**
- **AC-C1-2 — Camera clamps at world edges (no out-of-bounds reveal).** When player walks to the west or south edge of a zone, the camera stops scrolling so the room's authored edge is the rightmost/topmost visible pixel — no black-bar reveal, no out-of-bounds tile fragments. Verified via paired GUT in `tests/test_camera_director_follow_scroll.gd::test_camera_clamps_at_world_edge`. **`[PENDING-SPEC]`.**
- **AC-C1-3 — HUD remains screen-space (immune to scroll).** Top-left HP bar, top-right stratum indicator, bottom-center hint-strip, inventory + stash modals — all on screen-space CanvasLayer per PR #293 `CameraDirector` precedent. HUD does NOT scroll with the world. Verified via paired GUT in `tests/test_hud_screen_space.gd::test_hud_immune_to_camera_scroll` + Playwright spec snapshot during scroll motion.
- **AC-C1-4 — No z-index regression on chunk seams.** Between two adjacent chunks (port-mated, e.g. east port of chunk A → west port of chunk B), tile draw-order is consistent: floor < walls < props < mobs < player < HUD. Verified via paired GUT in `tests/test_chunk_seam_zorder.gd::test_no_zorder_regression_at_port` + HTML5 visual-verification screenshot.
- **AC-C1-5 — Scroll-transition rendering passes HTML5 visual-verification gate.** Per `.claude/docs/html5-export.md` § "HTML5 visual-verification gate": the scroll-transition + chunk-seam rendering surface is **ineligible for the escape clause** (touches z-index ordering + tilemap edge draw-order — the failure mode is empirically demonstrated in `html5-export.md` § "Z-index sensitivity"). Pre-merge Sponsor-soak with explicit probe targets is mandatory: "walk east across 3-screen zone, capture no visible chunk seams, confirm HUD stays anchored." **`[PENDING-SPEC]`.**
- **AC-C1-6 — Camera follow-scroll respects `Engine.time_scale`.** During T2 hit-pause (`Engine.time_scale = 0.0`) or T3 phase-transition slow-mo, camera follow-scroll pauses correspondingly (scaled `_process`). Time-scaled scroll behavior matches the `TimeScaleDirector` contract per `.claude/docs/time-scale-director.md`. Verified via paired GUT in `tests/test_camera_director_time_scale.gd::test_scroll_pauses_on_freeze`.

**Verification methods:**

- AC-C1-1..AC-C1-4 + AC-C1-6: paired GUT in `tests/test_camera_director_follow_scroll.gd`, `tests/test_hud_screen_space.gd`, `tests/test_chunk_seam_zorder.gd`, `tests/test_camera_director_time_scale.gd`.
- AC-C1-1 + AC-C1-3 + AC-C1-5: Playwright spec `tests/playwright/specs/m3-camera-scroll.spec.ts` + HTML5 release-build screenshot/video evidence.
- AC-C1-5 specifically: **pre-merge Sponsor-soak** (not post-merge) per per-surface escape-clause precedent (PR #291) — chunk-seam rendering is an empirically-demonstrated HTML5 failure class.

**Edge-case probes (4):**

- **EP-SCROLL-1:** Player teleports to a different zone via waypoint while camera mid-scroll — camera snaps cleanly to the new zone's player spawn position, no scroll-momentum carry-over.
- **EP-SCROLL-2:** Player dies mid-scroll → respawn loads hub-town → camera resets to hub-town's spawn position cleanly (no scroll state leak).
- **EP-SCROLL-3:** Player opens inventory mid-scroll → camera stops at current position (scaled `_process` halts scroll while modal is open per InventoryPanel time-scale wiring); close → scroll resumes from same position.
- **EP-SCROLL-4:** Player walks diagonally into a chunk-port corner (where two ports meet at a corner tile) — port-mating discipline (per `level-chunks.md §"Why ports"`) does NOT produce a visible seam; player traverses smoothly into the adjacent chunk.

**Integration scenario:**

Player loads into S1 via hub-town descent portal. S1's R01 is now a 2-screen-wide room with the entry chunk + a connected exploration chunk. Player spawns at the west port; walks east. Camera follows. At the chunk seam (middle of the room), z-order remains correct (no tile flicker). Player continues east into the second chunk, walks to its east port (exit to R02). Camera clamps at the room's east edge as the transition fires. R02 loads. Camera resets cleanly to R02's spawn.

**Sponsor-soak target:**

**"Does the level read as walking-through, not seeing-at-once?"** Sponsor walks through S1 + S2 with the new camera. Pass: "feels like I'm exploring." Fail: "still feels like rooms-as-tableaux" → camera follow-scroll deadzone or speed needs tuning.

---

### Commitment 2 — Talk-to-NPCs dialogue system (closes R-DIALOGUE)

**Risk closed:** R-DIALOGUE (dialogue-tree engine + modal-input HTML5 quirk risk — net-new system per `post-wave3-sequencing.md §1` Commitment 2).

**Acceptance criteria (8):**

- **AC-C2-1 — Player interact (E) on NPC opens `DialoguePanel.tscn` modal.** Within 1.5-tile proximity per `hub-town-direction.md §3 Common interaction rules` — same shape as hub-town NPC interact. NPC name + portrait + dialogue text + response options render in the modal. Verified via paired GUT in `tests/test_dialogue_controller.gd::test_e_press_opens_panel` + Playwright spec `tests/playwright/specs/m3-dialogue-modal.spec.ts`. **`[PENDING-SPEC]` — gated on AC-S2 dialogue system spike landing.**
- **AC-C2-2 — Dialogue tree branches on quest state.** `DialogueController` reads `Player.active_bounty + Player.completed_bounties` and routes to the correct branch (`pre_quest_offer / quest_active / quest_completed / quest_failed`). Verified via paired GUT in `tests/test_dialogue_tree_traversal.gd::test_branch_selection_by_quest_state` with all 4 branch fixtures. **`[PENDING-SPEC]`.**
- **AC-C2-3 — Response options drive branch traversal.** Selecting a response option (mouse-click or keyboard 1-9 hotkey per Sponsor-input window in `hub-town-direction.md §6 input bindings`) advances to the next dialogue node OR closes the modal (terminal node). Verified via paired GUT in `tests/test_dialogue_tree_traversal.gd::test_response_selection_advances_branch` + Playwright spec for real input. **`[PENDING-SPEC]`.**
- **AC-C2-4 — Esc closes the dialogue modal.** LIFO close stack per `stash-ui-v1.md §1` + `hub-town-direction.md §3`. Verified via paired GUT in `tests/test_dialogue_controller.gd::test_esc_closes_modal`.
- **AC-C2-5 — Dialogue modal pauses gameplay during open.** While modal is open, player cannot move (input gated); mobs do not advance (if dialogue is opened mid-combat — e.g. with a Sister Ennick mid-S2-zone). `TimeScaleDirector` request at `PRIORITY_DEFAULT` scale `0.05` per InventoryPanel migration policy precedent — OR via input-gating only if Devon's spike-spec uses input-gating, not time-scale (lockable at spike landing). Verified via paired GUT in `tests/test_dialogue_controller.gd::test_modal_open_pauses_gameplay`. **`[PENDING-SPEC]`** — gating mechanism locks at spike landing.
- **AC-C2-6 — Dialogue HTML5 modal-input safe.** Per `.claude/docs/html5-export.md` § "Godot input handling order" — keyboard shortcuts that overlap with Godot GUI semantics (Tab for focus-cycle, arrow keys for focus-direction) MUST be handled in `_input()`, not `_unhandled_input()`. Modal response-option keyboard nav (arrow keys + Enter + Esc + 1-9 hotkeys) hits this rule. **`[PENDING-SPEC]`** — locks at spike's input-binding decision.
- **AC-C2-7 — All dialogue text renders cleanly in HTML5 (no tofu boxes).** Per `.claude/docs/html5-export.md` § "Default-font glyph coverage" — dialogue text MUST be plain ASCII OR ship a custom `.ttf` covering the codepoint set. Tier 3 ships 9-15 dialogue trees (3 hub-town NPCs + 6 stratum NPCs per Priya §3 Track 2); all text MUST verify ASCII-clean in HTML5 release-build. Verified via Playwright spec character-by-character snapshot + Sponsor HTML5 spot-check.
- **AC-C2-8 — Dialogue audio cue fires after user gesture.** Per `.claude/docs/audio-architecture.md` § "HTML5 audio-playback gate" — any UI-tick or NPC voice-sting (if Uma direction-doc-amends) MUST fire post-gesture; the modal-open keypress IS a gesture site. No silent-`AudioContext` failures in HTML5. Verified via Sponsor HTML5 soak audible confirmation + `[combat-trace] AudioDirector.play_sfx` trace probe.

**Verification methods:**

- AC-C2-1..AC-C2-5: paired GUT in `tests/test_dialogue_controller.gd` + `tests/test_dialogue_tree_traversal.gd`.
- AC-C2-1 + AC-C2-3 + AC-C2-6 + AC-C2-7: Playwright spec `tests/playwright/specs/m3-dialogue-modal.spec.ts` against HTML5 release-build (real input events, modal-text rendering, HTML5 font-glyph coverage). With drift-pin pair (CC-4 below) for any free-form interpolated trace strings (e.g. `[dialogue-trace] DialogueController.open npc=hadda branch=pre_quest_offer`).
- AC-C2-8: Sponsor HTML5 soak + `[combat-trace] AudioDirector.play_sfx` Playwright probe.
- **HTML5 escape-clause eligibility:** AC-C2's surface is **modal UI text rendering with Label + ColorRect primitives** — renderer-safe per `.claude/docs/html5-export.md` § "Renderer". The escape clause applies (honest-disclose in Self-Test Report + route visual-of-record to Sponsor soak); pre-merge Sponsor-soak is NOT required for dialogue UI text rendering alone. (Per-surface invocation: AC-C2-1..AC-C2-7 invoke the clause; AC-C2-8 routes to Sponsor for audible confirmation regardless.)

**Edge-case probes (5):**

- **EP-DIA-1:** Player opens dialogue → presses Tab → focus does NOT cycle inventory (input gated). Tab MUST be handled in `_input()` not `_unhandled_input()` per `html5-export.md` rule.
- **EP-DIA-2:** Player opens dialogue → mid-conversation, dies (if not gated by AC-C2-5) → respawn handler closes modal cleanly, no orphaned UI state.
- **EP-DIA-3:** Save mid-dialogue (modal open) → quit → reload → modal does NOT re-open on load (dialogue state is ephemeral; only completed-branch state writes to `Player.completed_bounties` etc.). Verified via paired GUT save round-trip.
- **EP-DIA-4:** Player walks away from NPC while modal open → modal stays open (proximity is open-trigger only, not close-trigger). Esc is the canonical close.
- **EP-DIA-5:** Player has 2 NPCs within 1.5 tiles (e.g. hub-town wide-shot where Hadda + Brother Voll overlap proximity) → only the NPC the player faces (or last-approached) opens; press E does NOT open both. Per `hub-town-direction.md §3` proximity rules.

**Integration scenario:**

Player enters hub-town. Hadda's E-glyph appears at 1.5-tile proximity. Player presses E. `DialoguePanel.tscn` opens with Hadda's portrait + name + first-meeting dialogue text + 3 response options ("Show me your wares" / "Tell me about this place" / "Goodbye"). Player selects "Show me your wares" via mouse-click → modal closes → vendor UI opens. Player buys gear, closes vendor, returns to Hadda. E → modal opens with the post-purchase branch ("Anything else?" + same response set minus "Tell me about this place" if already-seen). Player selects "Goodbye" → modal closes.

Later in S1: player walks to wounded scholar NPC at zone entry; E → dialogue opens with `pre_quest_offer` branch (NPC offers "Find my missing satchel in the Sunken Library"). Player accepts → `Player.active_bounty` set → walk to S2 → satchel found → returns to NPC → E → dialogue opens with `quest_completed` branch.

**Sponsor-soak target:**

**"Does the dialogue flow feel right?"** Sponsor talks to all 3 hub-town NPCs + at least 2 stratum NPCs. Pass: "responds to what I've done" + "feels like a real NPC, not a vending machine." Fail: "every NPC sounds the same" or "I can't tell what state I'm in" → Uma direction-amend on tonal differentiation.

---

### Commitment 3 — Quest-driven exploration tied to geography (closes part of R-DIALOGUE + extends R-MAP)

**Risk closed:** partial R-DIALOGUE (quest-state-aware dialogue branching) + extends R-MAP (zone schema is the data layer the map UI consumes).

**Acceptance criteria (7):**

- **AC-C3-1 — Quests bind to zones (logical geography), not pixel coordinates.** Quest `.tres` resource defines `zone_id: StringName` (e.g. `&"s2_z2_reading_chamber"`); quest objective tracking reads zone membership via the assembler's zone tagging, NOT via player-position pixel coordinates. Verified via paired GUT in `tests/test_quest_state.gd::test_zone_binding_is_logical` with multiple zones loaded.
- **AC-C3-2 — Quest content authorable against `ZoneDef` schema.** Drew's W1 zone schema spike (AC-S3) defines `ZoneDef` with `entry_room_id / exit_room_id / npc_room_ids / quest_target_room_id / boss_room_id / story_beat_room_ids` anchor taxonomy. Quest `.tres` resources reference these by id. Verified via paired GUT in `tests/test_zone_def_schema.gd::test_quest_references_zone_anchors` + content audit of S1/S2 quest fixtures. **`[PENDING-SPEC]` — gated on AC-S3.**
- **AC-C3-3 — Quest-state save round-trip.** Quest state (`active_bounty + completed_bounties + quest_objective_progress`) round-trips through v5 save schema (per-character keys, additive on top of v5 multi-character lift). Verified via paired GUT in `tests/test_quest_state_save_roundtrip.gd` + Sponsor soak save-quit-reload at mid-quest.
- **AC-C3-4 — Quest archetypes deliver "exploration" feel, not pure "kill N."** Per `post-wave3-sequencing.md §1` Commitment 3 — at least 3 of the 3-5 M3 Tier 3 quests MUST be exploration-flavored (fetch / find-named-mob / lore-clue), not "kill N of mob X." Verified via content audit at Tier 3 RC.
- **AC-C3-5 — Quest-target room is reachable from zone entry under procgen.** For any quest authored to land in a zone, the procgen assembler MUST place the quest_target anchor such that the player can walk from zone entry → quest_target via the procgen-stitched chunks (no orphaned anchor, no port mismatch). Verified via paired GUT in `tests/test_assemble_floor.gd::test_quest_target_reachable_from_entry` with 8+ seeds. **`[PENDING-SPEC]` — gated on AC-S3 + AC-S4.**
- **AC-C3-6 — Quest dialogue branching consumes Commitment 2 system.** Quest-acceptance + quest-turn-in flow exclusively goes through `DialogueController` modal — no parallel quest-UI surface, no auto-complete on objective. Verified via paired GUT + Playwright spec for accept + turn-in flow.
- **AC-C3-7 — 3-5 exploration quests shipped across S1+S2 at Tier 3 RC.** Per `post-wave3-sequencing.md §3` Track 3 — content fill. Verified via content audit + Sponsor soak walkthrough of all 3-5 quests.

**Verification methods:**

- AC-C3-1..AC-C3-3 + AC-C3-5: paired GUT in `tests/test_quest_state.gd`, `tests/test_zone_def_schema.gd`, `tests/test_quest_state_save_roundtrip.gd`, `tests/test_assemble_floor.gd`.
- AC-C3-6: Playwright spec `tests/playwright/specs/m3-quest-dialogue-flow.spec.ts` against HTML5 release-build (drift-pin paired for `[quest-trace]` strings).
- AC-C3-4 + AC-C3-7: content audit at Tier 3 RC + Sponsor soak walkthrough.

**Edge-case probes (4):**

- **EP-QUEST-1:** Player accepts quest in S1, descends to S2 mid-quest (without turn-in) — quest state preserves; objective progress carries across stratum.
- **EP-QUEST-2:** Player completes quest objective in S2, returns to S1 NPC for turn-in — `quest_completed` branch fires correctly; reward (ember-shards + lore-snippet per `m3-design-seeds.md §3`) applies.
- **EP-QUEST-3:** Player accepts quest A (S2 fetch), then accepts quest B (S2 different zone) — both `active_bounty` slots tracked (per `mvp-scope.md §M3` "one quest active at a time" — confirm Devon's spike whether this is 1 or N quests in flight; row locks at spike landing). **`[PENDING-SPEC]`.**
- **EP-QUEST-4:** Player dies mid-quest in S2, respawns at hub-town, quest state preserved.

**Integration scenario:**

Player visits Sister Ennick in hub-town; E → dialogue opens with `pre_quest_offer` branch: "The vault-forged stokers still burn in S2. The flame demands their quenching. Bring me proof of three. Look for them in the Reading Chamber." Player accepts. `Player.active_bounty = "s2_stoker_purge"`. Walks to descent portal, opens world-map UI, picks S2 → enters S2 zone 1 (Entry Hall) → walks east through scrolled chunks → reaches zone 2 (Reading Chamber per quest binding) → kills 3 Stokers (objective progress 3/3 via mob-died signal → `Player.quest_objective_progress` writes). Returns to hub-town. E on Sister Ennick → `quest_completed` branch fires. Reward: 50 ember-shards + lore-snippet unlocked in `meta.lore_unlocked`.

**Sponsor-soak target:**

**"Does the quest feel like exploration, not chores?"** Sponsor completes 2 quests. Pass: "I went somewhere because of the quest." Fail: "the quest text told me what to kill and I went and killed it" → quest content authoring shift toward fetch / lore-clue / find-named-mob over kill-counts.

---

### Commitment 4 — World-map UI (closes R-MAP)

**Risk closed:** R-MAP (world-map UI architecture risk — net-new UI surface, screen-space CanvasLayer, scaling to 8 strata).

**Acceptance criteria (7):**

- **AC-C4-1 — World-map UI renders zone topology per stratum.** Diablo-II per-act map shape per Sponsor §6 SI-3 sign-off (`post-wave3-sequencing.md §6`). At-current-stratum view shows the stratum's zones as connected nodes; visited zones lit, unvisited zones dimmed. Verified via paired GUT in `tests/test_world_map_ui.gd::test_renders_zone_topology` + Playwright spec for HTML5.
- **AC-C4-2 — World-map shows discovery state correctly.** `Player.discovered_zones: Dictionary[String, bool]` (additive v4+/v5 save schema) drives lit/dimmed state. Verified via paired GUT save round-trip + per-zone discovery test cases. **`[PENDING-SPEC]` — gated on Devon's save-field landing.**
- **AC-C4-3 — Waypoint travel between visited zones works.** Selecting a visited zone via mouse-click or keyboard nav → confirms → teleports player to that zone's entry port. Unvisited zones are not selectable. Verified via paired GUT in `tests/test_waypoint_travel.gd::test_travel_to_visited_zone` + Playwright spec.
- **AC-C4-4 — World-map UI is HUD-immune (screen-space CanvasLayer).** No scroll, no z-index regression vs world tilemap. Verified via paired GUT in `tests/test_world_map_screen_space.gd::test_map_immune_to_camera_scroll`.
- **AC-C4-5 — World-map renders cleanly in HTML5 (no tofu, no Polygon2D).** Per `.claude/docs/html5-export.md`: any map node/edge graphics MUST use ColorRect / NinePatchRect / `_draw()` arcs, NOT Polygon2D. Any custom icons use plain ASCII Labels OR a custom `.ttf`. Per-surface escape clause applies (renderer-safe primitives → escape clause + Sponsor visual-of-record).
- **AC-C4-6 — World-map UI scales to 8 strata without layout collapse.** Tier 3 ships S1+S2 view, but the UI architecture MUST not produce visual collapse at 8 strata (M5 endpoint). Verified via paired GUT with 8-stratum fixture + visual inspection at design-time. **`[PENDING-SPEC]` — gated on Devon's spike layout decision.**
- **AC-C4-7 — Descent-portal evolves into world-map gate.** Per `hub-town-direction.md §4`, the descent-portal's stratum-picker is the minimal map. Tier 3 ships the expanded world-map UI behind the same Down-arrow keypress + portal proximity gate. No new keybinding. Verified via Playwright spec + Sponsor soak.

**Verification methods:**

- AC-C4-1..AC-C4-4 + AC-C4-6: paired GUT.
- AC-C4-1 + AC-C4-3 + AC-C4-5 + AC-C4-7: Playwright spec `tests/playwright/specs/m3-world-map.spec.ts` + drift-pin pair for `[map-trace]` strings.
- AC-C4-5: per-surface escape clause — renderer-safe primitives → Sponsor visual-of-record via soak (NOT pre-merge sponsor-soak — the visual gate is satisfied by escape-clause + probe-target enumeration in Self-Test Report).

**Edge-case probes (3):**

- **EP-MAP-1:** Player opens world-map mid-combat (e.g. by accidentally hitting Down arrow near portal) → map opens; combat pauses (input gate); close → combat resumes cleanly.
- **EP-MAP-2:** Player has discovered 0 zones in S2 → S2 view shows S2 entry node only; all other zones grey/inaccessible.
- **EP-MAP-3:** Player teleports via waypoint mid-quest (with active quest objective in target zone) → quest objective progress preserved; arrival at target zone fires the same room-load events as walking-in (no skip-load bugs).

**Integration scenario:**

Player at hub-town descent portal. Presses Down arrow. World-map opens. Stratum list pane shows S1 (lit, completed) + S2 (lit, visited) + S3-S8 (dimmed, locked). Player selects S2. Zone list pane shows S2 zones: Entry Hall (lit, visited) + Reading Chamber (lit, visited, current quest target) + Archive Vault (dimmed, unvisited) + Inner Sanctum (locked). Player clicks Reading Chamber → confirms → teleports to Reading Chamber's entry port. Quest objective tracking unchanged; Stoker kill-count progress preserved.

**Sponsor-soak target:**

**"Can I navigate the world without confusion?"** Sponsor uses the map to descend, travel, return. Pass: "I always know where I am." Fail: "I got lost in the menus" → Uma direction-amend on map visual style.

---

### Commitment 5 — Randomized maps per character (closes R-PROCGEN)

**Risk closed:** R-PROCGEN (all three sub-risks per `post-wave3-sequencing.md §7` v1.1 — R-PROCGEN.a seed-binding bugs, R-PROCGEN.b chunk-port mating gaps, R-PROCGEN.c HTML5 `gl_compatibility` procedural-seam rendering divergence).

**Acceptance criteria (7):**

- **AC-C5-1 — Per-character `world_seed` deterministically produces same map on reload.** Character A with `world_seed=12345` always sees the same S1 R01 chunk arrangement across save → quit → load → re-enter cycles. Verified via paired GUT in `tests/test_procgen_determinism.gd::test_same_seed_same_layout` with 8+ load cycles.
- **AC-C5-2 — Different characters in same save produce different maps.** Character B with `world_seed=67890` sees a different S1 R01 chunk arrangement than Character A (verified across at least 3 stratum entry rooms; with very high seed entropy the probability of identical layouts is negligibly small per Devon's spike). Verified via paired GUT in `tests/test_procgen_determinism.gd::test_different_seed_different_layout`.
- **AC-C5-3 — Hand-authored anchors compose correctly with procedural fill.** Zone entry/exit + NPC rooms + boss rooms + quest-target rooms + story-beat rooms render at deterministic positions (NOT seed-dependent); only the procedural slots between them vary by seed. Verified via paired GUT in `tests/test_assemble_floor.gd::test_anchors_deterministic_across_seeds` + spec assertion that anchor positions are identical across N=8 seeds. **`[PENDING-SPEC]` — gated on AC-S4.**
- **AC-C5-4 — Per-stratum seeds isolated.** `stratum_seed = hash(world_seed, stratum_id)` — re-rolling S1 layout does NOT leak into S2 layout for the same character. Verified via paired GUT in `tests/test_procgen_seed_derivation.gd::test_per_stratum_seeds_isolated`. **`[PENDING-SPEC]`.**
- **AC-C5-5 — Per-zone seeds isolated.** `zone_seed = hash(stratum_seed, zone_id)` — re-entering a zone within a run produces the same layout (no re-roll on zone-load); a different zone produces independent layout. Verified via paired GUT in `tests/test_procgen_seed_derivation.gd::test_per_zone_seeds_isolated`. **`[PENDING-SPEC]`.**
- **AC-C5-6 — `world_seed` save round-trip preserves bit-identical across all save operations.** Save → load preserves `data.characters[N].world_seed: int` bit-identical. Additive on top of v5 per-character keys (`save-schema-v5-plan.md` reference). No migration step required (additive field; default value rolled at character creation). Verified via paired GUT in `tests/test_save_world_seed_roundtrip.gd::test_world_seed_bit_identical`.
- **AC-C5-7 — Chunk-seam rendering passes HTML5 visual-verification.** Per `.claude/docs/html5-export.md` § "Z-index sensitivity" + § "Burst contrast against high-hue-saturation same-z sprites" — chunk seams between procedurally-placed chunks are an HTML5 rendering risk class. **Pre-merge Sponsor-soak with concrete probe targets is mandatory** (per-surface escape-clause INELIGIBLE — empirical failure mode demonstrated). Probe targets: "walk across 5+ procedural seams in S1 and S2, capture screenshot at each seam, confirm no visible tile gap or z-order regression." Per `post-wave3-sequencing.md §3` W6-W7 dedicated HTML5 procedural-seam Sponsor-soak round. **`[PENDING-SPEC]`** — locks at W2 impl landing.

**Verification methods:**

- AC-C5-1..AC-C5-6: paired GUT in `tests/test_procgen_determinism.gd`, `tests/test_assemble_floor.gd`, `tests/test_procgen_seed_derivation.gd`, `tests/test_save_world_seed_roundtrip.gd`.
- AC-C5-1 + AC-C5-2 + AC-C5-3 + AC-C5-7: Playwright spec `tests/playwright/specs/m3-procgen-determinism.spec.ts` (release-build determinism + HTML5 rendering probe) + drift-pin pair for `[procgen-trace]` strings.
- AC-C5-7 specifically: **pre-merge Sponsor-soak** (per `post-wave3-sequencing.md §3` v1.1 W6-W7 dedicated round); concrete probe-target enumeration per `html5-export.md` per-surface escape-clause precedent.
- **Sample-size discipline N≥8** for AC-C5-1, AC-C5-2, AC-C5-3 per AC4-retro Gap 1 (Lesson 1 below). Self-Test Report must cite ≥8 release-build seed-trial runs.

**Edge-case probes (5):**

- **EP-PROCGEN-1:** Character with `world_seed = 0` → assembler produces a valid (non-degenerate) layout. The 0-seed case must NOT be a special case OR null-deflate path.
- **EP-PROCGEN-2:** Character with `world_seed = INT64_MAX` → assembler does NOT overflow the hash derivation; same-seed determinism still holds.
- **EP-PROCGEN-3:** Zone with only 1 procedural slot between 2 anchors → assembler does NOT fail to place; produces a valid 1-chunk fill.
- **EP-PROCGEN-4:** Zone with 0 procedural slots (anchors only) → assembler produces anchor-only layout; quest-target reachability still holds via direct anchor port chain.
- **EP-PROCGEN-5:** Procedurally selected chunk's port count > zone's available connection slots → assembler rejects the chunk + falls back to a port-compatible chunk; no silent broken-port-mate.

**Integration scenario:**

Player creates Character A on M3 Tier 3 RC. `world_seed = 12345` rolled at creation, written to save. Player enters S1: assembler computes `s1_seed = hash(12345, "s1")`; loads `s1_z1_entry_hall` zone; places entry anchor (deterministic), NPC anchor (deterministic), exit anchor (deterministic); fills 3 procedural slots via seeded chunk selection. Player walks through, kills mobs, picks up loot. Saves + quits. Reloads. Same zone, same layout (AC-C5-1). Travels to S2: independent `s2_seed = hash(12345, "s2")` produces independent S2 layout (AC-C5-4). 

Player creates Character B in slot 1. `world_seed = 67890`. Same S1 entry hall, **different procedural chunk fill** between the same anchors (AC-C5-2). Anchors land at same room positions; procedural slots produce different chunks → different mob spawn points → different loot drop locations.

**Sponsor-soak target:**

**"Does the per-character map randomization feel meaningful?"** Sponsor creates 2 characters and walks the same first zone with both. Pass: "I noticed the layouts are different." Fail: "the maps feel identical" → procgen variance too low; chunk pool needs widening. Also: **"do procedural chunk seams render cleanly?"** — primary HTML5 risk gate.

---

## §3 — Acceptance criteria per W1 spike

Four W1 spikes. Each has a "spike pass" definition: what proof the spike must deliver before W2/W3 dispatch unblocks.

### AC-S1 — Camera-scroll spike (Devon, W1)

**Spike-pass definition:** Devon ships a design doc + a proof-of-concept branch that demonstrates `CameraDirector.follow_scroll(target)` extending the existing zoom + HUD-immunity contract (PR #293 precedent) with smooth follow + bounds-clamp on a wider-than-screen test room.

**Acceptance criteria (4):**

- **AC-S1-1 — Design doc lands at `team/devon-dev/camera-scroll-spike.md`** with: API extension proposal, bounds-clamp algorithm, deadzone/follow-speed parameters, HTML5 visual-verification plan, cross-references to `level-chunks.md` § "Why chunks" + `visual-direction.md` § "Camera".
- **AC-S1-2 — Proof-of-concept branch demonstrates follow-scroll on a wider-than-screen test room.** Branch (e.g. `devon/m3w1-camera-scroll-spike`) loads a 2-screen-wide test room; player walks east; camera follows; no visible jitter; bounds-clamp at room edges.
- **AC-S1-3 — HTML5 release-build of the spike branch demonstrates the same follow + clamp behavior under `gl_compatibility`.** Self-Test Report includes release-build screenshots + scroll-traversal screen-recording. Confirms no HTML5-specific scroll-rendering divergence (z-order at chunk seam, edge-clamp visual artifacts).
- **AC-S1-4 — Spike identifies HTML5 risks for the W2 impl.** Doc enumerates concrete HTML5 risks (z-index seam class, tilemap edge rendering, `Engine.time_scale` interaction with scroll) so W2 impl pre-mitigates rather than discovers.

### AC-S2 — Dialogue system spike (Devon, W1)

**Spike-pass definition:** Devon ships a design doc + a proof-of-concept branch with `DialogueTreeDef.tres` schema, `DialogueController` autoload skeleton, and one working dialogue tree against a hub-town NPC (Hadda — simplest case).

**Acceptance criteria (4):**

- **AC-S2-1 — Design doc lands at `team/devon-dev/dialogue-system-spike.md`** with: `DialogueTreeDef.tres` schema, `DialogueController` autoload API surface, modal `DialoguePanel.tscn` design, branch-selection algorithm (quest-state-aware), input-gating-vs-time-scale decision, HTML5 modal-input safety plan.
- **AC-S2-2 — Proof-of-concept branch has one working dialogue tree against Hadda.** Branch demonstrates: E-press opens modal, response selection advances branch, Esc closes modal. Hub-town integration is not required for spike pass; a synthetic test scene is acceptable.
- **AC-S2-3 — Schema validation: `DialogueTreeDef.tres` validates with all 4 quest-state branches.** Test fixture covers `pre_quest_offer / quest_active / quest_completed / quest_failed` branches. Paired GUT pin asserts the schema's required keys.
- **AC-S2-4 — HTML5 modal-input keyboard nav safety plan documented.** Doc cites `.claude/docs/html5-export.md` § "Godot input handling order" and pins `_input()` (not `_unhandled_input()`) for Tab + arrow-key handling.

### AC-S3 — Zone schema spike (Drew, W1)

**Spike-pass definition:** Drew ships a design doc extending `level-chunks.md` schema with `ZoneDef` + anchor-room id taxonomy, plus a content fixture demonstrating S1's first zone authored against the new schema.

**Acceptance criteria (4):**

- **AC-S3-1 — Design doc amends `team/drew-dev/level-chunks.md`** with new § "Zones" covering: `ZoneDef.tres` schema (anchor room ids, procedural slot count, allowed chunk-types per slot, quest-binding hooks), authoring guide for content team, validation rules.
- **AC-S3-2 — Schema validation gate: `ZoneDef.tres` `validate()` method enforces invariants.** Paired GUT pins: (a) anchor ids unique within zone, (b) entry + exit anchors mandatory, (c) at least one procedural slot OR explicit "no procedural fill" flag, (d) all referenced chunk-types exist in registry.
- **AC-S3-3 — Content fixture: `resources/zones/s1_z1_entry_hall.tres` lands.** First zone authored against the new schema; serves as the template for content team's M3 Tier 3 W2-W5 zone authoring.
- **AC-S3-4 — Spike identifies quest-binding integration surface.** Doc enumerates how Commitment 3's quest `.tres` resources reference `zone_id` (StringName) and how `quest_target_room_id` (per zone) drives quest-objective tracking.

### AC-S4 — Procgen spike (Devon + Drew, W1)

**Spike-pass definition:** Devon + Drew jointly ship a proof-of-concept branch demonstrating `assemble_floor(chunks, zone_def, seed)` composing hand-authored anchors with procedural fill, with per-character seed round-trip and HTML5 procedural-seam rendering validation.

**Acceptance criteria (4):**

- **AC-S4-1 — Per-character seed binding round-trip proof.** Character creation rolls `world_seed`; save round-trips it bit-identical; load reads it; assembler consumes it; same character → same map across 8+ load cycles. Paired GUT in `tests/test_procgen_spike_roundtrip.gd::test_seed_roundtrip_8_cycles`. **Sample-size discipline N≥8** per AC4-retro Gap 1.
- **AC-S4-2 — Hand-authored anchors compose with procedural fill correctly.** Zone schema (AC-S3 dep) defines anchors by id; assembler places anchors first (deterministic), then fills slots with seed-selected chunks. Port-mating discipline (per `level-chunks.md` § "Why ports") ensures no broken seams. Quest-target reachability from zone-entry verified (AC-C3-5 dep).
- **AC-S4-3 — Chunk-port mating at procedural seams renders cleanly under continuous-scroll camera under HTML5 `gl_compatibility`.** Self-Test Report includes release-build screenshots at 8+ procedural seams across S1's first zone; no visible tile gaps, no z-index regression, no draw-order seams. **Visual-verification gate per `.claude/docs/html5-export.md` is mandatory; Sponsor-soak with concrete probe targets per the per-surface escape clause INELIGIBLE — pre-merge Sponsor-soak required.**
- **AC-S4-4 — Spike identifies fallback path if HTML5 regression is unworkable.** Doc cites `post-wave3-sequencing.md §6` SI-8 option (c) hybrid fallback: S1+S2 ship with hand-pinned chunks inside zones (no procedural fill, but per-character seed still drives anchor selection from a hand-authored pool). Fallback is documented BEFORE the spike pass so W2 dispatch can pivot cleanly if needed.

---

## §4 — Risk register cross-reference

Per `team/priya-pl/risk-register.md` and `post-wave3-sequencing.md §7`, the Tier 3 risk surface has 5 active entries. Each AC item closes a specific risk; Tier 3 RC sign-off requires every named risk closed (or explicitly carried forward to M4 as a deferred mitigation).

| Risk | Probability | Impact | Closed by AC items | Status at Tier 3 RC |
|---|---|---|---|---|
| **R-SCROLL** (continuous-scroll architecture / HTML5 seam) | med | high | AC-C1-1..AC-C1-6 + AC-S1-1..AC-S1-4 | Closed if all 6 + 4 rows green |
| **R-DIALOGUE** (dialogue-tree engine + modal-input HTML5 quirk) | med | high | AC-C2-1..AC-C2-8 + AC-S2-1..AC-S2-4 + AC-C3-6 | Closed if all 8 + 4 + 1 rows green |
| **R-MAP** (world-map UI architecture / 8-stratum scaling) | med | med | AC-C4-1..AC-C4-7 | Closed if all 7 rows green |
| **R-PROCGEN.a** (per-character seed-binding bugs) | med | high | AC-C5-1 + AC-C5-2 + AC-C5-6 + AC-S4-1 | Closed if all 4 rows green |
| **R-PROCGEN.b** (chunk-port mating gaps at procedural seams) | med | high | AC-C5-3 + AC-S4-2 + AC-S4-3 | Closed if all 3 rows green |
| **R-PROCGEN.c** (HTML5 `gl_compatibility` procedural-seam rendering divergence) | med | high | AC-C5-7 + AC-S4-3 + AC-S4-4 (fallback documented) | Closed if green OR fallback (SI-8 option c) invoked |
| **R-ART** (PixelLab art-pass quality / per-character / per-stratum) | med | med | Sub-track 5a/5d HTML5 sprite-swap (engineering acceptance per `m3-acceptance-plan-tier-1.md §3`); existing per-mob hit-flash GUT pins re-run + HTML5 visual-verification + daltonization re-run | Closed if all 9 character sprites swapped + Sponsor soak passes |

**Risk-closure gate:** at Tier 3 RC boundary (post-W6-W7 Sponsor-soak round per `post-wave3-sequencing.md §3` v1.1), Tess audits which risks are closed vs carried forward. If any R-PROCGEN sub-risk is open, Tier 3 RC blocks until either (a) closure achieved or (b) Sponsor signs SI-8 option (c) hybrid fallback. The R-PROCGEN.c HTML5-seam risk is the highest-leverage gate.

---

## §5 — Self-Test Report obligations

Per `html5-visual-gated-author-self-soak` memory + `.claude/docs/test-conventions.md` § "Author HTML5 self-soak" + `.claude/docs/html5-export.md` § "Visual-verification escape clause — honest-disclose + Sponsor-soak routing" — Self-Test Report obligations vary per-surface, not per-PR.

**Per-PR routing matrix:**

| Surface | HTML5-visual-gated? | Author self-soak required? | Pre-merge Sponsor-soak required? | Escape clause eligible? |
|---|---|---|---|---|
| AC-C1 scroll-transition + chunk-seam (Commitment 1) | YES (z-index ordering class) | YES | **YES** | NO — empirical failure mode in `html5-export.md` |
| AC-C2 modal UI text rendering (Commitment 2) | YES (Label + ColorRect = renderer-safe) | YES | NO | YES — invoke per-surface |
| AC-C2-8 dialogue audio cue | YES (HTML5 AudioContext gate) | YES (audible self-confirm) | NO | YES — invoke per-surface |
| AC-C3 quest-state save round-trip (Commitment 3) | NO (engine-side data only) | NO | NO | N/A (no visual surface) |
| AC-C3 quest dialogue branching | Inherits AC-C2 surface | YES (per AC-C2) | NO | YES — per AC-C2 |
| AC-C4 world-map UI rendering (Commitment 4) | YES (renderer-safe primitives) | YES | NO | YES — invoke per-surface |
| AC-C4 waypoint travel (zone teleport) | NO (engine-side state + scene-load) | NO | NO | N/A |
| AC-C5 procedural-seam rendering (Commitment 5) | YES (chunk-port mating + z-index class) | YES | **YES** | NO — empirical failure mode in `html5-export.md` |
| AC-C5 per-character seed save round-trip | NO (engine-side data only) | NO | NO | N/A |
| AC-S1 camera-scroll spike | Inherits AC-C1 | YES | YES (for spike-pass) | NO |
| AC-S2 dialogue system spike | Inherits AC-C2 | YES | NO | YES |
| AC-S3 zone schema spike | NO (schema-doc only) | NO | NO | N/A |
| AC-S4 procgen spike | Inherits AC-C5 | YES | **YES** (for spike-pass) | NO |

**Self-Test Report mandatory sections (per HTML5-visual-gated PR):**

1. **Release artifact link** — the exact build the author soaked.
2. **BuildInfo SHA verification line** from DevTools console.
3. **Visual behavior observed** — screenshot or text description of what the author saw in browser. For ineligible-escape-clause surfaces (AC-C1-5, AC-C5-7, AC-S1-3, AC-S4-3), screenshot is mandatory; for eligible-escape-clause surfaces (AC-C2, AC-C4, AC-S2), honest-disclose + probe-target enumeration acceptable per the precedent.
4. **Trace excerpts** from DevTools console (`[combat-trace]`, `[dialogue-trace]`, `[procgen-trace]`, `[map-trace]`, `[quest-trace]`).
5. **Pass/fail call:** did the visual match the design intent in the actual browser?

**Sample-size discipline N≥8** (per AC4-retro Gap 1, Lesson 1) applies to stochastic-cost surfaces:

- **AC-C5-1 / AC-C5-2** per-character seed determinism → **N≥8 release-build seed-trial runs** required in Self-Test Report.
- **AC-C5-3** anchor-procgen composition → **N≥8 seeds** verifying anchors at deterministic positions.
- **AC-S4-1** seed round-trip → **8+ load cycles** in spike's Self-Test Report.
- **AC-C1** continuous-scroll smoothness → N≥8 traversals across chunk seams (clock-time + frame-rate assertion non-deterministic).
- Any Playwright spec authored against hypothesis (without prior diagnostic-trace baseline) → **N≥8 runs** required.

Tess REQUEST CHANGES bar: Self-Test Report citing fewer than 8 release-build runs for any of the above is REQUEST CHANGES, citing `TESTING_BAR.md` § "Statistical bar for stochastic-cost specs" (codification pending per Tier 1 acceptance plan).

**CLI-agent unsoakable surfaces (per PR #300 finding):** if an author cannot interactively drive the game to the target surface (e.g. dialogue-tree branch only reachable after 30+ min of S2 traversal), the Self-Test Report includes a "Structural soak blocker" section per `test-conventions.md` § "Edge case — CLI-agent unsoakable surfaces" + proposes one of: (A) Sponsor manual soak, (B) follow-up tooling PR (`?start_room=N` URL-param), (C) renderer-safety escape clause. Orchestrator surfaces the choice to Sponsor.

---

## §6 — Playwright + GUT coverage expectations

Per `m3-acceptance-plan-tier-1.md §6` shape. For each AC, the test-class is mandatory unless explicitly waived. **Drift-pin pairs are mandatory** for any Playwright spec asserting on free-form `<noun>=<value>` engine-emit strings (per CC-4 below).

| AC | Mandatory test class | Optional / Sponsor-only |
|---|---|---|
| AC-C1-1 (camera follow-scroll smooth) | Paired GUT + Playwright | — |
| AC-C1-2 (bounds clamp) | Paired GUT | — |
| AC-C1-3 (HUD screen-space) | Paired GUT + Playwright snapshot | — |
| AC-C1-4 (no z-order regression at seams) | Paired GUT + HTML5 screenshot | — |
| AC-C1-5 (HTML5 scroll-transition gate) | HTML5 release-build + **pre-merge Sponsor-soak** | — |
| AC-C1-6 (camera respects time-scale) | Paired GUT | — |
| AC-C2-1 (E opens dialogue modal) | Paired GUT + Playwright | — |
| AC-C2-2 (branch on quest state) | Paired GUT (4 fixtures) | — |
| AC-C2-3 (response options drive branch) | Paired GUT + Playwright | — |
| AC-C2-4 (Esc closes modal) | Paired GUT | — |
| AC-C2-5 (modal pauses gameplay) | Paired GUT | — |
| AC-C2-6 (HTML5 modal-input safe) | Playwright (Tab + arrow + Enter + Esc + 1-9) | Sponsor HTML5 spot-check |
| AC-C2-7 (dialogue text ASCII-clean) | Playwright snapshot per dialogue tree | Sponsor HTML5 spot-check |
| AC-C2-8 (audio cue post-gesture) | Playwright `[combat-trace] play_sfx` probe + Sponsor audible | — |
| AC-C3-1 (quest binds to zones logically) | Paired GUT | — |
| AC-C3-2 (quest content authorable) | Paired GUT + content audit | — |
| AC-C3-3 (quest-state save roundtrip) | Paired GUT save roundtrip | Sponsor soak |
| AC-C3-4 (exploration feel) | Content audit at RC | Sponsor soak |
| AC-C3-5 (quest-target reachable under procgen) | Paired GUT (8+ seeds) | — |
| AC-C3-6 (quest dialogue branching) | Paired GUT + Playwright | — |
| AC-C3-7 (3-5 quests shipped) | Content audit | Sponsor soak |
| AC-C4-1 (world-map renders zone topology) | Paired GUT + Playwright | — |
| AC-C4-2 (world-map shows discovery state) | Paired GUT save roundtrip | — |
| AC-C4-3 (waypoint travel) | Paired GUT + Playwright | — |
| AC-C4-4 (world-map HUD-immune) | Paired GUT | — |
| AC-C4-5 (HTML5 clean) | Playwright + escape-clause Sponsor visual-of-record | — |
| AC-C4-6 (scales to 8 strata) | Paired GUT (8-stratum fixture) | — |
| AC-C4-7 (descent-portal evolves) | Playwright + Sponsor soak | — |
| AC-C5-1 (same seed same layout) | Paired GUT (N≥8 cycles) + Playwright | — |
| AC-C5-2 (different seed different layout) | Paired GUT (N≥8 trials) | Sponsor 2-char soak |
| AC-C5-3 (anchors compose correctly) | Paired GUT (N≥8 seeds) | — |
| AC-C5-4 (per-stratum seeds isolated) | Paired GUT | — |
| AC-C5-5 (per-zone seeds isolated) | Paired GUT | — |
| AC-C5-6 (world_seed save roundtrip) | Paired GUT save roundtrip | — |
| AC-C5-7 (chunk-seam HTML5 render clean) | HTML5 release-build + **pre-merge Sponsor-soak** | — |
| AC-S1 spike pass | Devon design doc + spike branch HTML5 demo + paired GUT proof tests | — |
| AC-S2 spike pass | Devon design doc + 1 working dialogue tree + paired GUT schema validation | — |
| AC-S3 spike pass | Drew design doc amendment + `ZoneDef.validate()` GUT pin + `s1_z1_entry_hall.tres` fixture | — |
| AC-S4 spike pass | Devon+Drew spike branch + paired GUT N≥8 round-trip + HTML5 release-build + **pre-merge Sponsor-soak** | — |

**Drift-pin pair (CC-4) gate:** any new Playwright spec asserting on a `<noun>=<value>` regex from an interpolated engine `StringName` / `String` MUST be paired with a `tests/test_*_trace_string_contract.gd` GUT pin. Per Tier 3, this applies to:

- `[dialogue-trace]` strings (`npc=`, `branch=`, `response=`).
- `[quest-trace]` strings (`quest_id=`, `objective=`, `state=`).
- `[procgen-trace]` strings (`seed=`, `chunk_id=`, `zone_id=`).
- `[map-trace]` strings (`stratum=`, `zone=`, `action=`).
- `[camera-trace]` strings if Devon ships them (`mode=`, `state=`, `target=`).

Tess REQUEST CHANGES bar: any Tier 3 Playwright spec without a paired drift-pin is REQUEST CHANGES.

---

## §7 — Cross-references

### Priya's sequencing + risk plans
- `team/priya-pl/post-wave3-sequencing.md` (v1.1, 2026-05-22 amended; `main` HEAD `3a1a3ca`) — the canonical Tier 3 sequencing source. §1 (commitments + Commitment 5), §2 (vertical slice scope), §3 (calendar 7-10 weeks), §4 (ticket pre-shape), §6 (Sponsor-input items SI-1..SI-5 signed + SI-8 open), §7 (R-PROCGEN new), §8 (cross-references).
- `team/priya-pl/risk-register.md` — R-SCROLL / R-DIALOGUE / R-MAP / R-PROCGEN (a/b/c) / R-ART entries; this scaffold's §4 maps AC items to risks.
- `team/priya-pl/ac4-white-whale-retro.md` — four structural gaps inherited as cross-cutting concerns (CC-3 universal warning gate, CC-4 drift-pin HARD RULE, Lesson 1 N≥8 sample-size, Lesson 2 instrument-first, Lesson 3 N=3 retrospective-pause, Lesson 4 drift-pin).
- `team/priya-pl/m3-design-seeds.md` §4 — vertical-slice scope-cut framing the milestone shape inherits.
- `team/priya-pl/m3-tier-1-plan.md` — Tier 1 scaffold this Tier 3 scaffold mirrors structurally.
- `team/priya-pl/m3-tier2-boss-room-polish-scope.md` — Tier 2 closure status.
- `team/priya-pl/mvp-scope.md` §M3 — content contract for the milestone.

### Uma's design direction
- `team/uma-ux/hub-town-direction.md` — between-runs venue locked; hub-town's `HT-01..HT-27` checks (§11) carry forward as Tier 3 integration-floor checks.
- `team/uma-ux/visual-direction.md` § "Internal canvas + scaling rules" + § "Camera" + § "Stratum visual progression" — current locks; Commitment 1 camera-scroll amendment is the spike's amendment surface.
- `team/uma-ux/audio-direction.md` §1+§2+§3 — dark-folk-chamber ensemble + cue list + ducking + bus assignment; Tier 3 dialogue-modal duck pattern inherits from `stash-ui-v1.md §1` panel-open duck.
- `team/uma-ux/palette.md` + `team/uma-ux/palette-stratum-2.md` — hex doctrine that S1 + S2 art-pass conforms to.
- `team/uma-ux/stash-ui-v1.md` §1 — between-runs venue rules + LIFO close stack + B+Tab+Esc input bindings; dialogue-modal Esc-close inherits.

### Drew's engineering direction
- `team/drew-dev/level-chunks.md` § "Why chunks" + § "Why ports, not free-form transitions" + § "Schema decisions" + § "Out of scope for M1" — pre-shapes Commitment 1 (chunk-stitch for scroll) + Commitment 5 (procgen). AC-S3 zone schema spike extends this doc with `ZoneDef`.

### Devon's engineering direction
- `team/devon-dev/save-schema-v5-plan.md` — v5 multi-character lift; Commitment 5's `world_seed` rides additive on top of v5 per-character keys.

### `.claude/docs/` architecture briefs
- `.claude/docs/combat-architecture.md` § "Engine.time_scale interactions" + integration surface — dialogue-modal must respect `TimeScaleDirector` contract.
- `.claude/docs/html5-export.md` § "HTML5 visual-verification gate" + § "Visual-verification escape clause" + § "When a PR bundles eligible + ineligible surfaces — invoke the clause per-surface" + § "Z-index sensitivity" + § "Renderer" + § "Default-font glyph coverage" — load-bearing for §5 Self-Test Report obligations.
- `.claude/docs/audio-architecture.md` § "HTML5 audio-playback gate" — dialogue-open audio cues must fire post-gesture.
- `.claude/docs/test-conventions.md` § "Universal warning gate" + § "Spec-string-vs-engine-emit drift" + § "Author HTML5 self-soak — mandatory before claiming fix-complete on visual-gated surfaces" + § "Edge case — CLI-agent unsoakable surfaces" — cross-cutting concerns + Self-Test Report routing.
- `.claude/docs/time-scale-director.md` — Tier 1 director contract that Tier 3 dialogue-modal time-scale request (if Devon's spike chooses time-scale over input-gating) inherits.
- `.claude/docs/orchestration-overview.md` — team topology + dispatch conventions + hard gates.

### Tess's harness conventions
- `team/tess-qa/playwright-harness-design.md` §14 (staleness-bounded latestPos), §15 (harness-workaround-fail-loud), §16 (`test.fail()` canary semantics), §17 (drift-pin HARD RULE for engine-emit strings).
- `team/tess-qa/m3-acceptance-plan-tier-1.md` — structural template this Tier 3 scaffold mirrors.
- `team/tess-qa/playwright-drift-audit-2026-05-16.md` — drift-pin pattern's empirical origin.
- `team/TESTING_BAR.md` — Definition-of-Done, visual-primitive tiers, role-specific obligations, Milestone-gate journey probe.

---

## §QA scaffold — meta-acceptance for THIS doc

The scaffold doc itself has acceptance criteria so it can be QA'd at PR-merge time.

**Acceptance criteria (3):**

- **QA-SCAFFOLD-1 — Doc lands on `main`.** This PR merges, `team/tess-qa/m3-acceptance-plan-tier-3.md` is present on `origin/main` HEAD. Verified by `gh pr merge` completion.
- **QA-SCAFFOLD-2 — All commitment + spike + meta sections present with placeholder rows.** §1 (scope), §2 (AC-C1..AC-C5 with 6+8+7+7+7 = 35 rows), §3 (AC-S1..AC-S4 with 4+4+4+4 = 16 rows), §4 (risk register cross-ref), §5 (Self-Test Report obligations), §6 (test coverage matrix), §7 (cross-references), §QA (QA-SCAFFOLD-1..QA-SCAFFOLD-3). Verified by grep of the on-disk file.
- **QA-SCAFFOLD-3 — Cross-references intact.** All cited paths resolve to files on `main` at scaffold-merge time. Critical paths: `team/priya-pl/post-wave3-sequencing.md`, `team/priya-pl/risk-register.md`, `team/uma-ux/hub-town-direction.md`, `team/drew-dev/level-chunks.md`, `team/devon-dev/save-schema-v5-plan.md`, `team/tess-qa/m3-acceptance-plan-tier-1.md`, `team/tess-qa/playwright-harness-design.md`, `.claude/docs/test-conventions.md`, `.claude/docs/html5-export.md`, `.claude/docs/combat-architecture.md`, `.claude/docs/audio-architecture.md`, `.claude/docs/time-scale-director.md`. Verified by grep + Devon peer-review spot-check.

---

## Cross-cutting concerns

Six concerns cut across all five commitments + four spikes. Each is a HARD GATE for any Tier 3 dispatch.

### CC-1 — Save-schema `world_seed` additive-only field

Every Tier 3 PR touching save-state must demonstrate `data.characters[N].world_seed: int` is additive on top of v5 per-character keys — NOT a v5-non-additive lift, NOT a schema-bump. Per `post-wave3-sequencing.md §1` Commitment 5 spec + `save-schema-v5-plan.md` reference. AC-C5-6 + AC-S4-1 pin the round-trip; CC-1 enforces the additive-only discipline.

**Gate:** Tier 3 Tier 2 save-touching PRs Self-Test Report cite "additive only; no migration step required; `world_seed` rolled at character creation and never mutated." Migration tests in `tests/test_save_world_seed_roundtrip.gd` pin no-mutation invariant.

### CC-2 — AC4 spec regression-pin (M3 mustn't break M2 AC4 green)

Playwright `tests/playwright/specs/ac4-boss-clear.spec.ts` is the canonical M2 play-loop regression gate. **No M3 Tier 3 PR may merge if its release-build artifact run produces a red AC4 spec.** This is the "and prior milestones' ACs still pass" floor codified.

**Gate:** every M3 Tier 3 dispatch brief includes a Regression-guard line citing `ac4-boss-clear.spec.ts` (or a more-specific sub-spec) as the named regression-protection surface, per PR #216's Regression-guard gate. Tess journey-probe at Tier 3 RC boundary verifies AC4 green before Sponsor handoff per `TESTING_BAR.md § "Milestone-gate journey probe."`

### CC-3 — Universal warning gate (Phase 2A on main)

Per `.claude/docs/test-conventions.md` + PR #244 (Phase 2A migration of all existing specs to `test-base.ts`):

- **Every new Tier 3 Playwright spec MUST import from `tests/playwright/fixtures/test-base.ts`**, not from `@playwright/test`. The `afterEach` fixture filters for `/USER WARNING:|USER ERROR:/`.
- **Every new Tier 3 GUT test MUST attach a `NoWarningGuard` in `before_each` and call `assert_clean(self)` in `after_each`.** Required for: save-load (AC-C5-6), content-resolution (AC-C3-2, AC-C2-7), dialogue-tree-load (AC-S2-3), zone-def-load (AC-S3-2).
- **Source-side migration of `push_warning` → `WarningBus.warn` is required for new load-bearing surfaces:** AC-C2 dialogue-resolution warnings, AC-C3 zone-not-found / quest-target-orphan warnings, AC-C5 seed-derivation / chunk-port-mismatch warnings.

**Gate:** any new Tier 3 spec without the test-base import OR any new GUT test without `NoWarningGuard` attach is REQUEST CHANGES.

### CC-4 — Drift-pin HARD RULE for free-form engine-emit strings (§17)

Per `team/tess-qa/playwright-harness-design.md §17` — any Playwright spec assertion whose regex captures a free-form string interpolated from an engine-side `StringName` / `String` constant MUST be paired with a GUT drift-pin asserting the constant's string value.

Tier 3 surfaces the rule on five lanes simultaneously: `[dialogue-trace]`, `[quest-trace]`, `[procgen-trace]`, `[map-trace]`, `[camera-trace]`.

**Gate:** any new Playwright spec asserting on a free-form `<noun>=<value>` regex without a paired drift-pin is REQUEST CHANGES, citing `playwright-harness-design.md §17`.

### CC-5 — HTML5 visual-verification gate triggers (per-surface invocation)

Per `.claude/docs/html5-export.md` § "When a PR bundles eligible + ineligible surfaces — invoke the clause per-surface, not per-PR" — Tier 3 PRs that bundle eligible + ineligible surfaces MUST enumerate each surface separately and invoke the escape clause per-surface.

**Specifically:**
- AC-C1 + AC-S1 chunk-seam / scroll-transition + AC-C5 + AC-S4 procedural-seam: **INELIGIBLE for escape clause; pre-merge Sponsor-soak mandatory.**
- AC-C2 dialogue modal + AC-C4 world-map UI: **ELIGIBLE for escape clause; honest-disclose + Sponsor visual-of-record.**

**Gate:** Tier 3 PR Self-Test Reports MUST enumerate each visual surface separately and state per-surface eligibility. Mixed bundling without per-surface enumeration is REQUEST CHANGES. Precedent: PR #291 narrow REQUEST CHANGES on T6 mixed bundle.

### CC-6 — Retrospective-pause trigger after N=3 consecutive cluster dispatches (AC4 retro Gap 3)

Per `team/priya-pl/ac4-white-whale-retro.md §3 Gap 3` — after N=3 consecutive cluster dispatches without spec-closure, mandatory retrospective pause before dispatch N+1.

**M3 Tier 3 application:** the same trigger applies to **any of the 5 commitments or 4 spikes**. If any one (e.g. AC-C5 procgen spike + W2 impl + W3 fix-forward) takes 3 consecutive dispatches without closure, Priya triggers a retrospective pause.

**Gate:** orchestrator + Priya monitor dispatch count per commitment/spike. Tess flags to Priya when any commitment hits N=3 threshold. The pause is short (one-page audit doc, ~1-2 ticks); NOT a milestone-blocker — iteration-cost mitigation.

---

## AC4-retro lessons baked in

Four explicit baked-in lessons from `team/priya-pl/ac4-white-whale-retro.md`, inherited from `m3-acceptance-plan-tier-1.md` and applied to Tier 3.

### Lesson 1 — Self-Test Report sample-size discipline ≥8 release-build runs (Gap 1)

Applied to Tier 3 stochastic-cost specs. Specifically: AC-C5-1, AC-C5-2, AC-C5-3, AC-S4-1 (seed-determinism, all stochastic by definition). Also: AC-C1-1 (continuous-scroll smoothness — clock-time + frame-rate non-deterministic).

**Tess REQUEST CHANGES bar:** Self-Test Report citing fewer than 8 release-build runs for any stochastic Tier 3 spec is REQUEST CHANGES.

### Lesson 2 — Instrument-first dispatches for hypothesis-cluster bugs (Gap 2)

Per `diagnostic-traces-before-hypothesized-fixes` memory. Tier 3 application: any Tier 3 Tier 2 dispatch for a bug-fix or behavior-uncertain ticket MUST include an explicit "instrument plan" line. Fixes shipped against unverified hypotheses get REQUEST CHANGES.

**Most-applicable surfaces:** procgen seed-binding bugs (AC-C5-1..AC-C5-5), chunk-port mating gaps (AC-C5-3, AC-S4-2), HTML5 procedural-seam regressions (AC-C5-7, AC-S4-3), dialogue-state-machine bugs (AC-C2-2, AC-C2-5).

### Lesson 3 — N=3 retrospective-pause trigger (Gap 3)

See CC-6.

### Lesson 4 — Drift-pin GUT pairs for every new Playwright spec (Gap 4)

See CC-4.

---

## Test fixture catalog

Tier 3 Tier 2 dispatches will land save-fixture + content-fixture files. Anticipated set (locks at spike landings):

| Fixture | Purpose | Owner |
|---|---|---|
| `tests/fixtures/v5/save_v5_with_world_seed.json` | Per-character `world_seed` round-trip baseline | Devon (AC-S4) |
| `tests/fixtures/zones/s1_z1_entry_hall.tres` | First zone authored against AC-S3 schema | Drew (AC-S3) |
| `tests/fixtures/zones/s2_z2_reading_chamber.tres` | S2 zone with quest_target anchor | Drew (AC-S3) |
| `tests/fixtures/dialogue/s1_wounded_scholar.tres` | First dialogue tree with 4 quest-state branches | Devon (AC-S2) |
| `tests/fixtures/dialogue/hub_town_hadda_full.tres` | Hub-town NPC full dialogue tree (vendor + lore + bounty offer) | Devon (AC-S2) |
| `tests/fixtures/quests/s2_stoker_purge.tres` | First exploration quest binding to zone | Devon + Uma + Drew (AC-C3) |
| `tests/fixtures/procgen/seed_12345_s1_z1_layout.json` | Deterministic seed → layout snapshot for determinism pin | Devon (AC-C5) |
| `tests/fixtures/procgen/seed_67890_s1_z1_layout.json` | Different-seed snapshot for variance pin | Devon (AC-C5) |

---

## Paired-test file index — M3 Tier 3 NEW (anticipated)

Tess authors these stubs when corresponding Tier 2 PRs dispatch. Following the `m3-acceptance-plan-tier-1.md` anticipated-files shape:

| File | Purpose | Commitment / Spike |
|---|---|---|
| `tests/test_camera_director_follow_scroll.gd` | Pin AC-C1-1, AC-C1-2 follow-scroll + bounds-clamp | C1 |
| `tests/test_hud_screen_space.gd` | Pin AC-C1-3 HUD immunity | C1 |
| `tests/test_chunk_seam_zorder.gd` | Pin AC-C1-4 no z-order regression | C1 |
| `tests/test_camera_director_time_scale.gd` | Pin AC-C1-6 time-scale interaction | C1 |
| `tests/test_dialogue_controller.gd` | Pin AC-C2-1, AC-C2-4, AC-C2-5 modal lifecycle | C2 |
| `tests/test_dialogue_tree_traversal.gd` | Pin AC-C2-2, AC-C2-3 branch + response | C2 |
| `tests/test_quest_state.gd` | Pin AC-C3-1, AC-C3-5 quest binding | C3 |
| `tests/test_zone_def_schema.gd` | Pin AC-C3-2 zone schema; AC-S3-2 validation | C3, S3 |
| `tests/test_quest_state_save_roundtrip.gd` | Pin AC-C3-3 quest save | C3 |
| `tests/test_world_map_ui.gd` | Pin AC-C4-1, AC-C4-2 world-map render + state | C4 |
| `tests/test_waypoint_travel.gd` | Pin AC-C4-3 waypoint teleport | C4 |
| `tests/test_world_map_screen_space.gd` | Pin AC-C4-4 map HUD-immune | C4 |
| `tests/test_procgen_determinism.gd` | Pin AC-C5-1, AC-C5-2 seed-determinism | C5 |
| `tests/test_procgen_seed_derivation.gd` | Pin AC-C5-4, AC-C5-5 per-stratum / per-zone | C5 |
| `tests/test_assemble_floor.gd` | Pin AC-C5-3, AC-S4-2 anchor composition + port-mate | C5, S4 |
| `tests/test_save_world_seed_roundtrip.gd` | Pin AC-C5-6 save round-trip | C5 |
| `tests/test_procgen_spike_roundtrip.gd` | Pin AC-S4-1 N≥8 cycles | S4 |
| `tests/playwright/specs/m3-camera-scroll.spec.ts` | Playwright AC-C1-1, AC-C1-3, AC-C1-5 (with `[camera-trace]` drift-pin pair) | C1 |
| `tests/playwright/specs/m3-dialogue-modal.spec.ts` | Playwright AC-C2-1, AC-C2-3, AC-C2-6, AC-C2-7 (with `[dialogue-trace]` drift-pin pair) | C2 |
| `tests/playwright/specs/m3-quest-dialogue-flow.spec.ts` | Playwright AC-C3-6 accept + turn-in (with `[quest-trace]` drift-pin pair) | C3 |
| `tests/playwright/specs/m3-world-map.spec.ts` | Playwright AC-C4-1, AC-C4-3, AC-C4-7 (with `[map-trace]` drift-pin pair) | C4 |
| `tests/playwright/specs/m3-procgen-determinism.spec.ts` | Playwright AC-C5-1, AC-C5-2, AC-C5-3, AC-C5-7 (with `[procgen-trace]` drift-pin pair) | C5 |

Specs marked "drift-pin pair" require an entry in `tests/test_playwright_trace_string_contract.gd` (or a new lane-scoped contract file) per CC-4. Authoring trigger: when the corresponding Tier 2 PR lands the production code under test.

---

## Sponsor probe targets (M3 Tier 3 vertical-slice soak)

When Tier 3 RC ships (post-W6-W7 per `post-wave3-sequencing.md §3` v1.1 calendar), Sponsor's interactive soak evaluates:

1. **Continuous-scroll feel** (AC-C1). Sponsor walks through S1 + S2. Pass: "feels like I'm exploring." Fail: "still feels like rooms-as-tableaux" → camera tuning.
2. **Dialogue flow feel** (AC-C2). Sponsor talks to 3 hub-town NPCs + 2 stratum NPCs. Pass: "responds to what I've done" + "feels like a real NPC." Fail: "every NPC sounds the same" → tonal differentiation.
3. **Quest exploration feel** (AC-C3). Sponsor completes 2 quests. Pass: "I went somewhere because of the quest." Fail: "the quest was just kill-N" → archetype shift.
4. **World-map navigation feel** (AC-C4). Sponsor uses map to descend, travel, return. Pass: "I always know where I am." Fail: "I got lost" → Uma direction-amend.
5. **Procgen map-variance feel** (AC-C5). Sponsor creates 2 characters, walks same first zone with both. Pass: "I notice the layouts are different." Fail: "the maps feel identical" → chunk-pool widen.
6. **Procedural chunk-seam visual fidelity** (AC-C5-7, AC-S4-3). **Primary HTML5 risk gate.** Sponsor walks 5+ procedural seams in S1 + S2. Pass: "I don't see any tile gaps or weird draw-order." Fail: "I saw a visible seam at <location>" → P0 fix-forward OR SI-8 option (c) fallback.

**Top 3 priority for Tier 3 RC soak:** #6 (chunk-seam visual fidelity — P0 if it fails — closes R-PROCGEN.c), #1 (continuous-scroll feel — closes R-SCROLL), #2 (dialogue flow feel — closes R-DIALOGUE). #3, #4, #5 are quality bars; revisit at Tier 3 close.

---

## HTML5 audit re-run pattern (M3 Tier 3 RC)

When the M3 Tier 3 vertical-slice RC artifact lands (post-W6-W7), it gets the same Playwright + Sponsor-soak audit pattern M2 + Tier 1 + Tier 2 used. Audit document: `team/tess-qa/html5-rc-audit-<short-sha>.md` (template per `team/tess-qa/html5-rc-audit-591bcc8.md`).

**New testable invariants for M3 Tier 3 (TI-31..TI-42 extension of `tests/integration/test_html5_invariants.gd`):**

- **TI-31:** `CameraDirector.follow_scroll(target)` API surface exists.
- **TI-32:** `CameraDirector` clamps at world edges (`get_max_scroll_extent()` returns finite, non-zero bounds).
- **TI-33:** `DialogueController` autoload registered + reachable.
- **TI-34:** `DialogueTreeDef` schema validates with all 4 quest-state branches.
- **TI-35:** `DialoguePanel.tscn` instantiates without error in headless GUT (smoke).
- **TI-36:** `ZoneDef` schema validates required keys (entry, exit, anchor ids, slot count).
- **TI-37:** `WorldMap.tscn` instantiates without error + renders ≥1 stratum node (smoke).
- **TI-38:** `Player.discovered_zones` field exists on save schema (per-character key).
- **TI-39:** `data.characters[N].world_seed: int` field exists on v5+additive save schema.
- **TI-40:** `assemble_floor(chunks, zone_def, seed)` API surface exists + returns a non-null root.
- **TI-41:** `Levels.in_hub_town` boolean (from hub-town direction) coexists with continuous-scroll camera (hub-town is single-screen by design — no scroll engages on hub-town entry).
- **TI-42:** `Engine.time_scale == 1.0` throughout hub-town session under Tier 3 continuous-scroll camera (no time-scale leak from S1/S2 scroll-state to hub-town).

---

## Hand-off

- **Devon:** AC-S1 camera-scroll spike + AC-S2 dialogue system spike + AC-S4 procgen spike (jointly with Drew) + Commitment 2 implementation + Commitment 4 world-map UI + Commitment 5 `world_seed` save-write. All Self-Test Reports per §5 routing matrix. Per-PR sign-offs against the AC-C* + AC-S* rows.
- **Drew:** AC-S3 zone schema spike + AC-S4 procgen spike (jointly with Devon) + Commitment 1 S1 scroll retrofit + Commitment 3 zone authoring + Sub-track 5c S2 content. Per-PR sign-offs against AC-C1, AC-C3, AC-C5 rows.
- **Uma:** Commitment 2 dialogue tone direction + Commitment 4 world-map visual style + Sub-track 5d S1+S2 NPC sprites + Sponsor PixelLab handoff per `art-pass-ai-primary-brief.md`.
- **Tess:** this scaffold + ongoing fill-in as W1 spike docs land (AC-S1..AC-S4) + Playwright spec authoring (with drift-pin pairs) at Tier 2 + N≥8 sample-size enforcement on stochastic specs + journey-probe at Tier 3 RC boundary + W6-W7 dedicated HTML5 procedural-seam audit round per `post-wave3-sequencing.md §3` v1.1.
- **Priya:** §QA scaffold review + CC-6 retrospective-pause-trigger ownership + risk-register refresh as commitments + spikes close + Tier 3 RC retro authoring + M4 sequencing-plan authoring at Tier 3 close.
- **Sponsor:** SI-8 procgen-scope sign-off (post-W1 spike) + the 6 probe targets above + final M3 Tier 3 vertical-slice sign-off + the 9 character art pass via PixelLab batch (Sponsor-DIY per `m3-art-pass-collaboration-shape` memory).

---

## Caveat — parallel scaffold, not Tier 3+ lock

This doc is the M3 Tier 3 parallel-acceptance scaffold (mirrors `m3-acceptance-plan-tier-1.md` idiom — drafted at Tier 3 W1 day-1, before Tier 2 impl PRs have opened). Revisions land as v1.1 commits when:

- Devon's AC-S1 camera-scroll spike lands and AC-C1-1..AC-C1-6 rows lock against the spike's specifics (follow-scroll API, bounds-clamp algorithm, deadzone parameters, HTML5 risk enumeration).
- Devon's AC-S2 dialogue system spike lands and AC-C2-1..AC-C2-8 rows lock against the spike's specifics (schema shape, modal layout, branch-selection algorithm, input-gating-vs-time-scale decision).
- Drew's AC-S3 zone schema spike lands and AC-C3-1..AC-C3-7 rows lock against the spike's specifics (anchor taxonomy, validation rules, quest-binding hooks).
- Devon+Drew's AC-S4 procgen spike lands and AC-C5-1..AC-C5-7 rows lock against the spike's specifics (`assemble_floor` API, seed-derivation algorithm, fallback path enumeration).
- Sponsor signs SI-8 procgen-scope (a / b / c per `post-wave3-sequencing.md §6`). If Sponsor picks (c) hybrid fallback, AC-C5-3, AC-C5-7, AC-S4-2, AC-S4-3 rows soften to "hand-pinned chunks within zones, per-character seed drives anchor selection from hand-authored pool."
- An integration surface emerges that wasn't anticipated (likely candidates: continuous-scroll + dialogue-modal interaction race, world-map waypoint mid-quest state, multi-character world-seed collision, hub-town scroll-state leak).

The 5-commitment + 4-spike coverage + 51 acceptance row pinning + 6 cross-cutting concerns is the **path of least resistance from M3 Tier 3 W1 dispatch → M3 Tier 3 vertical-slice sign-off.** It is not the only path.

---

## Non-obvious findings

1. **Commitment 5 (procgen) is the highest-leverage risk class of Tier 3** — the only AC sub-cluster with three named risks (R-PROCGEN.a/b/c) and the only one with a designated dedicated HTML5 Sponsor-soak round (W6-W7). The procgen-seam HTML5-rendering risk class is empirically unforgiving (per `html5-export.md` z-index sensitivity + burst-contrast findings), and the SI-8 hybrid fallback exists precisely because Priya pre-shaped a graceful degrade path. The acceptance plan reflects this: AC-C5 has the largest row count (7) among commitments, the longest verification matrix, and the only mandatory pre-merge Sponsor-soak gate per AC item AC-C5-7.
2. **AC-C1 + AC-C5 are linked by a shared HTML5 risk class** — z-index sensitivity at chunk seams. Continuous-scroll surfaces the seams (player traverses them) and procgen produces the seams (assembler creates them per character). Both ineligible for the escape clause, both require pre-merge Sponsor-soak. If either AC fails the HTML5 gate, the other is likely to follow.
3. **AC-C2 (dialogue) and AC-C4 (world-map) are escape-clause-eligible UI surfaces** — same primitive class as AC-C1's HUD. The escape clause's per-surface invocation pattern from PR #291 governs both: honest-disclose + probe-target enumeration + Sponsor visual-of-record routes the visual gate without pre-merge Sponsor-soak. The contrast with AC-C1 + AC-C5 (ineligible, require pre-merge soak) is the load-bearing distinction.
4. **CC-4 drift-pin gate fires on 5 simultaneous lanes** (vs Tier 1's 3 lanes). Tier 3 introduces `[dialogue-trace]` + `[quest-trace]` + `[procgen-trace]` + `[map-trace]` + `[camera-trace]` — each is a free-form interpolated `StringName` surface vulnerable to spec-string-vs-engine-emit drift. The drift-pin pair gate is the structural defense; if any Tier 3 spec ships without it, the AC4 silent-pass pattern WILL recur in Tier 3. Tess authoring discipline + Devon peer-review on drift-pin pin compliance are the load-bearing process gates.
5. **Sample-size discipline N≥8 (Lesson 1) bites harder in Tier 3 than Tier 1** — Tier 3 introduces seed-based stochasticism (AC-C5-1, AC-C5-2, AC-C5-3) which is empirically guaranteed to fail at small samples (the variance is in the design, not bug-class). N≥8 is the floor; N≥16 may be required to surface low-probability port-mating bugs. Tess should encourage Devon+Drew to instrument the procgen-spike output with summary statistics (port-mating failure rate per 100 seeds, chunk-fill failure rate per zone, anchor-reachability failure rate) rather than relying on per-seed binary pass/fail.
6. **AC-S3 zone schema spike is the structurally-lowest-risk W1 spike** — it's a schema design doc + content fixture, no engine code, no HTML5 surface. It can dispatch + close fastest of the four W1 spikes; it's also the unblocker for AC-C3 (quests reference `zone_id`) and AC-S4 (procgen consumes `ZoneDef`). Recommend Priya dispatch AC-S3 first within W1.
7. **The procgen-spike's per-character-seed binding interacts with M4's multi-character UI** in a way Tier 3 cannot fully validate — only at M4 RC (when slot-switching is live) will the cross-character seed-isolation be empirically tested at full surface depth. Tier 3 RC validates AC-C5-2 (different characters → different maps) but only against a synthetic multi-character save fixture; the real-world slot-switch UX is M4's surface. Tier 3 acceptance plan flags this carry-forward explicitly: AC-C5-2 closes R-PROCGEN.a partially; M4 acceptance plan re-opens it for slot-switch coverage.
