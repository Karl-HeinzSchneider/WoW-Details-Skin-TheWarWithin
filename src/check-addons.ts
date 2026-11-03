import { existsSync, readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { requireAddons } from "./addons.js";
import { CLIENT_LOCALES, packageName, ROOT } from "./config.js";

const core = packageName();
const addons = requireAddons();
const names = new Set(addons.map((addon) => addon.name));
const failures: string[] = [];
const dependencies = new Map<string, string[]>();

if (!names.has(core)) failures.push(`missing the main addon ${core}/${core}.toc (package-as in .pkgmeta)`);

for (const addon of addons) {
  const toc = readFileSync(addon.toc, "utf-8");
  const dependencyLine = /^## (?:Dependencies|RequiredDeps):\s*(.*)$/m.exec(toc)?.[1] ?? "";
  const deps = dependencyLine
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  dependencies.set(
    addon.name,
    deps.filter((dependency) => names.has(dependency)),
  );

  // A companion addon (<Core>_Something) in the same repo is loaded on top of the main one.
  if (addon.name.startsWith(`${core}_`) && !deps.includes(core)) {
    failures.push(`${relative(ROOT, addon.toc)}: companion addons must depend on ${core}`);
  }

  for (const line of toc.split(/\r?\n/)) {
    const entry = line.trim();
    if (!entry || entry.startsWith("#")) continue;
    const path = resolve(dirname(addon.toc), entry.replace(/\\/g, "/"));
    // The client loads a [TextLocale] entry for its own language only and warns when that file is
    // missing, so it has to exist for every client language.
    const locales: string[] = path.includes("[TextLocale]") ? [...CLIENT_LOCALES] : [""];
    for (const locale of locales) {
      if (!existsSync(path.replaceAll("[TextLocale]", locale)))
        failures.push(`${relative(ROOT, addon.toc)}: missing load entry ${entry}${locale && ` for ${locale}`}`);
    }
  }
}

const visiting = new Set<string>();
const visited = new Set<string>();
const visit = (name: string, path: string[]) => {
  if (visiting.has(name)) {
    failures.push(`addon dependency cycle: ${[...path, name].join(" -> ")}`);
    return;
  }
  if (visited.has(name)) return;
  visiting.add(name);
  for (const dependency of dependencies.get(name) ?? []) visit(dependency, [...path, name]);
  visiting.delete(name);
  visited.add(name);
};
for (const addon of addons) visit(addon.name, []);

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(`Addons OK (${addons.map((addon) => addon.name).join(", ")})`);
