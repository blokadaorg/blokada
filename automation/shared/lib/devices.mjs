import { execSync } from "node:child_process";
import readline from "node:readline";

const XCDEVICE_REGEX =
  /^(?<name>.+?)\s+\[(?<udid>[0-9A-F-]{4,})\]\s+\((?<os>.+?)\)(?:\s+\((?<state>.+)\))?$/i;
const XCTRACE_REGEX =
  /^\s*(?<name>.+?)\s*\((?<os>[^()]+)\)\s*\((?<udid>[0-9A-F-]{4,})\)(?:\s*\((?<state>[^()]+)\))?/i;

export function parseDevices(output, regex) {
  const devices = [];
  const seen = new Set();

  for (const line of output.split("\n")) {
    const match = line.match(regex);
    if (!match?.groups) {
      continue;
    }

    const { name, os, udid, state } = match.groups;
    if (!udid || seen.has(udid)) {
      continue;
    }

    seen.add(udid);
    devices.push({
      name: name.trim(),
      os: os.trim(),
      udid: udid.trim(),
      state: state?.trim() ?? ""
    });
  }

  return devices;
}

export function filterConnectedDevices(devices) {
  return devices.filter((device) => {
    const state = (device.state ?? "").toLowerCase();
    const name = (device.name ?? "").toLowerCase();
    const os = (device.os ?? "").toLowerCase();
    const isConnected =
      state === "" || (state.includes("connected") && !state.includes("disconnected"));
    const isSupportedPlatform =
      !name.includes("watch") &&
      !name.includes("vision") &&
      !name.includes("tv") &&
      !os.includes("watchos") &&
      !os.includes("visionos") &&
      !os.includes("tvos");

    return isConnected && isSupportedPlatform;
  });
}

export function readDeviceList(exec = execSync) {
  try {
    const xcdevice = exec("xcrun xcdevice list 2>/dev/null", {
      encoding: "utf8"
    });
    const parsed = parseDevices(xcdevice, XCDEVICE_REGEX);
    if (parsed.length > 0) {
      return parsed;
    }
  } catch (_) {
    // Fall back to xctrace below.
  }

  try {
    const xctrace = exec("xcrun xctrace list devices 2>/dev/null", {
      encoding: "utf8"
    });
    return parseDevices(xctrace, XCTRACE_REGEX);
  } catch (_) {
    return [];
  }
}

export function pickNamedDevice(devices, requestedName) {
  const normalized = requestedName.trim().toLowerCase();
  if (!normalized) {
    return undefined;
  }

  const exact = devices.find(
    (device) => device.name.toLowerCase() === normalized
  );
  if (exact) {
    return exact;
  }

  return devices.find((device) =>
    device.name.toLowerCase().includes(normalized)
  );
}

export async function promptForDevice(devices, input = process.stdin, output = process.stderr) {
  const rl = readline.createInterface({ input, output });

  try {
    rl.write("Select iOS device:\n");
    devices.forEach((device, index) => {
      const state = device.state ? ` (${device.state})` : "";
      rl.write(`  [${index + 1}] ${device.name} – iOS ${device.os}${state}\n`);
    });
    rl.write("Enter choice number: ");

    const answer = await new Promise((resolve) => rl.question("", resolve));
    const selectedIndex = Number.parseInt(answer, 10) - 1;
    if (
      Number.isNaN(selectedIndex) ||
      selectedIndex < 0 ||
      selectedIndex >= devices.length
    ) {
      throw new Error("Invalid selection.");
    }

    return devices[selectedIndex];
  } finally {
    rl.close();
  }
}

export async function resolveTargetDevice(options = {}) {
  const {
    devices = filterConnectedDevices(readDeviceList()),
    requestedName = process.env.IOS_DEVICE_NAME ?? "",
    requestedUdid = process.env.IOS_UDID ?? "",
    autoSelectFirst = (process.env.IOS_AUTO_SELECT_FIRST ?? "").trim() === "1" ||
      (process.env.CI ?? "").trim() === "true",
    interactive = process.stdin.isTTY,
    prompt = promptForDevice
  } = options;

  if (devices.length === 0) {
    throw new Error("No physical iOS devices detected. Set IOS_UDID manually and retry.");
  }

  const normalizedUdid = requestedUdid.trim();
  if (normalizedUdid) {
    const matchingDevice = devices.find((device) => device.udid === normalizedUdid);
    if (matchingDevice) {
      return matchingDevice;
    }

    return {
      name: requestedName.trim() || "Unknown device",
      os: "unknown",
      udid: normalizedUdid,
      state: ""
    };
  }

  const normalizedName = requestedName.trim();
  if (normalizedName) {
    const matchingDevice = pickNamedDevice(devices, normalizedName);
    if (!matchingDevice) {
      throw new Error(
        `No connected device matches IOS_DEVICE_NAME='${requestedName}'.`
      );
    }
    return matchingDevice;
  }

  if (devices.length === 1 || !interactive || autoSelectFirst) {
    return devices[0];
  }

  return prompt(devices);
}

export function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}
