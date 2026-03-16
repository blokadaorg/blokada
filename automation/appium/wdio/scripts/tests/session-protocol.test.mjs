import test from "node:test";
import assert from "node:assert/strict";

import {
  createAck,
  createDone,
  createError,
  createResult,
  parseJsonlRequest
} from "../lib/session-protocol.mjs";

test("parseJsonlRequest validates structured input", () => {
  assert.deepEqual(
    parseJsonlRequest('{"id":"1","command":"session.status","args":{}}'),
    {
      id: "1",
      command: "session.status",
      args: {}
    }
  );
});

test("parseJsonlRequest rejects positional args", () => {
  assert.throws(
    () => parseJsonlRequest('{"id":"1","command":"ui.tap","args":["~foo"]}'),
    /must be an object/
  );
});

test("protocol envelopes include command metadata", () => {
  const request = { id: "1", command: "ui.inspect" };
  assert.deepEqual(createAck(request), {
    id: "1",
    type: "ack",
    ok: true,
    command: "ui.inspect"
  });
  assert.deepEqual(createResult(request, { result: { labels: [] } }), {
    id: "1",
    type: "result",
    ok: true,
    command: "ui.inspect",
    result: { labels: [] }
  });
  assert.deepEqual(createDone(request), {
    id: "1",
    type: "done",
    ok: true,
    command: "ui.inspect"
  });
});

test("createError serializes failures", () => {
  assert.deepEqual(createError({ id: "2", command: "ui.tap" }, new Error("boom")), {
    id: "2",
    type: "error",
    ok: false,
    command: "ui.tap",
    error: "boom"
  });
});
