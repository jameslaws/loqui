// Installing, updating and uninstalling loqui on GitHub's Windows computers,
// Intel/AMD and Arm, with no person involved. Runs last in the Windows check,
// after WINBASE installed this version and the dictation and screen checks
// used it. windows.yml builds two versions first, both as check builds whose
// update lists are on this computer (install/feed-server.mjs) and signed with
// a throwaway update key: this version (target/installers) and the next one
// (target/next-installers).
//
// The order matters and is the order below: this version's install is looked
// at, its update checks run, it updates itself to the next version, that is
// uninstalled keeping your data, this version is installed again and the next
// one's full installer run over it, and finally it is uninstalled with your data.
import { type ChildProcess, spawn } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { afterAll, beforeAll, expect, test } from "vitest";
import { data, desk, dk, localAppData, ps, windowsDir } from "../e2e/drive";
import { feed } from "../scripts/release/feed.mjs";
import {
  arch,
  checkByHand as check,
  closeUpdateWindow as closeUpdate,
  type Facts,
  facts,
  inst,
  installFromPrompt,
  type Manifest,
  manifestIn,
  quitLoqui,
  shot,
  shots,
  startLoqui,
  waitFor,
  yours,
} from "./helpers";

const onWindows = process.platform === "win32";
const SENTENCE = "Please send the report to Sarah before Friday, and copy the whole team.";
const lists = join(windowsDir, "target", "update-lists");
const LIST = "http://127.0.0.1:8719/";

// The update lists on this computer, and what loqui asked for.
let server: ChildProcess | undefined;
function serve() {
  server = spawn(process.execPath, [join(import.meta.dirname, "feed-server.mjs"), lists], { stdio: "ignore" });
}
async function stopServing() {
  server?.kill();
  server = undefined;
  await sleep(500);
}
const requests = (): { at: number; name: string; found: boolean }[] =>
  existsSync(join(lists, "requests.log"))
    ? readFileSync(join(lists, "requests.log"), "utf8")
        .split("\n")
        .filter(Boolean)
        .map((l) => JSON.parse(l))
    : [];
const listed = (name: string) => requests().filter((r) => r.name === name).length;

function publish(name: "stable.json" | "beta.json", m: Manifest, signature = m.update.signature) {
  const dir = join(windowsDir, "target", m.version === current.version ? "installers" : "next-installers");
  copyFileSync(join(dir, m.update.file), join(lists, m.update.file));
  const list = feed({
    base: LIST,
    notes: `- Version ${m.version}, made by the Windows check`,
    manifests: [{ ...m, update: { ...m.update, signature } }],
  });
  writeFileSync(join(lists, name), JSON.stringify(list));
}

let current: Manifest;
let next: Manifest;
let pid = 0;

const start = async (name: string) => {
  pid = await startLoqui(name);
};
const checkByHand = (expected: string, name: string) => check(pid, expected, name);
const closeUpdateWindow = () => closeUpdate(pid);

/** The settings file, as a person who finished the welcome has it. */
function settings(change: Record<string, unknown>) {
  const file = join(data, "settings.json");
  const now = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {};
  writeFileSync(file, JSON.stringify({ ...now, onboarded: true, ...change }, null, 2));
}

beforeAll(() => {
  if (!onWindows) return;
  mkdirSync(shots, { recursive: true });
  current = manifestIn("installers");
  next = manifestIn("next-installers");
  rmSync(lists, { recursive: true, force: true });
  mkdirSync(lists, { recursive: true });
  quitLoqui();
  desk("ready-desktop");
  // Your data, as someone who has used loqui has it: settings, a dictionary,
  // history and stats (the dictation checks wrote some; these are kept as they are).
  mkdirSync(data, { recursive: true });
  settings({ channel: "stable", startAtSignIn: true });
  const cleanup = join(data, "cleanup.json");
  if (!existsSync(cleanup)) writeFileSync(cleanup, JSON.stringify({ dictionary: { loki: "Loqui" } }));
  for (const [name, line] of [
    ["history.jsonl", { at: "2026-11-01T09:00:00Z", text: "Kept through every update." }],
    ["dictation-log.jsonl", { at: "2026-11-01T09:00:00Z", words: 5, seconds: 2.1 }],
  ] as const) {
    const file = join(data, name);
    if (!existsSync(file)) writeFileSync(file, `${JSON.stringify(line)}\n`);
  }
  serve();
}, 120_000);

afterAll(async () => {
  if (!onWindows) return;
  await stopServing();
  if (existsSync(join(lists, "requests.log")))
    copyFileSync(join(lists, "requests.log"), join(shots, "update-requests.log"));
});

test.runIf(onWindows)("INST-01: It installs for the current user without an administrator", () => {
  // WINBASE installed this version with the full installer's defaults.
  const f = facts();
  expect(f.exe).toBe(true);
  expect(f.appInDataFolder).toBe(false);
  expect(f.installed).toMatchObject({ name: "loqui", version: current.version });
  expect(f.installed?.uninstall.toLowerCase()).toContain(join(localAppData, "Programs", "loqui").toLowerCase());
  expect(f.startMenu.map((l) => l.split("\\").at(-1))).toContain("loqui.lnk");
  // The speech model is in place, with its version, and the engine beside it.
  expect(f.model.version).toMatch(/^[0-9a-f]{64}$/);
  expect(f.model.encoder).not.toBeNull();
  expect(f.engine).toContain("sherpa-onnx-c-api.dll");
  // The installer asks Windows for no more than the person's own rights.
  const setup = join(windowsDir, "target", "installers", current.setup.file);
  expect(inst("run-level", { Installer: setup }).level).toBe("asInvoker");
  // The full installer carries the model; it's the big download.
  expect(current.setup.size).toBeGreaterThan(300 * 1048576);
  // Starting it and the welcome window are WINBASE-01 and 02; a dictation is DICT-01.
});

test.runIf(onWindows)("UPD-04: It checks once a day, and on demand", async () => {
  // Nothing is published yet: no list at all is the same as nothing newer.
  await start("upd-04-start");
  await waitFor("the check as loqui starts", 30_000, () => listed("stable.json") === 1);
  checkByHand("loqui is up to date", "upd-04-up-to-date");
  closeUpdateWindow();
  await sleep(2000);
  // One as it started, one by hand; the next automatic one is a day away
  // (loqui-core's schedule test runs the 24 hours on a fake clock).
  expect(listed("stable.json")).toBe(2);
  expect(listed("beta.json")).toBe(0);
});

test.runIf(onWindows)(
  "UPD-03: Offline, the check fails quietly",
  async () => {
    await stopServing();
    try {
      await offline();
    } finally {
      serve();
    }
  },
  300_000,
);

async function offline() {
  await start("upd-03-start");
  // The check as it starts can't reach the list, and nothing pops up.
  expect(desk("no-window", { ProcessId: pid, Title: "loqui update", Wait: 15_000 }).appeared).toBe(false);
  checkByHand("Couldn't reach the update server. Try again later.", "upd-03-offline");
  closeUpdateWindow();
  // Dictation still works (on Arm there is no microphone; DICT-07 dictates there).
  if (arch === "x64") {
    dk("make-wav", { Text: SENTENCE, Wav: join(windowsDir, "target", "e2e", "offline.wav") });
    const notepad = dk("notepad").hwnd;
    dk("clear", { Hwnd: notepad });
    const r = dk(
      "dictate",
      {
        Hwnd: notepad,
        ProcessId: pid,
        Wav: join(windowsDir, "target", "e2e", "offline.wav"),
        Shot: shot("upd-03-dictated"),
      },
      180_000,
    );
    // It dictated: the sentence's words arrived (the exact wording is DICT-01's to check).
    for (const word of ["send", "report", "Sarah", "Friday", "copy", "team"]) expect(r.text).toContain(word);
    ps("Get-Process notepad -ErrorAction SilentlyContinue | Stop-Process -Force; exit 0");
  }
  expect(facts().processes.map((p) => p.pid)).toContain(pid);
}

test.runIf(onWindows)("CHAN-02: Only PCs with test versions on get them", async () => {
  // The next version is a test version; the public list still has this one.
  publish("stable.json", current);
  publish("beta.json", next);
  await start("chan-02-off");
  checkByHand("loqui is up to date", "chan-02-not-offered");
  closeUpdateWindow();
  expect(listed("beta.json")).toBe(0);

  // Get test versions, switched on in Settings like a teammate would.
  desk("open-menu", { ProcessId: pid });
  desk("choose", { Item: "Settings…" });
  desk("click", { ProcessId: pid, Title: "loqui settings", Name: "Get test versions" });
  desk("window", {
    ProcessId: pid,
    Title: "loqui settings",
    Name: "Get test versions",
    Shot: shot("chan-02-switch-on"),
  });
  desk("close-window", { ProcessId: pid, Title: "loqui settings" });
  expect(JSON.parse(readFileSync(join(data, "settings.json"), "utf8")).channel).toBe("test");
  checkByHand("A new version of loqui is ready", "chan-02-offered");
  closeUpdateWindow();
  expect(listed("beta.json")).toBe(1);
});

test.runIf(onWindows)("UPD-02: An update with a bad signature is refused", async () => {
  // The next version's file, with this version's signature: a file loqui's key didn't sign.
  publish("beta.json", next, current.update.signature);
  const r = checkByHand("A new version of loqui is ready", "upd-02-offered");
  expect(r.texts.join(" ")).toContain(`loqui ${next.version} is available. You have ${current.version}.`);
  desk("click", { ProcessId: pid, Title: "loqui update", Name: "Install and restart loqui" });
  desk("window", {
    ProcessId: pid,
    Title: "loqui update",
    Name: "This update couldn't be verified, so it wasn't installed.",
    Wait: 120_000,
    Shot: shot("upd-02-refused"),
  });
  closeUpdateWindow();
  const f = facts();
  expect(f.installed?.version).toBe(current.version);
  expect(f.processes.map((p) => p.pid)).toContain(pid);
});

test.runIf(onWindows)(
  "UPD-01: A newer version installs from the prompt",
  async () => {
    publish("beta.json", next);
    const before = facts();
    expect(next.update.size).toBeLessThan(30 * 1048576);
    const r = checkByHand("A new version of loqui is ready", "upd-01-prompt");
    const said = r.texts.join(" ");
    expect(said).toContain(`loqui ${next.version} is available. You have ${current.version}.`);
    expect(said).toContain(`Version ${next.version}, made by the Windows check`);
    expect(said).toContain(`The download is about ${Math.max(1, Math.round(next.update.size / 1048576))} MB`);
    // loqui closes, the update installs, and the new version starts by itself.
    const after = await installFromPrompt(pid, next.version);
    pid = after.processes.find((p) => p.pid !== pid)?.pid ?? 0;
    desk("screenshot", { Shot: shot("upd-01-restarted") });
    expect(after.processes[0].path.toLowerCase()).toBe(
      join(localAppData, "Programs", "loqui", "loqui.exe").toLowerCase(),
    );
    // Settings, dictionary, history, stats and the model untouched.
    expect(yours(after)).toEqual(yours(before));
    expect(after.model).toEqual(before.model);
    expect(after.startMenu).toEqual(before.startMenu);

    // CHAN-02's end: turning test versions off offers nothing older.
    settings({ channel: "stable" });
    await start("upd-01-switch-off");
    checkByHand("loqui is up to date", "chan-02-off-again");
    closeUpdateWindow();
  },
  400_000,
);

test.runIf(onWindows)(
  "INST-02: Uninstall asks about your data (Keep)",
  async () => {
    // Closed first, as a person would; a running loqui makes the uninstaller ask to close it.
    quitLoqui();
    await sleep(1000);
    const before = facts();
    const r = inst("uninstall", { Shot: shot("inst-02-keep") });
    expect(r.boxAtFirst).toBe("Off");
    const f: Facts = r.facts;
    expect(f.exe).toBe(false);
    expect(f.folder).toBe(false);
    expect(f.model.version).toBeNull();
    expect(f.installed).toBeNull();
    expect(f.startMenu).toEqual([]);
    expect(f.run).toBeFalsy();
    expect(f.processes).toEqual([]);
    expect(yours(f)).toEqual(yours(before));
  },
  300_000,
);

test.runIf(onWindows)(
  "INST-03: Installing over an older version keeps everything",
  () => {
    const older = inst("install", { Installer: join(windowsDir, "target", "installers", current.setup.file) });
    expect(older.exitCode).toBe(0);
    expect(older.facts.installed.version).toBe(current.version);
    const before: Facts = older.facts;
    quitLoqui();

    const newer = inst("install", { Installer: join(windowsDir, "target", "next-installers", next.setup.file) });
    expect(newer.exitCode).toBe(0);
    const after: Facts = newer.facts;
    expect(after.installed?.version).toBe(next.version);
    expect(yours(after)).toEqual(yours(before));
    // The model's version file matched, so not a byte of it was copied again.
    expect(after.model).toEqual(before.model);
    expect(after.model.version).not.toBeNull();
  },
  600_000,
);

test.runIf(onWindows)(
  "INST-02: Uninstall asks about your data (Delete)",
  () => {
    quitLoqui();
    const r = inst("uninstall", { Delete: true, Shot: shot("inst-02-delete") });
    expect(r.boxWhenUninstalled).toBe("On");
    const f: Facts = r.facts;
    expect(f.exe).toBe(false);
    expect(f.installed).toBeNull();
    expect(f.startMenu).toEqual([]);
    expect(f.run).toBeFalsy();
    expect(f.processes).toEqual([]);
    expect(f.data).toEqual([]);
    expect(existsSync(data)).toBe(false);
  },
  300_000,
);
