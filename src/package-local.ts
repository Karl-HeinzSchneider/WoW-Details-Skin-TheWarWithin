// `npm run package:local [-- <release.sh options>]`: runs the BigWigs packager — the script the
// GitHub release workflows run — on the local checkout, never uploading. The addon folders and the
// zip land in .release/. On Windows it needs Git for Windows (its bash and coreutils); Git's bash
// has no `zip`, so the packager is then told to skip the zip and this script writes it instead.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { relative, resolve } from "node:path";
import { packageName, ROOT } from "./config.js";
import { createZip, directoryEntries, fileNamePart } from "./zip.js";

// Same major version as `BigWigsMods/packager@v2` in .github/workflows/package.yml.
const PACKAGER_URL = "https://raw.githubusercontent.com/BigWigsMods/packager/v2/release.sh";
const PACKAGE_NAME = packageName();
const script = resolve(ROOT, ".cache", "packager", "release.sh");
const releaseDir = resolve(ROOT, ".release");

async function downloadPackager(): Promise<void> {
  try {
    const response = await fetch(PACKAGER_URL);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    mkdirSync(resolve(script, ".."), { recursive: true });
    writeFileSync(script, Buffer.from(await response.arrayBuffer()));
  } catch (error) {
    if (!existsSync(script)) throw new Error(`could not download ${PACKAGER_URL}: ${String(error)}`);
    console.warn(`could not update the packager (${String(error)}), using the cached copy`);
  }
}

// On Windows, `bash` on the PATH is usually WSL's; use the one that ships with Git for Windows.
function findBash(): string {
  if (process.platform !== "win32") return "bash";
  const execPath = spawnSync("git", ["--exec-path"], { encoding: "utf-8" }).stdout?.trim(); // <Git>/mingw64/libexec/git-core
  const bash = execPath && resolve(execPath, "..", "..", "..", "bin", "bash.exe");
  if (!bash || !existsSync(bash)) throw new Error("bash.exe from Git for Windows not found (is git on the PATH?)");
  return bash;
}

const posix = (path: string) => path.replace(/\\/g, "/");

await downloadPackager();
const bash = findBash();
const userArgs = process.argv.slice(2);
const hasZip = spawnSync(bash, ["-c", "command -v zip"], { stdio: "ignore" }).status === 0;
const zipOurselves = !hasZip && !userArgs.includes("-z");
const args = ["-d", ...(zipOurselves ? ["-z"] : []), ...userArgs];

const result = spawnSync(bash, [posix(script), ...args], { cwd: ROOT, stdio: "inherit" });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);

if (zipOurselves) {
  const addons = readdirSync(releaseDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && existsSync(resolve(releaseDir, entry.name, `${entry.name}.toc`)))
    .map((entry) => entry.name)
    .sort();
  const toc = readFileSync(resolve(releaseDir, PACKAGE_NAME, `${PACKAGE_NAME}.toc`), "utf-8");
  const version = /^## Version:\s*(.+)$/m.exec(toc)?.[1] ?? "dev";
  const output = resolve(releaseDir, `${PACKAGE_NAME}-${fileNamePart(version)}.zip`);
  writeFileSync(output, createZip(directoryEntries(releaseDir, addons)));
  console.log(`wrote ${relative(ROOT, output)} (${addons.join(", ")})`);
}
