function decodeXmlValue(value) {
  return String(value)
    .replaceAll("&quot;", "\"")
    .replaceAll("&apos;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&amp;", "&");
}

function extractRawAttributes(source, attributeName) {
  const matcher = new RegExp(`${attributeName}="([^"]*)"`, "g");
  const values = [];
  let match;
  while ((match = matcher.exec(source)) != null) {
    values.push(match[1]);
  }
  return values;
}

export function extractAttributeValues(source, attributeName) {
  return extractRawAttributes(source, attributeName).map(decodeXmlValue);
}

function normalizeInspectOptions(options = {}) {
  const rawTerms = Array.isArray(options.matchText)
    ? options.matchText
    : options.matchText == null
      ? []
      : [options.matchText];

  return {
    compact: options.compact === true,
    interactiveOnly: options.interactiveOnly === true,
    visibleOnly: options.visibleOnly === true,
    matchTerms: rawTerms
      .map((term) => String(term).trim().toLowerCase())
      .filter((term) => term.length > 0)
  };
}

function matchesTerms(values, matchTerms) {
  if (matchTerms.length === 0) {
    return true;
  }

  const normalizedValues = values
    .map((value) => String(value ?? "").trim().toLowerCase())
    .filter((value) => value.length > 0);

  return matchTerms.some((term) =>
    normalizedValues.some((value) => value.includes(term))
  );
}

function summarizeAttributes(rawAttributes) {
  const summary = [];
  for (const key of ["name", "label", "value", "visible", "enabled"]) {
    const match = rawAttributes.match(new RegExp(`${key}="([^"]*)"`, "i"));
    if (match?.[1]) {
      summary.push(`${key}="${decodeXmlValue(match[1])}"`);
    }
  }
  return summary.join(" ");
}

function extractTagAttributes(rawAttributes) {
  const attributes = {};
  const attributeMatcher = /([A-Za-z0-9:_-]+)="([^"]*)"/g;
  let match;

  while ((match = attributeMatcher.exec(rawAttributes)) != null) {
    attributes[match[1]] = decodeXmlValue(match[2]);
  }

  return attributes;
}

function normalizeBooleanAttribute(value) {
  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  if (["true", "1", "yes"].includes(normalized)) {
    return true;
  }
  if (["false", "0", "no"].includes(normalized)) {
    return false;
  }
  return undefined;
}

function parseNodeEntries(source) {
  const entries = [];
  const tagMatcher = /<(\/?)(XCUIElementType[^\s/>]+)([^>]*?)(\/?)>/g;
  let depth = 0;
  let match;

  while ((match = tagMatcher.exec(source)) != null) {
    const [, closing, elementType, rawAttributes, selfClosing] = match;
    if (closing) {
      depth = Math.max(0, depth - 1);
      continue;
    }

    const attributes = extractTagAttributes(rawAttributes);
    entries.push({
      attributes,
      depth,
      line: `${"  ".repeat(depth)}${elementType}${rawAttributes.trim() ? ` ${summarizeAttributes(rawAttributes)}` : ""}`,
      summary: summarizeAttributes(rawAttributes),
      textValues: [attributes.name, attributes.label, attributes.value],
      type: elementType
    });

    if (!selfClosing) {
      depth += 1;
    }
  }

  return entries;
}

function isGenericContainerType(elementType) {
  return elementType === "XCUIElementTypeOther" || elementType === "XCUIElementTypeWindow";
}

function isInteractiveEntry(entry) {
  const interactiveTypes = new Set([
    "XCUIElementTypeButton",
    "XCUIElementTypeCell",
    "XCUIElementTypeSearchField",
    "XCUIElementTypeSecureTextField",
    "XCUIElementTypeSlider",
    "XCUIElementTypeSwitch",
    "XCUIElementTypeTextField"
  ]);

  return (
    interactiveTypes.has(entry.type) ||
    normalizeBooleanAttribute(entry.attributes.hittable) === true
  );
}

function isMeaningfulEntry(entry) {
  if (!isGenericContainerType(entry.type)) {
    return true;
  }

  return (
    entry.textValues.some((value) => typeof value === "string" && value.trim().length > 0) ||
    isInteractiveEntry(entry)
  );
}

function isVisibleEntry(entry) {
  return normalizeBooleanAttribute(entry.attributes.visible) !== false;
}

function filterTreeEntries(entries, options) {
  const { compact, interactiveOnly, visibleOnly, matchTerms } = normalizeInspectOptions(options);
  const eligibleEntries = entries.filter((entry) => {
    if (compact && !isMeaningfulEntry(entry)) {
      return false;
    }
    if (visibleOnly && !isVisibleEntry(entry)) {
      return false;
    }
    return true;
  });

  if (matchTerms.length === 0 && !interactiveOnly) {
    return eligibleEntries;
  }

  const included = new Set();
  const ancestors = [];

  for (const entry of eligibleEntries) {
    ancestors[entry.depth] = entry;
    ancestors.length = entry.depth + 1;

    if (interactiveOnly && !isInteractiveEntry(entry)) {
      continue;
    }
    if (!matchesTerms(entry.textValues, matchTerms)) {
      continue;
    }

    for (const ancestor of ancestors) {
      if (ancestor) {
        included.add(ancestor);
      }
    }
  }

  return eligibleEntries.filter((entry) => included.has(entry));
}

export function listLabels(source, limit = 40, options = {}) {
  const seen = new Set();
  const normalizedOptions = normalizeInspectOptions(options);
  const values =
    normalizedOptions.visibleOnly || normalizedOptions.interactiveOnly || normalizedOptions.compact
      ? parseNodeEntries(source)
          .filter((entry) => {
            if (normalizedOptions.visibleOnly && !isVisibleEntry(entry)) {
              return false;
            }
            if (normalizedOptions.interactiveOnly && !isInteractiveEntry(entry)) {
              return false;
            }
            if (normalizedOptions.compact && !isMeaningfulEntry(entry)) {
              return false;
            }
            return true;
          })
          .flatMap((entry) => [entry.attributes.label, entry.attributes.name, entry.attributes.value])
      : [
          ...extractAttributeValues(source, "label"),
          ...extractAttributeValues(source, "name"),
          ...extractAttributeValues(source, "value")
        ];

  for (const value of values) {
    const trimmed = String(value ?? "").trim();
    if (!trimmed || trimmed.length > 80 || trimmed.startsWith("XCUIElementType")) {
      continue;
    }
    if (!matchesTerms([trimmed], normalizedOptions.matchTerms)) {
      continue;
    }
    seen.add(trimmed);
    if (seen.size >= limit) {
      break;
    }
  }

  return [...seen];
}

export function buildTreeLines(source, limit = 80, options = {}) {
  return filterTreeEntries(parseNodeEntries(source), options)
    .slice(0, limit)
    .map((entry) => entry.line);
}

export function listVisibleElements(source, limit = 40, options = {}) {
  const elements = [];
  const normalizedOptions = normalizeInspectOptions(options);

  for (const entry of parseNodeEntries(source)) {
    const { attributes, type } = entry;
    if (!isVisibleEntry(entry)) {
      continue;
    }
    if (normalizedOptions.compact && !isMeaningfulEntry(entry)) {
      continue;
    }
    if (normalizedOptions.interactiveOnly && !isInteractiveEntry(entry)) {
      continue;
    }
    if (!matchesTerms(entry.textValues, normalizedOptions.matchTerms)) {
      continue;
    }

    const element = {
      type
    };
    for (const key of [
      "name",
      "label",
      "value",
      "visible",
      "enabled",
      "hittable",
      "focused",
      "selected"
    ]) {
      if (attributes[key] != null && attributes[key] !== "") {
        element[key] = attributes[key];
      }
    }

    elements.push(element);
    if (elements.length >= limit) {
      break;
    }
  }

  return elements;
}

export function getApplicationIdentity(source) {
  const match = source.match(/<XCUIElementTypeApplication([^>]*)>/i);
  if (!match) {
    return undefined;
  }

  const attributes = extractTagAttributes(match[1]);
  return {
    type: "XCUIElementTypeApplication",
    name: attributes.name,
    label: attributes.label,
    value: attributes.value
  };
}
