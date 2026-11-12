import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    projects: [
      // Run anywhere: the shared rules, the look and the project records.
      { test: { name: "contracts", include: ["tests/**/*.test.ts"] } },
      // Run on Windows only, against the installed test build.
      {
        test: {
          name: "acceptance",
          include: ["acceptance/**/*.test.ts"],
          testTimeout: 120_000,
          fileParallelism: false,
        },
      },
      // Windows only, after the acceptance checks: real dictations into Notepad.
      {
        test: {
          name: "e2e",
          include: ["e2e/dictation.test.ts"],
          testTimeout: 180_000,
          hookTimeout: 600_000,
          fileParallelism: false,
        },
      },
      // Windows only, after the dictations: the real welcome, settings and
      // history windows, the tray menu, and their pictures light and dark.
      {
        test: {
          name: "windows-screens",
          include: ["e2e/windows-screens.test.ts"],
          testTimeout: 180_000,
          hookTimeout: 300_000,
          fileParallelism: false,
        },
      },
      // Windows only, last: install, update and uninstall, with this version
      // and the next one built as check builds (see install/install.test.ts).
      {
        test: {
          name: "install",
          include: ["install/**/*.test.ts"],
          testTimeout: 300_000,
          hookTimeout: 300_000,
          fileParallelism: false,
          sequence: { concurrent: false },
        },
      },
    ],
  },
});
