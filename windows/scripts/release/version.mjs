// Windows version numbers: the number inside the app always equals the one on
// its release and in the update lists, so every change to windows/ that
// reaches staging raises it (plans/windows-version, "Version numbers").
//
//   node scripts/release/version.mjs higher-than <git ref>
//     fails unless windows/package.json's version is above the one at <git ref>
//   node scripts/release/version.mjs next
//     prints the version one patch above windows/package.json's
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const windowsDir = join(import.meta.dirname, "..", "..");

/** "0.0.12" as [0, 0, 12]; anything else is refused. */
export function parse(version) {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
  if (!m) throw new Error(`"${version}" isn't a version like 0.0.3`);
  return m.slice(1).map(Number);
}

/** Positive when a is above b. */
export function compare(a, b) {
  const [x, y] = [parse(a), parse(b)];
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
}

export const next = (version) => {
  const [major, minor, patch] = parse(version);
  return `${major}.${minor}.${patch + 1}`;
};

const own = () => JSON.parse(readFileSync(join(windowsDir, "package.json"), "utf8")).version;

const [command, ref] = process.argv.slice(2);
if (command === "next") console.log(next(own()));
else if (command === "higher-than" && ref) {
  const theirs = JSON.parse(
    execFileSync("git", ["show", `${ref}:windows/package.json`], { cwd: windowsDir, encoding: "utf8" }),
  ).version;
  if (compare(own(), theirs) <= 0) {
    console.error(
      `windows/package.json says ${own()}, which isn't above ${theirs} on ${ref}. Raise it: every change to windows/ that reaches staging becomes a new test version.`,
    );
    process.exit(1);
  }
  console.log(`${own()} is above ${theirs} on ${ref}.`);
} else if (command) {
  console.error("Usage: node scripts/release/version.mjs next | higher-than <git ref>");
  process.exit(1);
}
