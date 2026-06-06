# Charger (S1 Bone-Hound v3-clean) — PixelLab folder → semantic name reverse-map

Replaces the prior humanoid bear-template art (`Charger_S1_Embergrave/`, M3W-3 / PR #275 +
PR #411). The charger is now a **skeletal bone-hound** per the Sponsor-locked look
(2026-06-05): clean bleached skeleton, no head/mane flames. The "ember-coal-in-ribcage" tell
is added in-engine as an additive-blend `Sprite2D` child on `Charger.tscn`, NOT painted
per-frame (see § Ember below).

`metadata.json` (committed sibling) is the authoritative record of the PixelLab template +
UUID provenance, byte-identical to the bone-hound ZIP root; this map exists for
grep-from-game-state-name discovery.

## Reverse-map

Original PixelLab character_id: `80d0db8c-c8bc-43f5-a6e4-d1b2af3359b3`
Group name: `S1 Charger Bone-Hound v3-clean`
Body type: quadruped (pro mode — v3 is humanoid-only; pro is the quadruped highest-quality floor)
Canvas: 124×124
Generated: 2026-06-06 (re-gen + animate by orchestrator; install ticket `86ca5a5wa`)

Folders live under `S1_charger_bone-hound_v3clean/S1_Charger_Bone-Hound_v3-clean/animations/`.

| Semantic name | PixelLab native folder | frames/dir | loop | game-state driver |
|---|---|---|---|---|
| `walk/` | `walking-6872b923/` | 6 | yes | SPOTTED / CHARGING → `walk_<dir>` |
| `telegraph/` | `running-993321cc/` | 6 | no | TELEGRAPHING → `telegraph_<dir>` (charge windup) |
| `atk/` | `barking-5818024d/` | 6 | no | RECOVERING → `atk_<dir>` (lunge/bite follow-through) |
| `die/` | `collapsing_and_falling_over_dead_onto_its_side_leg-55e75631/` | 9 | no | `_die` → `die_<dir>` |
| `idle/` | `animation-686d93ce/` | 8 | — | **UNWIRED** — see below |

## Rig→game-anim mapping rationale (dispatch brief)

- `running` → **telegraph**: the rig's fast 4-leg gait reads as the charge windup / build-up.
- `barking` → **atk**: the lunge/bite/bark is the contact-attack + recovery follow-through.
- `collapsing-falling-dead` → **die**: 9-frame collapse onto its side.

## NO `hit` animation — quadruped rig constraint

The bone-hound rig (like the prior bear template) ships no take-a-hit / flinch animation.
Per the M3W-3 contract, post-`take_damage` hit feedback is preserved entirely via the
modulate path of the 3-branch hit-flash resolver — `Charger.gd._play_hit_flash` lands on the
`_hit_flash_uses_animated_sprite` branch and tweens `AnimatedSprite2D.modulate`
rest → `HIT_FLASH_TINT` → rest (soft red wash). The state machine never calls
`play("hit_<dir>")` because the SpriteFrames resource has no `hit_*` keys; the script skips
the call explicitly so the trace doesn't emit a `MISS anim=hit_<dir>` line every hit. Pinned
by `tests/test_charger_animation_wire.gd::test_sprite_frames_has_no_hit_keys`.

## `idle` intentionally NOT wired

The contract is `{walk, telegraph, atk, die}` only. `Charger._set_state` STATE_IDLE triggers
no anim; production `.tscn`-loaded chargers hold `walk_s` as a stand-still pose (scene-author
default on the `Sprite` node, `animation = &"walk_s"`). The `idle/` rig frames are kept on
disk for possible future use but are NOT referenced by `Charger.tres` — wiring them would add
a contract key the wire test does not expect.

## Animation key convention in `.tres`

`<state>_<dir>` where dir ∈ {`n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw`}. PixelLab folder →
suffix: `south`→`s`, `south-east`→`se`, `east`→`e`, `north-east`→`ne`, `north`→`n`,
`north-west`→`nw`, `west`→`w`, `south-west`→`sw`.

SpriteFrames key set: `walk_<dir>`, `telegraph_<dir>`, `atk_<dir>`, `die_<dir>` × 8 dirs =
**32 anims**. FPS=8 across all; `walk_*` loop=true (sustained gait), rest loop=false
(one-shot beats). Frame totals: walk 48, telegraph 48, atk 48, die 72 = 216 frames.

## Ember (ribcage coal tell)

Added as `RibcageEmber` — an additive-blend `Sprite2D` child of `Charger.tscn` with a subtle
alpha pulse driven from `Charger.gd`. NOT a `PointLight2D` (HTML5 `gl_compatibility` light
quirks per `.claude/docs/html5-export.md`), NOT a per-frame paint. Sub-1.0 modulate channels
for HDR-clamp safety. Independent of the hit-flash modulate path (separate node, no shared
modulate target).

## Size note

124×124 quadruped canvas (vs the prior humanoid ~68×68). Renders larger / wider than the old
charger — no scale-edit applied (grunt #411 precedent: accepted as-is). Flagged for Sponsor
soak.
