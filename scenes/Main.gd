extends Node2D
## Main entry scene. Boots the game, prints a banner, hands off to the
## title screen / first room once those exist. Until then it's just a
## sanity scene so headless `--import` and CI smoke tests have something
## to load.

const BANNER: String = "==[ Embergrave — Ember-Knight wakes. Stratum 0. ]=="


func _ready() -> void:
	print(BANNER)
	print("[Main] Godot version: %s" % Engine.get_version_info().string)
	print("[Main] Scene tree ready. Autoloads: Save=%s" % (Save != null))
	# Stub: in a future task this will route to TitleScreen.tscn -> Stratum1.tscn.
	# For now we just sit here so the headless import smoke check passes.
