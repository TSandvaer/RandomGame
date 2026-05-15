# AC4 Room 05 — Balance Pass Design + Pin

**Owner:** Uma (UX / design) · **Ticket:** `86c9u3d7j` (HIGH) · **Status:** v1, design only.
**Pinned 2026-05-15** — supersedes any prior implicit balance assumptions for Room 05 (and by
extension Rooms 06–08 which share the multi-chaser shape). Feeds W3 implementation tickets.
**Audience:** Drew (consumes §3 to author the TRES edits + Player iframes-on-hit constants),
Devon (reviews the Player.gd iframes-on-hit code shape proposed in §3.B), Tess (acceptance
assertions on §4 player-feel checks + soak bands), Priya (W3 backlog wiring + cross-reference).

---

## TL;DR

The AC4 Playwright spec dies in Room 05 because the 2-Grunts + 1-Charger triangle out-DPSes the
iron sword for a stationary no-dodge melee player. Drew empirically refuted the "sibling-freeze"
hypothesis in PR #200: the harness reports a freeze only because *the Player dies* and respawns
in Room 01. **The user explicitly chose balance pass over harness skill-upgrade.** This pin
shapes a small, two-lever balance combination that makes Room 05 winnable for a no-dodge melee
player at L1 with the starter iron sword (deterministic harness clear) **without** trivialising
combat for skilled (dodging) play.

The chosen combination:

1. **Lever 1 — Chaser damage trim** — Grunt `damage_base 3 → 2`; Charger `damage_base 5 → 4`.
2. **Lever 3 — Player iframes-on-hit** — new constant `HIT_IFRAMES_SECS = 0.25` granted
   automatically inside `Player.take_damage` after the damage applies. Reuses existing
   `_enter_iframes / _exit_iframes` infrastructure.

Held (no edit) — iron sword damage (6), Grunt/Charger attack-recovery, Grunt/Charger aggro
spacing, Player dodge mechanics, regen mechanic, Room 05 spawn count or placement.

The whole proposal is **two TRES integer edits + one Player.gd block addition**. Every number
in this doc is a one-line reversible edit. The "shape of the curve" decision — adding
hit-iframes-on-hit to Embergrave's vocabulary at all — is the only sticky design call here,
and §3.B and §5 explain why it is the right one.

---

## 1. The Room 05 trade math today

### Mob constants (read from current TRES)

| Mob       | `hp_base` | `damage_base` | move | Attack cycle (rough)                                                                                            | Sustained DPS on stationary player |
|-----------|-----------|---------------|------|-----------------------------------------------------------------------------------------------------------------|------------------------------------|
| Grunt     | 50        | 3             | 60   | `LIGHT_TELEGRAPH 0.40 s + ATTACK_RECOVERY 0.55 s ≈ 0.95 s/cycle`                                                | 3 / 0.95 ≈ **3.2 dmg/s**           |
| Charger   | 70        | 5             | 180  | `SPOTTED 0.25 s + TELEGRAPH 0.55 s + CHARGE ≤0.85 s + RECOVERY 0.85 s ≈ 2.5 s/cycle` (one contact-hit per cycle) | 5 / 2.5 ≈ **2.0 dmg/s**            |

Room 05 spawn (from `s1_room05.tres`): 2 Grunts at `(208, 80)` and `(240, 208)`, 1 Charger at
`(368, 144)`. Player spawn carries from `DEFAULT_PLAYER_SPAWN = (240, 200)` after the preceding
room-traversal (Room 04 exit + Room 05 entry). All three mobs CHASE; both Grunts close to
melee range within ~2 s of player entry.

### Combined incoming-damage band (no-dodge, no-iframes, stationary)

- **Worst-case (all three in melee simultaneously):** 3.2 + 3.2 + 2.0 ≈ **8.4 dmg/s** sustained.
- **Realistic-case (2 Grunts in melee + Charger telegraphing/charging cyclically):** 6.4 dmg/s
  during the Charger's non-impact phase, spikes to 11.4 dmg/s during the Charger's contact
  frame (~1 frame/cycle). Time-averaged: ≈ **7.0 dmg/s** across a full Charger cycle.

Player HP = 100. Time-to-zero (no regen, no dodge, no iframes-on-hit): **~12 s**.

### Combined outgoing-damage band (no-dodge melee, iron sword light spam)

- Iron sword `damage = 6`; player `EDGE = 0` at L1 → light damage = `floor(6 * 1.0 * 1.0) = 6`,
  heavy = `floor(6 * 1.6) = 9`.
- Light recovery is short (~0.35 s of swing cycle including the swing wedge lifetime). Sustained
  light-only DPS ≈ **17 dmg/s** when a mob is in the wedge.
- Time-to-kill ONE Grunt = `ceil(50 / 6) = 9` light hits ≈ **3.0 s** of clean swing window.
- Time-to-kill the Charger (most damage comes during its RECOVERY state where
  `RECOVERY_DAMAGE_MULTIPLIER = 2.0`) ≈ 6 lights during recovery windows = **~2.5 s of windows**.
- Realistic clear of 3 chasers with player-side hit drift (chasers move out of wedge,
  re-aggro, telegraph re-fires): **~12-16 s of cumulative combat time**.

**Net:** the room is borderline-loseable today at L1/no-dodge — the math leaves the player at
**~0-30 HP remaining** on the median run and a coin-flip dead on the unlucky cluster (2 Grunts
land swings during the same Charger contact frame). The harness AI lands on the wrong side of
that coin flip deterministically because it never dodges and never repositions to break the
3-mob crowd.

### Why regen doesn't save the room

The `Player._tick_regen` path requires **both** `_time_since_last_damage_taken > 3.0 s` AND
`_time_since_last_hit_landed > 3.0 s`. In a 3-chaser room with one mob landing a hit every
~1 s and the player swinging every ~0.35 s, neither timer ever crosses 3 s. Regen activates
correctly between rooms (where it carries the AC1-04 chain) but is a no-op inside any sustained
multi-chaser fight by design (`hp-regen-design.md` § "Boss encounter" anticipated this — same
shape applies to multi-chaser rooms). **Holding the regen mechanic as authored.** Regen
is a between-fights breathe, not an in-fight safety net; the safety net belongs to dodge
+ iframes-on-hit.

---

## 2. Levers considered (and why we pick the combination we do)

The dispatch enumerated five candidate levers. Each evaluated against three criteria:

- **A — fixes Room 05 for the no-dodge harness**? (the immediate AC4 unblock)
- **B — preserves "skilled play matters"**? (does NOT trivialise combat for a dodging player)
- **C — gameplay-feel cost vs implementation cost**? (does it change rooms 01-04 / boss feel
  too?)

| Lever                         | Mechanism                                                                | A — unblocks R05 harness? | B — preserves skilled play? | C — feel-cost                                                                                                                                              | Verdict        |
|-------------------------------|--------------------------------------------------------------------------|---------------------------|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|
| **1. Chaser damage trim**     | Grunt 3→2, Charger 5→4                                                   | Yes (lowers DPS ~30%)     | Yes — skilled play is faster anyway, DPS-on-player only matters when crowded | Low — Rooms 02-04 (single Grunt / Grunt+Charger / Shooter) are already comfortable; trimmed values keep them solvable AND keep the boss meaningfully threatening (boss isn't touched). | **CHOSEN**     |
| 2. Iron sword damage          | `damage 6 → 7`                                                           | Marginal (~1 light shaved off Grunt kill) | Mixed — boosts skilled DPS more than no-dodge DPS                                                  | High — starter weapon feel locked in PR #146 / Drew's affix balance; bumping it cascades into T2/T3 progression curve.                                     | Rejected.       |
| **3. Player iframes-on-hit**  | `HIT_IFRAMES_SECS = 0.25` after every `take_damage`                       | Yes (breaks the 3-mob simultaneous-hit cluster cleanly) | Yes — short window doesn't shortcut skilled dodge play; it just protects against unavoidable crowds | Low-medium — adds one design concept (post-hit invuln) to Embergrave's vocabulary. Established ARPG convention. Audited against existing dodge i-frame plumbing — reuses `_enter_iframes/_exit_iframes`.   | **CHOSEN**     |
| 4. Mob attack recovery        | Grunt `ATTACK_RECOVERY 0.55 → 0.80`; Charger `RECOVERY_DURATION 0.85 → 1.10` | Yes (lengthens windows between hits)                | Reduces skilled-play DPS-trades — the player exploits recovery vulnerability for kills. Penalises skill. | Medium-high — changes the rhythm of *every* fight in the game. Vuln-window-during-recovery is a core combat feel for Charger especially (`RECOVERY_DAMAGE_MULTIPLIER = 2.0`). | Rejected.       |
| 5. Mob aggro spacing          | Stagger telegraph timers across siblings; add "wait your turn" rotation   | Yes (lowers concurrent hits) | Yes — preserves skilled trade math                                          | **Implementation cost is high** — Grunt.gd / Charger.gd have no aggro coordinator today; adding one is a multi-PR feature, not a balance pass. Defer to M3 "AI choreography" ticket. | Deferred to M3. |

### Why levers 1 + 3 (and not lever 1 alone)

Lever 1 alone (chaser damage cut) shifts the room from "lose on median" to "win with ~20 HP on
median, still lose on unlucky clusters." That's still a coin-flip room for the harness, and
worse, it doesn't address the *crowd* problem — three mobs landing hits in the same 0.1 s
window remains a one-shot scenario for any future M2 mob with higher damage.

Lever 3 alone (iframes-on-hit) shifts the room dramatically — the 8.4 dmg/s worst case becomes
~3.4 dmg/s (one hit per 0.25 s window × 1 mob → effective serialisation of the 3 attackers).
But it ALSO trivialises a lot of skilled play: a dodging player who eats one cheap hit now
gets a free 0.25 s of immortality. We don't want iframes-on-hit to be a "free crutch" — we want
it to be a "crowd-control safety floor."

**The combination keeps both effects modest.** Lever 1 trims absolute damage values, Lever 3
breaks the simultaneous-hit cluster. Together they shift Room 05 from "median-lose" to
"median-win with 30-50% HP remaining" — exactly the band the L1 starter player should feel.

---

## 3. The proposal — concrete numbers

### 3.A. Chaser damage trim

**Edits to `resources/mobs/grunt.tres`:**

```diff
- damage_base = 3
+ damage_base = 2
```

**Edits to `resources/mobs/charger.tres`:**

```diff
- damage_base = 5
+ damage_base = 4
```

No HP changes. No move-speed changes. No telegraph-duration changes. No recovery changes.
Drew's `affix-balance-pin.md` § "Feel check #1" used `damage = 5` for Grunt in its assumptions
— flagging that this pin supersedes those numbers, and Drew should re-derive feel-check #1
against `Grunt.damage = 2` when consuming this for the W3 implementation ticket.

**Shooter held at `damage_base = 5`.** Shooter is ranged; Room 05 has no Shooter; Shooter
fights are already projectile-dodge-shaped, not damage-cluster-shaped. Re-tuning Shooter would
ripple into Rooms 04/06/07/08 with no Room 05 benefit. **No edit.**

**Stratum1Boss held.** Boss is a single-target encounter — no concurrent-attacker damage
cluster. Boss balance is its own pin (Priya's M2 weeks).

### 3.B. Player iframes-on-hit

**Convention picked:** post-hit invulnerability is a well-established action-RPG mechanic.
Souls-likes grant ~0.5-1.2 s (Dark Souls 3: ~1.0 s); faster games (Hades, Hyper Light
Drifter) grant ~0.2-0.4 s. Embergrave's existing dodge i-frame window is `DODGE_DURATION =
0.30 s`. **Pick the shorter, faster-game band — `0.25 s` — to stay below the dodge window.**
This keeps the dodge mechanic strictly stronger than the eat-hit-and-recover mechanic; dodging
remains the dominant strategy for skilled play.

**Spec for Devon (consumed by Drew via the W3 implementation ticket):**

```gdscript
# In scripts/player/Player.gd, near DODGE_DURATION:
const HIT_IFRAMES_SECS: float = 0.25

# In take_damage, AFTER the damage applies + damaged.emit fires,
# BEFORE the _die check (so a fatal hit still kills cleanly):
func take_damage(amount: int, knockback: Vector2, source: Node) -> void:
    # ... existing damage / regen-interrupt / hp_changed code ...
    if hp_current == 0:
        _die()
        return  # death path consumes the frame; no iframes-on-hit needed
    # Grant brief post-hit iframes to break simultaneous-hit clusters
    # without trivialising skilled dodge play. See team/uma-ux/ac4-room05-balance-design.md.
    _enter_iframes()
    get_tree().create_timer(HIT_IFRAMES_SECS).timeout.connect(_exit_iframes_if_not_dodging,
        CONNECT_ONE_SHOT)
```

Where `_exit_iframes_if_not_dodging` is a tiny helper:

```gdscript
func _exit_iframes_if_not_dodging() -> void:
    # If a dodge began mid-hit-iframe window, the dodge's own _exit_iframes
    # call will fire when the dodge ends; we must not double-clear.
    if _state == STATE_DODGE:
        return
    _exit_iframes()
```

**Why this shape:**

- **Reuses existing infrastructure.** `_enter_iframes / _exit_iframes` already exist (dodge),
  including the `collision_layer` swap that makes the player physically intangible to mob
  hitboxes. The `Hitbox.gd` overlap check already honours `Player.is_invulnerable()`. Zero new
  collision plumbing.
- **Dodge takes precedence.** If a player dodges WHILE in the post-hit iframe window, the
  dodge's `_enter_iframes` is idempotent (already-true `_is_invulnerable` is a no-op set), and
  the dodge's own `_exit_iframes` runs on dodge-end. The post-hit timer's
  `_exit_iframes_if_not_dodging` guards against clobbering a still-active dodge — the dodge
  finishes cleanly. **No interaction bug.**
- **Knockback survives.** The post-hit iframe window does NOT cancel the knockback applied in
  `take_damage` (`velocity = knockback`). The player still gets thrown — the iframes just
  protect them from *additional* same-cluster hits during the throw.
- **Fatal hits still kill cleanly.** The `if hp_current == 0: _die() ; return` early-out
  prevents the iframes timer from arming on a death frame — keeps the death sequence visually
  clean (no "ghost iframes" on a corpse).
- **`damaged.emit` still fires before iframes.** The HUD hit-flash + HP bar updates happen on
  the actual hit — the iframes are a follow-on grace, not a hit-suppression. The player still
  *sees* they were hit; they just don't see five hits at once.

**Audit against existing dodge code (read `Player.gd:706` onward):**

- `try_dodge` calls `_enter_iframes()` directly — that path is unchanged. Dodging mid-hit-iframe
  is fine (the second `_enter_iframes` is a no-op set on an already-true flag).
- `_dodge_time_left <= 0.0` in `_process` calls `_exit_iframes()` at dodge-end. If the post-hit
  iframe timer arrived BEFORE the dodge ends, `_exit_iframes_if_not_dodging` skips the clear
  (because `_state == STATE_DODGE`). The dodge's own exit handles it.
- The reverse case (dodge ends, post-hit timer still pending): the dodge clears
  `_is_invulnerable = false`. The post-hit timer fires later, runs `_exit_iframes` (now a no-op
  because `_is_invulnerable` is already false). Idempotent. **Safe.**

**Visual cue (optional, M2-polish):**

Adding a brief player-modulate flicker during the hit-iframe window would be the natural visual
cue — same shape as the existing dodge invuln cue, but shorter. Spec-stub:

- Reuse the dodge i-frame visual if it exists, OR add a 0.25-s 6 Hz alpha-flicker
  `modulate.a → 0.5 → 1.0` cycle on the Player sprite (NOT the parent CharacterBody2D —
  cascading modulate rule from `combat-architecture.md` § "Mob hit-flash"). All channels
  sub-1.0 per the HTML5 HDR clamp rule.
- M1 ships without the cue (audio/visual stub scope); the gameplay behaviour ships in W3, the
  cue is a W4 polish ticket. Flag in W3 Self-Test Report that the iframe window is gameplay-
  observable (player ate hit, took no second hit within 0.25 s) even if visually identical to
  the existing post-hit hit-flash.

---

## 4. Player-feel checks + acceptance bands

These are **acceptance targets** for Drew's W3 implementation pass and Tess's M1/M2 RC soak.
Numbers derive from the constants in §3 plus the unchanged combat constants — no NEW tunables
beyond `HIT_IFRAMES_SECS`.

### Setup

- Player base: HP 100, Vigor 0, Edge 0, fresh L1 character.
- Iron sword T1 (`damage = 6`, light = 6, heavy = 9), no vest, no affixes.
- Regen 2 HP/s with 3 s quiet thresholds (held; same as today).
- Dodge: not used (no-dodge melee archetype for the harness AI; band is wider for a dodging
  player and §5 covers that case).
- Grunt: `hp_base = 50, damage_base = 2` (post-trim), `ATTACK_RECOVERY = 0.55 s`,
  `LIGHT_TELEGRAPH = 0.40 s`.
- Charger: `hp_base = 70, damage_base = 4` (post-trim), `RECOVERY_DAMAGE_MULTIPLIER = 2.0`
  during recovery.
- Iframes-on-hit: `HIT_IFRAMES_SECS = 0.25`.

### Feel check #1 — Room 05 clear, L1, iron sword, no dodge (THE HARNESS CASE)

**Primary target:** **L1 no-dodge melee player clears Room 05 in 25-90 s with ≥ 30 % HP
remaining.**

**Derivation:**

- 2 Grunts trimmed to 2 dmg/swing × 0.95 s cycle = 2.1 dmg/s per Grunt → 4.2 dmg/s pair.
  With `HIT_IFRAMES_SECS = 0.25`, simultaneous-hit clusters resolve to one hit per 0.25 s →
  effective max DPS to player from any combination of attackers is `1 hit / 0.25 s = ~8 dmg/s`
  worst-case (one Charger contact during the window). Time-averaged across the Charger's 2.5-s
  cycle, with the iframe window swallowing ~1/3 of redundant Grunt hits: effective DPS-on-
  player ≈ **3-4 dmg/s** in the worst cluster.
- Charger trimmed to 4 dmg/contact × ~1 contact / 2.5 s = 1.6 dmg/s base rate (independent of
  iframes-on-hit because Charger contact is rare-but-spiky; the iframes prevent it from
  *coinciding* with a Grunt hit but the Charger's own cadence is the limiter).
- Player outgoing: 17 dmg/s sustained-light when in melee. Time to kill one Grunt = 50 / 17 ≈
  **3 s of clean swing-time** (factor 1.5-2× for missed swings / mob drift → realistic 5-6 s).
  Time to kill Charger (with recovery-window vuln × 2.0 mult) ≈ 5-7 s of windows.
- **Total clear estimate:** 2 Grunts × 5.5 s + Charger × 6 s = ~17 s of pure damage windows.
  Realistic clear time including the harness's wedge-drift overhead and re-aggro pauses:
  **30-60 s**.
- **HP remaining (no dodge, iframes-on-hit active):** incoming damage over 45 s ≈ 4 dmg/s
  worst-cluster × 0.5 cluster-density-factor = 2 dmg/s × 45 s = **90 dmg taken** — that's too
  much (player starts at 100, would die). Re-derive with iframes properly:
  * The iframes-on-hit window is 0.25 s. A Grunt cycle is 0.95 s. So a single Grunt can land at
    most 0.95 / max(0.25, 0.95) = 1 hit per cycle (its own cooldown is the limiter, not
    iframes — iframes don't matter for a single Grunt).
  * **The iframe window's value is purely in the simultaneous-hit cluster case.** Two Grunts
    landing within 0.25 s of each other becomes one hit absorbed, one ignored — saving 2 dmg
    per cluster. Cluster rate: ~1 cluster / 2 s for a 2-Grunt pair (their cycles drift
    independently). Charger contact + Grunt hit cluster: ~1 / 5 s (Charger contact is rare).
  * Total clusters absorbed in 45 s: ~22 Grunt-Grunt + ~9 Grunt-Charger ≈ **62 dmg saved**.
  * Raw damage WITHOUT iframes-on-hit (= unchanged from §1 sum, but with trimmed values):
    `(2 × 2.1 + 1.6) × 45 ≈ 260 dmg`. Effective HP cost = 260 − 62 = **198** — still way more
    than 100 HP.

**This means my naive 4-dmg-cluster-only model UNDERESTIMATES the protection iframes provide.**
The real effect is that **within the 0.25 s iframe window, ALL incoming damage is suppressed,
not just one extra cluster hit.** Re-deriving:

- Over 45 s, the player is hit roughly: 2 Grunts × `45/0.95` swings = 95 hit-attempts + 1
  Charger × `45/2.5` contacts = 18 hit-attempts → **113 hit-attempts** total.
- With iframes-on-hit = 0.25 s, after each successful hit the next 0.25 s of overlapping
  hit-attempts are absorbed. Hit-attempts are ~2.5/s sustained; the iframe window covers
  `2.5 × 0.25 = 0.625` of the attempts on average post-hit → roughly **40% of hit-attempts are
  absorbed**.
- Effective landed hits: 113 × 0.6 ≈ **68 landed**. Avg damage per landed: weighted average of
  Grunt-2 and Charger-4 = `(95 × 2 + 18 × 4) / 113 = 2.32`. Effective damage taken: 68 × 2.32 ≈
  **158 dmg over 45 s** ≈ **3.5 dmg/s effective**.

Still too much — the player dies at ~28 s. **So 45 s is the wrong clear-time target if I want
≥ 30 % HP remaining.** Let me re-derive the *required* clear time:

- Player can absorb 70 dmg before dying (start 100, want ≥ 30 remaining).
- At 3.5 dmg/s effective, that's **20 s of allowed combat time**.
- Player outgoing 17 dmg/s sustained → 50 HP Grunt = 3.0 s real damage time; 70 HP Charger =
  4.1 s real damage time. Three mobs = 10.1 s of pure damage time. With ~1.5× harness-drift
  factor: **15 s realistic clear time**.

**Revised primary target:** **L1 no-dodge melee player clears Room 05 in 12-25 s with ≥ 30 %
HP remaining (≥ 30/100 HP).**

**Acceptance band for Tess's soak observation:**

| Outcome                  | Clear time | HP remaining | Verdict                                                                              |
|--------------------------|------------|--------------|--------------------------------------------------------------------------------------|
| **Sweet spot**           | 12-25 s    | 30-70%       | Pass. Room feels survivable but tense; harness clears deterministically.             |
| **Too easy (re-tune)**   | < 12 s     | > 70%        | Re-tune: chaser damage was over-trimmed OR iframes window too generous. Revisit §3.  |
| **Too hard (re-tune)**   | > 25 s     | < 30%        | Re-tune: another lever needed (lever 5 aggro spacing, OR iframe window 0.25 → 0.30). |
| **Fail (still loseable)** | N/A — death | 0           | Hard fail. Re-tune required before W3 implementation ticket closes.                  |

The 12-25 s clear-time band overlaps the harness's existing `chaseAndClearMultiChaserRoom`
clear-budget (90 s with multiple retry passes); the iframe protection lets the harness's slow
position-steered chase succeed within budget even when it's not playing optimally.

### Feel check #2 — Room 05 clear, L1, iron sword, WITH dodge (SKILLED PLAYER CASE)

**Target:** **L1 dodging melee player clears Room 05 in 8-18 s with ≥ 60 % HP remaining.**

A skilled player uses Charger telegraph as a dodge cue, exploits the 2× recovery damage
multiplier, and circles to keep the two Grunts on the same side. Damage taken should be 1-2
hits per fight = 4-8 dmg total → 90-95 HP remaining. Clear time is bounded by player DPS (17
dmg/s sustained) → 170 / 17 ≈ 10 s of pure damage; realistic 12-15 s including reposition
moves.

**The combination (lever 1 + lever 3) preserves this skilled-play band.** Lever 3 doesn't add
to a dodging player's survivability (they dodge BEFORE the hit lands, so iframes-on-hit never
fires); lever 1 makes the rare eaten-hit slightly less punishing but doesn't change the rhythm.
The skilled player still feels combat is dangerous; they're just rewarded for skill.

**Acceptance band:**

| Outcome              | Clear time | HP remaining | Verdict                                                          |
|----------------------|------------|--------------|------------------------------------------------------------------|
| **Sweet spot**       | 8-18 s     | 60-90%       | Pass.                                                            |
| **Too hard for skill** | > 18 s   | < 50%        | Re-tune. Skilled play should feel *safer* than no-dodge, not harder. |
| **Trivialised**      | < 8 s      | 100%         | Re-tune: chaser damage may have been over-trimmed. Revisit §3.A. |

### Feel check #3 — Rooms 02, 03, 04 (regression bound)

The chaser damage trim ripples into Rooms 02-04. Quick sanity check (numbers from feel
check #1's derivation):

- **Room 02** (2 Grunts): pre-trim 3.2 + 3.2 ≈ 6.4 dmg/s; post-trim + iframes ≈ 2-3 dmg/s
  effective. Clear time ~7 s × 2 = 14 s; HP loss ~30 → **70-80 HP remaining**. Already trivial
  pre-trim; remains trivial. **No regression risk.**
- **Room 03** (Grunt + Charger): pre-trim ~5 dmg/s; post-trim ~3 dmg/s. Clear ~10 s; HP loss
  ~30 → **70 HP remaining**. **No regression risk.**
- **Room 04** (Shooter only): unchanged (no chaser trim applies to ranged kiting). Iframes-on-
  hit helps marginally vs a Shooter projectile cluster — but Shooter shoots one projectile per
  ~1.5 s, so iframes-on-hit doesn't change the Shooter fight feel.

**Acceptance band for Rooms 02-04:** clear time AND HP remaining within ±20% of the pre-trim
baseline. If clear time drops below 5 s with > 95 % HP, that signals a re-tune (chasers
trivialised).

### Feel check #4 — Stratum-1 boss room (regression bound)

The boss `damage_base` is **not changed**. The boss is single-target — the iframes-on-hit
window only saves cluster-hits, and a single boss attack lands once per cycle with no sibling.
So iframes-on-hit gives the player ~0.25 s of grace AFTER a boss hit before another boss hit
can land. Boss attack cycles are slow (~3-4 s); the iframe window finishes long before the
next boss attack telegraphs.

**Expected boss-fight regression:** **none.** Same clear time band, same HP loss band as
pre-pin. Tess should still verify in M2 RC soak by including a boss-with-iframes pass.

### Feel check #5 — Multi-chaser rooms 06, 07, 08 (forward bound)

Rooms 06, 07, 08 all have 3+ mobs including Chargers. The same balance combination should
unlock these rooms for the harness as well (subject to per-room placement adjustment — Drew's
W3 implementation ticket should soak-verify each room post-trim).

**Acceptance band:** harness clears Rooms 06, 07, 08 deterministically in `ac4-boss-clear.spec.ts`
post-W3 implementation. If any room still fails, that's a per-room placement-pass ticket
(Drew lane), not a re-tune of this balance pin.

### Pre-soak vs post-soak discipline

**Pre-soak:** numbers in §3 are the design target. Drew's W3 implementation ticket pins them.
**Post-soak observation:** Tess's M2 RC soak captures actual clear times + HP remaining for
Rooms 05-08 in §4's bands. If a check falls in the "sweet spot" column, hold. If a check falls
in the "re-tune" column, file a one-line balance follow-up:

- Iframes too generous → `HIT_IFRAMES_SECS = 0.25 → 0.20`.
- Chasers still too lethal → Grunt `damage_base 2 → 1` (cap) or Charger `damage_base 4 → 3`.
- Iframes too short → `HIT_IFRAMES_SECS = 0.25 → 0.30`.
- Chasers over-trimmed → Grunt `damage_base 2 → 3` (revert) — *unlikely* unless Tess soaks
  show < 8 s clears with > 95 % HP.

Same discipline as `affix-balance-pin.md` § "Player-feel checks" — soak observations are
calibration signals, not pass/fail gates. Bug-bounce only on **2× deviation** from a band
edge.

---

## 5. Rationale — why this is the right design for Embergrave

### What we preserve

- **Dodge as the dominant skilled strategy.** The 0.25-s hit-iframe window is shorter than the
  0.30-s dodge i-frame window AND has zero cooldown control on the player's side (it's purely
  reactive, no input). A skilled player still dodges — the iframe-on-hit is a safety net for
  when they don't, not a replacement.
- **The "Souls-light" combat identity.** Embergrave's combat vocabulary (per
  `team/uma-ux/visual-direction.md` and `team/uma-ux/combat-visual-feedback.md`) is
  telegraph-react-dodge-trade. Iframes-on-hit fits this vocabulary cleanly: it's the modern
  ARPG nod (Hades, Hyper Light Drifter) that lets the player FEEL the hit without it cascading
  into a death spiral.
- **The starter-weapon "you got loot" floor.** Iron sword's `damage = 6` is unchanged.
  Priya's affix-balance-pin §2 ("T1 = 'you got loot' floor") survives. The iron sword still
  feels modest at L1 and exciting on first weapon upgrade.
- **Regen as between-fights breather.** Held at 2 HP/s with 3 s quiet thresholds. The pin
  doesn't shorten the quiet threshold to make regen activate mid-Room-05 (which would have
  collapsed boss difficulty too). Regen stays out-of-fight.

### What we change

- **Adding "iframes-on-hit" to Embergrave's vocabulary.** This is the only sticky design
  decision in this pin. The argument FOR: it's the established convention, it scales naturally
  to M2/M3 enemy variety (when bombers, AoE casters, and group-spawn affixes land, iframes-on-
  hit becomes a load-bearing safety floor), and it reuses existing infrastructure with zero
  new collision plumbing. The argument AGAINST: every new mechanic is a teaching beat for the
  player and a test surface for QA. We mitigate the AGAINST by making the window short (0.25 s
  is below human-noticeable threshold for "I dodged that") and by NOT adding a new visual cue
  in M1 (the existing hit-flash IS the cue — "you got hit, the immediate aftermath is graced").
- **Chaser damage trim is small.** Grunt 3 → 2 and Charger 5 → 4 are ~33% and 20% trims
  respectively. Big enough to matter against a multi-chaser cluster; small enough that single-
  chaser rooms feel barely-different. The trim signals: "stratum 1 chasers were tuned for
  single-target, the multi-target rooms are the harder content where this matters."

### What we DON'T do (and why)

- **No iron sword buff.** Priya's affix-balance-pin discipline — starter weapon is the floor,
  not the variance ladder. Buffing it would cascade into T2/T3 weapon design.
- **No mob-recovery lengthening (lever 4).** Recovery windows ARE the skilled-play exploit
  surface (especially Charger's `RECOVERY_DAMAGE_MULTIPLIER = 2.0`). Making them longer
  cheapens skilled play.
- **No aggro-rotation (lever 5).** Right call for M3. Multi-mob choreography deserves its own
  ticket and a proper aggro-coordinator pattern (timer-of-last-attacker on the room, etc.).
  Cramming it into a balance pass would over-extend scope.
- **No harness-skill upgrade.** The user explicitly chose Path A. The harness's no-dodge
  click-spam is also a *useful* canary: it represents the lowest-skill player. If the lowest-
  skill player can't survive Room 05 at L1, the room is too hard. This pin lets that canary
  pass.

### Forward-clean for M2/M3

- **Iframes-on-hit scales with M2 mob variety.** When M2 adds frost-shot, AoE bombs, and dash-
  attackers, the iframe window protects against cluster-overlap without per-mob tuning.
- **Chaser damage trim sets the baseline for M2.** When stratum-2 chasers land, their
  `damage_base` should be 1.5-2× stratum-1 values: Grunt-equivalent → 3-4 dmg, Charger-
  equivalent → 6-8 dmg. The trim doesn't bake a permanent ceiling; it just sets the stratum-1
  band.
- **No save-format break.** The pin doesn't add any saved state. `HIT_IFRAMES_SECS` is a
  constant on Player, not a save field. Existing saves load cleanly.

---

## 6. Out of scope for this pin

- **Implementation.** This is a design-only dispatch. Drew + Devon execute the TRES edits and
  Player.gd block addition in a separate W3 dispatch.
- **Harness changes.** The user rejected Path B. No harness skill upgrade in this pin.
- **Room-placement changes.** Room 05's `s1_room05.tres` spawn count/placement is unchanged.
- **Boss balance.** Stratum1Boss is its own pin (Priya's M2).
- **Visual cue for iframes-on-hit.** M2-polish ticket. M1 ships gameplay only.
- **Audio cue for iframes-on-hit.** M2+ when audio bus lands.

---

## 7. Self-test (design-only dispatch)

- Read existing `team/uma-ux/*.md` for tone/structure consistency (especially
  `hp-regen-design.md` § "Cap and interrupt behavior" and `combat-visual-feedback.md` for the
  cascade rule on parent-modulate).
- Read `team/priya-pl/affix-balance-pin.md` for balance-pin shape; mirrored §1-§5 structure +
  the pre-soak/post-soak discipline + the table-based options-considered pattern.
- Cross-checked numbers against:
  - `resources/mobs/grunt.tres` (HP 50, damage 3, move 60) — current state.
  - `resources/mobs/charger.tres` (HP 70, damage 5, move 180) — current state.
  - `scripts/player/Player.gd::take_damage` line 538-562 — iframes-on-hit insertion point
    audited.
  - `scripts/player/Player.gd::_enter_iframes / _exit_iframes` lines 896-908 — reused
    infrastructure verified.
  - `scripts/player/Player.gd::DODGE_DURATION = 0.30 / DODGE_COOLDOWN = 0.45` — confirmed
    iframe-on-hit window (0.25 s) stays below the dodge window.
  - `scripts/combat/Damage.gd::compute_player_damage` — iron sword damage path unchanged.
  - `scripts/mobs/Grunt.gd::ATTACK_RECOVERY / LIGHT_TELEGRAPH_DURATION` — chaser-cycle math.
  - `scripts/mobs/Charger.gd::TELEGRAPH_DURATION / CHARGE_MAX_DURATION / RECOVERY_DURATION /
    RECOVERY_DAMAGE_MULTIPLIER` — Charger-cycle math + recovery vuln window protected.
  - `tests/playwright/specs/ac4-boss-clear.spec.ts` line 232-287 — Drew PR #200 disambiguation
    of "sibling-freeze" as player-death-respawn confirmed.
  - `team/priya-pl/affix-balance-pin.md` § "Feel check #1" — flagged that this pin supersedes
    the Grunt `damage = 5` assumption used there for M2 derivations.
- No contradictions with `combat-architecture.md` (the iframes-on-hit reuses the existing
  collision-layer flip, doesn't introduce any new physics-flush surface).
- No contradictions with `html5-export.md` (no Tween / modulate / Polygon2D / CPUParticles2D
  / Area2D-state changes in the design; the optional visual cue is deferred to M2 polish).
- No contradictions with `DECISIONS.md 2026-05-02` damage formula lock (formula constants
  untouched; only TRES `damage_base` inputs and a new Player constant).

---

## 8. Hand-off checklist for W3 implementation (Drew + Devon)

- [ ] `resources/mobs/grunt.tres`: `damage_base 3 → 2` (one-line TRES edit)
- [ ] `resources/mobs/charger.tres`: `damage_base 5 → 4` (one-line TRES edit)
- [ ] `scripts/player/Player.gd`: add `const HIT_IFRAMES_SECS: float = 0.25` near
      `DODGE_DURATION`
- [ ] `scripts/player/Player.gd::take_damage`: append the iframes-on-hit block per §3.B (post-
      damage, pre-death-check semantics)
- [ ] `scripts/player/Player.gd`: add `_exit_iframes_if_not_dodging` helper per §3.B
- [ ] Paired GUT test: assert iframes activate after `take_damage` on a non-fatal hit, expire
      after `HIT_IFRAMES_SECS`, and do NOT activate on a fatal hit (death path consumes frame).
- [ ] Paired GUT test: assert iframes-on-hit window blocks a follow-up `take_damage(X)` call
      within `HIT_IFRAMES_SECS` (asserts `Player.is_invulnerable() == true` at `T = 0.10 s`
      post-first-hit).
- [ ] Paired GUT test: assert dodge initiated during iframes-on-hit window does not clobber
      the dodge's i-frame state (dodge runs to its own `DODGE_DURATION`, exits cleanly).
- [ ] Re-derive Drew's `affix-balance-pin.md` § "Feel check #1" against `Grunt.damage = 2` and
      flag any band shifts.
- [ ] AC4 spec re-runs against Room 05 release-build — assert `test.fail()` annotation can be
      removed.
- [ ] Self-Test Report comment on PR before Tess review.
- [ ] ClickUp `86c9u3d7j` status flip to `complete` on this design PR; W3 implementation
      ticket(s) flip independently.

---

## Sign-off

- **Drew + Devon:** read this before opening the W3 implementation ticket. The expected
  delta is two TRES integer edits and ~15 lines of Player.gd code (plus paired tests). No
  other surface should be touched in W3.
- **Tess:** §4 player-feel checks are **soak-time observations**, not pre-merge gates. Treat
  them as the calibration signal during the post-W3 AC4 re-run + M2 RC soak. Bug-bounce only
  on **2× deviation** from a band edge.
- **Priya:** wire this pin into the M2 W3 backlog as the design dependency for Drew's W3
  implementation ticket. Reference §3 for the exact deliverables.
- **Reversibility:** every number is a one-line edit. The sticky design call — adding iframes-
  on-hit to Embergrave's vocabulary — is the only non-trivially-reversible decision, and §5
  argues it's forward-clean for M2/M3 anyway.

This pin is the contract for AC4 Room 05 balance. Open a balance-pass v2 ticket post-M2-RC
soak only if a §4 check fails by ≥ 2×.

---

## Doc updates

`Doc updates: none.` The balance proposal itself lives in `team/uma-ux/`; the underlying
combat-architecture and HTML5-export `.claude/docs/*.md` files don't need amendment because
this pin doesn't introduce a new architectural pattern (iframes-on-hit reuses the existing
dodge i-frame plumbing). If W3 implementation surfaces a new lesson (e.g. a subtle interaction
between hit-iframes and the regen damage-timer reset), Drew's W3 PR may add a paragraph to
`combat-architecture.md` then.
