class_name Stoker
extends Grunt
## S2 Stoker mob — Grunt-retint per M3W-6 (Path A pre-bake palette swap).
##
## ## What this is
##
## Per `team/DECISIONS.md` 2026-05-18 + `team/uma-ux/palette-stratum-2.md
## §5` line 191 + `team/priya-pl/m3-scene-wiring-scope.md §M3W-6`, the
## Stoker ships in M3 Tier 1 as a **palette-swap retint of the Grunt v2
## silhouette**. Mechanism: Path A (pre-bake separate atlas) — selected
## over Path B (shader, WebGL2 risk) and Path C (modulate, multi-channel
## source fails) by the parallel Uma+Devon dispatch (PR #268).
##
## ## Behavioral parity
##
## Stoker inherits Grunt's AI verbatim:
##   - IDLE → CHASING → TELEGRAPHING_LIGHT → ATTACKING → RECOVERING loop.
##   - HEAVY telegraph at ≤30% HP (one-shot per life).
##   - Same hit-flash 3-branch resolver, same death pipeline, same
##     physics-flush-safe Hitbox encapsulation.
##
## All the inherited surfaces use `get_node("Sprite")` for the
## AnimatedSprite2D, so swapping the SpriteFrames resource on the .tscn's
## `Sprite` child to `Stoker.tres` is the only sprite-side change required.
## The `class_name Stoker` exists so:
##   - Scenes / MobDefs / tests can type against `Stoker` distinctly.
##   - Future Stoker-specific divergences (Phase 2 miner-cap silhouette,
##     S2-only behavior tweaks) have an obvious extension surface.
##
## ## Phase-2 follow-up
##
## When the miner-cap silhouette + torn-smock authoring lands (Phase 2,
## backlog per `team/DECISIONS.md` 2026-05-18 + ticket `86c9uze5j`),
## update `assets/sprites/stoker/Stoker.tres` to reference the new atlas
## and (if behavioral divergence is needed) override AI hooks here. The
## class hierarchy + scene layout are designed to absorb that change with
## minimal surface area.
