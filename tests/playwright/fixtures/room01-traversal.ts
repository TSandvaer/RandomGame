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
 * **iron_sword bandaid coexistence (PR #146 retirement ticket 86c9qbb3k):**
 * The bandaid auto-equips iron_sword at boot, so Player damage = 6. With
 * dummy HP = 3, 1 swing kills. When the bandaid retires (player drops in
 * fistless per Uma's design-correct path), dummy HP = 3 / FIST_DAMAGE = 1
 * → 3 swings to kill. The helper cycles `attacksPerDir = 4` per direction
 * which works in BOTH cases — overkill at damage=6, exact at damage=1. When
 * the bandaid retires, the dummy-poof timing budget shifts but the helper
 * does not need to change.
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
   * so spec authors don't have to tune. Real cost on the bandaid path
   * (damage=6) is typically ≤ 5 s; on the post-bandaid path (damage=1) ≤ 12 s.
   */
  budgetMs?: number;
  /** Per-direction attack count during the sweep. Default 3. */
  attacksPerDir?: number;
}

export interface Room01ClearResult {
  dummyKilled: boolean;
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
 * Postconditions:
 *   - At least one `[combat-trace] PracticeDummy._die` line in the buffer.
 *   - The room-clear flow has fired via `Main._install_room01_clear_listener`
 *     → `_on_room_cleared` → `_load_room_at_index(1)`. After ~1500ms settle,
 *     the player is teleported back to (240, 200) in Room02.
 *
 * Note: caller still needs to `waitForTimeout(~1500ms)` AFTER this helper
 * returns to let the Room02 load complete. The helper does not embed that
 * wait so callers can decide how to use the post-clear window (e.g. snapshot
 * line counts before the room-load fires).
 *
 * Throws if the dummy doesn't die within the budget.
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
  const t0 = Date.now();

  const preDummyDeaths = capture
    .getLines()
    .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text)).length;
  const checkDummyDead = () =>
    capture
      .getLines()
      .filter((l) => /\[combat-trace\] PracticeDummy\._die/.test(l.text))
      .length > preDummyDeaths;

  let attacksFired = 0;

  const attackSweep = async (
    directions: { keys: string[]; label: string }[]
  ): Promise<boolean> => {
    for (const dir of directions) {
      // Set facing via direction-key chord. Release in REVERSE order so the
      // last-released-key tick has the chord rather than a single key (the
      // input_dir vector reads the most-recently-resolved direction set).
      for (const k of dir.keys) await page.keyboard.down(k);
      await page.waitForTimeout(80);
      for (const k of [...dir.keys].reverse()) await page.keyboard.up(k);
      await page.waitForTimeout(80);

      for (let a = 0; a < attacksPerDir; a++) {
        if (Date.now() - t0 >= budgetMs) return false;
        await canvas.click({ position: { x: clickX, y: clickY } });
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
  if (checkDummyDead()) {
    return {
      dummyKilled: true,
      durationMs: Date.now() - t0,
      attacksFired,
    };
  }

  // ---- Phase B: walk pure E for 1300ms (X: 240 → ~396; walls clamp) ----
  await page.keyboard.down("d");
  await page.waitForTimeout(1300);
  await page.keyboard.up("d");
  await page.waitForTimeout(150);
  if (checkDummyDead()) {
    return {
      dummyKilled: true,
      durationMs: Date.now() - t0,
      attacksFired,
    };
  }

  // ---- Phase C: 8-direction attack sweep ----
  let dummyKilled = await attackSweep(SWEEP_DIRECTIONS);

  // ---- Phase D: small SW correction + retry sweep (in case walls clamped
  // the player far from the dummy) ----
  if (!dummyKilled && Date.now() - t0 < budgetMs - 8_000) {
    await page.keyboard.down("s");
    await page.keyboard.down("a");
    await page.waitForTimeout(200);
    await page.keyboard.up("a");
    await page.keyboard.up("s");
    await page.waitForTimeout(150);
    dummyKilled = await attackSweep(SWEEP_DIRECTIONS);
  }

  // ---- Phase E: extra N+E walk + sweep retry (if phase B undershot) ----
  if (!dummyKilled && Date.now() - t0 < budgetMs - 8_000) {
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

  return {
    dummyKilled,
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
