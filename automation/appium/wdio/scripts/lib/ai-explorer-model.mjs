const JSON_START = /[{[]/;

export class ModelEndpointError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = "ModelEndpointError";
    this.status = details.status;
    this.body = details.body;
    this.payload = details.payload;
    this.content = details.content;
  }
}

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
        "For ui.tap, ui.read, and ui.exists, args must contain selector. ui.wait may omit selector to just pause briefly and re-check the app is alive.",
        "Valid selector examples: {\"selector\":\"~Privacy Pulse\"}, {\"selector\":\"~automation.power_toggle\"}, {\"selector\":\"-ios predicate string: type == 'XCUIElementTypeButton' AND name == 'Advanced'\"}, {\"selector\":\"//XCUIElementTypeButton[@name='Advanced']\"}.",
        "Never shorten automation selectors: use \"~automation.home_settings\", not \"~home_settings\".",
        "NAVIGATION MODEL (important): the bottom-tab ~automation.nav_* ids do NOT resolve on iOS — never propose nav_home/nav_activity/nav_advanced/nav_settings. From Home, go FORWARD into a surface with a Home card: ~automation.home_privacy_pulse, ~automation.home_advanced, ~automation.home_settings. To go BACK / leave a surface or sub-page, tap ~automation.nav_back (the top-bar back button; pops exactly one level; present on every screen except Home).",
        "HARD RULE: only ui.tap / ui.read / ui.exists a selector that appears in 'Selectors available on the current screen'. If what you want is not listed, it is on another screen — navigate there first (Home card to go in, ~automation.nav_back to go out), confirm via the next summary, THEN act. Never tap a control from a screen you are not currently on.",
        "Do not rely on ui.back for navigation; platform back does nothing in this app. Use ~automation.nav_back to return and Home cards to go forward.",
        "Never use args.name, and never invent selectors like \"XCUIElementTypeSwitch value=0\" or \"~0\".",
        "Never propose purchases, subscription changes, sign-out, account deletion, external app/browser/mail flows, or destructive Settings changes.",
        "Your goal is DEPTH, not just visiting screens. On a detail surface, exercise several of THAT surface's own controls from the available list (e.g. ~automation.filter_option.*, ~automation.privacy_pulse_range_*, ~automation.settings_*, ~automation.power_*) before leaving.",
        "KNOW WHERE YOU ARE: the top-bar title text in the current summary is the name of the screen/sub-page you are on (e.g. 'Exceptions', 'Settings', 'Privacy Pulse'). Read it before every decision; if it changed after your last tap, you navigated — act on the NEW screen, do not repeat the tap that brought you here.",
        "SUB-PAGE DISCIPLINE: tapping a Settings row (~automation.settings_exceptions/_weekly_report/_retention/_support) or a Privacy Pulse list item OPENS a sub-page. After that tap succeeds you are on the sub-page — do NOT tap the same row again. Instead: inspect the sub-page, interact with 2-3 of its own controls, then tap ~automation.nav_back exactly once and pick a DIFFERENT row next. Re-tapping the same entry row is the #1 wasted-step mistake.",
        "Sub-pages and list details often have NO automation.* ids. For a control without one, use its visible label: \"~Add\" only if that exact text is a label in the summary, or \"-ios predicate string: type == 'XCUIElementTypeButton' AND name == 'Add'\". NEVER invent ids like ~automation.Add, ~automation.filter_option.medium, ~automation.settings_weekly_report_range_1 — only automation ids that literally appear in the available list exist.",
        "EMPTY / EXHAUSTED SCREEN: if the current summary shows an empty state (text like 'Nothing to show yet', 'No ...', empty list) or you have already exercised every actionable control available on this screen, do NOT re-observe or re-tap it — immediately tap ~automation.nav_back once and move to a different, not-yet-explored area. Looping on a page with nothing left to do is a wasted-step and stuck-screen failure.",
        "A surface marked seen in mission coverage still needs its controls exercised and its sub-pages opened; do not treat seen as done.",
        "Prefer in-surface automation ids from the available list over re-tapping Home navigation cards. Use ui.tap only when it exercises something not yet tried.",
        "Do not use selectors listed as known failed selectors, and avoid actions listed as already tried.",
        "If the same screen keeps repeating, tap ~automation.nav_back to leave it, then open a DIFFERENT surface or a different, not-yet-opened sub-page or row.",
        "Do not finish until you have opened at least two different sub-pages and exercised controls inside them, unless there is a critical failure."
      ].join("\n")
    },
    {
      role: "user",
      content: [
        "Mission: explore the already-onboarded Blokada app and look for crashes, blank screens, stuck loading, broken navigation, inaccessible controls, and obvious functional regressions. Exercise real controls (toggles, filters, settings rows, range switches), not just top-level navigation.",
        "",
        `Budget: step ${state.stepIndex + 1} of ${state.stepLimit}; minimum useful steps ${state.minSteps}.`,
        "",
        `CURRENT SCREEN: ${state.currentScreen ?? "unknown"}`,
        "Selectors available on the current screen (only act on these; to reach anything else, switch screens first with a nav tab):",
        trimForPrompt(state.availableSelectors ?? [], 1500),
        "",
        "Known app surfaces from the codebase:",
        trimForPrompt(state.knownSurfaces ?? [], 3000),
        "",
        "Mission surface coverage:",
        trimForPrompt(state.missionStatus ?? [], 2500),
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
          failedSelectors: state.failedSelectors,
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
      throw new ModelEndpointError("Model endpoint returned non-JSON response.", {
        body: text
      });
    }

    if (!response.ok) {
      const message = payload?.error?.message ?? text;
      throw new ModelEndpointError(`Model endpoint failed with ${response.status}: ${message}`, {
        body: text,
        payload,
        status: response.status
      });
    }

    const content = payload?.choices?.[0]?.message?.content;
    if (typeof content !== "string" || content.trim().length === 0) {
      throw new ModelEndpointError(
        "Model endpoint response did not include choices[0].message.content.",
        {
          body: text,
          payload,
          status: response.status
        }
      );
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

  let decision;
  try {
    decision = extractJsonFromModelContent(content);
  } catch (error) {
    throw new ModelEndpointError(
      `Model response content could not be parsed as explorer JSON: ${error instanceof Error ? error.message : String(error)}`,
      {
        content,
        payload
      }
    );
  }

  return {
    decision,
    rawContent: content,
    usage: payload.usage
  };
}
