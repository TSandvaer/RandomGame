# Soak Session Template

Per `team/TESTING_BAR.md`: each release candidate gets at least one **30-minute uninterrupted soak**. Tess copies this template to `team/tess-qa/soak-<YYYY-MM-DD>.md` (one file per soak), fills it during/after the session, commits it.

A release candidate is **not ready** for Sponsor sign-off until a soak completes with zero `blocker` and zero `major` findings.

---

## Soak — YYYY-MM-DD

### Build

- **Git SHA:**
- **Build artifact:** (HTML5 zip filename / itch.io URL / native exe)
- **Build date:**
- **Source CI run:**

### Environment

- **Platform:** HTML5 / Windows native / macOS native / Linux native
- **Browser + version:** (HTML5 only)
- **OS + version:**
- **Display / resolution:**
- **Network:** (HTML5 only)

### Plan

- **Duration:** 30 min minimum, uninterrupted (no other tabs, no slack, no email).
- **Goal:** play the M1 build like a player. Cover: title → first kill → stratum 1 traversal → death (intentional, ~10 min in) → restart → boss attempt → quit-and-relaunch sanity.
- **What I'm watching for:** crashes, stutters, save corruption, progress loss, AC regressions, anything that doesn't feel right.

### Timeline (fill while playing — minute markers)

| Minute | What I did                                        | What I observed                                          |
|--------|---------------------------------------------------|----------------------------------------------------------|
| 0:00   | Cold-launch URL.                                  |                                                          |
| 0:01   | Click New Game.                                   |                                                          |
| ...    |                                                   |                                                          |
| 30:00  | Stop.                                              |                                                          |

### Findings

For each finding, file a `bug(...)` ClickUp task with severity per `bug-template.md`. List the IDs here.

| Severity   | Summary                                           | ClickUp ID  |
|------------|---------------------------------------------------|-------------|
|            |                                                   |             |

### Verdict

- [ ] Zero `blocker` findings.
- [ ] Zero `major` findings.
- [ ] All `minor` findings filed.
- [ ] Build is **soak-clean** for Sponsor sign-off.

If the third box is unchecked, the build is **not** ready for Sponsor. Tess pings PL + the owning dev with the bug list.

### Notes

Anything else: subjective feel, pace, what the build does well, what felt off but isn't a defect.
