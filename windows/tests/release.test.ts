// The release steps' rules that can be checked on any computer: what every
// release says while loqui isn't signed, the update list's shape, and the
// version numbers. The workflows themselves run on GitHub (windows-release,
// windows-promote, windows-rollback and the drill).
import { expect, test } from "vitest";
import { feed } from "../scripts/release/feed.mjs";
import { releasePage, SMARTSCREEN } from "../scripts/release/notes.mjs";
import { compare, next } from "../scripts/release/version.mjs";

const changes = "- Settings opens 640 tall\n- Updates by itself";

test("SIGN-01: Without Microsoft signing, every release says how to get past SmartScreen", () => {
  for (const test of [true, false]) {
    const page = releasePage({ version: "0.0.3", test, signed: false, changes });
    // The SmartScreen steps come first, before anything else on the page.
    expect(page.startsWith(SMARTSCREEN)).toBe(true);
    for (const words of ["Windows protected your PC", "More info", "Run anyway", "Smart App Control"]) {
      expect(page).toContain(words);
    }
    expect(page).toContain("loqui-setup-0.0.3-x64.exe");
    expect(page).toContain("loqui-setup-0.0.3-arm64.exe");
    expect(page).toContain("no administrator");
    expect(page).toContain(changes);
    // Nothing claims a publisher while it isn't signed.
    expect(page.toLowerCase()).not.toContain("publisher");
    expect(page.toLowerCase()).not.toMatch(/(?<!n't )signed by/);
  }
  // Once signed, the steps go.
  expect(releasePage({ version: "0.1.0", test: false, signed: true, changes })).not.toContain("Run anyway");
});

test("CHAN-01: A test version's page says how to keep getting test versions", () => {
  expect(releasePage({ version: "0.0.3", test: true, signed: false, changes })).toContain("Get test versions");
  expect(releasePage({ version: "0.1.0", test: false, signed: false, changes })).not.toContain("test version");
});

test("UPD-01: The update list names each kind of PC's update installer, signature and size", () => {
  const list = feed({
    base: "https://github.com/jameslaws/loqui/releases/download/windows-v0.0.3-test/",
    notes: changes,
    date: "2026-11-12T20:00:00.123Z",
    manifests: ["x64", "arm64"].map((arch) => ({
      version: "0.0.3",
      arch,
      update: { file: `loqui-update-0.0.3-${arch}.exe`, size: 12_000_000, signature: `sig-${arch}` },
    })),
  });
  expect(list).toEqual({
    version: "0.0.3",
    notes: changes,
    pub_date: "2026-11-12T20:00:00Z",
    platforms: {
      "windows-x86_64": {
        url: "https://github.com/jameslaws/loqui/releases/download/windows-v0.0.3-test/loqui-update-0.0.3-x64.exe",
        signature: "sig-x64",
        size: 12_000_000,
      },
      "windows-aarch64": {
        url: "https://github.com/jameslaws/loqui/releases/download/windows-v0.0.3-test/loqui-update-0.0.3-arm64.exe",
        signature: "sig-arm64",
        size: 12_000_000,
      },
    },
  });
  // One version per list, and never a list without the update key's signature.
  expect(() =>
    feed({
      base: "b/",
      notes: "",
      manifests: [{ version: "0.0.3", arch: "x64" } as never],
    }),
  ).toThrow(/update installer/);
});

test("CHAN-04: Version numbers only go up, a patch at a time", () => {
  expect(next("0.0.9")).toBe("0.0.10");
  expect(compare("0.0.10", "0.0.9")).toBeGreaterThan(0);
  expect(compare("0.1.0", "0.0.99")).toBeGreaterThan(0);
  expect(compare("0.0.3", "0.0.3")).toBe(0);
  expect(() => next("0.1")).toThrow();
});
