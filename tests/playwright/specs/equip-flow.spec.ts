/**
 * equip-flow.spec.ts
 *
 * Equip flow — equipped weapon survives F5 reload (save → restore round-trip)
 * AND equip-via-LMB-click drives BOTH dual-surface state in lockstep
 *
 * Verifies the equip-state persistence path AND the in-game LMB-click equip
 * path that PR #145 / #146 / closed P0 86c9q96m8 all hit in different ways:
 *
 *   1. Cold boot: iron_sword auto-equipped via the Inventory.gd seeding +
 *      Main._ready ordering (PR #146).
 *   2. Player kills a grunt → Hitbox.hit registers damage=6.
 *   3. **NEW (P0 86c9q96m8 fix coverage):** open Tab inventory, click the
 *      equipped slot to unequip (iron_sword → grid), then click the grid
 *      cell to re-equip via the LMB-click path. Asserts the new
 *      `[combat-trace] Inventory.equip | source=lmb_click damage_after=6`
 *      line fires AND post-equip swing damage matches.
 *   4. F5 reload → Save autoload restores equipped state from snapshot.
 *   5. Post-reload: a fresh swing in Room 01 still produces damage=6 hits
 *      (proves Inventory._equipped["weapon"] AND Player._equipped_weapon
 *      both restored to iron_sword — the dual-surface invariant).
 *
 * **Status: green — P0 86c9q96m8 fix landed.**
 *
 * Coverage gap closed by this spec extension:
 *   - Tab → LMB-click equipped slot (unequip) → LMB-click grid cell (equip).
 *   - The `[combat-trace] Inventory.equip` shim now provides the
 *     observable signature for the LMB-click path.
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

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

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
    await capture.waitForLine(
      /\[Inventory\] starter iron_sword auto-equipped \(weapon slot\)/,
      5_000
    );

    const canvas = page.locator("canvas").first();
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB = await canvas.boundingBox();
    const clickX = (canvasBB?.x ?? 0) + (canvasBB?.width ?? 1280) / 2;
    const clickY = (canvasBB?.y ?? 0) + (canvasBB?.height ?? 720) / 2;

    // Set facing NE for grunt approach
    await page.keyboard.down("w");
    await page.keyboard.down("d");
    await page.waitForTimeout(100);
    await page.keyboard.up("w");
    await page.keyboard.up("d");
    await page.waitForTimeout(600);

    // ---- Phase 2: Kill a grunt and observe pre-reload damage=6 ----
    const preReloadStart = Date.now();
    let preReloadDamageObserved: number | null = null;

    while (Date.now() - preReloadStart < KILL_TIMEOUT_MS) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);

      const hitLine = capture
        .getLines()
        .find((l) =>
          /\[combat-trace\] Hitbox\.hit \| team=player.*damage=(\d+)/.test(
            l.text
          )
        );
      if (hitLine) {
        const m = hitLine.text.match(/damage=(\d+)/);
        if (m) {
          preReloadDamageObserved = parseInt(m[1], 10);
          console.log(
            `[equip-flow] Pre-reload first hit damage=${preReloadDamageObserved}`
          );
          break;
        }
      }
    }
    expect(preReloadDamageObserved).not.toBeNull();
    expect(preReloadDamageObserved).toBeGreaterThanOrEqual(2);

    // Continue attacking until at least one grunt dies — proves the full
    // combat→damage→death pipeline before reload.
    while (Date.now() - preReloadStart < KILL_TIMEOUT_MS) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      const dieLine = capture
        .getLines()
        .find((l) => /\[combat-trace\] Grunt\._die/.test(l.text));
      if (dieLine) {
        console.log(
          `[equip-flow] Pre-reload kill landed at t=${Date.now() - preReloadStart}ms.`
        );
        break;
      }
    }

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

    // Close Tab.
    await page.keyboard.press("Tab");
    await page.waitForTimeout(300);

    // ---- MAIN ASSERTION 2: post-LMB-equip swings still hit damage=6 ----
    // The dual-surface invariant: Player._equipped_weapon got refreshed by
    // the LMB-click path. Confirm by firing a swing and watching for
    // Hitbox.hit damage matching the pre-reload value.
    await canvas.click(); // re-focus
    await page.waitForTimeout(300);

    // Re-set facing NE (Tab+clicks may have lost focus).
    await page.keyboard.down("w");
    await page.keyboard.down("d");
    await page.waitForTimeout(100);
    await page.keyboard.up("w");
    await page.keyboard.up("d");
    await page.waitForTimeout(400);

    const phase25SwingStart = Date.now();
    let postLmbEquipDamage: number | null = null;
    while (Date.now() - phase25SwingStart < 30_000) {
      await canvas.click({ position: { x: clickX, y: clickY } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);
      // Look for hits AFTER the trace line (so we don't pick up pre-Tab hits).
      const recentLines = capture.getLines().slice(phase25LineCount);
      const hitLine = recentLines.find((l) =>
        /\[combat-trace\] Hitbox\.hit \| team=player.*damage=(\d+)/.test(l.text)
      );
      if (hitLine) {
        const m = hitLine.text.match(/damage=(\d+)/);
        if (m) {
          postLmbEquipDamage = parseInt(m[1], 10);
          break;
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

    // The auto-equip line is conditional. equip_starter_weapon_if_needed
    // is a no-op if Inventory._equipped["weapon"] is non-null. The save-
    // restored state should already have iron_sword equipped, so the
    // auto-equip print MAY OR MAY NOT fire. We don't assert either way —
    // the load-bearing assertion is on damage trace below.

    // Wait briefly for save-restore deferred frames
    await page.waitForTimeout(1_000);

    // Re-focus canvas and re-attack
    await canvas.click();
    await page.waitForTimeout(500);

    const canvasBB2 = await canvas.boundingBox();
    const clickX2 = (canvasBB2?.x ?? 0) + (canvasBB2?.width ?? 1280) / 2;
    const clickY2 = (canvasBB2?.y ?? 0) + (canvasBB2?.height ?? 720) / 2;

    // Set facing NE again — facing is per-instance state, lost in reload
    await page.keyboard.down("w");
    await page.keyboard.down("d");
    await page.waitForTimeout(100);
    await page.keyboard.up("w");
    await page.keyboard.up("d");
    await page.waitForTimeout(600);

    const postReloadStart = Date.now();
    let postReloadDamageObserved: number | null = null;

    while (Date.now() - postReloadStart < POST_RELOAD_HIT_TIMEOUT_MS) {
      await canvas.click({ position: { x: clickX2, y: clickY2 } });
      await page.waitForTimeout(ATTACK_INTERVAL_MS);

      const hitLine = capture
        .getLines()
        .find((l) =>
          /\[combat-trace\] Hitbox\.hit \| team=player.*damage=(\d+)/.test(
            l.text
          )
        );
      if (hitLine) {
        const m = hitLine.text.match(/damage=(\d+)/);
        if (m) {
          postReloadDamageObserved = parseInt(m[1], 10);
          console.log(
            `[equip-flow] Post-reload first hit damage=${postReloadDamageObserved}`
          );
          break;
        }
      }
    }

    // ---- MAIN ASSERTION ----
    expect(
      postReloadDamageObserved,
      "Post-reload: no Hitbox.hit|team=player observed in 60s. The harness " +
        "could not produce a swing→hit. Either canvas focus failed or grunts " +
        "were not in range. Re-check spawn positions in Room 01."
    ).not.toBeNull();

    expect(
      postReloadDamageObserved,
      `equip-flow REGRESSION: post-reload damage=${postReloadDamageObserved} (expected >=2). ` +
        `The save → restore_from_save round-trip lost the equipped iron_sword. ` +
        `Either Inventory.restore_from_save's reset loop wiped equipped state, ` +
        `or Player._equipped_weapon was not re-applied via _apply_equip_to_player. ` +
        `Compare pre-reload damage=${preReloadDamageObserved} vs post-reload=${postReloadDamageObserved}.`
    ).toBeGreaterThanOrEqual(2);

    // The pre-reload and post-reload damages should match (same equipped weapon,
    // same edge formula, same room geometry). If they differ, something in the
    // equipped-state restoration path subtly diverged.
    expect(postReloadDamageObserved).toBe(preReloadDamageObserved);

    // ---- Negative assertions ----
    const panicLine = capture.findUnexpectedLine(
      /Can't change this state while flushing queries/
    );
    expect(panicLine).toBeNull();

    // P0 86c9q96m8 trace-shim scoping: the [combat-trace] Inventory.equip line
    // MUST NOT fire from the F5-reload save-restore path. `restore_from_save`
    // bypasses `equip()` (it directly mutates `_equipped[slot]` and calls
    // `_apply_equip_to_player` synchronously), so no trace line should be
    // present after the page.reload(). If we see one, the trace shim was
    // accidentally wired into the save-restore path too — the line shape
    // would be identical and Sponsor would see double-fires (one on click,
    // one on every page reload).
    //
    // We scope the search to AFTER `capture.clearLines()` (line 163-ish),
    // which fires immediately before the page.reload(). Anything in the
    // buffer AFTER that point is post-reload activity.
    const postReloadTraceLines = capture
      .getLines()
      .filter((l) =>
        /\[combat-trace\] Inventory\.equip \| .*source=lmb_click/.test(l.text)
      );
    expect(
      postReloadTraceLines.length,
      `Negative assertion: [combat-trace] Inventory.equip line fired during ` +
        `F5-reload save-restore — should ONLY fire on user-driven LMB-click. ` +
        `Found ${postReloadTraceLines.length} post-reload trace line(s). ` +
        `Re-check Inventory.restore_from_save: it must NOT route through equip().`
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
