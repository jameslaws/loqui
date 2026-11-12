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
          include: ["e2e/**/*.test.ts"],
          testTimeout: 180_000,
          hookTimeout: 600_000,
          fileParallelism: false,
        },
      },
    ],
  },
});
