class_name MobDef
extends Resource
## Designer-authored mob template. Immutable at runtime — `Grunt`
## (or any future mob script) reads these stats once at spawn and tracks
## current state on the node. See `team/drew-dev/tres-schemas.md`.

## Stable identifier. Snake_case, unique across all MobDefs. Used as save-file
## key and content lookup. Never localize, never change after a mob ships.
@export var id: StringName = &""

## Player-visible name. Localized later via Godot tr() — keep en-source here
## for M1.
@export var display_name: String = ""

## res:// path to the sprite sheet (PNG). For M1 a single idle frame is fine;
## animations come in M2 with AnimatedSprite2D and a SpriteFrames sub-resource.
## Empty string is allowed (M1 can use a ColorRect placeholder).
@export var sprite_path: String = ""

## --- Combat stats ---
## Stratum scaling multipliers live elsewhere (StratumDef in M2); for M1 these
## are the literal HP/damage the mob spawns with.
@export_range(1, 9999, 1) var hp_base: int = 50
@export_range(0, 999, 1) var damage_base: int = 5

## Pixels per second. Player walks ~120 px/s (Devon's Player.gd) as reference.
@export_range(0.0, 500.0, 1.0) var move_speed: float = 60.0

## --- AI ---
## Drives which AI behavior the spawner attaches. M1 supports:
##   &"melee_chaser"  — walk toward player, swing on contact, telegraph heavy
##                      below 30% HP. Used by Grunt.
##   &"ranged_kiter"  — M2
##   &"charger"       — M2
@export var ai_behavior_tag: StringName = &"melee_chaser"

## --- Drops ---
## Loot table. Nullable — mobs without drops (e.g. M2 hand-placed bosses)
## can leave this empty.
@export var loot_table: LootTableDef

## --- Progression ---
@export_range(0, 9999, 1) var xp_reward: int = 10
