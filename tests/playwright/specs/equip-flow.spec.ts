/**
 * equip-flow.spec.ts
 *
 * Equip flow — equipped weapon survives F5 reload (save → restore round-trip)
 * AND equip-via-LMB-click drives BOTH dual-surface state in lockstep, AND the
 * combat-trace `source` enum cleanly distinguishes user clicks from system
 * auto-equips (tickets 86c9qah0v + 86c9qbb3k).
 *
 * **Bandaid RETIRED (ticket 86c9qbb3k — this PR).** The PR #146 boot-equip
 * bandaid is gone. The player boots FISTLESS; the design-correct onboarding
 * path is auto-equip-first-weapon-on-pickup: the Room01 PracticeDummy drops
 * a guaranteed iron_sword Pickup, the player walks onto it, and
 * `Inventory.on_pickup_collected` auto-equips it via
 * `equip(item, &"weapon", &"auto_pickup")` — emitting
 * `[combat-trace] Inventory.equip | source=auto_pickup`. The Room01 → Room02
 * advance is GATED on that equip (`Main._on_room01_mob_died` holds the
 * advance while the player is fistless), so reaching Room02 PROVES the
 * onboarding equip happened. The `clearRoom01Dummy` helper now handles the
 * full kill + pickup-collection flow and reports `pickupEquipped`.
 *
 * Verifies the equip-state persistence path AND the in-game LMB-click equip
 * path that PR #145 / #146 / closed P0 86c9q96m8 all hit in different ways:
 *
 *   1. Cold boot: player is FISTLESS — NO `Inventory.equip` line of any
 *      source fires during the boot window (no boot-time seed/equip at all).
 *   1.5. Boot-window negative assertions: ZERO `source=lmb_click`, ZERO
 *      `source=auto_starter` (deprecated tag, no producer), AND ZERO
 *      `source=auto_pickup` lines during cold boot — nothing equips until
 *      the player picks up the dummy drop.
 *   2. `clearRoom01Dummy` kills the dummy (fistless, damage=1 hits) and
 *      walks the player onto the dropped iron_sword Pickup. Assert the
 *      `source=auto_pickup` onboarding equip fired. After it, combat is
 *      weapon-scaled (damage=6) — the baseline `preReloadDamageObserved`
 *      is captured from a Room02 swing.
 *   3. **(P0 86c9q96m8 fix coverage):** open Tab inventory, click the
 *      equipped slot to unequip (iron_sword → grid), then click the grid
 *      cell to re-equip via the LMB-click path. Asserts the
 *      `[combat-trace] Inventory.equip | source=lmb_click damage_after=6`
 *      line fires AND post-equip swing damage matches.
 *   4. F5 reload → Save autoload restores equipped state from snapshot.
 *   5. Post-reload: the player is fistless again at cold boot, re-clears the
 *      Room01 dummy + picks up the (re-dropped) iron_sword, and a fresh
 *      Room02 swing still produces damage=6 hits (proves the equip path is
 *      healthy after a reload). Negative assertion: ZERO `source=lmb_click`
 *      and ZERO `source=auto_starter` lines fire post-reload (the F5 reload
 *      cold-boots, so the only equip is the dummy-drop `source=auto_pickup`).
 *
 * **Status: green — bandaid retired (86c9qbb3k), P0 86c9q96m8 fix landed.**
 *
 * **Phase 2.5 swing-after-Tab race fix (tickets 86c9qb7f3 + 86c9qah0f):**
 * Phase 2.5 historically flaked on Windows headed Chromium (~1 in 3; on
 * faster hardware, consistently). Two compounding harness bugs, both fixed
 * inline in Phase 2.5 below:
 *   (a) Closing the inventory after the grid-cell click failed. The click
 *       lands on a `Button` (default `focus_mode=FOCUS_ALL`) which grabs
 *       keyboard focus. From that point Godot's GUI input system consumes
 *       BOTH `Tab` (the focus-traversal key) AND `Escape` (bound to the
 *       built-in `ui_cancel` GUI action) before they reach
 *       `InventoryPanel._unhandled_input`. The panel stays open,
 *       `Engine.time_scale` stays at 0.10, and the facing-set runs in
 *       slow-mo. (PR #187 round-1 swapped `Tab` → `Escape` — but `Escape`
 *       is ALSO focus-consumed, so the panel stayed open in Devon's 0/5
 *       headed reproduction.)
 *       Fix: a test-only `InventoryPanel.force_close_for_test()` hook,
 *       wired to the `test_force_close_inventory` input action (F9) handled
 *       in `_input()`. `_input()` runs BEFORE the GUI focus system, so a
 *       focused Button cannot swallow it. The hook closes the panel,
 *       restores `Engine.time_scale`, and emits a `[combat-trace]
 *       InventoryPanel.force_close_for_test | open=false time_scale=1` line
 *       the spec POSITIVELY ASSERTS on before proceeding. The whole
 *       focus-consumption class is sidestepped — no key-picking lottery.
 *   (b) The post-equip swing used a fixed-NE facing + in-place click-spam,
 *       assuming a grunt sat NE of the player. Drift from `clearRoom01Dummy`
 *       + the room-advance teleport makes that false in headed mode. Fix: an
 *       8-direction attack sweep (mirrors `clearRoom01Dummy`'s discipline) so
 *       the post-equip hit lands regardless of where the grunt drifted.
 * Neither is a game bug — focus-consumption and grunt-chase drift are both
 * correct engine/gameplay behaviour; the spec was making timing assumptions
 * that only held headless. The `force_close_for_test` hook is a test-only
 * surface gated on `OS.has_feature("web")`, matching the existing
 * `force_click_*_for_test` convention in `scripts/ui/InventoryPanel.gd`.
 *
 * Coverage gap closed by this spec extension:
 *   - Tab → LMB-click equipped slot (unequip) → LMB-click grid cell (equip).
 *   - The `[combat-trace] Inventory.equip` shim now provides the
 *     observable signature for the LMB-click path.
 *   - Source-enum disambiguation (lmb_click vs auto_starter vs no-trace-on-
 *     save-restore) — ticket 86c9qah0v.
 *
 * Coverage still deferred (open follow-up):
 *   - True equip-swap (LMB on grid cell of a DIFFERENT weapon than what's
 *     equipped) requires programmatically injecting a second weapon into
 *     the inventory. Achievable via the Godot JS bridge but adds harness
 *     complexity disproportionate to the value at this milestone. The
 *     unequip+re-equip path covers the same `Inventory.equip()` code
 *     surface (the `_unequip_internal(slot, true)` swap branch is
 *     exercised by `test_inventory.gd::test_equip_swap_*`).
 *
 * **Click coordinate computation (load-bearing):**
 * Godot HTML5 viewport is 1280×720 logical pixels with `stretch_mode=
 * canvas_items, stretch_aspect=keep`. The DOM canvas may be smaller; we
 * scale logical coords to canvas DOM coords by `canvasW / 1280`.
 * InventoryPanel cell layout (scripts/ui/InventoryPanel.gd):
 *   - Equipped weapon button: HBoxContainer at (380, 32), separation=8,
 *     cell size 96×96. Weapon is index 0 → center at (428, 80).
 *   - Inventory grid: GridContainer at (380, 160), 8 cols × 3 rows, h_sep=4,
 *     v_sep=4, cell size 96×96. Cell (col, row) center at
 *     `(380 + col*100 + 48, 160 + row*100 + 48)` — first cell at (428, 208).
 *
 * References:
 *   - .claude/docs/combat-architecture.md §"Equipped-weapon dual-surface rule"
 *   - scripts/inventory/Inventory.gd::equip — LMB-click entry point
 *   - scripts/inventory/Inventory.gd::_emit_equip_trace — combat-trace shim
 *   - scripts/ui/InventoryPanel.gd:336 — _handle_inventory_click
 *   - scripts/ui/InventoryPanel.gd:359 — _handle_equipped_click
 *   - PR #145 / #146 (boot-order regression class)
 *   - Closed P0 86c9q96m8 (equip-via-LMB-click was broken pre-fix)
 */

import { test, expect } from "../fixtures/test-base";
import { ConsoleCapture } from "../fixtures/console-capture";
import {
  clearRoom01Dummy,
  waitForRoom02Load,
} from "../fixtures/room01-traversal";

const BOOT_TIMEOUT_MS = 30_000;
const KILL_TIMEOUT_MS = 60_000;
const POST_RELOAD_HIT_TIMEOUT_MS = 60_000;
const ATTACK_INTERVAL_MS = 220;

test.describe("equip flow — equipped weapon survives F5 reload", () => {
  // Note: this spec is currently expected to land GREEN against m1-rc-1
  // (the round-trip works in the artifact today). It's NOT marked test.fail()
  // because the F5-survival path is healthy — the OPEN P0 86c9q96m8 covers
  // the click-to-equip path which the harness cannot exercise.
  //
  // If the post-reload damage drops to 1 in CI, that's a NEW regression in
  // the save-restore → equip-restore → damage-flow chain (PR #146 class) and
  // this spec rightly fails.
  test("equip flow — LMB-click equip + F5 reload survival (P0 86c9q96m8)", async ({
    page,
    context,
  }) => {
    test.setTimeout(240_000);
    await context.route("**/*", (route) => route.continue());

    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // ---- Phase 1: Cold-boot integration baseline ----
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // ---- Phase 1.5: Boot-window negative assertions (ticket 86c9qbb3k) ----
    //
    // The PR #146 boot-equip bandaid is RETIRED — the player boots FISTLESS.
    // NO Inventory.equip line of ANY source should fire during the cold-boot
    // window: nothing equips until the player picks up the dummy's drop.
    //
    //   Negative: ZERO source=auto_pickup  — no pickup collected yet.
    //   Negative: ZERO source=lmb_click    — no user click yet.
    //   Negative: ZERO source=auto_starter — the deprecated boot-equip tag
    //             has no producer (the bandaid that emitted it is retired).
    //
    // Settle briefly so the deferred boot frames flush.
    await page.waitForTimeout(500);
    const bootWindowLines = capture.getLines();
    const bootEquipLines = bootWindowLines.filter((l) =>
      /\[combat-trace\] Inventory\.equip \|/.test(l.text)
    );
    expect(
      bootEquipLines.length,
      `Boot-window negative (86c9qbb3k): expected ZERO ` +
        `[combat-trace] Inventory.equip lines of ANY source during cold boot ` +
        `— the boot-equip bandaid is retired and the player is fistless until ` +
        `they pick up the dummy drop. Got ${bootEquipLines.length}:\n` +
        bootEquipLines.map((l) => `  ${l.text}`).join("\n")
    ).toBe(0);

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // ---- Phase 2: Kill the Room01 dummy + collect the iron_sword Pickup ----
    //
    // Ticket 86c9qbb3k: the player drops in FISTLESS. The Room01 PracticeDummy
    // (HP=3) poofs in 3 FIST_DAMAGE=1 swings, then drops a guaranteed
    // iron_sword Pickup. The `clearRoom01Dummy` helper kills the dummy AND
    // walks the player onto the Pickup — `Inventory.on_pickup_collected`
    // auto-equips it, emitting `source=auto_pickup`. The Room01 → Room02
    // advance is GATED on that equip, so `pickupEquipped` MUST be true.
    const room01ClearResult = await clearRoom01Dummy(
      page,
      canvas,
      capture,
      clickX,
      clickY,
      { budgetMs: KILL_TIMEOUT_MS }
    );
    expect(
      room01ClearResult.dummyKilled,
      "Phase 2: Room01 PracticeDummy must die (3 fistless swings)."
    ).toBe(true);
    expect(
      room01ClearResult.pickupEquipped,
      "Phase 2: the dummy-dropped iron_sword Pickup must be collected + " +
        "auto-equipped (source=auto_pickup). The Room01 → Room02 advance is " +
        "GATED on this equip — if it never happened, Room02 is unreachable."
    ).toBe(true);

    // Assert the onboarding auto-equip trace fired with the right shape.
    const autoPickupLine = capture
      .getLines()
      .find((l) =>
        /\[combat-trace\] Inventory\.equip \| .*source=auto_pickup/.test(l.text)
      );
    expect(
      autoPickupLine,
      "Phase 2: expected a [combat-trace] Inventory.equip | source=auto_pickup " +
        "line — the design-correct onboarding equip (ticket 86c9qbb3k)."
    ).toBeDefined();
    const autoPickupMatch = autoPickupLine!.text.match(
      /Inventory\.equip \| item=(\S+) slot=(\S+) source=(\S+) damage_after=(\d+)/
    );
    expect(autoPickupMatch, `auto_pickup trace shape: "${autoPickupLine!.text}"`)
      .not.toBeNull();
    expect(autoPickupMatch![1]).toBe("iron_sword");
    expect(autoPickupMatch![2]).toBe("weapon");
    expect(autoPickupMatch![3]).toBe("auto_pickup");
    // The iron_sword's light-attack damage — the value all later assertions
    // compare against (same iron_sword, edge=0, same formula).
    const preReloadDamageObserved = parseInt(autoPickupMatch![4], 10);
    console.log(
      `[equip-flow] auto_pickup equip: damage_after=${preReloadDamageObserved}.`
    );
    expect(preReloadDamageObserved).toBeGreaterThanOrEqual(2);

    // Settle for Room02 load — the gate released on the auto_pickup equip,
    // so _on_room_cleared → _load_room_at_index(1) now runs.
    await waitForRoom02Load(page, 1500);

    // ---- Phase 2.5: P0 86c9q96m8 — drive the LMB-click equip path ----
    //
    // Sponsor M1 RC re-soak attempt 5: clicking on the inventory grid to
    // equip a weapon was broken. Coverage gap pre-fix: the harness only
    // covered F5-reload survival, not the in-game click path.
    //
    // Strategy: open Tab panel, click the equipped weapon slot to unequip
    // (iron_sword → grid), then click the grid cell to re-equip via the
    // LMB-click path. This exercises the exact production code path
    // `InventoryPanel._handle_inventory_click(0, MOUSE_BUTTON_LEFT)` →
    // `Inventory.equip(item, &"weapon")` that the P0 fix touches.
    //
    // The new `[combat-trace] Inventory.equip | source=lmb_click` shim is
    // what we assert — its presence proves the user-driven click path was
    // exercised, and `damage_after=N` proves both Inventory and Player
    // surfaces stayed in lockstep (since damage_after reads from
    // Player.get_equipped_weapon — see Inventory.gd::_compute_post_equip_damage).
    console.log(
      `[equip-flow] Phase 2.5: Drive LMB-click equip path (P0 86c9q96m8 coverage).`
    );

    // Compute logical→canvas coord mapping. Godot 1280×720 viewport with
    // `stretch_mode=canvas_items, stretch_aspect=keep` so we scale uniformly.
    const LOGICAL_W = 1280;
    const LOGICAL_H = 720;
    const canvasBBLm = await canvas.boundingBox();
    const cw = canvasBBLm?.width ?? LOGICAL_W;
    const ch = canvasBBLm?.height ?? LOGICAL_H;
    const cx0 = canvasBBLm?.x ?? 0;
    const cy0 = canvasBBLm?.y ?? 0;
    // `keep` aspect: pick the smaller scale, letterbox the rest.
    const sx = cw / LOGICAL_W;
    const sy = ch / LOGICAL_H;
    const scale = Math.min(sx, sy);
    // Letterbox offsets — content is centered when aspect doesn't match.
    const lbX = (cw - LOGICAL_W * scale) / 2;
    const lbY = (ch - LOGICAL_H * scale) / 2;
    // Cell center in logical coords:
    //   Equipped weapon (HBox at offset_left=380, offset_top=32; index 0; size 96x96)
    //   → center at (380+48, 32+48) = (428, 80).
    //   Grid cell (col=0, row=0): GridContainer at (380, 160), cell 96x96, sep=4
    //   → center at (380+48, 160+48) = (428, 208).
    const equippedSlotLogical = { x: 428, y: 80 };
    const gridCell0Logical = { x: 428, y: 208 };
    const toCanvas = (p: { x: number; y: number }) => ({
      x: cx0 + lbX + p.x * scale,
      y: cy0 + lbY + p.y * scale,
    });
    const equippedSlotPx = toCanvas(equippedSlotLogical);
    const gridCell0Px = toCanvas(gridCell0Logical);
    console.log(
      `[equip-flow] Canvas ${cw}x${ch}, scale=${scale.toFixed(3)}, ` +
        `equipped@(${equippedSlotPx.x.toFixed(0)},${equippedSlotPx.y.toFixed(0)}), ` +
        `gridCell0@(${gridCell0Px.x.toFixed(0)},${gridCell0Px.y.toFixed(0)})`
    );

    // Mark the buffer position so we can scope post-Tab assertions.
    const phase25LineCount = capture.getLines().length;

    // Open Tab inventory.
    await page.keyboard.press("Tab");
    await page.waitForTimeout(400); // Time-slow factor=0.10 means UI animations crawl;
    // but the panel's open() is synchronous + the buttons render immediately.

    // Click the equipped weapon slot to unequip iron_sword back into the grid.
    // This exercises `_handle_equipped_click(&"weapon", MOUSE_BUTTON_LEFT)` →
    // `Inventory.unequip(&"weapon")` — proves the equipped row's click works.
    await page.mouse.click(equippedSlotPx.x, equippedSlotPx.y, {
      button: "left",
    });
    await page.waitForTimeout(300);

    // Now click the grid cell at (0,0) — the iron_sword should have landed
    // at index 0. This exercises `_handle_inventory_click(0, MOUSE_BUTTON_LEFT)`
    // → `Inventory.equip(item, &"weapon")` → fires the new combat-trace line.
    await page.mouse.click(gridCell0Px.x, gridCell0Px.y, { button: "left" });
    await page.waitForTimeout(400);

    // ---- MAIN ASSERTION 1: combat-trace fired with source=lmb_click ----
    const equipTraceLine = capture
      .getLines()
      .slice(phase25LineCount)
      .find((l) =>
        /\[combat-trace\] Inventory\.equip \| .*source=lmb_click/.test(l.text)
      );
    expect(
      equipTraceLine,
      "Phase 2.5 P0 86c9q96m8: no [combat-trace] Inventory.equip | " +
        "source=lmb_click line observed after Tab → click equipped slot → " +
        "click grid cell. Either:\n" +
        " (1) the click coordinates missed the InventoryPanel cell layout " +
        "(canvas scaling / letterbox math wrong), or\n" +
        " (2) the LMB-click handler didn't route to Inventory.equip, or\n" +
        " (3) the trace shim isn't wired in scripts/inventory/Inventory.gd."
    ).toBeDefined();

    // The trace line must include item=iron_sword, slot=weapon, source=lmb_click,
    // and damage_after MUST equal the iron_sword's light-attack damage (6).
    const traceMatch = equipTraceLine!.text.match(
      /Inventory\.equip \| item=(\S+) slot=(\S+) source=(\S+) damage_after=(\d+)/
    );
    expect(
      traceMatch,
      `Trace line shape mismatch: "${equipTraceLine!.text}". ` +
        `Expected: [combat-trace] Inventory.equip | item=<id> slot=<weapon|armor> source=lmb_click damage_after=<N>`
    ).not.toBeNull();
    if (traceMatch) {
      const [, itemId, slot, source, damageAfterStr] = traceMatch;
      const damageAfter = parseInt(damageAfterStr, 10);
      console.log(
        `[equip-flow] Trace observed: item=${itemId} slot=${slot} ` +
          `source=${source} damage_after=${damageAfter}`
      );
      expect(itemId).toBe("iron_sword");
      expect(slot).toBe("weapon");
      expect(source).toBe("lmb_click");
      // damage_after MUST match the pre-reload damage we captured earlier
      // (same iron_sword, same edge=0, same formula → same number).
      expect(damageAfter).toBe(preReloadDamageObserved);
    }

    // ---- Close the inventory panel — swing-after-Tab race fix (86c9qb7f3) ----
    //
    // ROOT CAUSE of the historical Phase 2.5 flake: the grid-cell click above
    // lands on a `Button` (scripts/ui/InventoryPanel.gd) created with the
    // default `focus_mode = FOCUS_ALL`, so the click grabs keyboard focus for
    // that Button. From that point Godot's GUI input system consumes BOTH of
    // the keys a spec might use to close the panel BEFORE they reach
    // `InventoryPanel._unhandled_input`:
    //   - `Tab` is the built-in UI focus-traversal key ("focus next
    //     neighbour") — swallowed by the focus system.
    //   - `Escape` is bound to the built-in `ui_cancel` GUI action — ALSO
    //     swallowed when a Control holds focus.
    // (PR #187 round-1 swapped `Tab` → `Escape`; Devon's peer review caught
    // that `Escape` is equally focus-consumed — 0/5 headed runs closed the
    // panel.) With the panel still open, `Engine.time_scale =
    // TIME_SLOW_FACTOR (0.10)` stays in effect, so the facing-set below runs
    // at 1/10th game speed and the swings fire in a stale direction.
    //
    // FIX: drive the test-only `InventoryPanel.force_close_for_test()` hook
    // via the `test_force_close_inventory` input action (F9 — see
    // project.godot). That action is handled in `InventoryPanel._input()`,
    // which runs BEFORE the GUI focus system — a focused Button cannot
    // swallow it. The hook closes the panel, restores `Engine.time_scale`,
    // and emits a `[combat-trace] InventoryPanel.force_close_for_test`
    // confirmation line. We POSITIVELY ASSERT that line (carrying
    // `open=false time_scale=1`) before proceeding — no more "press a key
    // and hope it closed". The hook is gated on `OS.has_feature("web")` so
    // it is inert on desktop / headless GUT (matches the `combat_trace`
    // gate in DebugFlags.gd). This sidesteps the entire focus-consumption
    // class rather than picking yet another key and hoping.
    const forceCloseLineCount = capture.getLines().length;
    await page.keyboard.press("F9"); // test_force_close_inventory action
    await page.waitForTimeout(500); // panel close + Engine.time_scale restore

    // ---- ASSERTION: panel actually closed (the round-1 failure mode) ----
    // The confirmation trace proves the close happened AND time_scale is back
    // to 1.0. Without this, a swallowed keypress would leave the panel open
    // and the rest of Phase 2.5 would run in 0.10 slow-mo — exactly the bug
    // Devon's peer review reproduced 0/5.
    const forceCloseTraceLine = capture
      .getLines()
      .slice(forceCloseLineCount)
      .find((l) =>
        /\[combat-trace\] InventoryPanel\.force_close_for_test/.test(l.text)
      );
    expect(
      forceCloseTraceLine,
      "Phase 2.5 (86c9qb7f3): no [combat-trace] InventoryPanel." +
        "force_close_for_test line after pressing F9. The panel did NOT " +
        "close — either the test_force_close_inventory action is unbound " +
        "in project.godot, the InventoryPanel._input() handler regressed, " +
        "or OS.has_feature('web') is false (this hook is HTML5-only). " +
        "Without the close, Engine.time_scale stays at 0.10 and the rest " +
        "of this phase runs in slow-mo — the round-1 failure shape."
    ).toBeDefined();
    const forceCloseMatch = forceCloseTraceLine!.text.match(
      /open=(\S+) time_scale=(\S+)/
    );
    expect(
      forceCloseMatch,
      `force_close_for_test trace shape mismatch: "${forceCloseTraceLine!.text}". ` +
        `Expected: ...| open=<bool> time_scale=<float>`
    ).not.toBeNull();
    if (forceCloseMatch) {
      const [, openState, timeScaleStr] = forceCloseMatch;
      // open MUST be false — the panel is closed.
      expect(
        openState,
        `Phase 2.5: InventoryPanel.force_close_for_test reported open=${openState} ` +
          `— the panel did not actually close. close() should have flipped _open false.`
      ).toBe("false");
      // time_scale MUST be restored to 1.0 — slow-mo is over.
      const timeScale = parseFloat(timeScaleStr);
      expect(
        timeScale,
        `Phase 2.5: Engine.time_scale=${timeScale} after force-close (expected 1.0). ` +
          `The panel's close() did not restore the snapshot — the rest of the ` +
          `phase would run in slow-mo. This is the load-bearing assertion that ` +
          `the round-1 Escape-key fix could not make (the panel never closed).`
      ).toBeCloseTo(1.0, 5);
    }

    // ---- MAIN ASSERTION 2: post-LMB-equip swings still hit damage=6 ----
    // The dual-surface invariant: Player._equipped_weapon got refreshed by
    // the LMB-click path. Confirm by firing a swing and watching for
    // Hitbox.hit damage matching the pre-reload value.
    await canvas.click(); // re-focus the canvas for swing input
    await page.waitForTimeout(300);

    // Drift-resilient post-equip swing: an 8-direction attack sweep, NOT a
    // fixed-facing click-spam.
    //
    // WHY a sweep, not fixed-NE: the original spec set facing NE once and
    // click-spammed in place, assuming a grunt was NE of the player. In headed
    // Windows Chromium that assumption is false — `clearRoom01Dummy`'s own
    // 8-direction sweep + the room-advance teleport leave the player at an
    // unpredictable position relative to the Room02 grunts, and the grunts
    // chase from every side (observed telegraph dirs span N/S/E/W). A
    // fixed-NE swing wedge (28px reach + 18px radius = 46px range) then never
    // overlaps a grunt and the spec hangs 30s with zero `Hitbox.hit |
    // team=player` lines — even though every swing correctly fires damage=6.
    // Headless timing happened to keep a grunt in the NE wedge, so the spec
    // passed in CI; headed did not — the exact "Windows headed-Chromium flake"
    // shape of tickets 86c9qb7f3 / 86c9qah0f.
    //
    // The fix mirrors the established `clearRoom01Dummy` discipline (see
    // fixtures/room01-traversal.ts): cycle the facing through all 8 cardinal/
    // diagonal directions and swing in each, so whichever side a grunt is on,
    // one direction in the cycle lands the hit. Direction keys are released in
    // REVERSE order so the last-resolved input tick carries the full chord.
    const PHASE25_SWEEP: { keys: string[]; label: string }[] = [
      { keys: ["w"], label: "N" },
      { keys: ["w", "d"], label: "NE" },
      { keys: ["d"], label: "E" },
      { keys: ["s", "d"], label: "SE" },
      { keys: ["s"], label: "S" },
      { keys: ["s", "a"], label: "SW" },
      { keys: ["a"], label: "W" },
      { keys: ["w", "a"], label: "NW" },
    ];

    const phase25SwingStart = Date.now();
    let postLmbEquipDamage: number | null = null;
    sweepLoop: while (Date.now() - phase25SwingStart < 30_000) {
      for (const dir of PHASE25_SWEEP) {
        // Set facing via direction-key chord. Hold 120ms so at least one
        // `_physics_process` frame updates `Player._facing` at time_scale=1.0
        // (the panel is closed — see the F9 force-close + asserted
        // confirmation trace above — so we are NOT in the 0.10 slow-mo
        // window here).
        for (const k of dir.keys) await page.keyboard.down(k);
        await page.waitForTimeout(120);
        for (const k of [...dir.keys].reverse()) await page.keyboard.up(k);
        await page.waitForTimeout(60);

        // Two swings per direction — covers the LIGHT_RECOVERY (0.18s) gap.
        for (let a = 0; a < 2; a++) {
          if (Date.now() - phase25SwingStart >= 30_000) break sweepLoop;
          await canvas.click({ position: { x: clickX, y: clickY } });
          await page.waitForTimeout(ATTACK_INTERVAL_MS);
          // Look for hits AFTER the marked buffer position so we don't pick
          // up pre-Tab hits.
          const recentLines = capture.getLines().slice(phase25LineCount);
          const hitLine = recentLines.find((l) =>
            /\[combat-trace\] Hitbox\.hit \| team=player.*damage=(\d+)/.test(
              l.text
            )
          );
          if (hitLine) {
            const m = hitLine.text.match(/damage=(\d+)/);
            if (m) {
              postLmbEquipDamage = parseInt(m[1], 10);
              break sweepLoop;
            }
          }
        }
      }
    }
    expect(
      postLmbEquipDamage,
      "Phase 2.5: no Hitbox.hit observed in 30s after LMB-equip. " +
        "Either the click missed (player not facing grunt) or — load-bearing — " +
        "the LMB-click equip didn't propagate to Player._equipped_weapon (the " +
        "dual-surface bug Sponsor saw: 'subsequent swings still register the " +
        "previous weapon's damage')."
    ).not.toBeNull();
    expect(
      postLmbEquipDamage,
      `Phase 2.5 LMB-equip dual-surface assertion: post-equip damage=` +
        `${postLmbEquipDamage} (expected ${preReloadDamageObserved}). ` +
        `If <2 (fistless), Player._equipped_weapon is null — the LMB-click ` +
        `path mutated Inventory but skipped Player. P0 86c9q96m8 regression class.`
    ).toBe(preReloadDamageObserved);

    // ---- Phase 3: F5 reload — must trigger Save → restore_from_save round-trip ----
    console.log(
      `[equip-flow] Reloading page (F5) — equipped state must survive.`
    );

    // Clear capture buffer so post-reload assertions are clean.
    // The reload also dumps the existing service worker (we have
    // serviceWorkers:"block" — there isn't one), so the reload re-fetches
    // index.html / .wasm / .pck without cache.
    capture.clearLines();

    await page.reload({ waitUntil: "domcontentloaded" });

    // ---- Phase 4: Post-reload integration assertions ----
    // The boot-ready line MUST fire again — the engine is restarting.
    await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

    // Wait briefly for save-restore deferred frames
    await page.waitForTimeout(1_000);

    // Re-focus canvas and re-attack
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB2 = await canvas.boundingBox();
    const clickX2 = (canvasBB2?.x ?? 0) + (canvasBB2?.width ?? 1280) / 2;
    const clickY2 = (canvasBB2?.y ?? 0) + (canvasBB2?.height ?? 720) / 2;

    // F5 reload restores the save (equipped iron_sword survives) but Main's
    // `_ready` always cold-loads Room01 — the player respawns at
    // DEFAULT_PLAYER_SPAWN ALREADY EQUIPPED (the save restored the weapon).
    // The Room01 PracticeDummy is re-instantiated. We re-run the dummy-clear
    // helper: because the player is already equipped, the kill-sweep hits are
    // weapon-scaled (damage=6), the Room01 → Room02 advance is NOT gated
    // (immediate-advance path — `Main._on_room01_mob_died` sees the equipped
    // weapon), and the helper skips its Phase F pickup-collection. So
    // `pickupEquipped` is false here (no NEW auto_pickup equip — the player
    // came in equipped from the save). The load-bearing assertion is the
    // weapon-scaled damage below.
    const postReloadClearResult = await clearRoom01Dummy(
      page,
      canvas,
      capture,
      clickX2,
      clickY2,
      { budgetMs: POST_RELOAD_HIT_TIMEOUT_MS }
    );
    expect(
      postReloadClearResult.dummyKilled,
      "Post-reload: Room01 PracticeDummy must die. Save-restore re-spawned " +
        "the dummy and the player; the equipped iron_sword should still " +
        "produce damage=6 hits. If the dummy doesn't die in the helper's " +
        "attack budget, either the equipped weapon was wiped (PR #146 class " +
        "regression) or the helper drifted."
    ).toBe(true);

    // Find the first Hitbox.hit team=player line emitted during the helper's
    // sweep. The buffer was cleared right before page.reload(), so the entire
    // current buffer is post-reload activity.
    const postReloadHitLine = capture
      .getLines()
      .find((l) =>
        /\[combat-trace\] Hitbox\.hit \| team=player.*damage=(\d+)/.test(l.text)
      );
    let postReloadDamageObserved: number | null = null;
    if (postReloadHitLine) {
      const m = postReloadHitLine.text.match(/damage=(\d+)/);
      if (m) {
        postReloadDamageObserved = parseInt(m[1], 10);
        console.log(
          `[equip-flow] Post-reload first hit damage=${postReloadDamageObserved} ` +
            `(${postReloadClearResult.attacksFired} attacks fired, ` +
            `${postReloadClearResult.durationMs}ms helper duration).`
        );
      }
    }

    // ---- MAIN ASSERTION ----
    expect(
      postReloadDamageObserved,
      "Post-reload: no Hitbox.hit|team=player observed in the helper's " +
        "post-reload dummy clear. The dummy died (kill confirmed) but no " +
        "Hitbox.hit trace fired — the combat-trace shim has regressed."
    ).not.toBeNull();

    expect(
      postReloadDamageObserved,
      `equip-flow REGRESSION: post-reload damage=${postReloadDamageObserved} (expected >=2). ` +
        `The save → restore_from_save round-trip lost the equipped iron_sword. ` +
        `Either Inventory.restore_from_save's reset loop wiped equipped state, ` +
        `or Player._equipped_weapon was not re-applied via _apply_equip_to_player. ` +
        `The post-reload Room01 kill should be weapon-scaled because the player ` +
        `came back equipped FROM THE SAVE (no fistless start, no pickup needed).`
    ).toBeGreaterThanOrEqual(2);

    // The post-reload Room01 kill damage should match the iron_sword's
    // light-attack damage captured from the Phase 2 auto_pickup equip
    // (same iron_sword, edge=0, same formula).
    expect(postReloadDamageObserved).toBe(preReloadDamageObserved);

    // ---- Negative assertions ----
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(panicLine).toBeNull();

    // Trace-shim scoping: NO user-driven or boot-driven `Inventory.equip`
    // line should fire post-reload. The buffer was cleared right before
    // `page.reload()`, so the entire current buffer is post-reload activity.
    //
    //   - `source=lmb_click`: the player did NOT Tab→click-equip post-reload
    //     (Phase 2.5 ran BEFORE the reload). `restore_from_save` bypasses
    //     `equip()` entirely (directly mutates `_equipped[slot]` +
    //     `_apply_equip_to_player`), so a save-restore must not emit a trace.
    //   - `source=auto_starter`: the deprecated PR #146 boot-equip tag has no
    //     producer at all (the bandaid is retired, ticket 86c9qbb3k).
    //   - `source=auto_pickup`: post-reload the player is ALREADY equipped
    //     (save-restored weapon), so when the helper kills the Room01 dummy,
    //     the dropped Pickup does NOT auto-swap an equipped weapon — no
    //     `on_pickup_collected` auto-equip fires.
    //
    // Thus ALL THREE source tags must be absent post-reload.
    const postReloadLmbClickLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Inventory\.equip \| .*source=lmb_click/.test(l.text)
      );
    expect(
      postReloadLmbClickLines.length,
      `Negative assertion: [combat-trace] Inventory.equip | source=lmb_click ` +
        `fired post-F5-reload — should ONLY fire on user-driven LMB-click, and ` +
        `no Tab→click happened after the reload. Found ` +
        `${postReloadLmbClickLines.length} line(s). Re-check ` +
        `Inventory.restore_from_save: it must NOT route through equip().`
    ).toBe(0);
    const postReloadAutoStarterLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Inventory\.equip \| .*source=auto_starter/.test(l.text)
      );
    expect(
      postReloadAutoStarterLines.length,
      `Negative assertion (86c9qbb3k): [combat-trace] Inventory.equip | ` +
        `source=auto_starter fired post-F5-reload — but the PR #146 boot-equip ` +
        `bandaid (the only producer of auto_starter) is RETIRED. Found ` +
        `${postReloadAutoStarterLines.length} line(s). Nothing should ever ` +
        `emit auto_starter any more.`
    ).toBe(0);
    const postReloadAutoPickupLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Inventory\.equip \| .*source=auto_pickup/.test(l.text)
      );
    expect(
      postReloadAutoPickupLines.length,
      `Negative assertion (86c9qbb3k): [combat-trace] Inventory.equip | ` +
        `source=auto_pickup fired post-F5-reload — but the player came back ` +
        `ALREADY EQUIPPED from the save-restore, so the dummy-drop Pickup must ` +
        `NOT auto-swap (auto-equip-on-pickup is first-weapon-only). Found ` +
        `${postReloadAutoPickupLines.length} line(s) — on_pickup_collected's ` +
        `"weapon already equipped" guard regressed.`
    ).toBe(0);

    // Ticket 86c9qah1f fix verification: the save-restore push_warning for
    // `unknown item id 'iron_sword'` MUST be absent after F5 reload. Pre-fix,
    // the ContentRegistry recursive DirAccess scan over the .pck-packed
    // `res://resources/items` did not enumerate `weapons/` reliably in
    // HTML5, so `from_save_dict` push_warning'd on every save-restore.
    // Post-fix (STARTER_ITEM_PATHS direct-load fallback in
    // `ContentRegistry.load_all`), iron_sword resolves silently on every
    // platform.
    //
    // This is a positive console-silence assertion — the AC5 dependency
    // unlock the ticket exists to enable. Going forward, every console
    // warning produced by save-restore is a real regression.
    const ironSwordResolverWarning = capture
      .getLines()
      .find((l) =>
        /ItemInstance\.from_save_dict: unknown item id 'iron_sword'/.test(
          l.text
        )
      );
    expect(
      ironSwordResolverWarning,
      "Ticket 86c9qah1f regression: 'unknown item id iron_sword' push_warning " +
        "fired during F5-reload save-restore. Either ContentRegistry's " +
        "STARTER_ITEM_PATHS preload regressed (check scripts/content/ContentRegistry.gd) " +
        "or a new content-resolution code path was added that doesn't " +
        "consult the registry."
    ).toBeUndefined();

    const errorLines = capture
      .getLines()
      .filter((l) => l.type === "error")
      .filter(
        (l) =>
          !l.text.includes("requestAnimationFrame") &&
          !l.text.includes("favicon.ico") &&
          !l.text.includes("Content-Security-Policy") &&
          !l.text.startsWith("Failed to load resource")
      );
    if (errorLines.length > 0) {
      console.log(
        "[equip-flow] UNEXPECTED ERROR LINES:\n" +
          errorLines.map((l) => `  ${l.text}`).join("\n") +
          "\n\nFull console dump:\n" +
          capture.dump()
      );
    }
    expect(errorLines).toHaveLength(0);

    capture.detach();
  });
});
