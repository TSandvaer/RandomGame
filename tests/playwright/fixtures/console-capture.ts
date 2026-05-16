/**
 * console-capture.ts — Playwright console capture fixture
 *
 * Wraps page.on("console", ...) to capture all console messages emitted by
 * the Godot HTML5 build. Provides a typed API for specs to wait for specific
 * log lines (e.g. [combat-trace] or [BuildInfo] lines) and to inspect the
 * full capture buffer.
 *
 * Godot HTML5 exports route GDScript print() / push_error() / push_warning()
 * through the JavaScript console bridge:
 *   print(...)       → console.log
 *   push_error(...)  → console.error
 *   push_warning(...) → console.warn
 *
 * Usage in specs:
 *   import { ConsoleCapture } from '../fixtures/console-capture';
 *   const capture = new ConsoleCapture(page);
 *   capture.attach();  // call before page.goto()
 *   await capture.waitForLine(/\[BuildInfo\] build: [0-9a-f]{7}/, 10_000);
 *   const allLines = capture.getLines();
 *   capture.clearLines();
 */

import type { Page, ConsoleMessage } from "@playwright/test";

export interface CapturedLine {
  type: string; // "log" | "error" | "warn" | "info" | etc.
  text: string;
  timestamp: number; // Date.now() at capture time
}

export class ConsoleCapture {
  private page: Page;
  private lines: CapturedLine[] = [];
  private attached = false;
  private listener: ((msg: ConsoleMessage) => void) | null = null;

  constructor(page: Page) {
    this.page = page;
  }

  /**
   * Attach the console listener to the page. Call this before page.goto()
   * so boot-time lines are captured from the first frame.
   */
  attach(): void {
    if (this.attached) return;

    this.listener = (msg: ConsoleMessage) => {
      this.lines.push({
        type: msg.type(),
        text: msg.text(),
        timestamp: Date.now(),
      });
    };

    this.page.on("console", this.listener);
    this.attached = true;
  }

  /**
   * Detach the console listener. Call in afterEach to avoid listener leaks.
   */
  detach(): void {
    if (!this.attached || !this.listener) return;
    this.page.off("console", this.listener);
    this.attached = false;
    this.listener = null;
  }

  /**
   * Returns a snapshot of all captured lines (all console types).
   */
  getLines(): CapturedLine[] {
    return [...this.lines];
  }

  /**
   * Returns lines matching a specific console type.
   * Use type="error" to check for Godot push_error() calls.
   * Use type="warning" for push_warning() calls.
   *
   * IMPORTANT: Playwright's `ConsoleMessage.type()` returns "warning"
   * (NOT "warn") for `console.warn()` calls. The original "warn"
   * convention assumed in earlier helper code is wrong against
   * Playwright 1.49 — verified empirically 2026-05-16 (ticket
   * 86c9upfex). The full enum returned by `msg.type()` is:
   * `"log" | "debug" | "info" | "error" | "warning" | "dir" |
   * "dirxml" | "table" | "trace" | "clear" | "startGroup" |
   * "startGroupCollapsed" | "endGroup" | "assert" | "profile" |
   * "profileEnd" | "count" | "time" | "timeEnd"`.
   */
  getLinesByType(type: string): CapturedLine[] {
    return this.lines.filter((l) => l.type === type);
  }

  /**
   * Returns all log lines as plain strings (convenience accessor).
   */
  getLogTexts(): string[] {
    return this.lines.map((l) => l.text);
  }

  /**
   * Clears the captured buffer. Useful between test phases when you want
   * to check for lines only after a specific action.
   */
  clearLines(): void {
    this.lines = [];
  }

  /**
   * Waits until a console line matching the pattern appears, or throws after
   * timeoutMs. Returns the matched line text.
   *
   * Polls the internal buffer; does not use page.waitForEvent to avoid
   * race conditions with lines that already arrived before this call.
   */
  async waitForLine(pattern: RegExp, timeoutMs: number): Promise<string> {
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
      const match = this.lines.find((l) => pattern.test(l.text));
      if (match) return match.text;
      // Poll at ~50ms intervals — fast enough to catch rapid boot lines
      await new Promise((resolve) => setTimeout(resolve, 50));
    }

    // On timeout, dump what we have for debugging
    const allText = this.lines.map((l) => `[${l.type}] ${l.text}`).join("\n");
    throw new Error(
      [
        `Timeout (${timeoutMs}ms) waiting for console line matching: ${pattern}`,
        `Captured ${this.lines.length} lines so far:`,
        allText || "(none)",
      ].join("\n")
    );
  }

  /**
   * Asserts that NO console line matching the pattern exists within the
   * current buffer. Returns the offending line text if found (so the test
   * can fail with a meaningful message), or null if clean.
   */
  findUnexpectedLine(pattern: RegExp): string | null {
    const match = this.lines.find((l) => pattern.test(l.text));
    return match ? match.text : null;
  }

  /**
   * Dumps the full capture buffer as a formatted string.
   * Useful for test failure messages and CI artifact uploads.
   */
  dump(): string {
    if (this.lines.length === 0) return "(no console lines captured)";
    return this.lines
      .map(
        (l) =>
          `[${new Date(l.timestamp).toISOString()}] [${l.type.padEnd(5)}] ${l.text}`
      )
      .join("\n");
  }

  /**
   * Asserts there are no console.error lines in the buffer.
   * Skips Chromium-internal warnings (requestAnimationFrame timing, etc.)
   * that are not Godot push_error calls.
   *
   * Returns the first offending error line, or null if clean.
   */
  findFirstError(): string | null {
    const errorLines = this.lines.filter((l) => l.type === "error");
    // Filter out Chromium-internal non-Godot error messages
    const godotErrors = errorLines.filter(
      (l) =>
        !l.text.includes("requestAnimationFrame") &&
        !l.text.includes("favicon.ico") &&
        !l.text.includes("Content-Security-Policy") &&
        !l.text.startsWith("Failed to load resource")
    );
    return godotErrors.length > 0 ? godotErrors[0].text : null;
  }
}
