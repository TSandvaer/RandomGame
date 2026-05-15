extends GutTest
## S2 audio entry-trigger integration — W3-T9 (`86c9uf6hh`).
##
## Asserts that:
##   1. The `AudioDirector` autoload registers and exposes the expected API.
##   2. `play_stratum2_bgm()` loads `mus-stratum2-bgm.ogg` and starts the
##      `_bgm_player` on the `BGM` bus.
##   3. `play_stratum2_ambient()` loads `amb-stratum2-room.ogg` and starts
##      the `_ambient_player` on the `Ambient` bus.
##   4. `crossfade_to_boss_stratum2()` swaps BGM to `mus-boss-stratum2.ogg`
##      (honoring Uma's UNIQUE not-cross-stratum-reuse decision logged in
##      `team/DECISIONS.md` 2026-05-15).
##   5. `stop_all_music()` halts both BGM and Ambient.
##   6. The DescendScreen "Return to Stratum 1" handler in `Main.gd` actually
##      fires `play_stratum2_entry()` — the wiring the Sponsor will exercise
##      in the next soak.
##
## **Headless caveat:** GUT runs Godot with `--headless`, which initializes
## `AudioServer` but does not actually decode + play sound to a device. The
## relevant assertions are stream identity (which `.ogg` is set on the player)
## and bus routing (which AudioServer bus the player is configured for) — both
## of which AudioServer tracks faithfully in headless mode. The actual
## audible-playback gate is the HTML5 release-build Self-Test Report in the
## PR comment. See `team/uma-ux/audio-direction.md` and PR #210's
## "Wiring brief for Devon" subsection.
##
## **Regression guard** (per Priya's PR #216 regression-test contract): this
## file is the regression guard for "S2 audio never triggered on descend."
## Without it, a future Main.gd refactor could drop the
## `play_stratum2_entry()` call without breaking any other test.

const STREAM_PATH_S2_BGM: String = "res://audio/music/stratum2/mus-stratum2-bgm.ogg"
const STREAM_PATH_S2_BOSS: String = "res://audio/music/stratum2/mus-boss-stratum2.ogg"
const STREAM_PATH_S2_AMBIENT: String = "res://audio/ambient/stratum2/amb-stratum2-room.ogg"

const TEST_SLOT: int = 993


# ---- Helpers ----------------------------------------------------------

func _audio_director() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AudioDirector")


func _reset_audio_director() -> void:
	# Clean slate: stop everything and clear cached "last path" so the
	# idempotence guard inside `play_stratum2_bgm` doesn't no-op a second
	# test that runs after a first.
	var ad: Node = _audio_director()
	if ad == null:
		return
	if ad.has_method("stop_all_music"):
		ad.stop_all_music(1)  # 1 ms fade — effectively immediate
	if ad.has_method("complete_pending_fades_for_test"):
		ad.complete_pending_fades_for_test()


func before_each() -> void:
	_reset_audio_director()


# ---- Autoload contract ------------------------------------------------

func test_audio_director_autoload_registered() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad, "AudioDirector must be registered as autoload")


func test_audio_director_exposes_full_public_api() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad)
	for method: String in [
		"play_stratum2_bgm",
		"play_stratum2_ambient",
		"play_stratum2_entry",
		"crossfade_to_boss_stratum2",
		"stop_all_music",
		"get_bgm_player",
		"get_ambient_player",
		"get_bgm_crossfade_player",
		"get_last_bgm_path",
		"get_last_ambient_path",
		"complete_pending_fades_for_test",
	]:
		assert_true(ad.has_method(method),
			"AudioDirector must expose %s() (Devon's wiring contract)" % method)


# ---- S2 entry triggers ----------------------------------------------

func test_play_stratum2_bgm_loads_correct_stream_on_bgm_bus() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad)
	ad.play_stratum2_bgm(50)
	ad.complete_pending_fades_for_test()
	var player: AudioStreamPlayer = ad.get_bgm_player()
	assert_not_null(player, "BGM AudioStreamPlayer must exist")
	assert_eq(player.bus, "BGM",
		"BGM player must route to the BGM bus (audio-direction.md §3)")
	# Stream identity — confirm the right OGG is loaded. Compare via
	# resource_path because the stream object is loaded lazily and identity
	# may not match a fresh `load()` call.
	assert_not_null(player.stream, "BGM player must have a stream assigned")
	assert_eq(player.stream.resource_path, STREAM_PATH_S2_BGM,
		"play_stratum2_bgm must load mus-stratum2-bgm.ogg")
	assert_eq(ad.get_last_bgm_path(), STREAM_PATH_S2_BGM,
		"AudioDirector.get_last_bgm_path() must reflect the played cue")


func test_play_stratum2_ambient_loads_correct_stream_on_ambient_bus() -> void:
	var ad: Node = _audio_director()
	assert_not_null(ad)
	ad.play_stratum2_ambient(50)
	ad.complete_pending_fades_for_test()
	var player: AudioStreamPlayer = ad.get_ambient_player()
	assert_not_null(player, "Ambient AudioStreamPlayer must exist")
	assert_eq(player.bus, "Ambient",
		"Ambient player must route to the Ambient bus")
	assert_not_null(player.stream)
	assert_eq(player.stream.resource_path, STREAM_PATH_S2_AMBIENT,
		"play_stratum2_ambient must load amb-stratum2-room.ogg")
	assert_eq(ad.get_last_ambient_path(), STREAM_PATH_S2_AMBIENT)


func test_play_stratum2_entry_fires_both_bgm_and_ambient() -> void:
	# This is the convenience method DescendScreen + Main.gd actually call.
	# Asserts the one-line entry-point produces both cues.
	var ad: Node = _audio_director()
	assert_not_null(ad)
	ad.play_stratum2_entry()
	ad.complete_pending_fades_for_test()
	assert_eq(ad.get_last_bgm_path(), STREAM_PATH_S2_BGM,
		"play_stratum2_entry() must trigger S2 BGM")
	assert_eq(ad.get_last_ambient_path(), STREAM_PATH_S2_AMBIENT,
		"play_stratum2_entry() must trigger S2 Ambient")


# ---- Boss-room crossfade (Uma's unique-music decision) --------------

func test_crossfade_to_boss_stratum2_loads_unique_boss_music_not_s1_reuse() -> void:
	# Honors Uma's DECISIONS.md 2026-05-15 entry — boss room plays
	# mus-boss-stratum2.ogg, NOT mus-boss-stratum1.ogg.
	var ad: Node = _audio_director()
	assert_not_null(ad)
	# Pre-condition: start with S2 BGM playing so the crossfade has
	# something to fade FROM.
	ad.play_stratum2_bgm(1)
	ad.complete_pending_fades_for_test()
	# Then crossfade to boss music.
	ad.crossfade_to_boss_stratum2(50)
	ad.complete_pending_fades_for_test()
	assert_eq(ad.get_last_bgm_path(), STREAM_PATH_S2_BOSS,
		"crossfade_to_boss_stratum2 must target mus-boss-stratum2.ogg")
	# Negative assertion: explicitly NOT the S1 boss music. Belt-and-
	# suspenders against a future regression that points the constant
	# back at S1 reuse.
	assert_ne(ad.get_last_bgm_path(),
		"res://audio/music/stratum1/mus-boss-stratum1.ogg",
		"Boss room MUST play unique S2 music (DECISIONS.md 2026-05-15)")


func test_crossfade_leaves_bgm_player_with_boss_music_after_swap() -> void:
	# After the role-swap the active BGM player should own the boss stream.
	var ad: Node = _audio_director()
	ad.play_stratum2_bgm(1)
	ad.complete_pending_fades_for_test()
	ad.crossfade_to_boss_stratum2(1)
	ad.complete_pending_fades_for_test()
	var active_player: AudioStreamPlayer = ad.get_bgm_player()
	assert_not_null(active_player.stream)
	assert_eq(active_player.stream.resource_path, STREAM_PATH_S2_BOSS,
		"After crossfade, the active BGM player owns the boss stream")


# ---- Global stop -----------------------------------------------------

func test_stop_all_music_halts_bgm_and_ambient() -> void:
	var ad: Node = _audio_director()
	ad.play_stratum2_entry()
	ad.complete_pending_fades_for_test()
	# Sanity: both are playing.
	assert_true(ad.get_bgm_player().playing, "BGM should be playing pre-stop")
	assert_true(ad.get_ambient_player().playing, "Ambient should be playing pre-stop")
	ad.stop_all_music(1)
	# The fade-out's `finished.connect` lambda calls stop() — give it one
	# frame to land.
	await wait_frames(2)
	# Either playing == false, or volume_db drove to silence floor. We
	# assert the stronger condition (playing == false) since headless
	# Tween.finished should fire reliably.
	assert_false(ad.get_bgm_player().playing, "BGM must stop after stop_all_music")
	assert_false(ad.get_ambient_player().playing, "Ambient must stop after stop_all_music")


# ---- Main.gd descend wiring ------------------------------------------

func test_main_descend_restart_run_fires_s2_audio() -> void:
	# Drive the Main scene's descend path and assert the S2 entry trigger
	# fired. This is the regression guard against the wiring getting
	# dropped from `_on_descend_restart_run`.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	assert_not_null(packed, "Main.tscn must load")
	var main: Node = packed.instantiate()
	# Clean slate save so Main doesn't try to restore stale state.
	var save_node: Node = Engine.get_main_loop().root.get_node_or_null("Save")
	if save_node != null and save_node.has_save(0):
		save_node.delete_save(0)
	add_child_autofree(main)
	# Force the descend handler — bypasses the StratumExit physics-overlap
	# flow that headless tests can't drive reliably.
	assert_true(main.has_method("force_descend_for_test"),
		"Main must expose force_descend_for_test() for QA hooks")
	# This pushes the descend screen — drive its restart_run signal too.
	main.force_descend_for_test()
	# Now simulate the player's "Return to Stratum 1" click via the
	# screen's test hook.
	var descend_screen: Node = main.get_descend_screen()
	if descend_screen != null and descend_screen.has_method("press_return_for_test"):
		descend_screen.press_return_for_test()
	# Let the deferred handlers + autoload calls land.
	await wait_frames(3)
	var ad: Node = _audio_director()
	ad.complete_pending_fades_for_test()
	assert_eq(ad.get_last_bgm_path(), STREAM_PATH_S2_BGM,
		"Main._on_descend_restart_run must trigger S2 BGM via AudioDirector")
	assert_eq(ad.get_last_ambient_path(), STREAM_PATH_S2_AMBIENT,
		"Main._on_descend_restart_run must trigger S2 Ambient via AudioDirector")


# ---- Idempotence -----------------------------------------------------

func test_play_stratum2_bgm_is_idempotent_when_already_playing() -> void:
	# Calling twice should not glitch the playback (no second .play() that
	# re-seeds the position to 0). We can't assert "position didn't reset"
	# in headless reliably, but we CAN assert no spurious bus/stream change.
	var ad: Node = _audio_director()
	ad.play_stratum2_bgm(1)
	ad.complete_pending_fades_for_test()
	var stream_before: AudioStream = ad.get_bgm_player().stream
	ad.play_stratum2_bgm(1)
	var stream_after: AudioStream = ad.get_bgm_player().stream
	assert_eq(stream_before, stream_after,
		"Repeated play_stratum2_bgm calls must not swap the stream")
