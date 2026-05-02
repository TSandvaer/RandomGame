class_name ChunkPort
extends Resource
## A connection point on a chunk edge — used by the assembler to stitch
## chunks together. M1 only ever needs one chunk so the assembler is
## largely a no-op, but the data shape is forward-extensible: M2's
## procedural assembler picks chunks whose `tag` and `direction` match.
##
## A chunk's "entry" port is where the player enters it; an "exit" port is
## where they leave. Stairs to the next stratum are a special exit port
## with `tag = &"stratum_descent"`.

enum Direction { NORTH, EAST, SOUTH, WEST }

## Position of the port in tile coordinates, on the chunk's local edge.
@export var position_tiles: Vector2i = Vector2i.ZERO

## Which edge of the chunk this port sits on. Determines which ports it
## can mate with (north mates south, east mates west).
@export var direction: Direction = Direction.NORTH

## Free-form tag for assembler matching.
##   &"entry"           — player spawn on first room of a stratum.
##   &"exit"            — generic transition to another chunk.
##   &"stratum_descent" — stairs to the next stratum (M2 boss room only).
##   &"locked"          — assembler must not place a neighbour here in M1.
@export var tag: StringName = &"exit"
