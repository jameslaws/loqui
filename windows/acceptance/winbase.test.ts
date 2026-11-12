// WINBASE: the test build installs and starts on GitHub's Windows computers,
// sits by the clock with its menu, shows About, and quits cleanly. Runs on
// Windows only, after `pnpm build`; desktop.ps1 does the clicking.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { expect, test } from "vitest";

type Proc = { pid: number; name: string };

const windowsDir = join(import.meta.dirname, "..");
const { version } = JSON.parse(readFileSync(join(windowsDir, "package.json"), "utf8"));
const shots = process.env.LOQUI_SHOTS ?? join(windowsDir, "target", "shots");
const onWindows = process.platform === "win32";
const label = process.arch === "arm64" ? "winbase-02-arm" : "winbase-01-x64";

/** One desktop action; returns its JSON answer or fails with what went wrong. */
function desk(verb: string, args: Record<string, string | number> = {}) {
  const argv = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(import.meta.dirname, "desktop.ps1"), verb];
  for (const [key, value] of Object.entries(args)) argv.push(`-${key}`, String(value));
  let out: string;
  try {
    out = execFileSync("powershell.exe", argv, { encoding: "utf8", timeout: 90_000 });
  } catch (error) {
    const { stdout, stderr } = error as { stdout?: string; stderr?: string };
    throw new Error(`desktop.ps1 ${verb} failed: ${stdout ?? ""} ${stderr ?? ""}`);
  }
  return JSON.parse(out.trim().split(/\r?\n/).at(-1) ?? "");
}

function installer(): string {
  const dir = join(windowsDir, "target", "release", "bundle", "nsis");
  const file = readdirSync(dir).find((name) => name.endsWith("-setup.exe"));
  if (!file) throw new Error(`no installer in ${dir}; run pnpm build first`);
  return join(dir, file);
}

let running = 0;

async function startsOnThisPc() {
  mkdirSync(shots, { recursive: true });
  const localAppData = process.env.LOCALAPPDATA ?? "";
  expect(existsSync(join(localAppData, "loqui", "loqui.exe"))).toBe(false);

  // Installed for this user only: under their own AppData, no administrator.
  const installed = desk("install", { Installer: installer() });
  expect(installed.exitCode).toBe(0);
  expect(installed.exe?.toLowerCase().startsWith(localAppData.toLowerCase())).toBe(true);
  expect(installed.running).toBe(0);

  const started = desk("start", { Exe: installed.exe });
  expect(started.ms).toBeLessThanOrEqual(2000);
  running = started.pid;

  const menu = desk("open-menu", { ProcessId: running, Shot: join(shots, `${label}-menu.png`) });
  expect(menu.items).toEqual([
    { name: "loqui is running", enabled: false },
    { name: "About loqui", enabled: true },
    { name: "Quit loqui", enabled: true },
  ]);

  desk("choose", { Item: "About loqui" });
  const about = desk("about", { ProcessId: running });
  expect(about.title).toBe("About loqui");
  expect(about.texts).toContain(`Version ${version} (test build)`);

  // The picture for the pull request: the About window with the menu open.
  desk("open-menu", { ProcessId: running, Shot: join(shots, `${label}-menu-and-about.png`) });
}

test.runIf(onWindows && process.arch === "x64")(
  "WINBASE-01: The Windows test build starts on an Intel/AMD PC",
  startsOnThisPc,
);

test.runIf(onWindows && process.arch === "arm64")(
  "WINBASE-02: The Windows test build starts on an Arm PC",
  startsOnThisPc,
);

test.runIf(onWindows)("WINBASE-03: Quit leaves nothing running", async () => {
  expect(running, "WINBASE-01 or 02 starts loqui first").not.toBe(0);
  const started: Proc[] = desk("tree", { ProcessId: running }).processes;
  // The About window's web view is running too, and must go with it.
  expect(started.some((p) => /msedgewebview2/i.test(p.name))).toBe(true);

  desk("open-menu", { ProcessId: running });
  desk("choose", { Item: "Quit loqui" });
  await sleep(3000);

  const after = desk("after-quit", {
    ProcessId: running,
    Pids: started.map((p) => p.pid).join(","),
    Shot: join(shots, `${label.replace(/winbase-0[12]/, "winbase-03")}-after-quit.png`),
  });
  expect(after.alive).toEqual([]);
  expect(after.trayWindow).toBe(false);
  expect(after.iconOnTaskbar).toBe(false);
});
