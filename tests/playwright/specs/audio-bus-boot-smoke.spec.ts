/**
 * audio-bus-boot-smoke.spec.ts
 *
 * W3-T9 (`86c9uf6hh`) — HTML5 audio-playback gate smoke check.
 *
 * **What it checks:**
 * 1. Build boots without `AudioDecodingError` / `AudioContext.state !== "running"`
 *    or related audio-pipeline warnings during boot.
 * 2. `[AudioDirector] ready — bgm_bus=N ambient_bus=N sfx_bus=N ui_bus=N` boot
 *    trace fires. This is the canonical proof that:
 *      - The `AudioDirector` autoload registered.
 *      - The 5-bus structure (`default_bus_layout.tres`) loaded — Master must
 *        be at index 0, and BGM/Ambient/SFX/UI must be present (their indices
 *        printed). A missing bus would log `-1`.
 *      - The AudioStreamPlayer children built and routed to the right buses.
 * 3. No `[AudioDirector]` warning lines (e.g. `failed to load
 *    res://audio/music/stratum2/mus-stratum2-bgm.ogg`) — which would mean
 *    the OGG resources didn't bundle into the HTML5 .pck.
 *
 * **What this DOES NOT check** (audible verification still requires manual soak):
 *  - Whether sound actually emits from speakers when the descend trigger fires.
 *  - The cue's tonal fidelity / mood match against `audio-direction.md §1`.
 *  - The crossfade audibility / loop seamlessness.
 *
 * Audible verification is the Sponsor-soak probe in the PR's Self-Test Report.
 * This spec is the structural / boot-time complement — it catches "audio
 * pipeline never wired" / "bus layout dropped" / "OGG missing from pck"
 * regressions that the Sponsor would otherwise hit in the next soak.
 *
 * Pattern source: `ac1-boot-and-sha.spec.ts`. Same boot-line capture + error
 * sweep + console-dump-on-failure shape.
 */

import { test, expect } from "@playwright/test";
import { ConsoleCapture } from "../fixtures/console-capture";

const BOOT_TIMEOUT_MS = 30_000;
const SMOKE_LINE_TIMEOUT_MS = 15_000;

test.describe("audio bus boot smoke — AudioDirector + 5-bus layout (W3-T9)", () => {
  test("AudioDirector autoload registers + 5-bus layout loads + no audio warnings", async ({
    page,
    context,
  }) => {
    await context.route("**/*", (route) => route.continue());
    const capture = new ConsoleCapture(page);
    capture.attach();

    const baseURL =
      process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:8000";
    await page.goto(baseURL, { waitUntil: "domcontentloaded" });

    // 1. Wait for the canonical boot-ready sentinel so we know the full
    //    autoload chain (Save → DebugFlags → ... → AudioDirector → Main)
    //    completed.
    await capture.waitForLine(
      /\[Main\] M1 play-loop ready/,
      BOOT_TIMEOUT_MS
    );

    // 2. AudioDirector boot trace: prints bgm/ambient/sfx/ui bus indices.
    //    If `default_bus_layout.tres` is missing or any bus is renamed,
    //    the corresponding index prints `-1`.
    const adReady = await capture.waitForLine(
      /\[AudioDirector\] ready — bgm_bus=(-?\d+) ambient_bus=(-?\d+) sfx_bus=(-?\d+) ui_bus=(-?\d+)/,
      SMOKE_LINE_TIMEOUT_MS
    );
    const match = adReady.match(
      /bgm_bus=(-?\d+) ambient_bus=(-?\d+) sfx_bus=(-?\d+) ui_bus=(-?\d+)/
    );
    expect(match, "AudioDirector ready trace must include all four bus indices").not.toBeNull();
    const bgmIdx = parseInt(match![1]);
    const ambIdx = parseInt(match![2]);
    const sfxIdx = parseInt(match![3]);
    const uiIdx = parseInt(match![4]);
    expect(bgmIdx, "BGM bus must exist in default_bus_layout.tres").toBeGreaterThan(0);
    expect(ambIdx, "Ambient bus must exist").toBeGreaterThan(0);
    expect(sfxIdx, "SFX bus must exist").toBeGreaterThan(0);
    expect(uiIdx, "UI bus must exist").toBeGreaterThan(0);
    // All four non-Master buses must be unique indices.
    const uniqueIndices = new Set([bgmIdx, ambIdx, sfxIdx, uiIdx]);
    expect(uniqueIndices.size, "All four buses must have unique indices").toBe(4);

    // 3. No AudioDirector failure-to-load warnings. The expected resources are
    //    the three S2 cues Uma shipped in PR #210; if any failed to bundle
    //    into the .pck, AudioDirector emits push_warning("[AudioDirector]
    //    failed to load <path>") on the first lazy-load attempt.
    //    We can't trigger the lazy-load from here without driving the full
    //    descend flow (~10 min), so this assertion only fires if the warning
    //    appeared before our test reached this point. The negative-assertion
    //    is still useful — a typoed STREAM_PATH constant would warn at any
    //    eager load and surface here.
    const adWarning = capture.findUnexpectedLine(
      /\[AudioDirector\].*failed to load/
    );
    if (adWarning) {
      console.log("[audio-bus-boot-smoke] AudioDirector warning:\n" + adWarning);
    }
    expect(adWarning).toBeNull();

    // 4. No `AudioDecodingError` / `AudioContext` warnings. Browsers log
    //    these as console.warn when an OGG fails to decode (e.g.
    //    Vorbis container malformed) or the AudioContext can't start.
    const audioErr = capture.findUnexpectedLine(
      /AudioDecodingError|AudioContext.*not.*allowed|AudioContext.*failed/i
    );
    if (audioErr) {
      console.log("[audio-bus-boot-smoke] Audio decoding error:\n" + audioErr);
    }
    expect(audioErr).toBeNull();

    // 5. No general push_error during boot.
    const firstError = capture.findFirstError();
    if (firstError) {
      console.log("[audio-bus-boot-smoke] FULL DUMP:\n" + capture.dump());
    }
    expect(firstError).toBeNull();

    capture.detach();
  });
});
