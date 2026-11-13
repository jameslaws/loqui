// The download page (docs/index.html) and the Windows download page it links
// to, opened straight from the files as a Windows, Mac and phone visitor.
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { expect, type Page, test } from "@playwright/test";
import { noAxeViolations, tabThrough } from "../screens/helpers";
import { downloadPage } from "../scripts/release/download-page.mjs";

const docs = join(import.meta.dirname, "../../docs");
const PAGE = pathToFileURL(join(docs, "index.html")).href;
const WINDOWS_PAGE = pathToFileURL(join(docs, "windows/download.html")).href;
const MAC_DOWNLOAD = "https://github.com/jameslaws/loqui/releases/latest";

const AGENTS = {
  edge: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0",
  safari:
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Safari/605.1.15",
  iphone:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 26_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1",
  android:
    "Mozilla/5.0 (Linux; Android 16; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36",
};

const hero = (page: Page) => page.locator("header.hero");
const downloads = (page: Page) => hero(page).getByRole("link", { name: /^Download for/ });

/**
 * The lowest contrast between an element's text colour and any pixel behind
 * it, read from the screen with the text hidden. The hero is a gradient,
 * which the accessibility scan can't judge, so this checks it pixel by pixel.
 */
async function lowestContrast(page: Page, selector: string) {
  const el = page.locator(selector).first();
  await el.scrollIntoViewIfNeeded();
  const color = await el.evaluate((e) => getComputedStyle(e).color);
  await el.evaluate((e) => {
    for (const x of [e, ...e.querySelectorAll("*")]) {
      (x as HTMLElement).style.setProperty("color", "transparent", "important");
      (x as HTMLElement).style.setProperty("text-decoration-color", "transparent", "important");
    }
  });
  const box = await el.boundingBox();
  if (!box) throw new Error(`${selector} isn't on screen`);
  const png = (await page.screenshot({ clip: box })).toString("base64");
  await el.evaluate((e) => {
    for (const x of [e, ...e.querySelectorAll("*")]) {
      (x as HTMLElement).style.removeProperty("color");
      (x as HTMLElement).style.removeProperty("text-decoration-color");
    }
  });
  return page.evaluate(
    async ({ png, color }) => {
      const img = new Image();
      img.src = `data:image/png;base64,${png}`;
      await img.decode();
      const canvas = document.createElement("canvas");
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext("2d") as CanvasRenderingContext2D;
      ctx.drawImage(img, 0, 0);
      const px = ctx.getImageData(0, 0, img.width, img.height).data;
      const lin = (c: number) => {
        const s = c / 255;
        return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
      };
      const lum = (r: number, g: number, b: number) => 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
      const [r, g, b] = (color.match(/\d+/g) ?? []).map(Number);
      const text = lum(r, g, b);
      let lowest = 21;
      for (let i = 0; i < px.length; i += 4) {
        const bg = lum(px[i], px[i + 1], px[i + 2]);
        const ratio = (Math.max(text, bg) + 0.05) / (Math.min(text, bg) + 0.05);
        lowest = Math.min(lowest, ratio);
      }
      return lowest;
    },
    { png, color },
  );
}

test.describe("a Windows visitor (Edge on Windows 11)", () => {
  test.use({ userAgent: AGENTS.edge, viewport: { width: 1440, height: 900 } });

  test("LAUNCH-01: Windows visitors get the Windows download first", async ({ page }) => {
    await page.goto(PAGE);
    await expect(downloads(page)).toHaveCount(1);
    const main = downloads(page).first();
    await expect(main).toHaveText("Download for Windows");
    await expect(main).toHaveAttribute("href", "windows/download.html");
    await expect(hero(page).getByRole("link", { name: "Download for macOS" })).toBeHidden();

    const line = hero(page).locator(".meta:visible");
    await expect(line).toHaveCount(1);
    await expect(line).toContainText("Windows 11 on Intel, AMD and Arm");
    await expect(line.getByRole("link", { name: "macOS 15 and later" })).toHaveAttribute("href", MAC_DOWNLOAD);

    // Windows words where the page would otherwise speak only of the Mac.
    await expect(page.getByRole("heading", { name: "Press Ctrl+Shift+Space and talk" })).toBeVisible();
    await expect(page.getByAltText(/statistics window on Windows 11/)).toBeVisible();
    // The closing call to download offers Windows too.
    const final = page.locator("section.final").getByRole("link", { name: /^Download for/ });
    await expect(final).toHaveText(["Download for Windows"]);
  });

  test("LAUNCH-01: Before the first public version, the Windows button says it is on its way", async ({ page }) => {
    // Before the first public version: never a dead end.
    await page.goto(WINDOWS_PAGE);
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("loqui for Windows is on its way");
    await expect(page.getByRole("link", { name: "download loqui for macOS" })).toHaveAttribute("href", MAC_DOWNLOAD);
    await noAxeViolations(page);
  });
});

test.describe("a Mac visitor (Safari on macOS)", () => {
  test.use({ userAgent: AGENTS.safari, viewport: { width: 1440, height: 900 } });

  test("LAUNCH-02: Mac visitors see today's page with Windows mentioned", async ({ page }) => {
    await page.goto(PAGE);
    await expect(downloads(page)).toHaveCount(1);
    const main = downloads(page).first();
    await expect(main).toHaveText("Download for macOS");
    await expect(main).toHaveAttribute("href", MAC_DOWNLOAD);

    const line = hero(page).locator(".meta:visible");
    await expect(line).toContainText("macOS 15 and later. Apple Silicon and Intel.");
    await expect(line.getByRole("link", { name: "Windows 11" })).toHaveAttribute("href", "windows/download.html");

    // Today's Mac words and pictures stay.
    await expect(page.getByRole("heading", { name: "Press ⌘R and talk" })).toBeVisible();
    await expect(page.getByAltText(/The Loqui statistics window\./)).toBeVisible();
    await expect(page.locator("section.final").getByRole("link", { name: /^Download for/ })).toHaveText([
      "Download for macOS",
    ]);
  });
});

test.describe("scripts off", () => {
  test.use({ javaScriptEnabled: false, userAgent: AGENTS.edge, viewport: { width: 1440, height: 900 } });

  test("LAUNCH-03: Without scripts, both downloads show", async ({ page }) => {
    await page.goto(PAGE);
    await expect(downloads(page)).toHaveText(["Download for macOS", "Download for Windows"]);
    for (const link of await downloads(page).all()) await expect(link).toBeVisible();
    await expect(hero(page).locator(".meta:visible")).toContainText("loqui runs on Mac and Windows computers.");

    // Both work: the Mac's goes to its release, Windows' to its page, which loads.
    await expect(downloads(page).nth(0)).toHaveAttribute("href", MAC_DOWNLOAD);
    await downloads(page).nth(1).click();
    await expect(page).toHaveURL(WINDOWS_PAGE);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  });
});

for (const [phone, userAgent] of [
  ["iPhone, Safari", AGENTS.iphone],
  ["Android, Chrome", AGENTS.android],
] as const) {
  test.describe(`a phone (${phone})`, () => {
    test.use({ userAgent, viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });

    test(`LAUNCH-04: Phones see both, laid out cleanly (${phone})`, async ({ page }) => {
      await page.goto(PAGE);
      await expect(downloads(page)).toHaveText(["Download for macOS", "Download for Windows"]);
      await expect(hero(page).locator(".meta:visible")).toContainText("loqui runs on Mac and Windows computers.");

      // Stacked: the Windows button sits under the Mac one, nothing overlaps.
      const [mac, win, source] = await Promise.all(
        [downloads(page).nth(0), downloads(page).nth(1), hero(page).getByRole("link", { name: "View the source" })].map(
          (l) => l.boundingBox(),
        ),
      );
      if (!mac || !win || !source) throw new Error("a button isn't on screen");
      expect(win.y).toBeGreaterThanOrEqual(mac.y + mac.height);
      expect(source.y).toBeGreaterThanOrEqual(win.y + win.height);

      // Nothing on the page scrolls sideways.
      const wide = await page.evaluate(() => document.documentElement.scrollWidth);
      expect(wide).toBeLessThanOrEqual(390);
    });
  });
}

for (const [size, use, both] of [
  // On a Windows PC the Mac download is the link under the button.
  ["desktop", { userAgent: AGENTS.edge, viewport: { width: 1440, height: 900 } }, ["macOS 15 and later"]],
  [
    "phone",
    { userAgent: AGENTS.iphone, viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true },
    ["Download for macOS"],
  ],
] as const) {
  test.describe(`the page, ${size}`, () => {
    test.use(use);

    test(`A11Y-03: The changed page passes the accessibility floor (${size})`, async ({ page }) => {
      await page.goto(PAGE);
      await noAxeViolations(page);

      // The words on magenta, read pixel by pixel: AA for body text, 3:1 for large.
      for (const [selector, floor] of [
        [".hero .tagline", 3],
        [".hero .meta:visible", 4.5],
        [".hero .meta:visible a", 4.5],
        [".hero .etymology", 4.5],
        [".final p:not(.fineprint)", 4.5],
        [".final .fineprint", 4.5],
      ] as const) {
        // The phone's line under the buttons has no link.
        if (selector.endsWith(" a") && (await page.locator(selector).count()) === 0) continue;
        expect(await lowestContrast(page, selector), selector).toBeGreaterThanOrEqual(floor);
      }

      // Both download buttons by keyboard, and Enter follows the Windows one.
      const reached = await tabThrough(page, 80);
      expect(reached).toContain("Download for Windows");
      for (const mac of both) expect(reached).toContain(mac);
      const windows = page.locator("header.hero a", { hasText: "Download for Windows" });
      await windows.focus();
      await page.keyboard.press("Enter");
      await expect(page).toHaveURL(WINDOWS_PAGE);
    });
  });
}

/** The Windows download page as Promote writes it for one version. */
const promoted = (version: string, signed: boolean) =>
  downloadPage({
    base: `https://github.com/jameslaws/loqui/releases/download/windows-v${version}/`,
    signed,
    manifests: ["x64", "arm64"].map((arch) => ({
      version,
      arch,
      setup: { file: `loqui-setup-${version}-${arch}.exe`, size: 461_000_000 },
    })),
  });

for (const [pc, userAgent, arch] of [
  ["an Intel or AMD PC", AGENTS.edge, "x64"],
  ["an Arm PC", AGENTS.edge.replace("Win64; x64", "ARM64"), "arm64"],
] as const) {
  test.describe(`the Windows download page on ${pc}`, () => {
    test.use({ userAgent, viewport: { width: 1440, height: 900 } });

    test(`LAUNCH-08: The Windows link follows each approved version (${arch})`, async ({ page }) => {
      await page.route("https://github.com/**", (route) => route.fulfill({ status: 200, body: "installer" }));
      for (const version of ["0.1.0", "0.1.1"]) {
        const started = page.waitForRequest(/loqui-setup-/);
        await page.setContent(promoted(version, false));
        expect((await started).url()).toBe(
          `https://github.com/jameslaws/loqui/releases/download/windows-v${version}/loqui-setup-${version}-${arch}.exe`,
        );
      }
    });
  });
}

test.describe("the Windows download page on a Mac", () => {
  test.use({ userAgent: AGENTS.safari, viewport: { width: 1440, height: 900 } });

  test("SIGN-01: The Windows download page says how to get past SmartScreen while unsigned", async ({ page }) => {
    // Away from Windows nothing downloads by itself; the choice and the steps show.
    let downloads = 0;
    await page.route("https://github.com/**", (route) => {
      downloads++;
      return route.fulfill({ status: 200, body: "installer" });
    });
    await page.setContent(promoted("0.1.0", false));
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("Download loqui for Windows");
    await expect(page.getByRole("link", { name: "Most PCs (Intel or AMD)" })).toBeVisible();
    await expect(page.getByRole("link", { name: /^Arm PCs/ })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Windows protected your PC" })).toBeVisible();
    for (const words of ["More info", "Run anyway", "Smart App Control", "no administrator"]) {
      await expect(page.locator("main")).toContainText(words);
    }
    await expect(page.locator("main")).not.toContainText(/publisher/i);
    await noAxeViolations(page);
    expect(downloads).toBe(0);

    // Once signed, the steps go.
    await page.setContent(promoted("0.1.0", true));
    await expect(page.locator("main")).not.toContainText("Run anyway");
  });
});
