# CI hardening pass — `.github/workflows/ci.yml`

Date: 2026-05-02
Author: Devon (run 008)
ClickUp: `86c9kxx8a` — `chore(ci): hardening pass`
Branch / PR: `devon/ci-hardening`

## Why now

CI runtime audit on green run [25257777669](https://github.com/TSandvaer/RandomGame/actions/runs/25257777669) (commit on `main`):

| Step                                  | Duration |
|---------------------------------------|----------|
| Set up job                            |  ~1 s    |
| **Initialize containers (docker pull `barichello/godot-ci:4.3`)** | **~85 s** |
| Checkout                              |  ~1 s    |
| Show Godot version                    |  ~0 s    |
| Install GUT (pinned, git clone)       |  ~1 s    |
| Stamp build SHA                       |  ~0 s    |
| Headless import (asset import sanity) |  ~7 s    |
| Run GUT tests (557 tests, 5646 asserts)| ~2 s    |
| Post-checkout / cleanup               |  ~1 s    |
| **Total wall-clock**                  | ~1 m 42 s |

Container init dominates, GUT runs in ~2 s, no individual test exceeds 5 s. The asset-import step (~7 s) is small today but grows with content as Drew adds rooms / mobs / loot tables.

## What changed (initial pass + follow-up)

The initial pass (PR #76, merged `d9dba48`) landed concurrency, `.godot/`
cache, GUT clone retry, and failure-artifact upload. The follow-up pass
(this file's update) adds a workflow-level `timeout-minutes`, a GUT
addon cache, and the flake-quarantine pattern documentation.

### 1. `concurrency:` — cancel superseded runs on the same ref

A `concurrency` block at workflow level:

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

When a new commit lands on a feature branch / PR while an earlier commit's CI is still running, the earlier run is cancelled. Saves the ~85 s container pull on every superseded run during a typo-fix-typo-fix push series. **`main` is excluded** — push-to-main runs always finish, never cancelled by a follow-up PR run. PR runs against different branches don't collide because the group is keyed on `github.ref`.

### 2. `actions/cache@v4` — cache `.godot/` import database

```yaml
- name: Cache Godot import (.godot)
  uses: actions/cache@v4
  with:
    path: .godot
    key: godot-import-${{ env.GODOT_VERSION }}-${{ env.GUT_VERSION }}-${{ hashFiles('project.godot', '**/*.tscn', '**/*.tres', '**/*.gd', '**/*.png', '**/*.svg', '**/*.ttf') }}
    restore-keys: |
      godot-import-${{ env.GODOT_VERSION }}-${{ env.GUT_VERSION }}-
```

The hash key changes whenever any importable input changes; the restore-key falls back to the most recent cache for this Godot+GUT pair so a near-miss cache (one new scene added) still gets a partial warm start. **Cache miss is identical to no-cache flow** — `godot --headless --import` rebuilds `.godot/` from scratch — so there's no second code path. Asset-import payback is ~7 s today and grows linearly with content.

### 3. Retry the GUT clone (3 attempts, exponential backoff)

```bash
attempt=0; max_attempts=3
until git clone --depth 1 --branch "${GUT_VERSION}" https://github.com/bitwes/Gut.git /tmp/gut-src; do
  attempt=$((attempt + 1))
  [ "${attempt}" -ge "${max_attempts}" ] && exit 1
  backoff=$((attempt * 10 - 5))   # 5 s, 15 s
  rm -rf /tmp/gut-src
  sleep "${backoff}"
done
```

Most common cold-CI flake mode in this stack: transient `git clone` ECONNRESET / 500 from `github.com`. Retrying 3 times with 5 s / 15 s backoff caps worst-case wait at ~22 s vs. an immediate red run + manual re-queue.

### 4. (Nice-to-have) `actions/upload-artifact@v4` on failure

GUT now emits a JUnit XML to `test-reports/gut-results.xml` (`-gjunit_xml_file=`, supported in v9.3.0). On `if: failure()`, the workflow uploads `test-reports/` and `build_info.txt` as a 7-day retention artifact. Always-on upload would burn quota on every green push; the failure guard scopes it to runs where post-mortem material is actually wanted.

### 5. Workflow `timeout-minutes: 10` (follow-up pass)

```yaml
jobs:
  import-and-test:
    ...
    timeout-minutes: 10
```

Recent baseline is ~1m20s — 10 minutes is plenty of headroom. A hung
Godot import (infinite recursion in a TRES, deadlocked autoload
`_ready`) or a runaway test wouldn't otherwise cap and would burn
Actions minutes until GitHub's 6h default kicks in. **If runs ever
start hitting this cap, investigate — don't bump it.**

### 6. `actions/cache@v4` — cache the GUT addon (follow-up pass)

```yaml
- name: Cache GUT addon
  id: cache-gut
  uses: actions/cache@v4
  with:
    path: addons/gut
    key: gut-${{ env.GUT_VERSION }}-v1

- name: Install GUT (pinned)
  if: steps.cache-gut.outputs.cache-hit != 'true'
  run: |
    ...
```

Initial pass deferred this on the basis that the clone is "<1 s on
success" (the timing audit showed ~1 s); the dispatch's wider scope
called this 5-10 s and asked for the cache anyway. Trade-off:
deterministic cache hit > variable-cost clone, even if the median is
small. The retry-with-backoff in the install step still covers the
cold path (e.g. on `GUT_VERSION` bump). A `Verify GUT addon present`
step covers both cache-hit and cold-clone paths so a missing addon
shows up with a clear error before GUT itself.

**Invalidation contract:** any change to `GUT_VERSION` re-runs the
clone. There is no second code path — the cache restore IS the
install on warm runs.

## Flake quarantine pattern (follow-up pass)

When a test starts failing intermittently on CI but passes locally
(real flake), or the cause is genuinely environmental (autoload not
available in pure-bare-test mode, Linux-only case-sensitive paths,
etc.), use GUT's `pending()` to quarantine it. This keeps the run
green without losing the test.

### Canonical example — GameState autoload

`tests/test_autoloads.gd:67`:

```gdscript
func test_gamestate_autoload_registered() -> void:
    if not Engine.has_singleton("GameState"):
        pending("GameState autoload not yet registered — see automated-smoke-plan.md tu-autoload-01")
        return
    assert_true(true)
```

`pending()` makes GUT count the test as **risky-pending** (visible in
the CI summary as e.g. `556/1/0` = 556 passing / 1 pending / 0
failing). The reason string MUST point to a follow-up — a ticket ID,
a plan-doc anchor, or a clear-enough sentence that a future reader
can decide whether the quarantine still applies.

### When to quarantine vs. fix

| Scenario | Action |
|----------|--------|
| Bug repros locally on the same SHA | **Fix it.** Quarantine is for things you can't immediately fix. |
| Only fails on CI (timing, autoload ordering, asset path case sensitivity, etc.) | **Quarantine + open a follow-up ticket.** Reference the ticket ID in the `pending()` reason. |
| Fails because a dependency isn't ready yet (autoload not registered, scene not authored) | **Quarantine** with a pointer to the dependency's plan-doc anchor — like the GameState example above. |
| Test is wrong (bad assertion, race condition in the test itself) | **Fix the test, don't quarantine.** |
| Test is slow (>1 s per assert) but not flaky | **Don't quarantine — file an optimisation ticket.** Quarantine is for non-determinism, not for budget. |

### How long can a quarantine live?

- **Default: 7 days.** A `pending()` left for more than a week
  without a corresponding fix-or-decision is a bug-debt smell.
- **Longer requires Priya's OK** as a planning call. Note the
  exception in the `pending()` reason string AND in the linked
  ticket.
- **No "permanent" quarantines.** If something is genuinely never
  going to be fixed (e.g. test for a deprecated subsystem), delete
  the test file instead of leaving it pending forever.

### Current quarantine list (2026-05-02)

| Test file | Test | Reason | Owner | Filed |
|-----------|------|--------|-------|-------|
| (none) | — | — | — | — |

The known `pending()` calls in the suite at this tick are NOT
quarantines — they are **conditional skips** (debug build only,
autoload presence checks):

- `tests/test_autoloads.gd:67` — GameState autoload existence probe.
  Self-clears when `Engine.has_singleton("GameState")` returns true.
- `tests/test_fast_xp_debug.gd` (7 calls) — gated on
  `OS.is_debug_build()`. Always pending in non-debug GUT-cmdln runs;
  not a flake.
- `tests/test_test_mode_seed.gd` (4 calls) — same pattern as
  fast_xp_debug.

Conditional skips don't need ticket follow-up because the gate IS the
intent of the test (e.g. `--test-mode` flag is debug-only by design).

### Workflow for filing a new quarantine

1. Add `pending("<reason + ticket ID or plan-doc anchor>")` inside the
   failing test. Place it as the FIRST statement so the test exits
   immediately and doesn't run any flaky setup.
2. Open a follow-up ticket on ClickUp, list `901523123922`, tag
   `flaky-test`, priority `low` (default) or `normal` (if it's
   blocking real coverage). Title pattern:
   `flaky(<area>): <test name> intermittent on CI`.
3. Reference the ticket ID in the `pending()` reason and add an entry
   to the **Current quarantine list** table above with the filed-date.
4. If the quarantine isn't resolved in 7 days, take it to Priya for
   either an extension or a "delete the test" call.

## Deliberately NOT addressed in this PR

- **Docker image cache.** The `barichello/godot-ci:4.3` pull is ~85 s and dominates every run. Caching it requires a `docker save` / `docker load` dance via `actions/cache@v4` on the `.tar` of the image, run *outside* the container job (a separate setup job that exports the tar, then the test job restores and `docker load`s before its own container starts). This is doable but materially restructures the workflow (two jobs, an artifact handoff, and the `container:` directive becomes harder to express with a cached image). Filed as a follow-up — defer until total runtime starts blocking development cadence.
- **Flake detection (per dispatch §3).** Skipped per dispatch's explicit "if running 5x is impractical, skip and document". Each rerun adds ~1 m 42 s and noise; the flake-rate signal isn't worth the cost when the test suite is fresh and Tess has added integration coverage in run 016. Revisit on a future tick once test count plateaus.
- **Per-test runtime budget enforcement.** GUT run total is ~2 s for 557 tests. Even a generous 5 s single-test budget is an order of magnitude above the actual maximum. Spending engineering time on a budget mechanism right now is premature; revisit if the GUT step duration crosses ~30 s.
- ~~**GUT clone caching.**~~ Initially deferred as <1 s noise; added in
  the follow-up pass (see §6) — hardening dispatch wanted deterministic
  cache hit over variable-cost clone, even at the small median. Cost is
  a few lines of YAML, gain is one fewer thing that can ECONNRESET on
  cold runs.

## Follow-up tickets

- **`chore(ci): cache barichello/godot-ci docker image via save/load`** — file in ClickUp on next dispatch when MCP reconnects (queued in `team/log/clickup-pending.md`). Estimated payback: ~80 s per cold run; cost: ~1 day of workflow restructuring + probably a separate "setup" job pre-pull plus an action that exposes the tar to the test job. Dispatch when total CI runtime > 5 min OR when team CI cadence becomes a bottleneck.
- **`chore(ci): flake-detection sweep`** — when the test suite plateaus (~2 weeks no new tests), run CI 5x in a row on a known-green commit; quarantine any test that flips pass/fail via GUT `pending()` + comment.

## Verification plan (this PR)

1. Push branch, open PR — CI runs with all four hardening items engaged.
2. **Cache miss path**: first run on the branch will be a cache miss (the `restore-keys:` fallback may match an existing main cache). Verify cache step does not fail and import still completes.
3. **Cache hit path**: second push to the same branch (e.g. trivial doc tweak) should show "Cache hit" in the cache step. Import step should be measurably shorter (test by adding a no-op commit and comparing run timestamps; not a hard CI-gated check).
4. **GUT XML emission**: even on a green run, `test-reports/gut-results.xml` is produced; the upload-artifact step is a no-op on success (only triggers `if: failure()`).
5. **Concurrency**: not directly verifiable on a single PR (would need two rapid pushes to the same branch); document in PR body and trust the GitHub Actions semantics.
6. **GUT clone retry**: hidden unless the network actually fails. The `until` loop's success path is identical to a single-attempt clone, so green runs verify it doesn't break the happy path.

## Numbers to watch (post-merge)

- Cold-run total wall-clock (docker pull + cache miss): expect ≈1 m 50 s — slightly slower than current ~1 m 42 s because the cache restore is a small overhead on miss.
- Warm-run total wall-clock (docker pull + cache hit): expect ≈1 m 35 s — saves the ~7 s import time.
- The big container-pull fish (~85 s) is unaddressed in this PR; see follow-up ticket above.

---

## Changelog

- **2026-05-02 — initial pass (PR #76, merged `d9dba48`):** workflow
  `concurrency:` cancels superseded non-main runs; `actions/cache@v4`
  caches `.godot/`; GUT clone retried 3x with backoff; failed-run
  artifact upload of GUT JUnit XML + build_info.txt with 7-day
  retention.
- **2026-05-02 — follow-up pass (this PR):** `timeout-minutes: 10` on
  `import-and-test` job (workflow safety net); `actions/cache@v4` on
  `addons/gut/` keyed by `GUT_VERSION` with cache-hit-skips-install
  guard; flake-quarantine pattern documented (canonical example,
  fix-vs-quarantine criteria, 7-day default lifetime, current
  quarantine list of zero, distinction between conditional skips and
  real quarantines, workflow for filing new quarantines).

  Verified cold + warm cache demo runs on this PR; numbers in the PR
  body table.
