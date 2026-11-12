// Dictation on Windows, end to end on GitHub's Windows computers with no person
// involved: a virtual sound cable is the microphone, Notepad is where you type,
// a script presses Ctrl+Shift+Space, and Windows' own voice does the talking.
// Runs after `pnpm build` and the WINBASE checks (which install loqui). On the
// Intel/AMD computer, against the installed build; on Arm, DICT-07 runs a test
// build that plays a file instead of the microphone (`pnpm build:test-audio`).
import { type ChildProcess, spawn } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { afterAll, beforeAll, beforeEach, expect, test } from "vitest";
import {
  type Args,
  data,
  desk,
  dk,
  installedExe,
  lines,
  localAppData,
  MIC_SWITCH,
  modelLoaded,
  ps,
  windowsDir,
} from "./drive";

const shots = process.env.LOQUI_SHOTS ?? join(windowsDir, "target", "shots");
const onWindows = process.platform === "win32";
const x64 = onWindows && process.arch === "x64";
const arm = onWindows && process.arch === "arm64";
const voiceLog = join(data, "logs", "voice-key.log");

const SENTENCE = "Please send the report to Sarah before Friday, and copy the whole team.";
const PARAGRAPH =
  "Thanks for sending the draft over this morning. I read it on the train, and I think the second section works well, but the opening is too long. Could we cut the first two paragraphs and start with the story about the customer who called on a Sunday? That is the moment readers will remember. I would also move the pricing table to the end, because nobody wants numbers before they care about the problem. I also spoke with the design team yesterday, and they would like to see the new layout before we send anything to the printer. They think the cover photo is too dark, so they will try a brighter one this week. Let me know if Thursday still works for a call. If not, Friday afternoon is fine, and I can send notes before then so we do not waste the time. One more thing: the headline should say what changes for the reader, not what we built. Talk soon.";
const LOKI = "I use loki every day.";
const MIC_BLOCKED =
  "loqui notice: Windows is blocking the microphone. Turn on \u201cLet desktop apps access your microphone\u201d in Settings, then try again.";
const NO_MIC = "loqui notice: loqui can't find a microphone.";

const words = (text: string) =>
  text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s']/gu, " ")
    .split(/\s+/)
    .filter(Boolean);
const shot = (name: string) => join(shots, name);

/** Every bubble state seen, in order, as [ms, foreground, state]. */
const states = (changes: string[]) =>
  changes.map((c) => c.split("|")).map(([ms, fg, state]) => ({ ms: Number(ms), fg, state }));

/** loqui's settings file, with the welcome finished (the welcome has its own checks in windows-screens.test.ts). */
function writeSettings(change: Record<string, unknown>) {
  mkdirSync(data, { recursive: true });
  const settings = { shortcut: "Ctrl+Shift+Space", historyRetentionDays: 0, onboarded: true, ...change };
  writeFileSync(join(data, "settings.json"), JSON.stringify(settings));
}

let pid = 0;
let notepad = 0;
let watcher: ChildProcess | undefined;
const stopWatching = join(windowsDir, "target", "e2e-stop-watching");
const connections = shot("priv-01-connections.jsonl");
const wav = (name: string) => join(windowsDir, "target", "e2e", `${name}.wav`);

function dictate(name: string, file: string, extra: Args = {}) {
  dk("clear", { Hwnd: notepad });
  return dk("dictate", { Hwnd: notepad, ProcessId: pid, Wav: file, Shot: shot(name), ...extra }, 180_000);
}

beforeAll(async () => {
  if (!onWindows) return;
  mkdirSync(shots, { recursive: true });
  mkdirSync(dirname(wav("x")), { recursive: true });
  desk("ready-desktop");
  for (const [name, text] of [
    ["sentence", SENTENCE],
    ["paragraph", PARAGRAPH],
    ["loki", LOKI],
  ]) {
    dk("make-wav", { Text: text, Wav: wav(name) });
  }
  // A fresh start: loqui's records and settings from earlier runs removed (never the installed app).
  ps("Get-Process loqui -ErrorAction SilentlyContinue | Stop-Process -Force; exit 0");
  for (const name of ["history.jsonl", "dictation-log.jsonl", "settings.json", "cleanup.json", "logs"]) {
    rmSync(join(data, name), { recursive: true, force: true });
  }
  rmSync(stopWatching, { force: true });
  // The welcome was finished long ago: it mustn't open over Notepad on a restart.
  writeSettings({});

  if (arm) {
    // The test build with the file in place of the microphone.
    process.env.LOQUI_TEST_AUDIO = wav("sentence");
    pid = desk("start", { Exe: join(windowsDir, "target", "release", "loqui.exe") }).pid;
  } else {
    pid = desk("start", { Exe: installedExe(), Shot: shot("e2e-start.png") }).pid;
    rmSync(connections, { force: true });
    const args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(import.meta.dirname, "dictate.ps1")];
    watcher = spawn("powershell.exe", [
      ...args,
      "net-watch",
      "-ProcessId",
      `${pid}`,
      "-Out",
      connections,
      "-StopFile",
      stopWatching,
    ]);
  }
  await modelLoaded();
  notepad = dk("notepad").hwnd;
}, 600_000);

/** Turns the virtual sound cable, and so the only microphone, off or on. */
const cable = (verb: "Enable" | "Disable") =>
  `Get-PnpDevice -Class MEDIA, AudioEndpoint -ErrorAction SilentlyContinue | Where-Object FriendlyName -like '*CABLE*' | ${verb}-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue; exit 0`;

beforeEach(async () => {
  if (!onWindows || !pid) return;
  if (dk("state", { ProcessId: pid }).bubble !== "loqui listening") return;
  dk("keys", { Hwnd: notepad, ProcessId: pid });
  for (let i = 0; i < 40 && dk("state", { ProcessId: pid }).bubble !== "loqui hidden"; i++) await sleep(250);
});

afterAll(() => {
  if (!onWindows) return;
  writeFileSync(stopWatching, "");
  // loqui's logs and the names behind any addresses, kept with the run's pictures.
  if (existsSync(join(data, "logs"))) cpSync(join(data, "logs"), join(shots, "loqui-logs"), { recursive: true });
  writeFileSync(
    join(shots, "dns-cache.txt"),
    ps("Get-DnsClientCache | Format-Table -AutoSize Entry, Data | Out-String -Width 200"),
  );
  // Put the microphone back for anything that runs after (there is none on Arm).
  if (x64) ps(cable("Enable"));
});

test.runIf(x64)("DICT-01: Tap to start, tap to stop, text lands at the cursor", () => {
  const r = dictate("dict-01", wav("sentence"));
  expect(r.text).toBe(SENTENCE);
  expect(r.ms).toBeGreaterThanOrEqual(0);
  expect(r.ms).toBeLessThanOrEqual(1500);
});

test.runIf(x64)("PASTE-01: The text stays on the clipboard, out of Windows' history and sync", () => {
  const c = dk("clipboard");
  expect(c.text).toBe(SENTENCE);
  expect(c.formats).toContain("CanIncludeInClipboardHistory=0");
  expect(c.formats).toContain("CanUploadToCloudClipboard=0");
});

let paragraph = "";

test.runIf(x64)(
  "DICT-04: A 60-second dictation keeps its last words",
  () => {
    const r = dictate("dict-04", wav("paragraph"));
    paragraph = r.text;
    expect(words(r.text)).toEqual(words(PARAGRAPH));
    // Its final sentence, explicitly: the words most at risk when it stops.
    const last = words("The headline should say what changes for the reader, not what we built. Talk soon.");
    expect(words(r.text).slice(-last.length)).toEqual(last);
    expect(r.ms).toBeGreaterThanOrEqual(0);
    expect(r.ms).toBeLessThanOrEqual(1500);
  },
  240_000,
);

test.runIf(x64)("REC-01: History and stats records match the Mac's format", () => {
  const history = lines(join(data, "history.jsonl")).map((l) => JSON.parse(l));
  const stats = lines(join(data, "dictation-log.jsonl")).map((l) => JSON.parse(l));
  const iso = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/;
  expect(history.map((h) => Object.keys(h))).toEqual([
    ["at", "text"],
    ["at", "text"],
  ]);
  expect(history.map((h) => h.text)).toEqual([SENTENCE, paragraph]);
  expect(history.every((h) => iso.test(h.at))).toBe(true);
  expect(stats.map((s) => Object.keys(s))).toEqual([
    ["at", "words", "seconds"],
    ["at", "words", "seconds"],
  ]);
  expect(stats.map((s) => s.words)).toEqual([13, paragraph.split(/\s+/).filter(Boolean).length]);
  expect(stats.every((s) => iso.test(s.at) && s.seconds > 1)).toBe(true);

  // History off: the dictation is counted for stats, and its text kept nowhere.
  writeSettings({ historyRetentionDays: -1 });
  try {
    expect(dictate("rec-01-off", wav("sentence")).text).toBe(SENTENCE);
    expect(lines(join(data, "history.jsonl"))).toHaveLength(2);
    expect(lines(join(data, "dictation-log.jsonl"))).toHaveLength(3);
  } finally {
    writeSettings({ historyRetentionDays: 0 });
  }
});

test.runIf(x64)("DICT-02: Hold to talk, let go to paste", () => {
  const r = dictate("dict-02", wav("sentence"), { Mode: "hold" });
  expect(r.text).toBe(SENTENCE);
  expect(r.ms).toBeGreaterThanOrEqual(0);
  expect(r.ms).toBeLessThanOrEqual(1500);

  // The gesture didn't stick: a short tap starts a new dictation, the next stops it.
  const start = dk("tap-watch", { Hwnd: notepad, ProcessId: pid, Ms: 1500 });
  expect(states(start.changes).at(-1)?.state).toBe("loqui listening");
  const stop = dk("tap-watch", { Hwnd: notepad, ProcessId: pid, Ms: 2500 });
  expect(states(stop.changes).at(-1)?.state).toBe("loqui hidden");
  expect(stop.text).toBe(SENTENCE);
});

test.runIf(x64)("DICT-03: The shortcut never reaches the app, other keys do", () => {
  dk("clear", { Hwnd: notepad });
  dk("tap-watch", { Hwnd: notepad, ProcessId: pid, Ms: 1000 });
  const stopped = dk("tap-watch", { Hwnd: notepad, ProcessId: pid, Ms: 2500 });
  expect(stopped.text).toBe("");
  expect(states(stopped.changes).at(-1)?.state).toBe("loqui hidden");

  // Other shortcuts aren't loqui's: they reach Notepad, which may type a space
  // for Ctrl+Alt+Shift+Space (Ctrl+Alt is AltGr on many keyboards).
  expect(dk("keys", { Hwnd: notepad, ProcessId: pid, Spec: "ctrl+space" }).bubble).not.toBe("loqui listening");
  const others = dk("keys", { Hwnd: notepad, ProcessId: pid, Spec: "ctrl+alt+shift+space" });
  expect(others.bubble).not.toBe("loqui listening");
  expect(others.text.trim()).toBe("");
  const typed = dk("type", { Hwnd: notepad, Text: "abc" }).text;
  expect(typed).toBe(`${others.text}abc`);

  // Held for 2 s, the shortcut repeats, and not one space gets through.
  const held = dk("keys", { Hwnd: notepad, ProcessId: pid, HoldMs: 2000 });
  expect(held.text).toBe(typed);
});

test.runIf(x64)("DICT-05: Cleanup and the dictionary apply", () => {
  writeFileSync(join(data, "cleanup.json"), JSON.stringify({ dictionary: { loki: "Loqui" }, removeFillers: true }));
  try {
    const r = dictate("dict-05", wav("loki"));
    expect(r.text).toBe("I use Loqui every day.");
    const audit = readFileSync(join(data, "logs", "cleanup.log"), "utf8");
    expect(audit).toMatch(/RAW: +I use lok(i|y) every day\./i);
    expect(audit).toContain("CLEANED: I use Loqui every day.");
    const ended =
      lines(voiceLog)
        .filter((l) => l.includes("dictation ended"))
        .at(-1) ?? "";
    expect(ended).toMatch(/— 5 words in \d+s$/);
    expect(readFileSync(voiceLog, "utf8")).not.toMatch(/Loqui|every day|Sarah/);
  } finally {
    rmSync(join(data, "cleanup.json"), { force: true });
  }
});

test.runIf(x64)("HUD-01: The bubble never takes the cursor", () => {
  const r = dictate("hud-01", wav("sentence"));
  expect(r.text).toBe(SENTENCE);
  expect(r.foregroundKept, `the foreground went to ${r.lostTo}`).toBe(true);

  const seen = states(r.changes);
  // The spinner shows only while the last words are being turned into text,
  // which can be over before the check looks again (every 20 ms).
  const order = seen
    .map((s) => s.state)
    .filter((s, i, all) => s !== all[i - 1])
    .filter((s) => s !== "loqui finishing");
  expect(order).toEqual(["loqui hidden", "loqui listening", "loqui pasted", "loqui hidden"]);
  const pasted = seen.find((s) => s.state === "loqui pasted")?.ms ?? 0;
  const gone = seen.filter((s) => s.state === "loqui hidden").at(-1)?.ms ?? 0;
  expect(gone - pasted).toBeGreaterThanOrEqual(700);
  expect(gone - pasted).toBeLessThanOrEqual(1400);

  // Bottom centre of the screen.
  const { listening: b, work } = r;
  expect(Math.abs((b.left + b.right) / 2 - (work.left + work.right) / 2)).toBeLessThanOrEqual(2);
  expect(b.bottom).toBe(work.bottom);
});

test.runIf(x64)("HUD-02: The tray icon shows recording", () => {
  dk("keys", { Hwnd: notepad, ProcessId: pid });
  const recording = dk("tray", { ProcessId: pid, Shot: shot("hud-02-recording"), Samples: 8 });
  dk("keys", { Hwnd: notepad, ProcessId: pid });
  const after = dk("tray", { ProcessId: pid, Shot: shot("hud-02-after"), Samples: 3 });

  // Magenta all the while, bright then dim as it pulses; plain once stopped.
  const strength: number[] = recording.magenta;
  expect(Math.min(...strength)).toBeGreaterThan(500);
  expect(Math.max(...strength)).toBeGreaterThan(Math.min(...strength) * 1.3);
  expect(after.magenta).toEqual([0, 0, 0]);
});

test.runIf(x64)("PRIV-02: Typed keys never reach any loqui file", () => {
  const unique = `Quillowbrandt${Date.now()}`;
  const typed = `This sentence is typed and never spoken: the word ${unique} is only ever on the keyboard, so if it turns up in any file that loqui keeps, then loqui recorded typing it should not have seen.`;
  expect(typed.length).toBeGreaterThanOrEqual(200);
  const since = new Date(Date.now() - 2000).toISOString();
  dk("clear", { Hwnd: notepad });
  expect(dk("type", { Hwnd: notepad, Text: typed }).text).toBe(typed);
  const r = dk("dictate", { Hwnd: notepad, ProcessId: pid, Wav: wav("sentence") }, 180_000);
  expect(r.text).toBe(`${typed}${SENTENCE}`);

  const folders = [data, dirname(installedExe()), join(localAppData, "com.jameslaws.loqui")];
  const found = dk("find-text", { Text: unique, Dirs: folders.join(";"), Since: since });
  expect(found.searched).toBeGreaterThan(0);
  expect(found.hits).toEqual([]);
});

test.runIf(x64)("MIC-01: Windows blocking the microphone gets a plain message", () => {
  const consent = MIC_SWITCH;
  dk("clear", { Hwnd: notepad });
  ps(`Set-ItemProperty -Path '${consent}' -Name Value -Value Deny`);
  try {
    const r = dk("tap-watch", { Hwnd: notepad, ProcessId: pid, Ms: 4000, Shot: shot("mic-01-blocked") });
    const seen = states(r.changes);
    const shown = seen.find((s) => s.state === MIC_BLOCKED);
    expect(shown, JSON.stringify(seen)).toBeDefined();
    const hidden = seen.find((s) => s.ms > (shown?.ms ?? 0) && s.state === "loqui hidden");
    expect((hidden?.ms ?? 0) - (shown?.ms ?? 0)).toBeGreaterThanOrEqual(1500);
    expect((hidden?.ms ?? 0) - (shown?.ms ?? 0)).toBeLessThanOrEqual(2500);
    expect(r.text).toBe("");
  } finally {
    ps(`Set-ItemProperty -Path '${consent}' -Name Value -Value Allow`);
  }
  // Switched back on, the next dictation works without restarting loqui.
  expect(dictate("mic-01-after", wav("sentence")).text).toBe(SENTENCE);
  expect(loquiAlive()).toBe(true);
});

function loquiAlive() {
  return ps(`(Get-Process -Id ${pid} -ErrorAction SilentlyContinue) -ne $null`).trim() === "True";
}

test.runIf(x64)(
  "DICT-06: Two minutes of silence stops it",
  () => {
    dk("clear", { Hwnd: notepad });
    const r = dk("tap-watch", { Hwnd: notepad, ProcessId: pid, Ms: 140_000 }, 200_000);
    const seen = states(r.changes);
    const listening = seen.find((s) => s.state === "loqui listening")?.ms ?? -1;
    const stopped = seen.find((s) => s.ms > listening && s.state !== "loqui listening")?.ms ?? -1;
    expect(listening).toBeGreaterThanOrEqual(0);
    expect((stopped - listening) / 1000).toBeGreaterThanOrEqual(110);
    expect((stopped - listening) / 1000).toBeLessThanOrEqual(130);
    expect(seen.at(-1)?.state).toBe("loqui hidden");
    expect(r.text).toBe("");
    expect(readFileSync(voiceLog, "utf8")).toContain("watchdog stop: 120s of silence");
    expect(dk("tray", { ProcessId: pid, Samples: 2 }).magenta).toEqual([0, 0]);
  },
  240_000,
);

test.runIf(x64)("PRIV-01: loqui opens no network connection", async () => {
  expect(watcher, "the watcher starts before DICT-01").toBeDefined();
  writeFileSync(stopWatching, "");
  for (let i = 0; i < 40 && watcher?.exitCode === null; i++) await sleep(250);
  const seen = lines(connections).map((l) => JSON.parse(l));
  const local = /^(127\.|::1$|0\.0\.0\.0$|::$)/;
  const outside = seen.filter((c) => !local.test(c.remote));
  console.log(`PRIV-01: ${seen.length} connections listed, ${outside.length} outside this machine`);
  expect(outside).toEqual([]);
});

test.runIf(x64)(
  "PERF-01: Ready soon after start, and memory is recorded",
  async () => {
    ps(`Stop-Process -Id ${pid} -Force`);
    await sleep(1500);
    dk("clear", { Hwnd: notepad });
    const r = dk(
      "dictate",
      { Hwnd: notepad, Exe: installedExe(), Wav: wav("sentence"), Shot: shot("perf-01") },
      180_000,
    );
    pid = r.pid;
    expect(r.pressedAfterStartMs).toBeLessThanOrEqual(1300);
    expect(r.text).toBe(SENTENCE);

    await modelLoaded();
    const idle = dk("memory", { ProcessId: pid });
    dk("keys", { Hwnd: notepad, ProcessId: pid });
    await sleep(1000);
    const dictating = dk("memory", { ProcessId: pid });
    dk("keys", { Hwnd: notepad, ProcessId: pid });
    const figures = { idle, dictating };
    writeFileSync(shot("perf-01-memory.json"), JSON.stringify(figures, null, 2));
    console.log(`PERF-01 memory: ${JSON.stringify(figures)}`);
    expect(idle.loquiPrivateMB).toBeGreaterThan(0);
  },
  300_000,
);

test.runIf(x64)("MIC-02: No microphone gets a plain message", async () => {
  ps(cable("Disable"));
  // Wait until Windows no longer lists a working microphone.
  const present =
    "@(Get-PnpDevice -Class AudioEndpoint -PresentOnly -Status OK -ErrorAction SilentlyContinue | Where-Object FriendlyName -like '*CABLE Output*').Count";
  for (let i = 0; i < 40 && ps(present).trim() !== "0"; i++) await sleep(250);
  expect(ps(present).trim()).toBe("0");
  const r = dk("tap-watch", { Hwnd: notepad, ProcessId: pid, Ms: 3000, Shot: shot("mic-02-no-microphone") });
  expect(states(r.changes).map((s) => s.state)).toContain(NO_MIC);
  expect(loquiAlive()).toBe(true);
});

test.runIf(arm)("DICT-07: The Arm version turns speech into the same text", () => {
  const r = dictate("dict-07-arm", wav("sentence"), { NoPlay: true });
  expect(r.text).toBe(SENTENCE);
});
