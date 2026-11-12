import { expect, test } from "@playwright/test";
import { fake } from "./helpers";

const REFUSED = "Use Ctrl or Alt with a key, or a function key.";

test("SET-01: Change the shortcut by pressing it", async ({ page }) => {
  await page.goto("/settings.html");
  await expect(page.getByRole("img", { name: "Current shortcut: Ctrl+Shift+Space" })).toBeVisible();

  await page.getByRole("button", { name: "Change" }).click();
  // While recording, loqui's own shortcut is off, so pressing it can't start a dictation.
  expect((await fake(page)).hookPaused).toBe(true);
  await page.keyboard.press("Shift+A");
  await expect(page.getByRole("status")).toHaveText(REFUSED);
  await page.keyboard.press("Control+Alt+D");
  await expect(page.getByRole("img", { name: "Current shortcut: Ctrl+Alt+D" })).toBeVisible();
  for (const key of ["Ctrl", "Alt", "D"]) await expect(page.locator(".keycap", { hasText: key })).toBeVisible();
  const saved = await fake(page);
  expect(saved.shortcut).toBe("Ctrl+Alt+D");
  expect(saved.hookPaused).toBe(false);

  // A bare function key is fine too; Esc cancels without changing anything.
  await page.getByRole("button", { name: "Change" }).click();
  await page.keyboard.press("F8");
  await expect(page.getByRole("img", { name: "Current shortcut: F8" })).toBeVisible();
  await page.getByRole("button", { name: "Change" }).click();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("img", { name: "Current shortcut: F8" })).toBeVisible();
  const after = await fake(page);
  expect(after.closed).toBe(false);
  expect(after.hookPaused).toBe(false);
});

test("SET-02: Filler words can be added and removed", async ({ page }) => {
  await page.goto("/settings.html");
  await page.getByRole("textbox", { name: "Add a filler word" }).fill("Like");
  await page.getByRole("button", { name: "Add", exact: true }).click();
  await expect(page.getByRole("listitem").filter({ hasText: /^like/ })).toBeVisible();
  expect((await fake(page)).fillers.at(-1)).toBe("like");

  await page.getByRole("button", { name: "Remove like" }).click();
  await expect(page.getByRole("button", { name: "Remove like" })).toHaveCount(0);
  expect((await fake(page)).fillers).not.toContain("like");

  await page.getByRole("switch", { name: "Remove filler words" }).click();
  await expect(page.getByRole("textbox", { name: "Add a filler word" })).toHaveCount(0);
  expect((await fake(page)).removeFillers).toBe(false);
});

test("SET-03: How long history is kept", async ({ page }) => {
  await page.goto("/settings.html");
  const keep = page.getByRole("combobox", { name: "Keep history" });
  await expect(keep).toHaveValue("0");
  for (const [label, days] of [
    ["30 days", 30],
    ["7 days", 7],
    ["Off: don’t save", -1],
    ["Forever", 0],
  ] as const) {
    await keep.selectOption({ label });
    await expect.poll(async () => (await fake(page)).retention).toBe(days);
  }
});

test("SET-04: Clear history asks first", async ({ page }) => {
  await page.goto("/settings.html");
  await page.getByRole("button", { name: "Clear history…" }).click();
  const dialog = page.getByRole("dialog", { name: "Clear all dictation history?" });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Cancel" })).toBeFocused();
  await dialog.getByRole("button", { name: "Cancel" }).click();
  expect((await fake(page)).history).toHaveLength(6);

  await page.getByRole("button", { name: "Clear history…" }).click();
  await dialog.getByRole("button", { name: "Clear" }).click();
  await expect(dialog).toBeHidden();
  expect((await fake(page)).history).toHaveLength(0);
});

test("DICTN-01: The dictionary can be searched and edited", async ({ page }) => {
  await page.goto("/settings.html");
  await page.getByRole("tab", { name: "Dictionary" }).click();
  const heard = page.getByRole("textbox", { name: "Heard" });
  await expect(heard).toHaveCount(4);

  const search = page.getByRole("searchbox", { name: "Search the dictionary" });
  await search.fill("forms");
  await expect(heard).toHaveCount(1);
  await expect(heard).toHaveValue("ninja forms");
  await search.fill("");
  await expect(heard).toHaveCount(4);

  await page.getByRole("button", { name: "+ Add term" }).click();
  await expect(heard.first()).toBeFocused();
  await page.keyboard.type("grayson");
  await page.getByRole("textbox", { name: "Written as, for grayson" }).fill("Greyson");
  await page.getByRole("textbox", { name: "Written as, for sarah k" }).fill("Sara K");
  await page.getByRole("button", { name: "Delete loki" }).click();

  const saved = (await fake(page)).dictionary;
  expect(saved).toEqual(
    expect.arrayContaining([
      { heard: "grayson", replacement: "Greyson" },
      { heard: "sarah k", replacement: "Sara K" },
    ]),
  );
  expect(saved.map((t) => t.heard)).not.toContain("loki");
  expect(saved).toHaveLength(4);
});
