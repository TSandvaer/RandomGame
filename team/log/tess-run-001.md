# Tess Run 001 — QA Spec Pass

[2026-05-01 start] Run begins. Tess unblocked, MVP scope locked at `team/priya-pl/mvp-scope.md`. Plan: paper-only deliverables this run (GUT scaffold not yet committed by Devon).

[2026-05-01] task w1#16 (M1 acceptance test plan): drafted `team/tess-qa/m1-test-plan.md` covering all 7 acceptance criteria from `mvp-scope.md`. 5 test cases per AC (35 total) + regression sweep (9 cases) + severity definitions + testability hooks Devon must expose. Outcome: complete (paper).

[2026-05-01] task QA-aux (bug template): drafted `team/tess-qa/bug-template.md`. Severity → ClickUp priority mapping, copy-paste body for ClickUp `bug(...)` tasks. Outcome: complete.

[2026-05-01] task w1#17 (automated smoke plan, paper): drafted `team/tess-qa/automated-smoke-plan.md`. 5 GUT test files planned (boot, autoloads, save round-trip, player movement, hit on grunt). Blocked-as-expected on Devon's scaffold + GUT plugin commit. Outcome: paper-complete; resume with actual `.gd` files once scaffold lands.

[2026-05-01] task QA-aux (test environment matrix): drafted `team/tess-qa/test-environments.md`. Primary = Chrome+Win11+HTML5, Firefox+Win11+HTML5, Windows native. Sponsor's likely env = Chrome on Win11. Native is the fallback path. Outcome: complete.

[2026-05-01 mid-run] Coordinator dispatched expanded directive — Sponsor's "no debugging" rule codified at `team/TESTING_BAR.md` (already committed by orchestrator). Role grows: active hammer, sole `ready for qa test → complete` gate, ≥3 edge-case probes per feature, scheduled bug bashes, soak sessions per release candidate. Updated all 4 docs to honor the new bar:
- `m1-test-plan.md`: added inventory targets table, severity table now binds to M1 ship/no-ship decisions, added Tess-only sign-off flow section, added 8-probe edge-case matrix (≥3 picks per feature), added soak-session policy.
- `bug-template.md`: severity table now binds to TESTING_BAR.md (blocker = no-ship, major = ship-impaired/fix-M2, minor = ship/fix-later); Sponsor sign-off gate spelled out.
- `automated-smoke-plan.md`: rewrote from 5-test smoke plan to a 40-test inventory hitting the 20–30/10–15 targets — Phase A (boot+save: 9u+2i), Phase B (player+combat+loot: 16u+5i), Phase C (fills: 5u+3i). Each test ID, file, and assertion specified. Tess writes these herself.
- `soak-template.md`: new file. Standardized 30-min soak session log: build/env/timeline/findings/verdict. Build is not Sponsor-ready until soak is zero-blocker, zero-major.
- `test-environments.md`: added soak-session line to test-slot allocation; release-candidate gate now requires both formal acceptance run + soak.

[2026-05-01 mid-run observation] Devon's scaffold + GUT canary CI + initial player scene have all landed during this run (per `git log` and `git status`). Phase A GUT tests are unblocked and writable starting next tick. Test path is `tests/` at repo root (per Devon's `Project layout` decision in `DECISIONS.md`).

[2026-05-01] task w1#16 (M1 acceptance test plan): drafted + expanded. 35 test cases across 7 ACs + regression sweep + 8-probe edge-case matrix + per-feature sign-off flow + soak policy + 5 testability hooks. Outcome: complete.

[2026-05-01] task QA-aux (bug template): drafted + bound severity to TESTING_BAR.md. Outcome: complete.

[2026-05-01] task w1#17 (automated test plan): expanded from smoke-only to full M1 inventory. 30 unit + 10 integration cases specified in detail. Outcome: paper-complete; Phase A ready to write next tick.

[2026-05-01] task QA-aux (test environment matrix): drafted + soak hook added. Primary = Chrome/Win11 HTML5, Firefox/Win11, Windows native. Outcome: complete.

[2026-05-01] task QA-aux (soak template): new file per TESTING_BAR.md. Outcome: complete.

[2026-05-01] decision logged: will append QA-testability-hooks decision to `team/DECISIONS.md` after main commit — Devon must expose 5 test hooks (build-SHA in main menu, debug fast-XP toggle, save-path README, stable mob spawn seed, HTML5 console error surfacing). These are what makes the M1 test plan actually executable.

[2026-05-01 end] Run complete. 5 deliverables committed. STATE.md updated to `idle (chunk done)`. Next run: write actual GUT Phase A tests against Devon's scaffolded autoloads (`test_boot.gd`, `test_autoloads.gd`, `test_save_roundtrip.gd`, integration `test_quit_relaunch_save.gd`).
