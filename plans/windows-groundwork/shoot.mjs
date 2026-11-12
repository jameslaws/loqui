// Takes this plan's pictures into shots/ beside this file. Loqui for Windows is a desktop app, so there is
// one size only (a 1440×900 Windows desktop); there is no phone size. Each mockup is photographed light and dark.
//   node plans/<feature>/shoot.mjs      (Playwright from the project, or ~/Developer/playbook's)
import { mkdirSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';
import { join } from 'node:path';

const here = new URL('.', import.meta.url).pathname;
const require = createRequire(import.meta.url);
const pw = await import(require.resolve('playwright', { paths: [process.cwd(), join(homedir(), 'Developer', 'playbook')] }));
const { chromium } = pw.default ?? pw;

// Every page in mockups/ is one picture: mockups/<name>.html → shots/after-<name>.png and after-<name>-dark.png.
const pages = readdirSync(join(here, 'mockups')).filter((f) => f.endsWith('.html')).map((f) => f.replace(/\.html$/, ''));
mkdirSync(join(here, 'shots'), { recursive: true });
const browser = await chromium.launch();
for (const scheme of ['light', 'dark']) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1, colorScheme: scheme });
  for (const name of pages) {
    const page = await context.newPage();
    await page.goto(new URL(`mockups/${name}.html`, import.meta.url).href, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    const file = join(here, 'shots', `after-${name}${scheme === 'dark' ? '-dark' : ''}.png`);
    await page.screenshot({ path: file });
    console.log(file);
    await page.close();
  }
  await context.close();
}
await browser.close();
