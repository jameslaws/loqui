import { expect, test } from "@playwright/test";
import { fake } from "./helpers";

test("HIST-01: History lists, searches, copies and deletes", async ({ page }) => {
  await page.goto("/history.html");
  const entries = page.getByRole("list", { name: "Dictations, newest first" }).getByRole("listitem");
  await expect(entries).toHaveCount(6);
  await expect(entries.first()).toContainText("Thanks for sending the draft over.");
  await expect(entries.first()).toContainText("Nov 10, 2026, 9:30 AM");
  await expect(entries.last()).toContainText("Nov 9, 2026, 10:00 AM");

  await page.getByRole("searchbox", { name: "Search dictations" }).fill("Friday");
  await expect(entries).toHaveCount(1);
  await entries.getByRole("button", { name: "Copy" }).click();
  await expect(entries.getByRole("button", { name: "Copied" })).toBeVisible();
  expect((await fake(page)).clipboard).toBe(
    "Can we move Thursday’s call to Friday afternoon? I’ll send notes before then.",
  );

  await page.getByRole("searchbox", { name: "Search dictations" }).fill("");
  await page.getByRole("button", { name: "Delete the dictation from Nov 9, 2026, 6:30 PM" }).click();
  await expect(entries).toHaveCount(5);
  await expect(page.getByText("The headline should say what changes")).toHaveCount(0);
  expect((await fake(page)).history).toHaveLength(5);
});

test("HIST-02: Empty history says how to start", async ({ page }) => {
  await page.goto("/history.html?history=empty");
  await expect(page.getByRole("heading", { name: "No dictations yet" })).toBeVisible();
  await expect(page.getByText("Press Ctrl+Shift+Space anywhere and start talking.")).toBeVisible();
  await expect(page.getByRole("searchbox")).toHaveCount(0);
  await expect(page.getByRole("list")).toHaveCount(0);
});

test("HIST-03: History updates while it's open", async ({ page }) => {
  await page.goto("/history.html");
  const entries = page.getByRole("list", { name: "Dictations, newest first" }).getByRole("listitem");
  await expect(entries).toHaveCount(6);
  await page.evaluate(() => window.loquiFake?.dictate("A brand new sentence."));
  await expect(entries.first()).toContainText("A brand new sentence.", { timeout: 1000 });
  await expect(entries).toHaveCount(7);
});

test("HIST-03: A history file that can't be read on a refresh says so, with Try again", async ({ page }) => {
  await page.goto("/history.html");
  const entries = page.getByRole("list", { name: "Dictations, newest first" }).getByRole("listitem");
  await expect(entries).toHaveCount(6);
  // The file can't be read when the window refreshes: an error with Try again, never "No dictations yet".
  await page.evaluate(() => window.loquiFake?.historyReadable(false));
  const alert = page.getByRole("alert");
  await expect(alert).toContainText("loqui couldn't read your dictation history");
  await expect(page.getByRole("heading", { name: "No dictations yet" })).toHaveCount(0);
  await page.evaluate(() => {
    if (window.loquiFake) window.loquiFake.state.historyUnreadable = false;
  });
  await alert.getByRole("button", { name: "Try again" }).click();
  await expect(alert).toHaveCount(0);
  await expect(entries).toHaveCount(6);
});
