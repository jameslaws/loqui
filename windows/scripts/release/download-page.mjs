// docs/windows/download.html: where the download page's "Download for Windows"
// button goes. It starts the current public version's full installer (the Arm
// one on an Arm PC) and says how to get past SmartScreen while loqui isn't
// signed. Promote writes it, in the same commit as stable.json, from the
// manifests of the files it published; before the first public version it
// says the download is on its way (LAUNCH-08).
//
//   node scripts/release/download-page.mjs <base url> <signed|unsigned> <manifest.json>... > download.html
//   node scripts/release/download-page.mjs waiting > download.html

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const RELEASES = "https://github.com/jameslaws/loqui/releases";

/**
 * The page for one public version, or the waiting page when there's none yet.
 * @param {{ base: string, signed: boolean, manifests: Array<{version: string, arch: string, setup: {file: string, size: number}}> } | null} release
 */
export function downloadPage(release) {
  if (!release) return page("loqui for Windows is on its way", waiting());
  const { base, signed, manifests } = release;
  const versions = [...new Set(manifests.map((m) => m.version))];
  if (versions.length !== 1) throw new Error(`one version per page, not ${versions.join(", ")}`);
  const setup = (arch) => {
    const m = manifests.find((x) => x.arch === arch);
    if (!m?.setup?.file) throw new Error(`${versions[0]} has no ${arch} installer`);
    return { url: `${base}${m.setup.file}`, mb: Math.round(m.setup.size / 1_000_000) };
  };
  return page(`Download loqui ${versions[0]} for Windows`, ready(versions[0], setup("x64"), setup("arm64"), signed));
}

function waiting() {
  return `<h1>loqui for Windows is on its way</h1>
<p>The first public version isn't out yet. When it is, this page starts the download.</p>
<p>loqui for Mac is ready now: <a href="https://github.com/jameslaws/loqui/releases/latest">download loqui for macOS</a>.</p>
<p><a href="${RELEASES}">All of loqui's releases</a> &middot; <a href="../">Back to loqui</a></p>`;
}

function ready(version, x64, arm64, signed) {
  const smartscreen = signed
    ? ""
    : `
<h2>Windows protected your PC</h2>
<p>loqui isn't signed by Microsoft yet. When you run the installer, Windows shows
<b>&ldquo;Windows protected your PC&rdquo;</b>. Click <b>More info</b>, then <b>Run anyway</b>.</p>
<p>If Windows' <b>Smart App Control</b> is turned on, it blocks apps that aren't signed and there is
no Run anyway, so loqui can't be installed on that PC for now.</p>`;
  return `<h1>Download loqui for Windows</h1>
<p>loqui ${version} for Windows 11. It installs just for you, with no administrator needed.</p>
<p>On a Windows PC the download starts by itself. If it doesn't, choose your PC:</p>
<ul class="pick">
  <li><a id="x64" href="${x64.url}">Most PCs (Intel or AMD)</a> <span>${x64.mb} MB</span></li>
  <li><a id="arm64" href="${arm64.url}">Arm PCs (Snapdragon, such as Surface Pro 11)</a> <span>${arm64.mb} MB</span></li>
</ul>${smartscreen}
<p class="foot"><a href="${RELEASES}">All of loqui's releases</a> &middot; <a href="../">Back to loqui</a></p>
<script>
  // Start the right installer on a Windows PC; anywhere else, just show the choice.
  (function () {
    if (!/Windows NT/.test(navigator.userAgent)) return;
    function go(arm) { location.href = document.getElementById(arm ? "arm64" : "x64").href; }
    var hint = /ARM64|aarch64/i.test(navigator.userAgent);
    var data = navigator.userAgentData;
    if (data && data.getHighEntropyValues) {
      data.getHighEntropyValues(["architecture"]).then(
        function (v) { go(hint || v.architecture === "arm"); },
        function () { go(hint); }
      );
    } else go(hint);
  })();
</script>`;
}

function page(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="robots" content="noindex">
<link rel="icon" href="../assets/loqui-icon-180.png" type="image/png">
<style>
  /* The download page's colours (docs/index.html), AA on both schemes. */
  :root { --magenta-text: #B0154F; --ink: #1A1A1A; --muted: #5F5B57; --surface: #FFFFFF; --rule: #E3DFDA; }
  @media (prefers-color-scheme: dark) {
    :root { --magenta-text: #FF8FB4; --ink: #EFECE8; --muted: #ABA49C; --surface: #131211; --rule: #322F2D; }
  }
  body {
    margin: 0 auto; max-width: 40rem; padding: 48px 24px; background: var(--surface); color: var(--ink);
    font: 17px/1.6 "Segoe UI", -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
  }
  img { display: block; margin-bottom: 20px; border-radius: 14px; }
  h1 { font-size: 30px; line-height: 1.2; margin: 0 0 12px; }
  h2 { font-size: 20px; margin: 32px 0 8px; }
  a { color: var(--magenta-text); }
  a:focus-visible { outline: 3px solid var(--magenta-text); outline-offset: 3px; border-radius: 4px; }
  .pick { list-style: none; padding: 0; margin: 0; border-top: 1px solid var(--rule); }
  .pick li { padding: 12px 0; border-bottom: 1px solid var(--rule); display: flex; gap: 12px; justify-content: space-between; flex-wrap: wrap; }
  .pick span, .foot { color: var(--muted); }
  .foot { margin-top: 32px; font-size: 15px; }
</style>
</head>
<body>
<main>
<img src="../assets/loqui-icon-180.png" width="72" height="72" alt="">
${body}
</main>
</body>
</html>
`;
}

if (process.argv[1] && import.meta.filename === resolve(process.argv[1])) {
  const [first, signing, ...files] = process.argv.slice(2);
  if (first === "waiting") process.stdout.write(downloadPage(null));
  else if (first && (signing === "signed" || signing === "unsigned") && files.length > 0) {
    const manifests = files.map((f) => JSON.parse(readFileSync(f, "utf8")));
    process.stdout.write(downloadPage({ base: first, signed: signing === "signed", manifests }));
  } else {
    console.error("Usage: download-page.mjs <base url> <signed|unsigned> <manifest.json>... | waiting");
    process.exit(1);
  }
}
