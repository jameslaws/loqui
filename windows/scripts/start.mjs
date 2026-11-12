// Starts the app built by `pnpm build` and leaves it running in the tray.
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const exe = join(import.meta.dirname, "..", "target", "release", process.platform === "win32" ? "loqui.exe" : "loqui");
if (!existsSync(exe)) {
  console.error(`No built app at ${exe}. Run pnpm build first.`);
  process.exit(1);
}
spawn(exe, { detached: true, stdio: "ignore" }).unref();
console.log("loqui started: look for its icon by the clock.");
