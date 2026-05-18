import { JsonlExplorerClient } from "./ai-explorer-jsonl-client.mjs";
import { evaluateExplorerAction } from "./ai-explorer-guardrails.mjs";
import { publicConfig, readAiExplorerConfig } from "./ai-explorer-config.mjs";
import { requestExplorerDecision } from "./ai-explorer-model.mjs";
import {
  addAdvisory,
  addFinding,
  addStep,
  createExplorerReport,
  deriveReportStatus,
  writeExplorerReports
} from "./ai-explorer-report.mjs";

// A command that failed only because the model proposed a selector that does
// not resolve (or is off-screen) is expected exploration noise, not an app
// defect. Such failures are recorded as advisory so they do not escalate run
// status — otherwise every run is permanently "warning" and the status tells
// us nothing about regressions.
function isSelectorResolutionError(error) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  return /wasn'?t found|was not found|could not be located|no such element|unable to (find|locate)|no elements? found|not found/i.test(
    message
  );
}
import { getProjectPaths } from "./paths.mjs";

function compactEvent(event) {
  const result = event?.result ?? event;
  if (!result || typeof result !== "object") {
    return result;
  }

  return {
    activeApp: result.activeApp,
    appIdentity: result.appIdentity,
    appState: result.appState,
    labels: Array.isArray(result.labels) ? result.labels.slice(0, 20) : undefined,
    target: result.target,
    bundleId: result.bundleId
  };
}

function compactInspect(event) {
  const result = event?.result ?? event;
  if (!result || typeof result !== "object") {
    return result;
  }

  return {
    artifacts: result.artifacts,
    elements: Array.isArray(result.elements) ? result.elements.slice(0, 25) : undefined,
    labels: Array.isArray(result.labels) ? result.labels.slice(0, 25) : undefined,
    tree: Array.isArray(result.tree) ? result.tree.slice(0, 25) : undefined
  };
}

function stepSignature(action, scope = "") {
  return `${scope}|${action.command}:${JSON.stringify(action.args ?? {})}`;
}

function repetitionLimit(action) {
  // Scoped per current screen (see stepSignature call site), so these allow
  // legitimately re-entering a surface and tapping a few of its controls
  // before the loop is treated as stuck. A limit of 1 globally meant each
  // navigation selector was banned for the whole run after one use, which
  // locked the explorer on Home.
  if (action.command === "ui.tap" || action.command === "ui.exists") {
    return 3;
  }
  if (action.command === "ui.inspect") {
    return 2;
  }
  return 4;
}

function labelSignature(summary) {
  const labels = summary?.labels ?? [];
  return Array.isArray(labels) ? labels.slice(0, 8).join("|") : "";
}

function recordAction(state, action) {
  const selector = selectorFromAction(action);
  if (selector) {
    state.triedSelectors.set(
      selector,
      (state.triedSelectors.get(selector) ?? 0) + 1
    );
  }
}

function compactMap(map, limit = 12) {
  return [...map.entries()]
    .slice(-limit)
    .map(([value, count]) => ({ value, count }));
}

const KNOWN_SURFACES = [
  {
    id: "home",
    name: "Home",
    reach: "Initial post-onboarding surface; return here with back navigation.",
    selectors: ["~automation.screen_home"],
    navigationSelectors: [],
    expectedLabels: [
      "automation.screen_home",
      "automation.power_toggle",
      "automation.home_privacy_pulse",
      "automation.home_advanced",
      "automation.home_settings",
      "Privacy Pulse",
      "Advanced"
    ]
  },
  {
    id: "privacyPulse",
    name: "Privacy Pulse",
    reach: "Home Privacy Pulse card; this is the current V6 activity/statistics surface.",
    selectors: ["~automation.screen_privacy_pulse"],
    navigationSelectors: ["~automation.home_privacy_pulse", "~Privacy Pulse"],
    expectedLabels: [
      "automation.screen_privacy_pulse",
      "24 h",
      "7 d",
      "Blocked",
      "Allowed"
    ],
    // Markers that prove the body actually rendered (not just the screen
    // identity / chrome). If the identity is seen but none of these ever are,
    // the surface is degraded/broken even though it is not fully blank.
    contentLabels: ["automation.privacy_pulse_range_", "Blocked", "Allowed"],
    scrollDirections: ["down", "down", "up"],
    returnHome: true
  },
  {
    id: "advanced",
    name: "Advanced",
    reach: "Home Advanced card; shows filter and blocklist controls.",
    selectors: ["~automation.screen_advanced"],
    navigationSelectors: ["~automation.home_advanced", "~Advanced"],
    expectedLabels: [
      "automation.screen_advanced",
      "automation.filter_option.",
      "Blocklists",
      "Filters"
    ],
    contentLabels: ["automation.filter_option.", "Filters", "Blocklists"],
    scrollDirections: ["down", "down", "up"],
    returnHome: true
  },
  {
    id: "settings",
    name: "Settings",
    reach: "Home header settings button; exposes account, notifications, support, and app info.",
    selectors: ["~automation.screen_settings"],
    navigationSelectors: ["~automation.home_settings", "~Settings"],
    expectedLabels: [
      "automation.screen_settings",
      "automation.settings_exceptions",
      "automation.settings_weekly_report",
      "Notifications",
      "Version"
    ],
    contentLabels: [
      "automation.settings_exceptions",
      "automation.settings_weekly_report",
      "automation.settings_retention",
      "automation.settings_support"
    ],
    scrollDirections: ["down", "up"],
    returnHome: true
  }
];

// Home cards whose tap MUST land on a specific surface. If the tap resolves
// but the screen is not the expected one afterward, the control is broken
// (does nothing / wrong target) — a regression a manual tester catches at
// once. Reliable because the destination is known and screen detection +
// the nav settle make it low-false-positive.
function expectedScreenForSelector(selector) {
  const s = String(selector ?? "").toLowerCase();
  if (!s) return undefined;
  if (s.includes("home_advanced") || s === "~advanced") return "advanced";
  if (s.includes("home_settings") || s === "~settings") return "settings";
  if (s.includes("home_privacy_pulse") || s === "~privacy pulse") {
    return "privacyPulse";
  }
  return undefined;
}

const MISSION_WARMUP_SURFACES = ["privacyPulse", "advanced", "settings"];

// Fraction of the wall-clock budget the deterministic mission warmup may consume
// before control is handed to the model. The run is time-bound (it hits the
// wall-clock budget long before the step budget), and the model can now reach
// every surface on its own, so the warmup is kept short to leave the model the
// bulk of the budget for in-surface depth.
const WARMUP_BUDGET_FRACTION = 0.15;

// Navigation primitive. The V6 bottom-tab ids (~automation.nav_*) do NOT
// resolve via Appium even after the TabItem MergeSemantics change (the blurred
// persistent overlay keeps them out of the iOS accessibility tree — confirmed
// by two on-device runs). The only Appium-resolvable navigation handle is the
// top-bar back button (~automation.nav_back, instrumented in top_bar.dart),
// which pops exactly one level. Platform back is a no-op in this Flutter iOS
// app. Forward navigation uses the Home cards (~automation.home_*).
const NAV_BACK_SELECTOR = "~automation.nav_back";

// A route pop animates for StandardRoute.transitionDuration (500ms) and the
// controller delays its own pop bookkeeping by 600ms, so the screen is not
// observable until ~1.1s later. Observing sooner makes screen detection race
// the animation and the model thinks it is still on the old screen.
const NAV_SETTLE_MS = 1400;

// Upper bound on back pops when returning to Home, so a stuck back button
// cannot loop forever.
const MAX_BACK_POPS = 6;

// How many consecutive model-decision failures end the run. A single failure
// triggers a deterministic fallback probe and the loop continues, so one flaky
// model response no longer aborts the whole exploration.
const MODEL_FAILURE_ABORT_THRESHOLD = 3;

function publicKnownSurfaces() {
  return KNOWN_SURFACES.map(
    ({ id, name, reach, navigationSelectors, expectedLabels, routeOnly }) => ({
      id,
      name,
      reach,
      navigationSelectors,
      expectedLabels,
      routeOnly: routeOnly === true
    })
  );
}

function createMissionState() {
  return KNOWN_SURFACES.map((surface) => ({
    id: surface.id,
    name: surface.name,
    routeOnly: surface.routeOnly === true,
    seen: false,
    contentSeen: false,
    attempted: false,
    attempts: 0
  }));
}

function collectObservedValues(summary, inspect) {
  const values = [];
  const push = (value) => {
    if (value == null) return;
    const text = String(value).trim();
    if (text) values.push(text);
  };

  for (const label of summary?.labels ?? []) push(label);
  for (const label of inspect?.labels ?? []) push(label);
  for (const line of inspect?.tree ?? []) push(line);
  for (const element of inspect?.elements ?? []) {
    push(element.name);
    push(element.label);
    push(element.value);
  }

  return [...new Set(values.map((value) => value.toLowerCase()))];
}

// Generic blank/broken-screen signal that works for EVERY WithTopBar screen
// and sub-page without per-screen config. Derived from real device captures:
// a healthy screen's ui.summary always has either a body automation id
// (filter_option / privacy_pulse_range / settings_* / exceptions_tab_* / …)
// or many content text labels; a blank screen (empty body) collapses to ONLY
// chrome — e.g. ["Dev","back","automation.nav_back","Home"(breadcrumb),
// "automation.screen_advanced","Advanced\nAdvanced"(title),
// "automation.screen_title"]. So: a real titled screen with no body
// automation id and at most the breadcrumb+title text remaining is blank.
function screenBodyValues(summary, inspect) {
  const raw = [];
  for (const label of summary?.labels ?? []) raw.push(String(label));
  for (const label of inspect?.labels ?? []) raw.push(String(label));
  for (const element of inspect?.elements ?? []) {
    raw.push(String(element.name ?? ""), String(element.label ?? ""), String(element.value ?? ""));
  }
  const values = [...new Set(raw.map((v) => v.trim().toLowerCase()).filter(Boolean))];

  const titled = values.some((v) => v.includes("automation.screen_title"));
  const loading = values.some((v) =>
    /\b(loading|please wait|initializing|starting)\b/.test(v)
  );
  // nav_/screen_ ids are chrome; any OTHER automation.* id is real body
  // content (a control the screen is supposed to show).
  const hasBodyAutomationId = values.some(
    (v) => /^automation\./.test(v) && !/^automation\.(nav_|screen_)/.test(v)
  );
  // Non-chrome text labels. On a blank screen only the persistent-nav
  // breadcrumb and the title text remain (<=2); a real screen has many more.
  const bodyTextCount = values.filter(
    (v) => !/^automation\./.test(v) && v !== "back" && v !== "dev" && v !== "blokada"
  ).length;
  const blank = titled && !loading && !hasBodyAutomationId && bodyTextCount <= 2;
  return { titled, loading, blank, hasBodyAutomationId, bodyTextCount };
}

// Two consecutive blank observations (the screen has settled, see the ~1.4s
// nav settle) before declaring it broken — guards against a single transient
// loading/transition frame producing a false red.
const BLANK_SCREEN_STREAK_ABORT = 2;

// A core screen rendering empty is a serious regression a manual tester would
// catch instantly: escalate to critical (red status) and stop the run — no
// value exploring a broken build further.
function evaluateScreenIntegrity(report, state) {
  const { blank } = screenBodyValues(state.summary, state.inspect);
  if (!blank) {
    state.blankScreenStreak = 0;
    return;
  }
  state.blankScreenStreak = (state.blankScreenStreak ?? 0) + 1;
  if (state.blankScreenStreak >= BLANK_SCREEN_STREAK_ABORT && !state.blankScreenAbort) {
    state.blankScreenAbort = true;
    addFinding(
      report,
      "critical",
      "A screen rendered with no content (blank/broken screen).",
      {
        summaryLabels: Array.isArray(state.summary?.labels)
          ? state.summary.labels.slice(0, 12)
          : []
      }
    );
  }
}

function matchesExpectedLabel(observedValues, expected) {
  const normalizedExpected = String(expected).trim().toLowerCase();
  if (!normalizedExpected) return false;

  if (normalizedExpected.startsWith("automation.") || normalizedExpected.endsWith(".")) {
    return observedValues.some((value) => value.includes(normalizedExpected));
  }

  return observedValues.some(
    (value) =>
      value === normalizedExpected ||
      value.startsWith(`${normalizedExpected} `) ||
      value.startsWith(`${normalizedExpected}\n`)
  );
}

function updateMissionCoverage(report, state, reason) {
  const observedValues = collectObservedValues(state.summary, state.inspect);
  if (observedValues.length === 0) return;

  for (const surface of KNOWN_SURFACES) {
    const mission = state.mission.find((entry) => entry.id === surface.id);
    if (!mission) continue;

    // Track body content separately from screen identity so a surface that
    // shows only its chrome (identity present, content markers absent) is
    // recorded as reached-but-degraded, not silently "seen".
    if (!mission.contentSeen && Array.isArray(surface.contentLabels)) {
      const contentHit = surface.contentLabels.find((label) =>
        matchesExpectedLabel(observedValues, label)
      );
      if (contentHit) {
        mission.contentSeen = true;
      }
    }

    if (mission.seen) continue;

    const matched = surface.expectedLabels.find((label) =>
      matchesExpectedLabel(observedValues, label)
    );
    if (!matched) continue;

    mission.seen = true;
    mission.matched = matched;
    mission.reason = reason;
    addStep(report, {
      kind: "mission",
      command: "surface-covered",
      reason: `${surface.name} observed via ${matched}.`
    });
  }

  // Runs at every observation point (summary+inspect just refreshed).
  evaluateScreenIntegrity(report, state);
}

function missionStatus(state) {
  return state.mission.map((entry) => ({
    id: entry.id,
    name: entry.name,
    routeOnly: entry.routeOnly,
    seen: entry.seen,
    attempted: entry.attempted,
    attempts: entry.attempts,
    matched: entry.matched
  }));
}

function missionEntry(state, surfaceId) {
  return state.mission.find((entry) => entry.id === surfaceId);
}

function missionSurfaceSeen(state, surfaceId) {
  return missionEntry(state, surfaceId)?.seen === true;
}

function currentScreenIds(state) {
  const observed = collectObservedValues(state.summary, state.inspect);
  return {
    advanced: observed.some((value) => value.includes("automation.screen_advanced")),
    home: observed.some((value) => value.includes("automation.screen_home")),
    privacyPulse: observed.some((value) => value.includes("automation.screen_privacy_pulse")),
    settings: observed.some((value) => value.includes("automation.screen_settings"))
  };
}

function isCurrentHomeSurface(state) {
  return currentScreenIds(state).home === true;
}

// Coarse "what screen are we on" key used to scope repetition signatures, so
// the same action on different surfaces is tracked independently. Detail
// surfaces win over Home because a pushed surface can still leak some Home
// labels in a merged accessibility tree.
function currentScreenKey(state) {
  const ids = currentScreenIds(state);
  if (ids.privacyPulse) return "privacyPulse";
  if (ids.advanced) return "advanced";
  if (ids.settings) return "settings";
  if (ids.home) return "home";
  return "other";
}

// Selectors the model can actually act on right now: every automation.* id
// currently visible in the summary/inspection, plus the persistent bottom-tab
// nav ids. Passing this to the model stops it proposing controls that only
// exist on a different screen (the dominant failure mode in earlier runs).
function observedAutomationSelectors(state) {
  const selectors = new Set();
  for (const value of collectObservedValues(state.summary, state.inspect)) {
    const match = String(value).match(/automation\.[a-z0-9_.]+/i);
    if (match) {
      selectors.add(`~${match[0].replace(/[.\s]+$/, "")}`);
    }
  }
  // The top-bar back button is present on every pushed surface/sub-page but
  // not on Home; surface it explicitly since the bare back Icon does not show
  // up as an automation.* label in the summary.
  if (currentScreenKey(state) !== "home") {
    selectors.add(NAV_BACK_SELECTOR);
  }
  return [...selectors];
}

// Coarse screen key from summary labels alone (no inspect dependency), used to
// detect screen changes so the repeated-UI guard does not treat normal
// in-surface exploration as "stuck".
function screenKeyFromSummary(summary) {
  const labels = (Array.isArray(summary?.labels) ? summary.labels : []).map((label) =>
    String(label).toLowerCase()
  );
  const has = (fragment) => labels.some((label) => label.includes(fragment));
  if (has("automation.screen_privacy_pulse")) return "privacyPulse";
  if (has("automation.screen_advanced")) return "advanced";
  if (has("automation.screen_settings")) return "settings";
  if (has("automation.screen_home")) return "home";
  return "other";
}

function selectorRequiresHomeSurface(selector) {
  if (!selector) return false;
  // Only the Home cards (~automation.home_*) genuinely exist only on Home and
  // therefore need a return-to-Home first. The bottom-tab ~automation.nav_*
  // ids are not Appium-resolvable on iOS anyway (TabItem Semantics issue), and
  // forcing a Home round-trip for generic text selectors just thrashed
  // navigation and blocked in-surface depth.
  return selector.startsWith("~automation.home_");
}

function selectorFromAction(action) {
  return typeof action?.args?.selector === "string" ? action.args.selector : undefined;
}

function recordFailedSelector(state, selector) {
  if (!selector) return;
  state.failedSelectors.set(selector, (state.failedSelectors.get(selector) ?? 0) + 1);
}

function trimString(value, maxLength = 3000) {
  const text = typeof value === "string" ? value : JSON.stringify(value);
  if (text == null) return undefined;
  return text.length > maxLength ? `${text.slice(0, maxLength)}\n... truncated ...` : text;
}

function compactModelPayload(payload) {
  if (payload == null || typeof payload !== "object") {
    return payload;
  }
  return {
    id: payload.id,
    model: payload.model,
    object: payload.object,
    usage: payload.usage,
    error: payload.error,
    choices: Array.isArray(payload.choices)
      ? payload.choices.slice(0, 2).map((choice) => ({
          finish_reason: choice.finish_reason,
          index: choice.index,
          message: choice.message
            ? {
                role: choice.message.role,
                content: trimString(choice.message.content ?? "", 500),
                reasoning_content: trimString(choice.message.reasoning_content ?? "", 500)
              }
            : undefined
        }))
      : undefined
  };
}

function modelFailureDetails(error) {
  const details = {
    error: error instanceof Error ? error.message : String(error)
  };
  if (error?.status != null) details.status = error.status;
  if (error?.body != null) details.body = trimString(error.body, 3000);
  if (error?.content != null) details.content = trimString(error.content, 3000);
  if (error?.payload != null) details.payload = compactModelPayload(error.payload);
  return details;
}

function createFakeDecisionProvider() {
  const decisions = [
    {
      command: "ui.inspect",
      args: { compact: true, interactiveOnly: true, limit: 30, visibleOnly: true },
      reason: "Inspect interactive controls after the static smoke completed.",
      confidence: 1
    },
    {
      command: "ui.scroll",
      args: { direction: "down" },
      reason: "Reveal lower home content without changing app state.",
      confidence: 1
    },
    {
      command: "ui.inspect",
      args: { compact: true, interactiveOnly: true, limit: 30, visibleOnly: true },
      reason: "Inspect the lower visible surface after scrolling.",
      confidence: 1
    },
    {
      command: "ui.scroll",
      args: { direction: "up" },
      reason: "Return toward the original visible surface.",
      confidence: 1
    },
    {
      command: "ui.summary",
      args: { limit: 25, visibleOnly: true },
      reason: "Confirm the app is still responsive.",
      confidence: 1
    },
    {
      command: "finish",
      args: {},
      reason: "Fake model completed its deterministic smoke exploration.",
      confidence: 1
    }
  ];
  let index = 0;
  return async () => decisions[Math.min(index++, decisions.length - 1)];
}

async function executeExplorerCommand(client, report, command, args, reason) {
  report.log?.(`AI explorer command: ${command}${reason ? ` - ${reason}` : ""}`);
  addStep(report, {
    kind: "command",
    command,
    args,
    reason
  });

  const event = await client.command(command, args);
  report.log?.(`AI explorer result: ${command}`);
  addStep(report, {
    kind: "result",
    command,
    result: compactEvent(event)
  });
  return event;
}

async function observeSummary(client, report, reason = "Observe current UI.") {
  const event = await executeExplorerCommand(
    client,
    report,
    "ui.summary",
    { limit: 25, visibleOnly: true },
    reason
  );
  return event.result;
}

async function observeInspect(client, report, reason = "Inspect current UI.") {
  const event = await executeExplorerCommand(
    client,
    report,
    "ui.inspect",
    {
      compact: true,
      elements: true,
      interactiveOnly: true,
      labels: true,
      limit: 35,
      tree: true,
      visibleOnly: true
    },
    reason
  );
  return event.result;
}

function evaluateSummary(report, summary, state) {
  const labels = Array.isArray(summary?.labels) ? summary.labels : [];
  const foreground = summary?.appState?.code === 4;

  if (!foreground) {
    addFinding(report, "critical", "App is not in foreground during AI exploration.", {
      appState: summary?.appState,
      target: summary?.target,
      bundleId: summary?.bundleId
    });
  }

  if (labels.length === 0) {
    addFinding(report, "critical", "Visible UI summary has no readable labels.", {
      appIdentity: summary?.appIdentity,
      target: summary?.target
    });
  }

  // Moving between screens clears accumulated staleness: re-observing the same
  // screen while drilling into its own controls is expected depth, not a loop,
  // so only genuine no-progress on one screen should trip the guard.
  const screenKey = screenKeyFromSummary(summary);
  if (screenKey !== "other" && state.lastScreenKey && screenKey !== state.lastScreenKey) {
    state.labelSignatures.clear();
  }
  if (screenKey !== "other") {
    state.lastScreenKey = screenKey;
  }

  const signature = labelSignature(summary);
  if (signature) {
    state.labelSignatures.set(signature, (state.labelSignatures.get(signature) ?? 0) + 1);
    const repeatCount = state.labelSignatures.get(signature);
    if (repeatCount >= 7 && !state.inCoverageIntervention) {
      state.needsCoverageIntervention =
        state.needsCoverageIntervention ??
        "Visible UI has repeated several times; force a scroll/back coverage action.";
    }
    if (repeatCount >= 12) {
      addFinding(report, "warning", "Explorer appears to be revisiting the same visible UI repeatedly.", {
        labels: labels.slice(0, 8)
      });
    }
  }

  const loadingLabels = labels.filter((label) =>
    /\b(loading|please wait|initializing|starting)\b/i.test(String(label))
  );
  if (loadingLabels.length > 0) {
    state.loadingObservations += 1;
    if (state.loadingObservations >= 3) {
      addFinding(report, "warning", "Loading-style text persisted across several observations.", {
        labels: loadingLabels
      });
    }
  } else {
    state.loadingObservations = 0;
  }
}

// Break a stuck-screen loop by popping one level via the top-bar back button
// (the only reliable navigation handle); landing on the parent surface is
// enough to escape. If that does not change the screen, fall through to a
// scroll nudge. Bottom-tab "switch surface" was tried in round 1 but the
// nav_* ids do not resolve, so it is not used here.
async function runCoverageIntervention(client, report, state, reason) {
  const currentKey = currentScreenKey(state);
  if (currentKey !== "other" && currentKey !== "home") {
    state.coverageInterventions += 1;
    state.inCoverageIntervention = true;
    report.log?.(`AI explorer coverage intervention: ${reason}`);
    addStep(report, {
      kind: "coverage",
      command: "ui.tap",
      args: { selector: NAV_BACK_SELECTOR },
      reason
    });
    try {
      await executeExplorerCommand(
        client,
        report,
        "ui.tap",
        { selector: NAV_BACK_SELECTOR },
        "Coverage intervention: pop one level to escape a repeated screen."
      );
      await settleAfterNavigation(client, report);
      state.summary = await observeSummary(client, report, "Observe after coverage intervention.");
      evaluateSummary(report, state.summary, state);
      state.inspect = await observeInspect(client, report, "Inspect after coverage intervention.");
      updateMissionCoverage(report, state, "Coverage intervention observation.");
      state.inCoverageIntervention = false;
      state.needsCoverageIntervention = undefined;
      if (currentScreenKey(state) !== currentKey) {
        return;
      }
    } catch (error) {
      addAdvisory(report, "Coverage intervention back-pop failed.", {
        selector: NAV_BACK_SELECTOR,
        error: error instanceof Error ? error.message : String(error)
      });
      state.inCoverageIntervention = false;
    }
  }

  const interventions = [
    {
      command: "ui.scroll",
      args: { direction: "down" },
      reason: "Coverage intervention: scroll down to reveal lower content."
    },
    {
      command: "ui.scroll",
      args: { direction: "up" },
      reason: "Coverage intervention: scroll up to verify the upper content."
    },
    {
      command: "ui.back",
      args: {},
      reason: "Coverage intervention: go back to escape a repeated screen."
    },
    {
      command: "ui.scroll",
      args: { direction: "down" },
      reason: "Coverage intervention: scroll after navigation to inspect another section."
    }
  ];
  const intervention = interventions[state.coverageInterventions % interventions.length];
  state.coverageInterventions += 1;
  state.inCoverageIntervention = true;

  report.log?.(`AI explorer coverage intervention: ${reason}`);
  addStep(report, {
    kind: "coverage",
    command: intervention.command,
    args: intervention.args,
    reason
  });

  try {
    await executeExplorerCommand(
      client,
      report,
      intervention.command,
      intervention.args,
      intervention.reason
    );
  } catch (error) {
    addAdvisory(report, `Coverage intervention failed: ${intervention.command}`, {
      args: intervention.args,
      error: error instanceof Error ? error.message : String(error)
    });
  }

  state.summary = await observeSummary(client, report, "Observe after coverage intervention.");
  evaluateSummary(report, state.summary, state);
  state.inspect = await observeInspect(client, report, "Inspect after coverage intervention.");
  updateMissionCoverage(report, state, "Coverage intervention observation.");
  state.inCoverageIntervention = false;
  state.needsCoverageIntervention = undefined;
}

async function runInitialCoverageProbe(client, report, state) {
  await runCoverageIntervention(
    client,
    report,
    state,
    "Initial coverage probe before model-led exploration."
  );
  await runCoverageIntervention(
    client,
    report,
    state,
    "Initial coverage probe return pass before model-led exploration."
  );
}

function labelsInclude(summary, value) {
  const labels = Array.isArray(summary?.labels) ? summary.labels : [];
  return labels.some((label) => String(label).includes(value));
}

async function dismissBlockingIntroIfPresent(client, report, state) {
  if (!labelsInclude(state.summary, "automation.onboard_continue")) {
    return;
  }

  addStep(report, {
    kind: "preflight",
    command: "ui.tap",
    args: { selector: "~automation.onboard_continue" },
    reason: "Dismiss intro onboarding overlay before AI exploration."
  });

  try {
    await executeExplorerCommand(
      client,
      report,
      "ui.tap",
      { selector: "~automation.onboard_continue" },
      "Dismiss intro onboarding overlay before AI exploration."
    );
  } catch (error) {
    addAdvisory(report, "Failed to dismiss intro onboarding overlay before AI exploration.", {
      error: error instanceof Error ? error.message : String(error)
    });
    return;
  }

  state.summary = await observeSummary(client, report, "Observe after dismissing intro onboarding overlay.");
  evaluateSummary(report, state.summary, state);
  state.inspect = await observeInspect(client, report, "Inspect after dismissing intro onboarding overlay.");
  updateMissionCoverage(report, state, "Post-onboarding-overlay observation.");
}

function addBlockingOnboardingFinding(report, state) {
  if (labelsInclude(state.summary, "automation.dns_onboard_sheet")) {
    addFinding(report, "warning", "AI explorer started before DNS onboarding was completed.", {
      hint: "Run make appium-test first, then make appium-ai-explore APP_INSTALL=0."
    });
  }
}

async function selectorExists(client, report, selector, reason) {
  try {
    const event = await executeExplorerCommand(
      client,
      report,
      "ui.exists",
      { selector },
      reason
    );
    return event.result === true;
  } catch (error) {
    addAdvisory(report, `Mission selector probe failed: ${selector}`, {
      error: error instanceof Error ? error.message : String(error),
      selector
    });
    return false;
  }
}

async function observeAfterMissionAction(client, report, state, reason) {
  state.summary = await observeSummary(client, report, reason);
  evaluateSummary(report, state.summary, state);
  state.inspect = await observeInspect(client, report, "Inspect after mission action.");
  updateMissionCoverage(report, state, reason);
}

async function observeAfterNavigation(client, report, state, reason) {
  state.summary = await observeSummary(client, report, reason);
  evaluateSummary(report, state.summary, state);
  state.inspect = await observeInspect(client, report, "Inspect after navigation action.");
  updateMissionCoverage(report, state, reason);
}

// Pause long enough for a route push/pop animation to finish before observing,
// so screen detection does not race the transition (see NAV_SETTLE_MS).
async function settleAfterNavigation(client, report) {
  try {
    await executeExplorerCommand(
      client,
      report,
      "ui.wait",
      { timeoutMs: NAV_SETTLE_MS },
      "Wait for the navigation transition to settle."
    );
  } catch (_) {
    // Best-effort settle; observation will still proceed.
  }
}

async function ensureHomeSurface(client, report, state, reason) {
  if (isCurrentHomeSurface(state)) {
    return true;
  }

  addStep(report, {
    kind: "navigation",
    command: "home",
    reason
  });

  // No Appium-resolvable "home"/tab control exists in this app. The only
  // reliable handle is the top-bar back button (~automation.nav_back), which
  // pops exactly one level, so return to Home by popping repeatedly until the
  // Home surface is detected. Each pop must settle before observing because the
  // route transition takes ~1.1s. Platform back / "~Home" / name=='Home' are
  // kept only as last-resort fallbacks (back is a no-op here; the others are
  // the dynamic breadcrumb label and unreliable).
  for (let pop = 0; pop < MAX_BACK_POPS; pop += 1) {
    try {
      await executeExplorerCommand(
        client,
        report,
        "ui.tap",
        { selector: NAV_BACK_SELECTOR },
        `${reason}: tap back (pop ${pop + 1}).`
      );
    } catch (error) {
      addStep(report, {
        kind: "navigation-failed",
        command: "ui.tap",
        args: { selector: NAV_BACK_SELECTOR },
        reason: error instanceof Error ? error.message : String(error)
      });
      break;
    }

    await settleAfterNavigation(client, report);
    await observeAfterNavigation(client, report, state, "Observe while returning to Home.");
    if (isCurrentHomeSurface(state)) {
      return true;
    }
  }

  const fallbacks = [
    {
      command: "ui.back",
      args: {},
      reason: `${reason}: platform back fallback.`
    },
    {
      command: "ui.tap",
      args: { selector: "~Home" },
      reason: `${reason}: tap visible Home breadcrumb control.`
    },
    {
      command: "ui.tap",
      args: {
        selector: "-ios predicate string: name == 'Home' OR label == 'Home'"
      },
      reason: `${reason}: tap Home by iOS predicate.`
    }
  ];

  for (const attempt of fallbacks) {
    try {
      await executeExplorerCommand(
        client,
        report,
        attempt.command,
        attempt.args,
        attempt.reason
      );
    } catch (error) {
      addStep(report, {
        kind: "navigation-failed",
        command: attempt.command,
        args: attempt.args,
        reason: error instanceof Error ? error.message : String(error)
      });
      continue;
    }

    await settleAfterNavigation(client, report);
    await observeAfterNavigation(client, report, state, "Observe while returning to Home.");
    if (isCurrentHomeSurface(state)) {
      return true;
    }
  }

  addAdvisory(report, "Could not return to Home surface before continuing exploration.", {
    labels: Array.isArray(state.summary?.labels) ? state.summary.labels.slice(0, 12) : []
  });
  return false;
}

async function returnTowardHome(client, report, state, reason) {
  return ensureHomeSurface(client, report, state, reason);
}

async function runMissionSurface(client, report, state, surface) {
  const mission = missionEntry(state, surface.id);
  if (!mission || mission.seen || surface.routeOnly) {
    return false;
  }

  mission.attempted = true;
  mission.attempts += 1;
  addStep(report, {
    kind: "mission",
    command: "surface-target",
    reason: `Exercise ${surface.name}: ${surface.reach}`
  });

  if (surface.navigationSelectors.some(selectorRequiresHomeSurface)) {
    const homeReady = await ensureHomeSurface(
      client,
      report,
      state,
      `Mission: return to Home before opening ${surface.name}.`
    );
    if (!homeReady) {
      return false;
    }
  }

  for (const selector of surface.navigationSelectors) {
    if (state.failedSelectors.has(selector)) {
      continue;
    }

    const exists = await selectorExists(
      client,
      report,
      selector,
      `Mission probe for ${surface.name}.`
    );
    if (!exists) {
      continue;
    }

    try {
      await executeExplorerCommand(
        client,
        report,
        "ui.tap",
        { selector },
        `Mission: open ${surface.name}.`
      );
      recordAction(state, { command: "ui.tap", args: { selector } });
    } catch (error) {
      recordFailedSelector(state, selector);
      addAdvisory(report, `Mission navigation failed: ${surface.name}`, {
        error: error instanceof Error ? error.message : String(error),
        selector
      });
      continue;
    }

    await observeAfterMissionAction(client, report, state, `Observe ${surface.name}.`);

    if (!missionSurfaceSeen(state, surface.id)) {
      addAdvisory(report, `Mission tap did not reach surface: ${surface.name}`, {
        selector,
        expected: surface.expectedLabels
      });
      continue;
    }

    for (const direction of surface.scrollDirections ?? []) {
      try {
        await executeExplorerCommand(
          client,
          report,
          "ui.scroll",
          { direction },
          `Mission: scan ${surface.name} ${direction}.`
        );
        await observeAfterMissionAction(
          client,
          report,
          state,
          `Observe ${surface.name} after ${direction} scroll.`
        );
      } catch (error) {
        addAdvisory(report, `Mission scroll failed: ${surface.name}`, {
          direction,
          error: error instanceof Error ? error.message : String(error)
        });
      }
    }

    if (surface.returnHome) {
      await returnTowardHome(
        client,
        report,
        state,
        `Mission: return from ${surface.name} to the home surface.`
      );
    }

    return true;
  }

  addAdvisory(report, `Mission surface was not reachable: ${surface.name}`, {
    selectors: surface.navigationSelectors
  });
  return false;
}

async function runMissionWarmup(client, report, state, warmupDeadline) {
  for (const id of MISSION_WARMUP_SURFACES) {
    if (state.blankScreenAbort || state.wrongAppAbort) {
      return;
    }
    if (Date.now() >= warmupDeadline) {
      addStep(report, {
        kind: "mission",
        command: "budget",
        reason:
          "Mission warmup stopped because the warmup time budget was reached; handing remaining budget to the model."
      });
      return;
    }
    const surface = KNOWN_SURFACES.find((entry) => entry.id === id);
    if (!surface) continue;
    await runMissionSurface(client, report, state, surface);
  }
}

// The foreground app is not the configured target (e.g. an incoming push
// notification banner was tapped and iOS switched to another app). ui.summary
// already computes this as targetVerified; the runner must act on it, or the
// explorer silently "explores" the wrong app and the run status is
// meaningless. Strict === false so an undefined field is treated as unknown
// (no false positive).
function isOffTarget(summary) {
  return summary != null && summary.targetVerified === false;
}

function foregroundBundleId(summary) {
  const bundle = summary?.activeApp?.bundleId ?? summary?.bundleId;
  return typeof bundle === "string" && bundle.trim() ? bundle.trim() : "unknown app";
}

// Two consecutive off-target observations *after* a recovery attempt before
// declaring the run unrecoverable — a single notification tap self-heals via
// app.activate and exploration continues; only a stuck wrong-app aborts.
const OFF_TARGET_STREAK_ABORT = 2;

async function recoverToApp(client, report) {
  try {
    await executeExplorerCommand(
      client,
      report,
      "app.activate",
      {},
      "Recover by activating the configured app."
    );
    return true;
  } catch (error) {
    addFinding(report, "critical", "Failed to reactivate app after explorer detected bad foreground state.", {
      error: error instanceof Error ? error.message : String(error)
    });
    return false;
  }
}

async function runFallbackProbe(client, report, state) {
  addAdvisory(report, "Model decision unavailable; ran deterministic fallback probe.", {});
  state.inspect = await observeInspect(client, report, "Fallback probe: inspect visible controls.");
  updateMissionCoverage(report, state, "Fallback inspection observation.");
  await executeExplorerCommand(
    client,
    report,
    "ui.scroll",
    { direction: "down" },
    "Fallback probe: scroll down."
  );
  state.summary = await observeSummary(client, report, "Fallback probe: observe after scrolling.");
  evaluateSummary(report, state.summary, state);
  updateMissionCoverage(report, state, "Fallback scrolled observation.");
  await executeExplorerCommand(
    client,
    report,
    "ui.scroll",
    { direction: "up" },
    "Fallback probe: scroll up."
  );
  state.summary = await observeSummary(client, report, "Fallback probe: final observation.");
  evaluateSummary(report, state.summary, state);
  updateMissionCoverage(report, state, "Fallback final observation.");
}

function shouldForceMoreExploration(action, stepIndex, minSteps) {
  return action.command === "finish" && stepIndex < minSteps;
}

export async function runAiExplorer(options = {}) {
  const env = options.env ?? process.env;
  const paths = getProjectPaths(env);
  const outputDir = options.outputDir ?? paths.outputDir;
  const log = options.log ?? console.error;
  const config = options.config ?? readAiExplorerConfig(env);
  const startedAt = new Date();
  const report = createExplorerReport({
    config: publicConfig(config),
    deviceName: env.IOS_DEVICE_NAME,
    startedAt: startedAt.toISOString(),
    udid: env.IOS_UDID
  });
  report.log = (message) => log(message);
  const client =
    options.client ??
    new JsonlExplorerClient({
      cwd: paths.wdioRoot,
      env,
      log
    });
  const state = {
    actionSignatures: new Map(),
    consecutiveModelFailures: 0,
    coverageInterventions: 0,
    failedSelectors: new Map(),
    findings: report.findings,
    inCoverageIntervention: false,
    inspect: undefined,
    labelSignatures: new Map(),
    blankScreenAbort: false,
    blankScreenStreak: 0,
    lastScreenKey: undefined,
    navBrokenAbort: false,
    offTargetStreak: 0,
    wrongAppAbort: false,
    loadingObservations: 0,
    mission: createMissionState(),
    needsCoverageIntervention: undefined,
    summary: undefined,
    triedSelectors: new Map()
  };
  const decisionProvider =
    options.decisionProvider ??
    (config.fakeModel
      ? createFakeDecisionProvider()
      : async (decisionState) => {
          let lastError;
          for (let attempt = 1; attempt <= 2; attempt += 1) {
            try {
              const response = await requestExplorerDecision({
                config,
                fetchFn: options.fetchFn,
                state: decisionState
              });
              log(`AI explorer model decision: ${response.rawContent.trim().slice(0, 500)}`);
              addStep(report, {
                kind: "model",
                command: "decision",
                reason: response.rawContent,
                usage: response.usage
              });
              return response.decision;
            } catch (error) {
              lastError = error;
              const details = modelFailureDetails(error);
              log(
                `AI explorer model decision attempt ${attempt} failed: ${details.error}`
              );
              addStep(report, {
                kind: "model-error",
                command: "decision",
                reason: `Model decision attempt ${attempt} failed.`,
                details
              });
            }
          }
          throw lastError;
        });

  try {
    log(
      `AI explorer starting with model ${config.model} at ${config.baseUrl}; budget ${config.stepLimit} steps / ${Math.round(config.timeoutMs / 1000)}s.`
    );
    client.start();

    const statusEvent = await executeExplorerCommand(
      client,
      report,
      "session.status",
      {},
      "Confirm explorer session."
    );
    report.deviceName = statusEvent.result?.deviceName ?? report.deviceName;
    report.udid = statusEvent.result?.udid ?? report.udid;

    if (statusEvent.result?.appState?.code === 4) {
      addStep(report, {
        kind: "activation-skip",
        command: "app.activate",
        reason:
          "Skipped activation because session.status already reported the configured app in foreground."
      });
      log(
        "AI explorer skipped app.activate because the configured app is already foreground."
      );
    } else {
      await executeExplorerCommand(
        client,
        report,
        "app.activate",
        {},
        "Bring the already-onboarded app to foreground."
      );
    }
    state.summary = await observeSummary(client, report, "Initial post-smoke UI summary.");
    evaluateSummary(report, state.summary, state);
    state.inspect = await observeInspect(client, report, "Initial post-smoke UI inspection.");
    updateMissionCoverage(report, state, "Initial post-smoke observation.");
    await dismissBlockingIntroIfPresent(client, report, state);
    addBlockingOnboardingFinding(report, state);
    const deadline = Date.now() + config.timeoutMs;
    await runInitialCoverageProbe(client, report, state);
    const warmupDeadline = Math.min(
      deadline,
      Date.now() + Math.floor(config.timeoutMs * WARMUP_BUDGET_FRACTION)
    );
    await runMissionWarmup(client, report, state, warmupDeadline);

    for (
      let stepIndex = 0;
      stepIndex < config.stepLimit &&
      Date.now() < deadline &&
      !state.blankScreenAbort &&
      !state.wrongAppAbort &&
      !state.navBrokenAbort;
      stepIndex += 1
    ) {
      let decision;
      try {
        log(`AI explorer asking model for step ${stepIndex + 1}/${config.stepLimit}.`);
        decision = await decisionProvider({
          availableSelectors: observedAutomationSelectors(state),
          currentScreen: currentScreenKey(state),
          findings: report.findings.map(({ severity, message }) => ({ severity, message })),
          failedSelectors: compactMap(state.failedSelectors),
          history: report.steps.slice(-12).map((step) => ({
            args: step.args,
            details: step.details,
            kind: step.kind,
            command: step.command,
            reason: step.reason
          })),
          inspect: compactInspect({ result: state.inspect }),
          knownSurfaces: publicKnownSurfaces(),
          minSteps: config.minSteps,
          missionStatus: missionStatus(state),
          stepIndex,
          stepLimit: config.stepLimit,
          summary: compactEvent({ result: state.summary }),
          triedSelectors: compactMap(state.triedSelectors),
          usedActions: compactMap(state.actionSignatures)
        });
        state.consecutiveModelFailures = 0;
      } catch (error) {
        state.consecutiveModelFailures += 1;
        addAdvisory(report, "Model decision request failed.", modelFailureDetails(error));
        await runFallbackProbe(client, report, state);
        if (state.consecutiveModelFailures >= MODEL_FAILURE_ABORT_THRESHOLD) {
          addFinding(
            report,
            "warning",
            `Model produced no usable decision ${state.consecutiveModelFailures} times in a row; ending exploration early.`,
            {}
          );
          report.completed = true;
          break;
        }
        continue;
      }

      const guard = evaluateExplorerAction(decision, {
        sessionBundleId: env.APP_BUNDLE_ID
      });
      if (!guard.allowed) {
        log(`AI explorer guardrail denied ${guard.action.command}: ${guard.reason}`);
        addStep(report, {
          kind: "guardrail",
          command: guard.action.command,
          args: guard.action.args,
          reason: guard.reason
        });
        continue;
      }

      const { action } = guard;
      if (shouldForceMoreExploration(action, stepIndex, config.minSteps)) {
        log("AI explorer model asked to finish early; collecting one more inspection.");
        state.inspect = await observeInspect(
          client,
          report,
          "Model wanted to finish before the minimum useful step count; inspect instead."
        );
        continue;
      }

      if (action.command === "finish") {
        log(`AI explorer finish requested: ${action.reason}`);
        addStep(report, {
          kind: "finish",
          command: "finish",
          reason: action.reason
        });
        report.completed = true;
        break;
      }

      const selector = selectorFromAction(action);
      if (selectorRequiresHomeSurface(selector) && !isCurrentHomeSurface(state)) {
        const homeReady = await ensureHomeSurface(
          client,
          report,
          state,
          `Return to Home before running ${action.command} ${selector}.`
        );
        if (!homeReady) {
          continue;
        }
        state.failedSelectors.delete(selector);
      }

      if (selector && state.failedSelectors.has(selector)) {
        log(`AI explorer skipped known failed selector: ${selector}`);
        addStep(report, {
          kind: "guardrail",
          command: action.command,
          args: action.args,
          reason: "Skipped selector because it already failed earlier in this run."
        });
        await runCoverageIntervention(
          client,
          report,
          state,
          `Known failed selector skipped: ${selector}`
        );
        continue;
      }

      const signature = stepSignature(action, currentScreenKey(state));
      state.actionSignatures.set(signature, (state.actionSignatures.get(signature) ?? 0) + 1);
      const actionRepeatCount = state.actionSignatures.get(signature);
      if (actionRepeatCount > repetitionLimit(action)) {
        log(`AI explorer skipped repeated action: ${signature}`);
        addStep(report, {
          kind: "guardrail",
          command: action.command,
          args: action.args,
          reason: "Skipped repeated action to avoid a loop."
        });
        await runCoverageIntervention(
          client,
          report,
          state,
          `Repeated action skipped: ${signature}`
        );
        continue;
      }
      recordAction(state, action);

      const navExpectedScreen =
        action.command === "ui.tap"
          ? expectedScreenForSelector(selectorFromAction(action))
          : undefined;

      let event;
      try {
        event = await executeExplorerCommand(
          client,
          report,
          action.command,
          action.args,
          action.reason
        );
      } catch (error) {
        const failedSelector = selectorFromAction(action);
        recordFailedSelector(state, failedSelector);
        const message = `Explorer command failed: ${action.command}${failedSelector ? ` ${failedSelector}` : ""}`;
        const details = {
          args: action.args,
          error: error instanceof Error ? error.message : String(error),
          selector: failedSelector,
          reason: action.reason
        };
        if (isSelectorResolutionError(error)) {
          addAdvisory(report, message, details);
        } else {
          addFinding(report, "warning", message, details);
        }
        state.summary = await observeSummary(client, report, "Observe after command failure.");
        evaluateSummary(report, state.summary, state);
        updateMissionCoverage(report, state, "Observation after command failure.");
        continue;
      }

      // A known navigation control must land on a specific screen. Let the
      // route transition settle before judging, so this is not racing the
      // animation (see NAV_SETTLE_MS).
      if (navExpectedScreen) {
        await settleAfterNavigation(client, report);
      }

      let summaryUpdated = false;
      if (action.command === "ui.inspect") {
        state.inspect = event.result;
      } else if (action.command === "ui.summary") {
        state.summary = event.result;
        summaryUpdated = true;
      } else {
        state.summary = await observeSummary(client, report, "Observe after model action.");
        summaryUpdated = true;
      }

      if (summaryUpdated) {
        evaluateSummary(report, state.summary, state);
      }
      updateMissionCoverage(report, state, "Observation after model action.");

      if (navExpectedScreen) {
        if (action.command !== "ui.inspect") {
          state.inspect = await observeInspect(
            client,
            report,
            "Inspect after navigation control."
          );
          updateMissionCoverage(report, state, "Observation after navigation control.");
        }
        const actualScreen = currentScreenKey(state);
        if (actualScreen !== navExpectedScreen && !state.navBrokenAbort) {
          state.navBrokenAbort = true;
          addFinding(
            report,
            "critical",
            `Navigation control ${selectorFromAction(action)} did not open ${navExpectedScreen} (now on ${actualScreen}); broken navigation.`,
            {
              selector: selectorFromAction(action),
              expected: navExpectedScreen,
              actual: actualScreen,
              summaryLabels: Array.isArray(state.summary?.labels)
                ? state.summary.labels.slice(0, 12)
                : []
            }
          );
        }
      }
      if (state.summary?.appState?.code !== 4 || isOffTarget(state.summary)) {
        const leftApp = isOffTarget(state.summary);
        if (leftApp) {
          addAdvisory(
            report,
            `Foreground left the target app (now in ${foregroundBundleId(state.summary)}); re-activating.`,
            { activeApp: state.summary?.activeApp }
          );
        }
        await recoverToApp(client, report);
        state.summary = await observeSummary(client, report, "Observe after app recovery.");
        evaluateSummary(report, state.summary, state);
        updateMissionCoverage(report, state, "Observation after app recovery.");
        if (isOffTarget(state.summary)) {
          state.offTargetStreak += 1;
          if (state.offTargetStreak >= OFF_TARGET_STREAK_ABORT && !state.wrongAppAbort) {
            state.wrongAppAbort = true;
            addFinding(
              report,
              "critical",
              `Explorer left the target app (now in ${foregroundBundleId(state.summary)}) and could not recover; run results are not trustworthy.`,
              { activeApp: state.summary?.activeApp }
            );
          }
        } else {
          state.offTargetStreak = 0;
        }
      }

      if (state.needsCoverageIntervention) {
        await runCoverageIntervention(
          client,
          report,
          state,
          state.needsCoverageIntervention
        );
        continue;
      }

      if (stepIndex % 4 === 3) {
        state.inspect = await observeInspect(client, report, "Periodic inspection after exploration steps.");
        updateMissionCoverage(report, state, "Periodic inspection observation.");
      }
    }

    // Degraded-surface verdict: a surface whose identity was observed but
    // whose body content markers never appeared anywhere in the whole run
    // (warmup deterministically visits each surface, so identity-seen is
    // reliable). Catches partial blanks the generic detector misses.
    for (const surface of KNOWN_SURFACES) {
      if (!Array.isArray(surface.contentLabels) || surface.contentLabels.length === 0) {
        continue;
      }
      const mission = state.mission.find((entry) => entry.id === surface.id);
      if (mission && mission.seen && !mission.contentSeen) {
        addFinding(
          report,
          "critical",
          `Surface "${surface.name}" was reached but its expected content never rendered (degraded/broken screen).`,
          { surface: surface.id, contentLabels: surface.contentLabels }
        );
      }
    }

    if (state.navBrokenAbort && !report.completed) {
      report.completed = true;
      log("AI explorer aborting: a navigation control did not open its destination.");
      addStep(report, {
        kind: "finish",
        command: "navigation-broken-abort",
        reason: "Run interrupted: a navigation control did not open its expected screen."
      });
    }

    if (state.blankScreenAbort && !report.completed) {
      report.completed = true;
      log("AI explorer aborting: a screen rendered with no content (blank/broken).");
      addStep(report, {
        kind: "finish",
        command: "blank-screen-abort",
        reason: "Run interrupted: a screen rendered with no content (blank/broken screen)."
      });
    }

    if (state.wrongAppAbort && !report.completed) {
      report.completed = true;
      log("AI explorer aborting: foreground left the target app and could not recover.");
      addStep(report, {
        kind: "finish",
        command: "wrong-app-abort",
        reason: "Run interrupted: foreground left the target app and could not recover."
      });
    }

    if (!report.completed) {
      report.completed = true;
      addStep(report, {
        kind: "finish",
        command: "budget",
        reason: "Explorer stopped at configured step or time budget."
      });
    }
  } catch (error) {
    log(`AI explorer infrastructure failure: ${error instanceof Error ? error.message : String(error)}`);
    report.infrastructureFailure = true;
    addFinding(report, "critical", "AI explorer infrastructure failed before completing.", {
      error: error instanceof Error ? error.message : String(error)
    });
  } finally {
    await client.shutdown().catch((error) => {
      addAdvisory(report, "Failed to shut down explorer session cleanly.", {
        error: error instanceof Error ? error.message : String(error)
      });
    });

    report.durationMs = Date.now() - startedAt.getTime();
    report.knownSurfaces = publicKnownSurfaces();
    report.mission = missionStatus(state);
    report.summary = `AI explorer finished with status ${deriveReportStatus(report)} after ${report.steps.length} recorded steps.`;
    report.artifacts = await writeExplorerReports(report, outputDir);
    delete report.log;
    log(`AI explorer report written: ${report.artifacts.markdownPath}`);
  }

  return report;
}
