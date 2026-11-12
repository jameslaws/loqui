// The drill's PC (windows-drill.yml): one of GitHub's Windows computers acting
// as a person's PC on the drill's public list. It installs drill version A
// from its GitHub release, finishes the welcome, dictates three times, and
// updates itself to B once B is promoted, then to the roll back once that is
// promoted. Every connection loqui opens is listed throughout (PRIV-03).
// Runs only in the drill, which sets DRILL_A, DRILL_B and DRILL_LIST.
import { execFileSync, spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { afterAll, beforeAll, expect, test } from "vitest";
import { data, desk, dk, windowsDir } from "../e2e/drive";
import { compare } from "../scripts/release/version.mjs";
import { checkByHand, facts, inst, installFromPrompt, quitLoqui, shot, shots, startLoqui, yours } from "./helpers";

const { DRILL_A: A = "", DRILL_B: B = "", DRILL_LIST: LIST = "" } = process.env;
const drill = process.platform === "win32" && A !== "";
const repo = process.env.GITHUB_REPOSITORY ?? "jameslaws/loqui";
const work = join(windowsDir, "target", "drill");
const connections = join(shots, "priv-03-connections.jsonl");
const stopWatching = join(work, "stop-watching");
const SENTENCE = "Please send the report to Sarah before Friday, and copy the whole team.";

/** When loqui was meant to be online: [from, to] in ms, with what for. */
const online: { from: number; to: number; why: string }[] = [];
/** When it dictated, and must have been offline. */
const dictating: { from: number; to: number }[] = [];
let pid = 0;
let notepad = 0;

/** The version the drill's public list offers now. */
async function listed() {
  const r = await fetch(LIST, { cache: "no-store" });
  return r.ok ? ((await r.json()) as { version: string }).version : "";
}

/** loqui starts and checks its list: online for the next 30 seconds. */
async function start(name: string) {
  const from = Date.now();
  pid = await startLoqui(name);
  online.push({ from, to: Date.now() + 30_000, why: `the check as loqui starts (${name})` });
}

function dictate(name: string) {
  const wav = join(work, "sentence.wav");
  if (!existsSync(wav)) dk("make-wav", { Text: SENTENCE, Wav: wav });
  if (!notepad) notepad = dk("notepad").hwnd;
  dk("clear", { Hwnd: notepad });
  const from = Date.now();
  const r = dk("dictate", { Hwnd: notepad, ProcessId: pid, Wav: wav, Shot: shot(name) }, 180_000);
  dictating.push({ from, to: Date.now() });
  return r.text as string;
}

beforeAll(async () => {
  if (!drill) return;
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  mkdirSync(shots, { recursive: true });
  quitLoqui();
  // A person's PC: no loqui, no loqui data.
  rmSync(data, { recursive: true, force: true });
  desk("ready-desktop");
  execFileSync(
    "gh",
    [
      "release",
      "download",
      `windows-drill-v${A}`,
      "--repo",
      repo,
      "--pattern",
      `loqui-setup-${A}-x64.exe`,
      "--dir",
      work,
    ],
    { stdio: "inherit" },
  );
  rmSync(stopWatching, { force: true });
  const ps1 = join(import.meta.dirname, "installer.ps1");
  spawn(
    "powershell.exe",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      ps1,
      "net-watch",
      "-Out",
      connections,
      "-StopFile",
      stopWatching,
    ],
    {
      stdio: "ignore",
    },
  );
}, 600_000);

afterAll(() => {
  if (!drill) return;
  writeFileSync(stopWatching, "");
  quitLoqui();
});

test.runIf(drill)(
  "INST-01: A downloaded from GitHub installs, starts and dictates",
  async () => {
    const installed = inst("install", { Installer: join(work, `loqui-setup-${A}-x64.exe`) });
    expect(installed.exitCode).toBe(0);
    expect(installed.facts.installed.version).toBe(A);
    await start("drill-a-start");
    // The welcome opens on a first start; the microphone is allowed, so Finish.
    desk("window", { ProcessId: pid, Title: "Welcome to loqui", Name: "Finish", Wait: 30_000 });
    desk("click", { ProcessId: pid, Title: "Welcome to loqui", Name: "Finish" });
    for (const n of [1, 2, 3]) expect(dictate(`drill-a-dictation-${n}`)).toBe(SENTENCE);
  },
  600_000,
);

/** Once the drill's promote puts the wanted version on the list: check by hand, install, restart. */
async function moveTo(wanted: (v: string) => boolean, name: string) {
  let offered = await listed();
  for (let i = 0; i < 120 && !wanted(offered); i++) {
    await sleep(30_000);
    offered = await listed();
  }
  expect(wanted(offered), `the drill list offers ${offered}`).toBe(true);
  const from = Date.now();
  const r = checkByHand(pid, "A new version of loqui is ready", `${name}-offered`);
  expect(r.texts.join(" ")).toContain(`loqui ${offered} is available.`);
  const before = facts();
  const after = await installFromPrompt(pid, offered);
  pid = after.processes.find((p) => p.pid !== pid)?.pid ?? 0;
  online.push({ from, to: Date.now() + 30_000, why: `checking for and downloading ${offered}` });
  desk("screenshot", { Shot: shot(`${name}-restarted`) });
  expect(yours(after)).toEqual(yours(before));
  expect(after.model).toEqual(before.model);
  return offered;
}

test.runIf(drill)(
  "CHAN-03: Promote publishes the exact files James tried (the PC on A gets B)",
  async () => {
    const got = await moveTo((v) => v === B, "drill-b");
    expect(got).toBe(B);
    // Tell the drill the PC is on B, so the roll back can start.
    writeFileSync(join(work, `pc-on-${B}.txt`), `on ${B}\n`);
    execFileSync(
      "gh",
      ["release", "upload", "windows-drill-feed", join(work, `pc-on-${B}.txt`), "--repo", repo, "--clobber"],
      {
        stdio: "inherit",
      },
    );
  },
  70 * 60_000,
);

test.runIf(drill)(
  "CHAN-04: Roll back moves every PC to the last good version",
  async () => {
    const got = await moveTo((v) => v !== "" && compare(v, B) > 0, "drill-rollback");
    expect(compare(got, B)).toBeGreaterThan(0);
    expect(compare(got, "0.1.0")).toBeLessThan(0);
    // It behaves as A: it dictates as A did (the drill's last job checks it was built from A's code).
    expect(dictate("drill-rollback-dictation")).toBe(SENTENCE);
  },
  70 * 60_000,
);

test.runIf(drill)("PRIV-03: The update check is the only network use", async () => {
  writeFileSync(stopWatching, "");
  await sleep(1500);
  const seen: { at: number; remote: string; port: number; process: string }[] = existsSync(connections)
    ? readFileSync(connections, "utf8")
        .split("\n")
        .filter(Boolean)
        .map((l) => JSON.parse(l))
    : [];
  const names: Record<string, string[]> = inst("names");
  const local = /^(127\.|::1$|0\.0\.0\.0$|::$)/;
  const outside = seen.filter((c) => !local.test(c.remote)).map((c) => ({ ...c, names: names[c.remote] ?? [] }));
  writeFileSync(join(shots, "priv-03-outside.json"), JSON.stringify({ outside, online, dictating }, null, 2));
  console.log(`PRIV-03: ${seen.length} connections, ${outside.length} outside this PC`);
  // There were some: the checks and downloads really went to GitHub.
  expect(outside.length).toBeGreaterThan(0);
  const github = /(^|\.)(github\.com|githubusercontent\.com|github\.io)$/;
  for (const c of outside) {
    expect(c.port, `${c.remote} by ${c.process}`).toBe(443);
    expect(
      c.names.some((n) => github.test(n)),
      `${c.remote} (${c.names.join(", ") || "no name"}) is GitHub's`,
    ).toBe(true);
    expect(
      online.some((w) => c.at >= w.from - 2000 && c.at <= w.to),
      `${c.remote} at ${new Date(c.at).toISOString()} was during a check or download`,
    ).toBe(true);
    expect(dictating.some((d) => c.at >= d.from && c.at <= d.to)).toBe(false);
  }
});
