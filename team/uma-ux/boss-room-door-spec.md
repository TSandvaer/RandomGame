# Boss-Room Door — Visual Direction (W3-T14)

**Owner:** Uma · **Ticket:** `86c9wjz80` · **Phase:** M3 W3 · **Drives:** Sponsor PixelLab generation (stage 2b), Drew's `BossRoomDoor.tscn` integration (stage 2c), Devon's audio cue wiring (stage 2d).

This doc is the dispatch-ready visual specification for the boss-room door — the visible-state surface that lands on the player's threshold cross of `Stratum1BossRoom`. It pairs with `boss-intro.md` Beat 1 (T+0.0 → T+0.4 s slam) and F3 (T+1.2 → unlock chime + ember-flash).

## 1. Tonal anchor

**The door is the threshold of consequence.** S1 is a "stone cloister settled into silence" (per `palette.md`); the boss room is the room where that silence ends. The door is the punctuation that lands at the player's back: *humans built this lock to keep something in; you crossed the threshold; now you are inside the lock with it.*

The door reads as **heavy, hand-forged, single-purpose**. Iron-banded oak, four iron rivet-clusters, a single horizontal lock-bar across the middle. Not ornate — this is a working door, not a decorative one. The lock-bar is the only part of the door that has *ember* in it: a single iron pin running through the bar, ember-quenched (the bar was forged in a brazier; the pin still remembers the fire). When the door slams shut, the pin **flashes once** — the ember briefly visible through the iron — and then settles back to inert dark iron. When the door unlocks after the boss falls, the pin flashes again — the seal releasing — and then the door reads "open" again.

The ember-flash on the lock-pin is the **only ember the door has**. The rest is iron and oak. The flash is the door's character beat: it tells the player that the lock is *of the same substance as the player's flame* — diegetically, the cloister monks forged this lock with a brazier flame, and the player carries a piece of that same flame. The boss is the thing the cloister locked away from itself.

## 2. Palette lock (S1 doctrine — verified against `palette.md`)

Every door pixel must trace to one of these palette entries. No invention; no off-doctrine darks; no cross-stratum hexes. **Sub-1.0 per channel on every color, HTML5 HDR-clamp safe** (all listed hexes verified).

### Door body — iron + oak

| Role | Hex | Source | Notes |
|---|---|---|---|
| Oak plank (lit face) | `#9A7A4E` | `palette.md` § S1 Environment, "Trim / pillar" | Bronzed trim hex repurposed as plank-lit; matches existing S1 door-arch trim. |
| Oak plank (mid) | `#5C4F38` | `palette.md` § S1 Environment, "Floor — deep" | Recessed plank face / between-rivet shadow. |
| Oak plank (deep) | `#4A3F2E` | `palette.md` § S1 Environment, "Wall — base" | Deepest shadow inside rivet recesses + bottom edge of planks. |
| Iron band (lit) | `#9C9590` | `palette.md` § S1 Mob accents, "Grunt weapon edge" | Worn iron — same hex used for grunt sword blades; ties door iron to mob iron. |
| Iron band (mid) | `#3F362C` | `palette.md` § S5 ref (wall riveted-iron plating) — falls inside S1 iron-shadow tonality | **Decision:** approved as S1-doctrine-compatible deep iron (sits within the S1 environmental dark-warm ramp; no cross-stratum cool bias). Iron-band-shadow needed a value below `#5C4F38` without dropping to pure outline. |
| Iron rivet (highlight) | `#A89677` | `palette.md` § S1 Environment, "Floor — highlight" | 1 px specular dot on the four rivet clusters; reuses the warm-stone highlight to avoid introducing a separate steel-highlight hex. |
| Outline / deepest shadow | `#1A1210` | `pixel-mcp-pipeline.md` § "Doctrine palette lock — worked example (S1 Grunt)" | The S1-doctrine outline hex used on the grunt; 1 px dark outline around door silhouette. |

### Lock-bar + ember pin

| Role | Hex | Source | Notes |
|---|---|---|---|
| Lock-bar (locked state, base) | `#3F362C` | shared with iron-band-mid above | Lock-bar reads as the same iron as the bands. |
| Lock-bar (locked state, lit) | `#9C9590` | shared with iron-band-lit above | Top edge of the bar. |
| Lock-bar (unlocked state, base) | `#5C4F38` | `palette.md` § S1 Floor-deep | When the bar is **slid back** (unlocked state), it sinks into the door body and reads as oak-recessed; iron lit-edge dims to oak-mid. The door visibly *releases* its hold. |
| Ember pin (inert) | `#A02E08` | `palette.md` § Ember accent (deep) | The pin in default unlocked + locked states sits at ember-deep — visible as a small dark-red dot, not a flash. |
| Ember pin (flash frame) | `#FF6A2A` | `palette.md` § Ember accent (primary) | The 1-frame flash on `slamming → locked` transition end AND on `unlocking → unlocked` end. Brand ember; same flame the player carries. |
| Ember pin (flash highlight) | `#FFB066` | `palette.md` § Ember light (highlight) | 1 px highlight pixel at the flash-frame center (the flame's hottest point). |

### Anti-list (do NOT use)

- Pure black `#000000` — S1 forbids per `palette.md` § "Stratum 1 anti-list."
- Any S2+ iron / mob hex (`#7A1F12`, `#7E5A40`, etc.) — S1 doctrine only.
- Cool steel-blue or any cyan hue — wrong stratum.
- Lock-pin in any state other than ember-deep `#A02E08` (inert) or ember-primary `#FF6A2A` (flash). No yellow, no white-hot, no off-ember.

## 3. Dimensions + composition

**Target sprite size: 48×64 px** (per-direction). Wider than tall by a small margin to read as a *door-frame inside the wall*, not a freestanding rectangle. Per `pixellab-pipeline.md` § "Canvas-size trap": PixelLab `size=64` → ~92×92 canvas; crop to 48×64 after import.

- **Door body:** 44×60 px centered in the sprite; 1 px outline `#1A1210` all around.
- **Iron bands:** 4 horizontal bands across the door (1 px tall each, full plank width). Spaced at y = 8 / 24 / 40 / 52 from the top of the door body.
- **Iron rivets:** 4 clusters of 4 rivets each, at the corners of the door body (top-left, top-right, bottom-left, bottom-right). Each rivet = 2×2 px iron-band-mid + 1 px iron-rivet-highlight specular dot.
- **Lock-bar:** horizontal bar centered vertically (y = 30 from door top), spanning x = 6 to x = 38 (32 px wide × 4 px tall).
- **Ember pin:** single 2×2 px dot at the center of the lock-bar (x = 22, y = 31).
- **Player approach side:** the door is rendered facing the room **interior** (the boss side) — the player crosses the threshold *toward the player*, slams behind them. Sprite orientation: door visible as the player looks back over their shoulder upon entry. Drew may need a paired "exterior side" rendering for the unlock-then-walk-out beat; recommend **same sprite mirrored** to keep PixelLab generations to a single 4-state set.

Why 48×64 (and not the room-tile budget of 32×48 or 48×48): the door is a **load-bearing dramatic object**, not a navigation tile. It needs vertical mass to read as "you are below it now, looking up at it." 48×64 puts it at the visual weight of a mini-boss prop while staying small enough for PixelLab's per-character generation budget.

## 4. Animation states (4 states)

The door is a **4-state SpriteFrames resource**. Drew picks the resource shape (single `.tres` with 4 anims, or 4 separate scene-toggle TextureRects); recommendation is a single `BossRoomDoor.tres` SpriteFrames with these animation keys following the `<state>_<dir>` convention from `pixellab-pipeline.md` § "M3W-1 realized implementation":

| State | Anim key | Frames | Duration | Loop | Fires from |
|---|---|---|---|---|---|
| `unlocked` (default) | `unlocked` | 1 | static | no | Room load (default visible state before entry-sequence). |
| `slamming` | `slamming` | 8 | 0.40 s | no | `entry_sequence_started.emit()` (boss-intro Beat 1). |
| `locked` | `locked` | 1 | static | no | Auto-set after `slamming` completes (frame 8 → hold). |
| `unlocking` | `unlocking` | 6 | 0.30 s | no | `boss_defeated.emit()` (boss-intro F3 — reverse of Beat 1). After completion: revert to `unlocked` static. |

### Per-state frame description (for PixelLab prompt + Drew integration)

**`unlocked` (static, 1 frame)**

The door sits **slightly ajar** — visible 4 px gap between door edge and frame. Lock-bar is in the **recessed/oak position** (`#5C4F38` mid-oak, no iron specular). Ember pin sits at inert `#A02E08` (visible as a small dark-red dot). This is the **pre-entry** appearance: the door is open, the player can walk through; there's no menace yet.

**`slamming` (8 frames over 0.40 s = 50 ms/frame)**

A short forceful slam closing the gap + locking the bar:

- Frame 1 (T+0.000 s): door at unlocked position (4 px ajar). Lock-bar still recessed.
- Frame 2 (T+0.050 s): door swung 2 px toward closed. Motion-blur via 1-px-darker mid-tones on the moving plank face. Lock-bar still recessed.
- Frame 3 (T+0.100 s): door fully closed. Lock-bar still recessed. Shake-tell: 1 px down-displacement on the entire door (sells the impact thud).
- Frame 4 (T+0.150 s): door body settled. Lock-bar **starts sliding into locked position** (1 px lift of bar above oak recess; iron base hex `#3F362C` becoming visible).
- Frame 5 (T+0.200 s): lock-bar 50% into locked position (half iron `#3F362C`, half oak `#5C4F38` visible across bar width).
- Frame 6 (T+0.250 s): lock-bar fully extended; iron-band-lit `#9C9590` highlights on bar top edge. Ember pin still inert `#A02E08`.
- Frame 7 (T+0.300 s): **EMBER FLASH FRAME.** Ember pin transitions to `#FF6A2A` primary with `#FFB066` highlight pixel center. 1-frame brilliance. (Per `boss-intro.md` Beat 1.)
- Frame 8 (T+0.350 s): ember pin returns to inert `#A02E08`; door is now in `locked` state. (Hold to T+0.40 then auto-transition to `locked` static state.)

**`locked` (static, 1 frame)**

Door fully shut, lock-bar fully extended with iron specular on top edge, ember pin at inert `#A02E08`. This is the state the door stays in for the entire boss fight (could be 30 s, could be 5 minutes — must hold static cleanly with no animation loop).

**`unlocking` (6 frames over 0.30 s = 50 ms/frame)**

Reverse of the slam — gentler, releasing rather than impacting:

- Frame 1 (T+0.000 s): `locked` state (lock-bar fully extended, ember pin inert `#A02E08`).
- Frame 2 (T+0.050 s): **EMBER FLASH FRAME.** Ember pin transitions to `#FF6A2A` primary with `#FFB066` highlight. This flash precedes the bar releasing (the seal "opens" the lock before the lock visually retracts). (Per `boss-intro.md` F3.)
- Frame 3 (T+0.100 s): ember pin returns to inert `#A02E08`; lock-bar begins sliding back to oak-recessed position (lit edge dimming as iron-mid is replaced with oak-mid).
- Frame 4 (T+0.150 s): lock-bar 50% retracted.
- Frame 5 (T+0.200 s): lock-bar fully retracted into oak-recessed position; door body still fully closed.
- Frame 6 (T+0.250 s): door body swings 2 px ajar (small, gentle — this is "release," not "burst open"). Final state visible: 4 px ajar gap, lock-bar recessed. (Hold to T+0.30 then auto-transition to `unlocked` static state.)

### Animation curves

- **`slamming` Frames 1-3 (closing):** linear interpolation. The slam is *mechanical*, not eased — iron on stone is rigid.
- **`slamming` Frames 4-6 (lock extending):** ease-out (the bar lands authoritatively).
- **`slamming` Frame 7 (ember flash):** instantaneous on/off — 1 frame at 50 ms is the flash duration.
- **`unlocking` Frames 2 (ember flash):** instantaneous on/off — same 1-frame at 50 ms.
- **`unlocking` Frames 3-5 (lock retracting):** ease-in-out (gentler than the slam — release is felt, not forced).
- **`unlocking` Frame 6 (door swings ajar):** ease-out (the door comes to rest naturally).

### Visual primitive discipline (HTML5 / WebGL2 safety)

This is **SpriteFrames → AnimatedSprite2D** territory — same primitive class as the existing M3W-1 mob roster (Grunt, Charger, Shooter, Stratum1Boss). Per `.claude/docs/html5-export.md` § "Polygon2D rendering quirks," ColorRect/Polygon2D are NOT the right surface here; SpriteFrames is the renderer-safe primitive class with empirical track record across the mob pipeline.

**Ember-flash implementation rule for Drew (stage 2c):** the flash is a **discrete frame in the SpriteFrames anim**, NOT a `modulate` tween on the door root. Encoding the flash as a frame avoids the modulate-clamp + Tween-on-leaf-Control gotcha pattern that bit the wedge in PR #137. The frame at T+0.35 in `slamming` and T+0.05 in `unlocking` literally has different ember-pin pixels (`#FF6A2A` + `#FFB066`) than the surrounding frames. Frame-encoded > modulate-encoded for HTML5.

**z_index discipline:** per `html5-export.md` § "Z-index sensitivity," door should sit at `z_index = +1` (above the floor `z_index = 0` and below the player `z_index = 2`). Do NOT use `z_index = -1`. The door is a *world prop*, not a *background tile* — positive z_index above the floor ramp.

## 5. PixelLab prompt template (Sponsor stage 2b)

Paste-ready into `mcp__pixellab__create_character`. Self-contained — no Sponsor-side prompt tuning needed.

```
description: "Heavy hand-forged dungeon door, iron-banded oak, single horizontal lock-bar across center with one small ember-red pin in the bar center. Four iron rivet clusters at the corners. Dark oak planks #5C4F38, iron bands #3F362C, lock-bar iron #3F362C, ember pin dark red #A02E08. Stocky rectangular silhouette, bold 1-pixel dark outline #1A1210, simple readable shape, head-on facing camera, NO ornate detail, NO carved relief, dark fantasy dungeon prop. The door is closed and locked, lock-bar fully extended across the planks."
size: 64
body_type: "humanoid"  # NOTE: humanoid is fine for inanimate props on PixelLab — the template just controls canvas shape
n_directions: 1  # door is single-facing (player faces the door interior); no rotations needed
no_background: true
```

**Anti-tokens** (for the `--no` field if PixelLab's create_character honors negative prompts; otherwise post-process):

```
ornate carvings, runes, glowing eyes, holes, gaps, multiple doors, archway, frame, hinges visible, character behind door, light beams, sparks, fire, ground shadow, background, complex texture
```

### Per-state generation strategy

Sponsor generates the **`locked` static** state first (1 generation @ standard, ~1 credit). Then uses `mcp__pixellab__create_character_state` for the variant states:

```
# Variant 1: unlocked (door slightly ajar, lock-bar recessed into oak)
create_character_state(
    character_id="<locked-char-id>",
    edit_description="door is slightly ajar with a 4px gap on the right side, lock-bar slid back into the oak-recessed position (no iron specular on bar, oak-mid color across bar), ember pin still inert dark red"
)

# Variant 2: slamming (intermediate frame, lock-bar 50% extending — generation pick frame 5 for the in-between)
# OPTIONAL — only needed if Sponsor wants a hand-tuned slam intermediate; otherwise the 8 frames can be tween-interpolated by Drew during integration from the locked + unlocked variants. Skip unless animation budget permits.

# Variant 3: ember-pin-flash (locked + ember pin at #FF6A2A primary instead of #A02E08 deep)
create_character_state(
    character_id="<locked-char-id>",
    edit_description="locked door with ember pin in the center of the lock-bar lit up bright ember-orange #FF6A2A with a small light highlight pixel, the only visible change is the ember pin color shifting from dark red to bright ember-orange"
)
```

### Doctrine palette lock (post-PixelLab)

After PixelLab generation, run `quantize_palette` then **Strategy 3 (per-slot nearest-neighbor)** per `pixellab-pipeline.md` § "Doctrine palette compliance — Strategy 3." The doctrine palette for this asset:

```python
DOCTRINE_DOOR_S1 = [
    "#9A7A4E",  # oak lit
    "#5C4F38",  # oak mid
    "#4A3F2E",  # oak deep
    "#9C9590",  # iron lit
    "#3F362C",  # iron mid
    "#A89677",  # rivet highlight
    "#1A1210",  # outline
    "#A02E08",  # ember pin inert
    "#FF6A2A",  # ember pin flash (flash variants only)
    "#FFB066",  # ember pin highlight (flash variants only)
    "#00000000", # transparent
]
```

**Character-beat preservation override** per `pixellab-pipeline.md` § "Refinement — manual override for character-beat preservation": the **ember-pin pixels** are doctrine-critical accents. PixelLab will likely generate them in the warm-red/orange family but may map them to `#A02E08` only (the closest doctrine ember member). For the **flash variant** (Variant 3), manually override the bright-red slot to `#FF6A2A` even if Euclidean nearest-neighbor picks `#A02E08` — the flash IS the character beat. Same rule as the Shooter eye-glow doctrine-lock (Shooter v2 worked example).

## 6. Audio coupling (T14 stage 2d — Devon)

Audio is **Devon's stage 2d work**, not in scope for this direction doc. For coordination clarity, the door's audio touch-points are:

| Trigger | Cue ID | Approx duration | dB target | Bus |
|---|---|---|---|---|
| `slamming` frame 1 fires | `sfx-door-slam-heavy` | ~0.5 s | nominal SFX (peaks at SFX-bus -6 dB) | SFX |
| `unlocking` frame 2 (ember-flash) fires | `sfx-door-unlock-chime` | ~0.3 s | -3 dB below `sfx-door-slam-heavy` (gentler release than the slam impact) | SFX |

`sfx-door-slam-heavy` already exists as an AD entry in `audio-direction.md` § SFX-items-world-UI. `sfx-door-unlock-chime` needs a NEW AD entry — Devon authors in stage 2d. **Cross-stratum-reuse decision:** the unlock chime is **single-use cue** (only the boss-room door fires it in M1); no cross-stratum reuse precedent needed yet. If M2 adds a similar boss-room door, the cue should be **reused (not retinted/varied)** — the chime is the diegetic release-of-the-lock sound; same lock-mechanism, same chime, regardless of stratum.

**Cycle-time risk:** none. Slam fires once on `entry_sequence_started`; unlock fires once on `boss_defeated`. Both single-shot, no looping, no overlap.

## 7. Cross-references

- `team/uma-ux/boss-intro.md` § Beat 1 (T+0.0 → T+0.4 s slam) — this doc fulfills.
- `team/uma-ux/boss-intro.md` § F3 (T+1.2 → unlock chime + ember-flash) — this doc fulfills the visual side; Devon stage 2d fulfills the audio side.
- `team/uma-ux/palette.md` § S1 Environment + Mob accents + Ember-orange — every door hex traces here.
- `team/uma-ux/audio-direction.md` § SFX-items-world-UI — `sfx-door-slam-heavy` AD entry exists; `sfx-door-unlock-chime` AD entry added in stage 2d.
- `.claude/docs/pixellab-pipeline.md` § Canonical hybrid pipeline + Doctrine palette compliance — Sponsor stage 2b uses these patterns.
- `.claude/docs/pixel-mcp-pipeline.md` § "Doctrine palette lock — worked example (S1 Grunt)" — outline hex `#1A1210` and palette-extension rule precedent.
- `.claude/docs/html5-export.md` § Polygon2D rendering quirks + Z-index sensitivity — Drew stage 2c integration constraints.
- `team/priya-pl/w3-dispatch-plan.md` § Brief 2 — full T14 chain (Uma stage 2a → Sponsor stage 2b → Drew stage 2c → Devon stage 2d).

## 8. Open questions

1. **Door orientation per-direction sprite.** Spec assumes 1 single-facing sprite (player faces the door interior on entry; mirror for the unlock-then-walk-out beat). Drew may request 2 explicit orientations if the room geometry needs them. **Recommendation:** ship single-facing first; Drew flips horizontally as needed during integration.
2. **Ember-flash exact timing within frame 7 of `slamming`.** Specced at T+0.30 (frame 7 of 8 at 50 ms/frame). Alternative: T+0.25 (frame 6) so the flash precedes the "settle" frame and reads more as "the lock LANDS and ignites." **Decision deferred to integration soak** — Drew + Sponsor pick the more impactful timing after Stage 2c first build.
3. **Ember-pin inert color while idle/locked.** Specced at `#A02E08` (ember-deep, visible as small dark-red dot). Alternative: `#1A1210` outline-dark (the pin is invisible until it flashes). **Decision: keep `#A02E08`** — the diegetic logic ("the lock remembers the fire") requires a visible-but-quiet inert state. Pure-dark would lose the cross-frame ember thread.

## 9. Tester checklist (yes/no — for stage 2c integration QA)

| ID | Check | Pass criterion |
|---|---|---|
| T14-D-01 | Door visible in boss-room entry threshold at room load (state = `unlocked`) | yes |
| T14-D-02 | On `entry_sequence_started.emit()`, `slamming` animation fires within 1 frame | yes |
| T14-D-03 | `slamming` animation duration ≈ 0.40 s (8 frames @ 50 ms) | yes |
| T14-D-04 | Frame 7 of `slamming` shows ember-pin at `#FF6A2A` with `#FFB066` highlight | yes |
| T14-D-05 | After `slamming` completes, door holds in `locked` state indefinitely (no auto-loop) | yes |
| T14-D-06 | On `boss_defeated.emit()`, `unlocking` animation fires within 1 frame | yes |
| T14-D-07 | `unlocking` animation duration ≈ 0.30 s (6 frames @ 50 ms) | yes |
| T14-D-08 | Frame 2 of `unlocking` shows ember-pin at `#FF6A2A` with `#FFB066` highlight | yes |
| T14-D-09 | After `unlocking` completes, door returns to `unlocked` static state | yes |
| T14-D-10 | All door pixels eye-droppable to a hex in §2 palette-lock table (no off-doctrine colors) | yes |
| T14-D-11 | Door renders at `z_index = +1` (above floor, below player) — no negative z_index used | yes |
| T14-D-12 | HTML5 soak: door visibly slams in WebGL2 incognito build — no invisibility regression | yes |
