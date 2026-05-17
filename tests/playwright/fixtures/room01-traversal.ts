/**
 * room01-traversal.ts — Stage 2b Room01 traversal helper
 *
 * Encapsulates the harness-side discipline for clearing Stratum-1 Room01
 * post-PR-#169 (Stage 2b tutorial flow). Room01 changed from "2 grunts that
 * chase" to "1 PracticeDummy that doesn't chase" — every spec that traverses
 * Room01 now has to walk the player up to the dummy at world (368, 144) and
 * swing alongside it (the dummy doesn't close the gap on its own).
 *
 * **Why this is in fixtures (not duplicated per spec):** six harness specs
 * traverse Room01 (ac2/ac3/equip-flow/room-traversal-smoke/negative-assertion-
 * sweep Test 2/room-gate-body-entered-regression). Duplicating the
 * walk-NE-then-attack-sweep pattern in every spec invites drift the moment
 * Stage 2c shifts the dummy spawn position or HP; centralizing it means one
 * edit ripples to all callers.
 *
 * **iron_sword bandaid RETIRED (ticket 86c9qbb3k — this PR).** The PR #146
 * boot-equip bandaid is gone: the player drops in FISTLESS and the Room01
 * dummy poofs at FIST_DAMAGE = 1 (HP = 3 → 3 swings to kill). The dummy then
 * drops a guaranteed iron_sword Pickup; the player must WALK ONTO that
 * Pickup to auto-equip it (`Inventory.on_pickup_collected` →
 * auto-equip-first-weapon). The Room01 → Room02 advance is GATED on that
 * equip (`Main._on_room01_mob_died` holds the advance while the player is
 * fistless) — so this helper now has a Phase F pickup-collection step:
 * after the dummy dies it walks the player over the drop position until the
 * `[combat-trace] Inventory.equip | ... source=auto_pickup` line fires. The
 * Pickup also has an initial-overlap check (it collects against a player
 * already standing on the drop tile from the killing blow), so the walk is
 * belt-and-suspenders. `clearRoom01Dummy` returns `pickupEquipped` so callers
 * can assert the onboarding equip happened.
 *
 * **Spawn geometry rationale:** PR #169's `s1_room01.tres` places the dummy
 * at `position_tiles = (11, 4)` × `tile_size_px = 32` = chunk-local (352, 128),
 * which assembles to roughly world (368, 144) per Devon's empirical AC4
 * verification. From `DEFAULT_PLAYER_SPAWN = (240, 200)`, that's ~140px NE
 * on the diagonal. Two-axis walks at `WALK_SPEED = 120 px/s`:
 *   - Pure N for ~470ms covers Y from 200 → 144.
 *   - Pure E for ~1070ms covers X from 240 → 368.
 *
 * **Why separate-axis walks (not pure-NE diagonal):** empirical evidence from
 * PR #170/#172 AC4 work showed diagonal walks land the player wildly past the
 * dummy due to walk-speed × diagonal overshoot timing. Pure-axis walks are
 * easier to predict; the room walls clamp overshoots. We use slightly-longer
 * durations (700ms N, 1300ms E) for safety against any ticks that don't
 * register movement.
 *
 * **Why an attack-sweep (not single-direction click-spam):** the player's
 * swing has a fixed 28px reach + 18px hitbox radius = 46px effective range.
 * Once the player is adjacent to the dummy, the swing wedge needs to overlap
 * the dummy regardless of which side of the dummy the player ended up on
 * (overshoot/undershoot from the walk). Cycling through 8 directions
 * guarantees coverage.
 *
 * **Detection:** PR #169 emits `[combat-trace] PracticeDummy._die | starting
 * death sequence` on death. `Main._install_room01_clear_listener` hooks the
 * `mob_died` signal and auto-loads Room02 on death — no RoomGate involvement,
 * no body_entered required. Specs that need to know "we're now in Room02"
 * watch for this trace + a `waitForTimeout(~1500ms)` for Main's deferred
 * `_on_room_cleared` + scene load + player teleport + STATE_ATTACK recovery
 * clear (LIGHT_RECOVERY = 0.18s).
 *
 * References:
 *   - resources/level_chunks/s1_room01.tres (dummy spawn position)
 *   - scripts/mobs/PracticeDummy.gd (HP=3, mob_died signal)
 *   - scenes/Main.gd::_install_room01_clear_listener (room clear flow)
 *   - tests/playwright/specs/ac4-boss-clear.spec.ts (the originating
 *     Room01-traversal pattern this helper extracts)
 */

import type { Locator, Page } from "@playwright/test";
import type { ConsoleCapture } from "./console-capture";
import { clickAtWorldPos } from "./mouse-facing";

/**
 * 8-direction sweep covering every approach angle the player could have
 * landed in relative to the dummy after the walk-up phase.
 */
const SWEEP_DIRECTIONS: { keys: string[]; label: string }[] = [
  { keys: ["w"], label: "N" },
  { keys: ["w", "d"], label: "NE" },
  { keys: ["d"], label: "E" },
  { keys: ["s", "d"], label: "SE" },
  { keys: ["s"], label: "S" },
  { keys: ["s", "a"], label: "SW" },
  { keys: ["a"], label: "W" },
  { keys: ["w", "a"], label: "NW" },
];

/** Attack click cadence — must clear LIGHT_RECOVERY (0.18s) + physics frame. */
const ATTACK_INTERVAL_MS = 220;

export interface Room01ClearOptions {
  /**
   * Total wall-clock budget for the dummy-clear phase. Default 90 s — generous
   * so spec authors don't have to tune. Post-bandaid (fistless, damage=1) the
   * dummy poofs in 3 swings; real cost is typically ≤ 12 s + a few seconds for
   * the pickup-collection phase.
   */
  budgetMs?: number;
  /** Per-direction attack count during the sweep. Default 3. */
  attacksPerDir?: number;
  /**
   * Skip the Phase F pickup-collection step. Default false. Set true ONLY for
   * specs that deliberately want to leave the player fistless / leave the
   * Room01 → Room02 advance gated (none currently — the gate means Room02 is
   * unreachable without the pickup, so almost every caller wants the pickup).
   */
  skipPickup?: boolean;
}

export interface Room01ClearResult {
  dummyKilled: boolean;
  /**
   * True once the dummy-dropped iron_sword Pickup was collected AND
   * auto-equipped (the `[combat-trace] Inventory.equip | source=auto_pickup`
   * line was observed). When false after a non-skipped run, the Room01 →
   * Room02 advance gate is still closed and Room02 will not load.
   */
  pickupEquipped: boolean;
  durationMs: number;
  attacksFired: number;
}

/**
 * Walk the player from `DEFAULT_PLAYER_SPAWN = (240, 200)` to the Room01
 * PracticeDummy at world (~368, 144) and click-spam through an 8-direction
 * sweep until the dummy poofs. The helper handles its own death-detection
 * via the `[combat-trace] PracticeDummy._die` line.
 *
 * Preconditions:
 *   - `[Main] M1 play-loop ready` line has fired (Room01 loaded).
 *   - Canvas has keyboard focus (a prior `canvas.click()` was issued).
 *   - No movement keys are currently held.
 *   - The player is at (or near) `DEFAULT_PLAYER_SPAWN = (240, 200)` —
 *     fresh boot or fresh room load.
 *
 * Postconditions (default, `skipPickup` false):
 *   - At least one `[combat-trace] PracticeDummy._die` line in the buffer.
 *   - At least one `[combat-trace] Inventory.equip | source=auto_pickup` line
 *     (the player walked onto the dummy-dropped iron_sword Pickup and it
 *     auto-equipped). `result.pickupEquipped` is true.
 *   - The Room01 → Room02 advance gate (`Main._on_room01_mob_died`) has
 *     released — the room-clear flow fires `_on_room_cleared` →
 *     `_load_room_at_index(1)`. After ~1500ms settle, the player is
 *     teleported to (240, 200) in Room02, now holding the iron_sword.
 *
 * Note: caller still needs to `waitForTimeout(~1500ms)` AFTER this helper
 * returns to let the Room02 load complete. The helper does not embed that
 * wait so callers can decide how to use the post-clear window (e.g. snapshot
 * line counts before the room-load fires).
 *
 * Throws if the dummy doesn't die within the budget, or (when `skipPickup`
 * is false) if the Pickup is never collected/auto-equipped.
 */
export async function clearRoom01Dummy(
  page: Page,
  canvas: Locator,
  capture: ConsoleCapture,
  clickX: number,
  clickY: number,
  options: Room01ClearOptions = {}
): Promise<Room01ClearResult> {
  const budgetMs = options.budgetMs ?? 90_000;
  const attacksPerDir = options.attacksPerDir ?? 3;
  const skipPickup = options.skipPickup ?? false;
  const t0 = Date.now();

  const preDummyDeaths = capture
    .getLines()
    .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text)).length;
  const checkDummyDead = () =>
    capture
      .getLines()
      .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text))
      .length > preDummyDeaths;

  // The dummy-dropped iron_sword Pickup auto-equips via
  // `Inventory.on_pickup_collected` → `equip(item, &"weapon", &"auto_pickup")`,
  // which emits `[combat-trace] Inventory.equip | ... source=auto_pickup`.
  const preAutoPickupEquips = capture
    .getLines()
    .filter((l) =>
      /\[combat-trace\] Inventory\.equip \| .*source=auto_pickup/.test(l.text)
    ).length;
  const checkPickupEquipped = () =>
    capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Inventory\.equip \| .*source=auto_pickup/.test(l.text)
      ).length > preAutoPickupEquips;

  let attacksFired = 0;

  const attackSweep = async (
    directions: { keys: string[]; label: string }[]
  ): Promise<boolean> => {
    // **Mouse-direction attacks (PR #255, ticket 86c9uthf0).** Direction keys
    // no longer set `Player._facing` — the mouse vector from player to cursor
    // does. Click AT the dummy's world position (~368, 144) so every swing's
    // `_facing` points toward the dummy (or near it after the dummy dies).
    // Caller-supplied `clickX, clickY` are intentionally unused here — they
    // would land at canvas-center, which is far SE of the dummy on a
    // no-Camera2D viewport (player at (240,200), canvas-center at (640,360)).
    // The legacy direction-key chord below is retained as a no-op input
    // marker (does nothing facing-wise post-PR-#255) so the call shape stays
    // stable for any future spec that wants to layer movement back in; the
    // load-bearing aim is the world-coord click. See `mouse-facing.ts` header.
    const DUMMY_WORLD_POS = { x: 368, y: 144 };
    for (const dir of directions) {
      // No-op input cycle — preserved for diff-stability with pre-#255 specs.
      // The chord does NOT set facing post-#255; it's the click that aims.
      for (const k of dir.keys) await page.keyboard.down(k);
      await page.waitForTimeout(80);
      for (const k of [...dir.keys].reverse()) await page.keyboard.up(k);
      await page.waitForTimeout(80);

      for (let a = 0; a < attacksPerDir; a++) {
        if (Date.now() - t0 >= budgetMs) return false;
        await clickAtWorldPos(canvas, DUMMY_WORLD_POS.x, DUMMY_WORLD_POS.y);
        attacksFired++;
        await page.waitForTimeout(ATTACK_INTERVAL_MS);
        if (checkDummyDead()) return true;
      }
    }
    return false;
  };

  // ---- Phase A: walk pure N for 700ms (Y: 200 → ~140) ----
  await page.keyboard.down("w");
  await page.waitForTimeout(700);
  await page.keyboard.up("w");
  await page.waitForTimeout(150);
  let dummyKilled = checkDummyDead();

  // ---- Phase B: walk pure E for 1300ms (X: 240 → ~396; walls clamp) ----
  if (!dummyKilled) {
    await page.keyboard.down("d");
    await page.waitForTimeout(1300);
    await page.keyboard.up("d");
    await page.waitForTimeout(150);
    dummyKilled = checkDummyDead();
  }

  // ---- Phase C: 8-direction attack sweep ----
  if (!dummyKilled) {
    dummyKilled = await attackSweep(SWEEP_DIRECTIONS);
  }

  // ---- Phase D: small SW correction + retry sweep (in case walls clamped
  // the player far from the dummy) ----
  if (!dummyKilled && Date.now() - t0 < budgetMs - 12_000) {
    await page.keyboard.down("s");
    await page.keyboard.down("a");
    await page.waitForTimeout(200);
    await page.keyboard.up("a");
    await page.keyboard.up("s");
    await page.waitForTimeout(150);
    dummyKilled = await attackSweep(SWEEP_DIRECTIONS);
  }

  // ---- Phase E: extra N+E walk + sweep retry (if phase B undershot) ----
  if (!dummyKilled && Date.now() - t0 < budgetMs - 12_000) {
    await page.keyboard.down("w");
    await page.waitForTimeout(500);
    await page.keyboard.up("w");
    await page.waitForTimeout(100);
    await page.keyboard.down("d");
    await page.waitForTimeout(800);
    await page.keyboard.up("d");
    await page.waitForTimeout(150);
    dummyKilled = await attackSweep(SWEEP_DIRECTIONS);
  }

  if (!dummyKilled) {
    throw new Error(
      `[room01-traversal] PracticeDummy did not die within ${budgetMs}ms ` +
        `across phases A-E. Player likely never reached the dummy at world ` +
        `(~368, 144). Last 30 trace lines:\n` +
        capture
          .getLines()
          .slice(-30)
          .map((l) => `  ${l.text}`)
          .join("\n")
    );
  }

  // ---- Phase F: collect the dummy-dropped iron_sword Pickup ----
  //
  // Ticket 86c9qbb3k: the dummy drops a guaranteed iron_sword Pickup at its
  // death position (world ~368, 144). On a FISTLESS player the Room01 →
  // Room02 advance is GATED on the auto-equip (`Main._on_room01_mob_died`
  // holds the advance while the player has no weapon), so Room02 is
  // UNREACHABLE until the Pickup is collected. The Pickup has an
  // initial-overlap check (it collects against a player already standing on
  // the drop tile from the killing blow), so the player is OFTEN already
  // equipped by the time we get here — `checkPickupEquipped()` short-circuits.
  //
  // **Already-equipped case (post-reload / post-respawn).** If the player
  // ALREADY had a weapon when the dummy died (a save-restored weapon, or a
  // post-death respawn that preserved equipped state per the M1 death rule),
  // `Main._on_room01_mob_died` advances IMMEDIATELY — no gate, no pickup
  // needed. We detect that case via the kill-sweep Hitbox.hit damage: a
  // weapon-scaled hit (damage >= 2) means the player was equipped before the
  // kill, so Phase F is skipped (the dropped Pickup just rides along until the
  // room frees, and `on_pickup_collected` would not auto-swap an equipped
  // weapon anyway). Fistless kills are damage=1 → Phase F is required.
  let pickupEquipped = checkPickupEquipped();
  const killSweepWasWeaponScaled = capture
    .getLines()
    .some((l) => {
      const m = l.text.match(
        /\[combat-trace\] Hitbox\.hit \| team=player.*damage=(\d+)/
      );
      return m != null && parseInt(m[1], 10) >= 2;
    });
  const playerWasAlreadyEquipped = killSweepWasWeaponScaled && !pickupEquipped;
  if (!skipPickup && !pickupEquipped && !playerWasAlreadyEquipped) {
    // Criss-cross walk centred on the dummy's death position. After the kill
    // sweep the player is near (368, 144) but the exact offset is unknown, so
    // we sweep short walk-bursts in all 8 directions to drag the player's
    // body across the Pickup's Area2D (radius 8 + player body radius ~10).
    const PICKUP_WALK: { keys: string[]; ms: number }[] = [
      { keys: ["a"], ms: 260 },
      { keys: ["w"], ms: 260 },
      { keys: ["d"], ms: 520 },
      { keys: ["s"], ms: 520 },
      { keys: ["a"], ms: 520 },
      { keys: ["w"], ms: 520 },
      { keys: ["d"], ms: 260 },
      { keys: ["s"], ms: 260 },
    ];
    const pickupDeadline = Date.now() + Math.min(20_000, budgetMs);
    pickupLoop: while (Date.now() < pickupDeadline) {
      for (const step of PICKUP_WALK) {
        for (const k of step.keys) await page.keyboard.down(k);
        await page.waitForTimeout(step.ms);
        for (const k of step.keys) await page.keyboard.up(k);
        await page.waitForTimeout(120);
        if (checkPickupEquipped()) {
          pickupEquipped = true;
          break pickupLoop;
        }
      }
    }
    if (!pickupEquipped) {
      throw new Error(
        `[room01-traversal] dummy died but the iron_sword Pickup was never ` +
          `collected/auto-equipped within the pickup budget. The player is ` +
          `still fistless and the Room01 → Room02 advance gate is closed — ` +
          `Room02 will not load. Expected a ` +
          `[combat-trace] Inventory.equip | source=auto_pickup line. ` +
          `Last 30 trace lines:\n` +
          capture
            .getLines()
            .slice(-30)
            .map((l) => `  ${l.text}`)
            .join("\n")
      );
    }
  }

  return {
    dummyKilled,
    pickupEquipped,
    durationMs: Date.now() - t0,
    attacksFired,
  };
}

/**
 * Wait for the post-dummy-poof Room02 load to settle. Mirrors the
 * `_on_room_cleared` deferred call + room scene load + player teleport +
 * STATE_ATTACK recovery clear cadence.
 *
 * Default 1500ms is generous; empirical tests show ~600-800ms is the actual
 * Main-side load duration on a fresh boot.
 */
export async function waitForRoom02Load(
  page: Page,
  ms: number = 1500
): Promise<void> {
  await page.waitForTimeout(ms);
}
