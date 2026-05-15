extends GutTest
## Audio bus baseline smoke — W3-T9 (`86c9uf6hh`).
##
## Asserts the `default_bus_layout.tres` registered via
## `project.godot::audio/buses/default_bus_layout` produces the 5-bus
## structure spec'd in `team/uma-ux/audio-direction.md` §3 — including the
## dB targets, the Master parent relationship, and the canonical bus order.
##
## **Regression guard** (per Priya's PR #216 "regression-test contract"):
## This is the regression test for "Devon's audio bus baseline didn't ship"
## — if some future PR drops the bus layout file or renames a bus, every
## `AudioStreamPlayer.bus = "BGM"` setter in the codebase silently routes
## to "Master" (Godot's fallback) and the dB attenuations vanish. The
## tester checklist AD-11 / AD-12 (BGM ducking) becomes impossible to
## verify. This test catches that regression at CI time.

const BUS_MASTER: String = "Master"
const BUS_BGM: String = "BGM"
const BUS_AMBIENT: String = "Ambient"
const BUS_SFX: String = "SFX"
const BUS_UI: String = "UI"

## Tolerance for dB float equality — Godot stores volume_db as float and the
## .tres round-trip can introduce <0.01 dB drift on some platforms.
const DB_EPSILON: float = 0.01


# ---- Bus existence ---------------------------------------------------

func test_all_five_buses_exist_by_name() -> void:
	# Bus indices are -1 when the bus is missing.
	assert_ne(AudioServer.get_bus_index(BUS_MASTER), -1,
		"Master bus must exist (default_bus_layout.tres)")
	assert_ne(AudioServer.get_bus_index(BUS_BGM), -1,
		"BGM bus must exist (per audio-direction.md §3)")
	assert_ne(AudioServer.get_bus_index(BUS_AMBIENT), -1,
		"Ambient bus must exist (per audio-direction.md §3)")
	assert_ne(AudioServer.get_bus_index(BUS_SFX), -1,
		"SFX bus must exist (per audio-direction.md §3)")
	assert_ne(AudioServer.get_bus_index(BUS_UI), -1,
		"UI bus must exist (per audio-direction.md §3)")


func test_master_bus_is_index_zero() -> void:
	# Godot convention: Master is always index 0. If the .tres declares any
	# other bus first, the engine still re-indexes Master to 0 — so this
	# check is belt-and-suspenders against a malformed layout.
	assert_eq(AudioServer.get_bus_index(BUS_MASTER), 0,
		"Master bus must be index 0 (Godot convention)")


# ---- dB targets per audio-direction.md §3 ----------------------------

func test_master_bus_at_zero_db() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_MASTER)
	var db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(db, 0.0, DB_EPSILON,
		"Master bus must be 0 dB (final output reference)")


func test_bgm_bus_at_minus_twelve_db() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_BGM)
	var db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(db, -12.0, DB_EPSILON,
		"BGM bus must be -12 dB (audio-direction.md §3)")


func test_ambient_bus_at_minus_eighteen_db() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_AMBIENT)
	var db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(db, -18.0, DB_EPSILON,
		"Ambient bus must be -18 dB (audio-direction.md §3)")


func test_sfx_bus_at_minus_six_db() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_SFX)
	var db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(db, -6.0, DB_EPSILON,
		"SFX bus must be -6 dB (audio-direction.md §3)")


func test_ui_bus_at_minus_ten_db() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_UI)
	var db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(db, -10.0, DB_EPSILON,
		"UI bus must be -10 dB (audio-direction.md §3)")


# ---- Bus topology (Master parent) ------------------------------------

func test_bgm_sends_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_BGM)
	var send: String = AudioServer.get_bus_send(idx)
	assert_eq(send, BUS_MASTER,
		"BGM bus must send to Master (audio-direction.md §3)")


func test_ambient_sends_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_AMBIENT)
	var send: String = AudioServer.get_bus_send(idx)
	assert_eq(send, BUS_MASTER,
		"Ambient bus must send to Master (audio-direction.md §3)")


func test_sfx_sends_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_SFX)
	var send: String = AudioServer.get_bus_send(idx)
	assert_eq(send, BUS_MASTER,
		"SFX bus must send to Master (audio-direction.md §3)")


func test_ui_sends_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_UI)
	var send: String = AudioServer.get_bus_send(idx)
	assert_eq(send, BUS_MASTER,
		"UI bus must send to Master (audio-direction.md §3)")


# ---- Initial mute / solo state ---------------------------------------

func test_no_bus_is_muted_or_soloed_at_boot() -> void:
	# A boot-time mute or solo means the player never hears the cue chain.
	# Easy regression class — someone toggled a mute in the editor during
	# debugging and forgot to flip it back before commit.
	for name: String in [BUS_MASTER, BUS_BGM, BUS_AMBIENT, BUS_SFX, BUS_UI]:
		var idx: int = AudioServer.get_bus_index(name)
		assert_false(AudioServer.is_bus_mute(idx),
			"%s bus must NOT boot muted (default_bus_layout.tres)" % name)
		assert_false(AudioServer.is_bus_solo(idx),
			"%s bus must NOT boot soloed (default_bus_layout.tres)" % name)
