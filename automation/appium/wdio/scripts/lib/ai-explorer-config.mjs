export const DEFAULT_AI_EXPLORER_BASE_URL = "http://192.168.1.11:1234/v1";
export const DEFAULT_AI_EXPLORER_MODEL = "nvidia/nemotron-3-nano-4b";

function parseInteger(value, fallback, { min, max } = {}) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  const boundedMin = min == null ? parsed : Math.max(min, parsed);
  return max == null ? boundedMin : Math.min(max, boundedMin);
}

function parseNumber(value, fallback, { min, max } = {}) {
  const parsed = Number.parseFloat(String(value ?? ""));
  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  const boundedMin = min == null ? parsed : Math.max(min, parsed);
  return max == null ? boundedMin : Math.min(max, boundedMin);
}

function parseBoolean(value, fallback = false) {
  if (value == null || value === "") {
    return fallback;
  }

  const normalized = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}

function normalizeBaseUrl(value) {
  const raw = String(value ?? DEFAULT_AI_EXPLORER_BASE_URL).trim();
  return raw.replace(/\/+$/, "");
}

export function readAiExplorerConfig(env = process.env) {
  return {
    advisory: parseBoolean(env.AI_EXPLORER_ADVISORY, true),
    apiKey: String(env.AI_EXPLORER_API_KEY ?? "").trim(),
    baseUrl: normalizeBaseUrl(env.AI_EXPLORER_BASE_URL),
    fakeModel: parseBoolean(env.AI_EXPLORER_FAKE_MODEL, false),
    maxTokens: parseInteger(env.AI_EXPLORER_MAX_TOKENS, 2500, {
      min: 100,
      max: 8000
    }),
    minSteps: parseInteger(env.AI_EXPLORER_MIN_STEPS, 8, {
      min: 0,
      max: 100
    }),
    model: String(env.AI_EXPLORER_MODEL ?? DEFAULT_AI_EXPLORER_MODEL).trim(),
    modelTimeoutMs: parseInteger(env.AI_EXPLORER_MODEL_TIMEOUT_MS, 45000, {
      min: 1000,
      max: 180000
    }),
    stepLimit: parseInteger(env.AI_EXPLORER_STEP_LIMIT, 36, {
      min: 1,
      max: 200
    }),
    temperature: parseNumber(env.AI_EXPLORER_TEMPERATURE, 0.1, {
      min: 0,
      max: 2
    }),
    timeoutMs: parseInteger(env.AI_EXPLORER_TIMEOUT_MS, 12 * 60 * 1000, {
      min: 30000,
      max: 30 * 60 * 1000
    })
  };
}

export function publicConfig(config) {
  return {
    advisory: config.advisory,
    baseUrl: config.baseUrl,
    fakeModel: config.fakeModel,
    maxTokens: config.maxTokens,
    minSteps: config.minSteps,
    model: config.model,
    modelTimeoutMs: config.modelTimeoutMs,
    stepLimit: config.stepLimit,
    temperature: config.temperature,
    timeoutMs: config.timeoutMs
  };
}
