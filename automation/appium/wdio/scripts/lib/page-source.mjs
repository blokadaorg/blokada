export function extractAttributeValues(source, attributeName) {
  const matcher = new RegExp(`${attributeName}="([^"]+)"`, "g");
  const values = [];
  let match;
  while ((match = matcher.exec(source)) != null) {
    values.push(match[1]);
  }
  return values;
}

export function listLabels(source, limit = 40) {
  const seen = new Set();
  const values = [
    ...extractAttributeValues(source, "label"),
    ...extractAttributeValues(source, "name"),
    ...extractAttributeValues(source, "value")
  ];

  for (const value of values) {
    const trimmed = value.trim();
    if (!trimmed || trimmed.length > 80 || trimmed.startsWith("XCUIElementType")) {
      continue;
    }
    seen.add(trimmed);
    if (seen.size >= limit) {
      break;
    }
  }

  return [...seen];
}

function summarizeAttributes(rawAttributes) {
  const summary = [];
  for (const key of ["name", "label", "value", "visible", "enabled"]) {
    const match = rawAttributes.match(new RegExp(`${key}="([^"]*)"`, "i"));
    if (match?.[1]) {
      summary.push(`${key}="${match[1]}"`);
    }
  }
  return summary.join(" ");
}

export function buildTreeLines(source, limit = 80) {
  const lines = [];
  const tagMatcher = /<(\/?)(XCUIElementType[^\s/>]+)([^>]*?)(\/?)>/g;
  let depth = 0;
  let match;

  while ((match = tagMatcher.exec(source)) != null) {
    const [, closing, elementType, rawAttributes, selfClosing] = match;
    if (closing) {
      depth = Math.max(0, depth - 1);
      continue;
    }

    const attributes = summarizeAttributes(rawAttributes);
    lines.push(`${"  ".repeat(depth)}${elementType}${attributes ? ` ${attributes}` : ""}`);
    if (lines.length >= limit) {
      break;
    }

    if (!selfClosing) {
      depth += 1;
    }
  }

  return lines;
}
