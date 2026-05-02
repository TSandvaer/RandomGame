# GUT (Godot Unit Test) — install instruction

We do **not** vendor the full GUT addon source in this repo. Instead, CI installs
GUT at runtime so the Godot version and GUT version stay pinned in one place
(`.github/workflows/ci.yml`).

## Local dev: install GUT into `addons/gut/`

Pick one of:

### Option A — Asset Library (recommended for local dev)

1. Open the project in Godot 4.3.
2. AssetLib tab -> search "Gut" -> author **bitwes** -> install.
3. Project -> Project Settings -> Plugins -> enable **Gut**.
4. Restart the editor.

### Option B — Git submodule (if you want it pinned in repo)

```sh
git submodule add https://github.com/bitwes/Gut.git addons/gut
git -C addons/gut checkout v9.3.0
```

We chose **Option A** for now: smaller repo, less merge-pain. Tests still run in CI
because the workflow does `git clone bitwes/Gut --depth 1 --branch v9.3.0` before
running tests.

## Running tests locally

After installing GUT:

```sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Pinned version

GUT **v9.3.0** (Godot 4.3 compatible). Bump in lockstep across this README,
the CI workflow, and any local dev installs.
