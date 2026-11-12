import { expect, type Page, test } from "@playwright/test";
import { fake, noAxeViolations, tabThrough } from "./helpers";

/** What the stand-in's update part holds: how often it was asked to check and install. */
const asked = (page: Page) =>
  page.evaluate(() => {
    const u = window.loquiUpdates;
    return { checks: u?.checks ?? 0, installs: u?.installs ?? 0, testVersions: u?.state.testVersions };
  });

test("UPD-01: A newer version installs from the prompt (the update window)", async ({ page }) => {
  await page.goto("/update.html?update=available&found=1");
  await expect(page.getByRole("heading", { name: "A new version of loqui is ready" })).toBeVisible();
  // Both versions, the size, and that the model stays.
  await expect(
    page.getByText(
      "loqui 0.0.3 is available. You have 0.0.2. The download is about 12 MB; your speech model stays as it is.",
    ),
  ).toBeVisible();
  const notes = page.getByRole("region", { name: "What’s new" });
  await expect(notes.getByRole("listitem")).toHaveText([
    "The dictation bubble follows the screen you’re working on",
    "Faster first dictation after the PC wakes",
  ]);
  await expect(page.getByText("Updates are checked once a day. Nothing else is sent.")).toBeVisible();
  await noAxeViolations(page);

  await page.getByRole("button", { name: "Install and restart loqui" }).click();
  await expect(page.getByRole("heading", { name: "Updating loqui" })).toBeVisible();
  await expect(page.getByText("Installing; loqui will start again by itself.")).toBeVisible();
  expect((await asked(page)).installs).toBe(1);
});

test("UPD-01: Later closes the update window and installs nothing", async ({ page }) => {
  await page.goto("/update.html?update=available&found=1");
  await page.getByRole("button", { name: "Later" }).click();
  expect((await fake(page)).closed).toBe(true);
  expect((await asked(page)).installs).toBe(0);
});

test("UPD-02: An update with a bad signature is refused (the update window)", async ({ page }) => {
  await page.goto("/update.html?update=unverified&found=1");
  await page.getByRole("button", { name: "Install and restart loqui" }).click();
  await expect(page.getByRole("heading", { name: "loqui wasn’t updated" })).toBeVisible();
  await expect(page.getByText("This update couldn't be verified, so it wasn't installed.")).toBeVisible();
  await noAxeViolations(page);
});

test("UPD-03: Offline, Check for updates says it couldn't reach the server", async ({ page }) => {
  await page.goto("/settings.html?update=offline");
  const card = page.locator(".card").filter({ hasText: "Get test versions" });
  await expect(card.getByText("loqui 0.0.2")).toBeVisible();
  await expect(card.getByRole("status")).toHaveText("Not checked yet");
  await card.getByRole("button", { name: "Check for updates" }).click();
  await expect(card.getByRole("status")).toHaveText("Couldn't reach the update server. Try again later.");
});

test("UPD-04: Check for updates in Settings says when it last checked", async ({ page }) => {
  await page.clock.setFixedTime(new Date("2026-11-12T14:12:00Z"));
  await page.goto("/settings.html?update=uptodate");
  const card = page.locator(".card").filter({ hasText: "Get test versions" });
  await card.getByRole("button", { name: "Check for updates" }).click();
  // 14:12 UTC is 9:12 AM in the test's time zone, New York.
  await expect(card.getByRole("status")).toHaveText("Up to date · checked today at 9:12 AM");
  expect((await asked(page)).checks).toBe(1);
});

test("CHAN-02: Get test versions is off until switched on", async ({ page }) => {
  await page.goto("/settings.html");
  const toggle = page.getByRole("switch", { name: "Get test versions" });
  await expect(toggle).toHaveAttribute("aria-checked", "false");
  await expect(toggle).toHaveAccessibleDescription("Try new versions before everyone else. They may have rough edges.");
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-checked", "true");
  expect((await asked(page)).testVersions).toBe(true);
  await toggle.click();
  expect((await asked(page)).testVersions).toBe(false);
  await expect(
    page.getByText(
      "The update check is the only thing loqui sends over the internet. It asks GitHub whether a newer version exists.",
    ),
  ).toBeVisible();
});

test("A11Y-01: The Updates card and the update window work by keyboard and pass the accessibility scan", async ({
  page,
}) => {
  await page.goto("/settings.html");
  await expect(page.getByRole("switch", { name: "Get test versions" })).toBeVisible();
  await noAxeViolations(page);
  const reached = await tabThrough(page);
  for (const control of ["Check for updates", "Get test versions"]) expect(reached).toContain(control);

  await page.goto("/update.html?update=available&found=1");
  await expect(page.getByRole("button", { name: "Later" })).toBeVisible();
  const inWindow = await tabThrough(page);
  for (const control of ["Later", "Install and restart loqui"]) expect(inWindow).toContain(control);
  await page.keyboard.press("Escape");
  expect((await fake(page)).closed).toBe(true);
});
