# kiting-mob-chase case B "inside" sub-case audit — 2026-05-16

**Author:** Tess
**Trigger:** Devon's peer-review of PR #239 (harness-workaround convention adoption) flagged a finer-grained audit question that PR #239 itself deferred as out-of-scope.
**Status:** Analysis only — no code change in this dispatch.

## Background

PR #239 (`qa/harness-workaround-convention`, merged 2026-05-16) formalized §15 of
`team/tess-qa/playwright-harness-design.md` — **"Convention: harness workarounds
for known game-side bugs must fail loudly"** — and retired
`gateTraversalWalk`'s case B in `tests/playwright/fixtures/gate-traversal.ts` as
the inaugural application of the rule. The retirement was paired with PR #230
(`RoomGate._fire_traversal_if_unlocked`), which closes the underlying game-side
bug: when `_unlock()` runs while a `CharacterBody2D` is overlapping the gate
trigger, the gate now defers `_fire_traversal_if_unlocked` and auto-emits
`gate_traversed` one frame later — promoting what would have been case B to
case A.

PR #239 explicitly classified `kiting-mob-chase.ts`'s case A/B/C as
**out-of-scope** under the convention (harness-design.md §15, "Out of scope"
bullet at line 662):

> Game-mechanic-driven multi-outcome resolution — `kiting-mob-chase.ts`'s
> case A/B/C resolution models the **legitimate game behavior** of "Shooter
> walks player through gate during chase." All three outcomes are valid
> gameplay states; none represents a bug.

### Devon's audit gap

Devon's review comment (PR #239) accepted the §15 classification but flagged a
finer question:

> `kiting-mob-chase.ts` case B (lines 994-1001 + 1588-1596). Tess classified
> as out-of-scope; defensible IF the "player outside trigger at unlock"
> sub-case dominates. The "player inside" sub-case should now auto-resolve to
> case A via PR #230. Recommend post-merge telemetry probe to log sub-case
> frequency; if "inside" is near-zero, retire similarly.

The point is structurally correct: kiting-mob-chase case B has **two sub-cases**
discriminated by where the player was at unlock time:

- **Sub-case B-inside**: chase walked the player THROUGH the trigger while the
  kiter was alive; the kiter dies while player is still overlapping the
  trigger; `_unlock()` fires with player inside. **Post-PR-#230 this becomes
  case A** via the deferred re-emit. If it ever reaches the harness's case-B
  branch, that's either a PR #230 regression or a rare race.
- **Sub-case B-outside**: chase walked the player through and back out of the
  trigger before the kiter died; `_unlock()` fires with no overlapping body;
  gate sits UNLOCKED waiting for the player to re-enter. **PR #230 does NOT
  touch this path** — it's the legitimate game-mechanic-driven case. The
  harness's `finishTraversalFromUnlocked` steer-and-walk handles it correctly.

If B-inside is now zero (game-side fix consumes it), the harness branch is
half-dead — same shape as PR #239's retirement target. If B-inside is
non-trivial, the branch is still load-bearing for both sub-cases.

## Current case B structure

Two consumers of the case B branch exist in `tests/playwright/fixtures/kiting-mob-chase.ts`:

### Consumer 1 — `chaseAndClearKitingMobs` (single-kiter Shooter pursuit)

Lines 980-1015. Resolution branches:

```ts
if (gateTraversed) {
  // Case A — nothing to do.
} else if (gateUnlocked) {
  // Case B — gate is UNLOCKED; finish the traversal ourselves.
  gateTraversed = await finishTraversalFromUnlocked(...);
} else {
  // Case C — gate still OPEN; reposition the player at spawn.
  await returnToSpawn(...);
}
```

Exercised by `tests/playwright/specs/ac4-boss-clear.spec.ts` (Rooms 04, 06, 07,
08 — every room containing a Shooter) and `tests/playwright/specs/soak-narrative-regression.spec.ts`.

### Consumer 2 — `chaseAndClearMultiChaserRoom` (3-chaser pursuit)

Lines 1576-1609. Same A/B/C resolution as Consumer 1, reusing
`finishTraversalFromUnlocked` and `returnToSpawn`. Exercised by
`ac4-boss-clear.spec.ts` Room 05 (the 3-chaser room).

### Shared helper — `finishTraversalFromUnlocked`

Lines 635-699. Steers the player to `FINISH_TRAVERSAL_STAGE` (just east of the
trigger), settles, then walks pure-WEST across the trigger east edge to fire
`body_entered` → `gate_traversed`. This is the workaround mechanism.

### Note on consumer 2 (multi-chaser) — sub-cases differ from consumer 1

The chaser AI (`Grunt`, `Charger`) does NOT retreat through the gate; chasers
close toward the player. Player-into-trigger drift is driven by combat
knockback + chaser westward spawn pulling the engage west, NOT by chasing a
kiter through the gate. So consumer 2's sub-case mix differs from consumer 1's
— B-inside is empirically more common for consumer 2 because the player drifts
into the trigger DURING combat and is still there when the last chaser dies
(this is precisely the bug-shape `RoomGate._unlock` overlap re-check was added
to fix; consumer 2's header at lines 1537-1548 documents the Room 05 reality
that prompted the consumer-2 retrofit).

## Analysis (probe B — first-principles)

### Sub-case B-inside is consumed by PR #230 — analytically

`RoomGate._unlock()` (scripts/levels/RoomGate.gd lines 404-431) now executes:

```gdscript
gate_unlocked.emit()
if is_inside_tree() and not _traversed_emitted:
    for body in get_overlapping_bodies():
        if body is CharacterBody2D:
            call_deferred("_fire_traversal_if_unlocked")
            break
```

`_fire_traversal_if_unlocked` (line 438) checks `_state == STATE_UNLOCKED` and
`_traversed_emitted == false`, then emits `gate_traversed`. The deferred call
runs at the end of the current physics frame, well within the harness's
`GATE_SETTLE_WINDOW_MS` (2500 ms) poll loop — so when the harness samples
gate state after settle, `gate_traversed` will have already fired and the
helper picks case A, not case B.

**Conclusion:** for sub-case B-inside (player overlapping trigger at unlock
time), PR #230 deterministically routes execution to case A. Reaching case B
via the B-inside sub-case requires either:

- **(a) PR #230 regression** — `_fire_traversal_if_unlocked` did not fire even
  though a `CharacterBody2D` was overlapping. The fixture has no detection of
  this — it silently steers and the regression hides.
- **(b) Inter-frame race** — `_unlock` runs at frame N, samples
  `get_overlapping_bodies()` finding the player, defers
  `_fire_traversal_if_unlocked` to frame N+1. If the player exits the trigger
  during frame N's idle processing (between the body-overlap snapshot and the
  deferred call running), the helper's `_state == STATE_UNLOCKED` check still
  passes and `gate_traversed` still emits — so B-inside still resolves to A.
- **(c) Tree-detachment race** — `is_inside_tree()` returns true at unlock but
  the gate is freed before the deferred call runs. Theoretically possible
  during room transitions; practically the gate persists until the room is
  freed by `Main._on_room_cleared`, which is gated on `room_cleared` (which
  RoomGate emits when `gate_traversed` fires) — so the helper has already
  emitted before the free can run.

Cases (b) and (c) are vanishingly rare; (a) is what the convention exists to
detect, but the existing harness silently absorbs it.

### Sub-case B-outside is NOT consumed by PR #230

PR #230 only acts when `get_overlapping_bodies()` returns a body at unlock
time. If the chase walked the player through and back out of the trigger
before the kiter died, `_unlock` finds no overlapping body, does NOT defer,
and the gate sits UNLOCKED waiting for the player to walk back in. This is
the **legitimate game-mechanic-driven** sub-case — a kiter's pursuit path is
unpredictable, the harness must steer the player back through the trigger to
finish the traversal, no game-side bug is involved.

For consumer 1 (single Shooter), B-outside is plausible: the kiter retreats
through the gate, the player chases through and corners the kiter west of the
gate, the kiter is killed there → `_unlock` fires with the player outside the
trigger (west side). The chase header at line 925 explicitly says: "because
the chase usually leaves the player inside/near the now-unlocked trigger" —
emphasis on "usually," not "always." The B-outside fraction is non-zero by
design.

For consumer 2 (3-chaser), B-outside is implausible — chasers don't lead the
player west of the gate, knockback during combat drifts the player INTO the
trigger but doesn't push them west of it. Consumer 2 case B is dominantly
B-inside (the bug shape PR #230 fixed).

### Empirical asymmetry between the two consumers

This is the load-bearing finding: **the two consumers' B sub-case mix is
different**.

| Consumer | B-inside frequency (pre-PR #230) | B-outside frequency | Post-PR #230 case B reachability |
|----------|----------------------------------|---------------------|----------------------------------|
| `chaseAndClearKitingMobs` (single kiter) | Common — kiter routes player through trigger, kill happens with player still inside | Non-zero — kiter retreats through gate, player corners west of trigger | B-outside path still legitimately reachable |
| `chaseAndClearMultiChaserRoom` (3-chaser) | Dominant — combat-knockback drift + westward spawn pull leaves player inside trigger at last-mob-dies | Near-zero — chasers don't retreat through gate, no mechanism walks player west of trigger | Case B is now near-dead (only PR #230 regression cases) |

### Probe A would refine the table

A passive `console.log("[harness-audit] kiting-case-B-inside/outside")` probe
in both consumers' B branch, with B-inside vs B-outside discriminated by
checking `get_overlapping_bodies()` shape in a one-shot trace (or by
sampling player.pos against the trigger rect at unlock time from the
harness's `latestPos`), would let us measure the frequency over an N≥8 CI
sweep. But the analytical case for asymmetry is strong enough that the
verdict differs by consumer regardless of empirical refinement.

## Verdict

**Split verdict by consumer.**

### Consumer 1 (`chaseAndClearKitingMobs`) — **KEEP case B**

The B-outside sub-case is legitimately reachable (kiter pursuit can leave the
player west of the trigger when the kill lands), and case B's
`finishTraversalFromUnlocked` is the correct resolution for that scenario.
Retiring case B here would convert a legitimate game-mechanic-driven path
into a spec failure. The §15 classification as out-of-scope holds.

**Caveat:** B-inside hits in this consumer post-PR-#230 are masked. If we
want to catch the PR #230 regression class here, the cleaner mitigation is to
ADD a regression-detection assertion at the top of the B branch — sample
`get_overlapping_bodies()`-equivalent state at unlock time (or simply check
"did the player's pos at the gate_unlocked trace timestamp overlap the
trigger rect?") and `throw` if yes. The B-outside path then still resolves
silently; B-inside fails loud. This would be a §15-aligned upgrade that
keeps the legitimate game-mechanic handling.

### Consumer 2 (`chaseAndClearMultiChaserRoom`) — **CANDIDATE FOR RETIREMENT**

B-outside is implausible by chaser AI (no retreat path through gate).
Consumer 2's case B is dominantly the B-inside shape that PR #230 now
consumes. Reaching consumer 2's B branch post-PR-#230 is itself a regression
signal of the same class PR #239 retired for `gateTraversalWalk`.

This makes consumer 2's case B a §15 retirement candidate. The retirement
shape would mirror PR #239: convert the silent `finishTraversalFromUnlocked`
call to a hard `throw new Error("[multi-chaser] case B detected — PR #230
regression: player was overlapping trigger at unlock time but
_fire_traversal_if_unlocked did not auto-promote to case A. ...")`. Pull the
diagnostic-trace pattern from PR #239's gate-traversal.ts case B throw for
consistency.

**Risk:** very small chance of consumer 2 producing legitimate B-outside (say
a future chaser variant gets a retreat behavior, or some yet-undiagnosed
combat-knockback edge pushes the player west of trigger). Mitigation: the
hard-throw error message says "if a legitimate spec scenario produces this,
update the spec" — same release-valve PR #239 uses.

### Confidence

- B-inside-is-consumed analysis: **high** — directly traceable from
  `RoomGate._unlock()` source and the deferred-call timing matches the
  harness's settle window.
- Consumer 1 B-outside is reachable: **high** — kiter retreat geometry +
  the chase header's "usually" language.
- Consumer 2 B-outside is near-zero: **medium-high** — chaser AI does not
  retreat through gate, no mechanism walks player west of trigger; one
  uncertainty is exotic combat-knockback edges.

## Recommendation

**For Sponsor's queue (one ticket per consumer):**

### Ticket 1 — Retire consumer 2 case B (high confidence, low risk)

Convert `chaseAndClearMultiChaserRoom` lines 1586-1601 case B branch to a
hard throw, mirroring the PR #239 `gateTraversalWalk` retirement pattern.
Scope: one fixture, ~30 lines diff including the throw's diagnostic-trace
construction. Risk: low — chaser AI does not produce B-outside.
Self-mitigating via the hard-throw error message that documents the
"update the spec" release valve.

### Ticket 2 — Add regression-detection upgrade to consumer 1 case B (lower priority)

Keep case B's `finishTraversalFromUnlocked` resolution path (legitimate
B-outside still reachable) but ADD a pre-check that infers sub-case from
the gate_unlocked trace timing + player.pos at unlock-time. Throw if
B-inside is detected (= PR #230 regression). The B-outside path resolves
silently as today.

Scope: more involved than Ticket 1 — requires player-pos trace lookup
bounded to the gate_unlocked timestamp, regex over Player.pos lines, rect
overlap math. ~60-80 lines diff. Risk: low (additive guard, existing path
unchanged). Could ship paired with a single-spec verification under N≥8 to
confirm no false positives during typical AC4 runs.

### Optional follow-up — Probe A empirical refinement

If Sponsor wants empirical evidence before committing to either ticket,
ship a passive `console.log("[harness-audit] case-B-inside")` /
`[harness-audit] case-B-outside` probe in both consumers, run a N≥16 CI
sweep across `ac4-boss-clear.spec.ts` + `mob-self-engagement.spec.ts` +
`soak-narrative-regression.spec.ts`. Count B-inside vs B-outside per
consumer. Decision threshold: if consumer 2 logs zero B-outside across
N≥16 runs, the retirement risk is empirically null. If consumer 1 logs
non-zero B-outside, the keep-with-upgrade verdict for Ticket 2 is
confirmed.

Cost: ~10 lines of probe code per consumer + one CI sweep (~30 min wall).
Benefit: empirical N over analytical confidence. **Not required to act on
Ticket 1** — analytical confidence is high enough — but useful as a small
investment before Ticket 2 design.

## Cross-references

- **PR #239** (`qa/harness-workaround-convention`, commit fcc7d13) — convention
  adoption + `gateTraversalWalk` case B retirement (the inaugural application).
- **PR #230** (`fix(level|gate)`, commit 8d7d39a) — game-side
  `_fire_traversal_if_unlocked` deferred re-emit that consumes the B-inside
  sub-case.
- **Convention rule:** `team/tess-qa/playwright-harness-design.md` §15,
  especially line 662 (out-of-scope classification for kiting-mob-chase) and
  the "discriminator" sentence at line 665.
- **Fixture under audit:** `tests/playwright/fixtures/kiting-mob-chase.ts`
  lines 980-1015 (consumer 1) + 1576-1609 (consumer 2). Shared helper at
  lines 635-699.
- **Game-side source:** `scripts/levels/RoomGate.gd` lines 404-446
  (`_unlock` + `_fire_traversal_if_unlocked`).
- **Pinned GUT regression tests for PR #230:** `tests/test_room_gate.gd`
  lines 321, 343, 361 — `test_fire_traversal_if_unlocked_emits_gate_traversed`,
  `_is_idempotent`, `_noop_when_not_unlocked`. These protect the game-side
  fix; the harness retirement should rely on these holding.
