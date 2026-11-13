// What a Windows release says on GitHub, and what the update window shows as
// "What's new". While loqui isn't signed by Microsoft, every release opens
// with how to get past Windows' SmartScreen notice (SIGN-01), and nothing
// claims a publisher.
//
//   node scripts/release/notes.mjs changes <since tag or "">     the "- " lines since that tag
//   node scripts/release/notes.mjs page <version> <test|public> <signed|unsigned> <changes file>

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

/** The steps past "Windows protected your PC", while loqui isn't signed. */
export const SMARTSCREEN = [
  "**loqui isn't signed by Microsoft yet.** The first time you run the installer, Windows shows **“Windows protected your PC”**. Click **More info**, then **Run anyway**.",
  "If Windows' **Smart App Control** is turned on, it blocks apps that aren't signed and there is no Run anyway, so loqui can't be installed on that PC for now.",
].join("\n\n");

/** The page on GitHub for one version. */
export function releasePage({ version, test, signed, changes }) {
  const parts = [];
  if (!signed) parts.push(SMARTSCREEN);
  if (test) {
    parts.push(
      "This is a **test version** of loqui for Windows, for trying it before everyone else. After installing, turn on **Get test versions** in loqui's Settings to get each new test version by itself.",
    );
  }
  parts.push(
    [
      "**Which file to download:**",
      `- Most PCs (Intel or AMD): \`loqui-setup-${version}-x64.exe\``,
      `- Arm PCs (Snapdragon, such as Surface Pro 11): \`loqui-setup-${version}-arm64.exe\``,
      "",
      "It installs just for you, with no administrator needed, on Windows 11. The `loqui-update-…` files are for loqui's automatic updates; you don't need to download them.",
    ].join("\n"),
  );
  parts.push(`## What's new\n\n${changes.trim() || "- Small fixes."}`);
  return `${parts.join("\n\n")}\n`;
}

/** Commit subjects that touched the Windows app since `since` (a tag), as "- " lines, newest first. */
export function changesSince(since, max = 15) {
  const range = since ? [`${since}..HEAD`] : ["HEAD"];
  const subjects = execFileSync("git", ["log", "--no-merges", "--format=%s", ...range, "--", "windows/", "shared/"], {
    encoding: "utf8",
    maxBuffer: 1 << 24,
  })
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
  if (!since) return "- The first test version of loqui for Windows.";
  const shown = subjects.slice(0, max).map((s) => `- ${s}`);
  if (subjects.length > max) shown.push(`- And ${subjects.length - max} more changes.`);
  return shown.join("\n");
}

if (process.argv[1] && import.meta.filename === resolve(process.argv[1])) {
  const [command, ...rest] = process.argv.slice(2);
  if (command === "changes") process.stdout.write(`${changesSince(rest[0] ?? "")}\n`);
  else if (command === "page" && rest.length === 4) {
    const [version, kind, signing, changesFile] = rest;
    process.stdout.write(
      releasePage({
        version,
        test: kind === "test",
        signed: signing === "signed",
        changes: readFileSync(changesFile, "utf8"),
      }),
    );
  } else {
    console.error(
      "Usage: notes.mjs changes <since tag> | page <version> <test|public> <signed|unsigned> <changes file>",
    );
    process.exit(1);
  }
}
