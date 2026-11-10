// Takes this plan's pictures into shots/ beside this file: the live download page today ("before") and the
// same page with the Windows changes made in the page ("after"), at MacBook and iPhone sizes.
//   node plans/windows-launch/shoot.mjs      (Playwright from the project, or ~/Developer/playbook's)
import { mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';
import { join } from 'node:path';

const here = new URL('.', import.meta.url).pathname;
const require = createRequire(import.meta.url);
const pw = await import(require.resolve('playwright', { paths: [process.cwd(), join(homedir(), 'Developer', 'playbook')] }));
const { chromium, webkit } = pw.default ?? pw;

const URL_ = 'https://jameslaws.github.io/loqui/';
const DEVICES = {
  mac: { engine: chromium, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 },
  phone: { engine: webkit, viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
};
// The "after": the hero offers the right download for the visitor's computer (here, a Windows visitor),
// with the other one a quiet link underneath, and the first value card no longer says Mac only.
async function windowsHero(page) {
  await page.evaluate(() => {
    const row = document.querySelector('.cta-row');
    row.querySelector('a.btn').textContent = 'Download for Windows';
    const meta = document.querySelector('.hero .meta');
    meta.innerHTML = 'Free and open source, no account, no subscription.<br>Windows 11, Intel, AMD and Arm. Also for <a href="#">macOS 15 and later</a>.';
    const tag = document.querySelector('.hero .tagline');
    tag.textContent = 'Press a key, speak, and clean text lands wherever your cursor is. On your Mac or your Windows PC, in any app.';
    const first = document.querySelector('.prop h3');
    if (first) first.lastChild.textContent = 'Runs on your computer';
    const firstP = document.querySelector('.prop p');
    if (firstP) firstP.textContent = 'Speech becomes text on your own Mac or PC. Your voice is never uploaded, because there is no server to upload it to.';
  });
}
mkdirSync(join(here, 'shots'), { recursive: true });
for (const [device, { engine, ...size }] of Object.entries(DEVICES)) {
  const browser = await engine.launch();
  const context = await browser.newContext({ ...size, colorScheme: 'light' });
  for (const [name, change] of [['before-download-page', null], ['after-download-page', windowsHero]]) {
    const page = await context.newPage();
    await page.goto(URL_, { waitUntil: 'networkidle' });
    if (change) await change(page);
    const file = join(here, 'shots', `${name}-${device}.png`);
    await page.screenshot({ path: file });
    console.log(file);
    await page.close();
  }
  await context.close();
  await browser.close();
}
