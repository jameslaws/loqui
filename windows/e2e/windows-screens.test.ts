// Settings, history, welcome and the tray menu on a real Windows PC (GitHub's
// Intel/AMD computer), after the dictation checks: the installed loqui is
// started fresh, its windows are read and clicked through Windows'
// accessibility interface, keys are pressed like a keyboard, and every window
// is photographed light and dark. The screens' own behaviour is checked in a
// browser (screens/*.spec.ts); these prove the real windows, files, keyboard
// hook, tray menu and Windows settings do what the screens promise.
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { afterAll, beforeAll, expect, test } from "vitest";
import { sampleDictionary, sampleHistory } from "../ui/src/sample";
import { data, desk, dk, installedExe, lines, MIC_SWITCH, modelLoaded, ps, windowsDir } from "./drive";

const x64 = process.platform === "win32" && process.arch === "x64";
const shots = process.env.LOQUI_SHOTS ?? join(windowsDir, "target", "shots");
const shot = (name: string) => join(shots, `${name}.png`);
const WELCOME = "Welcome to loqui";
const SETTINGS = "loqui settings";
const HISTORY = "loqui dictation history";
const SENTENCE = "Please send the report to Sarah before Friday, and copy the whole team.";
const RUN_KEY = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run";

let pid = 0;
let notepad = 0;
const wav = join(windowsDir, "target", "e2e", "screens-sentence.wav");

type Contents = { texts: string[]; buttons: { name: string; enabled: boolean }[] };
const read = (title: string, extra: Record<string, string | number> = {}): Contents =>
  desk("window", { ProcessId: pid, Title: title, ...extra });
const click = (title: string, name: string) => desk("click", { ProcessId: pid, Title: title, Name: name });
const press = (keys: string) => desk("press", { Keys: keys });
const count = (texts: string[], text: string) => texts.filter((t) => t === text).length;

/** Opens the tray menu and chooses an item. */
function choose(item: string) {
  desk("open-menu", { ProcessId: pid });
  desk("choose", { Item: item });
}

async function start() {
  ps("Get-Process loqui -ErrorAction SilentlyContinue | Stop-Process -Force; exit 0");
  await sleep(1000);
  pid = desk("start", { Exe: installedExe() }).pid;
}

/** loqui's files as a person would have them after a while: six dictations and four dictionary words. */
function seedFiles(settings: Record<string, unknown> | null) {
  for (const name of ["history.jsonl", "dictation-log.jsonl", "settings.json", "cleanup.json"]) {
    rmSync(join(data, name), { force: true });
  }
  mkdirSync(data, { recursive: true });
  const oldestFirst = [...sampleHistory].reverse();
  writeFileSync(join(data, "history.jsonl"), oldestFirst.map((h) => `${JSON.stringify(h)}\n`).join(""));
  writeFileSync(join(data, "dictation-log.jsonl"), `${JSON.stringify({ at: sampleHistory[0].at, words: 18 })}\n`);
  const dictionary = Object.fromEntries(sampleDictionary.map((t) => [t.heard, t.replacement]));
  writeFileSync(join(data, "cleanup.json"), JSON.stringify({ dictionary, maxPauseSeconds: 0.5 }));
  if (settings) writeFileSync(join(data, "settings.json"), JSON.stringify(settings));
}

beforeAll(async () => {
  if (!x64) return;
  mkdirSync(shots, { recursive: true });
  mkdirSync(join(windowsDir, "target", "e2e"), { recursive: true });
  dk("make-wav", { Text: SENTENCE, Wav: wav });
  desk("theme", { Mode: "light" });
  // A first start: no settings yet, and Windows' microphone switch for desktop apps off.
  seedFiles(null);
  ps(`Set-ItemProperty -Path '${MIC_SWITCH}' -Name Value -Value Deny`);
  await start();
}, 300_000);

afterAll(() => {
  if (!x64) return;
  ps(`Set-ItemProperty -Path '${MIC_SWITCH}' -Name Value -Value Allow`);
  desk("theme", { Mode: "light" });
});

test.runIf(x64)("WELC-01: The welcome window opens on first start and ticks itself off", async () => {
  const blocked = read(WELCOME, { Name: "Open microphone settings", Shot: shot("welc-01-blocked") });
  expect(blocked.texts).toContain("Not done yet");
  expect(blocked.texts).toContain("Allow the microphone to finish.");
  expect(blocked.buttons.map((b) => b.name)).toContain("Finish later");

  // Switched on in Windows, without touching loqui: the row ticks itself within 2 s.
  ps(`Set-ItemProperty -Path '${MIC_SWITCH}' -Name Value -Value Allow`);
  const switchedAt = Date.now();
  let ticked: Contents | null = null;
  while (Date.now() - switchedAt < 2000) {
    const now = read(WELCOME, { Wait: 500 });
    if (count(now.texts, "Done") === 3) {
      ticked = now;
      break;
    }
    await sleep(100);
  }
  expect(ticked, "the microphone row ticked within 2 s").not.toBeNull();
  expect(ticked?.buttons).toContainEqual({ name: "Finish", enabled: true });
  read(WELCOME, { Shot: shot("welc-01-ticked") });
});

test.runIf(x64)("WELC-02: Finish closes welcome for good, and it can be reopened", async () => {
  click(WELCOME, "Finish");
  expect(desk("no-window", { ProcessId: pid, Title: WELCOME, Wait: 500 }).appeared).toBe(false);
  expect(JSON.parse(readFileSync(join(data, "settings.json"), "utf8")).onboarded).toBe(true);

  await start();
  expect(desk("no-window", { ProcessId: pid, Title: WELCOME, Wait: 5000 }).appeared).toBe(false);
  choose("Welcome and setup…");
  const again = read(WELCOME, { Name: "Finish" });
  expect(count(again.texts, "Done")).toBe(3);
  desk("close-window", { ProcessId: pid, Title: WELCOME });
});

test.runIf(x64)("MENU-01: Every tray menu item does what it says", async () => {
  const idle = desk("open-menu", { ProcessId: pid, Shot: shot("menu-01-idle") });
  expect(idle.items[0]).toEqual({ name: "Press Ctrl+Shift+Space to dictate", enabled: false });
  desk("dismiss");

  for (const [item, title] of [
    ["Dictation history…", HISTORY],
    ["Settings…", SETTINGS],
  ]) {
    choose(item);
    expect(read(title).texts.length, `${item} opened ${title}`).toBeGreaterThan(1);
    desk("close-window", { ProcessId: pid, Title: title });
  }

  await modelLoaded();
  notepad = dk("notepad").hwnd;
  dk("keys", { Hwnd: notepad, ProcessId: pid });
  const listening = desk("open-menu", { ProcessId: pid, Shot: shot("menu-01-listening") });
  expect(listening.items[0].name).toBe("Listening: press Ctrl+Shift+Space to stop");
  desk("dismiss");
  dk("keys", { Hwnd: notepad, ProcessId: pid });
});

test.runIf(x64)("RECENT-01: Recent shows the last five and copies one", () => {
  desk("open-menu", { ProcessId: pid });
  const recent = desk("submenu", { Item: "Recent", Shot: shot("recent-01-menu") });
  expect(recent.items).toEqual(
    [
      "Thanks for sending the draft over. I think the s…",
      "Can we move Thursday’s call to Friday afternoon?…",
      "Reminder to pick up the dry cleaning and call th…",
      "The headline should say what changes for the rea…",
      "Let’s ship the pricing page first and come back …",
    ].map((name) => ({ name, enabled: true })),
  );
  desk("choose", { Item: recent.items[1].name });
  expect(dk("clipboard").text).toBe(sampleHistory[1].text);
});

test.runIf(x64)(
  "A11Y-01: Every new window works by keyboard and passes the accessibility scan (pictures on Windows)",
  async () => {
    // The scan and keyboard checks run in a browser (screens/accessibility.spec.ts);
    // here each real window is photographed, light and dark, for the try list.
    for (const mode of ["light", "dark"]) {
      desk("theme", { Mode: mode });
      choose("Settings…");
      read(SETTINGS, { Name: "Change", Shot: shot(`b-settings-general-${mode}`) });
      click(SETTINGS, "Dictionary");
      read(SETTINGS, { Name: "+ Add term", Shot: shot(`b-settings-dictionary-${mode}`) });
      desk("close-window", { ProcessId: pid, Title: SETTINGS });
      choose("Dictation history…");
      read(HISTORY, { Name: "Search dictations", Shot: shot(`b-history-${mode}`) });
      desk("close-window", { ProcessId: pid, Title: HISTORY });
      choose("Welcome and setup…");
      read(WELCOME, { Name: "Finish", Shot: shot(`b-welcome-${mode}`) });
      desk("close-window", { ProcessId: pid, Title: WELCOME });
      desk("open-menu", { ProcessId: pid });
      desk("submenu", { Item: "Recent", Shot: shot(`b-tray-menu-${mode}`) });
      desk("dismiss");
      desk("dismiss");
    }
    desk("theme", { Mode: "light" });
  },
);

test.runIf(x64)("SET-05: Start loqui when you sign in (on Windows)", () => {
  const entry = () => ps(`(Get-ItemProperty '${RUN_KEY}' -Name loqui -ErrorAction SilentlyContinue).loqui`).trim();
  // On by default: loqui wrote its sign-in entry when it started.
  expect(entry().toLowerCase()).toBe(`"${installedExe()}"`.toLowerCase());
  choose("Settings…");
  click(SETTINGS, "Start loqui when you sign in");
  expect(entry()).toBe("");
  expect(JSON.parse(readFileSync(join(data, "settings.json"), "utf8")).startAtSignIn).toBe(false);
  click(SETTINGS, "Start loqui when you sign in");
  expect(entry().toLowerCase()).toBe(`"${installedExe()}"`.toLowerCase());
  desk("close-window", { ProcessId: pid, Title: SETTINGS });
});

test.runIf(x64)("HIST-03: History updates while it's open (on Windows)", () => {
  choose("Dictation history…");
  read(HISTORY, { Name: sampleHistory[0].text });
  dk("clear", { Hwnd: notepad });
  const r = dk("dictate", { Hwnd: notepad, ProcessId: pid, Wav: wav }, 180_000);
  expect(r.text).toBe(SENTENCE);
  // It appears without reopening the window (the 1-second promise is timed in
  // the browser check; here each look starts a new PowerShell, which takes longer).
  const shown = read(HISTORY, { Name: SENTENCE, Wait: 3000 });
  expect(shown.texts).toContain(SENTENCE);
  // At the top: before the newest of the six.
  expect(shown.texts.indexOf(SENTENCE)).toBeLessThan(shown.texts.indexOf(sampleHistory[0].text));
  read(HISTORY, { Shot: shot("hist-03-updated") });
  desk("close-window", { ProcessId: pid, Title: HISTORY });
});

test.runIf(x64)("SET-01: Change the shortcut by pressing it (on Windows)", () => {
  const saved = () => JSON.parse(readFileSync(join(data, "settings.json"), "utf8")).shortcut;
  choose("Settings…");
  read(SETTINGS, { Name: "Change" });

  // While recording, the current shortcut is recorded, not dictated with.
  click(SETTINGS, "Change");
  press("ctrl+shift+space");
  expect(dk("state", { ProcessId: pid }).bubble).toBe("loqui hidden");
  read(SETTINGS, { Name: "Current shortcut: Ctrl+Shift+Space" });

  click(SETTINGS, "Change");
  press("shift+a");
  expect(read(SETTINGS, { Name: "Use Ctrl or Alt with a key, or a function key." }).texts).toContain(
    "Use Ctrl or Alt with a key, or a function key.",
  );
  press("ctrl+alt+d");
  read(SETTINGS, { Name: "Current shortcut: Ctrl+Alt+D", Shot: shot("set-01-ctrl-alt-d") });
  expect(saved()).toBe("Ctrl+Alt+D");
  desk("close-window", { ProcessId: pid, Title: SETTINGS });

  // It works at once, and the old one reaches the app instead.
  dk("clear", { Hwnd: notepad });
  const r = dk("dictate", { Hwnd: notepad, ProcessId: pid, Wav: wav, Spec: "ctrl+alt+d" }, 180_000);
  expect(r.text).toBe(SENTENCE);
  expect(dk("keys", { Hwnd: notepad, ProcessId: pid, Spec: "ctrl+shift+space" }).bubble).toBe("loqui hidden");

  // A bare function key is accepted too; then back to the default.
  choose("Settings…");
  click(SETTINGS, "Change");
  press("f8");
  read(SETTINGS, { Name: "Current shortcut: F8" });
  click(SETTINGS, "Change");
  press("ctrl+shift+space");
  read(SETTINGS, { Name: "Current shortcut: Ctrl+Shift+Space" });
  expect(saved()).toBe("Ctrl+Shift+Space");
  desk("close-window", { ProcessId: pid, Title: SETTINGS });
});

test.runIf(x64)("SET-04: Clear history asks first (on Windows)", () => {
  const stats = lines(join(data, "dictation-log.jsonl"));
  choose("Settings…");
  click(SETTINGS, "Clear history…");
  read(SETTINGS, { Name: "Clear all dictation history?", Shot: shot("set-04-confirm") });
  click(SETTINGS, "Cancel");
  expect(lines(join(data, "history.jsonl")).length).toBeGreaterThan(0);

  click(SETTINGS, "Clear history…");
  click(SETTINGS, "Clear");
  desk("close-window", { ProcessId: pid, Title: SETTINGS });
  expect(existsSync(join(data, "history.jsonl"))).toBe(false);
  expect(lines(join(data, "dictation-log.jsonl"))).toEqual(stats);

  choose("Dictation history…");
  read(HISTORY, { Name: "No dictations yet", Shot: shot("hist-02-empty") });
  desk("close-window", { ProcessId: pid, Title: HISTORY });
  desk("open-menu", { ProcessId: pid });
  expect(desk("submenu", { Item: "Recent" }).items).toEqual([{ name: "No dictations yet", enabled: false }]);
  desk("dismiss");
  desk("dismiss");
});
