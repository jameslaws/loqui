// A stand-in for GitHub during the Windows update checks: serves the files in
// one folder at http://127.0.0.1:8719/ and writes one line per request to
// requests.log beside them. loqui's check builds read their update lists here
// (LOQUI_STABLE_FEED and LOQUI_TEST_FEED in windows.yml). A file
// <name>.delay beside a list holds how many milliseconds to wait before
// answering for it, as a slow connection would.
//
// Usage: node install/feed-server.mjs <folder>
import { appendFileSync, createReadStream, existsSync, readFileSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { basename, join } from "node:path";

export const PORT = 8719;
const folder = process.argv[2];
if (!folder) {
  console.error("Usage: node install/feed-server.mjs <folder>");
  process.exit(1);
}

createServer((request, response) => {
  const name = basename(decodeURIComponent(new URL(request.url ?? "/", "http://x").pathname));
  const file = join(folder, name);
  const found = name !== "requests.log" && existsSync(file) && statSync(file).isFile();
  appendFileSync(join(folder, "requests.log"), `${JSON.stringify({ at: Date.now(), name, found })}\n`);
  if (!found) {
    response.writeHead(404).end();
    return;
  }
  const delay = existsSync(`${file}.delay`) ? Number(readFileSync(`${file}.delay`, "utf8")) : 0;
  setTimeout(() => {
    response.writeHead(200, { "content-length": statSync(file).size });
    createReadStream(file).pipe(response);
  }, delay);
}).listen(PORT, "127.0.0.1", () => console.log(`serving ${folder} at http://127.0.0.1:${PORT}/`));
