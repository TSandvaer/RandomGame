# M3 Character Scene-Wiring Scope — PR breakdown

**Owner:** Priya · **Status:** v1.0 — dispatch-ready · **Date:** 2026-05-18

This brief scopes how the **~1680-frame, 9-character M3 wiring effort** (PRs #262–#265 landed the assets; nothing is wired yet) breaks into PRs Devon/Drew can pick up. PixelLab frames sit at `assets/sprites/<char>/_pixellab_anims/` with UUID-laden native folder naming; each character's `metadata.json` is the authoritative folder→animation mapping.

**Key precondition observed during scope:** **no character in the codebase currently uses `AnimatedSprite2D` or `SpriteFrames`.** Every mob + Player scene uses a `ColorRect` placeholder named `"Sprite"` (verified across `Player.tscn`, `Grunt.tscn`, `Charger.tscn`, `Stratum1Boss.tscn`, `Shooter.tscn`, `PracticeDummy.tscn`). The hit-flash plumbing in `Grunt.gd` (lines 187–190, 425–440) explicitly switches between `Sprite.color` tween (ColorRect path) and `self.modulate` tween (Sprite2D path) — so the wiring effort is **net-new infrastructure**, not a sprite-swap on an existing pattern. The first wiring PR must establish the SpriteFrames + AnimatedSprite2D pattern; it will set conventions every subsequent PR follows.

---

## TL;DR (5 lines)

1. **Recommended split: 7 PRs.** One foundation PR (PracticeDummy — smallest surface, validates pattern), then bundled-by-character (Player, S1 mob-trio Grunt/Charger/Shooter, Boss, NPCs ×3, Stoker palette-swap). Boss + Player get their own PRs; everything else bundles.
2. **Ownership rule of thumb:** Devon authors `SpriteFrames.tres` + folder-rename + audio-cue resource wiring; Drew wires `AnimatedSprite2D` into the scene, integrates the state machine, and signs off on visual feel.
3. **Dependency chain:** Foundation (PD) → Player → S1-mob-trio → Boss → NPCs → Stoker palette-swap (depends on Grunt v2 atlas landed). Sponsor-soak gate after Player + after Boss; intermediate PRs ship behind Tess only.
4. **Biggest risk: AnimatedSprite2D + ColorRect-hit-flash interaction.** `Grunt.gd._play_hit_flash` currently tweens `Sprite.color` on a ColorRect; AnimatedSprite2D uses `modulate` instead. **R-WIRE1** (new) — every mob's hit-flash needs the Sprite2D branch path tested in HTML5 before merge.
5. **Total effort estimate: ~22–28 ticks across Devon + Drew in parallel** — roughly one M3 sub-week at W2 pace. Tess load is heavy (every PR is HTML5-visual-verification-gated per `html5-export.md`).

---

## Source of truth — this brief consumes

1. **PRs #262–#265** — landed assets at `assets/sprites/<char>/_pixellab_anims/<NativeFolder>/`. Each has `metadata.json` mapping UUID-suffixed folders → animation IDs (`animating-<uuid>`, `cross_punch_attack-<uuid>`, `walking_menacingly-<uuid>`, etc.).
2. **`.claude/docs/pixellab-pipeline.md` §"Animation frames are only exposed via ZIP download"** — `metadata.json` IS the authoritative folder→animation mapping; PixelLab folder naming is inconsistent across versions (`animating-<uuid>` vs `<template>_<name>-<uuid>`). Cannot parse folder names for semantic intent.
3. **`.claude/docs/pixellab-pipeline.md` §"Template animations can flip character facing direction mid-cycle"** + §"Hand-object continuity NOT preserved"** — known frame-quality risk per character. Drew's parallel spot-check dispatch is the diagnostic; this brief defers per-PR scope to that finding.
4. **`.claude/docs/audio-architecture.md` §"AudioDirector autoload"** + §"HTML5 audio-playback gate"** — audio-cue integration target. SFX bus (`-6 dB`) for attack/hit/die beats; first cue after user gesture (combat input qualifies as gesture).
5. **`.claude/docs/html5-export.md` §"HTML5 visual-verification gate"** — every PR in this scope touches sprite rendering → visual-verification-gated. Screenshots/short clips required in Self-Test Report per Tess.
6. **`team/priya-pl/art-pass-ai-primary-brief.md`** — animation-set-per-character source-of-truth (Player 6, Grunt/Stoker 5, Charger 4, Shooter 5, Boss 7, PD 2, NPCs 1).
7. **`team/DECISIONS.md` 2026-05-18 — Stoker runtime palette-swap** — Stoker reuses Grunt v2's atlas via runtime palette-swap rather than its own generated assets. Mechanism (shader vs `replace_color` per-frame vs indexed-palette swap) is a parallel Uma+Devon dispatch — **referenced not gated**.
8. **Player.gd lines 32–34** — `signal state_changed(from, to)` already exists "useful for animation hooks and tests." Drew's wiring plugs into this signal directly; no Player.gd state-machine refactor needed.
9. **`team/priya-pl/risk-register.md`** — R-WIRE1 (new, this brief), R-WIRE2 (new, folder-rename), R6 (Sponsor-found-bugs) re-armed by every visible visual change.

---

## Architecture decision recommendation (non-binding — Drew/Devon own the tech call)

**AnimatedSprite2D + SpriteFrames** (not AnimationPlayer + Sprite2D + per-frame texture swap). Rationale:

- `SpriteFrames.tres` is a **data resource** Devon can author without scene-graph changes; matches Devon's mechanical/data lane.
- `AnimatedSprite2D.play(anim_name)` is a 1-line Drew change per state-machine transition; matches Drew's wiring lane.
- Multi-direction support (`AnimatedSprite2D.animation = "walk_s"` vs `"walk_n"`) maps cleanly to the 8 PixelLab directions per animation.
- AnimationPlayer is overkill for sprite-frame sequencing; it shines for property tweens (modulate flashes, position bobs) which we already do separately.
- **Hit-flash compatibility:** AnimatedSprite2D uses `self.modulate` (CanvasItem property), so `Grunt.gd._play_hit_flash` falls into its existing Sprite2D branch path (lines 188 `_hit_flash_uses_sprite = false`). The branch already exists; the wiring PRs flip the flag.

If Drew/Devon disagree on the pattern, the foundation PR (M3W-1) is the right place to resolve — its scope is small enough to throw away if the pattern's wrong.

---

## PR breakdown

Seven PRs. Sized S/M/L/XL per `m2-week-3-backlog.md` convention (S = 1–2 ticks, M = 3–5, L = 6–10, XL = 10+).

### M3W-1 — `feat(art|wire): PracticeDummy AnimatedSprite2D foundation — pattern establishes here`

- **Owner:** Devon (SpriteFrames + folder convention) + Drew (AnimatedSprite2D node swap in scene + state machine hook)
- **Size:** **S (1–2 ticks)**
- **Priority:** **P0** — gates every downstream PR
- **Scope:**
  - Devon: author `assets/sprites/practice_dummy/PracticeDummy.tres` (SpriteFrames resource); resolve PD's 2 animations (`hit`, `die`) from `metadata.json` UUID folders; rename folders to semantic names (`hit/`, `die/`) OR document UUID-path convention; commit `metadata.json` as authoritative reverse-mapping.
  - Drew: swap PD's `Sprite` ColorRect for `AnimatedSprite2D` in `PracticeDummy.tscn`; wire `play("hit")` on damage signal, `play("die")` on death tween entry; verify the existing hit-flash + death-tween pipeline still fires correctly with `modulate` (not `Sprite.color`).
  - **Establish conventions in PR body:** SpriteFrames file location, folder-naming choice (rename vs UUID-paths), animation_name keys (`<state>_<direction>` like `walk_s`, `walk_ne`), default-fps choice (PixelLab's 6-frame walks → 8 fps reads cleanly), per-direction loop flag.
- **Acceptance:**
  - PD `.tres` loads in editor; both anims play in AnimatedSprite2D preview.
  - Player swings PD → hit-anim fires; HP ticks → die-anim fires; existing death-tween still completes; PD `queue_free`s on time.
  - Paired GUT test: `tests/test_practice_dummy_animated.gd` — asserts `AnimatedSprite2D.animation == "hit"` mid-damage, `== "die"` post-death-tween.
  - **HTML5 release-build screenshot/clip** in Self-Test Report — PD visible, hit anim plays, die anim plays. Cache-clear ritual per `html5-export.md`.
- **Risks:** R-WIRE1 fires here first (smallest blast radius). If hit-flash modulate path mis-tints the AnimatedSprite2D (e.g. unintended channel multiply), every downstream PR inherits the bug. Devon and Drew should sanity-check `Grunt.gd._play_hit_flash` lines 425–440 pre-merge.
- **Sponsor gate:** None — Tess sign-off only. PD is invisible to most playthroughs.

### M3W-2 — `feat(art|wire): Player — 6-anim wiring (walk, atk-light, atk-heavy, dodge, hit, die)`

- **Owner:** Devon (SpriteFrames + 4-UUID disambiguation) + Drew (`state_changed` signal handler + per-state `play()` call)
- **Size:** **M (3–5 ticks)** — likely the higher end; Player is highest-blast-radius
- **Priority:** **P0** — highest visibility; unlocks Sponsor "squares no longer fight squares" framing per `m3-design-seeds.md §4`
- **Scope:**
  - Devon — **resolve the 4 ambiguous `animating-<uuid>` folders** at `assets/sprites/player/_pixellab_anims/Player_re-queue/animations/`. Method: cross-reference `metadata.json` for each UUID's animation_name parameter (was passed at `animate_character` dispatch time per pixellab-pipeline.md). Frame counts may also disambiguate (walk = 4 or 6 frames; dodge likely 4; hit = 4; die = 6+). If `metadata.json` doesn't surface animation_name semantically, escalate to orchestrator for a Sponsor re-roll vs visual-inspect call — **do not guess**.
  - Devon — author `assets/sprites/player/Player.tres` (SpriteFrames); 6 animations × 8 directions = 48 sub-animations.
  - Devon — name convention: `walk_s`, `walk_sw`, `walk_w`, ..., `walk_se`; same for `atk_light_<dir>`, `atk_heavy_<dir>`, `dodge_<dir>`, `hit_<dir>`, `die_<dir>`.
  - Drew — swap `Player.tscn`'s `Sprite` ColorRect for `AnimatedSprite2D`; subscribe to existing `state_changed` signal (Player.gd:34); map state→anim:
    - `STATE_IDLE` → walk (frame 0 hold) — placeholder until idle anim authored; **no idle anim shipped in #265** — this is a known gap, flag in PR body
    - `STATE_MOVING` → `walk_<facing>`
    - `STATE_SWING_LIGHT` → `atk_light_<facing>`
    - `STATE_SWING_HEAVY` → `atk_heavy_<facing>`
    - `STATE_DODGE` → `dodge_<facing>`
    - On `take_damage` signal → `play("hit_<facing>")` interrupting state anim
    - On `_die` → `play("die_<facing>")`
  - Drew — facing-derivation helper: convert `Player._facing_vec` (or equivalent) → one of 8 cardinal/diagonal direction strings.
  - **No new audio cues land here** — audio integration is a follow-up to keep this PR's blast-radius bounded.
- **Acceptance:**
  - All 6 animations play in editor preview, all 8 directions per anim.
  - State-machine transitions visibly play the correct animation (Drew's Self-Test Report video required — 8-direction walk + light atk + heavy atk + dodge + hit + die loop, ~30s clip).
  - Paired GUT test: `tests/test_player_animation_wire.gd` — asserts `AnimatedSprite2D.animation` updates on `state_changed` signal.
  - Mouse-direction attacks (PR #255) still aim at cursor; animation facing matches.
  - **HTML5 release-build full soak (Player walks all 8 directions + attacks + dodges + dies)** — per `html5-export.md` visual-verification gate.
  - **Doctrine-exempt check passes:** Player palette is the PixelLab-natural purple/blue per `pixellab-pipeline.md §"Doctrine-lock is per-character"`. **No doctrine-lock retroactive on the SpriteFrames data** — frames ship as exported.
- **Risks:**
  - **4-UUID ambiguity** — if `metadata.json` doesn't disambiguate, blocks the PR. Mitigation: visual-inspect by Devon (open frame_000.png per UUID and read pose) is the fallback; Sponsor re-roll is the escalation.
  - **Facing-flip per pixellab-pipeline.md §"Template animations can flip character facing"** — Drew's parallel spot-check dispatch addresses this. If broken-cycle frames surface, follow `pixellab-pipeline.md` workarounds (re-roll, drop bad frames, manual edit, idle-as-walk). Document the workaround in commit per the doc.
  - **R6** (Sponsor-found-bugs re-armed) — first Sponsor-visible art change of M3; high probability of bug surface.
- **Sponsor gate:** **YES** — Sponsor-soak ritual per `html5-export.md §"Sponsor soak ritual"` after merge. This is the "graphics actually show up" PR.

### M3W-3 — `feat(art|wire): S1 mob-trio — Grunt v2 + Charger + Shooter`

- **Owner:** Devon (3 × SpriteFrames + folder rename) + Drew (3 × scene wiring + state-machine hooks)
- **Size:** **L (6–10 ticks)** — bundle is intentional to amortize the pattern setup
- **Priority:** **P0** — S1 is the primary playable surface; mob roster needs to read as art before Boss makes sense
- **Scope:**
  - Devon — author 3 SpriteFrames:
    - `assets/sprites/grunt/Grunt.tres` (5 anims × 8 dir): `walk`, `atk_telegraph`, `atk`, `hit`, `die`
    - `assets/sprites/charger/Charger.tres` (4 anims × 8 dir): `walk`, `telegraph`, `atk`, `die` — note: **no `hit` anim per art-pass brief** (quadruped templates). Drew handles by retaining current ColorRect hit-flash via modulate.
    - `assets/sprites/shooter/Shooter.tres` (5 anims × 8 dir): `walk`, `telegraph`, `atk`, `hit`, `die`
  - Devon — resolve PixelLab folder UUIDs via each character's `metadata.json` (grunt's `animating-62b12920` = ?, charger's `acting_angry-060d0b5f` = ?, shooter's `add_two_bright_glowi` = ?). Apply rename-OR-UUID-path convention per M3W-1.
  - Drew — swap each mob's `Sprite` ColorRect for `AnimatedSprite2D`; subscribe to each mob's state machine (each has its own pattern — Grunt has `_state_machine` constants, Charger has charge/recover phases, Shooter has aim/fire/recover). Map states → anim names.
  - Drew — **re-verify hit-flash compatibility per mob** — `Grunt.gd._play_hit_flash` lines 187–190 already branch on `_hit_flash_uses_sprite`. AnimatedSprite2D should drop into the `else` branch (modulate path). Confirm both Grunt + Shooter still flash red on hit via HTML5 visual check.
- **Acceptance:**
  - 3 mobs' state machines play correct animations through full combat encounters.
  - All 8 directions render per anim.
  - Charger's `_die` path still ember-bursts per `Grunt.gd` pattern.
  - Paired GUT tests per mob: `tests/test_<mob>_animation_wire.gd`.
  - **HTML5 release-build soak** — kill 1 of each mob, screenshot/clip each combat loop.
- **Risks:**
  - **Charger has no `hit` anim** — Drew accepts the placeholder modulate-flash; document in PR.
  - **Hit-flash regression risk per R-WIRE1** — 3× the surface as M3W-1.
  - **Per-mob facing-flip risk** — Drew's spot-check dispatch covers; if surfaces, descope the broken direction per pixellab-pipeline.md workarounds.
- **Sponsor gate:** None — Tess sign-off only. (S1 mob roster is established gameplay; Sponsor saw at PR #263.)

### M3W-4 — `feat(art|wire): Stratum1Boss — 7-anim wiring (telegraph-A/B + atk-A/B + walk + hit + die)`

- **Owner:** Devon (SpriteFrames — 7 anims × 8 dir = 56 sub-anims, the biggest authoring set) + Drew (boss state-machine wiring — already 9-state per `Stratum1Boss.gd`)
- **Size:** **L (6–10 ticks)** — Boss alone deserves its own PR; the 7-anim count + multi-phase state machine doubles the wiring surface vs a single mob
- **Priority:** **P0** — Boss is the S1 climax; visual identity matters disproportionately
- **Scope:**
  - Devon — author `assets/sprites/boss/Stratum1Boss.tres` (7 anims × 8 dir). Note: boss has TWO attack patterns (A and B) — the SpriteFrames keys must distinguish (`telegraph_a_<dir>`, `telegraph_b_<dir>`, `atk_a_<dir>`, `atk_b_<dir>`).
  - Devon — resolve UUIDs via `metadata.json`. Boss's `_pixellab_anims/` folder contains both `Stratum1Boss_S1_Warden/` AND `add_bright_glowing_r/` (a state-variant); confirm which is canonical with Sponsor-soak rotations.
  - Drew — wire into `Stratum1Boss.gd`'s 9-state machine (dormant → idle → chasing → telegraphing_A → attacking_A → telegraphing_B → attacking_B → phase_transition → dead). Phase boundary thresholds (66%/33%) drive `play()` selection between A/B telegraph patterns.
  - Drew — `entry_sequence_started` signal handler should fade in boss with idle anim (boss-intro.md Beat-1 to Beat-5).
- **Acceptance:**
  - All 7 anims play in editor; full boss-fight clears with correct anim per phase per direction.
  - Phase 1 attack-A → phase 2 attack-B transitions are visibly distinct.
  - Boss-room crossfade audio (per `audio-architecture.md` §"Boss-room crossfade") still triggers on entry.
  - Paired GUT test: `tests/test_stratum1_boss_animation_wire.gd` — full state-machine coverage.
  - **HTML5 full boss fight clip** in Self-Test Report.
- **Risks:**
  - **Boss telegraphs are gameplay-critical** — if the animation visually doesn't read as "windup," players can't react. Drew's spot-check should explicitly inspect telegraph-A and telegraph-B frames for readable windup poses.
  - **Boss generation may have palette quirks** — per `pixellab-pipeline.md §"Prompt-literalism — first noun dominates"` the boss v1 was "iron dominates, surcoat lost." Verify with Sponsor that the wired version reads correctly.
- **Sponsor gate:** **YES** — boss is the climax of S1 + the most user-facing aesthetic call. Soak after merge.

### M3W-5 — `feat(art|wire): hub-town NPCs — Vendor + Anvil-keeper + Bounty-poster (1 anim each)`

- **Owner:** Devon (3 × SpriteFrames, each trivial — 1 anim × 8 dir) + Drew (NPC scenes don't have state machines per `m3-design-seeds.md §2` — minimal wiring)
- **Size:** **S (1–2 ticks)** — smallest non-foundation PR
- **Priority:** **P1** — hub-town is M3 scope per `m3-design-seeds.md §2`; NPCs render but don't drive combat. Can land any time after M3W-1.
- **Scope:**
  - Devon — 3 × SpriteFrames (`NPC_Vendor.tres`, `NPC_AnvilKeeper.tres`, `NPC_BountyPoster.tres`); 1 breathing-idle anim × 8 dir each (NPCs don't face-track player aggressively — could even ship 4 directions if 8 is overkill).
  - Drew — author 3 minimal NPC scenes (`NPC_Vendor.tscn`, etc.) using `AnimatedSprite2D` with `play("idle_<dir>")` on `_ready`. No state machine; no combat hit-flash. Wire into hub-town scene when M3 hub-town surface lands (parallel ticket).
- **Acceptance:**
  - All 3 NPCs play breathing-idle in 8 (or 4) directions.
  - **HTML5 release-build clip** of each NPC.
  - Paired GUT test: `tests/test_npc_idle_animation.gd`.
- **Risks:**
  - Hub-town scene doesn't exist yet (M3 hub-town design seeds — `m3-design-seeds.md §2` — is design seeds only, not built). NPC scenes ship "instantiable but not yet instanced" — flag in PR body that downstream hub-town PR will instance them.
- **Sponsor gate:** None.

### M3W-6 — `feat(art|wire|fx): Stoker runtime palette-swap on Grunt atlas`

- **Owner:** Devon + Uma — **mechanism call is the parallel dispatch's output** (shader vs `replace_color` per-frame vs indexed-palette swap). Once mechanism decided, Devon implements + Drew wires.
- **Size:** **M (3–5 ticks)** if shader path; **L (6–10 ticks)** if per-frame texture replacement (depends on mechanism decision)
- **Priority:** **P1** — Stoker exists in S2 only; S1 ships without Stoker. Can land after M3W-3 (Grunt v2 atlas wired).
- **Priority caveat:** Stoker IS S2 content (per `team/uma-ux/palette-stratum-2.md §5` line 191). If S2 ships before this PR, S2 surface uses placeholder; not blocking M3W-1 through M3W-5.
- **Scope:**
  - **Depends on the parallel Uma+Devon palette-swap mechanism decision.** This brief references that dispatch; does not pre-empt the call. The mechanism options surface naturally:
    1. **Shader-based** — `AnimatedSprite2D.material = ShaderMaterial(palette_swap.gdshader)`; per-instance uniform array maps source palette → S2 palette. Cheap (single shader; per-frame uniform array). Risk: HTML5 `gl_compatibility` shader compatibility per `html5-export.md`.
    2. **Per-frame `replace_color`** — Devon authors a second SpriteFrames `.tres` with PNGs pre-processed via pixel-mcp `replace_color` against S1→S2 mapping. Expensive (3× the disk for 5 anims × 8 dir); safe (no shader).
    3. **Godot Image-level palette swap** — `Image.set_pixel` walk on `_ready` to remap. Slow on first-load; HTML5 may hitch.
  - Devon implements the chosen mechanism.
  - Drew wires `Stoker.gd` (extends Grunt with palette-swap on `_ready`) into S2 mob scenes.
- **Acceptance:**
  - Stoker visibly distinct from S1 Grunt under S2 lighting (Tess eye-dropper per palette-stratum-2.md §5 hexes).
  - All 5 anims × 8 dir play; full Stoker combat encounter clears.
  - Paired GUT test: `tests/test_stoker_palette_swap.gd` — asserts post-swap pixel sample matches S2 palette.
  - **HTML5 release-build clip** of Stoker — palette-swap visibly applied.
- **Risks:**
  - **Mechanism decision blocks start** — this PR's dispatch waits for the parallel Uma+Devon mechanism call. Mitigation: Devon can pre-stage SpriteFrames inheritance scaffolding (assuming mechanism #1 shader path) while the decision lands.
  - **HTML5 shader compat** — if shader path chosen, requires explicit HTML5 verification beyond visual-gate per `html5-export.md`.
- **Sponsor gate:** None — internal art QC only. Stoker is S2 mob, soaks with broader S2 surface.

### M3W-7 — `feat(audio|combat): wire animation-beat audio cues for Player + S1 mob-trio + Boss`

- **Owner:** Devon (audio resource authoring + AudioDirector signal hooks) + Drew (AnimatedSprite2D frame-changed signal handlers)
- **Size:** **M (3–5 ticks)**
- **Priority:** **P1** — gameplay works without it; visual+audio sync makes combat feel land. Sponsor-promoted in M2 RC soak ("squares fighting squares" → audio sync compounds the art-pass impact).
- **Priority caveat:** Defer until M3W-2 (Player) + M3W-3 (S1 mob-trio) + M3W-4 (Boss) have all landed. NPCs (M3W-5) don't need audio cues.
- **Scope:**
  - Devon — confirm with Uma the audio-cue list per character (per `team/uma-ux/audio-direction.md` content side):
    - Player: swing-light, swing-heavy, dodge, hit-take, die
    - Grunt: attack-swing, hit-take, die
    - Charger: charge-windup, charge-impact, die
    - Shooter: aim-windup, fire, hit-take, die
    - Boss: attack-A, attack-B, hit-take, phase-transition, die
  - Devon — register each cue under SFX bus per `audio-architecture.md` (NOT a new bus).
  - Drew — wire `AnimatedSprite2D.frame_changed` signal handlers per character; specific frame indices trigger AudioStreamPlayer per cue. Example: Player atk-light frame 3 of 6 (peak swing) → `AudioDirector.play_sfx("sfx_player_swing_light")`.
  - Drew — verify all cues fire **after** first user gesture per `audio-architecture.md §"HTML5 audio-playback gate"` — combat input is a gesture, so cues fire fine; document explicitly in PR body for the gate check.
- **Acceptance:**
  - Every animation cue plays its audio beat on the correct frame.
  - **HTML5 audio-playback Self-Test Report** per `audio-architecture.md §"Verification gate"` — audible verification + console excerpt required.
  - Paired GUT test: `tests/test_animation_audio_cue_wire.gd`.
- **Risks:**
  - **Audio sources may not be authored yet.** If `audio-direction.md` doesn't have the SFX cue list resolved for these specific beats, this PR forks: either ship with placeholder synthesis (per `audio-direction.md §6 placeholder synthesis disclosure`) or block on Uma authoring cues. Confirm cue inventory before dispatch.
  - **HTML5 audio user-gesture gate** per `audio-architecture.md` — non-issue for combat cues (combat input IS a gesture), but if any cue fires from `_ready` (e.g. boss intro Beat-1 audio), explicit handling required.
- **Sponsor gate:** None — Tess sign-off only.

---

## Per-PR Devon/Drew ownership split — quick-reference table

| PR | Devon authors | Drew wires | Sponsor-gate? |
|---|---|---|---|
| M3W-1 (PD) | `PracticeDummy.tres` + folder convention | AnimatedSprite2D scene swap + hit/die hook | No |
| M3W-2 (Player) | `Player.tres` + 4-UUID disambig | `state_changed` signal handler + 6-state mapping | **YES** |
| M3W-3 (S1 mob-trio) | 3 × SpriteFrames + folder UUIDs | 3 scene swaps + per-mob state-machine hooks | No |
| M3W-4 (Boss) | `Stratum1Boss.tres` (7 anims × 8 dir) | 9-state machine integration + phase-A/B disambig | **YES** |
| M3W-5 (NPCs) | 3 × trivial SpriteFrames | 3 × minimal NPC scenes | No |
| M3W-6 (Stoker) | Palette-swap mechanism impl (Devon) | Stoker.gd wiring (Drew) | No |
| M3W-7 (audio cues) | Audio resource + cue list confirm w/ Uma | `frame_changed` signal handlers per char | No |

**Handoff principle:** Devon's PR-portion can be authored offline (no scene-graph changes); Drew's portion picks up Devon's `.tres` and wires it. Two-author PRs work because the `.tres` resource is the explicit handoff seam. **Each PR can ship as either a single multi-author PR OR as Devon-first + Drew-followup pair** depending on per-week capacity.

---

## Dependency order

```
M3W-1 (PD foundation — pattern conventions)
  └─→ M3W-2 (Player)        ──→ [Sponsor soak gate]
        └─→ M3W-3 (S1 mob-trio)
              └─→ M3W-4 (Boss)     ──→ [Sponsor soak gate]
                    └─→ M3W-7 (audio cues — needs Player+mobs+boss anim wires)
M3W-5 (NPCs)         — parallel to M3W-3/4; can land anytime after M3W-1
M3W-6 (Stoker)       — parallel to M3W-4; depends on M3W-3 (Grunt atlas) + Uma+Devon palette-swap mechanism decision
```

**Sponsor-soak gates: 2 (after Player + after Boss).** Intermediate PRs merge behind Tess only — no soak between M3W-3 and M3W-4 because S1 mob art is established direction per #263.

---

## Risks + open questions

### R-WIRE1 (new) — Hit-flash interaction with AnimatedSprite2D
Every mob's hit-flash currently tweens `Sprite.color` on a ColorRect. AnimatedSprite2D doesn't have a `color` property — must use `modulate`. `Grunt.gd._play_hit_flash` lines 187–190, 425–440 already branch on `_hit_flash_uses_sprite` to handle this; the wiring PRs flip the flag. **Mitigation:** M3W-1 (PD) validates the modulate path first on the smallest surface. **Severity:** high — affects every PR.

### R-WIRE2 (new) — Folder-rename vs UUID-paths-in-tres decision
PixelLab folder naming is UUID-laden (`animating-03b05e65/`, `cross_punch_attack-5d4c0925/`). Two options:
- **Rename folders pre-PR** (e.g. `walk/`, `atk_light/`) — cleaner `.tres` paths; bigger commits; loses traceability to PixelLab.
- **Accept UUID paths in `.tres`** — preserves traceability; uglier `.tres` files; harder to grep "where does `walk_s` live."
**Recommendation:** rename for cleanliness + commit the original `metadata.json` as the reverse-mapping artifact. Devon owns the call in M3W-1; sets convention for all downstream PRs.

### R-WIRE3 (new) — Facing-direction flip in template animations
Per `pixellab-pipeline.md §"Template animations can flip character facing"`, some animation frames within a single 8-direction cycle have **internal facing inversions** (frame 0 faces south, frame 1 faces north, etc.). Drew's parallel spot-check dispatch is the diagnostic. **If flips found per character/direction:** apply the doc's workarounds (re-roll direction with different template, drop bad frames, manual edit, idle-as-walk). Document workarounds in each PR's commit. **Severity:** medium — depends on Drew's findings; could descope an animation direction per character.

### R-WIRE4 (new) — Player's 4 ambiguous `animating-*` UUID folders
Player has 4 animation folders named `animating-<uuid>` (no template name). Per `pixellab-pipeline.md §"Animation frames are only exposed via ZIP download"`, `metadata.json` should carry the original `animation_name` parameter as semantic anchor. **If `metadata.json` doesn't disambiguate**, fallback is frame-count heuristic (walk = 4 or 6, hit = 4, die = 6+) + visual-inspect of `frame_000.png`. **Don't guess** per the never-fabricate rule. Escalation: Sponsor re-roll the ambiguous anims with explicit `animation_name`. **Severity:** medium — blocks M3W-2 if unresolvable; resolved by Devon at M3W-2 dispatch time.

### R-WIRE5 (new) — Stoker palette-swap mechanism
Parallel Uma+Devon dispatch decides the mechanism (shader vs per-frame replace_color vs indexed). M3W-6 dispatch waits on this. **Severity:** low — Stoker is S2; doesn't block S1 surface.

### R-WIRE6 (new) — Audio-cue inventory may not be authored
M3W-7 depends on `audio-direction.md` having authored SFX cues for the specific animation beats. If absent, M3W-7 forks (placeholder synthesis vs Uma-authoring-block). **Mitigation:** confirm cue inventory with Uma before M3W-7 dispatch.

### R-WIRE7 (new) — `_pixellab_anim_test/` folder at player root
There's a `_pixellab_anim_test/` folder at `assets/sprites/player/` separate from `_pixellab_anims/`. Likely the early one-direction test from `pixellab-pipeline.md §"Cost calibration ... single-direction Player walking-4-frames test"`. **Action:** Devon confirms it's not the source of truth + can be removed (or moved to `_pixellab_archive/`) as housekeeping in M3W-2.

### R6 (re-armed) — Sponsor-found-bugs flood
Per `risk-register.md §R6`, every Sponsor-visible visual change re-arms the flood. M3W-2 (Player) + M3W-4 (Boss) are the high-trigger PRs. **Mitigation:** the 2 Sponsor-soak gates are explicit absorbers; W3-T10 absorber pattern (per W3 backlog) carries forward.

### Open question — idle animations
Per art-pass brief, **no idle anim is in the #265 batch.** Player's `STATE_IDLE` currently has no anim; using "walk frame 0 hold" is a placeholder. **Recommend:** flag idle-anim authoring as a follow-up M3 ticket (separate PixelLab dispatch — 1 gen per character × 8 directions × 9 characters = ~72 gens, well within Tier 1 budget). Out of scope for this brief.

### Open question — boss state-variant folder
Boss `_pixellab_anims/` contains BOTH `Stratum1Boss_S1_Warden/` AND `add_bright_glowing_r/`. The latter is a `create_character_state` variant per `pixellab-pipeline.md §"Fixing a single missing detail"`. **Confirm with Sponsor which is canonical** at M3W-4 dispatch time — Sponsor saw both at PR #263 sign-off.

---

## Effort estimate summary

| PR | Devon ticks | Drew ticks | Tess ticks | Total |
|---|---|---|---|---|
| M3W-1 (PD foundation) | 1–2 | 1 | 1 | **S (3–4)** |
| M3W-2 (Player) | 2–3 | 2–3 | 1–2 | **M (5–8)** |
| M3W-3 (S1 mob-trio) | 3–4 | 3–4 | 2 | **L (8–10)** |
| M3W-4 (Boss) | 3–4 | 3–4 | 2 | **L (8–10)** |
| M3W-5 (NPCs) | 1 | 1 | 1 | **S (3)** |
| M3W-6 (Stoker) | 2–3 (shader) or 4–6 (per-frame) | 1–2 | 1 | **M–L (4–9)** |
| M3W-7 (audio cues) | 2–3 | 2–3 | 1–2 | **M (5–8)** |

**Aggregate:** ~36–52 ticks across 3 roles in parallel = ~1 M3 sub-week at W2 throughput pace. Tess is the bottleneck (every PR is HTML5-visual-verification-gated). Drew is the second bottleneck (every PR has a wiring portion).

**Sequencing recommendation:** dispatch M3W-1 first solo; then M3W-2 + M3W-5 in parallel (Player + NPCs share zero surface); then M3W-3 + M3W-6 in parallel (S1 mobs + Stoker after Grunt atlas lands); then M3W-4 solo (boss is single-author-bottlenecked on Devon + Drew); then M3W-7 last.

---

## Decision drafts (carry into next batch PR per `decisions-batch-pr-template.md`)

- **Decision draft:** AnimatedSprite2D + SpriteFrames is the canonical animation pattern for M3 character wiring (not AnimationPlayer + per-frame texture swap). Foundation established in M3W-1 (PracticeDummy).
- **Decision draft:** PixelLab native folders are renamed to semantic names pre-PR; `metadata.json` committed as authoritative reverse-mapping artifact. (Confirm at M3W-1.)
- **Decision draft:** Animation key convention is `<state>_<direction>` (e.g. `walk_s`, `atk_light_ne`); state names mirror existing GDScript state constants.
- **Decision draft:** 2 Sponsor-soak gates for M3 character wiring — after M3W-2 (Player) + after M3W-4 (Boss). Intermediate PRs merge behind Tess only.
- **Decision draft:** Stoker palette-swap mechanism is held for the parallel Uma+Devon dispatch; M3W-6 scope branches on that output.

---

## Cross-references

- `team/priya-pl/art-pass-ai-primary-brief.md` — animation-set-per-character source-of-truth
- `team/priya-pl/m3-design-seeds.md §4` — Sponsor-promoted character-art-pass framing
- `.claude/docs/pixellab-pipeline.md` — UUID folder mapping, facing-flip risks, doctrine-exemption rules
- `.claude/docs/audio-architecture.md` — SFX bus + HTML5 audio-playback gate (M3W-7)
- `.claude/docs/html5-export.md` — visual-verification gate (every PR in scope)
- `team/DECISIONS.md` 2026-05-18 — Stoker palette-swap delegation
- `team/priya-pl/risk-register.md` — R-WIRE1 through R-WIRE7 (new entries, carry to next register refresh)
