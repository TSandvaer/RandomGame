extends Node2D
## Main entry scene. Boots the game, prints a banner, hands off to the
## title screen / first room once those exist. Until then it's just a
## sanity scene so headless `--import` and CI smoke tests have something
## to load.

const BANNER: String = "==[ Embergrave — Ember-Knight wakes. Stratum 0. ]=="


func _ready() -> void:
	print(BANNER)
	print("[Main] Godot version: %s" % Engine.get_version_info().string)
	print("[Main] Scene tree ready. Autoloads: Save=%s BuildInfo=%s" % [Save != null, BuildInfo != null])
	# Build SHA footer — sourced from CI stamp via BuildInfo autoload.
	# Per Tess m1-test-plan section "Build identification": every test run records
	# the build artifact + git SHA. Footer renders 7-char short SHA or
	# "dev-local" for non-CI builds.
	var build_label: Label = get_node_or_null("BuildLabel") as Label
	if build_label != null and BuildInfo != null:
		build_label.text = BuildInfo.display_label
	# Stub: in a future task this will route to TitleScreen.tscn -> Stratum1.tscn.
	# For now we just sit here so the headless import smoke check passes.
