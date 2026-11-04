import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** Repository layout, relative to this file (src/config.ts). */
export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/**
 * Every value of the client's [TextLocale] TOC path variable. The client loads a
 * `locales\[TextLocale]\<file>` entry for its own language only and warns when that file is
 * missing, so check:addons requires it for all of them.
 */
export const CLIENT_LOCALES = [
  "enUS",
  "enGB",
  "deDE",
  "esES",
  "esMX",
  "frFR",
  "itIT",
  "koKR",
  "ptBR",
  "ruRU",
  "zhCN",
  "zhTW",
] as const;

/** `package-as` in .pkgmeta: the name of the packaged zip and of the main addon. */
export function packageName(): string {
  const pkgmeta = readFileSync(resolve(ROOT, ".pkgmeta"), "utf-8");
  const name = /^package-as:\s*(\S+)/m.exec(pkgmeta)?.[1];
  if (!name) throw new Error(".pkgmeta has no package-as line");
  return name;
}
