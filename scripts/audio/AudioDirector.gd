extends Node
## AudioDirector autoload — central owner of BGM / Ambient music transitions.
##
## **What this autoload does** (M2 W3 T9 — ClickUp `86c9uf6hh`):
##   1. Owns three `AudioStreamPlayer` nodes for global non-positional cues:
##        - `_bgm_player` → BGM bus (stratum BGM, boss music)
##        - `_ambient_player` → Ambient bus (room ambient bed)
##        - `_bgm_crossfade_player` → BGM bus, used for boss-room crossfades
##          (the outgoing track fades on `_bgm_player`, the incoming track
##          fades in on this player, then they swap roles).
##   2. Exposes high-level intent methods that other systems call by name:
##        - `play_stratum2_bgm(fade_in_ms)` — S1→S2 transition BGM
##        - `play_stratum2_ambient(fade_in_ms)` — S1→S2 transition Ambient
##        - `crossfade_to_boss_stratum2(fade_ms)` — boss-room music swap
##        - `stop_all_music(fade_out_ms)` — global stop (death, descend)
##   3. Lazy-loads `AudioStreamOggVorbis` resources on first use so a cold
##      boot doesn't pay the decode cost up front.
##
## **Why an autoload (not a Main.gd member):** every stratum-transition,
## boss-room load, and player-death event needs to reach the audio plumbing
## from a distinct call site. Routing them all through `Main.gd` would
## couple the audio to the M1 play-loop scene (which is itself getting
## torn down + rebuilt on respawn). An autoload survives scene-tree swaps
## and is reachable as `AudioDirector.play_stratum2_bgm()` from any node.
##
## **HTML5 audio-playback gate** (`team/uma-ux/audio-direction.md` and
## PR #210's deferred-to-Devon note): browsers gate `AudioContext` activation
## behind a user-gesture (a click, keypress, or touch). Until the player
## interacts with the page, ALL audio is silently silenced — `play()` succeeds
## from the engine's perspective but no sound emits. Embergrave currently
## boots straight into Stratum1Room01 (no menu / no title screen), so the
## first audio cue MUST fire AFTER the player has pressed at least one key.
## This is OK in practice because the S2 BGM / Ambient fires from the descend
## screen's "Return to Stratum 1" button — which IS a user gesture — and
## subsequent cues inherit the unlocked AudioContext. The first-cue-before-
## gesture path (if any future cue fires from `_ready`) needs an explicit
## `AudioContext.resume()` hook; intentionally not added now.
##
## **Test surface** (paired tests):
##   - `tests/test_audio_bus_layout.gd` — bus existence + dB values
##   - `tests/integration/test_s2_audio_triggers.gd` — S2 entry cues fire on
##     the right buses with the right streams
##
## **Decision honored:** Uma's UNIQUE (not cross-stratum-reuse) boss-music
## decision is preserved here — `crossfade_to_boss_stratum2()` loads
## `mus-boss-stratum2.ogg`, NOT `mus-boss-stratum1.ogg`. See
## `team/DECISIONS.md` 2026-05-15 entry.

# ---- Constants --------------------------------------------------------

const BUS_BGM: StringName = &"BGM"
const BUS_AMBIENT: StringName = &"Ambient"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"

## Cue resource paths. Match the filenames Uma shipped in PR #210.
const STREAM_PATH_S2_BGM: String = "res://audio/music/stratum2/mus-stratum2-bgm.ogg"
const STREAM_PATH_S2_BOSS: String = "res://audio/music/stratum2/mus-boss-stratum2.ogg"
const STREAM_PATH_S2_AMBIENT: String = "res://audio/ambient/stratum2/amb-stratum2-room.ogg"

## Default fade durations per `audio-direction.md §3 ducking rule 4`.
const DEFAULT_FADE_IN_MS: int = 600
const DEFAULT_FADE_OUT_MS: int = 600
const DEFAULT_CROSSFADE_MS: int = 600

## Silence floor (dB) for fade-out. -80 dB is effectively inaudible; we never
## tween to -INF because Tween cannot interpolate to it.
const SILENCE_DB: float = -80.0

## Bus volume at full-target — the bus's own offset (BGM = -12 dB etc.) is
## applied on top of this, so we keep player nodes at 0 dB at peak.
const FULL_DB: float = 0.0

# ---- Runtime ----------------------------------------------------------

var _bgm_player: AudioStreamPlayer = null
var _bgm_crossfade_player: AudioStreamPlayer = null
var _ambient_player: AudioStreamPlayer = null

# Active fade tweens — kept so a new transition can kill the in-flight tween
# without orphan-tween leakage.
var _bgm_fade_tween: Tween = null
var _bgm_crossfade_tween: Tween = null
var _ambient_fade_tween: Tween = null

# Cached streams. Loaded once on first use; the stream object is shared
# between cues since `AudioStreamPlayer` doesn't mutate it.
var _stream_s2_bgm: AudioStream = null
var _stream_s2_boss: AudioStream = null
var _stream_s2_ambient: AudioStream = null

# Stable trace flag so we don't spam DevTools on every play() call when
# there's no actual surface change — set once per logical transition.
var _last_bgm_path: String = ""
var _last_ambient_path: String = ""


func _ready() -> void:
	_build_players()
	# Boot trace — proves the autoload registered + the bus indices resolved.
	# Same pattern as DebugFlags.gd's _ready trace.
	print("[AudioDirector] ready — bgm_bus=%d ambient_bus=%d sfx_bus=%d ui_bus=%d" % [
		AudioServer.get_bus_index(BUS_BGM),
		AudioServer.get_bus_index(BUS_AMBIENT),
		AudioServer.get_bus_index(BUS_SFX),
		AudioServer.get_bus_index(BUS_UI),
	])


# ---- Public API ------------------------------------------------------

## Start S2 BGM with a fade-in on the BGM bus. Idempotent: if S2 BGM is
## already the active stream, this is a no-op.
func play_stratum2_bgm(fade_in_ms: int = DEFAULT_FADE_IN_MS) -> void:
	if _last_bgm_path == STREAM_PATH_S2_BGM and _bgm_player != null and _bgm_player.playing:
		return
	var stream: AudioStream = _get_stream_s2_bgm()
	if stream == null:
		return
	_play_with_fade_in(_bgm_player, stream, fade_in_ms)
	_last_bgm_path = STREAM_PATH_S2_BGM
	_combat_trace("AudioDirector.play_stratum2_bgm",
		"stream=%s fade_in_ms=%d" % [STREAM_PATH_S2_BGM, fade_in_ms])


## Start S2 Ambient with a fade-in on the Ambient bus. Idempotent.
func play_stratum2_ambient(fade_in_ms: int = DEFAULT_FADE_IN_MS) -> void:
	if _last_ambient_path == STREAM_PATH_S2_AMBIENT and _ambient_player != null and _ambient_player.playing:
		return
	var stream: AudioStream = _get_stream_s2_ambient()
	if stream == null:
		return
	_play_with_fade_in_ambient(_ambient_player, stream, fade_in_ms)
	_last_ambient_path = STREAM_PATH_S2_AMBIENT
	_combat_trace("AudioDirector.play_stratum2_ambient",
		"stream=%s fade_in_ms=%d" % [STREAM_PATH_S2_AMBIENT, fade_in_ms])


## Convenience: fire the full S1→S2 transition (BGM + Ambient) in one call.
## This is the canonical Main.gd / DescendScreen entry-point.
func play_stratum2_entry() -> void:
	play_stratum2_bgm()
	play_stratum2_ambient()


## Crossfade BGM from whatever's currently playing to `mus-boss-stratum2`
## over `fade_ms`. The outgoing player fades to silence, the incoming
## (crossfade) player fades up — at the end they swap roles so future calls
## continue to operate on `_bgm_player`.
##
## Honors Uma's UNIQUE boss-music decision (`team/DECISIONS.md` 2026-05-15) —
## this targets `mus-boss-stratum2.ogg`, not the S1 boss music.
func crossfade_to_boss_stratum2(fade_ms: int = DEFAULT_CROSSFADE_MS) -> void:
	if _last_bgm_path == STREAM_PATH_S2_BOSS and _bgm_player != null and _bgm_player.playing:
		return
	var stream: AudioStream = _get_stream_s2_boss()
	if stream == null:
		return
	_crossfade_bgm(stream, fade_ms)
	_last_bgm_path = STREAM_PATH_S2_BOSS
	_combat_trace("AudioDirector.crossfade_to_boss_stratum2",
		"stream=%s fade_ms=%d" % [STREAM_PATH_S2_BOSS, fade_ms])


## Stop ALL global music + ambient with a fade-out. Used by player-death
## (Beat A: BGM hard-mutes) and any future "leave to title" path.
func stop_all_music(fade_out_ms: int = DEFAULT_FADE_OUT_MS) -> void:
	if _bgm_player != null and _bgm_player.playing:
		_fade_out_and_stop(_bgm_player, fade_out_ms)
	if _bgm_crossfade_player != null and _bgm_crossfade_player.playing:
		_fade_out_and_stop(_bgm_crossfade_player, fade_out_ms)
	if _ambient_player != null and _ambient_player.playing:
		_fade_out_and_stop(_ambient_player, fade_out_ms)
	_last_bgm_path = ""
	_last_ambient_path = ""


# ---- Test surface ----------------------------------------------------

## Returns the BGM AudioStreamPlayer. Used by paired tests to assert which
## stream is playing on which bus without find_child traversal.
func get_bgm_player() -> AudioStreamPlayer:
	return _bgm_player


## Returns the Ambient AudioStreamPlayer.
func get_ambient_player() -> AudioStreamPlayer:
	return _ambient_player


## Returns the BGM crossfade companion player.
func get_bgm_crossfade_player() -> AudioStreamPlayer:
	return _bgm_crossfade_player


## Returns the resource path of the last BGM stream we kicked off. Empty
## string before the first call. Useful for the integration test's "did
## the S2 trigger actually fire?" assertion.
func get_last_bgm_path() -> String:
	return _last_bgm_path


func get_last_ambient_path() -> String:
	return _last_ambient_path


## Test-only: deterministically tear down the fade tweens + snap each player
## to its target state. Lets tests assert end-state without wall-clock waits.
##
## Crucial subtlety: `Tween.kill()` does NOT fire the tween's `finished`
## signal. The crossfade's role-swap is wired to `finished` (so the canonical
## `_bgm_player` reference points at the new track after the fade). If a
## test kills the crossfade tween without manually triggering the swap, the
## role-swap never happens and the test asserts a stale state. We solve that
## by snapping volumes first, then manually invoking the finalize callback
## if a crossfade tween was in flight — same end-state as letting the tween
## complete naturally, but deterministic for headless tests.
func complete_pending_fades_for_test() -> void:
	var had_crossfade_in_flight: bool = (
		_bgm_crossfade_tween != null and _bgm_crossfade_tween.is_valid()
	)
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	if _bgm_crossfade_tween != null and _bgm_crossfade_tween.is_valid():
		_bgm_crossfade_tween.kill()
	if _ambient_fade_tween != null and _ambient_fade_tween.is_valid():
		_ambient_fade_tween.kill()
	# Snap volumes to the target before swap so the finalize observes the
	# expected end-state.
	if _bgm_player != null and _bgm_player.playing:
		_bgm_player.volume_db = FULL_DB
	if _ambient_player != null and _ambient_player.playing:
		_ambient_player.volume_db = FULL_DB
	if had_crossfade_in_flight and _bgm_crossfade_player != null \
			and _bgm_crossfade_player.playing:
		_bgm_crossfade_player.volume_db = FULL_DB
		_finalize_crossfade()


# ---- Internal --------------------------------------------------------

func _build_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = String(BUS_BGM)
	_bgm_player.volume_db = SILENCE_DB
	_bgm_player.autoplay = false
	add_child(_bgm_player)

	_bgm_crossfade_player = AudioStreamPlayer.new()
	_bgm_crossfade_player.name = "BgmCrossfadePlayer"
	_bgm_crossfade_player.bus = String(BUS_BGM)
	_bgm_crossfade_player.volume_db = SILENCE_DB
	_bgm_crossfade_player.autoplay = false
	add_child(_bgm_crossfade_player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = String(BUS_AMBIENT)
	_ambient_player.volume_db = SILENCE_DB
	_ambient_player.autoplay = false
	add_child(_ambient_player)


func _get_stream_s2_bgm() -> AudioStream:
	if _stream_s2_bgm == null:
		_stream_s2_bgm = load(STREAM_PATH_S2_BGM) as AudioStream
		if _stream_s2_bgm == null:
			push_warning("[AudioDirector] failed to load %s" % STREAM_PATH_S2_BGM)
			return null
		_set_stream_loop(_stream_s2_bgm, true)
	return _stream_s2_bgm


func _get_stream_s2_boss() -> AudioStream:
	if _stream_s2_boss == null:
		_stream_s2_boss = load(STREAM_PATH_S2_BOSS) as AudioStream
		if _stream_s2_boss == null:
			push_warning("[AudioDirector] failed to load %s" % STREAM_PATH_S2_BOSS)
			return null
		_set_stream_loop(_stream_s2_boss, true)
	return _stream_s2_boss


func _get_stream_s2_ambient() -> AudioStream:
	if _stream_s2_ambient == null:
		_stream_s2_ambient = load(STREAM_PATH_S2_AMBIENT) as AudioStream
		if _stream_s2_ambient == null:
			push_warning("[AudioDirector] failed to load %s" % STREAM_PATH_S2_AMBIENT)
			return null
		_set_stream_loop(_stream_s2_ambient, true)
	return _stream_s2_ambient


## Mark an OGG / WAV stream as looped. Both `AudioStreamOggVorbis` and
## `AudioStreamWAV` expose `loop` (different sub-properties), so we set
## whichever one exists rather than hard-coding the class.
func _set_stream_loop(stream: AudioStream, value: bool) -> void:
	if stream == null:
		return
	# AudioStreamOggVorbis.loop is a bool property.
	if "loop" in stream:
		stream.set("loop", value)


## Fade out the BGM player, fade in the new stream on the crossfade player,
## then swap node roles so the crossfade player becomes the canonical BGM
## player. Net effect: future calls (e.g. another `crossfade_to_*` or
## `stop_all_music`) operate on the right player without ambiguity.
func _crossfade_bgm(new_stream: AudioStream, fade_ms: int) -> void:
	if _bgm_player == null or _bgm_crossfade_player == null:
		return
	# Kill any in-flight fades so we don't double-tween volume.
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	if _bgm_crossfade_tween != null and _bgm_crossfade_tween.is_valid():
		_bgm_crossfade_tween.kill()
	# Start the new track silent on the crossfade player.
	_bgm_crossfade_player.stream = new_stream
	_bgm_crossfade_player.volume_db = SILENCE_DB
	_bgm_crossfade_player.play()
	# Tween both volumes in parallel.
	var duration_sec: float = max(fade_ms, 1) / 1000.0
	_bgm_crossfade_tween = create_tween()
	_bgm_crossfade_tween.set_parallel(true)
	_bgm_crossfade_tween.tween_property(_bgm_crossfade_player, "volume_db", FULL_DB, duration_sec)
	_bgm_crossfade_tween.tween_property(_bgm_player, "volume_db", SILENCE_DB, duration_sec)
	# After fade completes, swap so _bgm_player owns the new track. We bind
	# the swap as a deferred call so the tween's "finished" callback runs
	# off the property update path.
	_bgm_crossfade_tween.finished.connect(_finalize_crossfade)


func _finalize_crossfade() -> void:
	if _bgm_player == null or _bgm_crossfade_player == null:
		return
	# Stop the old (now-silent) BGM player.
	if _bgm_player.playing:
		_bgm_player.stop()
	# Swap roles by exchanging the variable references — both players sit on
	# the same bus and are functionally interchangeable, so a name/role swap
	# avoids re-instantiating the streams.
	var tmp: AudioStreamPlayer = _bgm_player
	_bgm_player = _bgm_crossfade_player
	_bgm_crossfade_player = tmp
	# Re-prep the (now idle) crossfade player.
	_bgm_crossfade_player.volume_db = SILENCE_DB


func _play_with_fade_in(player: AudioStreamPlayer, stream: AudioStream, fade_ms: int) -> void:
	if player == null or stream == null:
		return
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	player.stream = stream
	player.volume_db = SILENCE_DB
	player.play()
	var duration_sec: float = max(fade_ms, 1) / 1000.0
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(player, "volume_db", FULL_DB, duration_sec)


# Ambient has its own tween slot so a BGM transition doesn't kill an in-flight
# ambient fade.
func _play_with_fade_in_ambient(player: AudioStreamPlayer, stream: AudioStream, fade_ms: int) -> void:
	if player == null or stream == null:
		return
	if _ambient_fade_tween != null and _ambient_fade_tween.is_valid():
		_ambient_fade_tween.kill()
	player.stream = stream
	player.volume_db = SILENCE_DB
	player.play()
	var duration_sec: float = max(fade_ms, 1) / 1000.0
	_ambient_fade_tween = create_tween()
	_ambient_fade_tween.tween_property(player, "volume_db", FULL_DB, duration_sec)


func _fade_out_and_stop(player: AudioStreamPlayer, fade_ms: int) -> void:
	if player == null:
		return
	var duration_sec: float = max(fade_ms, 1) / 1000.0
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", SILENCE_DB, duration_sec)
	tween.finished.connect(func() -> void:
		if player != null and player.playing:
			player.stop()
	)


# ---- Diagnostics -----------------------------------------------------

## Routes through DebugFlags.combat_trace (HTML5-only) so Sponsor's DevTools
## console (and the Playwright harness) can confirm S2 audio triggers
## actually fired. Same pattern as `Stratum1BossRoom._combat_trace`.
func _combat_trace(tag: String, msg: String = "") -> void:
	if not is_inside_tree():
		return
	var df: Node = get_tree().root.get_node_or_null("DebugFlags")
	if df != null and df.has_method("combat_trace"):
		df.combat_trace(tag, msg)
