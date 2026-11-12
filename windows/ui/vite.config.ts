import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { fakeStats } from "./fake-stats";

// The app's version has one home: windows/package.json (tauri.conf.json reads it too).
const { version } = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));

export default defineConfig({
  plugins: [react(), fakeStats()],
  define: { __APP_VERSION__: JSON.stringify(version) },
  clearScreen: false,
  server: { port: 5173, strictPort: true },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    target: "es2022",
    // One page per window: About, the dictation bubble, welcome, settings, history, stats and update.
    rollupOptions: {
      input: Object.fromEntries(
        ["about", "bubble", "welcome", "settings", "history", "stats", "update"].map((page) => [
          page,
          fileURLToPath(new URL(`${page}.html`, import.meta.url)),
        ]),
      ),
    },
  },
});
