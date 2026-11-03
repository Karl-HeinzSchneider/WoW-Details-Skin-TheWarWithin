import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { basename, relative, resolve } from "node:path";
import { addonVersion, requireAddons } from "./addons.js";
import { packageName, ROOT } from "./config.js";
import { createZip, directoryEntries, fileNamePart } from "./zip.js";

const addons = requireAddons();
const versions = [...new Set(addons.map(addonVersion))];
const version = versions.length === 1 ? versions[0]! : "mixed";
const outputDir = resolve(ROOT, "dist");
const output = resolve(outputDir, `${packageName()}-${fileNamePart(version)}.zip`);

mkdirSync(outputDir, { recursive: true });
rmSync(output, { force: true });

// Guidance for Claude Code in the repository, not part of the addon.
const isClaudeMd = (path: string) => basename(path).toLowerCase() === "claude.md";

const entries = directoryEntries(
  ROOT,
  addons.map((addon) => addon.name),
  (path) => !isClaudeMd(path),
);

writeFileSync(output, createZip(entries));
console.log(`wrote ${relative(ROOT, output)} (${addons.map((addon) => addon.name).join(", ")})`);
