// The install, update and drill checks' shared hands: installer.ps1's verbs,
// what Windows has about loqui, and the tray menu's Check for updates.
import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { desk, localAppData, ps, windowsDir } from "../e2e/drive";

export const arch = process.arch === "arm64" ? "arm64" : "x64";
export const shots = process.env.LOQUI_SHOTS ?? join(windowsDir, "target", "shots");
export const shot = (name: string) => join(shots, `${name}.png`);
export const installedExe = join(localAppData, "Programs", "loqui", "loqui.exe");

/** What scripts/release/build.mjs says about the installers it made. */
export type Manifest = {
  version: string;
  arch: string;
  setup: { file: string; size: number; sha256: string };
  update: { file: string; size: number; sha256: string; signature: string };
};

/** Everything Windows has about loqui (installer.ps1 facts). */
export type Facts = {
  exe: boolean;
  folder: boolean;
  appInDataFolder: boolean;
  installed: { name: string; version: string; uninstall: string; location: string } | null;
  run: string | null;
  startMenu: string[];
  processes: { pid: number; path: string }[];
  model: { version: string | null; encoder: string | null; vad: string | null };
  engine: string[];
  data: { name: string; sha256: string }[];
};

export function manifestIn(folder: string): Manifest {
  const dir = join(windowsDir, "target", folder);
  const name = readdirSync(dir).find((f) => f.endsWith(`-${arch}.json`));
  if (!name) throw new Error(`no installers in ${dir}: windows.yml builds them first`);
  return JSON.parse(readFileSync(join(dir, name), "utf8"));
}

/** One action from installer.ps1. */
export function inst(verb: string, args: Record<string, string | boolean> = {}, timeout = 300_000) {
  const argv = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(import.meta.dirname, "installer.ps1"), verb];
  for (const [key, value] of Object.entries(args)) {
    if (value === true) argv.push(`-${key}`);
    else if (value !== false) argv.push(`-${key}`, value);
  }
  let out: string;
  try {
    out = execFileSync("powershell.exe", argv, { encoding: "utf8", timeout, maxBuffer: 1 << 24 });
  } catch (error) {
    const { stdout, stderr } = error as { stdout?: string; stderr?: string };
    throw new Error(`installer.ps1 ${verb} failed: ${stdout ?? ""} ${stderr ?? ""}`);
  }
  return JSON.parse(out.trim().split(/\r?\n/).at(-1) ?? "");
}

export const facts = (): Facts => inst("facts");

/** Your four files: settings, dictionary, history and stats, with their checksums. */
const YOURS = ["settings.json", "cleanup.json", "history.jsonl", "dictation-log.jsonl"];
export const yours = (f: Facts) =>
  f.data.filter((d) => YOURS.includes(d.name)).sort((a, b) => a.name.localeCompare(b.name));

export async function waitFor<T>(what: string, ms: number, probe: () => T | undefined | false | null) {
  const until = Date.now() + ms;
  for (;;) {
    const found = probe();
    if (found) return found;
    if (Date.now() > until) throw new Error(`waited ${ms / 1000} s for ${what}`);
    await sleep(500);
  }
}

export const quitLoqui = () => ps("Get-Process loqui -ErrorAction SilentlyContinue | Stop-Process -Force; exit 0");

/** Start the installed loqui (it checks its update list as it starts); returns its process id. */
export async function startLoqui(name: string): Promise<number> {
  quitLoqui();
  await sleep(1000);
  return desk("start", { Exe: installedExe, Shot: shot(name) }).pid;
}

/** The tray menu's Check for updates, and the update window saying `expected`. */
export function checkByHand(pid: number, expected: string, name: string, wait = 60_000) {
  desk("open-menu", { ProcessId: pid });
  desk("choose", { Item: "Check for updates\u2026" });
  return desk("window", { ProcessId: pid, Title: "loqui update", Name: expected, Wait: wait, Shot: shot(name) });
}

export const closeUpdateWindow = (pid: number) => desk("close-window", { ProcessId: pid, Title: "loqui update" });

/** Install and restart loqui from the update window; returns the new loqui's facts once it runs `version`. */
export async function installFromPrompt(pid: number, version: string) {
  desk("click", { ProcessId: pid, Title: "loqui update", Name: "Install and restart loqui" });
  try {
    return await waitFor(`loqui to restart as ${version}`, 300_000, () => {
      const f = facts();
      return f.installed?.version === version && f.processes.some((p) => p.pid !== pid) && f;
    });
  } catch (error) {
    // What Windows and loqui said when it didn't come back, for the run's log.
    try {
      desk("screenshot", { Shot: shot("update-stuck") });
    } catch {}
    const f = facts();
    const log = join(localAppData, "Loqui", "logs", "voice-key.log");
    let tail = "";
    try {
      tail = readFileSync(log, "utf8").split("\n").slice(-30).join("\n");
    } catch {}
    console.error(`Update to ${version} didn't finish. Facts: ${JSON.stringify(f)}\nloqui's log:\n${tail}`);
    throw error;
  }
}
