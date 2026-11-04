import { spawnSync } from "node:child_process";
import { relative } from "node:path";
import { requireAddons, walkFiles } from "./addons.js";
import { ROOT } from "./config.js";

const files = requireAddons()
  .flatMap((addon) => walkFiles(addon.path))
  .filter((path) => path.endsWith(".lua"));
const failures: string[] = [];

for (const file of files) {
  const result = spawnSync("luac", ["-p", file], { encoding: "utf-8" });
  if (result.error) {
    if ((result.error as NodeJS.ErrnoException).code === "ENOENT") {
      throw new Error("luac was not found; install a Lua 5.1 compiler to run check:lua");
    }
    throw result.error;
  }
  if (result.status !== 0) failures.push(`${relative(ROOT, file)}: ${(result.stderr || result.stdout).trim()}`);
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(`Lua syntax OK (${files.length} files)`);
