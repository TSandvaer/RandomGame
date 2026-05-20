## Summary

Three doc captures from the M3 Tier 1 drain (closure pass on PRs #280, #281, #282 — all merged yesterday). Pure docs follow-up — no code changes. Authored via the maintain-docs proposer+consolidator flow.

### `.claude/docs/audio-architecture.md` — Playwright audio QA pattern

New section: **`[combat-trace]` audio observability — Playwright QA pattern** (after "Verification gate").

- Documents `[combat-trace] AudioDirector.play_sfx | cue_id=<id>` as the **load-bearing Playwright-observable audio surrogate**. Playwright can't hear, but it can grep the console for `cue_id`.
- Validated by Tess's PR #281 HTML5 probe: Scenario A (dodge → 1 cue) + Scenario B (passive damage 20s → 20 take_damage events + 0 cues = strong negative).
- Coupling note: trace fires inside `play_sfx()`, not at individual `.play()` call sites — any SFX-routing refactor that bypasses `play_sfx` makes Playwright specs pass vacuously.
- HTML5-only limitation (same gate as all `[combat-trace]` lines).

### `.claude/docs/test-conventions.md` — three new sections

**1. Adversarial off-cardinal probe values for decoupling specs (PR #282).** A spec asserting "X follows movement-velocity, not cursor" can pass vacuously if probed with cardinal-east (`atan2(0,1)=0`) — both correct and regression paths return 0. PR #282 fix: use SE-diagonal `Vector2(1,1)` → `atan2≈0.785`. Includes the revert-hack validation rule (Drew validated SE-pin catches Fix #1 + Fix #2 reverts independently; cardinal-pin would not).

**2. Passive-damage Playwright probe windows (PR #281).** 8s is insufficient — Grunts at distance 27-28 take 10-12s to close + land first hit. Minimum 15s window for Room 01 mob density. Includes Room 02 load sentinel note (no `Main._load_room_at_index` trace; use first `Grunt.pos` line).

**3. Playwright-spec orphan-ref class — GUT test-name drift (PR #280).** Two root causes captured: legitimate rename drift (`test_sprite_rotation_updates_when_present` deleted in PR #274 fix #2) + author-typo orphan (`test_room_gate_3mob_concurrent_death_unlock` never existed). Future-tooling lint flagged (grep `test_*` tokens in Playwright specs against actual `tests/*.gd` defs). Author checklist until lint lands.

### `.claude/docs/combat-architecture.md` — Signal-emit-comment drift audit rule

New section after `[combat-trace] diagnostic shim`: **Signal-emit-comment drift — multi-path audit rule (PR #281)**.

- Documents the live PR #281 example: `iframes_started` documented as dodge-only but actually emits from both `try_dodge()` AND `take_damage()`. Two consumers caught with same-class wrong assumption — audio listener (Tess caught on PR #278) + `Stratum1Room01` tutorial wiring (latent because PracticeDummy has no aggressive hitbox).
- 3-step audit rule for any signal-touching refactor: grep all emit sites → audit all `.connect()` consumers against full emit topology → split mixed-semantic signals rather than patching with guards.
- Highest-risk pattern: intent-named signals (`iframes_started`, `mob_died`, `lmb_strike`, `TutorialEventBus.request_beat`).

## Test plan

- [x] Diffs reviewed locally — match the maintain-docs consolidator output
- [x] No code or asset changes — pure `.claude/docs/*.md` markdown
- [ ] CI green (lint / GUT / Playwright should all be no-op for doc-only)
- [ ] GitHub markdown renders all three files correctly (tables, code blocks, headers)

## Related

- M3 Tier 1 drain PRs (already merged): #280 (orphan-ref cleanup), #281 (dodge-signal split), #282 (walk-feel decouple Playwright spec)
- Prior docs follow-up pattern: PR #279 (M3 Tier 1 batch follow-ups — Strategy 4, worktree cleanup, --body-file)
- PR body authored via `--body-file` per the discipline established in PR #279

🤖 Generated with [Claude Code](https://claude.com/claude-code)
