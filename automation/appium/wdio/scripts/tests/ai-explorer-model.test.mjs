import test from "node:test";
import assert from "node:assert/strict";

import {
  callOpenAiCompatibleChat,
  extractJsonFromModelContent,
  ModelEndpointError,
  requestExplorerDecision
} from "../lib/ai-explorer-model.mjs";

test("extractJsonFromModelContent parses JSON with surrounding reasoning text", () => {
  assert.deepEqual(
    extractJsonFromModelContent('Reasoning...\n{"command":"ui.summary","args":{},"confidence":0.8}\nDone'),
    {
      command: "ui.summary",
      args: {},
      confidence: 0.8
    }
  );
});

test("callOpenAiCompatibleChat posts OpenAI-compatible request", async () => {
  const calls = [];
  const response = await callOpenAiCompatibleChat({
    apiKey: "secret",
    baseUrl: "http://lmstudio.test/v1",
    fetchFn: async (url, init) => {
      calls.push({ url, init });
      return new Response(
        JSON.stringify({
          choices: [
            {
              message: {
                content: "{\"command\":\"finish\",\"args\":{}}",
                reasoning_content: "done"
              }
            }
          ],
          usage: { total_tokens: 7 }
        }),
        { status: 200 }
      );
    },
    maxTokens: 50,
    messages: [{ role: "user", content: "hello" }],
    model: "test-model",
    modelTimeoutMs: 1000,
    temperature: 0
  });

  assert.equal(calls[0].url, "http://lmstudio.test/v1/chat/completions");
  assert.equal(calls[0].init.headers.Authorization, "Bearer secret");
  assert.equal(JSON.parse(calls[0].init.body).model, "test-model");
  assert.equal(response.content, "{\"command\":\"finish\",\"args\":{}}");
});

test("callOpenAiCompatibleChat exposes malformed OpenAI-compatible payload details", async () => {
  await assert.rejects(
    callOpenAiCompatibleChat({
      apiKey: "",
      baseUrl: "http://lmstudio.test/v1",
      fetchFn: async () =>
        new Response(JSON.stringify({ choices: [{ message: { reasoning_content: "thinking" } }] }), {
          status: 200
        }),
      maxTokens: 50,
      messages: [{ role: "user", content: "hello" }],
      model: "test-model",
      modelTimeoutMs: 1000,
      temperature: 0
    }),
    (error) =>
      error instanceof ModelEndpointError &&
      error.payload?.choices?.[0]?.message?.reasoning_content === "thinking"
  );
});

test("requestExplorerDecision returns parsed decision", async () => {
  const result = await requestExplorerDecision({
    config: {
      apiKey: "",
      baseUrl: "http://lmstudio.test/v1",
      maxTokens: 50,
      model: "test-model",
      modelTimeoutMs: 1000,
      temperature: 0
    },
    fetchFn: async () =>
      new Response(
        JSON.stringify({
          choices: [
            {
              message: {
                content: "\n{\"command\":\"ui.inspect\",\"args\":{\"limit\":10},\"reason\":\"look\"}"
              }
            }
          ]
        }),
        { status: 200 }
      ),
    state: {
      findings: [],
      history: [],
      inspect: {},
      minSteps: 1,
      stepIndex: 0,
      stepLimit: 3,
      summary: { labels: ["Home"] }
    }
  });

  assert.deepEqual(result.decision, {
    command: "ui.inspect",
    args: { limit: 10 },
    reason: "look"
  });
});
