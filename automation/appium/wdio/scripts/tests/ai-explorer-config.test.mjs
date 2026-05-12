import test from "node:test";
import assert from "node:assert/strict";

import {
  DEFAULT_AI_EXPLORER_BASE_URL,
  DEFAULT_AI_EXPLORER_MODEL,
  publicConfig,
  readAiExplorerConfig
} from "../lib/ai-explorer-config.mjs";

test("readAiExplorerConfig defaults to local LM Studio endpoint", () => {
  const config = readAiExplorerConfig({});

  assert.equal(config.baseUrl, DEFAULT_AI_EXPLORER_BASE_URL);
  assert.equal(config.model, DEFAULT_AI_EXPLORER_MODEL);
  assert.equal(config.advisory, true);
  assert.equal(config.stepLimit, 36);
});

test("readAiExplorerConfig clamps numeric budgets", () => {
  const config = readAiExplorerConfig({
    AI_EXPLORER_STEP_LIMIT: "999",
    AI_EXPLORER_TIMEOUT_MS: "1",
    AI_EXPLORER_TEMPERATURE: "99"
  });

  assert.equal(config.stepLimit, 200);
  assert.equal(config.timeoutMs, 30000);
  assert.equal(config.temperature, 2);
});

test("publicConfig omits API key", () => {
  const config = readAiExplorerConfig({ AI_EXPLORER_API_KEY: "secret" });

  assert.equal(publicConfig(config).apiKey, undefined);
});
