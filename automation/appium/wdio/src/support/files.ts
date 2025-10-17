import { mkdirSync } from "node:fs";
import { dirname } from "node:path";

export const ensureDirectory = (path: string): void => {
  const dir = dirname(path);
  mkdirSync(dir, { recursive: true });
};
