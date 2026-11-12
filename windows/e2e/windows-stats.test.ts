// The stats window on a real Windows PC (both of GitHub's Windows computers),
// after the other checks: the installed loqui is started with the shared
// sample record moved to today, and its stats window is read, clicked through
// Windows' accessibility interface and photographed light and dark. Every
// figure is checked in a browser and in the core's tests; this proves the
// real window, the record on disk, the PC's time zone and the tray item.
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { afterAll, beforeAll, expect, test } from "vitest";
import { data, desk, dk, installedExe, modelLoaded, ps, windowsDir } from "./drive";

const onWindows = process.platform === "win32";
const x64 = onWindows && process.arch === "x64";
const shots = process.env.LOQUI_SHOTS ?? join(windowsDir, "target", "shots");
const shot = (name: string) => join(shots, `${name}.png`);
const STATS = "loqui dictation stats";
const SENTENCE = "Please send the report to Sarah before Friday, and copy the whole team.";
const SENTENCE_WORDS = 13;
const ZONE = "America/New_York";

const shared = JSON.parse(readFileSync(join(windowsDir, "..", "shared", "stats-cases.json"), "utf8"));
const DAY = 86_400_000;

/** Today in the sample's time zone, as a date at noon UTC. */
const todayThere = () =>
  new Date(`${new Intl.DateTimeFormat("en-CA", { timeZone: ZONE }).format(new Date())}T12:00:00Z`);
/** Whole days from the sample's "now" to today, so its today is the PC's today. */
const shift = () => Math.round((todayThere().getTime() - Date.parse(`${shared.now.slice(0, 10)}T12:00:00Z`)) / DAY);

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const dayName = (d: Date) => `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;

let pid = 0;
let zoneBefore = "";

/** The sample record, every dictation moved by the same whole number of days; damaged lines kept. */
function seedRecord(empty = false) {
  const days = shift();
  const moved = shared.log.map((line: string) => {
    try {
      const e = JSON.parse(line);
      const at = Date.parse(e.at);
      if (Number.isNaN(at)) return line;
      return JSON.stringify({ ...e, at: new Date(at + days * DAY).toISOString().replace(/\.\d+Z$/, "Z") });
    } catch {
      return line;
    }
  });
  mkdirSync(data, { recursive: true });
  rmSync(join(data, "dictation-log.jsonl"), { force: true });
  if (!empty) writeFileSync(join(data, "dictation-log.jsonl"), moved.map((l: string) => `${l}\n`).join(""));
  // No welcome window in the way; every other setting as it is.
  const path = join(data, "settings.json");
  let settings = {};
  try {
    settings = JSON.parse(readFileSync(path, "utf8"));
  } catch {}
  writeFileSync(path, JSON.stringify({ ...settings, onboarded: true }));
}

async function start() {
  ps("Get-Process loqui -ErrorAction SilentlyContinue | Stop-Process -Force; exit 0");
  await sleep(1000);
  pid = desk("start", { Exe: installedExe() }).pid;
}

function openStats(name: string, shotName?: string) {
  desk("open-menu", { ProcessId: pid });
  desk("choose", { Item: "Dictation stats…" });
  return desk("window", { ProcessId: pid, Title: STATS, Name: name, ...(shotName ? { Shot: shot(shotName) } : {}) });
}

const click = (name: string) => desk("click", { ProcessId: pid, Title: STATS, Name: name });

beforeAll(async () => {
  if (!onWindows) return;
  mkdirSync(shots, { recursive: true });
  desk("theme", { Mode: "light" });
  // The sample's time zone, so its days are the PC's days.
  zoneBefore = ps("(Get-TimeZone).Id").trim();
  ps("Set-TimeZone -Id 'Eastern Standard Time'");
  seedRecord();
  await start();
}, 300_000);

afterAll(() => {
  if (!onWindows) return;
  ps("Get-Process loqui -ErrorAction SilentlyContinue | Stop-Process -Force; exit 0");
  if (zoneBefore) ps(`Set-TimeZone -Id '${zoneBefore}'`);
  desk("theme", { Mode: "light" });
});

const t = shared.top;
const n = (x: number) => x.toLocaleString("en-US");
const summary = (extra = 0) =>
  `${n(t.allTimeWords + extra)} words all-time · ${n(t.dictations + (extra ? 1 : 0))} dictations · ${n(
    Math.floor((t.allTimeWords + extra) / (t.dictations + (extra ? 1 : 0))),
  )} words each`;

test.runIf(onWindows)("STAT-01: The top of the window matches the record (on Windows)", () => {
  const window = openStats(summary(), "c-stats-light");
  // The damaged lines are skipped, and today counts in the PC's own time zone.
  expect(window.texts).toContain(summary());
  expect(window.texts).toContain(n(t.today));
  expect(window.texts).toContain(`${n(t.yesterday)} yesterday`);
  expect(window.texts).toContain("Patterns");
});

test.runIf(onWindows)("STAT-04: The calendar jumps to a shaded day (on Windows)", () => {
  // The sample's busiest day, moved like the rest.
  const { date, words } = shared.periods.find((p: { id: string }) => p.id === "all time").biggestDay;
  const busiest = new Date(Date.parse(`${date}T12:00:00Z`) + shift() * DAY);
  const today = todayThere();

  click("Day");
  click("Today, choose a day");
  desk("window", { ProcessId: pid, Title: STATS, Name: "Darker days had more words" });
  if (busiest.getUTCMonth() !== today.getUTCMonth()) click("Previous month");
  const name = `${WEEKDAYS[busiest.getUTCDay()]}, ${dayName(busiest)}, ${n(words)} words`;
  desk("window", { ProcessId: pid, Title: STATS, Name: name, Shot: shot("c-stats-picker-light") });
  click(name);
  const picked = desk("window", { ProcessId: pid, Title: STATS, Name: `${dayName(busiest)}, choose a day` });
  expect(picked.texts).toContain(`${n(words)} words`);
  // Back to all time for the next check.
  click("All time");
});

test.runIf(x64)("STAT-08: The window updates while open (on Windows)", async () => {
  await modelLoaded();
  const wav = join(windowsDir, "target", "e2e", "stats-sentence.wav");
  mkdirSync(join(windowsDir, "target", "e2e"), { recursive: true });
  dk("make-wav", { Text: SENTENCE, Wav: wav });
  const notepad = dk("notepad").hwnd;
  dk("clear", { Hwnd: notepad });
  const r = dk("dictate", { Hwnd: notepad, ProcessId: pid, Wav: wav }, 180_000);
  expect(r.text).toBe(SENTENCE);
  // Without reopening the window (the 1-second promise is timed in the browser
  // check; each look here starts a new PowerShell, which takes longer).
  const shown = desk("window", { ProcessId: pid, Title: STATS, Name: summary(SENTENCE_WORDS), Wait: 3000 });
  expect(shown.texts).toContain(n(t.today + SENTENCE_WORDS));
  desk("window", { ProcessId: pid, Title: STATS, Shot: shot("c-stats-updated") });
});

test.runIf(onWindows)("A11Y-02: Stats work by keyboard and pass the accessibility scan (pictures on Windows)", () => {
  // The scan and keyboard checks run in a browser (screens/stats.spec.ts); here
  // the real window is photographed dark too, for the try list.
  desk("close-window", { ProcessId: pid, Title: STATS });
  desk("theme", { Mode: "dark" });
  openStats("Patterns", "c-stats-dark");
  click("Day");
  click("Today, choose a day");
  desk("window", {
    ProcessId: pid,
    Title: STATS,
    Name: "Darker days had more words",
    Shot: shot("c-stats-picker-dark"),
  });
  desk("close-window", { ProcessId: pid, Title: STATS });
  desk("theme", { Mode: "light" });
});

test.runIf(onWindows)("STAT-05: No dictations shows how to start (on Windows)", async () => {
  seedRecord(true);
  await start();
  const empty = openStats("No dictations yet", "c-stats-empty");
  expect(empty.texts).toContain("No dictations yet");
  expect(empty.texts.some((text: string) => text.includes("anywhere to start."))).toBe(true);
  desk("close-window", { ProcessId: pid, Title: STATS });
});
