// What the README, security policy, roadmap and contributing notes say about
// Windows, and that the Windows download page is the one Promote writes.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "vitest";
import { downloadPage } from "../scripts/release/download-page.mjs";

const root = join(import.meta.dirname, "../..");
const read = (file: string) => readFileSync(join(root, file), "utf8").replaceAll("\r\n", "\n");
/** A `## Heading` section of a Markdown file, up to the next one. */
const section = (text: string, heading: string) => {
  const body = text.split(`\n## ${heading}\n`)[1];
  if (body === undefined) throw new Error(`no "## ${heading}" section`);
  return body.split("\n## ")[0];
};

test("LAUNCH-05: The README covers Windows", () => {
  const readme = read("README.md");
  const opening = readme.split("\n## ")[0];
  expect(opening).not.toMatch(/macOS menu-bar|macOS only/);
  expect(opening).toContain("Mac and Windows");

  const install = section(readme, "Install");
  expect(install).toContain("https://jameslaws.github.io/loqui/windows/download.html");
  expect(install).toContain("no administrator");
  expect(install).toContain("isn't signed by Microsoft yet");
  for (const words of ["Windows protected your PC", "More info", "Run anyway", "Smart App Control"]) {
    expect(install).toContain(words);
  }

  expect(section(readme, "Permissions")).toContain("Let desktop apps access your microphone");

  const privacy = section(readme, "Privacy");
  for (const file of ["%LOCALAPPDATA%\\Loqui", "history.jsonl", "dictation-log.jsonl", "logs\\voice-key.log"]) {
    expect(privacy).toContain(file);
  }
  // Both update lists, as the only network requests.
  expect(privacy).toContain("https://jameslaws.github.io/loqui/windows/stable.json");
  expect(privacy).toContain("https://github.com/jameslaws/loqui/releases/download/windows-test-feed/beta.json");
  expect(privacy).toMatch(/only network requests loqui for Windows makes are for updates/);

  const security = section(readme, "Security model");
  expect(security).toContain("WH_KEYBOARD_LL");
  expect(security).toMatch(/acts\s+only on that/);
  expect(security).toContain("no administrator rights");
  expect(security).toContain("isn't signed by Microsoft yet");

  const uninstall = section(readme, "Uninstall");
  expect(uninstall).toContain("Installed apps");
  expect(uninstall).toContain("also delete your dictation history, dictionary,\nsettings and stats");

  expect(section(readme, "Requirements")).toContain("Windows 11, on Intel, AMD and Arm");

  const development = section(readme, "Development");
  for (const command of ["pnpm install", "pnpm fetch:speech", "pnpm build"]) expect(development).toContain(command);

  // Nothing claims a publisher while loqui isn't signed by Microsoft.
  expect(readme.toLowerCase()).not.toMatch(/publisher(?! yet)(?!,)/);
});

test("LAUNCH-06: Security policy, roadmap and contributing cover Windows", () => {
  const scope = section(read("SECURITY.md"), "Scope");
  expect(scope).toContain("keyboard watcher");
  expect(scope).toContain("Windows update chain");
  expect(scope).toContain("clipboard");
  expect(section(read("SECURITY.md"), "Reporting a vulnerability")).toMatch(/macOS or Windows version/);

  expect(section(read("ROADMAP.md"), "Shipped")).toContain("Loqui for Windows");

  const windows = section(read("CONTRIBUTING.md"), "The Windows app");
  for (const command of ["pnpm check", "pnpm test:screens", "pnpm build"]) expect(windows).toContain(command);
  expect(windows).toContain("GitHub's Windows computers");
});

test("LAUNCH-08: The Windows download page is the one Promote writes", () => {
  const page = read("docs/windows/download.html");
  const list = join(root, "docs/windows/stable.json");
  if (!existsSync(list)) {
    // Before the first public version: the waiting page, never a dead link.
    expect(page).toBe(downloadPage(null));
    return;
  }
  // After a Promote: the page starts the full installers of the version the list offers.
  const { version } = JSON.parse(readFileSync(list, "utf8"));
  for (const arch of ["x64", "arm64"]) {
    expect(page).toContain(
      `https://github.com/jameslaws/loqui/releases/download/windows-v${version}/loqui-setup-${version}-${arch}.exe`,
    );
  }
});
