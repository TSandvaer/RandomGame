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
 * leak before DCL fired). The hardened form (PR #386) registers the
 * document-level preventDefault SYNCHRONOUSLY at <head>-parse time, on BOTH
 * capture and bubble phases at `document`, plus a canvas-specific capture
 * listener re-added on DCL.
 *
 * Coverage (the bug CLASS, not just one instance):
 *   1. A real right-click at the canvas center does NOT leave the contextmenu
 *      event un-prevented (defaultPrevented === true after the event cycle).
 *   2. A synthetic contextmenu dispatched at the canvas, body (letterbox
 *      margin), and document all end up defaultPrevented — the whole page
 *      surface is covered, not just the canvas.
 *   3. The document-level suppressor is active during the PRE-DCL window
 *      (readyState === "loading"), i.e. there is no late-attach gap — this is
 *      the test that goes RED if someone reverts to the DCL-deferred form.
 *
 * Probe technique: assert `event.defaultPrevented` after dispatching/firing
 * the contextmenu — that is the exact browser signal that gates whether the
 * native menu shows. This is the headless proxy for "no native menu appears"
 * (Playwright cannot screenshot the OS-drawn context menu chrome).
 *
 * ─────────────────────────────────────────────────────────────────────────
 * HARDENING (tess/contextmenu-test-harden) — why the OLD test 5 was a false-green
 * ─────────────────────────────────────────────────────────────────────────
 * The OLD test 5 ("suppressor is active as soon as the canvas exists") did:
 *     await page.goto(baseUrl(), { waitUntil: "commit" });
 *     await page.waitForSelector("#canvas", { timeout: 10_000 });
 *     // ...then dispatch a contextmenu and assert defaultPrevented === true
 * On a fast headless load (the ~10 KB shell + a static <canvas> parse
 * near-instantly) DOMContentLoaded has ALREADY fired by the time
 * `waitForSelector("#canvas")` resolves and `page.evaluate` runs the dispatch.
 * So the DCL-deferred (reverted) form would have ATTACHED its listener by then,
 * and the test passes WITH OR WITHOUT the head-parse-synchronous hardening.
 * Empirically: the old test 5 passed 8/8 on a hand-reverted DCL-deferred build
 * (PR #386 QA note, `team/tess-qa/_pr386-approve.md` finding). It covered the
 * bug *surface* but had no teeth — reverting the fix would NOT turn it red.
 *
 * The fix: probe the contextmenu suppression DURING the pre-DCL window
 * (`document.readyState === "loading"`), the only window the DCL-deferred form
 * leaks. We do this build-faithfully by INTERCEPTING the served index.html and
 * splicing a tiny probe <script> in immediately AFTER the real head_include
 * suppressor (and before </head>). That probe runs synchronously during head
 * parse — right after the suppressor would have registered IF it is
 * synchronous — fires a `contextmenu` at `document` while readyState is still
 * "loading", and stashes `{readyState, defaultPrevented}` on window. The test
 * then reads the stash:
 *   - Hardened build (head-parse-synchronous): probe sees the listener →
 *     defaultPrevented === true.
 *   - Reverted build (DCL-deferred OR suppressor removed): listener not yet
 *     attached at head-parse → defaultPrevented === false → test goes RED.
 * A control assertion inside the probe (dispatch with the suppressor's own
 * `block` semantics absent) is not needed: the readyState==="loading" guard
 * proves we are genuinely pre-DCL, so a `true` result can only come from the
 * synchronous registration.
 *
 * References:
 *   - export_presets.cfg `html/head_include` — the injected suppressor script
 *   - .claude/docs/html5-export.md §"Browser-native event leakage (RMB context menu)"
 *   - team/tess-qa/_pr386-approve.md — the non-blocking false-green finding this PR closes
 */

import { test, expect } from "../fixtures/test-base";

function baseUrl(): string {
  return process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
}

/**
 * The probe <script> spliced into the served index.html immediately before
 * </head>, i.e. AFTER the real head_include suppressor. It runs synchronously
 * during head parse while document.readyState === "loading", fires a
 * cancelable `contextmenu` at `document`, and records whether the suppressor
 * (which must already be registered, if it is head-parse-synchronous) cancelled
 * it. Result is stashed on window for the test to read post-load.
 *
 * It also runs a NEGATIVE control: it dispatches a plain `click` event (which
 * the suppressor does NOT touch) and records its defaultPrevented — this must
 * be false, proving the probe machinery can observe an UN-prevented event and
 * the `contextmenu` true-result is meaningful (not a harness artifact).
 */
const PRE_DCL_PROBE_SCRIPT = `
<script>
(function () {
  try {
    var atLoading = (document.readyState === 'loading');
    var ctx = new MouseEvent('contextmenu', { bubbles: true, cancelable: true });
    document.dispatchEvent(ctx);
    var ctrl = new MouseEvent('click', { bubbles: true, cancelable: true });
    document.dispatchEvent(ctrl);
    window.__preDclProbe = {
      ran: true,
      readyStateAtProbe: document.readyState,
      atLoading: atLoading,
      contextmenuPrevented: ctx.defaultPrevented,
      controlClickPrevented: ctrl.defaultPrevented
    };
  } catch (e) {
    window.__preDclProbe = { ran: true, error: String(e) };
  }
})();
</script>
`;

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
      // NEGATIVE CONTROL: a plain `click` is NOT touched by the suppressor;
      // it must end up NOT-prevented. This proves the dispatch machinery can
      // observe an un-prevented event, so the `true` results below are
      // meaningful (the suppressor is actually doing the work, the harness is
      // not trivially reporting true for everything).
      const controlClick = (() => {
        const ev = new MouseEvent("click", { bubbles: true, cancelable: true });
        document.dispatchEvent(ev);
        return ev.defaultPrevented;
      })();
      const canvas = document.getElementById("canvas");
      return {
        canvas: canvas ? fire(canvas) : null,
        body: fire(document.body),
        document: fire(document),
        controlClick,
      };
    });

    // Negative control: plain click must NOT be prevented.
    expect(
      results.controlClick,
      "control: a plain click must NOT be preventDefault-ed — if it is, the " +
        "harness cannot distinguish prevented from un-prevented and the " +
        "contextmenu assertions below are meaningless",
    ).toBe(false);

    // All three contextmenu surfaces must be prevented — the document-level
    // capture/bubble listener is the airtight catch-all; the canvas listener is
    // belt-and-suspenders.
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

  test("suppressor is active during the pre-DCL window (no late-attach gap — RED on revert)", async ({
    page,
  }) => {
    test.setTimeout(45_000);

    // ── HARDENED (see file header) ──────────────────────────────────────────
    // The OLD form of this test dispatched AFTER waitForSelector("#canvas"),
    // by which point DOMContentLoaded had already fired on a fast headless
    // load — so it passed even on the DCL-deferred (reverted) suppressor. This
    // form intercepts the served index.html and splices a probe <script> in
    // right before </head>, AFTER the real head_include suppressor. The probe
    // fires a contextmenu at `document` synchronously during head parse, while
    // document.readyState === "loading" (genuinely pre-DCL), and records
    // whether it was prevented.
    //
    //   • Hardened build (head-parse-synchronous registration): the suppressor's
    //     document capture listener is ALREADY attached when the probe runs →
    //     contextmenuPrevented === true.
    //   • Reverted build (DCL-deferred form, OR suppressor removed entirely):
    //     no document listener yet at head-parse → contextmenuPrevented ===
    //     false → this test goes RED. THESE are the teeth.

    let splicedHtmlServed = false;
    await page.route("**/*", async (route) => {
      const req = route.request();
      const url = req.url();
      const isIndex =
        req.resourceType() === "document" ||
        url.endsWith("/") ||
        url.endsWith("/index.html");
      if (!isIndex) {
        await route.continue();
        return;
      }
      // Fetch the real served index.html, splice the probe in before </head>,
      // and fulfil with the modified body. This keeps the REAL head_include
      // suppressor intact and only ADDS the probe immediately after it.
      const response = await route.fetch();
      const original = await response.text();
      // Safety: only splice if we recognise the document shape.
      if (!original.includes("</head>")) {
        await route.fulfill({ response });
        return;
      }
      const modified = original.replace(
        "</head>",
        `${PRE_DCL_PROBE_SCRIPT}</head>`,
      );
      splicedHtmlServed = true;
      await route.fulfill({
        response,
        body: modified,
        headers: {
          ...response.headers(),
          "content-type": "text/html",
        },
      });
    });

    await page.goto(baseUrl(), { waitUntil: "domcontentloaded" });

    // The route must have actually intercepted + spliced the document — if it
    // didn't, the test below would vacuously read `undefined` and we'd be back
    // to a false-green. Fail loudly if the splice never happened.
    expect(
      splicedHtmlServed,
      "the index.html route interception did not fire — the pre-DCL probe was " +
        "never spliced in, so this test cannot verify the suppressor; harness bug",
    ).toBe(true);

    const probe = await page.evaluate(
      () =>
        (
          window as unknown as {
            __preDclProbe?: {
              ran?: boolean;
              readyStateAtProbe?: string;
              atLoading?: boolean;
              contextmenuPrevented?: boolean;
              controlClickPrevented?: boolean;
              error?: string;
            };
          }
        ).__preDclProbe,
    );

    // The probe must have run and recorded a result.
    expect(probe, "pre-DCL probe did not run / left no result").toBeTruthy();
    expect(probe!.ran).toBe(true);
    expect(probe!.error, `pre-DCL probe threw: ${probe!.error}`).toBeUndefined();

    // The probe must genuinely have executed during the pre-DCL window — this
    // is what makes the test a real regression-catcher rather than a re-run of
    // the post-DCL surface the old test covered.
    expect(
      probe!.atLoading,
      `pre-DCL probe ran at readyState="${probe!.readyStateAtProbe}", not ` +
        `"loading" — the probe must execute during head parse for this test to ` +
        `exercise the pre-DCL window the DCL-deferred form leaks`,
    ).toBe(true);

    // Negative control: a plain click (untouched by the suppressor) must NOT be
    // prevented — proves the probe can observe an un-prevented event, so the
    // contextmenu-true result is meaningful.
    expect(
      probe!.controlClickPrevented,
      "control: a plain click was preventDefault-ed during the probe — the " +
        "probe cannot distinguish prevented from un-prevented",
    ).toBe(false);

    // THE TEETH: pre-DCL, the contextmenu MUST already be suppressed. Reverting
    // to the DCL-deferred form (or removing the suppressor) flips this to false.
    expect(
      probe!.contextmenuPrevented,
      "pre-DCL contextmenu was NOT preventDefault-ed (readyState was " +
        `"loading") — the head_include suppressor is NOT registered ` +
        "synchronously at head-parse. This is the DCL-deferred-regression / " +
        "suppressor-removed signal (export_presets.cfg head_include).",
    ).toBe(true);
  });
});
