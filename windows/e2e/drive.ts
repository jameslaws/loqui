// The Windows checks' hands: each call runs one verb of dictate.ps1 (dictation,
// Notepad, the bubble, the clipboard) or acceptance/desktop.ps1 (install, start,
// the tray menu, loqui's windows) and returns its one-line JSON answer.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export type Args = Record<string, string | number | boolean>;

export const windowsDir = join(import.meta.dirname, "..");
export const localAppData = process.env.LOCALAPPDATA ?? "";
/** loqui's files: settings, history, stats and logs. */
export const data = join(localAppData, "Loqui");

function powershell(script: string, verb: string, args: Args, timeout: number) {
  const argv = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, verb];
  for (const [key, value] of Object.entries(args)) {
    if (value === true) argv.push(`-${key}`);
    else argv.push(`-${key}`, String(value));
  }
  let out: string;
  try {
    out = execFileSync("powershell.exe", argv, { encoding: "utf8", timeout, maxBuffer: 1 << 24 });
  } catch (error) {
    const { stdout, stderr } = error as { stdout?: string; stderr?: string };
    throw new Error(`${verb} failed: ${stdout ?? ""} ${stderr ?? ""}`);
  }
  return JSON.parse(out.trim().split(/\r?\n/).at(-1) ?? "");
}

/** One action from dictate.ps1. */
export const dk = (verb: string, args: Args = {}, timeout = 120_000) =>
  powershell(join(import.meta.dirname, "dictate.ps1"), verb, args, timeout);
/** One action from desktop.ps1. */
export const desk = (verb: string, args: Args = {}, timeout = 90_000) =>
  powershell(join(windowsDir, "acceptance", "desktop.ps1"), verb, args, timeout);
/** A PowerShell command's output. */
export const ps = (command: string) =>
  execFileSync("powershell.exe", ["-NoProfile", "-Command", command], { encoding: "utf8" });

export const lines = (file: string) => (existsSync(file) ? readFileSync(file, "utf8").split("\n").filter(Boolean) : []);

/** Where the WINBASE checks installed loqui. */
export function installedExe() {
  const exe = [join(localAppData, "loqui", "loqui.exe"), join(localAppData, "Programs", "loqui", "loqui.exe")].find(
    existsSync,
  );
  if (!exe) throw new Error("loqui isn't installed; the WINBASE checks install it first");
  return exe;
}

const voiceLog = join(data, "logs", "voice-key.log");

/** Waits until loqui's speech model has loaded (it says so in its log). */
export async function modelLoaded() {
  for (let i = 0; i < 120; i++) {
    const log = existsSync(voiceLog) ? readFileSync(voiceLog, "utf8") : "";
    if (/speech model loaded/.test(log)) return;
    if (/speech model FAILED/.test(log)) throw new Error(log);
    await new Promise((done) => setTimeout(done, 500));
  }
  throw new Error("the speech model never loaded");
}

/** The microphone switch for desktop apps, as Windows Settings sets it. */
export const MIC_SWITCH =
  "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\microphone\\NonPackaged";
