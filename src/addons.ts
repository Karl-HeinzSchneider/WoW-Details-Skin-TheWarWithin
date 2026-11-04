import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, resolve } from "node:path";
import { ROOT } from "./config.js";

export interface AddonDirectory {
  name: string;
  path: string;
  toc: string;
}

/** Direct child directories that contain a same-named WoW addon manifest. */
export function addonDirectories(): AddonDirectory[] {
  return readdirSync(ROOT, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
    .map((entry) => {
      const path = resolve(ROOT, entry.name);
      return { name: entry.name, path, toc: resolve(path, `${entry.name}.toc`) };
    })
    .filter((addon) => existsSync(addon.toc))
    .sort((a, b) => a.name.localeCompare(b.name));
}

export function addonVersion(addon: AddonDirectory): string {
  const match = /^## Version:\s*(.+)$/m.exec(readFileSync(addon.toc, "utf-8"));
  return match?.[1]?.trim() || "dev";
}

export function walkFiles(root: string): string[] {
  const files: string[] = [];
  const walk = (dir: string) => {
    for (const name of readdirSync(dir).sort()) {
      const path = resolve(dir, name);
      if (statSync(path).isDirectory()) walk(path);
      else files.push(path);
    }
  };
  walk(root);
  return files;
}

export function requireAddons(): AddonDirectory[] {
  const addons = addonDirectories();
  if (addons.length === 0) throw new Error(`no addon directories found under ${basename(ROOT)}`);
  return addons;
}
