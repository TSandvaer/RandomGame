# itch.io deploy — secrets & setup checklist

The `release-itch.yml` workflow exports HTML5 + Windows + Linux + macOS on tag
push and uploads each platform to its own itch.io channel using **butler**.
This doc is the one-time setup checklist plus the runbook for tagging a release.

## Required GitHub Actions secrets

Set these in the repo at: **Settings -> Secrets and variables -> Actions -> New repository secret**.

| Secret name      | Where to get it | Notes |
|------------------|-----------------|-------|
| `BUTLER_API_KEY` | https://itch.io/user/settings/api-keys -> "Generate new API key" | Treat as a password. Rotate if leaked. Scope is full account, so only paste it into the repo's GitHub Secrets — never into a workflow file. |
| `ITCH_USER`      | Your itch.io username (the part of your profile URL after `itch.io/`) | e.g. `tsandvaer`. No `@`, no URL. |
| `ITCH_GAME`      | The slug of the itch.io game page | e.g. `embergrave`. The game page must already exist on itch.io (create it as **Restricted / Draft** for the M1 sponsor playtest). |

## itch.io channel naming

The workflow pushes to four channels per release. itch's convention is
`<user>/<game>:<channel>`. We use:

| Platform | Channel name |
|----------|--------------|
| HTML5 (browser-playable) | `html5` |
| Windows (zip)            | `windows` |
| Linux (zip)              | `linux` |
| macOS (zip)              | `mac` |

Optional channel suffix: passing `itch_channel_suffix=preview` to a manual
`workflow_dispatch` run pushes to `html5-preview`, `windows-preview`, etc.,
which is useful for non-tag builds you want behind a separate page.

## Tagging a release

```sh
git tag m1-2026-05-30
git push origin m1-2026-05-30
```

Tag patterns that trigger the workflow: `v*.*.*`, `m1-*`, `m2-*`, `m3-*`. The
tag name becomes the `--userversion` butler passes to itch — this is the
human-readable version string shown on the itch page.

For a non-tagged trial run, use **Actions -> Release to itch.io -> Run
workflow** in the GitHub UI. That route still uploads to itch but skips the
GitHub Release step.

## Export presets (`export_presets.cfg`)

This file is **not yet committed**. The release workflow will fail until
Devon (or whoever ships the first export) generates it via:

```
godot --headless --path . --editor    # creates export_presets.cfg with empty defaults
```

Then in the editor: **Project -> Export -> add presets** named exactly:
`HTML5`, `Windows Desktop`, `Linux/X11`, `macOS`. The matrix entries in
`release-itch.yml` reference those preset names verbatim.

When `export_presets.cfg` lands, commit it. Open the file and remove any
encryption keys or local paths that leaked in.

Until then, the `publish-itch` job is best treated as smoke-tested by the
workflow's own static linting; the first real run will be after the first
preset config lands (week 2).

## First-run sanity checklist

1. itch.io game page created (Restricted/Draft).
2. Three secrets set in GitHub.
3. `export_presets.cfg` committed with the four preset names.
4. `butler` runs locally once with `BUTLER_API_KEY` env var set, just to
   confirm the key is good: `butler push --userversion test some.zip
   $ITCH_USER/$ITCH_GAME:html5-preview`.
5. Push a `v0.0.1-smoke` tag. Watch Actions. If the HTML5 channel updates
   on itch.io, you're green.

## Troubleshooting

| Symptom | Probable cause |
|---------|----------------|
| Workflow fails at "Export" with "preset not found" | `export_presets.cfg` missing or preset name doesn't match the matrix entry. |
| Workflow fails at "Push to itch" with "401 Unauthorized" | `BUTLER_API_KEY` expired/typoed. Rotate at itch.io, update secret. |
| HTML5 channel uploads but page won't load in browser | `index.html` not at the root of the artifact. Check `export_path` in the matrix matches the preset's HTML5 file. |
| Steam-like 404 on the itch URL | Game page set to Draft + you're not signed into itch as the owner. Sign in. |
