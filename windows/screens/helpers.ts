import AxeBuilder from "@axe-core/playwright";
import { expect, type Page } from "@playwright/test";
import type { FakeState } from "../ui/src/fake-backend";

/** What loqui's stand-in holds now (settings, history, clipboard, whether the window closed). */
export const fake = (page: Page): Promise<FakeState> =>
  page.evaluate(() => JSON.parse(JSON.stringify(window.loquiFake?.state)));

/** No accessibility problems on the page as it is now (WCAG 2.2 AA rules). */
export async function noAxeViolations(page: Page) {
  const scan = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
    .analyze();
  expect(scan.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target).join(", ")}`)).toEqual([]);
}

/**
 * Tab through the whole page with the keyboard alone: every control is reached,
 * and the focused one always shows an outline. Returns what was reached.
 */
export async function tabThrough(page: Page, max = 60) {
  const reached: string[] = [];
  await page.locator("body").focus();
  for (let i = 0; i < max; i++) {
    await page.keyboard.press("Tab");
    const focused = await page.evaluate(() => {
      const el = document.activeElement as HTMLElement | null;
      if (!el || el === document.body) return null;
      const style = getComputedStyle(el);
      const name =
        el.getAttribute("aria-label") || el.textContent?.trim() || el.getAttribute("placeholder") || el.tagName;
      return { name, outline: style.outlineStyle !== "none" && Number.parseFloat(style.outlineWidth) >= 2 };
    });
    if (!focused) break;
    expect(focused.outline, `the focus outline on ${focused.name}`).toBe(true);
    if (reached.includes(focused.name) && reached[0] === focused.name) break;
    reached.push(focused.name);
  }
  return reached;
}
