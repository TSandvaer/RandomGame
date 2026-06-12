# Unity Migration Re-Scope Proposal — 2026-06-12 (rev. 2, post-Sponsor-walkthrough)

**Author:** Priya (PL). **Status:** REWORKED — the Sponsor's 7 walkthrough decisions
(2026-06-12, ticket `86ca85ttd` comment thread) are now folded in; this doc records the
confirmed plan, not open recommendations. Drew's PR #437 review (REQUEST_CHANGES, B1 + 2 nits)
is resolved in this revision. No ClickUp tickets created, no PRs closed by this doc, no Godot
code touched. The Sponsor reads §0 first.

**Trigger:** Sponsor-authored ticket `86ca85ttd` (2026-06-12) — "ENGINE DECISION: migrate to
Unity (Sponsor-directed)" — plus the 7-decision walkthrough recorded in that ticket's comment
thread (2026-06-12 popups). The underlying engine decision is durably sourced from `86ca85ttd`
and the prior eval ticket `86ca7y46c`; the corresponding `team/DECISIONS.md` entries are
**pending the next Monday batch** (drafted in §7) and ride orch-docs PR #438 for the coordination
record — they are not yet on `main`. Embergrave migrates Godot 4.6 → Unity 6 (URP) as the
production engine. The 2026-06-11 development hold resolves as **retire-Godot** (not pause). All
five style gates passed on BUILD iter7 (Sponsor verbatims, tickets `86ca7zkyr` / `86ca7zhyk`):
character "appealing (if it can be a bit more detailed/polished)"; "i love zone D + quality";
"zone c approved".

> **What changed in rev. 2 (Sponsor walkthrough 2026-06-12, `86ca85ttd`):**
> 1. **FRESH Unity production project** — graduation REJECTED; the spike stays an eval artifact.
> 2. **Repo/working title = NEW survival-themed name** (Sponsor supplies; placeholder `<new-name>`);
>    "Embergrave" retires with the Godot repo.
> 3. **Milestones SPLIT** — M-U1 = bootstrap + ports + desktop build + test gates; M-U2 = thin
>    survival loop (one need → craft axe → chop → campfire).
> 4. **Held 5 Godot tickets close-as-superseded AFTER orch-docs PR #438 merges** (sequencing guard
>    from Drew's B1).
> 5. **PR #422 already CLOSED** by the orchestrator (Sponsor-decided); survival-roadmap rewrite is
>    an M-U1 ticket.
> 6. **PixelLab = keep-but-idle** confirmed.

---

## §0 — PO-facing digest (read this first)

We made the biggest call of the project: **Unity is the production engine, Godot is retired.**
The eval spike did its job — it turned your gut ("I have serious doubts about Godot") into
evidence (no Unity blockers; the character + Zone C/D look you approved). You then made 7
walkthrough decisions on 2026-06-12 (`86ca85ttd`) that set the shape of what comes next. This
revision records that confirmed plan — it is no longer a set of open recommendations.

**The confirmed plan, in six lines (each with your decision + the one-line why):**

1. **A FRESH Unity production project — not a graduated spike.** *(Your decision 1/6; my
   graduate-recommendation overridden.)* The spike (`EmbergraveUnitySlice`) stays an **eval
   artifact** — proof the engine works, not the foundation. The production project is built clean,
   **deliberately porting** the systems you approved (PoE click-to-move, orbit camera, Zone-C/D
   low-poly look, castaway character). *Why you chose it: a clean foundation beats inheriting
   spike-debugging scaffolding; the ports are deliberate, not a tangle of iteration commits.*

2. **The repo + working title get a NEW survival-themed name** (you supply it; this doc uses the
   placeholder `<new-name>`). *(Your decision 2/6.)* "Embergrave" retires with the Godot repo — it
   was a top-down-ARPG-era name. *Why: the genre changed; the name should match the survival game,
   from day one of the fresh repo.*

3. **Archive the Godot repo, don't delete it.** Flip `TSandvaer/RandomGame` to archived
   (read-only) once the fresh Unity project carries the approved slice (timing folds into M-U1
   sequencing per decision 1/6). It keeps M1/M2 history, the combat/save/quest/dialogue systems,
   and every DECISIONS entry as reference. *Why: one-way archive is reversible; delete is not, and
   the design learnings are worth keeping.*

4. **Close the five held Godot tickets as superseded — AFTER PR #438 merges.** *(Your decision
   5/6.)* H1–H4 + the Playwright fix are Godot-engine-specific (TileSet `.tres`, `.tscn` scenes,
   `BuildingFade.gd`, Godot-4.6 HTML5 CI) — none runs in Unity. **Sequencing guard (from Drew's
   review):** orch-docs PR #438 lands FIRST — it commits the still-uncommitted `.claude/docs`
   including `art-direction.md` (H3's real engine-agnostic content) — THEN the five closes execute.
   *Why: closing H3 while `art-direction.md` is untracked would let a clone/cleanup sweep the
   north-star doc; commit first, close second.*

5. **PR #422 is CLOSED** (already executed by the orchestrator, your decision 6-a). The journey-arc
   roadmap was authored for a Godot top-down ARPG; the game is now a survival game. Its replacement
   — a survival-roadmap — is an M-U1 ticket. *Why: §2 "what exists vs new" mapped every pillar to a
   shipped Godot system; post-migration that mapping is wrong on every line; a clean rewrite is
   faster and honester than a patch.*

6. **Milestones SPLIT into M-U1 and M-U2.** *(Your decision 3/6 — single-slice rejected.)*
   **M-U1** = fresh-project bootstrap + deliberate ports (PoE-move, orbit camera, Zone-D look,
   castaway) + desktop build + EditMode/PlayMode/shipped-build-capture test gates. **M-U2** = the
   first **thin** survival loop (decision 4/6): ONE need → craft axe → chop → campfire; extra
   needs/shelter layer later, after the loop proves fun. Draft backlogs in §4. *Why: bootstrap-and-
   port is its own body of de-risking work; bundling the survival loop into the same milestone hid
   the foundation effort behind a feature.*

**PixelLab = keep but idle** (your decision 6-b): the $24/mo Tier-2 stays subscribed but no
generation work dispatches until a UI/portrait/2D-map surface is scoped; revisit at M-U1 close.

**Honest scale note:** this is a re-foundation, not a feature, and the FRESH-project call makes
that explicit — we are NOT carrying the spike across; we re-build it deliberately. M1/M2's Godot
combat/loot/save/quest/dialogue systems do NOT come across either; they are reference designs to
re-implement in C# when the loop needs them. We are closer to **"strong prototype"** than
"halfway to ship." I'd rather say that now than victory-lap the spike. The fresh-project decision
costs more up front than graduating would have — that's the price of a clean foundation, and it's
your call to pay it.

---

## §1 — Production-project bootstrap

### Confirmed: a FRESH Unity production project, ports deliberate (Sponsor decision 1/6, `86ca85ttd`)

My original recommendation here was to GRADUATE the spike; the Sponsor **overrode** it on
2026-06-12 in favor of a fresh project. This section is reworked to that decision. The spike's
value is now as a **proven reference**, not a foundation to inherit — every approved system is
re-built deliberately into the clean project, using the spike as the working specification.

**The spike's role going forward: eval artifact + porting reference.** Verified 2026-06-12 from
disk (`c:/Trunk/PRIVATE/EmbergraveUnitySlice`, HEAD `f8c7d22`):

- 10 commits of real history; HEAD `f8c7d22` = "Iteration 7: player → clothed CC0 low-poly
  castaway character (86ca7zkyr)"; checked out on `devon/86ca7zkyr-lowpoly-3d-player`, `master`
  behind at `43a1b88`.
- Proven systems the Sponsor approved — **these are the deliberate-port targets:** PoE
  click-to-move (NavMesh), orbit camera (35–70° clamp), Zone C low-poly + Zone D quality pass (the
  approved environment look target), CC0 Quaternius castaway character, blob-shadow grounding, HUD
  build-stamp ritual. (Feet-pivot billboard infra is spike-legacy — NOT a port target; the 3D
  character supersedes it.)
- `FINDINGS.txt` — the engine-eval evidence (no blockers, PixelLab-fit, build-only-failure
  lessons). Carries into the new repo's `docs/` as the migration rationale record.

**Why fresh, not graduate (the Sponsor's reasoning, recorded):** a clean foundation avoids
inheriting the spike's iteration-debugging scaffolding (8 style iterations, mannequin/mangle
dead-ends, billboard infra the 3D char retired). The deliberate ports are a known, bounded body of
work — the spike proves each system works and gives the exact shape to re-build. The cost is
re-typing ~working systems; the Sponsor judged the clean-foundation benefit worth that cost. My
graduate-recommendation's cost argument (re-typing wastes days) is acknowledged and overridden —
this is a strategic foundation call, the Sponsor's to make.

### Bootstrap + port steps (for the M-U1 bootstrap + port tickets)

1. **Create the fresh Unity project** under the `<new-name>` working title (Sponsor decision 2/6 —
   Sponsor supplies the survival-themed name; bootstrap placeholder-starts as `<new-name>` pending
   it). Unity 6 / URP, matching the spike's URP setup. Set `ProductName` / `CompanyName` to
   `<new-name>`.
2. **Author the clean `Assets/` layout** from scratch: `Scripts/` (Runtime + Editor + Tests),
   `Art/`, `Scenes/`, `Prefabs/`, `Resources/`, `Settings/`, `Shaders/`, `NavMesh/`, `Tests/`.
   Author a proper Unity `.gitignore` (ignore `Library/`, `Build/`, `Logs/`, `Captures/`, `*.log`,
   `UserSettings/`, IDE cruft, `test-results.xml`) BEFORE the first commit — never let throwaway
   artifacts enter history.
3. **Create a NEW private GitHub repo** `<new-name>` under `TSandvaer`, add as `origin`, push the
   bootstrap commit. Keep it private (CC0 assets are fine; private matches the Godot repo's privacy
   and keeps options open for future paid asset packs — same rationale as the 2026-06-10 Cainos
   private-repo call).
4. **Deliberately port each approved system** (separate tickets per §4): PoE click-to-move + orbit
   camera (U-2), Zone-D look (U-4), castaway character (U-5). Each port reads the spike as the
   working spec, re-implements clean in the new project, and gets paired tests + a shipped-build
   capture (NOT just an editor screenshot — see §5's build-only-failure lesson).
5. **CI shape — early M-U1 ticket (U-3):** GitHub Actions with a Unity license (Personal,
   machine-bound — the spike already ran `-batchmode` headless EditMode 8/8 + PlayMode 10/11). A
   `game-ci/unity-test-runner` + `unity-builder` workflow is the standard path; license activation
   is the one gated step (needs a Unity serial/ULF — Sponsor-side interactive, same class as the
   spike's license sign-in). Land it early in M-U1 once the repo exists; it gates every later port.

### Repo strategy summary

| Repo | Action | Rationale |
|---|---|---|
| `TSandvaer/RandomGame` (Godot, "Embergrave") | **Archive** (read-only) once the fresh project carries the approved slice; do not delete | M1/M2 history + system designs + DECISIONS reference; one-way-safe. "Embergrave" name retires here (decision 2/6). |
| `EmbergraveUnitySlice` (local spike) | **Keep as eval artifact + porting reference**; do NOT graduate | Proves the engine + every approved system; the working spec the fresh project ports from (decision 1/6) |
| New `TSandvaer/<new-name>` (Unity) | **Create fresh** (private) | Production engine + survival-themed name from day one (decisions 1/6 + 2/6) |

---

## §2 — Disposition of held Godot work

**Standing context:** H1–H4 + the Playwright fix were held under the 2026-06-11 development hold.
The hold has now resolved as retire-Godot. **Sponsor decision 5/6 (`86ca85ttd`, 2026-06-12):
close all five as superseded** — with the sequencing guard below. Honest disposition follows.

### Confirmed verdict: close all five as superseded — AFTER orch-docs PR #438 merges. Salvage is near-zero code, one real doc.

The harvest tickets exist to *commit Godot iso-sprint artifacts into the Godot repo*. With Godot
retired, committing engine-specific artifacts into an archived repo has no production value. The
learnings split into "engine-specific (dies with Godot)" and "engine-agnostic (already survives or
transfers as design reference)".

> **Sequencing guard (B1 fix, from Drew's PR #437 review + Sponsor decision 5/6):** H3's real
> engine-agnostic content — `art-direction.md` (the north-star), plus `godot-headless-tooling.md`
> and the `pixellab-pipeline.md` delta — was **uncommitted orch-root state** at the time of this
> doc's first draft, NOT committed on main. Orch-docs **PR #438**
> (https://github.com/TSandvaer/RandomGame/pull/438, OPEN at rev. 2) now commits them
> (`art-direction.md` +183 ADDED, `godot-headless-tooling.md` +219 ADDED, `pixellab-pipeline.md`
> +804 MODIFIED — per `gh pr view 438 --json files`). **The five closes execute only AFTER #438
> merges**, so the north-star doc is durably on main before H3 closes. Closing H3 while
> `art-direction.md` is untracked would let a clone/cleanup sweep it.

| Ticket | What it harvests | Engine-specific? | Disposition |
|---|---|---|---|
| **H1** `86ca7ugce` | iso ground pipeline: numpy/PIL tile scripts, Godot TileSet `.tres`, `_check_iso_*.gd` headless probes | YES — `.tres` + GDScript probes are Godot-only | **Close superseded** (after #438). The numpy/PIL *generation approach* is engine-agnostic knowledge but the iso/top-down 2D-tile target is itself superseded by 3D low-poly — the tiles aren't wanted either. |
| **H2** `86ca7ugfr` | iso building kit: 11 `.tscn` scenes, `BuildingFade.gd`, PixelLab raw building PNGs | MOSTLY — `.tscn` + GDScript are Godot-only | **Close superseded** (after #438). *Exception worth noting:* the raw PixelLab building PNGs (`assets/props/s1_cloister/_pixellab_raw/*`) are engine-agnostic art, BUT they're isometric 2D — wrong for the 3D low-poly world. No salvage into the Unity milestones; archive on disk only. |
| **H3** `86ca7ugkj` | iso docs: `godot-headless-tooling.md`, `art-direction.md`, `pixellab-pipeline.md` delta, CLAUDE.md index | MIXED | **Close as SUPERSEDED-BY-#438** (after #438 merges). The harvest H3 was scoped to commit was **un-done** at draft time — `art-direction.md` + `godot-headless-tooling.md` were UNTRACKED and `pixellab-pipeline.md` had an uncommitted delta (per H3 ticket text + `gh pr view 438 --json files`). PR #438 now performs that commit. Once #438 lands, H3's work is **done by #438**, so H3 closes as superseded-by-#438 — NOT as "already on main" (the rev.1 claim, which was the B1 defect). `art-direction.md` (the inspiration-board north-star) is **engine-agnostic and CARRIES** into the Unity world palette; `godot-headless-tooling.md` becomes Godot-archive reference. |
| **H4** `86ca7ugrq` | refresh `team/RESUME.md` to "M3 iso state" | N/A (process doc) | **Close superseded** (after #438). "M3 iso state" no longer exists as a target. RESUME.md should be refreshed to the *Unity migration* state instead — that's a new task under the M-U1 docs spine (§4), not this ticket. |
| **Playwright fix** `86ca7xgud` | restore Godot-4.6 HTML5 Playwright E2E green | YES — Godot HTML5 export + Playwright specs against it | **Close superseded** (after #438). HTML5 is no longer the primary surface (desktop-first per 2026-06-11). The entire Playwright-against-Godot-HTML5 harness retires with Godot. Unity gets its own test/build-capture story (§5). |

### What actually salvages (be honest — it's thin)

1. **`art-direction.md` inspiration-board north-star** — the "small player / big alive world,
   warm cohesive palette, purposeful decoration, human-scale landmarks" doctrine is
   engine-agnostic. It already shaped the Zone-D look Sponsor loved. **Carries into the Unity
   world-art direction** (with the caveat that the 2026-06-10 "dark sinister iso building" memory
   is retired — the survival POC is warm/lush per the board + Zone D). *Status note:* this doc is
   committed to main by **PR #438** (not previously on main — see the §2 sequencing guard); the
   carry-forward depends on #438 landing before H3 closes.
2. **PixelLab pipeline knowledge** — survives but *narrows*. PixelLab is ruled out for the 3D
   low-poly character (it can only make pixel art — proven across v3/v4 probes). It carries for
   **UI / icons / HUD / dialogue portraits / 2D map surfaces** if those are wanted. **Confirmed
   keep-but-idle** (Sponsor decision 6-b/`86ca85ttd`): the $24/mo Tier-2 stays subscribed, no
   generation dispatched until such a surface is scoped; revisit at M-U1 close.
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

## §3 — PR #422 (journey-arc roadmap) disposition — DONE: CLOSED

**Sponsor decision 6-a (`86ca85ttd`, 2026-06-12 walkthrough popup):** PR #422 =
**CLOSE-AND-REWRITE as survival roadmap** (rejected: rework-in-place). The orchestrator has
**already CLOSED PR #422** (Sponsor-decided), with a comment linking the engine decision and
pointing at the rewrite's home in the new backlog. The journey-arc macro spirit (start small →
journey into a big alive world) carries via memory + the art-direction board into the
survival-roadmap doc. This section is now a **record of the executed decision + the rationale that
backed it**, not an open recommendation. *(The earlier "recorded STATE.md" cite in rev. 1 was
inaccurate — STATE.md had no record of the defer; the durable source is the Sponsor's walkthrough
on `86ca85ttd`.)*

### Why CLOSE-AND-REWRITE was the right call (the rationale, for the record):

PR #422's `journey-arc-roadmap.md` was a strong document — but it was authored for a fundamentally
different game:

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

### Status + follow-through

1. **PR #422 — CLOSED** (orchestrator-executed, Sponsor-decided 2026-06-12) with a comment
   crediting the macro-vision spirit as carried-forward and pointing at the rewrite's home in the
   new backlog. ✅ done.
2. **Author a NEW `survival-roadmap.md`** — now an **M-U1 ticket** (§4, ticket U-7, docs spine).
   Structured around the survival loop (needs → crafting → shelter → biomes-as-survival-regions →
   progression), mapping pillars against the *ported Unity baseline*, not Godot systems. NOT a
   graduated-spike baseline — the ports are deliberate (decision 1/6).
3. **Carry the one DECISION-draft line** PR #422's §6 held into the next batch only if it's still
   meaningful under survival framing; otherwise drop it. (I'll evaluate at batch time.)

I am the PL on the rewrite. The new roadmap is **not** in scope for this proposal — it's an M-U1
docs ticket (§4, U-7).

---

## §4 — Two-milestone backlog: M-U1 (foundation) → M-U2 (thin survival loop)

**Sponsor decision 3/6 (`86ca85ttd`): the milestones SPLIT** (single vertical slice rejected). The
foundation work (fresh project, deliberate ports, desktop build, test gates) is its own milestone;
the survival loop is the next one. This keeps the foundation effort visible instead of hiding it
behind a feature, and lets the loop start from a clean, tested base.

**This is a DRAFT ticket LIST inside this doc — no ClickUp tickets are created.** Sizes S/M/L;
owners proposed. I file the backlog once the Sponsor supplies the `<new-name>` (decision 2/6) and
PR #438 merges (the H-ticket closes precede M-U1's first dispatch).

---

### M-U1 — "Fresh Unity foundation + deliberate ports" (Sponsor decision 1/6 + 3/6)

**Shape:** stand up the clean `<new-name>` Unity project, deliberately port the four
Sponsor-approved systems from the spike, ship a desktop build, and translate the testing bar to
Unity (EditMode + PlayMode + shipped-build-capture). **No survival loop yet** — M-U1 proves the
*foundation* (engine, ports, build, gates), M-U2 proves the *loop*. The ports re-build the spike's
proven systems clean; the spike is the working spec, not the codebase.

| # | Title (conventional-commit) | Owner | Size | Notes |
|---|---|---|---|---|
| **U1-1** | `chore(repo): bootstrap fresh Unity <new-name> production project` | Devon | M | §1 steps 1–3. Fresh Unity 6/URP project under `<new-name>`, clean `Assets/` layout + `.gitignore` BEFORE first commit, new private GitHub repo, push bootstrap. Gate: repo exists, opens clean in Unity, trivial scene builds. Blocked on Sponsor supplying `<new-name>` (decision 2/6) — placeholder-start allowed, rename-gate before push. |
| **U1-2** | `feat(input): port PoE click-to-move + orbit camera (NavMesh)` | Devon | M | §1 step 4. Re-implement clean from the spike spec: NavMesh click-to-move + orbit camera (35–70° clamp). Paired PlayMode tests + shipped-build capture. |
| **U1-3** | `ci(unity): GitHub Actions — EditMode + PlayMode + Windows build` | Devon | M | game-ci test-runner + builder. Unity license activation = Sponsor-interactive step (fail-fast like the spike). Gate: green CI on a trivial PR. Land early — gates every later port. |
| **U1-4** | `feat(world): port Zone-D look as the production environment` | Devon | L | Re-build the approved Zone-D quality pass (lighting/fog/post) clean as the actual play space, not a side-by-side vignette; grass-clump fix folded in. Visual gate = Sponsor desktop soak. |
| **U1-5** | `feat(char): port CC0 castaway character + grounding` | Devon | M | Re-import the approved CC0 Quaternius castaway clean: NavMesh-driven locomotion, blob-shadow grounding. (Polish pass "more detailed/polished" is M-U2 U2-6 — see note.) Visual gate = Sponsor soak. |
| **U1-6** | `test(unity): testing-bar translation — EditMode + PlayMode + build-capture gate` | Tess+Devon | M | §5. Translate the bar to Unity: EditMode (scene/asset integrity) + PlayMode (runtime behavior) + the **shipped-build capture gate** (editor-green ≠ build-correct — the spike's hard-won lesson). |
| **U1-7** | `chore(unity): build-capture + soak-serve ritual for desktop builds` | Devon | S | Carry the spike's HUD-build-stamp + auto-capture convention into a repeatable Sponsor-soak handoff (desktop .exe + captures). |
| **U1-8** | `docs(pl): author survival-roadmap.md (replaces closed PR #422)` | Priya | M | §3. Survival-loop-structured roadmap mapping pillars against the *ported Unity baseline*. Sponsor-shapes the arc. Feeds the M-U2 ticket shapes. |
| **U1-9** | `docs(pl): refresh RESUME.md + team docs to Unity-migration state` | Priya | S | Replaces H4. New engine, new repo, new milestone — clean the process docs + STATE.md/RESUME.md to the `<new-name>` Unity reality. |

**M-U1 critical path:** U1-1 (repo) → U1-3 (CI) gate everything. U1-2 / U1-4 / U1-5 are the three
ports (parallelizable once CI is green). U1-6 / U1-7 are the gates. U1-8 / U1-9 are the docs spine.
**M-U1 exit = a tested, shipped desktop build of `<new-name>` with the four approved systems
working — and zero survival mechanics.** That's the deliberate split.

---

### M-U2 — "Thin survival loop" (Sponsor decisions 3/6 + 4/6)

**Shape:** the first survival loop, **THIN** (decision 4/6): **ONE need** (e.g. energy/hunger)
satisfied by **craft axe → chop tree → campfire**. Additional needs + a shelter layer are
explicitly deferred to later milestones, after the loop proves fun. M-U2 builds on M-U1's tested
foundation — the loop's first line of code lands on green CI + a working ported world/character.

| # | Title (conventional-commit) | Owner | Size | Notes |
|---|---|---|---|---|
| **U2-1** | `feat(survival): single need model — one decaying need + HUD readout` | Drew | M | The survival "why" — ONE need (energy/hunger) that decays and drives the loop. Thin per decision 4/6: no second need, no shelter yet. Paired PlayMode tests. |
| **U2-2** | `feat(survival): craft axe — first crafting interaction` | Drew | M | The entry to the loop: gather/craft an axe (the chop tool). Inventory readout seed. |
| **U2-3** | `feat(survival): chop tree → wood resource` | Drew | M | Axe + tree → wood. The "do work in the world" beat; wires the axe to a world-interaction. |
| **U2-4** | `feat(survival): campfire — build + satisfy the need` | Drew | M | Wood → campfire; campfire satisfies the one need (warm/cook per the need chosen). **Closes the loop:** need decays → craft axe → chop → campfire → need satisfied. Don't-Starve prefab-placement seed (2026-06-11) for the campfire. |
| **U2-5** | `feat(ui): minimal survival HUD — the one need + inventory` | Uma+Devon | M | Diegetic-light HUD for the single need + collected resources (axe/wood). Uma specs, Devon wires. |
| **U2-6** | `feat(char): castaway polish pass — "more detailed/polished"` | Devon+Uma | M | Sponsor's iter7 note ("appealing if a bit more detailed/polished"). Warmer costume/material, possibly a higher-detail CC0 variant. Visual gate = Sponsor soak. Sequenced into M-U2 (after the ported base char lands in M-U1 U1-5). |
| **U2-7** | `test(unity): PlayMode survival-loop coverage` | Tess+Devon | M | Loop-behavior coverage on top of M-U1's bar: need-decays, craft, chop, campfire-satisfies — the full loop green in PlayMode + a shipped-build capture of the loop. |

**M-U2 critical path:** U2-1 (need) → U2-2 (axe) → U2-3 (chop) → U2-4 (campfire) is the loop
spine — sequential, each beat depends on the prior. U2-5 (HUD) + U2-6 (char polish) are parallel
polish. U2-7 is the gate. **M-U2 exit = the thin loop is *felt* — one need, satisfied by the
craft→chop→fire cycle, in a desktop build the Sponsor soaks.** If the loop is fun, later
milestones layer needs + shelter; if not, we iterate the loop before layering (decision 4/6).

---

**Out of BOTH milestones (deferred — named so they're visible, NOT built):** combat (re-implement
from Godot combat-architecture.md *if/when* the survival game wants enemies); save/load
(re-implement from save-architecture.md when the loop needs persistence); multiple needs + shelter
(layer after the thin loop proves fun — decision 4/6); multiple biomes beyond the first survival
region; quest/dialogue systems; multiplayer; itch.io/Steam distribution. M-U1 proves the
*foundation*, M-U2 proves the *loop* — neither builds the *content spine*.

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

## §6 — Strategic questions — RESOLVED (Sponsor walkthrough 2026-06-12, `86ca85ttd`)

All five open questions from rev. 1 were answered in the Sponsor's 7-decision walkthrough. Record:

- **Q1 — Survival-loop depth → THIN** (decision 4/6). ONE need (e.g. energy/hunger) satisfied by
  craft→chop→campfire; extra needs + shelter layer later, after the loop proves fun. Shapes M-U2
  (§4). *(My recommendation — thin — accepted.)*
- **Q2 — Character polish → SLICE-IT, sequenced into M-U2** (U2-6). Warmer costume/material pass +
  possibly a higher-detail CC0 variant; full custom castaway model stays deferred. The ported base
  character lands first in M-U1 (U1-5); the polish pass follows in M-U2. *(My slice-now-lightweight
  recommendation accepted; placed in M-U2 per the milestone split.)*
- **Q3 — PixelLab → KEEP BUT IDLE** (decision 6-b). $24/mo Tier-2 stays subscribed; no generation
  until a UI/portrait/2D-map surface is scoped; revisit at M-U1 close. *(My recommendation
  accepted; pause/cancel rejected.)*
- **Q4 — Repo name → NEW survival-themed name** (decision 2/6). Sponsor supplies it; this doc uses
  `<new-name>`. "Embergrave" retires with the Godot repo. *(My `Embergrave`-for-continuity
  recommendation OVERRIDDEN — the Sponsor wants a name matching the survival genre.)*
- **Q5 — Godot archive timing → AFTER the fresh project carries the approved slice** (folded into
  M-U1 sequencing per decision 1/6). *(My "archive after the first repo ticket lands" recommendation
  accepted, re-anchored to the fresh-project sequencing rather than spike-graduation.)*

**Open dependency (not a question — an input I'm waiting on):** the `<new-name>` value. Bootstrap
(U1-1) can placeholder-start but must carry the real name before the first push. No other item
blocks filing the backlog.

---

## §7 — DECISION drafts (for the next Monday batch — NOT appended here)

These capture the decisions the Sponsor **confirmed** in the 2026-06-12 walkthrough; they belong in
the next centralized DECISIONS.md batch PR, not this doc. All are **CONFIRMED 2026-06-12** (cite:
`86ca85ttd` comment thread, 7-decision walkthrough) — no longer pending. Listed here so the
orchestrator routes them into my batch queue.

- `Decision (2026-06-12, confirmed — 86ca85ttd decision 1/6 + 2/6): Unity production project = a
  FRESH project (graduate-spike REJECTED). The spike (EmbergraveUnitySlice) stays an eval artifact +
  porting reference; the production project is built clean, deliberately porting the Sponsor-approved
  systems (PoE click-move, orbit camera, Zone-C/D look, castaway). Repo + working title = NEW
  survival-themed name (Sponsor supplies; placeholder <new-name>); "Embergrave" retires with the
  Godot repo. Godot repo archived (read-only, not deleted) once the fresh project carries the
  approved slice.`
- `Decision (2026-06-12, confirmed — 86ca85ttd decision 5/6): Held Godot tickets H1 86ca7ugce / H2
  86ca7ugfr / H3 86ca7ugkj / H4 86ca7ugrq + Playwright fix 86ca7xgud all CLOSE-AS-SUPERSEDED —
  executed AFTER orch-docs PR #438 merges (sequencing guard: #438 commits the still-uncommitted
  .claude/docs incl. art-direction.md north-star = H3's real content, so H3 closes as
  superseded-by-#438 not "already on main"). Salvage limited to: art-direction.md (carries,
  engine-agnostic, lands via #438), PixelLab knowledge (narrows to UI/2D), R&D-harvest process
  (unchanged). All Godot engine-specific code = design-reference, not code-salvage.`
- `Decision (2026-06-12, confirmed — 86ca85ttd decision 6-a): PR #422 journey-arc roadmap
  CLOSE-AND-REWRITE — #422 CLOSED by orchestrator; the survival-roadmap rewrite is M-U1 ticket U1-8.
  Genre changed (top-down ARPG → 3D survival); §2 system-mapping was wrong on every line;
  macro-vision spirit survives in memory + art-direction board.`
- `Decision (2026-06-12, confirmed — 86ca85ttd decision 3/6 + 4/6): Milestones SPLIT (single
  vertical slice rejected). M-U1 = fresh-project bootstrap + deliberate ports (PoE-move, orbit
  camera, Zone-D look, castaway) + desktop build + EditMode/PlayMode/shipped-build-capture gates
  (9-ticket draft, §4). M-U2 = THIN survival loop — ONE need → craft axe → chop → campfire (7-ticket
  draft, §4); extra needs/shelter deferred until the loop proves fun. Backlog filed after Sponsor
  supplies <new-name> + PR #438 merges.`
- `Decision (2026-06-12, confirmed — 86ca85ttd decision 6-b): PixelLab Tier-2 ($24/mo) = KEEP BUT
  IDLE (pause/cancel rejected). No generation dispatched until a UI/portrait/2D-map surface is
  scoped; revisit at M-U1 close.`

---

## Cross-references

- **Durable decision sources:** ticket `86ca85ttd` (Sponsor-authored engine-decision ticket + the
  7-decision walkthrough comment thread, 2026-06-12 — the authoritative source for every confirmed
  decision in this doc); prior eval ticket `86ca7y46c` (Unity eval, complete). *Note: the
  corresponding `team/DECISIONS.md` 2026-06-08→12 entries (iso pivot / dev hold / Unity eval GO /
  survival reveal / low-poly character / ENGINE DECISION migrate to Unity) were uncommitted
  orch-root state at this doc's cite time — they ride **orch-docs PR #438** and are not yet on
  `main`; the durable cite is the ticket IDs above, not the not-yet-committed DECISIONS dates. They
  also enter the centralized DECISIONS.md via my next Monday batch (§7).*
- **Orch-docs PR #438** (https://github.com/TSandvaer/RandomGame/pull/438, OPEN) — commits the
  uncommitted coordination state (DECISIONS.md +47, STATE.md +146, `.claude/docs` incl.
  `art-direction.md` +183 ADDED + `godot-headless-tooling.md` +219 ADDED + `pixellab-pipeline.md`
  +804, erik-consult notes). Pre-req for the H1–H4 + `86ca7xgud` closes (§2 sequencing guard).
- `c:/Trunk/PRIVATE/EmbergraveUnitySlice/FINDINGS.txt` — the engine-eval evidence (no engine
  blockers; PixelLab-fit; the build-only-failure lessons). Carries into the new repo's `docs/`.
- `team/erik-consult/low-poly-style-sourcing-2026-06-12.md` — CC0 low-poly sourcing (Kenney,
  Quaternius), smooth-shading technique, pixel-billboard-on-low-poly cohesion evidence (rides #438).
- PR #422 — `priya/journey-arc-roadmap`, journey-arc-roadmap.md (Godot-ARPG roadmap) — **CLOSED**
  by orchestrator 2026-06-12 (Sponsor decision 6-a); rewrite is M-U1 ticket U1-8.
- Held tickets: H1 `86ca7ugce`, H2 `86ca7ugfr`, H3 `86ca7ugkj`, H4 `86ca7ugrq`, Playwright
  `86ca7xgud` (all close-as-superseded after #438, decision 5/6); engine-eval `86ca7y46c`
  (complete); character `86ca7zkyr` (in progress); Zone C/D `86ca7zhyk` (complete).
- Memory: `sponsor-direction-shift-poe-camera-unity`, `player-char-castaway-vision`,
  `world-feel-big-and-endless`, `game-world-journey-arc`, `bandaid-retirement-scope-blowup`
  (the "salvage is thin, be honest" discipline applies here too).
