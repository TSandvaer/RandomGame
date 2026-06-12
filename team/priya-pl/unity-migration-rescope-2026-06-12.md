# Unity Migration Re-Scope Proposal — 2026-06-12

**Author:** Priya (PL). **Status:** PROPOSAL — strategy for Sponsor review. No ClickUp
tickets created, no PRs closed, no Godot code touched. The Sponsor reads §0 first.

**Trigger:** `team/DECISIONS.md` 2026-06-12 — "ENGINE DECISION: migrate to Unity
(Sponsor-directed)". Embergrave migrates Godot 4.6 → Unity 6 (URP) as the production engine.
The 2026-06-11 development hold resolves as **retire-Godot** (not pause). All five style gates
passed on BUILD iter7 (Sponsor verbatims, tickets `86ca7zkyr` / `86ca7zhyk`): character
"appealing (if it can be a bit more detailed/polished)"; "i love zone D + quality"; "zone c
approved".

---

## §0 — PO-facing digest (read this first)

We just made the biggest call of the project: **Unity is the production engine, Godot is
retired.** The eval spike did its job — it turned your gut ("I have serious doubts about
Godot") into evidence (no Unity blockers; the character + Zone C/D look you approved). This
doc proposes how to re-anchor everything on Unity without losing the spike's momentum.

**Five recommendations, each with a one-line "why":**

1. **Graduate the spike into the production repo — do NOT start fresh.** The spike
   (`EmbergraveUnitySlice`) already has a clean Unity `.gitignore`, a tidy Assets layout, 10
   commits, working PoE-move + orbit-camera + Zone-C/D look + the CC0 castaway you approved.
   Starting fresh throws all of that away to re-type it. Rename it `Embergrave` (or `Embergrave-Unity`),
   give it a fresh GitHub repo, keep building. *Why: the spike IS the vertical slice — re-anchoring
   on it costs days, rebuilding costs weeks.*

2. **Archive the Godot repo, don't delete it.** Flip `TSandvaer/RandomGame` to archived
   (read-only) on GitHub. It keeps M1/M2 history, the combat/save/quest/dialogue systems, and
   every DECISIONS entry as a reference. *Why: one-way archive is reversible; delete is not, and
   the design learnings are worth keeping.*

3. **Close the five held Godot tickets as superseded — salvage learnings, not code.** H1–H4 +
   the Playwright fix are all Godot-engine-specific (TileSet `.tres`, `.tscn` scenes,
   `BuildingFade.gd`, Godot-4.6 HTML5 CI). None of that code runs in Unity. Three docs already
   landed on main and survive; the rest closes. *Why: "harvest Godot iso work into Unity" is a
   trap — it's a rewrite, not a port; honest disposition is close-as-superseded.*

4. **Close PR #422 and re-write the roadmap, don't rework it in place.** The journey-arc roadmap
   was authored for a Godot top-down ARPG (cloister → biomes → dungeons). The game is now a
   Unity 3D survival game (wake up → survive → chop / fire / food / shelter). The genre changed,
   not just the engine — a rework would leave too much load-bearing old framing. *Why: the §2
   "what exists vs new" mapping is now wrong on every line; a clean rewrite is faster and
   honester than a patch.*

5. **Next milestone = "M-U1: Survival Vertical Slice on Unity"** — graduate the spike, then build
   the first real survival loop (craft axe → chop tree → campfire → basic needs) in the
   Zone-D look with the castaway, on a desktop build. Draft ticket list in §4 (~12 tickets).
   *Why: you have a playable spike already; the slice converts it from throwaway-proof into the
   real game's first floor.*

**What I need from you (the open questions, §6):** survival-loop depth for the first slice
(thin / medium); whether to keep PixelLab on payroll for UI/portraits now or pause it; the
character-polish ask ("a bit more detailed/polished") — slice-now or defer; and the repo name.
All have a recommended default; none block me from drafting the M-U1 backlog once you pick.

**Honest scale note:** this is a re-foundation, not a feature. The spike makes it cheaper than
it sounds — but M1/M2's Godot combat/loot/save/quest/dialogue systems do NOT come across; they
are reference designs to re-implement in C# when the survival loop needs them. We are closer to
"strong prototype" than "halfway to ship." I'd rather say that now than victory-lap the spike.

---

## §1 — Production-project bootstrap

### Recommendation: GRADUATE the spike (not fresh project)

**The spike is already production-shaped.** Verified 2026-06-12 from disk
(`c:/Trunk/PRIVATE/EmbergraveUnitySlice`):

- Proper Unity `.gitignore` ignoring `Library/`, `Build/`, `Logs/`, `Captures/`, `*.log`,
  `UserSettings/`, IDE cruft, `test-results.xml` — i.e. the throwaway artifacts (40+ build/
  bootstrap logs, captures, the 97MB build) are already excluded from version control.
- Clean `Assets/` layout: `Scripts/` (Runtime + Editor + Tests), `Art/`, `Scenes/`, `Prefabs/`,
  `Resources/`, `Settings/`, `Shaders/`, `NavMesh/`, `Tests/`.
- 10 commits of real history; HEAD `f8c7d22` = "Iteration 7: player → clothed CC0 low-poly
  castaway character (86ca7zkyr)".
- Working systems Sponsor has approved: PoE click-to-move (NavMesh), orbit camera (35–70° clamp),
  Zone C low-poly + Zone D quality pass (the approved environment look target), CC0 Quaternius
  castaway character, blob-shadow grounding, feet-pivot billboard infra (now legacy but the
  conventions transfer), HUD build-stamp ritual.
- Note: the spike is currently checked out on branch `devon/86ca7zkyr-lowpoly-3d-player` with
  `master` behind at `43a1b88` — a graduation step reconciles this (fast-forward master, or make
  the iter7 branch the new main).

**Why graduate, not restart:**

| | Graduate spike | Fresh project |
|---|---|---|
| PoE-move + orbit camera + NavMesh | ✅ keep (working, ~100 lines) | ❌ re-type |
| Zone C/D approved look | ✅ keep (Sponsor-approved) | ❌ re-build, re-soak |
| CC0 castaway character (approved) | ✅ keep | ❌ re-import, re-retarget |
| Build-stamp / capture / test infra | ✅ keep | ❌ re-author |
| Throwaway artifact pollution | already `.gitignore`d | n/a |
| Cost | hours (add remote, push, rename) | weeks (re-derive everything) |

The only argument for fresh is "the spike has throwaway baggage" — but the `.gitignore` already
solves that. The captures/logs/build are untracked; the tracked surface is clean.

### Graduation steps (for the bootstrap ticket, U1)

1. **Rename** the project root `EmbergraveUnitySlice` → `Embergrave` (or `Embergrave-Unity` if
   the Godot folder name collides locally). Update `ProductName` / `CompanyName` in
   `ProjectSettings`.
2. **Reconcile git:** fast-forward `master` to the iter7 work (or make iter7's tree the new
   `main`), so the production repo's default branch carries the approved state. Squash the
   iter1–iter8 spike-iteration commits into a clean "M-U1 baseline" commit if Sponsor prefers a
   clean history (recommended — the iter-by-iter messages are spike-debugging noise).
3. **Strip pure-throwaway tracked files** if any slipped past `.gitignore` (FINDINGS.txt stays —
   it's the engine-decision evidence; move it under `docs/`).
4. **Create a NEW private GitHub repo** `Embergrave` under `TSandvaer`, add as `origin`, push.
   Keep it private (CC0 assets are fine; private matches the current Godot repo's privacy and
   keeps options open for any future paid asset packs — same rationale as the 2026-06-10 Cainos
   private-repo call).
5. **CI shape — defer to a follow-up ticket, but seed the decision:** GitHub Actions with a
   Unity license (Personal, machine-bound — the spike already runs `-batchmode` headless EditMode
   8/8 + PlayMode 10/11). A `game-ci/unity-test-runner` + `unity-builder` workflow is the standard
   path; license activation is the one gated step (needs a Unity serial/ULF — Sponsor-side
   interactive, same class as the spike's license sign-in). Do NOT block M-U1 on CI; land it as
   an early M-U1 ticket once the repo exists.

### Repo strategy summary

| Repo | Action | Rationale |
|---|---|---|
| `TSandvaer/RandomGame` (Godot) | **Archive** (read-only), do not delete | M1/M2 history + system designs + DECISIONS reference; one-way-safe |
| `EmbergraveUnitySlice` (local) | **Graduate** → new repo `Embergrave` | Already production-shaped; the vertical-slice foundation |
| New `TSandvaer/Embergrave` (Unity) | **Create** (private) | Production engine going forward |

---

## §2 — Disposition of held Godot work

**Standing context:** H1–H4 + the Playwright fix were held under the 2026-06-11 development hold.
The hold has now resolved as retire-Godot. Honest disposition follows.

### The honest verdict: close all five as superseded. Salvage is near-zero.

The harvest tickets exist to *commit Godot iso-sprint artifacts into the Godot repo*. With Godot
retired, committing engine-specific artifacts into an archived repo has no production value.
The learnings split into "engine-specific (dies with Godot)" and "engine-agnostic (already
survives or transfers as design reference)".

| Ticket | What it harvests | Engine-specific? | Disposition |
|---|---|---|---|
| **H1** `86ca7ugce` | iso ground pipeline: numpy/PIL tile scripts, Godot TileSet `.tres`, `_check_iso_*.gd` headless probes | YES — `.tres` + GDScript probes are Godot-only | **Close superseded.** The numpy/PIL *generation approach* is engine-agnostic knowledge but the iso/top-down 2D-tile target is itself superseded by 3D low-poly — the tiles aren't wanted either. |
| **H2** `86ca7ugfr` | iso building kit: 11 `.tscn` scenes, `BuildingFade.gd`, PixelLab raw building PNGs | MOSTLY — `.tscn` + GDScript are Godot-only | **Close superseded.** *Exception worth noting:* the raw PixelLab building PNGs (`assets/props/s1_cloister/_pixellab_raw/*`) are engine-agnostic art, BUT they're isometric 2D — wrong for the 3D low-poly world. No salvage into M-U1; archive on disk only. |
| **H3** `86ca7ugkj` | iso docs: `godot-headless-tooling.md`, `art-direction.md`, `pixellab-pipeline.md` delta, CLAUDE.md index | MIXED | **Already largely landed** — `art-direction.md`, `godot-headless-tooling.md`, `pixellab-pipeline.md` are committed on main (verified on disk this session). `art-direction.md` (the inspiration-board north-star) is **engine-agnostic and CARRIES** — it informs the Unity world palette. `godot-headless-tooling.md` becomes Godot-archive reference. **Close the ticket** (work effectively done); fold the carry note into the Unity doc set. |
| **H4** `86ca7ugrq` | refresh `team/RESUME.md` to "M3 iso state" | N/A (process doc) | **Close superseded.** "M3 iso state" no longer exists as a target. RESUME.md should be refreshed to the *Unity migration* state instead — that's a new task under the bootstrap, not this ticket. |
| **Playwright fix** `86ca7xgud` | restore Godot-4.6 HTML5 Playwright E2E green | YES — Godot HTML5 export + Playwright specs against it | **Close superseded.** HTML5 is no longer the primary surface (desktop-first per 2026-06-11). The entire Playwright-against-Godot-HTML5 harness retires with Godot. Unity gets its own test/build-capture story (§5). |

### What actually salvages (be honest — it's thin)

1. **`art-direction.md` inspiration-board north-star** — the "small player / big alive world,
   warm cohesive palette, purposeful decoration, human-scale landmarks" doctrine is
   engine-agnostic. It already shaped the Zone-D look Sponsor loved. **Carries into the Unity
   world-art direction** (with the caveat that the 2026-06-10 "dark sinister iso building" memory
   is retired — the survival POC is warm/lush per the board + Zone D).
2. **PixelLab pipeline knowledge** — survives but *narrows*. PixelLab is ruled out for the 3D
   low-poly character (it can only make pixel art — proven across v3/v4 probes). It carries for
   **UI / icons / HUD / dialogue portraits / 2D map surfaces** if those are wanted. Decision in §6 Q3.
3. **The R&D-lane harvest discipline itself** — the *process* (every R&D burst closes with a
   harvest PR + peer review + productionization tickets) is engine-agnostic and stays in force for
   Unity R&D. This very re-scope is an application of it.
4. **Procedural-generation-as-knowledge** (numpy/PIL, seed-cascade thinking from the Godot
   FloorAssembler) — *conceptually* transferable if Unity ever wants procedural terrain/placement,
   but the M1/M2/M3 Godot implementations do not port. Reference-only.

**Everything else — combat system, loot/affix system, save/version-gate architecture, quest
router, dialogue system, camera director, the whole `.claude/docs` Godot-architecture set — is
design-reference, not code-salvage.** When the Unity survival game grows a combat or save or
quest need, those docs describe *what worked and why* and we re-implement in C#. That's the
honest scope: M1/M2/M3 Godot systems are a design library, not a codebase that comes with us.

---

## §3 — PR #422 (journey-arc roadmap) disposition

**Standing Sponsor decision (2026-06-12 walkthrough, recorded STATE.md):** "defer PR #422 until
the engine verdict lands, then Priya re-reads/re-scopes it under the survival direction." The
verdict has landed. This is that re-scope.

### Recommendation: CLOSE-AND-REWRITE, not rework-in-place.

PR #422's `journey-arc-roadmap.md` (read this session) is a strong document — but it was authored
for a fundamentally different game:

- **Its genre:** Godot top-down 2D action-RPG; "cloister START → journey OUT through biomes
  (wilderness / village / dungeon / caves / castle / ruins) → monk grows."
- **The current genre:** Unity 3D low-poly survival; "wake up on a beach → survive → chop wood /
  make fire / collect food / build shelter."

The mismatch is structural, not cosmetic:

- **§2 "What exists vs new"** maps every roadmap pillar to a *shipped Godot system* (camera /
  assembler / combat / dialogue / quests / save-seed / audio). Post-migration, **none of those
  systems exist in the production engine** — every line of that mapping is now wrong.
- **§3 "Structural enablers"** is built on the Godot procgen-assembler + continuous-scroll path.
  Unity's spatial model is NavMesh + 3D world + orbit camera — a different foundation.
- **§1 "the arc"** (cloister → biomes) is a dungeon-crawl exploration arc. Survival is a
  needs/crafting/base-building arc. Different core loop, different progression.

What *survives* from #422 is the **macro-vision spirit** (big alive world, journey/wonder, grow
from humble-start into more) — and that's already captured in memory (`world-feel-big-and-endless`,
`game-world-journey-arc`) and the art-direction board. The document's *structure* is too
Godot-ARPG-shaped to rework cleanly.

### Proposed action (orchestrator executes; this proposal does NOT touch PR #422)

1. **Close PR #422** with a comment crediting the macro-vision spirit as carried-forward and
   pointing to the new survival roadmap (authored as part of M-U1 planning).
2. **Author a NEW `survival-roadmap.md`** as the first M-U1 planning artifact — structured around
   the survival loop (needs → crafting → shelter → biomes-as-survival-regions → progression),
   mapping pillars against the *Unity spike* baseline, not Godot systems.
3. **Carry the one DECISION-draft line** PR #422's §6 holds into the next batch only if it's still
   meaningful under survival framing; otherwise drop it. (I'll evaluate at batch time.)

I am the PL on both; I'll own the rewrite. The new roadmap is **not** in scope for this proposal —
it's the first ticket of M-U1 planning (§4, ticket U2).

---

## §4 — Next milestone: M-U1 "Survival Vertical Slice on Unity"

**Shape:** convert the throwaway spike into the real game's first floor. The slice proves the
*survival loop* in the *approved Zone-D look* with the *approved castaway*, on a *desktop build*,
with a *real test + build-capture gate*. It is the smallest build that makes the survival genre
*felt*, not just demoed.

**Scope seed (from the dispatch brief + spike state):**
- iter8 spike state (PoE-move, orbit camera, Zone C/D, CC0 castaway, grass-clump polish in flight)
- Zone D look as the environment target
- the castaway as the protagonist (with the "more detailed/polished" follow-up, §6 Q2)
- the craft-axe → chop → campfire loop as the survival-loop seed

**This is a DRAFT ticket LIST inside this doc — no ClickUp tickets are created. Sponsor reviews
the strategy first, then I file the backlog.** Sizes S/M/L; owners proposed.

### M-U1 draft backlog

| # | Title (conventional-commit) | Owner | Size | Notes |
|---|---|---|---|---|
| **U1** | `chore(repo): graduate Unity spike → production Embergrave repo` | Devon | M | §1 steps 1–4. Rename, reconcile git, new private GitHub repo, push. Gate: repo exists, spike state pushed, builds clean. |
| **U2** | `docs(pl): author survival-roadmap.md (replaces journey-arc #422)` | Priya | M | §3. Survival-loop-structured roadmap; close PR #422. Sponsor-shapes the arc. |
| **U3** | `ci(unity): GitHub Actions — EditMode + PlayMode + Windows build` | Devon | M | game-ci test-runner + builder. Unity license activation = Sponsor-interactive step (fail-fast like the spike). Gate: green CI on a trivial PR. |
| **U4** | `feat(survival): needs model — hunger/energy (or chosen needs) with HUD` | Drew | M | The survival "why" — a need that decays + drives the loop. Depth per §6 Q1. Paired PlayMode tests. |
| **U5** | `feat(survival): resource loop — gather wood/food → consume to satisfy needs` | Drew | M | Wires craft→chop→wood and food→need together into a real loop (vs the spike's disconnected demo). |
| **U6** | `feat(survival): campfire as a need-satisfier + shelter seed` | Drew | M | Campfire warms / cooks (per needs model); seeds the "build shelter" pillar (Don't-Starve prefab-placement per 2026-06-11). |
| **U7** | `feat(char): castaway polish pass — "more detailed/polished"` | Devon+Uma | M | §6 Q2. Sponsor's iter7 note. Warmer costume/material, possibly a higher-detail CC0 variant. Visual gate = Sponsor soak. |
| **U8** | `feat(world): Zone-D look as the production environment (not a vignette)` | Devon | L | Promote the approved Zone-D quality pass (lighting/fog/post) from a side-by-side vignette into the actual play space; grass-clump fix folded in. |
| **U9** | `feat(ui): minimal survival HUD — needs + inventory readout` | Uma+Devon | M | Diegetic-light HUD for needs + collected resources. Uma specs, Devon wires. |
| **U10** | `test(unity): PlayMode survival-loop coverage + EditMode scene-integrity` | Tess+Devon | M | §5. Translate the testing-bar to Unity: EditMode (scene/asset integrity) + PlayMode (loop behavior) + shipped-build capture gate. |
| **U11** | `chore(unity): build-capture + soak-serve ritual for desktop builds` | Devon | S | Carry the spike's HUD-build-stamp + auto-capture convention into a repeatable Sponsor-soak handoff (desktop .exe + captures). |
| **U12** | `docs(pl): refresh RESUME.md + team docs to Unity-migration state` | Priya | S | Replaces H4. New engine, new repo, new milestone — clean the process docs. |

**Critical path:** U1 (repo) → U3 (CI) gate everything. U4→U5→U6 are the survival-loop spine.
U8 (world) + U7 (char) are the look. U10/U11 are the gates. U2/U12 are the docs spine.

**Out of M-U1 (deferred — name them so they're visible, don't build them):** combat (re-implement
from Godot combat-architecture.md *if/when* the survival game wants enemies); save/load
(re-implement from save-architecture.md when the loop needs persistence); multiple biomes beyond
the first survival region; quest/dialogue systems; multiplayer; itch.io/Steam distribution. These
are post-slice — the slice proves the *loop*, not the *content spine*.

---

## §5 — Process carry-overs (engine-agnostic conventions that survive)

The migration changes the engine, not the team's discipline. What survives, what translates,
what retires:

### Survives unchanged (engine-agnostic)

- **Worktree-isolated dispatch** — one worktree per role, single-tenant. Unchanged.
- **PR-flow + protected main + `gh pr merge --admin --squash --delete-branch`** — git workflow is
  engine-agnostic. Unchanged (new repo, same protocol).
- **ClickUp status as hard gate** — every dispatch/PR-open/merge pairs a status move. Unchanged.
- **Self-Test Report gate** — author posts a Self-Test Report before QA on UX-visible PRs.
  Unchanged (the *content* shifts from HTML5-soak to desktop-build-capture).
- **Testing bar — paired tests + green CI + edge probes + Tess sign-off before complete; Sponsor
  will not debug.** Unchanged as a *principle*; the *surfaces* translate (below).
- **R&D-lane harvest discipline** — every R&D burst closes with a harvest PR + peer review +
  productionization tickets. Unchanged (this re-scope is an instance of it).
- **Outcome-over-motion** — ≥2 rejections on the same surface = wrong approach, escalate the
  approach not the tweak. The spike's style-iteration (iter6 mangled → iter6b mannequin → iter7
  CC0 castaway) honored this. Unchanged.
- **Decision-log centralization (Priya-only, weekly batch)** — unchanged. (A migration-summary
  `Decision draft:` line is in my final report for the next batch.)
- **Tightened final-report contract; agent-liveness-from-probe; never-fabricate** — all
  engine-agnostic. Unchanged.

### Translates (same principle, new mechanism)

| Godot mechanism | Unity equivalent | Source for the Unity shape |
|---|---|---|
| GUT unit/integration tests | **EditMode tests** (scene/asset integrity, edit-time logic) | spike: EditMode 8/8–11/11 across iters |
| Playwright HTML5 E2E | **PlayMode tests** (runtime loop behavior) + **shipped-build capture** | spike: PlayMode 10–11/11; `-batchmode` headless |
| HTML5 visual-verification gate (Tween/Polygon2D/Area2D) | **Shipped-build capture gate** — verify in the *built .exe*, not editor (the iter6 "legs-up mangle" passed editor captures but the shipped runtime mangled; iter3 magenta-campfire was build-only) | spike FINDINGS: build-only failures are real; capture the shipped player |
| BuildInfo SHA footer (HTML5) | **HUD build-stamp** ("BUILD iterN \| UTC \| sha") in the desktop build | spike: build-identity ambiguity hit twice → HUD stamp ritual |
| Sponsor HTML5 soak via artifact link | **Sponsor desktop-build soak** (.exe + captures) | spike: Windows build double-click soak |

**Key translated lesson (from the spike, now a Unity gate):** *editor-green ≠ build-correct.*
Three spike incidents (iter3 magenta campfire = stripped URP shader; iter6 legs-up = Awake-no-
serialize divergence; NavMesh-not-shipping = asset-not-baked-into-build) were ALL build-only —
invisible in editor/EditMode, visible only in the shipped .exe. The Unity testing bar MUST include
a **shipped-build capture gate** (Tess/Devon launch the actual .exe and capture), not just
EditMode/PlayMode green. This is the Unity-shaped sibling of the HTML5-visual-verification-gate.

### Retires (Godot-specific, dies with the engine)

- Godot HTML5 / WebGL2 export quirks (HDR clamp, Polygon2D, service-worker cache) — N/A in Unity.
- The Playwright-against-HTML5 harness — retires (Unity gets PlayMode + build-capture).
- `gl_compatibility` renderer discipline, `.tres`/`.tscn` conventions, GDScript style rules —
  replaced by URP + C# + Unity prefab/scene conventions (to be authored as Unity docs grow).
- Godot-architecture `.claude/docs` set (combat/camera/procgen/save/quest/dialogue) — becomes
  **design reference** (what worked + why), not live architecture docs. A new Unity doc set grows
  as M-U1 lands systems.

---

## §6 — Open strategic questions for the Sponsor

Each has a recommended default so I can draft the M-U1 backlog without blocking. These are the
items I genuinely need a steer on before filing tickets.

- **Q1 — Survival-loop depth for the first slice.** Thin (one need, e.g. energy/hunger, that the
  craft→chop→campfire loop satisfies) vs medium (2–3 interacting needs + basic shelter). *Recommend
  **thin** — prove the loop is felt with one need before layering; matches "smallest build that
  makes survival felt".*
- **Q2 — Character polish ("a bit more detailed/polished").** Slice-now (U7 in M-U1) vs defer to a
  later pass. *Recommend **slice-now, lightweight** — a warmer costume/material pass + possibly a
  higher-detail CC0 variant; full custom castaway model stays deferred (it's a later step per the
  2026-06-12 character decision).*
- **Q3 — PixelLab disposition.** Keep active for UI/icons/portraits/2D-map now, or pause the
  subscription until those surfaces are scoped? *Recommend **keep but idle** — it's ruled out for
  the 3D character but the $24/mo Tier-2 is cheap insurance for UI/portrait art the survival HUD
  will want; revisit at M-U1 close. (Sponsor-decision — it's a recurring spend, surfaced not
  auto-decided.)*
- **Q4 — Repo name.** `Embergrave` vs `Embergrave-Unity` vs keep a new working title (the survival
  genre may warrant a new name — the old name surfaced in Godot build artifacts). *Recommend
  **`Embergrave`** for continuity unless you want a fresh survival-themed name — open-ended, your call.*
- **Q5 — Godot repo archive timing.** Archive `RandomGame` now (clean break) or keep it writable a
  few weeks as a reference safety net? *Recommend **archive after U1 lands** — once the Unity repo
  is the live one and the design docs are confirmed readable, flip Godot to read-only.*

---

## §7 — DECISION drafts (for the next Monday batch — NOT appended here)

These capture decisions this proposal *recommends*; they belong in the next centralized
DECISIONS.md batch PR, not this doc. Listed here so the orchestrator can route them into my batch
queue.

- `Decision draft (2026-06-12): Unity production project = GRADUATED spike (EmbergraveUnitySlice →
  new private GitHub repo Embergrave), NOT a fresh project. Rationale: spike is already
  production-shaped (clean .gitignore, tidy Assets, 10 commits, Sponsor-approved systems). Godot
  repo archived (read-only), not deleted. — pending Sponsor confirm.`
- `Decision draft (2026-06-12): Held Godot tickets H1 86ca7ugce / H2 86ca7ugfr / H3 86ca7ugkj /
  H4 86ca7ugrq + Playwright fix 86ca7xgud all CLOSE-AS-SUPERSEDED. Salvage limited to:
  art-direction.md (carries, engine-agnostic), PixelLab knowledge (narrows to UI/2D), R&D-harvest
  process (unchanged). All Godot engine-specific code = design-reference, not code-salvage. —
  pending Sponsor confirm.`
- `Decision draft (2026-06-12): PR #422 journey-arc roadmap CLOSE-AND-REWRITE as survival-roadmap.md
  (M-U1 ticket U2). Genre changed (top-down ARPG → 3D survival); §2 system-mapping now wrong on
  every line; macro-vision spirit survives in memory + art-direction board. — pending Sponsor
  confirm.`
- `Decision draft (2026-06-12): Next milestone = M-U1 "Survival Vertical Slice on Unity" — graduate
  spike + first real survival loop (need → craft → chop → campfire) in Zone-D look with castaway,
  desktop build, EditMode+PlayMode+shipped-build-capture gates. ~12-ticket backlog drafted; filed
  after Sponsor strategy review. — pending Sponsor confirm.`

---

## Cross-references

- `team/DECISIONS.md` — 2026-06-10 (iso pivot), 2026-06-11 (dev hold; Unity eval GO; survival
  reveal), 2026-06-12 (low-poly character; ENGINE DECISION migrate to Unity).
- `c:/Trunk/PRIVATE/EmbergraveUnitySlice/FINDINGS.txt` — the engine-eval evidence (iter1–3+ logged;
  no engine blockers; PixelLab-fit; the build-only-failure lessons).
- `team/erik-consult/low-poly-style-sourcing-2026-06-12.md` — CC0 low-poly sourcing (Kenney,
  Quaternius), smooth-shading technique, pixel-billboard-on-low-poly cohesion evidence.
- PR #422 — `priya/journey-arc-roadmap`, journey-arc-roadmap.md (Godot-ARPG roadmap, to close).
- Held tickets: H1 `86ca7ugce`, H2 `86ca7ugfr`, H3 `86ca7ugkj`, H4 `86ca7ugrq`, Playwright
  `86ca7xgud`; engine-eval `86ca7y46c` (complete); character `86ca7zkyr` (in progress); Zone C/D
  `86ca7zhyk` (complete).
- Memory: `sponsor-direction-shift-poe-camera-unity`, `player-char-castaway-vision`,
  `world-feel-big-and-endless`, `game-world-journey-arc`, `bandaid-retirement-scope-blowup`
  (the "salvage is thin, be honest" discipline applies here too).
