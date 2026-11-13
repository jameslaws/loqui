// An update list in the form Tauri's updater reads, made from what
// build.mjs wrote for each kind of PC (target/installers/loqui-<v>-<arch>.json).
// The release workflows and the Windows checks both make lists with this.
//
//   node scripts/release/feed.mjs <base url> <notes file> <manifest.json>... > list.json
//
// <base url> is where the update installers will be downloaded from, ending
// with "/"; each one's file name is added to it.

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

/** Tauri's names for the two kinds of Windows PC. */
export const PLATFORM = { x64: "windows-x86_64", arm64: "windows-aarch64" };

/**
 * The update list for one version.
 * @param {{ base: string, notes: string, manifests: Array<{version: string, arch: string, update: {file: string, size: number, signature: string}}>, date?: string }} release
 */
export function feed({ base, notes, manifests, date = new Date().toISOString() }) {
  const versions = [...new Set(manifests.map((m) => m.version))];
  if (versions.length !== 1) throw new Error(`one version per list, not ${versions.join(", ")}`);
  const platforms = {};
  for (const m of manifests) {
    if (!m.update) throw new Error(`${m.version} ${m.arch} has no update installer (it needs the update key)`);
    if (!PLATFORM[m.arch]) throw new Error(`unknown kind of PC: ${m.arch}`);
    platforms[PLATFORM[m.arch]] = {
      url: `${base}${m.update.file}`,
      signature: m.update.signature,
      // loqui shows the download's size; Tauri's updater ignores this.
      size: m.update.size,
    };
  }
  return { version: versions[0], notes, pub_date: date.replace(/\.\d+Z$/, "Z"), platforms };
}

if (process.argv[1] && import.meta.filename === resolve(process.argv[1])) {
  const [base, notesFile, ...files] = process.argv.slice(2);
  if (!base || !notesFile || files.length === 0) {
    console.error("Usage: node scripts/release/feed.mjs <base url> <notes file> <manifest.json>...");
    process.exit(1);
  }
  const manifests = files.map((f) => JSON.parse(readFileSync(f, "utf8")));
  const notes = readFileSync(notesFile, "utf8").trim();
  process.stdout.write(`${JSON.stringify(feed({ base, notes, manifests }), null, 2)}\n`);
}
