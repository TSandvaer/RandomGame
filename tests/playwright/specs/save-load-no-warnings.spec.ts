/**
 * save-load-no-warnings.spec.ts
 *
 * **Save-load no-warning smoke spec — Sponsor M2 RC soak meta-finding
 * (2026-05-15), ticket 86c9uerqx.**
 *
 * Sponsor directive: "the tester should be able to test what I found."
 *
 * The `leather_vest` unknown-id warning (bug 86c9uen3z) fired at boot in
 * Sponsor's M2 RC soak log (build `embergrave-html5-5bef197`) and had NO
 * harness coverage — it was caught only by Sponsor's console-log eyeball.
 * Verbatim symptom from the soak log:
 *
 *   USER WARNING: ItemInstance.from_save_dict: unknown item id 'leather_vest'
 *       at: push_warning (core/variant/variant_utility.cpp:1112)
 *
 * The warning fires between `[Inventory] autoload ready (capacity=24)` and
 * `[Main] M1 play-loop ready` — i.e. during the save-payload-restore
 * pass that runs as part of the autoload chain. Godot's HTML5 export
 * routes `push_warning(...)` calls through the JS `console.warn` channel
 * with the `USER WARNING:` prefix (see `tests/playwright/fixtures/
 * console-capture.ts` § Godot HTML5 console mapping). So a Playwright
 * `console.warn` capture would have caught this on the first release-build
 * Playwright run, before Sponsor ever loaded the artifact.
 *
 * **This spec's scope:** assert NO `USER WARNING:` or `USER ERROR:` console
 * lines fire during the cold-boot → autoload-chain → first-room-ready
 * window. Three variants documented in the ticket; this PR ships the
 * SMOKE variant as `test.fail()` and scaffolds the MIGRATION + UNKNOWN-ID
 * variants for follow-up extraction once Devon's fix lands.
 *
 * **Variant 1 — SMOKE (default cold boot, no save loaded).** The cleanest
 * variant: boot the artifact in an empty IndexedDB browser context. No
 * save data exists, so `Save.load_game` returns the default empty payload
 * and `Inventory.restore_from_save` runs against an empty inventory.
 * Expected post-fix: zero `USER WARNING:` / `USER ERROR:` lines between
 * boot and `[Main] M1 play-loop ready`.
 *
 * This is the variant that catches the `leather_vest` bug directly — at
 * Sponsor's soak the IndexedDB contained a save from a prior session that
 * had `leather_vest` in the inventory; the fresh-context behavior here
 * exercises the same code path with the default save instead, but the
 * spec class is `console.warn` based and any *new* unknown-id added to a
 * future M2/M3 save would also surface.
 *
 * **Variant 2 — MIGRATION (v3 save → v4 migration fires cleanly).**
 * Synthesize a v3 envelope in IndexedDB via Playwright's `addInitScript`
 * before navigation, then assert (a) `[Save] autoload ready (schema v4)`
 * fires (NOT v3 — proves the migration ran) AND (b) zero warnings during
 * the migration. This is the load-bearing safety net for R1 (Save
 * migration risk) — if the v3→v4 path ever silently no-ops, this spec
 * flips RED before any Sponsor sees a half-migrated save.
 *
 * **Variant 3 — UNKNOWN-ID GRACEFUL (synthesized save with a deliberately-
 * unknown id).** Synthesize a save with `inventory: [{"id": "definitely_
 * not_a_real_item_id_zzzz"}, ...]`. Expected post-fix: the warning fires
 * (we EXPECT it — graceful handling per `ItemInstance.from_save_dict:103`
 * "unknown item id" push_warning is the documented behavior for forward-
 * compat), but (a) `[Main] M1 play-loop ready` still fires (no crash), and
 * (b) the rest of the save loads correctly (other items aren't dropped).
 * This is the "we shipped the safety net" assertion — the warning is
 * acceptable, the crash is not.
 *
 * **Disposition this PR (initial scaffold):**
 *
 *   - **Smoke variant** — `test.fail()` until Devon's `86c9uen3z` fix
 *     lands. The variant catches the active Sponsor bug on flip.
 *
 *   - **Migration variant** — `test.fail()` indefinitely. Needs the v3
 *     IndexedDB synthesis primitive (`seedSaveInIndexedDB` helper), filed
 *     as a follow-up extraction on this ticket. The full assertion logic
 *     is in place; only the seeding step is a TODO.
 *
 *   - **Unknown-id graceful variant** — `test.fail()` indefinitely. Same
 *     seeding primitive needed. Full assertion logic in place.
 *
 * **Why a Playwright spec, not a GUT test?** The Sponsor finding fires
 * specifically in the HTML5 release build via `console.warn` capture.
 * Godot's `--headless` GUT runner captures `push_warning` via `stderr`,
 * not via a structured JS console channel — and the M2 RC contract is
 * "the artifact Sponsor downloads ships clean." Playwright is the only
 * harness that sees what Sponsor sees. (A paired GUT test for the
 * migration path is filed under W3-T6 stress fixtures, separately.)
 *
 * **Pairs with:**
 *   - ClickUp 86c9uen3z — Devon's leather_vest fix (flip-trigger for
 *     variant 1)
 *   - W3-T6 — v4 stress fixtures (Tess + Devon co-owned; provides the
 *     concrete save shapes for variants 2 + 3 once the helper extracts)
 *   - `.claude/docs/combat-architecture.md` § "Harness coverage gap" (the
 *     Sponsor-authored doc section motivating this spec class)
 *
 * References:
 *   - scripts/save/Save.gd § "[Save] autoload ready (schema vN)"
 *   - scripts/loot/ItemInstance.gd:103 — push_warning("ItemInstance.
 *     from_save_dict: unknown item id '%s'")
 *   - scripts/inventory/Inventory.gd:299 — restore_from_save
 *   - tests/playwright/fixtures/console-capture.ts — Godot push_warning
 *     → console.warn mapping
 *   - ClickUp 86c9uerqx — this ticket (W3-T14 scaffold)
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

/** Timeout for the [Main] M1 play-loop ready sentinel — full autoload + first-room load. */
const BOOT_TIMEOUT_MS = 30_000;
/** Timeout for individual boot smoke lines ([Save] autoload ready, etc.). */
const SMOKE_LINE_TIMEOUT_MS = 15_000;

/**
 * The exact warning shape from Sponsor's soak log:
 *   USER WARNING: ItemInstance.from_save_dict: unknown item id 'leather_vest'
 *
 * Godot's HTML5 export wraps every `push_warning(...)` call with this
 * "USER WARNING:" prefix when routing through the JS console bridge — so
 * matching against the prefix alone catches the entire class. The body
 * regex below is permissive: any unknown-id message from any save-load
 * surface (ItemInstance, AffixDef-resolve, etc.) trips it.
 */
const UNEXPECTED_USER_WARNING_RE = /^USER WARNING:/;

/**
 * Godot push_error fires both a `console.error` AND prefixes the message
 * with `USER ERROR:` in the text body. Match either signal — a real
 * Godot error always carries the prefix, but Chromium-internal errors
 * (favicon 404, requestAnimationFrame timing) don't. The
 * `console-capture.ts::findFirstError` helper filters Chromium-internal
 * noise but for the strictest assertion we match the text prefix directly.
 */
const UNEXPECTED_USER_ERROR_RE = /^USER ERROR:/;

test.describe("save-load no-warning smoke — Sponsor 86c9uerqx", () => {
  // ===================================================================
  // VARIANT 1 — SMOKE: default cold boot, no save loaded.
  // ===================================================================
  //
  // This is THE variant that catches the active `leather_vest` bug
  // (86c9uen3z) on flip. Boot the artifact in an empty IndexedDB
  // context — Playwright's `serviceWorkers: "block"` + isolated user-
  // data-dir (per `cache-mitigation.ts`) already give us this isolation;
  // no save data persists from any prior test run.
  //
  // With no save data, `Save.load_game` returns the default empty
  // payload; `Inventory.restore_from_save` runs against an empty
  // inventory; no `ItemInstance.from_save_dict` calls fire; therefore no
  // unknown-id warnings should fire. CURRENTLY: Sponsor's reproduction
  // shows the warning even on what should be a clean boot — investigate
  // is on Devon (86c9uen3z). When that bug is fixed, this test flips
  // to `test()` and provides ongoing regression coverage.
  //
  // **Why `test.fail()` until the fix lands:** the soak log demonstrates
  // the warning fires reproducibly on every release-build run today.
  // Shipping this test as `test()` would red-block CI immediately;
  // `test.fail()` keeps CI green while documenting the expected failure
  // pattern. Flip to `test()` in the SAME PR as Devon's fix so we never
  // have a regression window.
  test.fail(
    "Variant 1 — Smoke: default cold boot emits no USER WARNING or USER ERROR (Sponsor 86c9uen3z)",
    async ({ page, context }) => {
      test.setTimeout(120_000);
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      const baseURL =
        process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      await page.goto(baseURL, { waitUntil: "domcontentloaded" });

      // ---- Wait for boot sentinels ----
      //
      // We block on `[Main] M1 play-loop ready` which is emitted at the end
      // of `Main._ready()` AFTER the full autoload chain (Save, BuildInfo,
      // DebugFlags, Levels, PlayerStats, StratumProgression, Inventory,
      // TutorialEventBus, MobRegistry) wired and Room 01 loaded. That
      // window is exactly where `ItemInstance.from_save_dict` runs as part
      // of `Inventory.restore_from_save`, and is exactly where the
      // `leather_vest` warning fires in Sponsor's soak log.
      await capture.waitForLine(
        /\[Save\] autoload ready \(schema v\d+\)/,
        SMOKE_LINE_TIMEOUT_MS
      );
      await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);

      // Drain one more frame so any deferred-warning push_warnings from
      // the same physics tick land in the capture buffer before we sweep.
      await page.waitForTimeout(300);

      // ---- Sweep the capture buffer for USER WARNING: / USER ERROR: ----
      //
      // We check BOTH the warn-type lines (Godot push_warning → console.warn
      // with "USER WARNING:" prefix) AND the text-prefix match across the
      // full buffer. The text-prefix sweep is stricter because some
      // Chromium contexts route certain Godot warnings through console.log
      // instead of console.warn depending on the export config.
      const allLines = capture.getLines();
      const userWarnings = allLines.filter((l) =>
        UNEXPECTED_USER_WARNING_RE.test(l.text)
      );
      const userErrors = allLines.filter((l) =>
        UNEXPECTED_USER_ERROR_RE.test(l.text)
      );

      if (userWarnings.length > 0 || userErrors.length > 0) {
        console.log(
          `[save-load-no-warn] Variant 1 FAILURE — ` +
            `${userWarnings.length} USER WARNING, ${userErrors.length} USER ERROR. ` +
            `Sponsor-reported leather_vest signature OR fresh regression.`
        );
        if (userWarnings.length > 0) {
          console.log("[save-load-no-warn] USER WARNINGs:");
          for (const w of userWarnings) {
            console.log(`  ${w.text}`);
          }
        }
        if (userErrors.length > 0) {
          console.log("[save-load-no-warn] USER ERRORs:");
          for (const e of userErrors) {
            console.log(`  ${e.text}`);
          }
        }
      }

      expect(
        userWarnings.length,
        `Default cold boot must not emit any USER WARNING: lines. ` +
          `Sponsor's M2 RC soak observed ` +
          `"USER WARNING: ItemInstance.from_save_dict: unknown item id 'leather_vest'" ` +
          `(ticket 86c9uen3z). Found ${userWarnings.length} USER WARNING(s) — ` +
          `first: "${userWarnings[0]?.text ?? "(none)"}".`
      ).toBe(0);

      expect(
        userErrors.length,
        `Default cold boot must not emit any USER ERROR: lines. ` +
          `Found ${userErrors.length} — first: "${userErrors[0]?.text ?? "(none)"}".`
      ).toBe(0);

      capture.detach();
    }
  );

  // ===================================================================
  // VARIANT 2 — MIGRATION: v3 save → v4 migration fires cleanly.
  // ===================================================================
  //
  // Seed a v3 envelope into IndexedDB via Playwright's `addInitScript`
  // before navigation. Assert (a) `[Save] autoload ready (schema v4)`
  // fires (NOT v3 — proves migration ran) AND (b) zero warnings during
  // the migration.
  //
  // **Why `test.fail()` indefinitely:** the `seedSaveInIndexedDB(envelope)`
  // helper isn't extracted yet. Godot's HTML5 export uses IDBFS (an
  // emscripten IndexedDB shim) for `user://` storage; seeding a save
  // means writing to a specific IDB object store with the file path
  // encoded the way emscripten expects. The seeding primitive is a
  // follow-up extraction on this ticket.
  //
  // **Why also useful as scaffolding even unflipped:** the full assertion
  // logic below is the post-extraction body the helper completes. When the
  // helper lands, replace the `throw new Error` with `await seedSaveInIndexedDB
  // (page, v3SaveFixture);` and the rest of the body runs the migration check.
  test.fail(
    "Variant 2 — Migration: v3 save → v4 migration fires cleanly with no warnings",
    async ({ page, context }) => {
      test.setTimeout(120_000);
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      // TODO (ticket 86c9uerqx follow-up): seed a v3 save envelope into
      // IndexedDB BEFORE navigating, so `Save.load_game` reads it and
      // exercises the v3→v4 migration path. The helper signature should be:
      //
      //   await seedSaveInIndexedDB(page, {
      //     schema_version: 3,
      //     saved_at: "2026-05-01T00:00:00Z",
      //     data: { inventory: [{ id: "iron_sword", tier: 1 }], ... }
      //   });
      //
      // Where the helper handles the IDBFS encoding (emscripten stores
      // `user://save_v3.json` under a path like `/embergrave/save_v3.json`
      // in the `EMBERGRAVE_FS` object store, file_data field as Uint8Array).
      throw new Error(
        "[save-load-no-warn] Variant 2: seedSaveInIndexedDB helper not yet " +
          "extracted (ticket 86c9uerqx follow-up). Once extracted, assertion " +
          "logic below runs the migration check."
      );

      // ---- Post-extraction body (kept here for diff-readability on flip) ----
      //
      // const baseURL =
      //   process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      // await page.goto(baseURL, { waitUntil: "domcontentloaded" });
      //
      // // Block on the [Save] autoload-ready line — this is where the schema
      // // version is announced AFTER the migration runs.
      // const saveReadyLine = await capture.waitForLine(
      //   /\[Save\] autoload ready \(schema v\d+\)/,
      //   SMOKE_LINE_TIMEOUT_MS
      // );
      //
      // // Assert the post-migration schema is v4 (NOT v3 — that would mean
      // // the migration silently no-op'd, exactly the R1 risk this spec
      // // guards against).
      // expect(
      //   saveReadyLine,
      //   "v3 save must migrate to v4 at autoload. If this line shows v3, " +
      //     "the migration silently no-op'd — R1 (Save migration) regression."
      // ).toMatch(/\[Save\] autoload ready \(schema v4\)/);
      //
      // await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
      // await page.waitForTimeout(300);
      //
      // const userWarnings = capture
      //   .getLines()
      //   .filter((l) => UNEXPECTED_USER_WARNING_RE.test(l.text));
      // const userErrors = capture
      //   .getLines()
      //   .filter((l) => UNEXPECTED_USER_ERROR_RE.test(l.text));
      // expect(
      //   userWarnings.length,
      //   "v3→v4 migration must emit no warnings. Found " +
      //     `${userWarnings.length}; first: "${userWarnings[0]?.text}".`
      // ).toBe(0);
      // expect(userErrors.length).toBe(0);
      //
      // capture.detach();
    }
  );

  // ===================================================================
  // VARIANT 3 — UNKNOWN-ID GRACEFUL: synthesized save with deliberately-
  // unknown id; warning fires but the rest of the load succeeds.
  // ===================================================================
  //
  // This is the inverted assertion: we EXPECT a warning to fire (because
  // we deliberately seeded an unknown id), and we assert that:
  //
  //   1. The warning shape matches `ItemInstance.from_save_dict: unknown
  //      item id 'definitely_not_a_real_item_id_zzzz'` (proves the
  //      graceful-handling path ran).
  //   2. `[Main] M1 play-loop ready` STILL fires (proves the load didn't
  //      crash mid-restore).
  //   3. OTHER known items in the same save were loaded correctly (proves
  //      the unknown-id handling drops the entry, doesn't drop the whole
  //      save — verified via a follow-up `[Inventory] add: item=iron_sword`
  //      trace assertion).
  //
  // This variant is FORWARD-COMPAT coverage: in M3 / M4, a player who
  // installs a newer save (created on a newer build with new item ids)
  // and then rolls back to an older build should get graceful drops with
  // warnings, not a crash. The spec pins that.
  //
  // **Why `test.fail()` indefinitely:** same as Variant 2 — needs the
  // `seedSaveInIndexedDB` helper. When that lands, this variant is the
  // primary defensive test for the unknown-id graceful path.
  test.fail(
    "Variant 3 — Unknown-id graceful: bad-id save loads with warning + no crash",
    async ({ page, context }) => {
      test.setTimeout(120_000);
      await context.route("**/*", (route) => route.continue());

      const capture = new ConsoleCapture(page);
      capture.attach();

      // TODO (ticket 86c9uerqx follow-up): seed a save with a deliberately-
      // unknown item id alongside a known one. Use:
      //
      //   await seedSaveInIndexedDB(page, {
      //     schema_version: 4,
      //     saved_at: "2026-05-15T00:00:00Z",
      //     data: {
      //       inventory: [
      //         { id: "iron_sword", tier: 1 },
      //         { id: "definitely_not_a_real_item_id_zzzz", tier: 1 },
      //       ],
      //       ...
      //     }
      //   });
      throw new Error(
        "[save-load-no-warn] Variant 3: seedSaveInIndexedDB helper not yet " +
          "extracted (ticket 86c9uerqx follow-up). Once extracted, this variant " +
          "asserts the unknown-id graceful drop + boot-completion contract."
      );

      // ---- Post-extraction body (kept here for diff-readability on flip) ----
      //
      // const baseURL =
      //   process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
      // await page.goto(baseURL, { waitUntil: "domcontentloaded" });
      //
      // // Boot must complete — the unknown id MUST be a graceful drop, not a crash.
      // await capture.waitForLine(/\[Main\] M1 play-loop ready/, BOOT_TIMEOUT_MS);
      // await page.waitForTimeout(300);
      //
      // // ---- Assert the EXPECTED warning shape fired (positive assertion) ----
      // const expectedWarning = capture
      //   .getLines()
      //   .find((l) =>
      //     /USER WARNING: ItemInstance\.from_save_dict: unknown item id 'definitely_not_a_real_item_id_zzzz'/.test(
      //       l.text
      //     )
      //   );
      // expect(
      //   expectedWarning,
      //   "Variant 3 seeds an unknown id; the graceful-drop path MUST emit " +
      //     "the documented USER WARNING. If absent, either the seeding " +
      //     "failed OR the graceful path silently swallowed the bad entry " +
      //     "(forward-compat regression — Sponsor will see crashes on schema " +
      //     "rollback)."
      // ).toBeDefined();
      //
      // // ---- Assert KNOWN items still loaded (negative-on-unintended-drop) ----
      // // The Inventory.restore_from_save loop iterates entries — the unknown
      // // id is dropped, but iron_sword should still land.
      // const ironSwordRestored = capture
      //   .getLines()
      //   .find((l) => /\[Inventory\].*iron_sword/.test(l.text));
      // expect(
      //   ironSwordRestored,
      //   "Variant 3: the known iron_sword entry must survive the restore " +
      //     "loop even with an unknown sibling entry. If absent, the unknown-" +
      //     "id handler dropped MORE than just the bad entry — bug."
      // ).toBeDefined();
      //
      // // ---- Assert no USER ERROR (crash signature) ----
      // const userErrors = capture
      //   .getLines()
      //   .filter((l) => UNEXPECTED_USER_ERROR_RE.test(l.text));
      // expect(
      //   userErrors.length,
      //   "Variant 3: unknown id must drop gracefully — no USER ERROR. " +
      //     `Found ${userErrors.length}; first: "${userErrors[0]?.text}".`
      // ).toBe(0);
      //
      // capture.detach();
    }
  );
});
