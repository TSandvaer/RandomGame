extends Node
## BuildInfo autoload — exposes the current build's git SHA so the main
## menu / HUD can render it as a footer ("build: abcdef1") for Tess's
## acceptance test bookkeeping. Per `team/tess-qa/m1-test-plan.md` §"Build
## identification": *every test run records the build artifact + git SHA*.
##
## Source priority (first match wins):
##   1. `res://build_info.txt` — written by CI (`.github/workflows/ci.yml`
##      and `release-itch.yml`) using `$GITHUB_SHA`. One line, no trailing
##      newline. CI also writes the short (7-char) form for display.
##   2. Environment variable `GITHUB_SHA` — for local builds that run
##      under CI shells (`act`, etc.).
##   3. Literal `"dev-local"` — local dev runs without CI plumbing.
##
## API:
##   BuildInfo.sha            -> String   full or short SHA, or "dev-local"
##   BuildInfo.short_sha      -> String   first 7 chars (or whole string if shorter)
##   BuildInfo.display_label  -> String   "build: abcdef1" (or "build: dev-local")
##
## All values are computed once at `_ready()` and frozen for the run, so
## queries from HUD code are O(1).

const BUILD_INFO_PATH: String = "res://build_info.txt"
const FALLBACK_SHA: String = "dev-local"

# Populated in _ready(). Public read-only by convention.
var sha: String = FALLBACK_SHA
var short_sha: String = FALLBACK_SHA
var display_label: String = "build: %s" % FALLBACK_SHA


func _ready() -> void:
	sha = _resolve_sha()
	short_sha = _shorten(sha)
	display_label = "build: %s" % short_sha
	# One line so smoke tests / Tess can grep it from a headless --import run.
	print("[BuildInfo] %s" % display_label)


## Internal: resolve the SHA from CI artifact, env, or fallback.
## Exposed for testability — `tests/test_build_sha.gd` can inject a
## different file and re-resolve.
func _resolve_sha() -> String:
	# (1) CI-written file. Strip whitespace defensively in case the CI
	# `echo` pipeline added a newline.
	if FileAccess.file_exists(BUILD_INFO_PATH):
		var f: FileAccess = FileAccess.open(BUILD_INFO_PATH, FileAccess.READ)
		if f != null:
			var raw: String = f.get_as_text().strip_edges()
			f.close()
			if raw.length() > 0:
				return raw
	# (2) Env var fallback.
	var env_sha: String = OS.get_environment("GITHUB_SHA")
	if env_sha != "":
		return env_sha.strip_edges()
	# (3) Local dev marker.
	return FALLBACK_SHA


## Internal: shrink a 40-char SHA to 7 (Git's default short form). Returns
## the input unchanged if it's already shorter or is the dev-local marker.
func _shorten(value: String) -> String:
	if value == FALLBACK_SHA:
		return value
	if value.length() <= 7:
		return value
	return value.substr(0, 7)


## Test-only: re-resolve from disk + env. Tests use this to verify the
## CI-file path overrides the env var, etc. Not called from gameplay.
func reload_for_test() -> void:
	sha = _resolve_sha()
	short_sha = _shorten(sha)
	display_label = "build: %s" % short_sha
