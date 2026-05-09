# Devon screenshots — Self-Test Report visual evidence

This directory holds screenshots Devon captures from HTML5 release-build artifacts to satisfy the **HTML5 visual-verification gate** (`.claude/docs/html5-export.md` § "HTML5 visual-verification gate", tightened per PR #161). Each file is named `<short-purpose>-<ticket-id>.png` and is referenced from the Self-Test Report comment on the corresponding PR.

These are point-in-time evidence captures, not gameplay content. They live in `team/devon-dev/` (Devon's lane) so the production tree stays clean.

## Capture method

1. Download the HTML5 release-build artifact (`embergrave-html5-<sha>` from `release-github.yml`).
2. Unzip to a fresh directory.
3. Run an ad-hoc Playwright spec that boots the artifact, drives a deterministic input (e.g. F1 keybind temporarily wired in `Main._unhandled_input`), waits for the visual to fade in, and saves a screenshot.
4. Revert the temporary input trigger before opening the PR (the trigger is dev-only convenience, not a feature).
5. Commit the captured PNG here and reference it from the Self-Test Report.

## Files

| File | Ticket | PR | What it shows |
|---|---|---|---|
| `tutorial-prompt-firing-86c9qajcf.png` | `86c9qajcf` | TBD | TutorialPromptOverlay test prompt ("LMB to strike.") firing on F1, build SHA `4963b24` (the temp-trigger build; the PR ships without the trigger). Renderer = `gl_compatibility` (HTML5 default per `project.godot`). |
