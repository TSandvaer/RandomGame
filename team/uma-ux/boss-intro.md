# Boss Intro & Health-Bar Treatment (M1)

**Owner:** Uma · **Phase:** M1 (stratum-1 boss) · **Drives:** Drew's stratum-1 boss build (`86c9kxx4t`), Devon's `BossNameplate.tscn` + `BossIntroSequence.tscn`, audio cue list for the boss-room beat.

The stratum-1 boss is the **first time the run feels like a story**. Eight rooms of grunts then *this*. The intro must telegraph "the floor changes here," the nameplate must read like a gauntlet thrown, the phase transitions must feel like the boss *responds* to the player's pressure, and the kill must feel like the run's climax — earned, not anticlimactic.

## Design intent (one paragraph)

A boss room is a **comma plus an exclamation point**. The door slams behind, the music shifts, the lights drop, the nameplate slides in from the top like a banner unfurled — then the fight is just a fight, but every cue you stacked at the door is still ringing in the player's chest. Phase transitions are the boss saying *"again, but harder"* — they're not health gates, they're *narrative gates*. The kill is the only place in M1 where the world stops to honor the player. After that, the loot they kept (per M1 death rule) or the loot they lost is the next decision.

## Beat-by-beat: boss entry

Triggered when the player crosses the boss-room threshold (Drew's `BossRoomTrigger` collision).

### Beat 1 — Door slam (T+0.0 → T+0.4 s)

- The door **behind the player** slams shut and locks. Heavy iron-on-stone thud — `door_slam_heavy.ogg`, ~0.5 s.
- A 1-frame screen-shake pulse (3 px amplitude, 0.15 s decay) sells the impact.
- The door visual gets a 1-frame ember-flash on its lock-bar, then settles to a "locked" sprite state. (Tells the player: *no retreat now.*)
- All player input remains live — they can keep moving. **No input lock at the door** (that's a death-sequence move; this is gameplay).

### Beat 2 — Room darkens + ambient cuts (T+0.0 → T+0.6 s)

In parallel with Beat 1:

- Stratum-1 ambient music **fades to 0%** over 0.6 s. Hard mute by T+0.6.
- The room's vignette deepens from the stratum-1 default (~30% per `palette.md`) to **70%** over 0.6 s. The boss is centered; the periphery dims.
- Wall torches in the boss room (Drew's call on placement) flicker once and **drop to 60% brightness**. The room reads cooler, more dangerous, without changing the palette wholesale.

### Beat 3 — Camera zoom + boss reveal (T+0.6 → T+1.2 s)

- Camera **eases in** from default zoom to **1.25× internal pixel scale** over 0.6 s. Just enough to make the boss feel bigger; not enough to break the playfield-readability budget.
- Camera target shifts from the player to the **midpoint between player and boss** for the duration of the intro. Returns to player-anchored on Beat 5.
- The boss sprite — which has been idle in its anchor position — **stands up / unfurls / lights its ember** (boss-specific Drew tell). Drew authors a 0.5 s wake animation per boss.
- **Boss-wake audio:** a single low brass note + a stinger (`boss_wake_stratum1.ogg`, ~0.6 s, layered with a soft impact).

### Beat 4 — Nameplate banner (T+1.2 → T+1.8 s)

- Boss nameplate **slides down from the top of the screen** over 0.4 s, easing out. Anchors at 12 px below the screen top. (The regular HUD top-left vitals stay in place; the boss nameplate sits centered, 480 px wide per `hud.md` §6.)
- Nameplate text types in over 0.3 s — boss name first, threat-level pip second, health bar fills last (left-to-right wipe, 0.4 s).
- **Audio:** a low bell tone — same bell sample as the splash and the death-flow, intentionally rhyming — at T+1.4. Single strike, not a peal.

### Beat 5 — Combat begins (T+1.8 s onward)

- Camera returns to player-anchored over 0.3 s.
- **Boss music** layer fades in (`boss_loop_stratum1.ogg`, fade over 0.6 s). Boss music is a **one-track loop in M1** — final scoring is M3.
- The boss enters its first attack pattern. Drew's call on the opening pattern; the design doc just says *"the boss does NOT attack during Beats 1–4."* Fairness for the player who is reading the nameplate.
- HUD top-right region (`hud.md` §2) flips to red `STRATUM 1 · BOSS` treatment.

**Total intro length: 1.8 s.** Skippable? Yes — see "Skip rule" below.

### Skip rule

After the **first boss kill of the player's lifetime** (per-character flag, saves to disk), the boss intro can be **skipped by pressing any movement key during Beats 2–4**. The skip collapses to: door slam (always plays), nameplate slides in (0.2 s, faster), boss music fades in (0.3 s). Skip is **not advertised** — it's discovered, like Esc-skip on the death sequence.

Rationale: first-time players see the full theatre; veteran replays don't get nagged. The door slam + nameplate are the irreducible "this is a boss" cues; everything else is optional.

## Boss nameplate spec

A wider, taller, more elaborate variant of the regular mob nameplate from `hud.md` §6. **Anchored to the HUD canvas, not the boss world position** — the boss can move, the nameplate doesn't.

### Layout (1280 × 720 reference)

```
              +------------------------------------------------------------+
              |                                                            |
              |   [!] WARDEN OF THE OUTER CLOISTER         THREAT: ELITE   |
              |                                                            |
              |   ████████████████████ | ████████████████ | ███░░░░░░░░░░  |
              |   PHASE 1               PHASE 2             PHASE 3        |
              |                                                            |
              +------------------------------------------------------------+
                                  ^
                                centered, top of screen, 12 px from top edge
```

Component breakdown:

- **Width:** 480 px. **Height:** 56 px. **Anchored:** top-center, 12 px from screen top.
- **Background:** `#1B1A1F` at 92% opacity. 1 px ember-orange `#FF6A2A` border. Inset shadow 2 px on inner edge for depth.
- **Threat glyph** (top-left, 24×24): an ember-orange `[!]` for elite, an ember-orange skull for "boss-tier" (M2+). M1 stratum-1 boss is `ELITE` tier — the skull glyph is reserved.
- **Boss name** (top-center, 16 px caps off-white `#E8E4D6`): the boss's display name. Stratum-1 working title: **"WARDEN OF THE OUTER CLOISTER"** (Uma's working name; Drew can rename in the boss TRES if he prefers — single-source-of-truth is `MobDef.display_name`).
- **Threat label** (top-right, 12 px caps muted parchment `#B8AC8E`): `THREAT: ELITE` for M1. M2+ progression: `ELITE` → `CHAMPION` → `LORD` → `ASCENDANT` (4-tier ramp; only `ELITE` ships in M1).
- **Multi-segment health bar** (bottom of nameplate, 432 px × 12 px): see "Phase-segmented health bar" below.

### Phase-segmented health bar

The stratum-1 boss has **3 phases** (per Drew's `86c9kxx4t` task — phase transitions at 66% and 33% HP). The health bar reflects this **visually as 3 segments** divided by a 2 px ember-orange separator.

```
  PHASE 1                  PHASE 2                  PHASE 3
████████████████████████│████████████████████████│████████████████████████
└─────── 144 px ────────┘└─────── 144 px ────────┘└─────── 144 px ────────┘
```

- **Segment dimensions:** Each segment is exactly **1/3 of the bar width** (144 px of the 432 px usable area). Segments are visually **identical width** even though they may not represent equal HP — they're **narrative phases**, not literal HP brackets. Drew's call on internal phase HP weights; the bar lies a little to make the story land.
- **Segment fill (active phase):** `#7A2A26` (mob HP foreground per `palette.md`) with the same ghost-damage layer treatment as the regular HP bar — foreground drops instantly on hit, ghost layer drains over 0.6 s. **Only the active phase's segment animates** — completed segments stay at 0 fill; future segments stay at 100% fill (locked, dimmed to 60% brightness so the eye knows the boss has more left).
- **Phase separator:** 2 px ember-orange vertical line between segments. Always visible; it's the **promise of more fight**.
- **Phase label** (above each segment, 10 px caps muted parchment): `PHASE 1` / `PHASE 2` / `PHASE 3`. The active phase's label brightens to `#E8E4D6`; completed labels stay muted; future labels are `#605C50` (HUD disabled color).
- **No numeric HP value.** This is intentional. The bar is the data. Numbers diminish the moment.

### Boss-only states

- **Below 10% in current phase:** active segment pulses (1 px ember-orange outline blinks at 1.5 Hz). Telegraphs "phase transition imminent."
- **Active phase fully drained:** segment goes black, separator flashes ember for 0.3 s, **next segment activates with a 1-frame ember-flash on its phase label**.
- **All three segments drained:** no special state on the nameplate; the boss-defeated sequence (Beat F below) takes over the screen entirely.

## Phase transition cinematics (M1: at 66% / 33% HP)

When a phase boundary is crossed, the world pauses for a breath — but **does not fully freeze** (consistent with the inventory + level-up time-slow conventions; M1 has a single language for "modal moments").

### Beat T — Phase break (T+0.0 → T+0.6 s)

- World time **drops to 30%** for 0.6 s (less aggressive than inventory's 10% — it's a beat, not a takeover).
- The boss sprite gets a **1-frame ember-flash outline**.
- A short audio sting plays: `phase_break_stratum1.ogg`, 0.4 s — a tritone tension chord, brief.
- The transitioning segment on the nameplate: separator flashes ember-orange for 0.3 s; next segment's phase-label brightens with a 1-frame flash.
- The boss may play a **short tell animation** (Drew's call — 0.4 s max so we don't blow the time budget). Recommended: boss takes a step back, ember-pulses, takes a step forward — communicates *"I am going harder now."*

### Beat T+0.6 onward

- World time ramps back to 100% over 0.2 s.
- Boss enters its next-phase attack pattern.
- Boss music **does not change** in M1 (single loop). M2 stretch: layer-in additional instrumentation per phase.

**Total phase break: 0.6 s.** Skippable? **No.** The phase transition is a respawn checkpoint feeling — the player needs the beat to mentally reset, even on replay. Holding the line on this until tested.

## Boss-defeated moment (the climax)

Triggered on the boss's HP hitting 0 in phase 3.

### Beat F1 — Final hit lands (T+0.0 → T+0.3 s)

- Time **fully freezes** for 0.3 s — first true freeze in the game's design language. This is the moment of celebration; we earn the freeze here.
- The boss sprite **flashes white for 1 frame**, then desaturates to grey over 0.3 s.
- **Audio:** combat audio cuts hard. Boss music cuts hard. A single struck bell — same bell sample as splash / death / boss-wake — rings at T+0.1.

### Beat F2 — Embers rising (T+0.3 → T+1.2 s)

- The boss sprite **dissolves into upward-rising embers** — same emitter as the death-flow's player-dissolve (Drew authors once per `death-restart-flow.md` Beat B-C), but **brighter, faster, and with more particles** (boss-flavored). Ember-orange + ember-light particles.
- Camera does a slow ease-in to 1.5× over 0.9 s, centered on the boss's last position.
- Vignette deepens to 80% — the room narrows to just the dissolution.
- **Audio:** sustained warm horn note rises (`boss_kill_horn.ogg`, 0.9 s), reaching peak as embers exit screen.

### Beat F3 — Title card + loot reveal (T+1.2 → T+2.4 s)

- Title card fades in centered: **"The Warden falls."** in wordmark font, off-white `#E8E4D6`, holds for 0.8 s. The boss's name from `MobDef.display_name` substitutes — strings live in a single resource so M2 bosses get the same treatment.
- Below it, in muted parchment 12 px caps: `STRATUM 1 CLEARED`.
- At T+1.6, the **boss's loot drops** from the boss's last position with the standard loot-drop audio + light-beam VFX from Drew's `Pickup.tscn`. M1 acceptance #4 is *"a death does not lose character level or stashed gear"* — the boss kill is where this rule **earns its first real test**: the player **picks up the loot before deciding what to do next.** They might equip it on the spot. They might keep it in inventory and risk losing it on the next stratum (M2+).
- Camera returns to player-anchored over 0.4 s.
- Vignette returns to stratum-1 default (30%) over 0.4 s.
- World time resumes 100%.
- The locked door **unlocks** with a soft chime + a 1-frame ember-flash on its lock-bar. (Reverse of Beat 1.)

### Beat F4 — Stratum-clear ambient (T+2.4 onward)

- Boss music does not return; **stratum-1 ambient resumes** at 60% volume (slightly quieter than pre-fight — the room feels emptier now, deliberately).
- HUD top-right `STRATUM 1 · BOSS` returns to its pre-fight state. M1 stops here. M2+ chains the next stratum.
- The player has the room and the loot. **They get to be a person for a minute** before the design hands them the next decision.

### Honoring the M1 death rule

Per `team/DECISIONS.md` (2026-05-02 — M1 death rule): on death, the player keeps character level + equipped items, loses unequipped inventory + run-progress. The boss kill is **the singular moment in M1 where the equipped-vs-inventory choice has the highest stakes**:

- Boss loot drops at the player's feet. The player can equip it (kept on next death) or leave it in inventory (lost on next death — but M1 has only one stratum so the next death IS the next run; loss is real but bounded).
- The run-summary screen (`death-restart-flow.md`) visually confirms the choice retroactively after the next death — "Lost With The Run" shows the loot the player left in inventory.
- This is the **fantasy of the loop**: the boss kill is climax, but greed for one more affix gets punished. We don't lecture the player on this — the rule does its own teaching.

The boss-defeated moment **does not call out the M1 death rule** in copy. The rule speaks for itself the first time the player dies after a boss kill. (One of the cleanest pieces of game-feel teaching we get for free.)

## Audio map (concrete cues for the placeholder pass)

| Beat | Cue | Asset placeholder name |
|------|-----|------------------------|
| 1 — door slam | Heavy iron-on-stone thud | `door_slam_heavy.ogg`, ~0.5 s |
| 2 — ambient cut | Stratum-1 ambient fades to 0% | (existing `stratum1_ambient.ogg` fade) |
| 3 — boss wake | Low brass + impact stinger | `boss_wake_stratum1.ogg`, ~0.6 s |
| 4 — nameplate bell | Single struck bell (same sample as splash/death) | `bell_struck.ogg` |
| 5 — boss music in | One-loop boss combat track | `boss_loop_stratum1.ogg` |
| T — phase break | Tritone tension chord | `phase_break_stratum1.ogg`, 0.4 s |
| F1 — final hit | Combat + music cut, single bell | `bell_struck.ogg` (reused) |
| F2 — embers rising | Sustained warm horn note | `boss_kill_horn.ogg`, 0.9 s |
| F3 — title card | (no audio — silence carries the moment) | — |
| F3 — door unlock | Soft chime | `door_unlock_chime.ogg`, ~0.3 s |
| F4 — stratum-clear ambient | Stratum-1 ambient at 60% | (existing) |

All audio is M1 placeholder. Real scoring is M3.

## Copy spec

Every player-facing string in this flow:

| Where | String | Notes |
|-------|--------|-------|
| Boss nameplate name (M1) | `WARDEN OF THE OUTER CLOISTER` | Sourced from `MobDef.display_name`. Drew can rename. |
| Boss nameplate threat | `THREAT: ELITE` | M1 only tier. Future: CHAMPION / LORD / ASCENDANT. |
| Phase labels | `PHASE 1` / `PHASE 2` / `PHASE 3` | 10 px caps. |
| Phase-imminent telegraph | (none — visual pulse only) | — |
| Boss-defeated title card | `The Warden falls.` | `{MobDef.display_name} falls.` template. Wordmark font. |
| Boss-defeated subtitle | `STRATUM 1 CLEARED` | Muted parchment, 12 px caps. |

## Cross-references

- `team/uma-ux/hud.md` §6 — regular mob nameplate spec (this doc extends it for bosses).
- `team/uma-ux/death-restart-flow.md` — the ember-rising particle authored once, reused here for boss dissolve.
- `team/uma-ux/palette.md` — every hex used.
- `team/DECISIONS.md` 2026-05-02 — M1 death rule (equipped kept, inventory lost on next death).
- `team/priya-pl/mvp-scope.md` — M1 acceptance criterion #6 (stratum-1 boss exists; player can defeat it).

## Hand-off

- **Drew (`86c9kxx4t`):** boss state machine drives `BossIntroSequence` via signals. Phases 1/2/3 transition at 66% and 33% HP — Drew picks the internal HP weights freely (segments lie about HP-equality on the bar by design). Boss `MobDef` exposes `display_name` (used in nameplate + title card), `is_boss: bool`, and `phase_count: int`. The boss music loop and the boss-wake stinger are M1 placeholders — Drew picks any free-asset stand-in or Uma will source.
- **Devon:** `BossNameplate.tscn` (480×56, anchored top-center HUD canvas), `BossIntroSequence.tscn` (CanvasLayer with door-slam camera-zoom nameplate-slide), `BossDefeatedSequence.tscn` (time-freeze + dissolve + title card). Boss music routing through the existing `MusicBus` autoload. The skip flag is per-character: `Player.first_boss_kill_seen: bool`.
- **Tess:** the boss-defeated sequence is **acceptance-critical for M1 #6**. Test cases below cover the full path. Soak run after the kill should verify the door unlocks, ambient resumes, and the player can pick up + equip the loot drop.

## Open questions

1. **Boss display name (`WARDEN OF THE OUTER CLOISTER`):** Uma's working name. Drew has authority to rename via boss TRES.
2. **Phase HP weights:** Drew's call. Recommend not making them equal — phase 3 is shorter and frantic; phase 1 is the longer "learn-the-pattern" phase.
3. **Skip-after-first-kill flag:** propose per-character (saves to disk). M2 retro: maybe per-stratum-per-character so first-kill of each stratum's boss is unskippable.
4. **Boss attack patterns:** Drew owns. This doc only constrains *"boss does NOT attack during Beats 1–4 (intro)."*

---

## Tester checklist (yes/no)

Per `team/TESTING_BAR.md`.

| ID    | Check                                                                                                       | Pass criterion (yes/no) |
|-------|-------------------------------------------------------------------------------------------------------------|-------------------------|
| BI-01 | Crossing boss-room threshold triggers door-slam audio (`door_slam_heavy.ogg`) within 1 frame                | yes                     |
| BI-02 | Door behind player visually transitions to a "locked" sprite state with 1-frame ember-flash on the lock     | yes                     |
| BI-03 | Stratum-1 ambient music fades to 0% over ~0.6 s                                                             | yes                     |
| BI-04 | Room vignette deepens from default 30% to 70% over ~0.6 s                                                   | yes                     |
| BI-05 | Camera eases in to 1.25× internal pixel scale over ~0.6 s, centered between player and boss                 | yes                     |
| BI-06 | Boss sprite plays its wake animation (~0.5 s) and `boss_wake_stratum1.ogg` plays at T+0.6                   | yes                     |
| BI-07 | Boss nameplate slides down from screen top over ~0.4 s, anchored top-center, 12 px from top edge            | yes                     |
| BI-08 | Nameplate is 480×56 px, `#1B1A1F` at 92% opacity, 1 px ember-orange border                                  | yes                     |
| BI-09 | Nameplate shows boss name from `MobDef.display_name` (M1: `WARDEN OF THE OUTER CLOISTER`) in 16 px caps     | yes                     |
| BI-10 | Threat label reads `THREAT: ELITE` in muted parchment 12 px caps                                            | yes                     |
| BI-11 | Health bar is 3 visually-equal segments divided by 2 px ember-orange separators                             | yes                     |
| BI-12 | Phase labels `PHASE 1` / `PHASE 2` / `PHASE 3` render above each segment                                    | yes                     |
| BI-13 | Active phase's segment uses `#7A2A26` foreground with ghost-damage drain over ~0.6 s                        | yes                     |
| BI-14 | Future-phase segments stay at 100% fill at 60% brightness; completed segments stay at 0 fill                | yes                     |
| BI-15 | At <10% HP in current phase, active segment pulses (1 px ember-orange outline at 1.5 Hz)                    | yes                     |
| BI-16 | Phase transition at 66% HP triggers world-time-slow to 30% for 0.6 s                                        | yes                     |
| BI-17 | Phase transition at 33% HP triggers world-time-slow to 30% for 0.6 s                                        | yes                     |
| BI-18 | Phase break audio `phase_break_stratum1.ogg` plays on each transition; separator flashes ember 0.3 s        | yes                     |
| BI-19 | Boss does NOT attack during intro Beats 1–4 (T+0.0 → T+1.8 s)                                               | yes                     |
| BI-20 | HUD top-right region flips to red `STRATUM 1 · BOSS` treatment during the fight                             | yes                     |
| BI-21 | After first boss kill of character's lifetime, intro is skippable on subsequent fights via movement key     | yes                     |
| BI-22 | First-ever boss fight: intro is NOT skippable                                                               | yes                     |
| BI-23 | On boss HP=0, time freezes for 0.3 s; combat + boss music cut hard; bell strike at T+0.1                    | yes                     |
| BI-24 | Boss sprite dissolves into upward-rising embers over 0.9 s with `boss_kill_horn.ogg`                        | yes                     |
| BI-25 | Title card `The Warden falls.` (or `{name} falls.`) appears at T+1.2; subtitle `STRATUM 1 CLEARED`          | yes                     |
| BI-26 | Boss loot drops at the boss's last position at ~T+1.6 with standard pickup audio + light-beam VFX           | yes                     |
| BI-27 | Door behind player unlocks with `door_unlock_chime.ogg` + 1-frame ember-flash on the lock-bar               | yes                     |
| BI-28 | Stratum-1 ambient resumes at 60% volume after Beat F4                                                       | yes                     |
| BI-29 | Player can pick up + equip boss loot post-kill; equipped items persist on next death (per M1 death rule)    | yes                     |
| BI-30 | M1 acceptance #6 (stratum-1 boss exists, defeatable) verified end-to-end via full intro → kill flow         | yes                     |
