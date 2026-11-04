import { readFileSync } from "node:fs";
import { relative, resolve, sep } from "node:path";
import { walkFiles } from "./addons.js";

export interface ZipEntry {
  name: string;
  data: Buffer;
}

/** Every file below `root/<dir>` for each dir, named `<dir>/<path>` with forward slashes. */
export function directoryEntries(root: string, dirs: string[], keep = (_path: string) => true): ZipEntry[] {
  return dirs.flatMap((dir) => {
    const base = resolve(root, dir);
    return walkFiles(base)
      .filter(keep)
      .map((path) => ({
        name: `${dir}/${relative(base, path).split(sep).join("/")}`,
        data: readFileSync(path),
      }));
  });
}

// The TOC version may carry WoW color codes (`|cff8080ff…|r`), and a file name can't hold `|` or
// the other characters Windows forbids.
export function fileNamePart(value: string): string {
  const plain = value.replace(/\|c[0-9a-f]{8}|\|r/gi, "");
  return plain.replace(/[<>:"/\\|?*\x00-\x1f]/g, "").trim() || "dev";
}

/** A stored (uncompressed) zip with fixed timestamps, so the same input gives the same bytes. */
export function createZip(entries: ZipEntry[]): Buffer {
  const localParts: Buffer[] = [];
  const centralParts: Buffer[] = [];
  let offset = 0;

  for (const entry of entries) {
    const name = Buffer.from(entry.name, "utf-8");
    const crc = crc32(entry.data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6);
    local.writeUInt16LE(0, 8);
    local.writeUInt16LE(0x0021, 12); // 1980-01-01, for deterministic archives
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(entry.data.length, 18);
    local.writeUInt32LE(entry.data.length, 22);
    local.writeUInt16LE(name.length, 26);
    localParts.push(local, name, entry.data);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(0, 10);
    central.writeUInt16LE(0x0021, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(entry.data.length, 20);
    central.writeUInt32LE(entry.data.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(offset, 42);
    centralParts.push(central, name);
    offset += local.length + name.length + entry.data.length;
  }

  const centralSize = centralParts.reduce((sum, part) => sum + part.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...localParts, ...centralParts, end]);
}

const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let value = n;
  for (let i = 0; i < 8; i++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  return value >>> 0;
});

function crc32(data: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of data) crc = CRC_TABLE[(crc ^ byte) & 0xff]! ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}
