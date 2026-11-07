#!/usr/bin/env node

// Device review bridge for an agent that cannot keep a process on stdin open
// between tool calls (Claude in .github/workflows/device-review.yml).
//
//   node scripts/review-session.mjs serve six|family   start the explorer, listen
//   node scripts/review-session.mjs send COMMAND [JSON_ARGS]   one command, one JSON reply
//
// `serve` owns one explorer session (scripts/explore.mjs --jsonl) and answers
// one command per socket connection. Every explorer command goes through
// gateReviewCommand: the AI explorer's guardrails (allowlist, no purchase,
// account or external-flow text) plus the few commands a feature review needs
// on top (typing, center taps, system alerts). Bridge commands:
//   flavor {"name":"six"|"family"}  restart the session on the other app (installed already)
//   log {"flavor":"six"|"family","artifact":"log"|"crash"}  recent app log or crash report
//   stop                            end the session and the server

import { execFile } from "node:child_process";
import { existsSync, rmSync } from "node:fs";
import { createConnection, createServer } from "node:net";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import process from "node:process";
import { createInterface } from "node:readline";

import { evaluateExplorerAction } from "./lib/ai-explorer-guardrails.mjs";
import { JsonlExplorerClient } from "./lib/ai-explorer-jsonl-client.mjs";
import { getProjectPaths } from "./lib/paths.mjs";

export const BUNDLES = { six: "net.blocka.app", family: "net.blocka.app.family" };
const MAX_TEXT = 120;
const MAX_LOG_LINES = 200;
const ALERT_ACTIONS = new Set(["accept", "dismiss", "getButtons"]);

// Under the temp dir: a Unix socket path must stay under 104 bytes on macOS,
// which a runner's work directory can exceed.
export function socketPath(env = process.env) {
  return env.REVIEW_SOCKET ?? join(tmpdir(), "blokada-review.sock");
}

// The guardrails check text on the action's reason, so a value the review
// wants to type or tap is passed as the reason of an equivalent ui.tap.
function gateText(selector, text, bundleId) {
  const check = evaluateExplorerAction(
    { command: "ui.tap", args: { selector }, reason: text },
    { sessionBundleId: bundleId }
  );
  return check.allowed ? { selector: check.action.args.selector } : { error: check.reason };
}

export function gateReviewCommand(command, args, bundleId) {
  const a = args && typeof args === "object" && !Array.isArray(args) ? args : {};
  switch (command) {
    case "ui.type": {
      const text = String(a.text ?? "");
      if (!text || text.length > MAX_TEXT) {
        return { error: `ui.type needs args.text of 1 to ${MAX_TEXT} characters.` };
      }
      const gated = gateText(a.selector, text, bundleId);
      return gated.error ? gated : { command, args: { selector: gated.selector, text } };
    }
    case "ui.tapCenter": {
      const gated = gateText(a.selector, "", bundleId);
      return gated.error ? gated : { command, args: { selector: gated.selector } };
    }
    case "ui.alert": {
      const action = String(a.action ?? "getButtons");
      if (!ALERT_ACTIONS.has(action)) {
        return { error: "ui.alert action must be accept, dismiss or getButtons." };
      }
      const label = typeof a.buttonLabel === "string" ? a.buttonLabel.slice(0, 40) : "";
      // Without a label WebDriverAgent picks the button itself, unchecked.
      if (action !== "getButtons" && !label) {
        return { error: "ui.alert accept and dismiss need args.buttonLabel; list them with getButtons." };
      }
      const check = evaluateExplorerAction(
        { command: "ui.back", args: {}, reason: label },
        { sessionBundleId: bundleId }
      );
      if (!check.allowed) {
        return { error: check.reason };
      }
      return { command, args: action === "getButtons" ? { action } : { action, buttonLabel: label } };
    }
    case "ui.screenshot": {
      const check = evaluateExplorerAction({ command, args: a }, { sessionBundleId: bundleId });
      if (!check.allowed) {
        return { error: check.reason };
      }
      // A fixed prefix keeps review screenshots apart from the smoke's, and the
      // name stays a plain slug: it becomes a path on the release-review branch.
      const slug = String(a.name ?? "")
        .replace(/^review-/, "")
        .replace(/[^A-Za-z0-9-]+/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 60);
      return { command, args: { name: `review-${slug || Date.now()}` } };
    }
    case "finish":
      return { error: "Use stop to end the session." };
    default: {
      const check = evaluateExplorerAction({ command, args: a }, { sessionBundleId: bundleId });
      return check.allowed
        ? { command: check.action.command, args: check.action.args }
        : { error: check.reason };
    }
  }
}

function tail(text, lines) {
  const all = String(text ?? "").split("\n");
  return all.slice(Math.max(0, all.length - lines)).join("\n");
}

function readLog(paths, flavor, artifact, env) {
  return new Promise((done) => {
    execFile(
      process.execPath,
      [resolve(paths.repoRoot, "automation", "device", "log.mjs")],
      {
        cwd: paths.repoRoot,
        env: { ...env, APP_BUNDLE_ID: BUNDLES[flavor], ARTIFACT: artifact },
        maxBuffer: 32 * 1024 * 1024,
        timeout: 120000
      },
      (error, stdout, stderr) => {
        if (error) {
          done({ type: "error", error: tail(stderr || error.message, 20) });
        } else {
          done({ type: "result", result: tail(stdout, MAX_LOG_LINES) });
        }
      }
    );
  });
}

async function serve(flavor) {
  if (!BUNDLES[flavor]) {
    throw new Error("serve needs six or family.");
  }
  const paths = getProjectPaths(process.env);
  const path = socketPath(process.env);
  if (existsSync(path)) {
    rmSync(path);
  }

  let current = flavor;
  let client;
  const start = async (name) => {
    current = name;
    client = new JsonlExplorerClient({
      cwd: paths.wdioRoot,
      // REVIEW_EXPLORER_SCRIPT swaps in a fake explorer for a dry run without a device.
      scriptPath: process.env.REVIEW_EXPLORER_SCRIPT ?? "scripts/explore.mjs",
      env: { ...process.env, APP_FLAVOR: name, APP_BUNDLE_ID: BUNDLES[name], APP_INSTALL: "0" }
    });
    client.start();
    await client.command("session.status", {});
  };
  await start(flavor);

  const handle = async (request) => {
    const { command, args } = request ?? {};
    if (command === "stop") {
      await client.shutdown();
      setImmediate(() => server.close(() => process.exit(0)));
      return { type: "done" };
    }
    if (command === "flavor") {
      const name = String(args?.name ?? "");
      if (!BUNDLES[name]) {
        return { type: "error", error: "flavor name must be six or family." };
      }
      await client.shutdown();
      await start(name);
      return { type: "result", result: `session on ${name}` };
    }
    if (command === "log") {
      const name = BUNDLES[args?.flavor] ? args.flavor : current;
      const artifact = args?.artifact === "crash" ? "crash" : "log";
      return readLog(paths, name, artifact, process.env);
    }
    const gated = gateReviewCommand(String(command ?? ""), args, BUNDLES[current]);
    if (gated.error) {
      return { type: "refused", error: gated.error };
    }
    try {
      return { type: "result", result: await client.command(gated.command, gated.args) };
    } catch (error) {
      return { type: "error", error: error instanceof Error ? error.message : String(error) };
    }
  };

  const server = createServer((socket) => {
    const rl = createInterface({ input: socket, crlfDelay: Infinity });
    rl.once("line", async (line) => {
      let reply;
      try {
        reply = await handle(JSON.parse(line));
      } catch (error) {
        reply = { type: "error", error: error instanceof Error ? error.message : String(error) };
      }
      socket.end(`${JSON.stringify(reply)}\n`);
    });
  });
  server.on("error", (error) => {
    process.stderr.write(`review-session: ${error.message}\n`);
    process.exit(1);
  });
  server.listen(path, () => process.stderr.write(`review session on ${current}, socket ${path}\n`));
}

function send(command, rawArgs) {
  let args = {};
  if (rawArgs) {
    args = JSON.parse(rawArgs);
  }
  return new Promise((done, fail) => {
    const socket = createConnection(socketPath(process.env));
    let data = "";
    socket.on("data", (chunk) => {
      data += chunk;
    });
    socket.on("end", () => {
      process.stdout.write(data);
      const reply = JSON.parse(data);
      done(reply.type === "error" || reply.type === "refused" ? 1 : 0);
    });
    socket.on("error", fail);
    socket.write(`${JSON.stringify({ command, args })}\n`);
  });
}

async function main(argv) {
  const [mode, ...rest] = argv;
  if (mode === "serve") {
    await serve(rest[0]);
    return;
  }
  if (mode === "send" && rest[0]) {
    process.exitCode = await send(rest[0], rest[1]);
    return;
  }
  throw new Error("usage: review-session.mjs serve six|family | send COMMAND [JSON_ARGS]");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`review-session: ${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
  });
}
