import { expect, test } from "@playwright/test";
import { fake } from "./helpers";

test("WELC-01: The welcome window opens on first start and ticks itself off", async ({ page }) => {
  await page.goto("/welcome.html?mic=blocked");
  const mic = page.getByRole("region", { name: "Microphone" });
  await expect(mic.getByRole("img", { name: "Not done yet" })).toBeVisible();
  await expect(mic.getByRole("button", { name: "Open microphone settings" })).toBeVisible();
  await expect(page.getByText("Allow the microphone to finish.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Finish", exact: true })).toHaveCount(0);

  // Turned on in Windows, without touching loqui: the row ticks itself within 2 s.
  await page.evaluate(() => window.loquiFake?.allowMicrophone());
  await expect(mic.getByRole("img", { name: "Done" })).toBeVisible({ timeout: 2000 });
  await expect(page.getByRole("button", { name: "Finish", exact: true })).toBeEnabled({ timeout: 2000 });
  await expect(page.getByText("You’re all set: press Ctrl+Shift+Space and start talking.")).toBeVisible();
});

test("WELC-02: Finish closes welcome for good, and it can be reopened", async ({ page }) => {
  await page.goto("/welcome.html");
  await page.getByRole("button", { name: "Finish", exact: true }).click();
  const state = await fake(page);
  expect(state.onboarded).toBe(true);
  expect(state.closed).toBe(true);

  // Opened again from the tray menu: every row ticked.
  await page.goto("/welcome.html");
  for (const row of ["Microphone", "Your shortcut", "Start loqui when you sign in"]) {
    await expect(page.getByRole("region", { name: row }).getByRole("img", { name: "Done" })).toBeVisible();
  }
});

test("SET-05: Start loqui when you sign in", async ({ page }) => {
  await page.goto("/welcome.html");
  const welcomeSwitch = page.getByRole("switch", { name: "Start loqui when you sign in" });
  await expect(welcomeSwitch).toBeChecked();
  await welcomeSwitch.click();
  await expect(welcomeSwitch).not.toBeChecked();
  expect((await fake(page)).startAtSignIn).toBe(false);

  await page.goto("/settings.html");
  const settingsSwitch = page.getByRole("switch", { name: "Start loqui when you sign in" });
  await expect(settingsSwitch).toBeChecked();
  await settingsSwitch.click();
  await expect(settingsSwitch).not.toBeChecked();
  expect((await fake(page)).startAtSignIn).toBe(false);
});
