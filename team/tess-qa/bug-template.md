# Bug Report Template — Embergrave

Use this template for every bug Tess (or anyone) files. The ClickUp task title goes in conventional-commit form: `bug(<scope>): <one-line summary>` — see `team/ROLES.md`. The fields below are the body of the ClickUp task description.

## How to use

1. Reproduce the bug **at least once** before filing. Flaky-only-once observations go in `team/log/tess-run-NNN.md` instead, not as a ClickUp bug.
2. Copy the template (everything from `### Summary` to the end of `### Notes`) into the ClickUp task description.
3. Fill every field. If a field genuinely doesn't apply, write `n/a` — don't delete it. This keeps Drew/Devon's intake fast: same shape every time.
4. Tag the ClickUp task `bug` plus the relevant theme tag (`combat`, `loot`, `save`, `ui`, `ci`, `engine`, ...).
5. Set priority honestly per the severity → priority mapping below.

## Severity → ClickUp priority mapping (per `team/TESTING_BAR.md`)

| Severity   | ClickUp priority | M1 ship decision         | When to file                                                              |
|------------|------------------|--------------------------|---------------------------------------------------------------------------|
| `blocker`  | `urgent`         | M1 cannot ship.          | AC fails, build unplayable, save corruption, hard crash, progress loss.   |
| `major`    | `high`           | M1 ships impaired; fix M2.| Real defect, AC passes via workaround, or single-platform issue.          |
| `minor`    | `normal`         | M1 ships; fix when convenient.| Cosmetic / copy / low-frequency edge case.                            |
| `polish`   | `low`            | Backlog only.             | Nice-to-have, not a defect against spec.                                  |

Rule of thumb: **if you can't reproduce it twice, don't file it as `blocker`.**

Per `TESTING_BAR.md`, the orchestrator gates Sponsor sign-off on **zero `blocker` AND zero `major`** open against the M1 build. Severity discipline is binding.

---

## Template (copy from here)

### Summary

One sentence. What's broken, where, in what state. No diagnosis — just the symptom.

> Example: "Equipping a T2 weapon while inventory tab is mid-animation causes max HP to display as `NaN` until the next room transition."

### Severity

`blocker` | `major` | `minor` | `polish` — pick one. See severity table above.

### Build

- **Git SHA:** (from main-menu footer or itch.io artifact label)
- **Build artifact:** (HTML5 zip filename, native exe filename, or itch.io page URL)
- **Build date:** YYYY-MM-DD
- **Source CI run:** (link to GitHub Actions run if applicable)

### Environment

- **Platform:** HTML5 / Windows native / macOS native / Linux native
- **Browser + version:** (HTML5 only — e.g. Chrome 124.0.6367.78, Firefox 125.0.2)
- **OS + version:** (e.g. Windows 11 24H2, macOS 14.5, Ubuntu 22.04)
- **Display / resolution:** (e.g. 1920×1080 windowed, 2560×1440 fullscreen)
- **Input device:** keyboard + mouse (M1 supports nothing else; flag if controller was plugged in)
- **Network:** (only relevant for HTML5 — wifi / wired / throttled)

### Repro steps

Numbered list. Be specific. Click coordinates aren't needed; in-game state is.

```
1. New Game from title screen.
2. Walk to room 2.
3. Open inventory (Tab).
4. Equip the T2 weapon dropped by the first grunt in room 1.
5. While the equip animation is still playing, press Tab again to close inventory.
6. Walk forward.
```

**Reproducibility:** always / often (>50%) / sometimes (10–50%) / rare (<10%) / once-off — give a hit rate ("3/3 attempts", "5/10 attempts").

### Expected behavior

What should have happened. Cite the spec, mockup, or design doc if relevant — not your opinion.

> Example: "Per `mvp-scope.md` §M1, max HP must reflect equipped affixes immediately after equip. Per Uma's inventory mockup, the equip animation is purely visual and must not block stat propagation."

### Actual behavior

What did happen. Be precise. If a number was wrong, give the exact wrong number. If a UI element was missing, say which one.

> Example: "Max HP UI shows `NaN/120` for ~3 seconds. Combat log shows damage taken as `NaN`. After next room transition, HP resets to `120/120`."

### Evidence

- **Screenshot:** (attach to ClickUp task — drag-and-drop into the description)
- **Clip / GIF:** (attach if motion or timing matters — preferred for combat / animation bugs)
- **Console output:** (paste any GDScript errors or warnings, in a code block)
- **Save file:** (if the bug is save-related, attach the JSON save that triggers it; redact nothing — saves are non-secret)

### Workaround

Anything that gets the player past it. `none` is a valid answer for a `blocker`.

> Example: "Close inventory before equip animation finishes (wait ~0.5s)."

### Suspected area

Tess's gut on which subsystem owns it — combat / inventory / save / UI / level gen / mob AI / build pipeline. **One word, your best guess.** Not authoritative; helps the dev triaging.

### Regression status

- **Was this working before?** yes / no / don't know
- **If yes, last good build SHA:** (best guess)
- **Linked PR / commit suspected:** (only if you have a strong signal — e.g. it broke right after Devon's last combat push)

### Notes

Anything that didn't fit a field above. Hypotheses, related bugs, weird side observations.

---

## After filing

1. Set ClickUp task status to `to do`.
2. Assign to the role that owns the subsystem (combat → Devon, mobs/loot → Drew, ui → Uma + Devon).
3. Append `[YYYY-MM-DD HH:MM] filed bug <ClickUp ID>: <one-line summary>` to `team/log/tess-run-NNN.md`.
4. If `blocker`, also note in `team/STATE.md` "Open decisions" so the orchestrator picks it up the next tick.
