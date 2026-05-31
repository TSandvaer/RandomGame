## Self-Test Report — ArchiveSentinel attack visuals render in WebGL2

**PR #380** · branch `drew/sentinel-invisible-attack-fix` @ `c7023db` · base `devon/archive-sentinel-v3-spriteswap` (stacked).

### CI status — stacked-base caveat (honest disclosure)

`ci.yml` (GUT) + `playwright-e2e.yml` trigger **only on PRs against `main`** (`pull_request: branches: [main]`). This PR targets the stacked base `devon/archive-sentinel-v3-spriteswap`, so the GUT/Playwright CI workflows do NOT auto-run here. They will run once the stack rebases onto main (after the base PR merges). To compensate, the verification below is empirical against the actual release-build artifact + parse-checks.

- **GDScript parse-check** (local Godot 4.3.stable): `ArchiveSentinelCastBolt.gd` parses clean (`--check-only`, exit 0). Local full GUT cannot run — repo ships empty `addons/gut/` vendor (only README) per the documented `local-gut-discipline-tooling-precondition`; GUT is CI-only.
- **Release build (export pipeline)**: green on `c7023db` — [run 26652682046](https://github.com/TSandvaer/RandomGame/actions/runs/26652682046). Artifact `embergrave-html5-c7023db`. A clean export proves the new GDScript compiles in the headless export path.

### HTML5 author-self-soak (visual-verification gate)

Ran the Playwright harness against the **downloaded artifacts** via the COOP/COEP `artifact-server.ts` fixture (per `html5-export.md` § "CLI-agent HTML5 self-soak — COOP/COEP headers required"). Soak spec archived at `team/drew-dev/sentinel-attack-soak.spec.ts.txt`.

**1. CAST BOLT — production build `c7023db`, `?start_room=9`** (this IS the Sponsor re-soak artifact):

Boss auto-casts on wake (player ~328 px, inside AGGRO_RADIUS 640). Renderer-observable trace captured (the bolt's own `_ready` — on-screen truth, not spawn-intent):
```
[combat-trace] ArchiveSentinelCastBolt._ready | VISIBLE bolt pos=(512,384) visible=true alpha=1.00 z=1 color_rect=true
```
2 casts fired, 2 visible bolts rendered (1:1 — no invisible damage). Player HP dropped 86→72 across the casts (damage progression confirmed). Screenshot of the cast-fire moment (ember at the construct's book): `team/drew-dev/sentinel-cast-fire-c7023db.png`.

**2. PHASE-2 SLAM TELEGRAPH — diag build `85dd96a`** (`diag/sentinel-attack-soak`, Sentinel hp_base nerfed 700→8 so phase 2 is reachable; production cannot reach phase 2 passively — fistless player, 700 HP):

Drove the player to the plinth + swung to cross into phase 2, then provoked the slam at short range. Trace:
```
ArchiveSentinel.take_damage | amount=1 hp=4->3 phase=2
ArchiveSentinel._spawn_slam_indicator | radius=96 color=(1.00,0.42,0.17,0.50) telegraph_duration=0.55 fade=0.080 strobe_hz=5.0 strobe=[0.25..1.00]
```
**Screenshot `team/drew-dev/sentinel-slam-telegraph-85dd96a.png` shows the ember-orange `draw_arc` AOE danger circle rendered around the construct in WebGL2, nameplate at PHASE 2.** No invisible-slam regression — the `draw_arc` primitive renders exactly as the S1 boss `SlamTelegraphIndicator` (PR #291, Sponsor-verified).

### Visual-verification escape clause — per-surface

- **Cast bolt (ColorRect, modulate tween)** — renderer-safe primitive (PR #137 class). Author DID produce HTML5 evidence (trace + screenshot above). Gate satisfied.
- **Slam telegraph (`_draw` + `draw_arc`)** — renderer-safe primitive. Author DID produce HTML5 evidence (screenshot above). Gate satisfied.
- Per `test-conventions.md` § "Playwright headless ≠ real-browser perception": headless captures prove "rendered at the right position/config/visibility," NOT "a human perceives it in real-time motion." **Sponsor interactive soak remains the human-perceptibility gate of record** — probe targets: (a) cast — does the ember bolt read as a visible projectile traveling book→impact during phase 1? (b) slam — does the AOE circle read clearly during the 0.55 s windup? Re-soak artifact: production `embergrave-html5-c7023db` at `?start_room=9`.

### Cross-lane integration check (PR #216 gate)

- `[combat-trace]` contract preserved — existing lines unchanged; cast-bolt + the new `ArchiveSentinelCastBolt._ready` line are additive via the same `DebugFlags.combat_trace` shim.
- Player iframes / Damage formula constants — untouched. Bolt is cosmetic; damage hitbox path byte-identical.
- RoomGate signal chain — untouched.
- Adjacent specs probed — only `stratum2-boss-room.spec.ts` references ArchiveSentinel attack traces; extended in-place. No `level_chunks/*.tres` `mob_spawns` mutated (roster-swap gate N/A).

### Regression guard (Done clause)

Invisible-attack bug class pinned at GUT (node visible/alpha/z/ColorRect at fire time + phase-2 slam indicator visible) AND Playwright (renderer-observable visibility trace + damage⟹visible-node implication for both cast and slam). A refactor that drops the bolt or the trace fails CI before merge.

### Reviewer

Tess (QA). Ticket `86c9y7ygj` stays `ready for qa test` (multi-stage).
