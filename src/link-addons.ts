import { existsSync, lstatSync, realpathSync, symlinkSync } from "node:fs";
import { resolve } from "node:path";
import { requireAddons } from "./addons.js";

const destination = process.argv[2] ?? process.env.WOW_ADDONS_DIR;
if (!destination) {
  console.error('usage: npm run dev:link -- "<World of Warcraft>/Interface/AddOns"\nOr set WOW_ADDONS_DIR.');
  process.exit(2);
}

const addonsDir = resolve(destination);
if (!existsSync(addonsDir) || !lstatSync(addonsDir).isDirectory()) {
  console.error(`addon directory does not exist: ${addonsDir}`);
  process.exit(2);
}

for (const addon of requireAddons()) {
  const target = resolve(addonsDir, addon.name);
  if (existsSync(target)) {
    if (realpathSync(target) === realpathSync(addon.path)) {
      console.log(`linked: ${addon.name}`);
      continue;
    }
    console.error(`refusing to replace existing path: ${target}`);
    process.exitCode = 1;
    continue;
  }
  symlinkSync(addon.path, target, process.platform === "win32" ? "junction" : "dir");
  console.log(`linked ${target} -> ${addon.path}`);
}
