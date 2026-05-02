# Test Environment Matrix — M1

Owner: Tess (QA). Defines what we test M1 on, what's nice-to-have, what's deferred to M2+.

Per Priya's distribution call (`team/DECISIONS.md` 2026-05-01 — itch.io HTML5 first, native desktop later, Steam at M3), HTML5 is the **primary** target because that's the channel the Sponsor will play through. Native desktop is **secondary** because it's free off the same Godot export pipeline and a useful safety net if HTML5 hits a browser-specific issue mid-playtest.

## M1 — must pass before Sponsor playtest

| Tier         | Platform           | Browser / runtime              | OS                          | Why                                                                |
|--------------|--------------------|--------------------------------|-----------------------------|--------------------------------------------------------------------|
| **Primary**  | HTML5 (itch.io)    | Chrome (latest stable)         | Windows 11                   | Sponsor's most likely environment; majority browser share.         |
| **Primary**  | HTML5 (itch.io)    | Firefox (latest stable)        | Windows 11                   | Diverges from Chrome on web audio + canvas perf; cheap to cover.   |
| **Primary**  | Windows native exe | Godot 4.3 export               | Windows 11                   | Sponsor fallback if HTML5 misbehaves on the day. Same SHA as HTML5.|

If any **Primary** row fails its M1 acceptance suite, M1 is not signed off.

## M1 — nice-to-have (test if time permits, log results)

| Tier            | Platform           | Browser / runtime              | OS                          | Why                                                                |
|-----------------|--------------------|--------------------------------|-----------------------------|--------------------------------------------------------------------|
| Nice-to-have    | HTML5 (itch.io)    | Edge (latest stable)           | Windows 11                   | Chromium-based; usually free if Chrome passes, but worth confirming.|
| Nice-to-have    | HTML5 (itch.io)    | Safari (latest stable)         | macOS 14+                    | WebKit's web audio + canvas behavior diverges most. Catches surprises.|
| Nice-to-have    | HTML5 (itch.io)    | Chrome (latest stable)         | macOS 14+                    | Confirms macOS-host browser parity.                                 |
| Nice-to-have    | macOS native       | Godot 4.3 export               | macOS 14+ (Apple Silicon)    | Free off the same export; useful for any team member on a Mac.     |
| Nice-to-have    | Linux native       | Godot 4.3 export               | Ubuntu 22.04 LTS             | Free off the same export. CI runner already runs Linux.            |

## M1 — deferred (won't test for M1 sign-off)

| Platform           | Why deferred                                                                                       |
|--------------------|----------------------------------------------------------------------------------------------------|
| Mobile browsers    | Out of scope per `game-concept.md` ("desktop+web only"). M1 target is keyboard+mouse.              |
| Touch input        | Same.                                                                                              |
| Controller         | Per `mvp-scope.md` M1 stubs: keyboard + mouse only. Drew validates controller during M1 polish if time, but no M1 gate.|
| Steam / Steam Deck | Per Priya: Steam playtest at M3.                                                                   |
| Old browsers (IE, pre-Chromium Edge, browsers more than 2 majors behind) | Godot HTML5 export targets modern browsers; we don't need to widen this for M1.|
| 4K / ultrawide displays | Render scale tested at 1080p + 1440p in M1. 4K is a future polish issue, not an AC.            |
| Throttled networks slower than Fast 3G | Sponsor's connection assumed reasonable. Below Fast 3G is M2+ if at all.       |
| Localized OS / non-English keyboards | Localization is M2+ per `tech-stack.md`. M1 is English-only.                          |

## Sponsor's likely test environment

Best inference (we have not asked the Sponsor — orchestrator hands-off rule):

- **Likely platform:** Windows 11 + Chrome on a desktop / laptop. This is the modal global config for casual web playtest.
- **Likely flow:** clicks the itch.io URL Devon emails → "Play in browser" → plays.
- **Therefore:** the M1 build's **single most important pass** is `M1-AC1-T01` (Chrome + Windows 11 HTML5) plus `M1-AC2-T01` (cold-launch ≤60s on the same). Tess prioritizes those.
- **Fallback if HTML5 fails on the day:** Sponsor downloads the Windows native zip from the same itch.io page. Therefore `M1-AC1-T03` must also be green before sign-off — the native build must be one click + one extract + one double-click away.
- **What we don't know:** Sponsor's actual machine specs, network speed, default browser, screen resolution. Mitigation: budget for the build to work on a 5-year-old laptop on Fast 3G — that's the conservative envelope.

## Test slot allocation per build

For an M1 candidate build, Tess runs:

1. **Primary tier** in full (`M1-AC1` through `M1-AC7`, all rows). ~3 hours per build, single tester.
2. **Nice-to-have tier** as a regression sweep only (`REG-BOOT` + a 5-min freeplay per row). ~30 min per row, time permitting.
3. **Deferred tier**: skip entirely.
4. **Soak session** per `TESTING_BAR.md`: at least one 30-min uninterrupted play on the Primary platform per release candidate. Documented in `team/tess-qa/soak-<YYYY-MM-DD>.md`.

Sponsor playtest builds get **two** Tess passes — the formal acceptance run + an exploratory 30-min soak — minimum 24h apart so fatigue doesn't mask issues. Build is not Sponsor-ready until at least one soak comes back zero-blocker, zero-major.

## When this matrix updates

- Adding a primary platform: requires PL sign-off in `team/DECISIONS.md`.
- Adding a nice-to-have: Tess can do this unilaterally; note in `team/log/tess-run-NNN.md`.
- Promoting nice-to-have → primary: only on Sponsor request OR after a real bug found there that wasn't caught on a primary row.
- M2 will absorb controller + Steam Deck + macOS native into primary. Updated then.
