const ALLOWED_COMMANDS = new Set([
  "app.activate",
  "finish",
  "ui.back",
  "ui.exists",
  "ui.inspect",
  "ui.labels",
  "ui.read",
  "ui.screenshot",
  "ui.scroll",
  "ui.summary",
  "ui.swipe",
  "ui.tap",
  "ui.tree",
  "ui.wait"
]);

const RISKY_TEXT_PATTERNS = [
  /\bapp store\b/i,
  /\bbrowser\b/i,
  /\bcancel subscription\b/i,
  /\bdelete\b/i,
  /\berase\b/i,
  /\bexternal\b/i,
  /\blog\s*out\b/i,
  /\blogout\b/i,
  /\bmail\b/i,
  /\bpayment\b/i,
  /\bpurchase\b/i,
  /\bremove account\b/i,
  /\breset\b/i,
  /\brestore purchase/i,
  /\bsafari\b/i,
  /\bsign\s*out\b/i,
  /\bsubscribe\b/i,
  /\bsubscription\b/i,
  /\btrial\b/i
];

function asObject(value) {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value
    : {};
}

function normalizeAction(decision) {
  const root = asObject(decision);
  const nested = asObject(root.action);
  const source = nested.command ? nested : root;
  return {
    command: String(source.command ?? "").trim(),
    args: asObject(source.args),
    confidence: Number(source.confidence ?? root.confidence ?? 0),
    expected: String(source.expected ?? root.expected ?? "").trim(),
    reason: String(source.reason ?? root.reason ?? "").trim()
  };
}

function containsRiskyText(...values) {
  const text = values
    .map((value) => {
      if (value == null) {
        return "";
      }
      return typeof value === "string" ? value : JSON.stringify(value);
    })
    .join("\n");

  return RISKY_TEXT_PATTERNS.some((pattern) => pattern.test(text));
}

function normalizeDirection(value, fallback = "down") {
  const direction = String(value ?? fallback).trim().toLowerCase();
  if (["up", "down", "left", "right"].includes(direction)) {
    return direction;
  }
  return fallback;
}

function normalizeLimit(value, fallback, max) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.min(parsed, max);
}

function normalizeSelector(args, command) {
  const selector = String(args.selector ?? "").trim();
  if (!selector) {
    throw new Error(`${command} requires args.selector.`);
  }
  if (
    !(
      selector.startsWith("~") ||
      selector.startsWith("-ios predicate string:") ||
      selector.startsWith("-ios class chain:") ||
      selector.startsWith("//")
    )
  ) {
    throw new Error(
      `${command} selector must be an accessibility id (~...), iOS predicate/class chain, or XPath selector.`
    );
  }
  return selector;
}

function normalizeAppArgs(args, sessionBundleId) {
  const target = String(args.target ?? "").trim().toLowerCase();
  const bundleId = String(args.bundleId ?? "").trim();
  if (target && !["six", "blokada", "blokada6", "blokada-6"].includes(target)) {
    throw new Error(`app.activate target '${target}' is outside the initial explorer scope.`);
  }
  if (bundleId && bundleId !== sessionBundleId) {
    throw new Error(`app.activate bundleId '${bundleId}' is outside the current app.`);
  }
  return target ? { target } : bundleId ? { bundleId } : {};
}

function sanitizeArgs(action, context) {
  const { args, command } = action;
  switch (command) {
    case "finish":
      return {};
    case "app.activate":
      return normalizeAppArgs(args, context.sessionBundleId);
    case "ui.summary":
      return {
        compact: args.compact === true,
        interactiveOnly: args.interactiveOnly === true,
        limit: normalizeLimit(args.limit, 25, 40),
        visibleOnly: args.visibleOnly !== false
      };
    case "ui.inspect":
      return {
        compact: args.compact !== false,
        elements: args.elements !== false,
        interactiveOnly: args.interactiveOnly === true,
        labels: args.labels !== false,
        limit: normalizeLimit(args.limit, 35, 60),
        tree: args.tree !== false,
        visibleOnly: args.visibleOnly !== false
      };
    case "ui.labels":
    case "ui.tree":
      return {
        compact: args.compact !== false,
        interactiveOnly: args.interactiveOnly === true,
        limit: normalizeLimit(args.limit, 35, 60),
        visibleOnly: args.visibleOnly !== false
      };
    case "ui.scroll":
      return { direction: normalizeDirection(args.direction, "down") };
    case "ui.swipe":
      return { direction: normalizeDirection(args.direction, "up") };
    case "ui.tap":
      return { selector: normalizeSelector(args, command) };
    case "ui.read":
    case "ui.exists":
    case "ui.wait":
      return {
        selector: normalizeSelector(args, command),
        ...(command === "ui.wait"
          ? { timeoutMs: normalizeLimit(args.timeoutMs, 5000, 15000) }
          : {})
      };
    case "ui.screenshot":
      return {
        name: String(args.name ?? `ai-explorer-${Date.now()}`).replace(/[^A-Za-z0-9._-]+/g, "-")
      };
    case "ui.back":
      return {};
    default:
      throw new Error(`Unsupported explorer command '${command}'.`);
  }
}

export function evaluateExplorerAction(decision, context = {}) {
  const action = normalizeAction(decision);
  if (!ALLOWED_COMMANDS.has(action.command)) {
    return {
      allowed: false,
      action,
      reason: `Command '${action.command || "(empty)"}' is not in the allowlist.`
    };
  }

  if (containsRiskyText(action.reason, action.expected, action.args)) {
    return {
      allowed: false,
      action,
      reason: "Action text matched a risky purchase/account/external-flow guardrail."
    };
  }

  try {
    return {
      allowed: true,
      action: {
        ...action,
        args: sanitizeArgs(action, context)
      }
    };
  } catch (error) {
    return {
      allowed: false,
      action,
      reason: error instanceof Error ? error.message : String(error)
    };
  }
}
