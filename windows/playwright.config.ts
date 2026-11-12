import { defineConfig } from "@playwright/test";

// The screens in a plain browser against loqui's in-memory stand-in
// (ui/src/fake-backend.ts): runs on the Mini and on GitHub's Linux computers.
// The Windows check photographs the real windows separately.
export default defineConfig({
  testDir: "screens",
  fullyParallel: true,
  forbidOnly: true,
  reporter: [["list"]],
  use: {
    baseURL: "http://localhost:5174",
    locale: "en-US",
    timezoneId: "America/New_York",
    viewport: { width: 680, height: 820 },
  },
  projects: [
    { name: "light", use: { colorScheme: "light" } },
    { name: "dark", use: { colorScheme: "dark" } },
  ],
  webServer: {
    // The stats screen's figures come from loqui-core (ui/fake-stats.ts): built first.
    command: "cargo build -q -p loqui-core --example stats_server && pnpm exec vite ui --port 5174 --strictPort",
    url: "http://localhost:5174/settings.html",
    reuseExistingServer: false,
    timeout: 300_000,
  },
});
