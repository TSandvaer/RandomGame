class_name LevelChunkDef
extends Resource
## A hand-authored room chunk. The smallest unit the level assembler can
## place. M1 ships exactly one — the stratum-1 first room (`s1_room01`) —
## but the schema is forward-extensible to many chunks per stratum.
##
## A chunk declares:
##   - its grid size (in 32 px internal tiles per Uma's visual-direction.md),
##   - the path to a `.tscn` containing the actual TileMap + decorations,
##   - entry/exit ports for the assembler to stitch against,
##   - mob spawn points (mobs referenced by id, resolved by the MobRegistry).
##
## Per Uma's visual direction lock (DECISIONS.md 2026-05-02):
##   - 32 px internal tiles, 480x270 internal canvas → 15x8.4 tiles fit one
##     screen. M1 chunks are sized to fit the screen exactly (15x8 or
##     similar) so the camera doesn't have to scroll yet.
##
## Per Devon's project-layout (DECISIONS.md 2026-05-01):
##   - Chunk scenes live under `scenes/levels/chunks/`; chunk defs under
##     `resources/level_chunks/`.

## Stable identifier (snake_case, unique). Used by the assembler and by
## save files (so a player respawning re-enters a known chunk).
@export var id: StringName = &""

## Player-visible name (for debug UI / loot logs). en-source for M1.
@export var display_name: String = ""

## Grid size in tiles (NOT pixels). 480/32 = 15 wide, 270/32 ≈ 8.43 high
## per Uma's canvas spec, so a single-screen chunk is ~15x8 tiles.
@export var size_tiles: Vector2i = Vector2i(15, 8)

## Internal tile size in pixels. Locked at 32 per Uma's visual-direction
## lock; exported so M2 strata can experiment with bigger rooms (e.g. a
## 64 px boss room) without changing every chunk.
@export var tile_size_px: int = 32

## Path to the `.tscn` containing the actual chunk geometry (TileMap node
## or composed sprites). The assembler instantiates this and parents it
## under the room root, offset by chunk placement.
@export_file("*.tscn") var scene_path: String = ""

## Entry/exit ports on the chunk's edges. M1 first room gets one entry
## (player spawn) and zero exits (single-screen room). M2 multi-chunk
## strata grow this list.
@export var ports: Array[ChunkPort] = []

## Mob spawn points inside this chunk. Each carries a `mob_id` resolved
## against the MobRegistry. Empty for purely decorative / boss-room chunks.
@export var mob_spawns: Array[MobSpawnPoint] = []


# ---- Convenience helpers ---------------------------------------------

## Returns the chunk's pixel size (size_tiles * tile_size_px).
func size_px() -> Vector2i:
	return size_tiles * tile_size_px


## True iff `tile_pos` is inside this chunk's grid bounds.
func contains_tile(tile_pos: Vector2i) -> bool:
	return (
		tile_pos.x >= 0 and tile_pos.x < size_tiles.x
		and tile_pos.y >= 0 and tile_pos.y < size_tiles.y
	)


## Returns ports matching `tag`. Empty array if none.
func ports_with_tag(want: StringName) -> Array[ChunkPort]:
	var out: Array[ChunkPort] = []
	for p: ChunkPort in ports:
		if p.tag == want:
			out.append(p)
	return out


## Returns the player-spawn port (tag = &"entry"). Null if none.
func get_entry_port() -> ChunkPort:
	var entries: Array[ChunkPort] = ports_with_tag(&"entry")
	if entries.is_empty():
		return null
	return entries[0]


## Validate the chunk's mob spawns are inside the grid. Returns an array
## of error strings (empty = valid). Used by tests + editor lint.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("LevelChunkDef.id must be non-empty")
	if size_tiles.x <= 0 or size_tiles.y <= 0:
		errors.append("LevelChunkDef.size_tiles must be positive: got %s" % str(size_tiles))
	for ms: MobSpawnPoint in mob_spawns:
		if not contains_tile(ms.position_tiles):
			errors.append(
				"MobSpawnPoint at %s outside chunk bounds %s" % [str(ms.position_tiles), str(size_tiles)]
			)
		if ms.mob_id == &"":
			errors.append("MobSpawnPoint has empty mob_id at %s" % str(ms.position_tiles))
	for p: ChunkPort in ports:
		if not contains_tile(p.position_tiles):
			errors.append(
				"ChunkPort at %s outside chunk bounds %s" % [str(p.position_tiles), str(size_tiles)]
			)
	return errors
