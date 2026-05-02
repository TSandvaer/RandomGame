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

## What changed (3 hardening items + 1 nice-to-have)

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

## Deliberately NOT addressed in this PR

- **Docker image cache.** The `barichello/godot-ci:4.3` pull is ~85 s and dominates every run. Caching it requires a `docker save` / `docker load` dance via `actions/cache@v4` on the `.tar` of the image, run *outside* the container job (a separate setup job that exports the tar, then the test job restores and `docker load`s before its own container starts). This is doable but materially restructures the workflow (two jobs, an artifact handoff, and the `container:` directive becomes harder to express with a cached image). Filed as a follow-up — defer until total runtime starts blocking development cadence.
- **Flake detection (per dispatch §3).** Skipped per dispatch's explicit "if running 5x is impractical, skip and document". Each rerun adds ~1 m 42 s and noise; the flake-rate signal isn't worth the cost when the test suite is fresh and Tess has added integration coverage in run 016. Revisit on a future tick once test count plateaus.
- **Per-test runtime budget enforcement.** GUT run total is ~2 s for 557 tests. Even a generous 5 s single-test budget is an order of magnitude above the actual maximum. Spending engineering time on a budget mechanism right now is premature; revisit if the GUT step duration crosses ~30 s.
- **GUT clone caching.** GUT clone is ~0.8 s on success. Caching it would save under a second and add cache complexity. Pure noise.

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
