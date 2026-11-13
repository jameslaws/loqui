import { defineConfig } from "@playwright/test";

// The download page (docs/) opened straight from its files, as Windows, Mac
// and phone visitors, light and dark. Runs on the Mini and on GitHub's Linux
// computers; needs nothing built.
export default defineConfig({
  testDir: "page",
  fullyParallel: true,
  forbidOnly: true,
  reporter: [["list"]],
  use: { locale: "en-US" },
  projects: [
    { name: "light", use: { colorScheme: "light" } },
    { name: "dark", use: { colorScheme: "dark" } },
  ],
});
