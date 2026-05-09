/**
 * artifact-server.ts — Playwright globalSetup / globalTeardown
 *
 * Reads RELEASE_BUILD_ARTIFACT_PATH (path to the unzipped HTML5 directory,
 * post-PR-#152 single-unzip format). Spawns a local HTTP server on an
 * ephemeral port and writes the base URL into process.env.PLAYWRIGHT_BASE_URL
 * so playwright.config.ts and all spec files pick it up.
 *
 * Post-PR-#152 artifact format:
 *   The CI download-artifact step downloads the artifact (named
 *   "embergrave-html5-<sha>") which contains a single zip file
 *   "embergrave-html5-<sha>-<label>.zip". The CI workflow unzips that zip
 *   once to get the HTML5 directory (index.html + .js + .wasm + .pck +
 *   .audio.worklet.js + icons). RELEASE_BUILD_ARTIFACT_PATH should point
 *   to that unzipped directory.
 *
 * Local dev:
 *   1. Download the artifact zip from the GitHub Actions run page.
 *   2. Unzip once: unzip embergrave-html5-356086a-manual.zip -d ./html5-build
 *   3. RELEASE_BUILD_ARTIFACT_PATH=./html5-build npm test
 */

import { spawn, ChildProcess } from "child_process";
import * as path from "path";
import * as fs from "fs";
import * as os from "os";

/** Persisted across globalSetup → globalTeardown via environment variable. */
const SERVER_PID_ENV = "PLAYWRIGHT_SERVER_PID";
const SERVER_PORT_ENV = "PLAYWRIGHT_SERVER_PORT";

let serverProcess: ChildProcess | null = null;

/**
 * Spawns a Node.js HTTP server on an ephemeral port in the given directory.
 * Uses Node's built-in http module — no extra dependencies, cross-platform,
 * and reliably captures the port via stdout pipe.
 *
 * Node is already a hard dependency (Playwright runs on Node), so this avoids
 * any Python version or platform issues with `python -m http.server` stderr
 * capture behavior.
 *
 * The server serves static files with appropriate MIME types for Godot HTML5:
 *   - .wasm → application/wasm (required for SharedArrayBuffer + WebAssembly)
 *   - .js   → application/javascript
 *   - .pck  → application/octet-stream
 *
 * Includes CORS headers required for Godot's SharedArrayBuffer:
 *   - Cross-Origin-Opener-Policy: same-origin
 *   - Cross-Origin-Embedder-Policy: require-corp
 */
async function startHttpServer(serveDir: string): Promise<number> {
  // Write the server script to a temp file to avoid Node.js -e parsing issues
  // (Node 25+ changed TypeScript/ESM handling of -e flag).
  const serverScriptPath = path.join(
    os.tmpdir(),
    `embergrave-server-${Date.now()}.cjs`
  );
  const serverScript = [
    "const http=require('http');",
    "const fs=require('fs');",
    "const pt=require('path');",
    "const dir=process.argv[2];",
    "const M={'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.ico':'image/x-icon'};",
    "const srv=http.createServer((req,res)=>{",
    "  let u=req.url.split('?')[0];if(u==='/')u='/index.html';",
    "  const f=pt.join(dir,u);",
    "  fs.readFile(f,(err,data)=>{",
    "    if(err){res.writeHead(404);res.end('NF');return;}",
    "    const ext=pt.extname(f);",
    "    res.writeHead(200,{'Content-Type':M[ext]||'application/octet-stream','Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});",
    "    res.end(data);",
    "  });",
    "});",
    "srv.listen(0,'127.0.0.1',()=>{",
    "  const p=srv.address().port;",
    "  process.stdout.write('PORT='+p+'\\n');",
    "});",
  ].join("\n");

  fs.writeFileSync(serverScriptPath, serverScript);

  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, [serverScriptPath, serveDir], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    serverProcess = proc;

    let portFound = false;
    let stdout = "";
    let stderr = "";

    proc.stdout!.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
      const match = stdout.match(/PORT=(\d+)/);
      if (match && !portFound) {
        portFound = true;
        const port = parseInt(match[1], 10);
        resolve(port);
      }
    });

    proc.stderr!.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    proc.on("error", (err) => {
      reject(new Error(`Failed to start HTTP server: ${err.message}`));
    });

    proc.on("exit", (code) => {
      if (!portFound) {
        reject(
          new Error(
            `HTTP server exited (code ${code}) before port was reported.\n` +
              `stdout: ${stdout}\nstderr: ${stderr}`
          )
        );
      }
    });

    // Timeout if server never reports the port
    setTimeout(() => {
      if (!portFound) {
        proc.kill();
        reject(
          new Error(
            `Timeout waiting for HTTP server to report port.\n` +
              `stdout so far: ${stdout}\nstderr so far: ${stderr}`
          )
        );
      }
    }, 15_000);
  });
}

/**
 * Playwright globalSetup — called once before all tests.
 * Starts the HTTP server and writes PLAYWRIGHT_BASE_URL.
 */
async function setup(): Promise<void> {
  const artifactPath = process.env.RELEASE_BUILD_ARTIFACT_PATH;

  if (!artifactPath) {
    throw new Error(
      [
        "RELEASE_BUILD_ARTIFACT_PATH is not set.",
        "Set it to the path of the unzipped HTML5 directory:",
        "  RELEASE_BUILD_ARTIFACT_PATH=/path/to/unzipped/html5 npm test",
        "",
        "For CI, this is set automatically by the playwright-e2e workflow",
        "after downloading and unzipping the release artifact.",
        "",
        "For local dev: unzip the artifact zip once, then set the path:",
        "  unzip embergrave-html5-356086a-manual.zip -d ./html5-build",
        "  RELEASE_BUILD_ARTIFACT_PATH=./html5-build npm test",
      ].join("\n")
    );
  }

  const resolvedPath = path.resolve(artifactPath);

  if (!fs.existsSync(resolvedPath)) {
    throw new Error(
      `RELEASE_BUILD_ARTIFACT_PATH does not exist: ${resolvedPath}`
    );
  }

  // Verify it looks like a Godot HTML5 export (smoke-check)
  const indexHtml = path.join(resolvedPath, "index.html");
  if (!fs.existsSync(indexHtml)) {
    throw new Error(
      [
        `No index.html found in RELEASE_BUILD_ARTIFACT_PATH: ${resolvedPath}`,
        "Make sure you unzipped the artifact zip once to get the HTML5 directory.",
        "Expected files: index.html, index.js, index.wasm, index.pck",
      ].join("\n")
    );
  }

  console.log(`[artifact-server] Serving HTML5 build from: ${resolvedPath}`);

  const port = await startHttpServer(resolvedPath);
  // Use 127.0.0.1 explicitly (not localhost) to avoid IPv6 resolution issues
  // on Windows where "localhost" may resolve to ::1 (IPv6) while the server
  // binds to 127.0.0.1 (IPv4).
  const baseURL = `http://127.0.0.1:${port}`;

  process.env.PLAYWRIGHT_BASE_URL = baseURL;
  process.env[SERVER_PORT_ENV] = String(port);
  if (serverProcess?.pid) {
    process.env[SERVER_PID_ENV] = String(serverProcess.pid);
  }

  // Register cleanup on process exit so the server is always killed,
  // even if Playwright crashes or the test run is interrupted.
  const cleanup = () => {
    if (serverProcess) {
      serverProcess.kill("SIGTERM");
      serverProcess = null;
    }
  };
  process.on("exit", cleanup);
  process.on("SIGINT", cleanup);
  process.on("SIGTERM", cleanup);

  console.log(`[artifact-server] HTTP server running at ${baseURL}`);
  console.log(
    `[artifact-server] Cache-mitigation: tests use isolated Chrome profiles + --disable-cache`
  );
}

/**
 * Playwright globalTeardown — called once after all tests complete.
 * Kills the HTTP server process.
 */
async function teardown(): Promise<void> {
  if (serverProcess) {
    console.log("[artifact-server] Shutting down HTTP server...");
    serverProcess.kill("SIGTERM");
    serverProcess = null;
  } else {
    // In teardown we may be in a different process; use the PID from env.
    const pid = process.env[SERVER_PID_ENV];
    if (pid) {
      try {
        process.kill(parseInt(pid, 10), "SIGTERM");
        console.log(`[artifact-server] Killed HTTP server (pid ${pid})`);
      } catch {
        // Already dead — that's fine.
      }
    }
  }
}

// Playwright expects the globalSetup / globalTeardown file to export a default
// function. The same file is used for both by exporting setup as default and
// calling teardown logic inside it via the returned function.
export default setup;
export { teardown };
