# Save schema v5 — Tier 3 additive layer survey

**Owner:** Devon (engine) · **Phase:** M3 Tier 3 W1 (paper-survey; implementations land across W2/W3/Track 3 W2 per §8) · **Drives:** Tier 3 W2 procgen impl (`world_seed` save-write), Tier 3 W2 map-UI impl (`discovered_zones` + `discovered_waypoints` save-writes), Tier 3 W2 dialogue impl (`active_dialogue_states` save-write), Track 3 W2/W3 quest content (`active_bounty` + `completed_bounties` + `quest_progress` save-writes), sub-track 5b W3 hub-town impl (`meta.hub_town_seen` write — already pre-pinned in v5 plan but routed for per-character).

This survey is a **consolidated map** of every save-state additive field M3 Tier 3 will land on top of the v5 baseline (`team/devon-dev/save-schema-v5-plan.md`). It is **not** an implementation spec — each field's runtime write code, GUT round-trip test, and fixture authoring belong to its owning W2/W3 implementation ticket per §8 routing. The survey's job is one-stop reference so W2/W3 dispatches inherit a unified vocabulary + fixture catalog + cross-character semantics.

**Crucially: nothing here triggers a v6 schema bump.** All Tier 3 additions ride additively on top of v5's per-character key structure (`data.characters[N].*`) and v5's root `meta.*` namespace, per `save-schema-v4-plan.md §4.1` rule 4 ("Always allowed: add a new field"). The v5-non-additive multi-character lift (`data.character` → `data.characters[]`, equipped lift, shared_stash lift, active_slot) is **out of scope** for this survey — that's v5's spike (landed PR #256).

---

## TL;DR

- **5 per-character additive fields:** `world_seed: int` (Commitment 5 / procgen), `discovered_zones: Dictionary[StringName, bool]` (Track 4 / map UI), `discovered_waypoints: Dictionary[StringName, bool]` (Track 4 / map UI), `active_dialogue_states: Dictionary[StringName, StringName]` (Track 2 / dialogue), `active_bounty: Dictionary | null` (Track 3 / quest — recap from v5 plan §2.3; survey enumerates the runtime contract Track 3 W2 will write to).
- **2 per-character additive collections:** `completed_bounties: Array[StringName]` (Track 3 / quest), `quest_progress: Dictionary[StringName, Dictionary]` (Track 3 / quest).
- **1 root-level additive** in flight already: `meta.hub_town_seen` — recap from v5 plan §2.3, **moved per-character per Sponsor 2026-05-17**. This survey reflects the resolved scope (lives at `data.characters[N].hub_town_seen`); no new root key is needed for hub-town.
- **No new `meta.*` fields in this survey.** All Tier 3 additions are per-character. (A future `meta.dialogue_settings: Dictionary` for player-config UI preferences was considered and rejected — see §3.)
- **7 new test fixtures** to author under `tests/fixtures/v5/` at W2 impl time (catalog in §6). Survey enumerates filenames + distinguishing payloads; the fixtures themselves are authored by W2 impl tickets.
- **v6 trigger guard:** none of the additions trigger v6. All ride on per-character keys (additive rule); the v5 pointer-shadow doctrine is unaffected because no Tier 3 field touches `data.character` / `data.equipped` / `data.stash` shadows.
- **Size delta on a typical save:** +1.5–4 KB per character at full Tier 3 discovery state (60+ discovered_zones entries late-game + 30+ discovered_waypoints + ~5 completed_bounties + ~1 quest_progress entry). Well within v5's quota analysis (v5 plan §7.2).
- **HTML5 OPFS implication:** discovered_zones / discovered_waypoints are dict-of-bool; serialize cheaply (~50 B per entry). The Dict-of-Dict roundtrip cost flagged in the v5 plan §7.2 does NOT escalate from these additions — `quest_progress` is the only nested Dict, with bounded entry-count (1 active + ~5 completed × ~3 progress sub-keys each = ~18 leaves worst-case).

---

## 1. Source of truth

This survey is bounded by these prior artifacts. Any conflict resolves in favor of the source listed (this doc is downstream of all of them):

1. **`team/priya-pl/post-wave3-sequencing.md` v1.1 §1 Commitment 5** — locks `world_seed: int` per-character, rolled at character creation, immutable thereafter, persisted in v5 save schema. `stratum_seed = hash(world_seed, stratum_id)` + `zone_seed = hash(stratum_seed, zone_id)` derivation lives in the procgen runtime (`assemble_floor`, not Save.gd); the schema persists `world_seed` only.
2. **`team/priya-pl/post-wave3-sequencing.md` v1.1 §3 calendar + §4 W1/W2 pre-shape** — per-character `world_seed` save-write listed as W2 impl ticket. Track 4 world-map UI minimal is W2 (consumes `discovered_zones` + `discovered_waypoints`). Sub-track 5b hub-town impl is W3 (consumes `hub_town_seen`).
3. **`team/priya-pl/post-wave3-sequencing.md` v1.1 §1 Commitment 4** — World-map UI: "`Player.discovered_zones: Dictionary` (additive to v4 save schema)". This survey **expands to two dicts** (`discovered_zones` + `discovered_waypoints`) because waypoint discovery is semantically distinct from zone-clear discovery — see §2.2.
4. **`team/devon-dev/save-schema-v5-plan.md`** (PR #256, merged) — v5 baseline. `data.characters[N]` is the per-character namespace this survey extends additively. The v5 pointer-shadow doctrine (§4.4) is unaffected by Tier 3 additions: shadows mirror `characters[active_slot]`, so any field added per-character is automatically shadowed in `data.character` on save — no extra shadow-discipline burden.
5. **`team/devon-dev/save-schema-v4-plan.md` §4.1** — the additive-only rule. Tier 3 additions are all in compliance: no renames, no type changes, no deletions. Every new field is `has()`-guarded backfill in its owning W2 migration step.
6. **`team/priya-pl/m3-design-seeds.md` §2 Save-schema implications + §3 NG+ Paragon track / bounty content** — design substrate for `active_bounty` shape (`{ quest_id: String, target: String, progress: int }`) per-character, plus the wider bounty content roster Track 3 W2/W3 fills.
7. **`team/priya-pl/mvp-scope.md` §M3** — "bounty quest system" listed; Track 3 is the implementation track. The dispatch ticket clarified `Character.active_bounty` + `Character.completed_bounties` + `Character.quest_progress` as the per-character shape (see §4).
8. **Sibling W1 spikes:**
   - `team/drew-dev/level-chunks.md` § "Zone schema" (PR #312, merged) — `ZoneDef.zone_id: StringName` is the key consumed by `discovered_zones` (and `quest_progress`'s zone-bound bounties).
   - `scripts/dialogue/DialogueTreeDef.gd` + `DialogueController.gd` (PR #319, merged) — `npc_id: StringName` is the key consumed by `active_dialogue_states`; the dialogue spike's `quest_action_invoked(action_id, npc_id)` signal is the surface Track 3 W2 BountyController subscribes to for write-side state mutations.
9. **`team/priya-pl/risk-register.md` R1 (save migration breakage) + R-PROCGEN.a (per-character seed save-binding)** — both touch this survey's surface. Mitigation per-field: round-trip invariants enumerated in §2 + §4 + §5; W2 impl tickets pick up the testing contract directly.

---

## 2. Per-character additive fields (Tier 3)

All fields live under `data.characters[N]` in the v5 multi-character structure. Each is independent across slots — no cross-character interaction unless explicitly noted.

### 2.1 `world_seed: int` (Commitment 5 / procgen)

| Property | Value |
|---|---|
| **Path** | `data.characters[N].world_seed` |
| **Type** | `int` (64-bit; Godot Dictionary handles long ints natively) |
| **Default on migration** | `0` (sentinel — see Migration considerations §5) |
| **Default for new character creation** | `randi() << 32 | randi()` (rolled at character-creation form-submit; assigned ONCE; immutable thereafter) |
| **Owning surface** | Track 1.5 procgen W2 impl ticket (`assemble_floor(chunks, zone_def, seed)`) |
| **Save-write trigger** | Character creation (once per character lifetime) |
| **Cross-character interaction** | None — each character's `world_seed` is independent. Re-rolling a new character ALWAYS gets a fresh `randi()`; never seeded from another slot. |
| **Round-trip fixture** | `save_v5_world_seed_set.json` |
| **Sponsor decision surface** | None outstanding. Sponsor signed Commitment 5 + SI-8 2026-05-22 per post-wave3-sequencing.md v1.1 §6. |

**Why `int` not `String` or `PackedByteArray`:** Godot 4.3 JSON serializes int64 cleanly; no precision loss. A 32-bit seed (`randi()`) is sufficient for procgen uniqueness, but the upper-32-bit XOR (`randi() << 32 | randi()`) hedges against the procgen runtime hashing pattern colliding within `randi()`'s 2^31 space.

**Why immutable:** Per Commitment 5, "same character → same map across loads." Mutating `world_seed` mid-run would re-shuffle the player's known map between save→load, breaking the determinism contract. The W2 procgen-impl ticket MUST treat the field as write-once (assert at character-creation time; never assign elsewhere). The Save.gd schema layer cannot enforce this — the discipline lives in character-creation code.

**Round-trip invariant** (W2 procgen-impl test):

```gdscript
func test_world_seed_round_trips_on_save_load() -> void:
    var save: Dictionary = Save.create_new_character_payload("Test")
    save["characters"][0]["world_seed"] = 0xCAFEBABE_DEADBEEF
    Save.save_game(0, save)
    var loaded := Save.load_game(0)
    assert_eq(loaded["characters"][0]["world_seed"], 0xCAFEBABE_DEADBEEF)
```

**Cross-reference to procgen runtime:** `assemble_floor(chunks, zone_def, seed)` consumes `world_seed` via derived `zone_seed = hash(world_seed, stratum_id, zone_id)`. The save layer persists `world_seed` only — derived seeds are computed at runtime each `assemble_floor` call; never persisted (would be redundant + drift risk).

### 2.2 `discovered_zones: Dictionary[StringName, bool]` (Track 4 / map UI)

| Property | Value |
|---|---|
| **Path** | `data.characters[N].discovered_zones` |
| **Type** | `Dictionary` (Godot untyped at Resource level; W2 consumer treats as `Dictionary[StringName, bool]` by convention — same shape pattern as `ember_bags` in v4) |
| **Default on migration** | `{}` (empty dict — Tier 3-naive characters discovered nothing yet) |
| **Default for new character creation** | `{}` (fresh character starts undiscovered everywhere) |
| **Key semantics** | `ZoneDef.zone_id` per `level-chunks.md` § "Zone schema". Examples: `&"s1_z1_outer_cloister"`, `&"s2_z3_sunken_library"`. |
| **Value semantics** | `true` = player has entered the zone at least once (and thereafter it renders on the world-map UI). False/absent = undiscovered (fog-of-war on map). |
| **Owning surface** | Track 4 W2 map-UI impl ticket |
| **Save-write trigger** | Zone-entry callback (`Player._on_zone_entered(zone_id)` → `data.characters[active_slot].discovered_zones[zone_id] = true` → `Save.save_game()`). Idempotent (re-entering an already-discovered zone is no-op). |
| **Cross-character interaction** | None — each character maintains their own exploration state. **Per-character is the load-bearing design call**: per-character discovery preserves "each character is encountering the world as themselves" (same diegetic-first rationale as Sponsor's 2026-05-17 `hub_town_seen` per-character decision). |
| **Round-trip fixture** | `save_v5_discovered_zones_partial.json` |
| **Sponsor decision surface** | Survey defaults this to per-character. **If Sponsor prefers account-scoped (shared across slots), reroute to `meta.discovered_zones` and confirm at Track 4 W2 impl dispatch.** Recommendation: per-character. |

**Why `Dictionary[StringName, bool]` not `Array[StringName]`:** Dict allows O(1) membership check + supports future expansion (`Dictionary[StringName, ZoneDiscoveryState]` with sub-keys for entry-count / clear-count / first-discovered timestamp) without a non-additive bump. Array would force a Dict migration at first expansion.

**Why `StringName` keys not `String`:** matches the `ZoneDef.zone_id: StringName` runtime convention (`level-chunks.md` § "ZoneDef shape"). Godot JSON serializes `StringName` as a string on disk (lossy round-trip — keys come back as `String` not `StringName`), but the W2 map-UI consumer normalizes keys via `StringName(key)` at read time. Same idiom v4 uses for `ember_bags` stratum-id-as-string keys (v4 plan §2.4).

**Round-trip invariant** (Track 4 W2 map-UI impl test):

```gdscript
func test_discovered_zones_round_trips() -> void:
    var save: Dictionary = Save.create_new_character_payload("Test")
    save["characters"][0]["discovered_zones"] = {
        "s1_z1_outer_cloister": true,
        "s1_z2_ember_well": true,
    }
    Save.save_game(0, save)
    var loaded := Save.load_game(0)
    assert_eq(loaded["characters"][0]["discovered_zones"].size(), 2)
    assert_true(loaded["characters"][0]["discovered_zones"].has("s1_z1_outer_cloister"))
```

### 2.3 `discovered_waypoints: Dictionary[StringName, bool]` (Track 4 / map UI)

| Property | Value |
|---|---|
| **Path** | `data.characters[N].discovered_waypoints` |
| **Type** | `Dictionary` (W2 consumer treats as `Dictionary[StringName, bool]`) |
| **Default on migration** | `{}` |
| **Default for new character creation** | `{}` |
| **Key semantics** | Waypoint StringName id — convention TBD by Track 4 W2 map-UI impl. Suggested shape: `&"<stratum>_<zone>_<waypoint_slug>"` (e.g. `&"s1_z1_threshold"`, `&"s2_z3_descent"`). |
| **Value semantics** | `true` = waypoint discovered + available for fast-travel from world-map UI. Absent = locked (fog-of-war). |
| **Owning surface** | Track 4 W2 map-UI impl ticket |
| **Save-write trigger** | Waypoint-interact callback (player touches a waypoint shrine / descend-portal). Idempotent. |
| **Cross-character interaction** | None — per-character (same rationale as `discovered_zones`). |
| **Round-trip fixture** | `save_v5_discovered_waypoints_full.json` |
| **Sponsor decision surface** | None outstanding. Track 4 W2 confirms key-naming convention at impl dispatch. |

**Why separate from `discovered_zones`:** zones and waypoints have **distinct discovery cadences**. A player can fully clear (discover) zone `s1_z1_outer_cloister` without ever finding its waypoint shrine (which is gated on an exploration-quest objective). The map UI renders these as two layers: zone fill (`discovered_zones`) + waypoint pins (`discovered_waypoints`). Conflating into one Dict would force the UI to handle ambiguous `true` semantics.

**Why duplicates the dict-of-bool shape rather than `Dictionary[StringName, WaypointState]`:** Tier 3 doesn't need per-waypoint metadata (last-used timestamp, fast-travel-cooldown, etc.). The cost of expanding to a sub-Dict later is one additive bump (v6+) inside the per-character namespace — same rule as `discovered_zones`. Keep it dict-of-bool until a feature demands more.

### 2.4 `active_dialogue_states: Dictionary[StringName, StringName]` (Track 2 / dialogue persistence)

| Property | Value |
|---|---|
| **Path** | `data.characters[N].active_dialogue_states` |
| **Type** | `Dictionary` (W2 consumer treats as `Dictionary[StringName, StringName]`) |
| **Default on migration** | `{}` |
| **Default for new character creation** | `{}` |
| **Key semantics** | `DialogueTreeDef.npc_id: StringName` per `scripts/dialogue/DialogueTreeDef.gd:1`. Examples: `&"s1_warden_scholar"`, `&"hub_vendor"`, `&"hub_anvil_keeper"`. |
| **Value semantics** | The `branch_key` (StringName) the player is currently inside for that NPC. Absent = no in-progress conversation; player will see the default-state branch on next interact. Present = on next interact, controller resumes at this branch. |
| **Owning surface** | Track 2 W2 dialogue impl ticket (extends the W1 spike's `DialogueController` to read/write this dict on `open()` + `dialogue_closed`) |
| **Save-write trigger** | **TWO design options — Sponsor decision surface §3.4**. Option A (granularity = per-NPC current-branch): save-write fires on `dialogue_closed(npc_id)` to persist the last-seen branch_key. Option B (granularity = per-NPC quest-progressed): save-write fires only when `quest_action_invoked(action_id, npc_id)` mutates bounty state (via Track 3 W2 BountyController). Recommendation in §3.4. |
| **Cross-character interaction** | None — per-character. Each character's NPC relationships are independent. |
| **Round-trip fixture** | `save_v5_dialogue_active_state.json` |
| **Sponsor decision surface** | **YES — granularity decision (see §3.4)**. Default if Sponsor doesn't weigh in: Option A (per-NPC current branch). |

**Why `StringName` values not `Dictionary`:** Tier 3 dialogue persistence is **simple branch-pointer state**, not "full conversation history." The dialogue spike's `DialogueController.resolve_branch(quest_state)` walks the tree's branch map by `quest_state` parameter — if save records `quest_state == &"post_quest"`, next interact opens the post-quest branch. Per-line scrubback (resume mid-line) is out of scope for M3 (Diablo-II reference also doesn't do mid-line scrubback).

**Why the empty-default + opt-out:** if a character never talks to an NPC, the NPC's key is absent (not `&""`). Absent key + `DialogueController.open(tree, &"")` → falls back to `tree.default_branch_key` per W1 spike's `resolve_branch` contract. This **preserves the spike's quest_state-driven branch resolution semantic** — the save layer just persists the player's "last seen state" for resume, doesn't replace the quest-state lookup.

**Round-trip invariant** (Track 2 W2 dialogue impl test — under `NoWarningGuard` per `test-conventions.md`):

```gdscript
func test_active_dialogue_states_round_trips() -> void:
    var save: Dictionary = Save.create_new_character_payload("Test")
    save["characters"][0]["active_dialogue_states"] = {
        "s1_warden_scholar": "quest_active",
        "hub_vendor": "post_purchase",
    }
    Save.save_game(0, save)
    var loaded := Save.load_game(0)
    assert_eq(loaded["characters"][0]["active_dialogue_states"].size(), 2)
    assert_eq(loaded["characters"][0]["active_dialogue_states"]["s1_warden_scholar"], "quest_active")
```

**Coupling guard for W2 impl:** the active_dialogue_states write site is `DialogueController.close(npc_id, branch_key)` — NOT `Player._on_npc_interact()` or any caller-side site. Centralizing the write in the controller means new NPCs added to the dialogue roster automatically inherit the persistence behavior. Decentralized writes would create the "spec author guessed wrong" failure class (per `test-conventions.md` § "Spec-string-vs-engine-emit drift") at runtime instead of test time.

### 2.5 `active_bounty: Dictionary | null` (Track 3 / quest — recap from v5 plan §2.3)

| Property | Value |
|---|---|
| **Path** | `data.characters[N].active_bounty` |
| **Type** | `Dictionary` or `null` (recap from v5 plan §2.3) |
| **Default on migration** | `null` (v5 plan §2.3) |
| **Default for new character creation** | `null` |
| **Shape when non-null** | `{ "quest_id": String, "target": String, "progress": int }` per `m3-design-seeds.md §3.9` (Track 3 W2 BountyController extends as needed within the additive rule; new sub-keys are sub-additive within the Dict, no schema bump). |
| **Owning surface** | Track 3 W2 quest-content ticket |
| **Save-write trigger** | Bounty accept (player chooses to accept a bounty via dialogue `quest_action_invoked(&"accept_bounty:<quest_id>", npc_id)`) → `data.characters[active_slot].active_bounty = { quest_id, target, progress=0 }`. Bounty progress updates on objective-hit (write per-room-clear, not per-objective-tick — folds into existing `room_cleared` save trigger). Bounty turn-in clears to `null`. |
| **Cross-character interaction** | None — per-character. |
| **Round-trip fixture** | `save_v5_quest_active.json` |
| **Sponsor decision surface** | None outstanding. v5 plan §2.3 + m3-design-seeds.md §3.9 lock the shape. |

**Cross-reference:** the dialogue spike's `DialogueResponse.quest_action: StringName` is the **write-side signal** that triggers active_bounty mutations. Authoring convention: `&"accept_bounty:<quest_id>"`, `&"complete_bounty:<quest_id>"`, `&"abandon_bounty"`. Track 3 W2 BountyController owns the action-id verb registry; the schema layer is permissive.

### 2.6 `completed_bounties: Array[StringName]` (Track 3 / quest)

| Property | Value |
|---|---|
| **Path** | `data.characters[N].completed_bounties` |
| **Type** | `Array` (W2 consumer treats as `Array[StringName]`) |
| **Default on migration** | `[]` |
| **Default for new character creation** | `[]` |
| **Element semantics** | Quest StringName id (e.g. `&"s1_clear_outer_cloister"`, `&"s2_recover_scholar_journal"`). Stable across patches per `m3-design-seeds.md §3.9` (renaming a completed quest_id would orphan history; Track 3 W2 authoring convention pins ids at first ship). |
| **Owning surface** | Track 3 W2 quest-content ticket |
| **Save-write trigger** | Bounty turn-in (player completes bounty via dialogue `quest_action_invoked(&"complete_bounty:<quest_id>", npc_id)`) → `data.characters[active_slot].completed_bounties.append(quest_id)` + `active_bounty = null` + `Save.save_game()`. |
| **Cross-character interaction** | None — per-character. |
| **Round-trip fixture** | `save_v5_quest_completed_multiple.json` |
| **Sponsor decision surface** | None outstanding. Per-character per the multi-character pillar intent. |

**Why Array not Dict-of-bool:** completed_bounties has natural ordering semantics (display "your last 5 completed bounties" in some future UI), and a player CAN'T un-complete a bounty (no membership-check needed beyond `has(quest_id)` which Array supports O(N) — acceptable at ~100 completed bounties late-game). Dict-of-bool would lose insertion order on JSON round-trip pre-Godot-4.4 (Godot 4.3 preserves Dict insertion order, but JSON spec does not — round-trip is non-deterministic across implementations).

**Growth bound:** ~5–20 entries per character mid-game; ~50–100 entries at full M5 ship if every stratum has 8–12 bounties. At 50 × ~40 chars per id = ~2 KB worst-case per character. Negligible.

### 2.7 `quest_progress: Dictionary[StringName, Dictionary]` (Track 3 / quest)

| Property | Value |
|---|---|
| **Path** | `data.characters[N].quest_progress` |
| **Type** | `Dictionary` (W2 consumer treats as `Dictionary[StringName, Dictionary]` — nested) |
| **Default on migration** | `{}` |
| **Default for new character creation** | `{}` |
| **Key semantics** | Quest StringName id (`completed_bounties` element shape). |
| **Value semantics** | Per-quest progress sub-Dict. Shape varies by quest archetype — example for a "kill N of mob X" bounty: `{ "kills": int }`; for a "find item Y" exploration quest: `{ "found": bool }`; for a multi-stage escort: `{ "stage": int, "objectives": Array[String] }`. Track 3 W2 BountyController defines the per-archetype sub-shape; the schema layer is permissive (no validation in Save.gd). |
| **Owning surface** | Track 3 W2/W3 quest-content ticket |
| **Save-write trigger** | Progress-tick events from BountyController (per-room-clear, per-mob-kill if the active bounty is "kill N of X", per-zone-enter if "explore zone Y"). Folds into existing `room_cleared` save trigger; no new save cadence. |
| **Cross-character interaction** | None — per-character. |
| **Round-trip fixture** | `save_v5_quest_completed_multiple.json` (smoke-baseline includes one active quest_progress entry alongside completed list) + `save_v5_full_tier3.json` |
| **Sponsor decision surface** | None outstanding. Per-quest-archetype sub-shape is Track 3 W2 authoring call. |

**Why nested Dict not flat:** quest archetypes have heterogeneous progress shapes (kill-counter, exploration-bool, escort-stage). Flat keys (`quest_progress["s1_clear_outer_cloister.kills"]`) would lose the per-quest grouping + complicate cleanup-on-turn-in (would have to grep keys by prefix).

**Why retain after turn-in:** quest_progress entries for completed quests can be deleted on turn-in (BountyController choice). Two design options:
- **Option A — purge on turn-in:** `quest_progress.erase(quest_id)` when bounty completes. Save size stays bounded.
- **Option B — retain for history:** keep entries forever for "best time / first complete date" telemetry surfaces (post-M3 backlog).

Recommendation: **Option A (purge on turn-in)** for M3 Tier 3 + 4. Save-size hygiene matters more than speculative telemetry. Re-promotion to retention is a Track 3 W3+ decision once telemetry features ship.

**HTML5 OPFS implication:** `quest_progress` is the ONLY nested-Dict addition in this survey. Worst-case (1 active + ~5 completed × ~3 progress sub-keys each = ~18 leaves) is well below the v5 plan §7.2 OPFS roundtrip-cost threshold; no chunking needed.

---

## 3. Root-level additive fields (Tier 3)

This section enumerates `meta.*` namespace additions. **None are surfaced by this survey.**

### 3.1 `meta.hub_town_seen` — recap, moved per-character

The v5 plan originally proposed `meta.hub_town_seen: bool` (account-scoped). Sponsor reversed 2026-05-17 to per-character (`data.characters[N].hub_town_seen`). This survey reflects the resolved scope: **no `meta.hub_town_seen` root key exists in v5 or Tier 3**; the field lives per-character per v5 plan §2.3.

This survey does NOT re-survey `hub_town_seen` — it's already pinned by v5 plan §2.3 + INV-6. Listed here for completeness so W3 sub-track 5b hub-town impl knows the save-write path is `data.characters[active_slot].hub_town_seen = true` (NOT `meta.hub_town_seen = true`).

### 3.2 `meta.hub_town_last_descended_stratum` — recap, per-character

Same shape: pinned per-character by v5 plan §2.3 (`data.characters[N].hub_town_last_descended_stratum: int`). No `meta.*` root key. Listed here so W3 sub-track 5b knows the path.

### 3.3 Considered + rejected: `meta.dialogue_settings: Dictionary`

The dispatch brief flagged: "any new root keys (e.g. if Track 2 dialogue system surfaces a `meta.dialogue_settings: Dictionary` for player-config preferences)."

**Surveyed and rejected.** The dialogue spike (PR #319) does NOT expose any player-config preferences (text speed, auto-advance, response-button layout, etc.). All dialogue state is per-NPC + per-character. **No `meta.dialogue_settings` field is needed at Tier 3 W2 impl.**

If a future ticket (M4+) adds player-config dialogue preferences (e.g. "auto-advance lines after 3 seconds"), the addition would be account-scoped (player preference is per-keyboard, not per-character) and would land under `meta.*` at that future ticket. Survey flags the slot for awareness; no Tier 3 work.

### 3.4 Sponsor decision surface — `active_dialogue_states` granularity (Option A vs B)

**The question** (from §2.4): when should `active_dialogue_states[npc_id] = branch_key` be written to save?

- **Option A — per-NPC current-branch (recommended):** write on every `dialogue_closed(npc_id, branch_key)` signal. Save-write cadence: ~every NPC interact end. Cost: ~50-100 ms HTML5 save hitch per interact. Behavior: player walks away from NPC mid-conversation → save persists last branch seen → next interact resumes at that branch.
- **Option B — per-NPC quest-progressed only:** write only when `quest_action_invoked(action_id, npc_id)` mutates bounty state (via Track 3 W2 BountyController). Save-write cadence: rare (only on accept/abandon/complete-bounty). Cost: negligible. Behavior: player walks away from NPC mid-conversation → no save → next interact opens default-state branch (loses position in conversation tree).

**Recommendation: Option A (per-NPC current-branch).** Two reasons:
1. **Diablo-II precedent:** NPCs in Diablo II remember the last topic the player was on; re-opening a conversation re-prompts the same dialogue tree at the same node. Option B breaks the precedent.
2. **Save-write hitch is acceptable.** ~50–100 ms HTML5 hitch fires only on dialogue close; player is already in a UI-modal context (no combat / no scrolling), so the hitch is invisible. v5 plan §11 finding 6 catalogues the same hitch class for hub-town first-visit save.

**Sponsor decision surface:** if Sponsor prefers Option B (cleaner save cadence, lose mid-conversation position), reroute at Track 2 W2 dialogue-impl ticket. Default if no decision: Option A.

---

## 4. Quest-state save shape (Track 3 — recap of §2.5/§2.6/§2.7)

For dispatch precision: this section is **a recap of §2.5 + §2.6 + §2.7** in one table, not a new field surface. Track 3 W2/W3 implementers reference this section for the per-character quest namespace contract.

| Field | Type | Path | Default | Owning ticket |
|---|---|---|---|---|
| `active_bounty` | `Dictionary | null` | `data.characters[N].active_bounty` | `null` | Track 3 W2 quest-content |
| `completed_bounties` | `Array[StringName]` | `data.characters[N].completed_bounties` | `[]` | Track 3 W2 quest-content |
| `quest_progress` | `Dictionary[StringName, Dictionary]` | `data.characters[N].quest_progress` | `{}` | Track 3 W2/W3 quest-content |

**Cross-system contract (dialogue ↔ quest):**

```
DialogueResponse.quest_action: StringName
        ↓ (signal: quest_action_invoked(action_id, npc_id))
DialogueController
        ↓ (Track 3 W2 BountyController subscribes)
BountyController.handle_quest_action(action_id, npc_id)
        ↓
data.characters[active_slot].active_bounty = ...      # write A
data.characters[active_slot].completed_bounties.append(...)  # write B
data.characters[active_slot].quest_progress[id] = ...  # write C
        ↓
Save.save_game()   # synchronous; folds into existing room_cleared cadence
```

All three writes (A/B/C) happen in BountyController, NOT in DialogueController. Dialogue spike's `quest_action_invoked` signal is the **only** coupling point — BountyController subscribes; everything else lives in Track 3. This isolation is load-bearing for the dialogue spike's spike-scope claim (PR #319 §findings: "spike EMITS only; W2 wires bounty-state mutations").

**Round-trip invariant** (Track 3 W2 quest-content test):

```gdscript
func test_quest_state_round_trips_across_active_completed_progress() -> void:
    var save: Dictionary = Save.create_new_character_payload("Test")
    save["characters"][0]["active_bounty"] = {
        "quest_id": "s1_clear_outer_cloister",
        "target": "grunt",
        "progress": 3,
    }
    save["characters"][0]["completed_bounties"] = [
        StringName("s1_first_bounty"),
        StringName("s1_descent_test"),
    ]
    save["characters"][0]["quest_progress"] = {
        "s1_clear_outer_cloister": { "kills": 3 },
    }
    Save.save_game(0, save)
    var loaded := Save.load_game(0)
    assert_eq(loaded["characters"][0]["active_bounty"]["progress"], 3)
    assert_eq(loaded["characters"][0]["completed_bounties"].size(), 2)
    assert_eq(loaded["characters"][0]["quest_progress"]["s1_clear_outer_cloister"]["kills"], 3)
```

---

## 5. Migration considerations

All Tier 3 additions ride the additive-only rule. The migration contract for each field is identical and trivial:

**Round-trip invariant (per-field):**
1. Load a v5-baseline save (no Tier 3 fields present).
2. Assert each Tier 3 field defaults correctly on read (e.g. `loaded["characters"][0].get("world_seed", 0) == 0`).
3. Re-save (without explicitly setting the field).
4. Reload.
5. Assert field still defaults (no field drift; no spurious key insertion).

**Implementation pattern** (every Tier 3 W2 impl ticket inherits this shape, mirroring `_migrate_v3_to_v4`'s `has()`-guarded backfill per v4 plan §3):

```gdscript
# In Save.gd::_migrate_v5_to_v5_tier3(data) (or similar — exact function
# name is the W2 impl ticket's call; the key point is each field is
# additive and backfilled with `has()`-guard):
for character in data["characters"]:
    if not character.has("world_seed"):
        character["world_seed"] = 0       # sentinel — see §5.1
    if not character.has("discovered_zones"):
        character["discovered_zones"] = {}
    if not character.has("discovered_waypoints"):
        character["discovered_waypoints"] = {}
    if not character.has("active_dialogue_states"):
        character["active_dialogue_states"] = {}
    if not character.has("active_bounty"):
        character["active_bounty"] = null    # already in v5 per v5 plan §2.3
    if not character.has("completed_bounties"):
        character["completed_bounties"] = []
    if not character.has("quest_progress"):
        character["quest_progress"] = {}
```

**No schema_version bump.** Per the additive rule, `SCHEMA_VERSION` stays at `5` across all Tier 3 additions. The W2 impl PRs that add fields update `DEFAULT_PAYLOAD` in Save.gd (so fresh characters start with the new field defaults) + ensure existing v5 saves backfill on load (via the pattern above).

**Per-impl-PR contract for migration safety:** each Tier 3 W2/W3 impl ticket MUST:
1. Add field default to `DEFAULT_PAYLOAD["character"]` (so new characters get it).
2. Add `has()`-guarded backfill in `Save.gd::migrate()` for existing v5 saves (the field migrates to default on first load post-impl-merge).
3. Pin the round-trip invariant in a GUT test (`tests/test_save_<field_name>_round_trip.gd` or extend `tests/test_save_roundtrip.gd`).
4. Route any warnings through `WarningBus.warn(text, "save")` per `test-conventions.md` § Universal warning gate (every save-load test runs under `NoWarningGuard.assert_clean(self)`).

### 5.1 The `world_seed = 0` sentinel discussion

The migration backfill sets `world_seed = 0` for existing v5 saves that pre-date Tier 3. Two design options:
- **Sentinel 0 + procgen treats 0 as "re-roll":** load-time check in procgen runtime — if `world_seed == 0`, re-roll a fresh `randi() << 32 | randi()` and save back. Cost: silent re-roll on first post-Tier-3 load. Behavior: pre-Tier-3 characters see fresh maps on their next play session.
- **Sentinel 0 + procgen treats 0 as "deterministic for legacy":** procgen runtime uses `world_seed = 0` literal as a seed value; maps are deterministic but identical across all pre-Tier-3 characters. Behavior: pre-Tier-3 characters all see the same map.

**Recommendation: sentinel-0 + re-roll-on-first-load.** Reasons:
1. **Backward-compat semantic preservation:** pre-Tier-3 saves wouldn't have a `world_seed` because procgen wasn't a feature yet. Re-rolling on first load matches "each character has their own seed" intent without retroactively pinning a seed they never had.
2. **Pre-Tier-3 character count is likely zero or near-zero by W2 ship.** M3 Tier 3 W1 spikes are still in flight; no Sponsor-soak builds carry Tier-3-naive v5 saves yet. The re-roll fires once per legacy character (likely Sponsor's own dev-save), then never again.
3. **Telemetry signal:** any character with `world_seed == 0` after a fresh re-roll attempt indicates a save-write bug (re-roll should immediately replace the sentinel). A future GUT invariant `test_no_loaded_character_has_world_seed_zero_after_first_load` would catch it.

The W2 procgen-impl ticket owns the re-roll-on-first-load gate. Survey just flags the surface.

### 5.2 The `active_dialogue_states` cleanup discussion

`active_dialogue_states[npc_id]` accumulates across all NPCs the player has ever talked to. Unbounded growth at long-play timescales (hundreds of NPCs in M5 strata × N hours of play).

**Recommendation:** Track 2 W2 dialogue impl should treat `active_dialogue_states` as "current branch state only" (not history). On `dialogue_closed`, write the current branch_key; on `dialogue_opened` of the same NPC, read + resume from the key. **No history append.** The Dict grows at most one entry per unique NPC the player has ever spoken to (~50 entries late-game at M5; ~2 KB worst-case per character).

If the Dict grows past ~200 entries (unlikely in M3 Tier 3; possible in M5 with all 8 strata + per-stratum NPCs), introduce a per-NPC "last-spoken timestamp" + LRU-eviction policy in a future Track 2 PR. Out of scope for Tier 3.

---

## 6. Fixture catalog additions

Seven new fixtures to author under `tests/fixtures/v5/` at W2 impl time. **Authored by the owning W2 impl ticket**, not by this survey. Survey enumerates filenames + distinguishing payloads so dispatches are precise.

| Fixture filename | Distinguishing payload | Drives | Owning ticket |
|---|---|---|---|
| `save_v5_world_seed_set.json` | 1 character at L5; `world_seed = 0xCAFEBABE_DEADBEEF`; all other Tier 3 fields at default | World_seed round-trip; procgen runtime smoke | W2 procgen-impl |
| `save_v5_discovered_zones_partial.json` | 1 character at L8; `discovered_zones = { s1_z1: true, s1_z2: true, s2_z1: true }` (3 of ~10 zones explored mid-game); all other Tier 3 fields at default | Discovered_zones round-trip + map-UI mid-game state | W2 map-UI-impl |
| `save_v5_discovered_waypoints_full.json` | 1 character at L12; `discovered_waypoints = { ...all S1+S2 waypoints... }` (~8 entries) + `discovered_zones` matching | Full waypoint roster round-trip + fast-travel UI smoke | W2 map-UI-impl |
| `save_v5_dialogue_active_state.json` | 1 character at L4; `active_dialogue_states = { s1_warden_scholar: "quest_active", hub_vendor: "post_purchase" }` (mid-conversation save) | Active_dialogue_states round-trip + resume behavior | W2 dialogue-impl |
| `save_v5_quest_active.json` | 1 character at L6; `active_bounty = { quest_id: "s1_clear_outer_cloister", target: "grunt", progress: 3 }`; `quest_progress = { s1_clear_outer_cloister: { kills: 3 } }`; `completed_bounties = []` | Active bounty + in-progress round-trip | Track 3 W2 quest-content |
| `save_v5_quest_completed_multiple.json` | 1 character at L20; `completed_bounties = [s1_first_bounty, s1_descent_test, s2_recover_journal, s2_clear_library, s1_explore_ember_well]` (5 completed); `quest_progress = {}` (purged on turn-in); `active_bounty = null` | Completed-list round-trip + Option-A (purge on turn-in) behavior | Track 3 W2 quest-content |
| `save_v5_full_tier3.json` | 3 characters: slot 0 at L15 with full Tier 3 state (world_seed set + 60% discovered_zones + 40% discovered_waypoints + 3 active_dialogue_states + 1 active_bounty + 8 completed_bounties + 1 quest_progress entry); slot 1 at L5 with partial Tier 3 state; slot 2 fresh (Tier 3 defaults). `active_slot = 0`. | Smoke baseline + full-Tier-3-roundtrip + size-delta upper bound | W2/W3 cross-impl + Tess QA gate |

**Eight fixtures total catalogued by v5 plan §6** for the v5-non-additive lift; **seven fixtures total catalogued here** for Tier 3 additive layer. Combined v5 + Tier 3 fixture count at end-of-W3: **15 fixtures under `tests/fixtures/v5/`**. Tess's M3 Tier 3 acceptance gate (per `team/tess-qa/m3-acceptance-plan-tier-3.md`) consumes the full catalog.

**Fixture-authoring discipline** (per `tests/fixtures/save_v0_*.json` precedent):
1. Author by hand (not via runtime `save_game`) so the on-disk shape is the explicit contract being tested, not whatever the engine happens to write.
2. Pin schema_version + saved_at envelope fields. schema_version stays `5` for all Tier 3 additions per §5.
3. Use realistic NPC ids / quest ids / zone ids — reference `resources/dialogue/*.tres` + `resources/level/zones/*.tres` for authoritative ids.
4. Format with `python -m json.tool` (or equivalent) so diffs are reviewable line-by-line.

---

## 7. HTML5 OPFS implications

### 7.1 Size delta vs v5 baseline

Per-character at full Tier 3 discovery state:

| Field | Worst-case bytes | Typical bytes |
|---|---|---|
| `world_seed` (int64) | 24 (`"world_seed":1234567890123456789,`) | 24 |
| `discovered_zones` (60 entries × ~50 B) | 3,000 | 1,000 (20 entries mid-game) |
| `discovered_waypoints` (30 entries × ~50 B) | 1,500 | 500 (10 entries mid-game) |
| `active_dialogue_states` (50 entries × ~80 B avg) | 4,000 | 1,500 (~20 NPCs spoken to) |
| `active_bounty` (1 dict, ~80 B) | 80 | 80 |
| `completed_bounties` (100 entries × ~40 B) | 4,000 | 800 (20 mid-game) |
| `quest_progress` (~5 entries × ~100 B) | 500 | 200 (1-2 entries mid-game) |
| **Total Tier 3 per-character delta** | **~13 KB** | **~4 KB** |

A typical v5 Tier-3-mid-game save grows from ~12-18 KB (v5 baseline mid-stash + 3 slots) to ~24-30 KB (v5 + 3-slot Tier 3 mid-state). Worst case (3 full characters at L30 + 72 shared_stash + full ember_bags + full Paragon + full Tier 3 discovery/quest/dialogue history) is ~120 KB.

**Within v5 plan §7.3 quota guidance** (TI-N pins worst-case <150 KB): yes — 120 KB is comfortably under the 150 KB safety upper bound. **Tess's TI-N invariant should be re-pinned at <150 KB for the Tier 3-extended worst-case** (`save_v5_full_tier3.json` fixture per §6), which preserves the v5 plan's safety guarantee with no relaxation needed.

### 7.2 Dict-of-Dict roundtrip cost re-evaluation

The v5 plan §7.2 flagged `characters[]` as the first save schema with two-level nesting; the analysis concluded that nesting depth is irrelevant to the IndexedDB storage layer (blob-oriented; nesting collapses on JSON stringify). **Tier 3 additions do NOT change this conclusion:**

- `discovered_zones` / `discovered_waypoints` / `active_dialogue_states` / `completed_bounties` are all flat dicts/arrays at the character level — no new nesting depth introduced.
- `active_bounty` is a 1-level Dict (4 keys); same flatness as ember_bags per-stratum entry.
- `quest_progress` is the only nested-Dict addition (`Dictionary[StringName, Dictionary]`), but the inner Dict is small (~3-5 keys per archetype) and the outer Dict is bounded (1 active + ~5 completed if Option-A purge-on-turn-in adopted; ~50 if Option-B retain-for-history adopted, but Option-A is recommended in §2.7).

**Verdict: no chunking concern for Tier 3.** JSON stringify cost on low-end HTML5 stays under 100 ms per save (extrapolated from v5 plan §7.2 with +20% for the new fields). Re-evaluate at v6/v7 if cumulative save grows past 500 KB.

### 7.3 Save-write frequency change for Tier 3

Per `m3-design-seeds.md §3` + this survey:

| Tier 3 surface | New save-write trigger? | Folds into existing? |
|---|---|---|
| `world_seed` | Yes — character creation (once per character lifetime) | No, but trivial frequency (one save per character lifetime) |
| `discovered_zones` | Yes — zone-entry callback | Could fold into existing `room_cleared` save trigger; preferred: dedicated save on first-zone-enter for immediate persistence |
| `discovered_waypoints` | Yes — waypoint-interact callback | Could fold; preferred: immediate save (waypoint-discovery is a player-meaningful event) |
| `active_dialogue_states` | Yes — `dialogue_closed` signal (Option A per §3.4) | Dedicated save on dialogue close |
| `active_bounty` | Folded into Track 3 W2 quest-action save cadence | Yes — bounty accept/complete/abandon |
| `completed_bounties` | Folded same as `active_bounty` | Yes |
| `quest_progress` | Folded into existing `room_cleared` save trigger | Yes |

**Net frequency change:** +3 to +5 new save-write triggers (world_seed once, discovered_zones per zone-entry, discovered_waypoints per waypoint, active_dialogue_states per dialogue-close, with bounty/quest folding). Each is bounded (no per-frame save). Aggregate impact: ~5-10 additional saves per typical play session, each ~50-100 ms HTML5 hitch. **Acceptable.**

---

## 8. W2/W3 implementation routing

Table mapping each Tier 3 additive field to its owning ticket per `post-wave3-sequencing.md` v1.1 §4 W2/W3 pre-shape. Survey enumerates ownership so Priya's W2/W3 dispatch can use this as the authoritative ticket-vs-field matrix.

| Field | Path | Owning ticket | Wave |
|---|---|---|---|
| `world_seed` | `data.characters[N].world_seed` | Per-character `world_seed` save-write + v5 additive | W2 (Devon) |
| `discovered_zones` | `data.characters[N].discovered_zones` | Track 4 world-map UI minimal impl | W2 (Devon) |
| `discovered_waypoints` | `data.characters[N].discovered_waypoints` | Track 4 world-map UI minimal impl | W2 (Devon) |
| `active_dialogue_states` | `data.characters[N].active_dialogue_states` | Track 2 dialogue content + state-persistence impl | W2 (Devon) |
| `active_bounty` | `data.characters[N].active_bounty` | Track 3 quest-content (exploration quests + BountyController) | Track 3 W2 (Drew + content) |
| `completed_bounties` | `data.characters[N].completed_bounties` | Track 3 quest-content | Track 3 W2 |
| `quest_progress` | `data.characters[N].quest_progress` | Track 3 quest-content | Track 3 W2/W3 |
| `hub_town_seen` (recap from v5 plan) | `data.characters[N].hub_town_seen` | Sub-track 5b hub-town impl save-state wiring | W3 (Drew) |
| `hub_town_last_descended_stratum` (recap from v5 plan) | `data.characters[N].hub_town_last_descended_stratum` | Sub-track 5b hub-town impl save-state wiring | W3 (Drew) |

**Dispatch sequencing recommendation:**
1. **W2 first wave (parallel-safe):** `world_seed` save-write (Devon, ~1 ticket) + Track 2 dialogue content impl (Devon, ~3-5 tickets) + Track 4 world-map UI (Devon, ~3-5 tickets) + Track 3 quest-content authoring (Drew + Sponsor + Uma collab, ~5-8 tickets).
2. **W3 sub-track 5b hub-town:** Drew owns hub-town scene authoring; the save-state wiring for `hub_town_seen` + `hub_town_last_descended_stratum` is already pre-pinned by v5 plan §2.3 — sub-track 5b inherits, no fresh survey work needed.

**Parallel-safety note:** each W2 impl ticket touches a distinct per-character key. The `has()`-guarded backfill pattern (§5) means concurrent merges don't conflict at the schema layer — each adds its own default + its own GUT round-trip test. **The shared coordination point is `DEFAULT_PAYLOAD["character"]` in Save.gd** — if 3 PRs each add 1 key, the third PR merge resolves additively (line-level conflict, mechanical resolve). Priya's dispatch should sequence them onto the same week so the resolves happen in one orchestrator round, not across days.

---

## 9. v6 trigger guard

**Explicit statement:** no Tier 3 addition in this survey triggers a v6 schema bump.

Per `save-schema-v4-plan.md §4.1` rule 4 ("Always allowed: add a new field") + v5 plan §4.3 rule 6 ("Non-additive bumps are permitted when no additive expression exists for the feature"):

- Every Tier 3 field rides on per-character keys (additive under `data.characters[N]`).
- No Tier 3 field renames an existing field (no v4 plan §4.1 rule 1 violation).
- No Tier 3 field type-changes an existing field (no v4 plan §4.1 rule 2 violation).
- No Tier 3 field deletes an existing field (no v4 plan §4.1 rule 3 violation).
- The v5 pointer-shadow doctrine (v5 plan §4.4) is unaffected: shadows mirror `characters[active_slot]`, so any field added per-character is automatically shadowed in `data.character` on save. **No new shadow-discipline burden** introduced by Tier 3.

**SCHEMA_VERSION stays at 5** across all Tier 3 W2/W3 implementation PRs. The `data.envelope.schema_version` on disk reads `5` for both v5-baseline saves and Tier-3-extended saves. The distinguishing test is field-presence (`has("world_seed")`) not version-number.

**When v6 WOULD trigger** (not Tier 3, but flagged for future awareness):
1. If the dialogue system's `active_dialogue_states` value-type changes from `StringName` to `Dictionary` (e.g. tracking per-line-position for mid-line resume). That's a v4 plan §4.1 rule 2 violation → v6 + non-additive bump.
2. If `completed_bounties` Array semantics change (e.g. to `Dictionary[StringName, CompletionMetadata]` for telemetry). Rule 2 violation → v6.
3. If `world_seed` becomes per-stratum instead of per-character. Rule 1 (rename) + rule 2 (type) violation → v6.

None of these are in scope for Tier 3. Survey flags them so authors don't accidentally trigger v6 thinking they're being additive.

---

## 10. DECISIONS log entry (one-line append for Priya's weekly batch)

To be batched into `team/DECISIONS.md` by Priya on merge — drafted here per `same-day-decisions-rebase-pattern` (avoid same-day direct DECISIONS.md edits):

```
## 2026-05-22 — Save schema v5 Tier 3 additive layer survey
- Decided by: Devon (M3 Tier 3 W1 ticket `86c9xuc17`)
- Decision: Save schema v5 Tier 3 additive layer surveyed at `team/devon-dev/save-schema-v5-tier3-additions.md` — 7 per-character additive fields (`world_seed`, `discovered_zones`, `discovered_waypoints`, `active_dialogue_states`, `active_bounty` (recap), `completed_bounties`, `quest_progress`) + recap of v5-plan-resolved `hub_town_seen` + `hub_town_last_descended_stratum`. Zero new `meta.*` root keys. `meta.dialogue_settings` surveyed + rejected (no W2 surface needs it). All additions ride v5 per-character key namespace via `has()`-guarded backfill; **no v6 schema bump triggered**. 7 new test fixtures catalogued for W2 impl tickets to author. HTML5 size delta +4 KB typical / +13 KB worst per character; well within v5 §7 quota. Three per-field Sponsor-decision surfaces flagged: (a) `discovered_zones` per-character vs account-scoped (recommendation: per-character), (b) `active_dialogue_states` Option A per-NPC-current-branch vs Option B per-quest-progressed (recommendation: A), (c) `world_seed = 0` sentinel re-roll-on-first-load vs deterministic-legacy (recommendation: re-roll). All three default to recommendation if Sponsor doesn't weigh in at W2 impl dispatch. Implementation lands across W2 procgen / W2 map-UI / W2 dialogue / Track 3 W2 quest-content / W3 sub-track 5b hub-town tickets.
- Why: M3 Tier 3 introduces 5+ new save-write surfaces (Commitment 5 / Track 2 / Track 3 / Track 4 / sub-track 5b). Without a consolidated survey, each W2/W3 ticket re-discovers the v5 + additive structure piecemeal. Survey enumerates field-vs-owning-ticket matrix + round-trip invariants + Sponsor-decision surfaces so W2/W3 dispatches inherit unified vocabulary + fixture catalog + cross-character semantics.
- Reversibility: reversible — paper survey only; W2 impl tickets implement field-by-field. Any field can be re-shaped before its first W2 impl PR merges. Once a field's W2 impl ships and saves are written with the field, the field becomes sticky per v4 plan §4.1 rules 1-3 (no rename / no type-change / no delete while readers exist).
```

---

## 11. Cross-references

- `team/devon-dev/save-schema-v5-plan.md` (PR #256, merged) — v5 baseline; this survey extends additively per v5 plan §11 finding 4 ("schema bumps are doc-PRs first")
- `team/devon-dev/save-schema-v4-plan.md` §4.1 (additive-only rule) — rules 1-5 + v5 plan §4.3 rule 6 govern this survey
- `team/priya-pl/post-wave3-sequencing.md` v1.1 §1 Commitment 3 + Commitment 4 + Commitment 5 — design substrate for `discovered_zones` + `discovered_waypoints` + `world_seed`
- `team/priya-pl/post-wave3-sequencing.md` v1.1 §3 calendar + §4 W2/W3 pre-shape — dispatch sequencing source
- `team/priya-pl/post-wave3-sequencing.md` v1.1 §6 SI-1 through SI-5 + SI-8 Sponsor sign-offs — Diablo-shape commitments + procgen scope locked
- `team/priya-pl/m3-design-seeds.md` §2 Save-schema implications + §3 NG+ Paragon + bounty content — `active_bounty` shape source
- `team/priya-pl/mvp-scope.md` §M3 — bounty quest system context
- `team/priya-pl/risk-register.md` R1 (save migration breakage) + R-PROCGEN.a (per-character seed save-binding) — mitigation: round-trip invariants per-field in §2/§4
- `team/drew-dev/level-chunks.md` § "Zone schema" (PR #312) — `ZoneDef.zone_id: StringName` consumed by `discovered_zones` + `quest_progress` zone-bound bounties
- `scripts/dialogue/DialogueTreeDef.gd` + `DialogueController.gd` (PR #319) — `npc_id: StringName` consumed by `active_dialogue_states`; `quest_action_invoked` signal is the dialogue↔quest coupling point (§4)
- `team/uma-ux/world-map-direction.md` (PR #308) — parchment per-stratum map visual design; consumes `discovered_zones` + `discovered_waypoints` at W2 Track 4 impl
- `team/uma-ux/hub-town-direction.md` §7 — per-character `hub_town_seen` + `hub_town_last_descended_stratum` design rationale (resolved per Sponsor 2026-05-17, lives at v5 plan §2.3)
- `.claude/docs/test-conventions.md` § Universal warning gate — every W2/W3 save-load test runs under `NoWarningGuard`; routes warnings through `WarningBus.warn(text, "save")`
- `.claude/docs/html5-export.md` § Resource enumeration on packed `.pck` resources — HTML5 storage context (saves live in IndexedDB `user://`, unaffected by `.pck` recursion)
- ClickUp `86c9xuc17` — this survey's dispatch ticket

---

## 12. Non-obvious findings

1. **The dialogue↔quest coupling is signal-based, not data-coupled.** The dialogue spike (PR #319) deliberately keeps `DialogueController` blind to bounty state — the controller fires `quest_action_invoked(action_id, npc_id)` and the Track 3 W2 BountyController subscribes. Survey reinforces this isolation: the schema layer DOES NOT add cross-field invariants (e.g. "if `active_bounty.quest_id == X` then `active_dialogue_states[questgiver_npc] == &"quest_active"`"). Such invariants would be game-state contracts enforced at runtime, not save-layer contracts enforced at JSON shape. **Survey discipline:** never add cross-field invariants at the schema layer; let runtime systems own their own state coherence.
2. **`hub_town_seen` Sponsor-reversal is a precedent for the diegetic-first per-character default.** v5 plan §2.3 captures Sponsor's 2026-05-17 reversal (account-scoped → per-character). Three Tier 3 additions in this survey inherit that precedent: `discovered_zones`, `discovered_waypoints`, `active_dialogue_states` all default to per-character. **The pattern:** any field that represents "the character's relationship with the world" defaults per-character; only player-keyboard-config fields would land at `meta.*` account-scoped. No `meta.*` additions surfaced in Tier 3 confirms the pattern is robust.
3. **The W2 impl PRs converge on `DEFAULT_PAYLOAD["character"]` in Save.gd.** Three Track 2/3/4 W2 PRs each add their key + default to `DEFAULT_PAYLOAD["character"]`. Merge-order matters for textual conflict resolution but not for semantic correctness (additive rule guarantees each new key is independent). Priya's dispatch should sequence them onto the same week so resolves happen in one orchestrator round; spreading them across days multiplies the conflict surface.
4. **`world_seed = 0` sentinel is the only Tier 3 field that needs runtime-side discipline beyond the schema layer.** Every other Tier 3 field is JSON-pure additive — the schema layer fully describes the field's lifecycle. `world_seed` needs the procgen runtime to detect-and-re-roll on first post-Tier-3 load. Survey flags this as the one cross-layer discipline; W2 procgen-impl ticket owns the runtime gate. If the gate is missed, the bug manifests as "all pre-Tier-3 characters share the same procgen map" (deterministic seed=0). A future telemetry probe `test_no_loaded_character_has_world_seed_zero_after_first_load` would catch it; out of scope for the survey itself.
5. **`active_dialogue_states` granularity decision (Option A vs B in §3.4) is the most-impactful Sponsor-decision surface.** Option A (per-NPC current-branch) is recommended for Diablo-II-precedent + diegetic continuity. Option B would simplify save cadence but break the "NPC remembers the last topic" Diablo convention. Survey flags both for Sponsor weigh-in at W2 dialogue-impl dispatch; default Option A. **The decision is reversible** (granularity change is additive at the schema layer; the runtime save-write trigger swaps), so it's a soft-gate decision Sponsor can defer to W2 review without blocking the spike.
6. **The fixture catalog grows v5 fixture count from 8 → 15 by end-of-W3.** Tess's M3 Tier 3 acceptance gate (`team/tess-qa/m3-acceptance-plan-tier-3.md`) absorbs this; the fixture-authoring burden is bounded because each fixture is hand-authored ~50-line JSON (~30 min per fixture). Survey flags the bandwidth + the routing: W2 impl tickets author their own fixtures (not Tess); Tess wires them into the test suite. This preserves Tess's QA-gate role (verification, not authoring) per the v5 plan §10 hand-off.
