# Performance Budget — Embergrave HTML5 Build (M1 baseline → M2 regression gate)

**Owner:** Priya · **Tick:** 2026-05-03 (M1 RC `embergrave-html5-4484196` in active Sponsor soak; combat-fix dispatch in flight; M2 week-1 + week-2 backlogs drafted; orchestrator just dispatched T-EXP-2 from `backlog-expansion-2026-05-02.md`) · **Status:** v1 proposed budget — six concrete metrics with targets + measurement methodology + regression gate proposal. Estimates are derived from architecture inspection, not measured actuals; baseline-confirmation pass is a prerequisite for the gate to fire (see §6).

## TL;DR (5 lines)

1. **Six metrics measured:** frame rate, peak heap memory, draw calls per frame, save/load latency, HTML5 build artifact size, boot-to-playable time. All HTML5-specific (browser playback is the ship target — desktop perf is not the constraint).
2. **Targets held** (per metric, ship-blocking):  60 FPS at 480×270 internal canvas with 50 FPS floor over 30s; <100 MB peak heap; <100 draw calls normal play / <200 boss climax + visual feedback; <100 ms save round-trip; <500 ms full v3→v4 migration; <10 MB HTML5 zip artifact; <3 s boot-to-playable on localhost.
3. **Regression gate primary:** **Tess manual checklist on every M2 RC** (one row per metric, eye-on-DevTools), with a CI step running `godot --headless --benchmark` on a deterministic scene as the cheap-CI complement when Devon's bench harness lands. Manual-first because we don't have the harness yet; automated-second when T-EXP-2-FOLLOWUP ships.
4. **M1 baseline (estimated, not measured):** ~60 FPS sustained, ~40-60 MB heap, ~30-50 draw calls, ~20-50 ms save round-trip, **8.49 MB** HTML5 zip (actual, from RC `4484196`), ~2-3 s boot. All within budget. Headroom for M2 stash + audio + S2 content adds before any budget trips.
5. **Top open questions:** (a) is the 50 FPS floor the right floor for HTML5 — or do we need 30 FPS for tab-defocus / low-end browsers; (b) does the manual-first gate hold once M2 ships six new HTML5 surfaces or do we need automated bench earlier; (c) should peak-heap be measured in-engine with `Performance.get_monitor` or via Chrome Memory tab — both are imperfect on web.

---

## 1. Source of truth

This budget derives from direct reads of the following artifacts. Per `agent-verify-evidence.md`: every target is grounded in observed architecture / observed M1 numbers / observed audio cue cost, not reasoned-from-priors.

1. **`team/priya-pl/risk-register.md`** (refreshed 2026-05-03, `b704345`+) — **R3-M2** (HTML5 export regression, M2-introduced surfaces) is the load-bearing risk this budget mitigates. R3 closed at M1 close; the register explicitly re-opens it as **R3-M2** at M2 dispatch entry, listing six new HTML5 surfaces: v4 save with Dictionary-of-Dictionary OPFS roundtrip, stash UI 12×6 cell rendering, ember-bag pickup with sprite anim + audio, stratum-2 entry with ambient tint, Stoker cone-fire-breath telegraph, audio sourcing pass. Each of these can blow a different budget; without per-metric targets there is no signal to act on.
2. **`team/priya-pl/m2-week-2-backlog.md`** §"Tickets" — W2-T3 (S2 boss room first impl L) + W2-T4 (MobRegistry refactor) + W2-T5 (v4 stress fixtures) all touch performance-sensitive code paths. W2-T5 §Acceptance explicitly references the v4 round-trip timing budget ("<50ms desktop, <500ms HTML5 — coordinates with W2-T11 performance budget"). The `<500 ms HTML5` figure is consumed verbatim into §3 below.
3. **`team/uma-ux/audio-direction.md`** §2 cue list (60+ rows) + §3 mixing/ducking rules — the audio cues add real perf cost. Notable load: 5-bus structure (Master / BGM / Ambient / SFX / UI / Voice-reserved), sidechain compression on SFX→BGM at 50 ms attack / 400 ms release, **always-on ambient bed** (`amb-stratum1-room` + positional `amb-stratum1-torch`) layered under BGM, plus `mus-stratum1-bgm` looped 90-120s. M1 active audio voices: roughly 2 always-on (BGM + ambient bed) + 1-3 transient SFX (footstep / hit / aggro / pickup) + 1 positional torch ambient when player within 4 tiles. M2 adds `mus-stratum2-bgm` + `amb-stratum2-room` + ducking-aware boss-music switch — voice-count grows but not above ~6 simultaneous. Audio decode + sidechain math is non-trivial on HTML5 web-audio backend; see §3.6 boot-to-playable for the audio-decode cost on stratum entry.
4. **`team/priya-pl/backlog-expansion-2026-05-02.md`** T-EXP-2 spec (lines 116-129) — original ticket shape said "Devon owner, performance-budget.md under devon-dev/, browser-DevTools-Performance + GUT-timing + gh-release-view methodology, M1 baseline numbers populated, M2 fail-fast gates identified." The orchestrator's run-009 dispatch reframes ownership: PL drafts the budget (this doc), Devon implements the bench harness when T-EXP-2-FOLLOWUP fires. Doc lives under `priya-pl/` (PL-owned; the budget is a planning artifact, not a code artifact).
5. **`project.godot`** lines 36-40 — **window/size/viewport_width=1280, viewport_height=720** but the rendering target is **480×270 internal canvas, integer-scaled** per visual-direction.md commitments (1280 = 480 × 2.66 — the actual integer-scale ratio is canvas-items stretch with viewport doing the upscale; effective pixel work is 480×270 = 129,600 pixels, not 1280×720 = 921,600 pixels). This 7× pixel-work reduction is load-bearing for the FPS budget — without it, GL Compatibility renderer on HTML5 would struggle to hit 60 FPS on low-end browsers.
6. **`project.godot`** lines 21-29 — **7 autoloads:** Save, BuildInfo, DebugFlags, Levels, PlayerStats, StratumProgression, Inventory. Each loads at boot. Heap impact ~negligible per autoload (single Object + script class), but boot-to-playable scales with autoload `_ready()` cost. M2 adds **SaveSchema** autoload (T2 in week-1 backlog) + likely **MobRegistry** autoload (W2-T4) → 9 autoloads. Within budget.
7. **Repo file counts** (architecture inventory) — 25 `.tscn` files, 44 `.gd` scripts, 19 `.tres` resources, 49 test files. Main.tscn is the play surface (post-PR #107 integration). 8 stratum-1 rooms + 1 boss room + 1 healing fountain + 1 stratum-exit scene + 4 mob scenes + 4 UI scenes + ~3 player/projectile scenes. Per-room mob count: 1-3 grunts in non-boss rooms; boss room has 1 boss + entry-trigger Area2D. Total live nodes per room when player in it: ~30-60 (room geometry + 1-3 mobs + player + projectiles + UI overlays + autoload nodes). This count drives the draw-call estimate (§3.3) and heap estimate (§3.2).
8. **GitHub release artifact `embergrave-html5-4484196`** — actual file size **8.49 MB** zip (from `m2-week-1-backlog.md` capacity check + risk register R3 evidence row). This is the M1 hard data point; everything else is architecture-derived estimate.

---

## 2. Why these six metrics

The metric list is the intersection of (a) what HTML5 builds can plausibly regress on, (b) what the team can measure cheaply, and (c) what Sponsor would actually notice on his next soak.

- **Frame rate:** the most user-visible regression. Sponsor's soak is the only real signal we have; if FPS drops below 50 sustained, action-game feel breaks down (combat windows are 100-180 ms — at 30 FPS that's 3-5 frames per recovery window, audit threshold).
- **Peak heap memory:** HTML5 has a practical cap (~1-2 GB per tab on desktop; lower on mobile / low-end). 100 MB target is conservative — gives 10× headroom before browser-tab kill becomes likely. M2's v4 schema with full stash + multi-stratum ember-bags will grow heap; we want signal before it bites.
- **Draw calls per frame:** GL Compatibility renderer on HTML5 is draw-call-bound much sooner than Vulkan-desktop. Each Sprite2D + each AudioStreamPlayer2D + each CPUParticles2D adds calls. Combat-feedback design (Uma's `combat-visual-feedback.md`) explicitly adds 6-particle ember bursts (24 particles for boss climax) — particle overdraw is a real risk.
- **Save/load latency:** v3 schema is small (<10 KB JSON typically); v4 grows to potentially 50 KB at full stash. HTML5 OPFS round-trip is ~10× slower than desktop FileAccess. Player feels the latency on every auto-save (post-room-clear, post-level-up, post-loot-pickup). >100 ms is felt; >500 ms is broken.
- **Build artifact size:** itch-deploy + browser-load latency. Currently 8.49 MB; M2 adds audio (~3-5 MB OGG q5/q7) + S2 sprites (~0.5 MB PNG) + stash UI assets (~0.1 MB). Headroom matters because once we exceed ~15 MB, browser-cache misses become user-noticeable on slower connections.
- **Boot-to-playable:** time-to-first-input from page-load. Drives "feel" of the demo. Audio decode of ambient + BGM at boot is the largest contributor (per `audio-direction.md` §2, BGM is ~90-120s OGG @ q7 = ~2-3 MB decoded). 3 s target gives Sponsor a snappy first impression.

**Metrics deliberately NOT in the budget (and why):**
- **GPU shader compile time:** GL Compatibility minimal-shader project; not a meaningful surface.
- **Network latency:** game is offline-only; no multiplayer in M1-M3.
- **Per-frame CPU time:** subsumed by FPS metric (60 FPS = 16.6 ms per frame, the budget is implicit).
- **Garbage collection pause time:** subsumed by FPS floor (50 FPS floor = the largest acceptable GC pause is ~12 ms; if it exceeds, FPS metric trips).
- **Test-suite runtime:** Devon's `ci-hardening.md` covers CI runtime separately; not a player-facing metric.

---

## 3. Per-metric targets and budgets

### 3.1 Frame rate

- **Target:** 60 FPS at 480×270 internal canvas, integer-scaled to viewport.
- **Floor:** **50 FPS sustained over a 30 s window**. Single-frame dips below 50 are tolerated; a 30-frame moving-average below 50 is a regression.
- **Hard fail:** any 30 s window with mean FPS below 30. This is the "game is unplayable" boundary.
- **Where regression risks live:**
    - Boss fight with breath-cone particles + hit-flash + screen-shake + boss climax 24-particle ember burst (M2 W2-T3 Vault-Forged Stoker; visual-feedback overlap).
    - Stash UI open with 12×6 = 72 item slots, each rendering a Sprite2D + tier-tint Modulate (M2 W2-T3 — 72 sprites is non-trivial on GL Compat).
    - 3-mob room with active projectiles (Shooter mob fires + Charger windup particles + mob hit-flashes simultaneously).

### 3.2 Peak heap memory

- **Target:** <100 MB peak heap on web build.
- **Soft warning:** >75 MB at any point — investigate.
- **Hard fail:** >150 MB at any point — ship-blocker.
- **Why these numbers:** Chrome and Firefox impose practical per-tab caps around 1-2 GB on desktop; <100 MB gives 10-20× headroom before tab-kill risk. M2's v4 schema with full stash (72 items) + 3 ember-bags + multi-stratum cleared-state can plausibly add 5-10 MB to base heap; 100 MB target absorbs that comfortably.
- **Where regression risks live:**
    - Texture atlas growth with S2-S8 sprite additions (each soft-retint sprite is ~10 KB PNG on disk, ~50-100 KB decoded as RGBA8 texture).
    - Audio stream caching — if Devon's audio-loader keeps all 60+ cues decoded simultaneously instead of LRU-evicting, ~20-40 MB heap could go to audio buffers alone.
    - Save state grows with stash + ember-bag history; each saved-and-loaded round-trip allocates fresh Dictionary/Array allocations.

### 3.3 Draw calls per frame

- **Target:** <100 draw calls per frame in normal play (player + 1-3 mobs in a stratum-1/2 room with default UI hidden).
- **Boss + visual feedback peak:** <200 draw calls (boss attack with telegraph particles + player swing wedge + mob hit-flashes + screen-shake + ember burst on enemy death).
- **Hard fail:** any single-frame >300 draw calls — render-pipeline saturated on GL Compatibility HTML5.
- **Why these numbers:** GL Compatibility renderer batches CanvasItem draws per material/texture; each unique sprite atlas + each particle system breaks a batch. 100 calls = healthy budget for a 480×270 pixel-art game; 200 = peak combat headroom; >300 starts to bottleneck on web GPU drivers.
- **Where regression risks live:**
    - Each mob's hit-flash modulate may force a re-batch if not already on shared atlas.
    - CPUParticles2D bursts (6 particles default, 24 for boss climax) add ~6-24 draw calls per active emitter.
    - Stash UI 72 sprites + tier tints — if not atlased correctly, 72+ calls just for the panel.

### 3.4 Save/load latency

- **Target round-trip (`Save.save_game(0)` → file written → `Save.load_game(0)` → state restored):**
    - **<50 ms on desktop** (existing M1 baseline observation; not formally measured).
    - **<100 ms on HTML5** (OPFS round-trip is ~10× slower than desktop FileAccess; budget reflects browser tax).
- **Full v3→v4 schema migration:** **<500 ms on HTML5**, **<100 ms on desktop**. Migration runs once on first load after upgrade; user-felt latency is a one-time cost on the next save-load cycle.
- **Hard fail:** any save round-trip >250 ms on HTML5 (player feels the auto-save stutter); any migration >2 s (looks like the game froze).
- **Where regression risks live:**
    - v4 schema full stash (72 items × ~150 bytes each + affixes per item) JSON-serializes to ~15-25 KB.
    - HTML5 OPFS write is async-promise-based; Devon's wrapper synchronizes via await — slow path.
    - Migration `_migrate_v3_to_v4` per `save-schema-v4-plan.md` is idempotent + has()-guarded — should be cheap, but stress fixtures (W2-T5) confirm.
- **Note:** The M2 W2-T5 ticket explicitly references "<50ms desktop, <500ms HTML5 — coordinates with W2-T11 performance budget." Those numbers are adopted into this budget verbatim and become the formal target.

### 3.5 Build artifact size

- **Target:** **<10 MB HTML5 zip artifact**.
- **Soft warning:** >12 MB — investigate; itch-deploy gets slower, browser cache pressure rises.
- **Hard fail:** >20 MB — Sponsor's first-load latency on a residential connection becomes user-noticeable (>2-3 s download).
- **Current actual (M1 RC `4484196`):** **8.49 MB**. Budget room: 1.5 MB before soft warning, 3.5 MB before hard fail.
- **What M2 adds (estimated):**
    - Audio sourcing pass (T10 week-1, T9 week-2): ~3-5 MB OGG (q5 SFX cues + q7 BGM + ambient). Could push artifact to 11-13 MB if all cues source as hand-composed at q7.
    - S2 sprites (W2-T2 soft-retints — palette swap of S1 silhouettes): ~0.5 MB.
    - Stash UI scene + assets: ~0.1 MB.
    - Stratum-2 rooms (W2-T1, W2-T3): ~0.2 MB scene+chunk.
    - Total M2 add estimate: **~4-6 MB** on top of M1's 8.49 MB. **Plausibly trips the 10 MB target.**
- **Mitigation lever if budget trips:** OGG Vorbis q5 (SFX) is already at the lowest sane setting; q7 (music + ambient) is also reasonable. The lever is **placeholder loops vs. final compositions** for the music cues — placeholder loops compress smaller. Per `audio-direction.md` open question on M3 scoring contract, M2 RC can ship with placeholder music if budget pressure forces it.

### 3.6 Boot-to-playable

- **Target:** **<3 s from page-load to first-input-response on a typical localhost serve**.
- **Stretch:** <2 s — feels snappy, comparable to itch.io demos.
- **Hard fail:** >5 s — Sponsor mentally checks out before he even gets to play.
- **Where the time goes (M1 estimated):**
    - HTML5 wasm + assets download: ~0.5 s on localhost (8.49 MB at gigabit-localhost).
    - Godot engine init + GL context: ~0.3-0.5 s (engine fixed cost).
    - Autoload `_ready()` calls (7 autoloads M1; 9 autoloads M2): ~50-100 ms cumulative.
    - Main.tscn instantiation + initial room load: ~200-400 ms (loads 8 stratum-1 chunks lazily? confirm — currently all 8 may eager-load).
    - Audio decode of `mus-title` + `mus-stratum1-bgm` + `amb-stratum1-room` (~3-5 MB OGG total): ~500-800 ms on web-audio backend.
    - First input-paint cycle: ~16 ms (one frame at 60 FPS).
    - **Total estimate: ~1.5-2.5 s.** Within 3 s target with comfortable margin.
- **M2 risk:** if the audio-loader eagerly decodes all 60+ cues at boot, decode time grows linearly. Per `audio-direction.md` §4 source-of-truth flow, the audio-loader builds a flat dictionary `cue_id → AudioStream` — Devon's call whether `AudioStream` resources lazy-decode (default) or eager-decode. If eager, M2 boot time could blow past 3 s. **Mitigation:** lazy-decode SFX (small files; first-fire latency negligible), eager-decode the always-on `mus-` and `amb-` cues only.

---

## 4. Measurement methodology per metric

### 4.1 Frame rate

- **Local (dev machine):** Godot editor → run with `--debug-collisions --print-fps` flag, or query `Engine.get_frames_per_second()` in a debug HUD overlay.
- **HTML5 build (browser):** Chrome DevTools → Performance tab → record 30 s → read FPS meter. Or in-game debug HUD reading `Engine.get_frames_per_second()` rendered to a corner Label2D when `DebugFlags.fps_overlay()` flag is on.
- **CI:** `godot --headless --benchmark <scene_path> --duration 30` — Devon's bench harness (T-EXP-2-FOLLOWUP). Outputs mean FPS + 1% low + 0.1% low. Not feasible in current CI without harness; manual-first.
- **Sponsor soak:** Tess includes "FPS holds at 60" as a probe target row in `m2-acceptance-plan-week-1.md`/`m2-acceptance-plan-week-2.md`. Sponsor reports if game feels stuttery — that's the human signal.

### 4.2 Peak heap memory

- **In-engine:** `Performance.get_monitor(Performance.MEMORY_STATIC)` — returns bytes used by Godot's static allocator. NOT the same as JS heap (HTML5 export wraps Godot in a wasm runtime; JS heap is separate). Use as the primary in-engine signal.
- **HTML5 browser:** Chrome DevTools → Memory tab → Heap Snapshot at three points: boot, mid-combat (with stash open), boss-fight peak. Compare snapshots for growth.
- **CI:** Devon's `--benchmark` harness can dump `MEMORY_STATIC` peak — same as FPS bench, packaged as a single bench-run.
- **Note on web-vs-desktop:** the JS-side wasm heap on HTML5 is the binding constraint, not Godot's internal `MEMORY_STATIC`. We track both because they correlate but aren't identical. **Open question 3 (§9):** which is the load-bearing number for the budget?

### 4.3 Draw calls per frame

- **In-engine:** `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` — Godot exposes this directly. Sample once per frame in a debug HUD.
- **HTML5 browser:** Chrome DevTools → Rendering tab → "Frame Rendering Stats" overlay shows GPU work; not exact draw-call count but a proxy.
- **CI:** Devon's bench harness samples `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` over the 30 s window, outputs mean + p99. Same packaging as FPS / heap.

### 4.4 Save/load latency

- **In-engine GUT test:** `tests/test_save.gd` already exists. Add a **timing assertion**: `var t0 = Time.get_ticks_msec(); Save.save_game(TEST_SLOT); Save.load_game(TEST_SLOT); var dt = Time.get_ticks_msec() - t0; assert_lt(dt, 100, "save round-trip exceeded 100ms")`. This catches desktop regressions cheaply.
- **HTML5 timing:** harder — GUT doesn't run in browser. Tess runs a manual `m2-rcN` probe with the in-game save flow + browser DevTools Performance recording. **OR** Devon adds a `DebugFlags.save_timing()` flag that writes elapsed-ms to console + a corner toast on every save. Then HTML5 round-trip is observable on every soak.
- **CI:** the timing-assertion test runs in headless GUT (desktop FileAccess); covers the desktop budget. HTML5 budget is manual-first per the gate-proposal in §5.

### 4.5 Build artifact size

- **Local:** after `godot --export-release HTML5`, `ls -la build/web/embergrave-html5.zip`.
- **CI:** the existing release-build workflow (per Devon's `ci-hardening.md`) already produces the zip. Add a step: `BUDGET=10485760; SIZE=$(stat -c%s embergrave-html5.zip); [ $SIZE -lt $BUDGET ] || (echo "Build artifact $SIZE > budget $BUDGET"; exit 1)`. **Cheapest CI gate of all six metrics — should ship first.**
- **Release tracking:** `gh release view <tag> --json assets` exposes per-asset size. Tess includes "build artifact ≤10 MB" as a row in the M2 RC audit checklist.

### 4.6 Boot-to-playable

- **Local:** browser DevTools → Network tab → record from page-load → first-input-paint. Look for the first `requestAnimationFrame` after the canvas is interactive.
- **HTML5 instrumentation:** inject `console.time('boot')` on page-load + `console.timeEnd('boot')` from Godot autoload `_ready()` of a sentinel autoload (`BuildInfo` already exists, can carry the marker). Console output is the timing.
- **CI:** not feasible without browser CI runner; manual-first. Sponsor-soak probe target: "did the game feel snappy to start?" is the human signal.

---

## 5. Regression gate proposal (PRIMARY: manual; SECONDARY: automated when harness lands)

**Decision: manual checklist + cheap CI step is the primary gate; automated bench harness is the deferred follow-up.**

### Why manual-first

1. **No bench harness exists yet.** Devon's `ci-hardening.md` explicitly defers per-test runtime profiling and automated coverage to v2 (still not built). A `godot --headless --benchmark` harness is a new infrastructure build with its own design + paired-test cost. Building it is a separate ticket (T-EXP-2-FOLLOWUP — see §10).
2. **Tess already runs the M2 RC audit pattern** (see W3-A5 / W2-T11). One more checklist row per metric is a 5-minute add to her existing flow.
3. **Six metrics × manual check = ~10-15 minutes per RC.** Acceptable for the M2 RC frequency (1-2 per week).
4. **Sponsor's soak is the ultimate gate anyway** — if FPS drops or boot time blows up, his interactive run surfaces it within minutes. Manual checklist is the team's last-line-of-defense before he sees it.

### What ships now (manual gate)

Tess adds a §"Performance Budget" section to `m2-acceptance-plan-week-1.md` (and week-2 / week-3 successors) with one row per metric:

| ID    | Metric             | Target                   | Pass? |
|-------|--------------------|--------------------------|-------|
| PB-01 | Frame rate         | 60 FPS / 50 floor 30s    | yes   |
| PB-02 | Peak heap          | <100 MB                  | yes   |
| PB-03 | Draw calls         | <100 normal / <200 peak  | yes   |
| PB-04 | Save round-trip    | <100 ms HTML5            | yes   |
| PB-05 | v3→v4 migration    | <500 ms HTML5            | yes   |
| PB-06 | Build artifact     | <10 MB                   | yes   |
| PB-07 | Boot-to-playable   | <3 s                     | yes   |

Each row includes the measurement method (Chrome DevTools, GUT timing, `gh release view`, etc. per §4). On any fail, Tess files a `bug(perf):` ticket against the responsible feature ticket.

### What ships cheap-now (CI artifact-size gate)

The build-artifact size budget (PB-06) is the **only metric that's already CI-measurable today**. Devon adds a single `bash` step to the existing release-build workflow:

```bash
BUDGET=$((10 * 1024 * 1024))  # 10 MB
SIZE=$(stat -c%s build/web/embergrave-html5.zip)
if [ "$SIZE" -gt "$BUDGET" ]; then
  echo "::error::Build artifact $SIZE bytes exceeds budget $BUDGET"
  exit 1
fi
echo "Build artifact $SIZE bytes — within budget $BUDGET"
```

Five-minute add. Ships as part of T-EXP-2-FOLLOWUP or piggybacks on the next CI-touching PR.

### What ships later (automated bench)

Devon's `T-EXP-2-FOLLOWUP — perf bench harness` ticket (P1, deferred to M2 week-3 or later):

1. New script `scripts/debug/PerfBenchmark.gd` — autoload-able when `--bench` CLI flag is set; runs a deterministic 30 s scene (boss fight + stash open + 3-mob room) and outputs JSON `{fps_mean, fps_p1, draws_mean, draws_p99, heap_peak}`.
2. New CI workflow step `bench.yml` runs `godot --headless --bench scenes/Main.tscn --duration 30 > bench.json`.
3. CI compares `bench.json` to budget thresholds; failing values produce annotation comments on the PR.
4. Save round-trip + boot-to-playable remain manual until headless-browser CI is feasible (also deferred — `m2-week-2-backlog.md` W2-T5 acknowledges headless GUT for HTML5 isn't yet built).

This split keeps the M2-blocking budget enforceable today (manual) without waiting on harness work that has its own design + test cost.

---

## 6. Current measurements (M1 baseline — best-guess from architecture, not measured)

**Caveat:** these are estimates. The first action when this budget lands is for Tess (and/or Devon) to run the manual checklist on the M1 RC `4484196` and confirm/adjust. Do **not** treat these as actual M1 floors.

| Metric             | Estimated M1 baseline    | Confidence | Notes                                                                                                                       |
|--------------------|--------------------------|------------|-----------------------------------------------------------------------------------------------------------------------------|
| Frame rate         | ~60 FPS sustained        | medium     | 480×270 internal canvas, GL Compat, ~30-60 nodes per room — should be comfortable. M1 had no FPS complaints in soaks.        |
| Peak heap          | ~40-60 MB                | low        | 7 autoloads + ~10 KB save data + ~3-5 MB audio buffers (BGM + ambient always-on) + texture atlases ~5-10 MB.                  |
| Draw calls         | ~30-50 normal            | medium     | Per-room: ~8 tiles + 1-3 mobs + 1 player + UI HUD = ~15-25 sprites; particles add ~5-10 on combat; 30-50 is conservative.      |
| Save round-trip    | ~20-50 ms desktop / ~50-100 ms HTML5 | medium | v3 schema is small (<10 KB); FileAccess is fast on desktop; OPFS is the slowdown on web.                       |
| v0→v3 migration    | ~5-15 ms desktop         | high       | Five M1 schema bumps shipped; each migration is mechanical has()-guarded; `test_save_migration.gd` exercises this hot.      |
| Build artifact     | **8.49 MB** (actual)     | **high**   | Confirmed from `embergrave-html5-4484196` GitHub release asset. Only metric with a hard data point.                         |
| Boot-to-playable   | ~1.5-2.5 s (localhost)   | low        | No instrumentation yet; estimate from autoload + decode load. Sponsor's soak doesn't complain about boot time so far.        |

**Interpretation:** all M1 estimates are within budget with comfortable headroom. M2 has room to add stash + audio + S2 content before any single budget trips, **except** the build-artifact size is the most likely first-trip — 8.49 MB plus M2's estimated +4-6 MB plausibly hits 10 MB.

**First-action follow-up:** when this PR merges, orchestrator routes a Tess (or Devon) probe-pass on RC `4484196` to confirm/correct the estimates above. Updated numbers replace the estimates in §6 as a v1.1 of this doc.

---

## 7. M2 risk surfaces — per HTML5 R3 escalation

Per `risk-register.md` R3-M2, six new HTML5 surfaces ship in M2 week-1. Below: which budget each surface most likely trips, plus mitigation lever.

| # | M2 surface (R3 list)                          | Most-likely-tripped budget               | Why                                                                                       | Mitigation lever                                                              |
|---|-----------------------------------------------|------------------------------------------|-------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| 1 | v4 save with Dict-of-Dict OPFS roundtrip      | **Save round-trip latency** (PB-04)      | OPFS async + larger JSON shape (stash + bags) → cumulative round-trip grows.              | Lazy-write strategy (don't auto-save mid-combat); compress JSON if >25 KB.    |
| 2 | Stash UI 12×6 cell rendering                   | **Draw calls** (PB-03) + **Heap** (PB-02) | 72 sprites + 72 tier-tints + tooltip atlas. Each Modulate call may re-batch.              | Atlas all stash icons into one texture; reuse Modulate via shared material.   |
| 3 | Ember-bag pickup w/ sprite anim + audio        | **Draw calls** (PB-03) + **Heap** (PB-02) | Sprite anim adds frames; audio cue decode adds heap.                                      | Reuse pickup particle system from existing loot drops; lazy-decode audio.     |
| 4 | Stratum-2 entry with ambient tint              | **Boot-to-playable** (PB-07)             | New tile palette + ambient cue decode + tint shader (if any).                             | Pre-decode `amb-stratum2-room` only when player crosses S1→S2 threshold.      |
| 5 | Stoker cone-fire-breath telegraph              | **Draw calls** (PB-03) + **Frame rate** (PB-01) | Cone telegraph + breath particles + screen feedback layered with player swing/hit-flash. | Bound particle count; pre-warm tween instances; shared ember atlas.            |
| 6 | Audio sourcing pass (5+ new cues)              | **Build artifact** (PB-05) + **Heap** (PB-02) | Each new cue adds ~50-300 KB OGG + decoded buffer when active.                            | Strict q5/q7 quality limits; only eager-decode always-on cues.                |

**Cross-cutting mitigation:** every M2 PR that touches one of these surfaces includes a manual perf-budget probe in its PR description (`PB-XX measured: [target] / [actual] / [pass/fail]`). The author runs it themselves at PR-open time. Tess re-runs at sign-off. Sponsor's soak is the third check.

---

## 8. Per-ticket gating (M2 week-1 / week-2 readiness)

Which M2 tickets the budget gates, and how:

- **W1-T1 (v3→v4 migration, Devon):** add timing assertion to migration test (PB-04 / PB-05 desktop floor); run manual HTML5 probe before sign-off.
- **W1-T3 (Stash UI L, Devon):** PR description includes PB-03 (draw calls with stash open) + PB-02 (heap with full stash) measurements.
- **W1-T7 (Ember-bag pickup, Devon):** PR description includes PB-04 (save round-trip with bag write) + PB-02 measurements.
- **W1-T11 (M2 RC build pipeline, Devon):** **REQUIRED** — adds the artifact-size CI gate (PB-06) as part of the pipeline ticket. Cheapest CI win.
- **W2-T3 (S2 boss room L, Drew):** PR description includes PB-01 (FPS during boss climax) + PB-03 (draw calls peak) measurements.
- **W2-T5 (v4 stress fixtures, Tess+Devon):** explicitly references "<50ms desktop, <500ms HTML5" round-trip budget per the W2-T5 acceptance row — adopts PB-04/PB-05 as test gates.
- **W2-T9 (audio sourcing close-out, Uma+Devon):** PR description includes PB-05 (artifact size delta) + PB-07 (boot-time delta with new audio decode).
- **W2-T10 (Tess M2-week-2 acceptance plan):** **adds the §"Performance Budget" PB-01..PB-07 row table** to the acceptance plan doc — the manual-gate vehicle.

Open-question item: should the gate be advisory-only for week-1 (not blocking sign-off, just measured-and-reported), and blocking from week-2 onward? Devon-FOLLOWUP discussion in §10 below.

---

## 9. Open questions for orchestrator/Sponsor

1. **Is the 50 FPS floor right for HTML5?** Browsers vary — Chrome on a fast desktop hits 60 reliably, but Firefox on a low-end laptop or any tab-defocus state drops to 30 or pauses entirely. Should we adopt a 30 FPS floor for tab-defocus / low-end-detection, or hold at 50 with the caveat that low-end browsers fall outside our QA bar? **Default recommendation:** hold at 50 FPS floor for active-tab on Sponsor's typical machine; explicitly out-of-scope for tab-defocus / low-end. Sponsor's machine is the gold-standard.
2. **Does manual-first hold once M2 ships six new HTML5 surfaces, or do we need automated bench earlier?** Manual is ~10-15 min per RC; if M2 generates 1-2 RCs per week × 3 weeks = ~6 manual probes = ~90 min Tess time. Manageable. But if M3 grows the surface count, automated becomes mandatory. **Default recommendation:** manual through M2; T-EXP-2-FOLLOWUP (automated bench) lands in M2 week-3 or M3 week-1 onset. Sponsor confirms when ready.
3. **Peak-heap measurement: in-engine `MEMORY_STATIC` vs. browser JS heap?** Both are imperfect. `MEMORY_STATIC` is the Godot-internal allocator (doesn't capture wasm heap fragmentation). Browser JS heap captures the full picture but is harder to read in CI. **Default recommendation:** track both — `MEMORY_STATIC` as the easy in-engine signal (fires on regression), browser DevTools as the spot-check during Sponsor soak. Devon's call on which is the canonical CI number when bench harness lands.
4. **Build-artifact 10 MB target — is that the right ceiling, or should we tighten?** itch-hosted games commonly run 5-20 MB; we're conservative at 10. Tightening to 8 MB protects boot-time more aggressively but constrains audio sourcing decisions (forces more placeholder loops vs. hand-composed). **Default recommendation:** hold at 10 MB for M2; revisit at M3 onset when audio is a more known quantity.
5. **Should boot-to-playable be 3 s on localhost or 3 s on Sponsor's actual itch-deploy?** Localhost is gigabit; itch-deploy adds CDN latency (~200-500 ms) for the initial wasm/asset download. Sponsor's first-soak is the relevant signal. **Default recommendation:** target 3 s on localhost (developer-loop signal); communicate ~3.5-4 s as the Sponsor-itch-deploy expectation in soak prep docs.

None of these block dispatch of this budget. All are revisable post-Sponsor-feedback or post-first-bench-data.

---

## 10. Hand-off

When this PR merges:

- **Tess:** add §"Performance Budget" PB-01..PB-07 row table to `m2-acceptance-plan-week-1.md` (in flight) + future `m2-acceptance-plan-week-2.md` per W2-T10. First probe-pass against M1 RC `4484196` to confirm §6 baseline estimates → file v1.1 of this doc with measured numbers.
- **Devon:** add the artifact-size CI gate (PB-06 — 5-minute step) to next CI-touching PR or as part of W1-T11 M2 RC build pipeline ticket. Schedule **T-EXP-2-FOLLOWUP — perf bench harness** as P1 deferred to M2 week-3 / M3 onset. Add `DebugFlags.save_timing()` flag for in-game save round-trip observability when next save-touching PR fires.
- **Drew:** when authoring W2-T3 boss + W2-T2 sprites, manually probe PB-01 + PB-03 in PR description. Use shared particle pool / atlas patterns to keep draw calls bounded.
- **Uma:** in W2-T9 audio sourcing close-out, prefer placeholder loops if hand-composed cycle cost would push artifact past 10 MB. Document the OGG q5/q7 ceiling decisions in `audio-direction.md` v1.2 if any are revised.
- **Priya:** monitor for budget trips at M2 week-1 close + week-2 close retros. Author v1.1 of this doc when first measured numbers land. If multiple budgets trip simultaneously, escalate to scope-trim conversation per `m2-week-2-backlog.md` capacity check trim-to-10 / trim-to-8 path.
- **Orchestrator:** route the Tess baseline-confirmation probe as the first follow-up dispatch after this merges. T-EXP-2-FOLLOWUP (Devon bench harness) sits in the P1 envelope until M2 week-3.

---

## 11. Caveat — this is a v1 budget, not a contract

Revisions land if:

- **Tess's baseline-confirmation probe** surfaces M1 actual numbers materially different from §6 estimates (e.g., heap is 80 MB not 50 MB → tighten the budget or accept a revised target).
- **Sponsor's M1 sign-off soak** flags a perf issue this budget didn't anticipate (e.g., audio-decode hitch on stratum entry — adds PB-08 audio-decode latency).
- **M2 week-1 lived experience** surfaces an unexpected regression (e.g., stash UI ships at 250 draw calls — either tighten implementation or relax PB-03 peak to 300).
- **Bench harness data** (T-EXP-2-FOLLOWUP) replaces estimates with actuals; numbers may revise both up and down.

Revisions land as v1.1 of this doc, with the changed sections diff-highlighted and a one-line DECISIONS.md append referencing the change.

**This v1 is the path of least resistance from "no budget" → "M2 has a regression gate."** It is not the only path.
