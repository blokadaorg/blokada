import test from "node:test";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  filterLogText,
  getCrashReportPrefix,
  getDeviceLogArtifactBaseName,
  getShareLogPrefix,
  pullRecentCrashReport,
  pullRecentDeviceLog,
  selectNewestCrashReport,
  selectNewestLogFile
} from "../lib/log.mjs";

test("getShareLogPrefix maps supported bundle ids", () => {
  assert.equal(getShareLogPrefix("net.blocka.app"), "blokada-i6x");
  assert.equal(getShareLogPrefix("net.blocka.app.family"), "blokada-iFx");
  assert.throws(() => getShareLogPrefix("com.example.app"));
});

test("getDeviceLogArtifactBaseName is stable per bundle and window", () => {
  assert.equal(getDeviceLogArtifactBaseName("net.blocka.app", "1h"), "blokada-i6x-1h");
  assert.equal(
    getDeviceLogArtifactBaseName("net.blocka.app.family", "today"),
    "blokada-iFx-today"
  );
});

test("getCrashReportPrefix only supports known in-project bundle ids", () => {
  assert.equal(getCrashReportPrefix("net.blocka.app"), "Dev-");
  assert.equal(getCrashReportPrefix("net.blocka.app.family"), "FamilyDev-");
  assert.throws(
    () => getCrashReportPrefix("com.example.app"),
    /Only Blokada 6 and Blokada Family are supported/
  );
});

test("selectNewestLogFile chooses the newest matching share log", () => {
  const selected = selectNewestLogFile(
    [
      {
        name: "blokada-i6xR.log",
        relativePath: "blokada-i6xR.log",
        metadata: { lastModDate: "2026-03-13T12:00:00.000Z" },
        resources: { isDirectory: false }
      },
      {
        name: "blokada-i6xD.log",
        relativePath: "blokada-i6xD.log",
        metadata: { lastModDate: "2026-03-13T13:00:00.000Z" },
        resources: { isDirectory: false }
      },
      {
        name: "blokada.log",
        relativePath: "blokada.log",
        metadata: { lastModDate: "2026-03-13T14:00:00.000Z" },
        resources: { isDirectory: false }
      }
    ],
    "net.blocka.app"
  );

  assert.equal(selected.relativePath, "blokada-i6xD.log");
});

test("selectNewestCrashReport chooses the newest matching crash artifact", () => {
  const selected = selectNewestCrashReport(
    [
      {
        name: "Dev-2026-03-16-120000.ips",
        metadata: { lastModDate: "2026-03-16T12:00:00.000Z" },
        resources: { isDirectory: false }
      },
      {
        name: "Dev-2026-03-16-130000.ips",
        metadata: { lastModDate: "2026-03-16T13:00:00.000Z" },
        resources: { isDirectory: false }
      },
      {
        name: "OtherApp-2026-03-16-140000.ips",
        metadata: { lastModDate: "2026-03-16T14:00:00.000Z" },
        resources: { isDirectory: false }
      }
    ],
    "net.blocka.app"
  );

  assert.equal(selected.name, "Dev-2026-03-16-130000.ips");
});

test("filterLogText keeps full sections for the recent hour", () => {
  const logText = [
    "   INFO ┌────────",
    "   INFO │ 2026-03-13 11:30:00 (+0:00:00) CET",
    "   INFO │ too old",
    "   INFO └────────",
    "   INFO ┌────────",
    "   INFO │ 2026-03-13 12:45:00 (+0:00:00) CET",
    "   INFO │ keep me",
    "   INFO └────────",
    "   INFO trailing without timestamp"
  ].join("\n");

  const filtered = filterLogText(logText, {
    now: new Date(2026, 2, 13, 13, 0, 0),
    window: "1h"
  });

  assert.equal(filtered.lineCount, 5);
  assert.match(filtered.text, /keep me/);
  assert.match(filtered.text, /trailing without timestamp/);
  assert.doesNotMatch(filtered.text, /too old/);
});

test("filterLogText keeps only today's sections for window=today", () => {
  const logText = [
    "   INFO ┌────────",
    "   INFO │ 2026-03-12 23:59:00 (+0:00:00) CET",
    "   INFO │ old day",
    "   INFO └────────",
    "   INFO ┌────────",
    "   INFO │ 2026-03-13 00:01:00 (+0:00:00) CET",
    "   INFO │ new day",
    "   INFO └────────"
  ].join("\n");

  const filtered = filterLogText(logText, {
    now: new Date(2026, 2, 13, 8, 0, 0),
    window: "today"
  });

  assert.match(filtered.text, /new day/);
  assert.doesNotMatch(filtered.text, /old day/);
});

test("filterLogText truncates after time filtering", () => {
  const logText = [
    "   INFO ┌────────",
    "   INFO │ 2026-03-13 12:30:00 (+0:00:00) CET",
    "   INFO │ line 1",
    "   INFO │ line 2",
    "   INFO │ line 3",
    "   INFO └────────"
  ].join("\n");

  const filtered = filterLogText(logText, {
    lines: 2,
    now: new Date(2026, 2, 13, 13, 0, 0),
    window: "1h"
  });

  assert.equal(filtered.lineCount, 6);
  assert.equal(filtered.returnedLineCount, 2);
  assert.equal(filtered.text, ["   INFO │ line 3", "   INFO └────────"].join("\n"));
});

test("pullRecentDeviceLog saves full and filtered artifacts", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "device-log-"));
  const copiedText = [
    "   INFO ┌────────",
    "   INFO │ 2026-03-13 12:45:00 (+0:00:00) CET",
    "   INFO │ copied log",
    "   INFO └────────"
  ].join("\n");

  const calls = [];
  const result = await pullRecentDeviceLog({
    bundleId: "net.blocka.app",
    device: { name: "Example iPhone", udid: "abc" },
    execFileSyncImpl(command, args) {
      calls.push([command, args]);

      if (args[1] === "device" && args[2] === "info") {
        const jsonPath = args[args.length - 1];
        writeFileSync(
          jsonPath,
          JSON.stringify({
            result: {
              files: [
                {
                  name: "blokada-i6xR.log",
                  relativePath: "blokada-i6xR.log",
                  metadata: { lastModDate: "2026-03-13T13:00:00.000Z" },
                  resources: { isDirectory: false }
                }
              ]
            }
          }),
          { encoding: "utf8" }
        );
        return "";
      }

      if (args[1] === "device" && args[2] === "copy") {
        const destination = args[args.indexOf("--destination") + 1];
        writeFileSync(destination, copiedText, { encoding: "utf8" });
        return "";
      }

      throw new Error(`Unexpected devicectl call: ${args.join(" ")}`);
    },
    now: new Date(2026, 2, 13, 13, 0, 0),
    outputDir,
    save: true,
    window: "1h"
  });

  assert.equal(result.sourceFile, "blokada-i6xR.log");
  assert.match(result.text, /copied log/);
  assert.equal(calls.length, 2);
  assert.match(result.fullArtifactPath, /blokada-i6x-1h\.full\.log$/);
  assert.match(result.artifactPath, /blokada-i6x-1h\.log$/);
  assert.equal(await readFile(result.fullArtifactPath, "utf8"), copiedText);
  assert.equal(await readFile(result.artifactPath, "utf8"), result.text);
  assert.deepEqual(
    calls[1][1],
    [
      "devicectl",
      "device",
      "copy",
      "from",
      "--device",
      "abc",
      "--domain-type",
      "appGroupDataContainer",
      "--domain-identifier",
      "group.net.blocka.app",
      "--source",
      "blokada-i6xR.log",
      "--destination",
      result.fullArtifactPath
    ]
  );
});

test("pullRecentDeviceLog errors when no matching share log exists", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "device-log-empty-"));
  await assert.rejects(
    () =>
      pullRecentDeviceLog({
        bundleId: "net.blocka.app",
        device: { name: "Example iPhone", udid: "abc" },
        execFileSyncImpl(command, args) {
          if (!(args[1] === "device" && args[2] === "info")) {
            throw new Error("unexpected call");
          }

          const jsonPath = args[args.length - 1];
          writeFileSync(
            jsonPath,
            JSON.stringify({
              result: {
                files: [
                  {
                    name: "blokada.log",
                    relativePath: "blokada.log",
                    metadata: { lastModDate: "2026-03-13T13:00:00.000Z" },
                    resources: { isDirectory: false }
                  }
                ]
              }
            }),
            { encoding: "utf8" }
          );
          return "";
        },
        outputDir
      }),
    /No share log file matching/
  );
});

test("pullRecentDeviceLog surfaces copy failures clearly", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "device-log-fail-"));
  await assert.rejects(
    () =>
      pullRecentDeviceLog({
        bundleId: "net.blocka.app",
        device: { name: "Example iPhone", udid: "abc" },
        execFileSyncImpl(command, args) {
          if (args[1] === "device" && args[2] === "info") {
            const jsonPath = args[args.length - 1];
            writeFileSync(
              jsonPath,
              JSON.stringify({
                result: {
                  files: [
                    {
                      name: "blokada-i6xR.log",
                      relativePath: "blokada-i6xR.log",
                      metadata: { lastModDate: "2026-03-13T13:00:00.000Z" },
                      resources: { isDirectory: false }
                    }
                  ]
                }
              }),
              { encoding: "utf8" }
            );
            return "";
          }

          const error = new Error("copy failed");
          error.stderr = "permission denied";
          throw error;
        },
        outputDir
      }),
    /permission denied/
  );
});

test("pullRecentCrashReport copies the newest crash artifact from systemCrashLogs", async () => {
  const outputDir = await mkdtemp(join(tmpdir(), "device-crash-"));
  const copiedText = '{"crash":"report"}';
  const calls = [];

  const result = await pullRecentCrashReport({
    bundleId: "net.blocka.app",
    device: { name: "Example iPhone", udid: "abc" },
    execFileSyncImpl(command, args) {
      calls.push([command, args]);

      if (args[1] === "device" && args[2] === "info") {
        const jsonPath = args[args.length - 1];
        writeFileSync(
          jsonPath,
          JSON.stringify({
            result: {
              files: [
                {
                  name: "Dev-2026-03-16-125626.ips",
                  metadata: { lastModDate: "2026-03-16T12:56:26.000Z" },
                  resources: { isDirectory: false }
                }
              ]
            }
          }),
          { encoding: "utf8" }
        );
        return "";
      }

      if (args[1] === "device" && args[2] === "copy") {
        const destination = args[args.indexOf("--destination") + 1];
        writeFileSync(destination, copiedText, { encoding: "utf8" });
        return "";
      }

      throw new Error(`Unexpected devicectl call: ${args.join(" ")}`);
    },
    outputDir,
    save: true
  });

  assert.equal(result.sourceFile, "Dev-2026-03-16-125626.ips");
  assert.match(result.artifactPath, /Dev-2026-03-16-125626\.ips$/);
  assert.equal(await readFile(result.artifactPath, "utf8"), copiedText);
  assert.deepEqual(
    calls[1][1],
    [
      "devicectl",
      "device",
      "copy",
      "from",
      "--device",
      "abc",
      "--domain-type",
      "systemCrashLogs",
      "--source",
      "Dev-2026-03-16-125626.ips",
      "--destination",
      result.artifactPath
    ]
  );
});
