# M1 RC Build — secret-free release path

The Sponsor doesn't have itch.io secrets configured, and isn't here to set
them up. We need a build path that works without `BUTLER_API_KEY`,
`ITCH_USER`, or `ITCH_GAME`. That's `release-github.yml`.

This is the M1 RC sign-off path. Tess downloads the artifact, runs the
manual cases from `team/tess-qa/m1-test-plan.md`, signs off, and the
orchestrator surfaces the same artifact URL to the Sponsor.

## What it produces

A single zipped HTML5 build:
`embergrave-html5-<short_sha>-<label>.zip` containing `index.html`,
`index.js`, `index.wasm`, `index.pck` (and any `*.worklet.js` Godot 4.3
emits). Drop the unzipped folder in any static web host (or open
`index.html` via a localhost server — file:// won't work due to wasm
fetch). Itch.io will accept the same zip directly when the time comes.

## How to trigger a build

### Option A — manual dispatch (preferred for ad-hoc QA builds)

```sh
gh workflow run release-github.yml --ref <branch>
# Optionally add a label that ends up in the artifact filename:
gh workflow run release-github.yml --ref devon/m1-rc-build -f release_label=rc1
```

Or via the GitHub UI: Actions -> "Release to GitHub (M1 RC build)" ->
"Run workflow", pick the branch, optionally type a label, click "Run
workflow".

The artifact lands under the run's "Artifacts" section once the job is
green:

```
https://github.com/TSandvaer/RandomGame/actions/runs/<RUN_ID>
```

Direct artifact download (CLI):

```sh
gh run download <RUN_ID> --name embergrave-html5-<short_sha>
```

### Option B — tag push (preferred for actual M1 RC handoffs)

Tag patterns that trigger a Release with the zip attached:

- `v*-rc*`     (e.g. `v0.9.0-rc1`)
- `v*-m1-*`    (e.g. `v0.9.0-m1-final`)
- `m1-rc*`     (e.g. `m1-rc1`)

```sh
git tag m1-rc1
git push origin m1-rc1
```

Both jobs run: the export job uploads the workflow artifact (same as
Option A), and the release job creates / updates a GitHub Release at
`https://github.com/TSandvaer/RandomGame/releases/tag/<tag>` with the zip
attached. Auto-generated release notes pull from commits since the
previous tag.

## How Tess downloads it

1. Open the run page (or the Release page for tag pushes).
2. Click the artifact (or release asset) named like
   `embergrave-html5-<short_sha>.zip`.
3. Unzip to a local folder (e.g. `~/embergrave-rc1/`).
4. Serve the folder via any local HTTP server — `python3 -m http.server
   8000` from inside the unzipped dir works. Open
   `http://localhost:8000/index.html`.
5. Verify the build SHA stamp in the main menu footer matches the run's
   short SHA (testability hook 1, per
   `team/devon-dev/debug-flags.md`).

## Verifying without itch.io

The artifact zip is the same content shape itch.io would receive via
butler. If/when secrets land, `release-itch.yml` produces an equivalent
upload to itch.io's HTML5 channel. They aren't redundant: GitHub Releases
are durable for the team's record-keeping; itch.io is the Sponsor-facing
playtest URL. Until secrets exist, GitHub Releases is the only one that
runs.

## Failure modes and what to do

- **"Export preset HTML5 not found"** — `export_presets.cfg` is missing
  or the preset was renamed. Verify `grep 'name="HTML5"' export_presets.cfg`
  matches the workflow's `--export-release "HTML5"`. The CI step
  "Verify HTML5 preset present" catches this before export.
- **"templates not found"** — barichello/godot-ci image was rebuilt
  without 4.3 templates. The "Provide export templates" step downloads
  them as a fallback.
- **WASM doesn't load in browser** — almost always file:// vs http://
  fetch policy. Always serve via http(s)://, not by double-clicking
  `index.html`.
- **Release attached an empty zip** — the "Verify HTML5 output" step
  catches this: it asserts `index.html`, `index.js`, `index.wasm`, and
  `index.pck` all exist before zipping. If that step fails, the Godot
  export silently produced nothing (corrupt project? missing main scene?
  re-import needed?).

## Why this exists separately from release-itch.yml

`release-itch.yml` does a 4-platform export (HTML5 + Win + macOS +
Linux), then runs `butler push` against itch.io. Both halves require
secrets. We need:

- A GitHub-only path that an orchestrator/Devon agent can trigger
  any time without the Sponsor configuring repo secrets.
- A fast path — HTML5 only, ~3 minutes vs. the full matrix's ~10.
- A path that produces a downloadable zip. itch.io fetches directly from
  butler's CDN; there's no easy way for Tess to grab the binaries off
  itch.io for local QA.

`release-github.yml` is HTML5-only on purpose. Win/macOS/Linux exports
land via `release-itch.yml` once secrets exist. M1 sign-off only needs
HTML5.

## Bumping Godot version

Three places in lockstep (matches `team/GIT_PROTOCOL.md` § CI):

1. `.github/workflows/ci.yml` — `GODOT_VERSION`, container image tag.
2. `.github/workflows/release-itch.yml` — `GODOT_VERSION`,
   `GODOT_DOCKER_TAG`, container image tag.
3. `.github/workflows/release-github.yml` — `GODOT_VERSION`, container
   image tag.

Mismatched versions silently produce export artifacts that don't match
the running editor's binary format. Always grep the repo for
`GODOT_VERSION` before bumping.
