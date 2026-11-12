// Replaces an update list kept as a file on a fixed GitHub pre-release (the
// test list, and the drill's lists), creating that pre-release the first time.
// A list never goes back: if it already offers a newer version, it's left as is.
// Needs the gh command and GH_TOKEN.
//
//   node windows/scripts/release/list.mjs replace <list tag> <list file> <commit for a new tag>
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { compare } from "./version.mjs";

const repo = process.env.GITHUB_REPOSITORY ?? "jameslaws/loqui";
const gh = (...args) => execFileSync("gh", [...args, "--repo", repo], { encoding: "utf8" });

export function replaceList(listTag, file, commit) {
  const name = basename(file);
  const ours = JSON.parse(readFileSync(file, "utf8")).version;
  try {
    gh("release", "view", listTag, "--json", "tagName");
  } catch {
    gh(
      "release",
      "create",
      listTag,
      "--prerelease",
      "--latest=false",
      "--target",
      commit,
      "--title",
      `loqui for Windows: update list (${listTag})`,
      "--notes",
      "Not a download. loqui reads its update list here; the installers are on each version's own release.",
    );
  }
  const scratch = mkdtempSync(join(tmpdir(), "list-"));
  try {
    gh("release", "download", listTag, "--pattern", name, "--dir", scratch);
    const theirs = JSON.parse(readFileSync(join(scratch, name), "utf8")).version;
    if (compare(theirs, ours) > 0) {
      console.log(`${listTag}/${name} already offers ${theirs}, newer than ${ours}; left as it is.`);
      return false;
    }
  } catch (error) {
    if (!String(error).includes("no assets")) console.log(`No ${name} on ${listTag} yet.`);
  }
  gh("release", "upload", listTag, file, "--clobber");
  console.log(`${listTag}/${name} now offers ${ours}.`);
  return true;
}

const [command, listTag, file, commit] = process.argv.slice(2);
if (command === "replace" && listTag && file && commit) replaceList(listTag, file, commit);
else {
  console.error("Usage: node windows/scripts/release/list.mjs replace <list tag> <list file> <commit>");
  process.exit(1);
}
