class_name StatStrings
extends Resource
## Designer-authored UI string table for the level-up panel + inventory
## stat-allocation mirror. Per Uma's `team/uma-ux/level-up-panel.md`
## §"Tooltip language standard" — the canonical 12 strings live here so M2
## localisation is a one-file swap and microcopy revisions don't require
## scene-edits.
##
## **Why a Resource (not a CSV / JSON)**: editor-inspectable, pre-imported
## by Godot at build time, no runtime parse cost, autoload-free. Matches
## the rest of Drew's content schema (MobDef / ItemDef / etc).
##
## **The 12 canonical strings** (Uma `level-up-panel.md` §"Tooltip language
## standard"):
##
## | Block               | Keys                                               |
## |---------------------|----------------------------------------------------|
## | Stat tooltips (3x4) | header, sub_header, body, flavor — one each for V/F/E |
##
## Each stat tooltip is 4 strings; 3 stats * 4 = 12. The other strings Uma
## documents (level_up_header, points_banked_toast, hud_pip_tooltip, etc.)
## live on the panel scenes that consume them — those are control-copy, not
## tooltip-copy, and changing them rarely. The 12 here are the load-bearing
## tooltip-language set per the level-up-panel spec hand-off.
##
## **Tone notes** (Uma):
##   - Second person. Always *you*. Never *the player*.
##   - Adventurous, not sterile.
##   - One vibe sub-header per stat. Three words, lowercase, dot-separated.
##   - Numerics in affix-style: `+5 max HP per point`. Always per-point.
##   - Flavor line is 1-2 lines max.
##   - No game-design jargon.
##
## **Resource lookup pattern** (used by `StatAllocationPanel.gd`):
##
##   var ss: StatStrings = load("res://content/ui/stat_strings.tres")
##   ss.get_header(&"vigor")     # "VIGOR"
##   ss.get_sub_header(&"vigor") # "toughness · health pool · stamina"
##   ss.get_body(&"vigor")       # "+5 max HP per point\n+1 HP regen / 10 s per point"
##   ss.get_flavor(&"vigor")     # "Vigor is what stands between you and..."

# ---- Vigor (toughness · health pool · stamina) ------------------------

@export var vigor_header: String = "VIGOR"
@export var vigor_sub_header: String = "toughness · health pool · stamina"
@export_multiline var vigor_body: String = (
	"+5 max HP per point\n"
	+ "+1 HP regen / 10 s per point"
)
@export_multiline var vigor_flavor: String = (
	"\"Vigor is what stands between you and the next bell. "
	+ "Stack it when the floor bites.\""
)

# ---- Focus (dodge · cooldowns · steady hands) -------------------------

@export var focus_header: String = "FOCUS"
@export var focus_sub_header: String = "dodge · cooldowns · steady hands"
@export_multiline var focus_body: String = (
	"+0.02 s dodge i-frame per point\n"
	+ "-1% ability cooldown per point"
)
@export_multiline var focus_flavor: String = (
	"\"Focus narrows the world to the next strike. "
	+ "The flame burns truer for it.\""
)

# ---- Edge (damage · crit · bite) --------------------------------------

@export var edge_header: String = "EDGE"
@export var edge_sub_header: String = "damage · crit · bite"
@export_multiline var edge_body: String = (
	"+1 damage per point\n"
	+ "+1% crit chance per point"
)
@export_multiline var edge_flavor: String = (
	"\"Edge is the cruelty in your swing. "
	+ "Sharper, faster, more often.\""
)


# ---- Lookup API -------------------------------------------------------
# StatAllocationPanel.gd resolves stat-id -> string via these accessors so
# the panel scene doesn't have to inline the @export property names.

## Returns the stat header (caps: VIGOR / FOCUS / EDGE) for the given stat.
## Unknown stat id returns "".
func get_header(stat_id: StringName) -> String:
	match stat_id:
		&"vigor":
			return vigor_header
		&"focus":
			return focus_header
		&"edge":
			return edge_header
		_:
			return ""


## Returns the sub-header vibe phrase. Unknown stat id returns "".
func get_sub_header(stat_id: StringName) -> String:
	match stat_id:
		&"vigor":
			return vigor_sub_header
		&"focus":
			return focus_sub_header
		&"edge":
			return edge_sub_header
		_:
			return ""


## Returns the multi-line numeric body. Unknown stat id returns "".
func get_body(stat_id: StringName) -> String:
	match stat_id:
		&"vigor":
			return vigor_body
		&"focus":
			return focus_body
		&"edge":
			return edge_body
		_:
			return ""


## Returns the flavor quote. Unknown stat id returns "".
func get_flavor(stat_id: StringName) -> String:
	match stat_id:
		&"vigor":
			return vigor_flavor
		&"focus":
			return focus_flavor
		&"edge":
			return edge_flavor
		_:
			return ""


## Returns all 12 strings in a flat dict. Used by the
## test_stat_allocation.gd "load 12 strings" assertion.
func to_dict() -> Dictionary:
	return {
		"vigor_header": vigor_header,
		"vigor_sub_header": vigor_sub_header,
		"vigor_body": vigor_body,
		"vigor_flavor": vigor_flavor,
		"focus_header": focus_header,
		"focus_sub_header": focus_sub_header,
		"focus_body": focus_body,
		"focus_flavor": focus_flavor,
		"edge_header": edge_header,
		"edge_sub_header": edge_sub_header,
		"edge_body": edge_body,
		"edge_flavor": edge_flavor,
	}
