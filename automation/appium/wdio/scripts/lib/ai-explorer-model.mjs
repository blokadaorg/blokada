const JSON_START = /[{[]/;

function trimForPrompt(value, maxLength = 5000) {
  const text = JSON.stringify(value, null, 2);
  if (text.length <= maxLength) {
    return text;
  }
  return `${text.slice(0, maxLength)}\n... truncated ...`;
}

function selectorHintsFromLabels(...sources) {
  const seen = new Set();
  for (const source of sources) {
    const labels = Array.isArray(source?.labels) ? source.labels : [];
    for (const label of labels) {
      const text = String(label ?? "").trim();
      if (!text || text.length > 80 || text.includes("\n") || text.includes("&#10;")) {
        continue;
      }
      seen.add(`~${text}`);
      if (seen.size >= 12) {
        return [...seen];
      }
    }
  }
  return [...seen];
}

function findJsonEnd(content, startIndex) {
  const stack = [];
  let inString = false;
  let escaping = false;

  for (let index = startIndex; index < content.length; index += 1) {
    const char = content[index];

    if (inString) {
      if (escaping) {
        escaping = false;
        continue;
      }
      if (char === "\\") {
        escaping = true;
        continue;
      }
      if (char === "\"") {
        inString = false;
      }
      continue;
    }

    if (char === "\"") {
      inString = true;
      continue;
    }

    if (char === "{" || char === "[") {
      stack.push(char);
      continue;
    }

    if (char === "}" || char === "]") {
      const expected = char === "}" ? "{" : "[";
      if (stack.pop() !== expected) {
        throw new Error("Model returned malformed JSON.");
      }
      if (stack.length === 0) {
        return index + 1;
      }
    }
  }

  throw new Error("Model response did not contain a complete JSON object.");
}

export function extractJsonFromModelContent(content) {
  const text = String(content ?? "").trim();
  const match = text.match(JSON_START);
  if (!match || match.index == null) {
    throw new Error("Model response did not contain JSON.");
  }

  const endIndex = findJsonEnd(text, match.index);
  return JSON.parse(text.slice(match.index, endIndex));
}

export function buildExplorerMessages(state) {
  return [
    {
      role: "system",
      content: [
        "You are a mobile QA explorer for the Blokada iOS app.",
        "You propose exactly one safe Appium explorer command at a time.",
        "Return only JSON with this shape:",
        "{\"command\":\"ui.inspect|ui.summary|ui.tap|ui.back|ui.scroll|ui.swipe|ui.read|ui.exists|ui.wait|ui.screenshot|app.activate|finish\",\"args\":{},\"reason\":\"short reason\",\"confidence\":0.0,\"expected\":\"short expected result\"}",
        "For ui.tap, ui.read, ui.exists, and ui.wait, args must contain selector.",
        "Valid selector examples: {\"selector\":\"~Privacy Pulse\"}, {\"selector\":\"~automation.power_toggle\"}, {\"selector\":\"-ios predicate string: type == 'XCUIElementTypeButton' AND name == 'Advanced'\"}, {\"selector\":\"//XCUIElementTypeButton[@name='Advanced']\"}.",
        "Never use args.name, and never invent selectors like \"XCUIElementTypeSwitch value=0\".",
        "Never propose purchases, subscription changes, sign-out, account deletion, external app/browser/mail flows, or destructive Settings changes.",
        "Coverage is more important than repeating a successful tap. Avoid selectors that were already tapped or checked.",
        "If the same labels or the same screen keep appearing, choose ui.scroll or ui.back instead of another ui.tap.",
        "Use ui.scroll down/up to reveal more of the current screen, and use ui.back to leave a detail screen after checking one or two controls.",
        "Prefer unvisited low-risk navigation controls visible in the current UI. Use ui.tap only when it expands coverage.",
        "Do not finish until you have explored several distinct surfaces unless there is a critical failure."
      ].join("\n")
    },
    {
      role: "user",
      content: [
        "Mission: explore the already-onboarded Blokada app and look for crashes, blank screens, stuck loading, broken navigation, inaccessible controls, and obvious functional regressions.",
        "",
        `Budget: step ${state.stepIndex + 1} of ${state.stepLimit}; minimum useful steps ${state.minSteps}.`,
        "",
        "Current summary:",
        trimForPrompt(state.summary, 6000),
        "",
        "Selector hints you may use directly:",
        trimForPrompt(selectorHintsFromLabels(state.summary, state.inspect), 1000),
        "",
        "Most recent inspection:",
        trimForPrompt(state.inspect, 7000),
        "",
        "Recent executed steps:",
        trimForPrompt(state.history, 5000),
        "",
        "Selectors/actions already tried; avoid repeating them:",
        trimForPrompt({
          triedSelectors: state.triedSelectors,
          usedActions: state.usedActions
        }, 2500),
        "",
        "Known findings:",
        trimForPrompt(state.findings, 3000)
      ].join("\n")
    }
  ];
}

export async function callOpenAiCompatibleChat({
  apiKey,
  baseUrl,
  fetchFn = fetch,
  messages,
  model,
  modelTimeoutMs,
  maxTokens,
  temperature
}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), modelTimeoutMs);
  const headers = {
    "Content-Type": "application/json"
  };

  if (apiKey) {
    headers.Authorization = `Bearer ${apiKey}`;
  }

  try {
    const response = await fetchFn(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers,
      signal: controller.signal,
      body: JSON.stringify({
        model,
        messages,
        temperature,
        max_tokens: maxTokens
      })
    });

    const text = await response.text();
    let payload;
    try {
      payload = JSON.parse(text);
    } catch (_) {
      throw new Error(`Model endpoint returned non-JSON response: ${text.slice(0, 200)}`);
    }

    if (!response.ok) {
      const message = payload?.error?.message ?? text;
      throw new Error(`Model endpoint failed with ${response.status}: ${message}`);
    }

    const content = payload?.choices?.[0]?.message?.content;
    if (typeof content !== "string" || content.trim().length === 0) {
      throw new Error("Model endpoint response did not include choices[0].message.content.");
    }

    return {
      content,
      payload
    };
  } finally {
    clearTimeout(timeout);
  }
}

export async function requestExplorerDecision({
  config,
  fetchFn,
  state
}) {
  const messages = buildExplorerMessages(state);
  const { content, payload } = await callOpenAiCompatibleChat({
    apiKey: config.apiKey,
    baseUrl: config.baseUrl,
    fetchFn,
    messages,
    model: config.model,
    modelTimeoutMs: config.modelTimeoutMs,
    maxTokens: config.maxTokens,
    temperature: config.temperature
  });

  return {
    decision: extractJsonFromModelContent(content),
    rawContent: content,
    usage: payload.usage
  };
}
