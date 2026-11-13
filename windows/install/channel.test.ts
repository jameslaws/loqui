// The real test channel, end to end (windows-channel.yml): one of GitHub's
// Windows computers acts as a teammate's PC. It downloads the test version
// from the link teammates are given, installs it, dictates, switches on Get
// test versions in Settings, and updates itself when the next test version
// reaches the test list. Runs only there, which sets CHANNEL_FROM (the version
// the teammate link installs).
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { afterAll, beforeAll, expect, test } from "vitest";
import { data, desk, dk, windowsDir } from "../e2e/drive";
import { compare } from "../scripts/release/version.mjs";
import { checkByHand, facts, inst, installFromPrompt, quitLoqui, shot, shots, startLoqui, yours } from "./helpers";

const { CHANNEL_FROM: FROM = "" } = process.env;
const channel = process.platform === "win32" && FROM !== "";
const repo = process.env.GITHUB_REPOSITORY ?? "jameslaws/loqui";
const TEST_LIST = `https://github.com/${repo}/releases/download/windows-test-feed/beta.json`;
/** The link a teammate is given, and the file they download from it. */
const PAGE = `https://github.com/${repo}/releases/tag/windows-v${FROM}-test`;
const SETUP = `https://github.com/${repo}/releases/download/windows-v${FROM}-test/loqui-setup-${FROM}-x64.exe`;
const work = join(windowsDir, "target", "channel");
const SENTENCE = "Please send the report to Sarah before Friday, and copy the whole team.";
let pid = 0;
let notepad = 0;

async function listed() {
  const r = await fetch(TEST_LIST, { cache: "no-store" });
  return r.ok ? ((await r.json()) as { version: string }).version : "";
}

function dictate(name: string) {
  const wav = join(work, "sentence.wav");
  dk("make-wav", { Text: SENTENCE, Wav: wav });
  if (!notepad) notepad = dk("notepad").hwnd;
  dk("clear", { Hwnd: notepad });
  return dk("dictate", { Hwnd: notepad, ProcessId: pid, Wav: wav, Shot: shot(name) }, 180_000).text as string;
}

beforeAll(() => {
  if (!channel) return;
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  mkdirSync(shots, { recursive: true });
  quitLoqui();
  // A teammate's PC: no loqui, no loqui data.
  rmSync(data, { recursive: true, force: true });
  desk("ready-desktop");
}, 300_000);

afterAll(() => {
  if (channel) quitLoqui();
});

test.runIf(channel)(
  "INST-01: It installs for the current user without an administrator (from the teammate link)",
  async () => {
    // The page a teammate opens, and the installer it offers, with no sign-in.
    const page = await (await fetch(PAGE)).text();
    expect(page).toContain(`loqui-setup-${FROM}-x64.exe`);
    const file = join(work, `loqui-setup-${FROM}-x64.exe`);
    execFileSync("curl.exe", ["-fsSL", "-o", file, SETUP], { stdio: "inherit" });

    const installed = inst("install", { Installer: file });
    expect(installed.exitCode).toBe(0);
    expect(installed.facts.installed.version).toBe(FROM);
    pid = await startLoqui("channel-start");
    desk("window", { ProcessId: pid, Title: "Welcome to loqui", Name: "Finish", Wait: 30_000 });
    desk("click", { ProcessId: pid, Title: "Welcome to loqui", Name: "Finish" });
    expect(dictate("channel-dictation")).toBe(SENTENCE);
  },
  900_000,
);

test.runIf(channel)(
  "UPD-01: A newer version installs from the prompt (the next test version, with Get test versions on)",
  async () => {
    desk("open-menu", { ProcessId: pid });
    desk("choose", { Item: "Settings…" });
    desk("click", { ProcessId: pid, Title: "loqui settings", Name: "Get test versions" });
    desk("window", {
      ProcessId: pid,
      Title: "loqui settings",
      Name: "Get test versions",
      Shot: shot("channel-switch-on"),
    });
    desk("close-window", { ProcessId: pid, Title: "loqui settings" });
    expect(JSON.parse(readFileSync(join(data, "settings.json"), "utf8")).channel).toBe("test");

    // Wait for the next merge into staging to become a test version (up to two hours).
    let offered = await listed();
    for (let i = 0; i < 240 && !(offered && compare(offered, FROM) > 0); i++) {
      await sleep(30_000);
      offered = await listed();
    }
    expect(compare(offered, FROM), `the test list offers ${offered}`).toBeGreaterThan(0);
    console.log(`The test list offers ${offered}; checking for updates as a teammate would.`);

    const r = checkByHand(pid, "A new version of loqui is ready", "channel-offered");
    expect(r.texts.join(" ")).toContain(`loqui ${offered} is available.`);
    const before = facts();
    const after = await installFromPrompt(pid, offered);
    pid = after.processes.find((p) => p.pid !== pid)?.pid ?? 0;
    desk("screenshot", { Shot: shot("channel-updated") });
    expect(after.installed?.version).toBe(offered);
    expect(yours(after)).toEqual(yours(before));
    expect(after.model).toEqual(before.model);
    expect(dictate("channel-after-update")).toBe(SENTENCE);
  },
  150 * 60_000,
);
