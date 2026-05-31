/**
 * contextmenu-suppress.spec.ts
 *
 * Regression guard for the browser right-click (RMB) context-menu suppressor
 * shipped in export_presets.cfg `html/head_include`.
 *
 * Why this exists: RMB is the in-game HEAVY-ATTACK bind. In the browser, a
 * right-click ALSO fires the native `contextmenu` event, popping the browser's
 * context menu over the canvas and stealing input focus until the user
 * dismisses it. The suppressor preventDefault's the `contextmenu` event so the
 * native menu never shows and RMB stays a pure gameplay input.
 *
 * The original PR #235 suppressor deferred BOTH the document- and canvas-level
 * `addEventListener` calls to `DOMContentLoaded`, leaving a head-parse -> DCL
 * window with no suppressor at all (a real-browser cold-load right-click could
 * leak before DCL fired). The hardened form registers the document-level
 * preventDefault SYNCHRONOUSLY at <head>-parse time, on BOTH capture and bubble
 * phases at `document`, plus a canvas-specific capture listener re-added on DCL.
 *
 * Coverage (the bug CLASS, not just one instance):
 *   1. A real right-click at the canvas center does NOT leave the contextmenu
 *      event un-prevented (defaultPrevented === true after the event cycle).
 *   2. A synthetic contextmenu dispatched at the canvas, body (letterbox
 *      margin), and document all end up defaultPrevented — the whole page
 *      surface is covered, not just the canvas.
 *   3. The document-level suppressor is active as soon as the canvas is
 *      present (readyState already complete by the time the canvas exists),
 *      i.e. there is no late-attach gap on a normal load.
 *
 * Probe technique: assert `event.defaultPrevented` after dispatching/firing
 * the contextmenu — that is the exact browser signal that gates whether the
 * native menu shows. This is the headless proxy for "no native menu appears"
 * (Playwright cannot screenshot the OS-drawn context menu chrome).
 *
 * References:
 *   - export_presets.cfg `html/head_include` — the injected suppressor script
 *   - .claude/docs/html5-export.md §"Browser-native event leakage (RMB context menu)"
 *   - Sponsor HTML5/WebGL2 re-soak finding: "RMB heavy attack still triggers
 *     the browser's context menu"
 */

import { test, expect } from "../fixtures/test-base";

function baseUrl(): string {
  return process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
}

test.describe("RMB context-menu suppression", () => {
  test("real right-click on canvas does not leave contextmenu un-prevented", async ({
    page,
  }) => {
    test.setTimeout(60_000);

    await page.goto(baseUrl(), { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#canvas", { timeout: 15_000 });
    // Let the head_include DOMContentLoaded path + engine boot settle.
    await page.waitForTimeout(4_000);

    // Capture-phase observer at document records every contextmenu event so we
    // can confirm a REAL right-click actually generated one at the canvas.
    await page.evaluate(() => {
      (window as unknown as { __ctx: unknown[] }).__ctx = [];
      document.addEventListener(
        "contextmenu",
        (e) => {
          (window as unknown as { __ctx: { target: string }[] }).__ctx.push({
            target:
              (e.target as Element)?.id ||
              (e.target as Element)?.tagName ||
              "?",
          });
        },
        true,
      );
    });

    const box = await page.locator("#canvas").boundingBox();
    expect(box).not.toBeNull();
    const cx = box!.x + box!.width / 2;
    const cy = box!.y + box!.height / 2;

    // Fire a genuine browser right-click at canvas center.
    await page.mouse.move(cx, cy);
    await page.mouse.down({ button: "right" });
    await page.mouse.up({ button: "right" });
    await page.waitForTimeout(300);

    // The real right-click must have produced a contextmenu event on the canvas.
    const captured = await page.evaluate(
      () => (window as unknown as { __ctx: { target: string }[] }).__ctx,
    );
    expect(captured.length).toBeGreaterThan(0);
    expect(captured.some((c) => c.target === "canvas")).toBe(true);

    // Definitive: a fresh contextmenu at the element under the cursor must end
    // up defaultPrevented — the browser only shows its native menu when the
    // event survives the cycle un-prevented.
    const final = await page.evaluate(
      ({ x, y }: { x: number; y: number }) => {
        const el = document.elementFromPoint(x, y) || document.body;
        const ev = new MouseEvent("contextmenu", {
          bubbles: true,
          cancelable: true,
          clientX: x,
          clientY: y,
        });
        el.dispatchEvent(ev);
        return {
          element: (el as Element).id || (el as Element).tagName,
          defaultPrevented: ev.defaultPrevented,
        };
      },
      { x: cx, y: cy },
    );

    expect(final.defaultPrevented).toBe(true);
  });

  test("contextmenu is suppressed across canvas, body margin, and document", async ({
    page,
  }) => {
    test.setTimeout(60_000);

    await page.goto(baseUrl(), { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#canvas", { timeout: 15_000 });
    await page.waitForTimeout(4_000);

    const results = await page.evaluate(() => {
      const fire = (target: EventTarget) => {
        const ev = new MouseEvent("contextmenu", {
          bubbles: true,
          cancelable: true,
        });
        target.dispatchEvent(ev);
        return ev.defaultPrevented;
      };
      const canvas = document.getElementById("canvas");
      return {
        canvas: canvas ? fire(canvas) : null,
        body: fire(document.body),
        document: fire(document),
      };
    });

    // All three surfaces must be prevented — the document-level capture/bubble
    // listener is the airtight catch-all; the canvas listener is belt-and-suspenders.
    expect(results.canvas).toBe(true);
    expect(results.body).toBe(true);
    expect(results.document).toBe(true);
  });

  test("Shift+right-click contextmenu is suppressed (heavy-attack combo)", async ({
    page,
  }) => {
    test.setTimeout(60_000);

    // WHY: Shift+RMB is the in-game SPRINT + HEAVY-ATTACK combo. Sponsor re-soak
    // #5 (Brave/Chromium) reported the browser context menu STILL appears on
    // Shift+RMB even though plain RMB is suppressed. MDN documents a Firefox-only
    // escape hatch where Shift+RightClick shows the menu WITHOUT firing the
    // contextmenu event (un-suppressible from JS). This test pins the EMPIRICAL
    // reality for the engine we ship against (Chromium/Brave): the contextmenu
    // event DOES fire with shiftKey set, and the suppressor's preventDefault is
    // honored. (Verified against the real Brave binary via CDP during the fix —
    // both plain and shift right-click reach the suppressor and end
    // defaultPrevented. There is NO modifier gate in the suppressor to begin
    // with; the fix hardens the registration to window-level capture so nothing
    // can intercept the shift-modified event before our preventDefault runs.)
    //
    // Regression teeth: this FAILS if a future edit (a) adds an `if(!e.shiftKey)`
    // gate to the block, or (b) regresses the capture-phase registration so a
    // mid-chain stopPropagation can swallow the event before our listener.

    await page.goto(baseUrl(), { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#canvas", { timeout: 15_000 });
    await page.waitForTimeout(4_000);

    // 1) Synthetic contextmenu carrying shiftKey:true on every page surface must
    //    end defaultPrevented — same airtight coverage as the plain case.
    const synthetic = await page.evaluate(() => {
      const fire = (target: EventTarget) => {
        const ev = new MouseEvent("contextmenu", {
          bubbles: true,
          cancelable: true,
          shiftKey: true,
        });
        target.dispatchEvent(ev);
        return ev.defaultPrevented;
      };
      const canvas = document.getElementById("canvas");
      return {
        canvas: canvas ? fire(canvas) : null,
        body: fire(document.body),
        document: fire(document),
      };
    });
    expect(synthetic.canvas).toBe(true);
    expect(synthetic.body).toBe(true);
    expect(synthetic.document).toBe(true);

    // 2) A REAL Shift+right-click at canvas center: hold Shift, right-click,
    //    confirm the browser-fired contextmenu carried shiftKey:true and ended
    //    defaultPrevented. This is the direct analog of Sponsor's gesture.
    await page.evaluate(() => {
      (window as unknown as { __shiftCtx: { shift: boolean; prevented: boolean }[] }).__shiftCtx = [];
      document.addEventListener(
        "contextmenu",
        (e) => {
          queueMicrotask(() => {
            (window as unknown as { __shiftCtx: { shift: boolean; prevented: boolean }[] }).__shiftCtx.push({
              shift: e.shiftKey,
              prevented: e.defaultPrevented,
            });
          });
        },
        false,
      );
    });

    const box = await page.locator("#canvas").boundingBox();
    expect(box).not.toBeNull();
    const cx = box!.x + box!.width / 2;
    const cy = box!.y + box!.height / 2;

    await page.keyboard.down("Shift");
    await page.mouse.move(cx, cy);
    await page.mouse.down({ button: "right" });
    await page.mouse.up({ button: "right" });
    await page.keyboard.up("Shift");
    await page.waitForTimeout(300);

    const realShift = await page.evaluate(
      () => (window as unknown as { __shiftCtx: { shift: boolean; prevented: boolean }[] }).__shiftCtx,
    );
    // The real shift+right-click must have fired a contextmenu with shiftKey set,
    // and it must be prevented (no native menu).
    expect(realShift.some((e) => e.shift)).toBe(true);
    expect(realShift.every((e) => e.prevented)).toBe(true);
  });

  test("Shift+right-click still delivers button-2 to the game (heavy attack fires)", async ({
    page,
  }) => {
    test.setTimeout(60_000);

    // Guards the inverse risk: the contextmenu suppression must NOT swallow the
    // mousedown/pointerdown (button 2) that Godot reads for the heavy-attack.
    // preventDefault on `contextmenu` is a SEPARATE event from the pointer/mouse
    // button events; this test pins that the button-2 inputs still REACH the
    // canvas under Shift, so heavy-attack still fires.
    //
    // NOTE on defaultPrevented: against the real Godot WASM build, the engine's
    // own glue calls preventDefault() on the canvas mousedown it CONSUMES for
    // input — so `defaultPrevented` is TRUE on the real build and that is
    // correct (Godot received the input; the preventDefault is Godot's, made
    // AFTER it read the event, and does not stop the heavy-attack). Therefore we
    // assert DELIVERY (a button-2 mousedown reached the canvas), NOT
    // defaultPrevented state — delivery is the load-bearing signal that the
    // heavy-attack input is intact. Our contextmenu suppressor only touches the
    // `contextmenu` event, never mousedown/pointerdown.
    await page.goto(baseUrl(), { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#canvas", { timeout: 15_000 });
    await page.waitForTimeout(4_000);

    await page.evaluate(() => {
      (window as unknown as { __btn2: { type: string; button: number; prevented: boolean }[] }).__btn2 = [];
      const c = document.getElementById("canvas")!;
      for (const t of ["pointerdown", "mousedown"]) {
        c.addEventListener(t, (e) => {
          const me = e as MouseEvent;
          (window as unknown as { __btn2: { type: string; button: number; prevented: boolean }[] }).__btn2.push({
            type: me.type,
            button: me.button,
            prevented: me.defaultPrevented,
          });
        });
      }
    });

    const box = await page.locator("#canvas").boundingBox();
    expect(box).not.toBeNull();
    const cx = box!.x + box!.width / 2;
    const cy = box!.y + box!.height / 2;

    await page.keyboard.down("Shift");
    await page.mouse.move(cx, cy);
    await page.mouse.down({ button: "right" });
    await page.mouse.up({ button: "right" });
    await page.keyboard.up("Shift");
    await page.waitForTimeout(200);

    const btn2 = await page.evaluate(
      () => (window as unknown as { __btn2: { type: string; button: number; prevented: boolean }[] }).__btn2,
    );
    // A button-2 mousedown must have REACHED the canvas (heavy-attack input is
    // delivered — only the contextmenu event is suppressed, never the mouse
    // button events). defaultPrevented is intentionally NOT asserted: the real
    // Godot build sets it itself after consuming the input (see NOTE above).
    const heavyDown = btn2.filter((e) => e.type === "mousedown" && e.button === 2);
    expect(heavyDown.length).toBeGreaterThan(0);
  });

  test("suppressor is active as soon as the canvas exists (no late-attach gap)", async ({
    page,
  }) => {
    test.setTimeout(45_000);

    await page.goto(baseUrl(), { waitUntil: "commit" });
    await page.waitForSelector("#canvas", { timeout: 10_000 });

    // The document-level listener is registered synchronously at <head>-parse,
    // so the moment the canvas is selectable a contextmenu is already prevented.
    const early = await page.evaluate(() => {
      const c = document.getElementById("canvas")!;
      const ev = new MouseEvent("contextmenu", {
        bubbles: true,
        cancelable: true,
      });
      c.dispatchEvent(ev);
      return { readyState: document.readyState, defaultPrevented: ev.defaultPrevented };
    });

    expect(early.defaultPrevented).toBe(true);
  });
});
