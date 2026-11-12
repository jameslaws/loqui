import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// The app's version has one home: windows/package.json (tauri.conf.json reads it too).
const { version } = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));

export default defineConfig({
  plugins: [react()],
  define: { __APP_VERSION__: JSON.stringify(version) },
  clearScreen: false,
  server: { port: 5173, strictPort: true },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    target: "es2022",
    // Two pages: the About window and the dictation bubble.
    rollupOptions: {
      input: {
        about: fileURLToPath(new URL("index.html", import.meta.url)),
        bubble: fileURLToPath(new URL("bubble.html", import.meta.url)),
      },
    },
  },
});
