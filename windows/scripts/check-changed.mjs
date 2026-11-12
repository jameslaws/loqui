// Quick checks for what your changes touch, so a small edit doesn't wait for
// the whole suite. CI still runs everything.
import { execFileSync, spawnSync } from "node:child_process";
import { join } from "node:path";

const windowsDir = join(import.meta.dirname, "..");
const git = (...args) => execFileSync("git", args, { cwd: windowsDir, encoding: "utf8" });
const root = git("rev-parse", "--show-toplevel").trim();
const changed = [
  ...git("diff", "--name-only", "HEAD", "--", root).split("\n"),
  ...git("ls-files", "--others", "--exclude-standard", "--full-name", root).split("\n"),
].filter(Boolean);

const touches = (...prefixes) => changed.some((f) => prefixes.some((p) => f.startsWith(p)));
const checks = [];
if (touches("windows/", "shared/", "PROJECT.md")) {
  checks.push(["pnpm", "exec", "biome", "check", "."], ["pnpm", "exec", "tsc", "-p", "."]);
  checks.push(["pnpm", "exec", "vitest", "run", "--project", "contracts"]);
}
if (touches("windows/crates/", "windows/src-tauri/", "windows/Cargo")) {
  checks.push(
    ["cargo", "fmt", "--all", "--check"],
    ["cargo", "clippy", "--workspace", "--all-targets", "--", "-D", "warnings"],
  );
}
if (touches("windows/crates/", "shared/", "windows/Cargo")) checks.push(["cargo", "test", "-p", "loqui-core"]);

if (checks.length === 0) console.log("Nothing in windows/ or shared/ changed.");
for (const [cmd, ...args] of checks) {
  console.log(`\n> ${cmd} ${args.join(" ")}`);
  const run = spawnSync(cmd, args, { cwd: windowsDir, stdio: "inherit", shell: process.platform === "win32" });
  if (run.status !== 0) process.exit(run.status ?? 1);
}
