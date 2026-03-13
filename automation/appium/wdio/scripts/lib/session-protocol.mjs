function isPlainObject(value) {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

export function parseJsonlRequest(line) {
  const trimmed = line.trim();
  if (!trimmed) {
    return undefined;
  }

  const parsed = JSON.parse(trimmed);
  if (!isPlainObject(parsed)) {
    throw new Error("Request must be a JSON object.");
  }

  const { id, command, args } = parsed;
  if (typeof id !== "string" && typeof id !== "number") {
    throw new Error("Request 'id' must be a string or number.");
  }

  if (typeof command !== "string" || command.trim() === "") {
    throw new Error("Request 'command' must be a non-empty string.");
  }

  if (args != null && !isPlainObject(args)) {
    throw new Error("Request 'args' must be an object when provided.");
  }

  return {
    id,
    command,
    args: args ?? {}
  };
}

export function createAck(request) {
  return {
    id: request.id,
    type: "ack",
    ok: true,
    command: request.command
  };
}

export function createResult(request, payload = {}) {
  return {
    id: request.id,
    type: "result",
    ok: true,
    command: request.command,
    ...payload
  };
}

export function createDone(request, payload = {}) {
  return {
    id: request.id,
    type: "done",
    ok: true,
    command: request.command,
    ...payload
  };
}

export function createError(request, error) {
  return {
    id: request?.id ?? null,
    type: "error",
    ok: false,
    command: request?.command ?? "unknown",
    error: error instanceof Error ? error.message : String(error)
  };
}
