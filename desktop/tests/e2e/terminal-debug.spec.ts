/**
 * terminal-debug.spec.ts — Focused diagnostic for the TerminalSession bridge.
 *
 * Steps:
 *  1. Create an interactive session via POST /api/v1/sessions
 *  2. Navigate to /sessions/<id>
 *  3. Attach console / pageerror / websocket listeners
 *  4. Wait 8 seconds for streams to flow
 *  5. Assert xterm-screen is visible and fallback banner is gone
 */

import { test, expect } from "@playwright/test";
import path from "path";

test("terminal bridge: xterm renders, fallback banner absent", async ({
  page,
}) => {
  // ── 1. Create interactive session ──────────────────────────────────────────
  const resp = await page.request.post(
    "http://localhost:9190/api/v1/sessions",
    {
      data: {
        runtime_type: "claude-local",
        workspace_slug: "default",
        interactive: true,
      },
    },
  );

  const body = await resp.json();
  console.log("SESSION_CREATE_STATUS:", resp.status());
  console.log("SESSION_BODY:", JSON.stringify(body));

  const sessionId: string = body.session_id as string;
  expect(sessionId).toBeTruthy();

  // ── 2. Attach listeners BEFORE navigation ──────────────────────────────────
  const consoleMessages: string[] = [];
  const pageErrors: string[] = [];
  const wsFrames: string[] = [];

  page.on("console", (msg) => {
    const line = `CONSOLE [${msg.type()}]: ${msg.text()}`;
    console.log(line);
    consoleMessages.push(line);
  });

  page.on("pageerror", (err) => {
    const line = `PAGE_ERROR: ${err.message}\n${err.stack ?? ""}`;
    console.log(line);
    pageErrors.push(line);
  });

  page.on("websocket", (ws) => {
    console.log(`WS_OPEN: ${ws.url()}`);
    ws.on("framesent", (f) => {
      const line = `WS_SEND: ${String(f.payload).slice(0, 300)}`;
      console.log(line);
      wsFrames.push(line);
    });
    ws.on("framereceived", (f) => {
      const line = `WS_RECV: ${String(f.payload).slice(0, 300)}`;
      console.log(line);
      wsFrames.push(line);
    });
    ws.on("close", () => {
      const line = `WS_CLOSE: ${ws.url()}`;
      console.log(line);
      wsFrames.push(line);
    });
  });

  // ── 3. Navigate ────────────────────────────────────────────────────────────
  await page.goto(`http://localhost:5281/sessions/${sessionId}`);

  // ── 4. Wait for streams ────────────────────────────────────────────────────
  await page.waitForTimeout(8_000);

  // ── 5. Screenshot ──────────────────────────────────────────────────────────
  const screenshotPath = path.join(import.meta.dirname, "terminal-debug.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  console.log(`SCREENSHOT: ${screenshotPath}`);

  // ── 6. DOM checks ──────────────────────────────────────────────────────────
  const xtermVisible = await page.locator(".xterm-screen").isVisible();
  const fallbackVisible = await page
    .locator("text=Terminal bridge not ready")
    .isVisible();

  console.log(`XTERM_VISIBLE: ${xtermVisible}`);
  console.log(`FALLBACK_VISIBLE: ${fallbackVisible}`);

  // ── 7. Diagnostic summary ──────────────────────────────────────────────────
  const wsJoinSent = wsFrames.some((f) => f.includes("phx_join"));
  const wsJoinOk = wsFrames.some(
    (f) => f.includes("phx_reply") && f.includes('"ok"'),
  );
  const wsOutputReceived = wsFrames.some((f) => f.includes("output"));
  const hasPageErrors = pageErrors.length > 0;

  console.log(`WS_JOIN_SENT: ${wsJoinSent}`);
  console.log(`WS_JOIN_OK: ${wsJoinOk}`);
  console.log(`WS_OUTPUT_RECEIVED: ${wsOutputReceived}`);
  console.log(`PAGE_ERRORS_COUNT: ${pageErrors.length}`);

  if (hasPageErrors) {
    console.log("=== PAGE ERRORS ===");
    pageErrors.forEach((e) => console.log(e));
  }

  // ── 8. Assertions ──────────────────────────────────────────────────────────
  expect(
    fallbackVisible,
    `Fallback banner should NOT be visible. WS join sent=${wsJoinSent}, ok=${wsJoinOk}, errors: ${pageErrors.join(" | ")}`,
  ).toBe(false);

  expect(
    xtermVisible,
    `xterm-screen should be visible. WS join sent=${wsJoinSent}, ok=${wsJoinOk}`,
  ).toBe(true);
});
