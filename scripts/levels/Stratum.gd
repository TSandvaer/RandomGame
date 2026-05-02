class_name Stratum
extends RefCounted
## Stratum namespace — single source of truth for "which stratum is this?"
## across the codebase. Replaces magic ints / strings scattered through
## chunk ids, scene paths, save keys.
##
## **Why a class instead of an enum-on-an-autoload:**
##   - GDScript class_name members are accessible as `Stratum.S1` from any
##     script that imports the class implicitly (i.e. anywhere in the
##     project), without registering an autoload. Less project.godot churn.
##   - Plain-int enum keeps Save/JSON cheap (StringName-only id round-trips
##     also work but ints are smaller in the save payload).
##   - Static-only — never instantiated. The `RefCounted` base is just so
##     class_name registers cleanly in 4.3.
##
## **Add a new stratum (M2+):**
##   1. Add the entry to the `Id` enum below.
##   2. Add it to `ALL_IDS` and `IDS_TO_NAMES` / `NAMES_TO_IDS`.
##   3. Add a row to the test in `tests/test_stratum_namespace.gd` so the
##      round-trip + listing assertion stays exhaustive.
##   4. (Content side) Place chunk TRES under `resources/level_chunks/sN_*`
##      and authored mob TRES under the layout recommended in
##      `team/drew-dev/level-chunks.md` §"Multi-stratum tooling".
##
## **Conventions:**
##   - `id` is the stable int (1..N). Saves persist this.
##   - `prefix` is the snake-case tag used in chunk ids and resource paths
##     (e.g. `s1`, `s2`). Authoring tools and the chunk loader use this.
##   - `display_name` is en-source. Localisation is M3+ scope.

## Stratum identifiers. Extend by appending — never reorder, since saves
## persist the int value. M1 ships S1 only; the rest of the enum is the
## scaffold M2 implementers fill in (rooms / mobs / palette).
enum Id {
	S1 = 1,
	S2 = 2,
	S3 = 3,
	S4 = 4,
	S5 = 5,
	S6 = 6,
	S7 = 7,
	S8 = 8,
}

## Authoring/runtime prefix for a stratum. Used to namespace chunk ids
## (`s1_room01`, `s2_room01`, ...) and resource paths
## (`resources/level_chunks/s1_*`, `resources/mobs/s2/*`).
const PREFIX_S1: StringName = &"s1"
const PREFIX_S2: StringName = &"s2"
const PREFIX_S3: StringName = &"s3"
const PREFIX_S4: StringName = &"s4"
const PREFIX_S5: StringName = &"s5"
const PREFIX_S6: StringName = &"s6"
const PREFIX_S7: StringName = &"s7"
const PREFIX_S8: StringName = &"s8"

## Order matters: this is the canonical descent order in M1+M2. Tests use
## this to assert that "next stratum" is well-defined. Append-only.
const ALL_IDS: Array[int] = [
	Id.S1,
	Id.S2,
	Id.S3,
	Id.S4,
	Id.S5,
	Id.S6,
	Id.S7,
	Id.S8,
]

# ---- Public API -------------------------------------------------------

## Returns true iff `id` is a registered stratum. Use to validate save
## payloads + chunk-id parses without hardcoding the bounds.
static func is_known(id: int) -> bool:
	return id in ALL_IDS


## Returns the snake-case prefix for `id` (`"s1"` etc). Empty string for
## unknown ids (callers should `is_known` first if they care).
static func prefix(id: int) -> StringName:
	match id:
		Id.S1: return PREFIX_S1
		Id.S2: return PREFIX_S2
		Id.S3: return PREFIX_S3
		Id.S4: return PREFIX_S4
		Id.S5: return PREFIX_S5
		Id.S6: return PREFIX_S6
		Id.S7: return PREFIX_S7
		Id.S8: return PREFIX_S8
	return &""


## Inverse of `prefix`. Returns 0 (an unknown id; never == Id.S1) for
## strings that don't map to a registered stratum. Tolerant of leading
## whitespace + case.
static func id_from_prefix(p: StringName) -> int:
	match p:
		PREFIX_S1: return Id.S1
		PREFIX_S2: return Id.S2
		PREFIX_S3: return Id.S3
		PREFIX_S4: return Id.S4
		PREFIX_S5: return Id.S5
		PREFIX_S6: return Id.S6
		PREFIX_S7: return Id.S7
		PREFIX_S8: return Id.S8
	return 0


## Display name for `id`. en-source; localisation is M3+ scope.
static func display_name(id: int) -> String:
	match id:
		Id.S1: return "Stratum 1"
		Id.S2: return "Stratum 2"
		Id.S3: return "Stratum 3"
		Id.S4: return "Stratum 4"
		Id.S5: return "Stratum 5"
		Id.S6: return "Stratum 6"
		Id.S7: return "Stratum 7"
		Id.S8: return "Stratum 8"
	return ""


## Next stratum after `id`, by descent order. Returns 0 if `id` is the
## last known stratum (or unknown). Useful for the descent-portal flow:
## `next_id = Stratum.next(current)` then early-return on 0.
static func next(id: int) -> int:
	var idx: int = ALL_IDS.find(id)
	if idx < 0 or idx >= ALL_IDS.size() - 1:
		return 0
	return ALL_IDS[idx + 1]


## Parse a stratum id out of a chunk identifier of the form `sN_roomMM`.
## Returns 0 for malformed ids. Used by the chunk loader to route a chunk
## id back to its owning stratum without a full path scan.
##
## Examples:
##   `Stratum.id_from_chunk_id(&"s1_room01")` -> 1
##   `Stratum.id_from_chunk_id(&"s2_boss")`   -> 2
##   `Stratum.id_from_chunk_id(&"foo")`       -> 0
static func id_from_chunk_id(chunk_id: StringName) -> int:
	var s: String = String(chunk_id)
	var underscore: int = s.find("_")
	if underscore <= 0:
		return 0
	var prefix_part: String = s.substr(0, underscore)
	return id_from_prefix(StringName(prefix_part))
