import { expect, test } from "@playwright/test";
import { fake, noAxeViolations, tabThrough } from "./helpers";

const windows = [
  { name: "welcome", url: "/welcome.html?mic=blocked", controls: ["Open microphone settings", "Finish later"] },
  { name: "settings, General", url: "/settings.html", controls: ["Change", "Remove filler words", "Clear history…"] },
  { name: "settings, Dictionary", url: "/settings.html", tab: "Dictionary", controls: ["+ Add term", "Delete loki"] },
  { name: "history", url: "/history.html", controls: ["Search dictations", "Clear all…", "Copy"] },
];

for (const w of windows) {
  test(`A11Y-01: Every new window works by keyboard and passes the accessibility scan (${w.name})`, async ({
    page,
  }) => {
    await page.goto(w.url);
    if (w.tab) {
      // Tabs by keyboard: focus the selected tab and step with the arrow key.
      await page.getByRole("tab", { name: "General" }).focus();
      await page.keyboard.press("ArrowRight");
      await expect(page.getByRole("tab", { name: w.tab })).toHaveAttribute("aria-selected", "true");
    }
    await expect(page.getByRole("button").first()).toBeVisible();
    await noAxeViolations(page);

    const reached = await tabThrough(page);
    for (const control of w.controls) expect(reached, `${control} by keyboard`).toContain(control);

    // The confirm dialog passes too, and Esc answers it without closing the window.
    if (w.name === "history") {
      await page.getByRole("button", { name: "Clear all…" }).focus();
      await page.keyboard.press("Enter");
      await expect(page.getByRole("dialog")).toBeVisible();
      await noAxeViolations(page);
      await page.keyboard.press("Escape");
      await expect(page.getByRole("dialog")).toBeHidden();
      expect((await fake(page)).closed).toBe(false);
    }

    await page.keyboard.press("Escape");
    expect((await fake(page)).closed).toBe(true);
  });
}
