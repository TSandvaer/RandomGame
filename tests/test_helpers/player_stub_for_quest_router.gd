extends Node
## Player-shaped stub for `tests/test_quest_action_router_persists.gd`.
##
## Bare `Node.new()` does NOT accept dynamic property assignment via
## `Object.set("active_bounty", value)` — Godot 4 silently drops the call
## when the property isn't declared on the script. That bit the W2-T6
## persistence tests at PR #352 commit `495070b`: every router write to
## `player.set("active_bounty", qs)` was a no-op, every read returned
## `null`, every assertion failed.
##
## This stub declares the two fields the QuestActionRouter persistence
## layer reads + writes (`active_bounty: Variant`, `completed_bounties:
## Array`), so `Object.set/get` resolves to the declared properties and
## the persistence path works as in production.
##
## Match Player.gd's field shape so the stub stays drop-in-replaceable:
##   - `active_bounty: Variant = null` — null when no bounty active, else a
##     `QuestState` instance. Matches `scripts/player/Player.gd:408`.
##   - `completed_bounties: Array = []` — append-on-complete, never cleared.
##     Matches Player.gd's same-name field.
##
## Add the stub to the `&"player"` group so QuestActionRouter._player_node()
## resolves it via `get_nodes_in_group("player")` per the router's defensive
## resolution (no autoload coupling to a specific Player instance).

var active_bounty: Variant = null
var completed_bounties: Array = []
