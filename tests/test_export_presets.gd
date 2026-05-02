extends GutTest
## Sanity check: export_presets.cfg must be committed and must declare
## every preset name the CI release workflows reference. If a preset is
## renamed in the file but the workflow's matrix entry isn't updated in
## lockstep, headless `godot --export-release "<name>"` exits non-zero
## with a quiet "preset not found" — which manifests as a CI failure
## that's painful to bisect. This test catches that drift at unit-test
## time instead.
##
## Devon, 2026-05-02 — paired test for the M1 RC build path
## (.github/workflows/release-github.yml, ClickUp 86c9ky4fv).

const PRESET_PATH: String = "res://export_presets.cfg"

# Preset name -> human-friendly description of the workflow consuming it.
# If you add a preset and reference it from a workflow, append it here.
const REQUIRED_PRESETS: Dictionary = {
	"HTML5": "release-github.yml + release-itch.yml HTML5 matrix entry",
	"Windows Desktop": "release-itch.yml Windows matrix entry",
	"Linux/X11": "release-itch.yml Linux matrix entry",
	"macOS": "release-itch.yml macOS matrix entry",
}


func test_export_presets_file_is_present() -> void:
	# FileAccess.file_exists works on res:// in --headless mode iff the
	# file is registered with the project. export_presets.cfg lives at the
	# project root, so it's accessible via res://.
	assert_true(FileAccess.file_exists(PRESET_PATH),
		"export_presets.cfg must be committed at repo root — see team/devon-dev/m1-rc-build.md")


func test_export_presets_declare_required_names() -> void:
	# We can't use ConfigFile.load("res://export_presets.cfg") directly because
	# Godot's editor strips this file from the resource pack on export — but we
	# can read it as a plain text resource via FileAccess.
	var f: FileAccess = FileAccess.open(PRESET_PATH, FileAccess.READ)
	assert_not_null(f, "export_presets.cfg must be readable via FileAccess")
	if f == null:
		return
	var contents: String = f.get_as_text()
	f.close()
	for preset_name in REQUIRED_PRESETS.keys():
		var key: String = String(preset_name)
		var needle: String = 'name="%s"' % key
		var found: bool = contents.find(needle) != -1
		assert_true(found,
			"Preset name=\"%s\" missing from export_presets.cfg — referenced by %s"
				% [key, REQUIRED_PRESETS[preset_name]])


func test_release_github_workflow_present() -> void:
	# The M1 RC build path. If this file is missing, M1 has no secret-free
	# build path and Tess cannot get an artifact for sign-off.
	var path: String = "res://.github/workflows/release-github.yml"
	# .github/ may not be visible via res:// (Godot's import filter excludes
	# dotfiles). Fall back to globalize_path + system FileAccess.
	var abs_root: String = ProjectSettings.globalize_path("res://")
	var sys_path: String = abs_root + ".github/workflows/release-github.yml"
	# FileAccess on an absolute system path works in Godot 4.3 if Godot was
	# launched with that path inside its res:// root (true for headless CI).
	# We accept either path resolution — both indicate the file is committed.
	var found: bool = FileAccess.file_exists(path) or FileAccess.file_exists(sys_path)
	assert_true(found,
		"release-github.yml must be committed at .github/workflows/ — see team/devon-dev/m1-rc-build.md")
