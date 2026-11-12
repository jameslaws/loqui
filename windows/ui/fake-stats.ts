import { type ChildProcessWithoutNullStreams, spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import type { Plugin } from "vite";

/**
 * For the screens in a plain browser: the stats window's figures come from
 * loqui-core itself (crates/loqui-core/examples/stats_server.rs), never from a
 * copy of its rules in TypeScript. The browser stand-in posts to
 * `/__fake/stats`; this answers with the shared sample record
 * (shared/stats-cases.json), its fixed time now and time zone, plus any
 * dictations the stand-in made. Only while Vite serves pages, never in the app.
 */
export function fakeStats(): Plugin {
  const windowsDir = new URL("..", import.meta.url);
  const sample = JSON.parse(readFileSync(new URL("../shared/stats-cases.json", windowsDir), "utf8"));
  let server: ChildProcessWithoutNullStreams | null = null;
  const waiting: ((line: string) => void)[] = [];

  const ask = (request: string): Promise<string> => {
    if (!server) {
      server = spawn("cargo", ["run", "-q", "-p", "loqui-core", "--example", "stats_server"], {
        cwd: windowsDir,
        shell: process.platform === "win32",
      });
      server.stderr.pipe(process.stderr);
      createInterface({ input: server.stdout }).on("line", (line) => waiting.shift()?.(line));
      // No Rust here, or it stopped: every waiting screen says so, and the next ask tries again.
      const gone = (why: string) => {
        server = null;
        for (const answer of waiting.splice(0))
          answer(JSON.stringify({ error: `loqui-core's stats server isn't running (${why})` }));
      };
      server.on("error", (e) => gone(e.message));
      server.on("exit", (code) => gone(`it stopped with code ${code}`));
    }
    const answered = new Promise<string>((resolve) => waiting.push(resolve));
    server.stdin.write(`${request.replace(/\n/g, " ")}\n`);
    return answered;
  };

  return {
    name: "loqui-fake-stats",
    apply: "serve",
    configureServer(vite) {
      vite.httpServer?.on("close", () => server?.kill());
      vite.middlewares.use("/__fake/stats", (req, res) => {
        let body = "";
        req.on("data", (chunk) => {
          body += chunk;
        });
        req.on("end", async () => {
          const { request, empty, added, shortcut } = JSON.parse(body);
          // The stand-in's dictations happen at the sample's time now.
          const made = added.map((d: { words: number; seconds: number }) => JSON.stringify({ at: sample.now, ...d }));
          const log = [...(empty ? [] : sample.log), ...made].join("\n");
          const reply = JSON.parse(
            await ask(
              JSON.stringify({
                log,
                now: sample.now,
                timeZone: sample.timeZone,
                firstWeekday: sample.firstWeekday,
                shortcut,
                request,
              }),
            ),
          );
          res.statusCode = reply.ok ? 200 : 500;
          res.setHeader("Content-Type", "application/json");
          res.end(JSON.stringify(reply.ok ?? reply.error));
        });
      });
    },
  };
}
