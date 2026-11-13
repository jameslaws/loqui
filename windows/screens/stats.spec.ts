import { readFileSync } from "node:fs";
import { expect, type Page, test } from "@playwright/test";
import { fake, noAxeViolations, tabThrough } from "./helpers";

/**
 * The stats window in a browser. Its figures come from loqui-core itself
 * (ui/fake-stats.ts) for the shared sample record, so every number here is
 * read from shared/stats-cases.json, the file the Mac's tests and the Windows
 * core's tests also run.
 */
const shared = JSON.parse(readFileSync(new URL("../../shared/stats-cases.json", import.meta.url), "utf8"));
const n = (x: number) => x.toLocaleString("en-US");
const words = (x: number) => `${n(x)} ${x === 1 ? "word" : "words"}`;

type Period = (typeof shared.periods)[number];
const periodOf = (grain: string, offset: number): Period => {
  const p = shared.periods.find((c: Period) => c.grain === grain && c.offset === offset && !c.firstWeekday);
  if (!p) throw new Error(`the shared file has no ${grain} ${offset}`);
  return p;
};

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const LONG_MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];
const day = (iso: string) => new Date(`${iso}T12:00:00Z`);
const dayLabel = (iso: string) => `${MONTHS[day(iso).getUTCMonth()]} ${day(iso).getUTCDate()}`;
const hourRange = (h: number) => {
  const part = (x: number) => [x % 12 === 0 ? 12 : x % 12, x % 24 < 12 ? "AM" : "PM"] as const;
  const [[a, am], [b, bm]] = [part(h), part(h + 1)];
  return am === bm ? `${a}–${b} ${am}` : `${a} ${am}–${b} ${bm}`;
};

/** The eight tiles as a person reads them, from the shared file's figures. */
function tiles(p: Period, grain: string) {
  const mins = p.timeSavedMinutes;
  return [
    ["Time saved", mins < 60 ? `≈${mins} min` : `≈${Math.floor(mins / 60)}h ${mins % 60}m`],
    ["Speaking pace", p.paceMeasured ? `${n(p.speakingPace)} wpm` : "—"],
    grain === "allTime"
      ? ["Current streak", `${p.currentStreak} ${p.currentStreak === 1 ? "day" : "days"}`]
      : ["Longest streak", `${p.longestStreak} ${p.longestStreak === 1 ? "day" : "days"}`],
    ["Days active", `${p.activeDays} of ${p.spanDays}`],
    ["Peak hours", p.peakHours],
    ["Highest volume day", p.biggestDay ? words(p.biggestDay.words) : "—"],
    ["Longest dictation", words(p.longestDictation)],
    ["Per active day", words(p.perActiveDay)],
  ];
}

const chart = (page: Page, name: string) => page.getByRole("group", { name, exact: true }).getByRole("img");
const periodButton = (page: Page) => page.getByRole("button", { name: /, choose a / });

async function patternsMatch(page: Page, p: Period, grain: string) {
  if (grain !== "allTime") await expect(periodButton(page)).toHaveText(p.label);
  await expect(chart(page, "By weekday")).toHaveCount(7);
  for (const [i, w] of p.byWeekday.entries())
    await expect(chart(page, "By weekday").nth(i)).toHaveAccessibleName(`${WEEKDAYS[i]}: ${words(w)}`);
  for (const [h, w] of p.byHour.entries())
    await expect(chart(page, "By hour of day").nth(h)).toHaveAccessibleName(`${hourRange(h)}: ${words(w)}`);
  if (p.empty) {
    await expect(page.getByRole("list", { name: /^Patterns for/ })).toHaveCount(0);
    return;
  }
  const list = page.getByRole("list", { name: `Patterns for ${p.label}` }).getByRole("listitem");
  await expect(list).toHaveCount(8);
  for (const [i, [title, value]] of tiles(p, grain).entries()) {
    await expect(list.nth(i).getByRole("heading")).toHaveText(title);
    await expect(list.nth(i)).toContainText(value);
  }
}

const choose = (page: Page, grain: string) => page.getByRole("radio", { name: grain, exact: true }).check();

test("STAT-01: The top of the window matches the record", async ({ page }) => {
  await page.goto("/stats.html");
  const t = shared.top;
  await expect(page.getByRole("heading", { level: 1, name: "Dictation" })).toBeVisible();
  await expect(
    page.getByText(
      `${n(t.allTimeWords)} words all-time · ${n(t.dictations)} dictations · ${n(t.wordsEach)} words each`,
    ),
  ).toBeVisible();
  const card = (name: string) => page.getByRole("region", { name, exact: true });
  await expect(card("Today")).toContainText(n(t.today));
  await expect(card("Today")).toContainText(`${n(t.yesterday)} yesterday`);
  const pct = (now: number, before: number) => {
    const p = Math.round(((now - before) / before) * 100);
    return `${p >= 0 ? "▲" : "▼"} ${Math.abs(p)}%`;
  };
  await expect(card("This week")).toContainText(n(t.thisWeek));
  await expect(card("This week")).toContainText(`${n(t.lastWeek)} last week · ${pct(t.thisWeek, t.lastWeek)}`);
  await expect(card("This month")).toContainText(n(t.thisMonth));
  await expect(card("This month")).toContainText(`${n(t.lastMonth)} last month · ${pct(t.thisMonth, t.lastMonth)}`);
  // All time below: its patterns and tiles too.
  await patternsMatch(page, periodOf("allTime", 0), "allTime");
});

test("STAT-02: The two charts show each day and month, with hover labels", async ({ page }) => {
  await page.goto("/stats.html");
  const days = chart(page, "Last 30 days");
  await expect(days).toHaveCount(30);
  const first = day(shared.last30Days.first);
  for (const [i, w] of shared.last30Days.words.entries()) {
    const d = new Date(first.getTime() + i * 86_400_000).toISOString().slice(0, 10);
    await expect(days.nth(i)).toHaveAccessibleName(`${dayLabel(d)}: ${words(w)}`);
  }
  const months = chart(page, "By month");
  await expect(months).toHaveCount(12);
  const [y, m] = shared.byMonth.first.split("-").map(Number);
  for (const [i, w] of shared.byMonth.words.entries()) {
    const at = (m - 1 + i) % 12;
    const year = y + Math.floor((m - 1 + i) / 12);
    await expect(months.nth(i)).toHaveAccessibleName(`${LONG_MONTHS[at]} ${year}: ${words(w)}`);
  }

  // Hover: the bar for Oct 27 says its date and words.
  const busiest = days.and(page.getByRole("img", { name: "Oct 27: 1,412 words" }));
  await busiest.hover();
  const tip = page.getByRole("region", { name: "Last 30 days" }).locator(".chart-tip");
  await expect(tip).toContainText("Oct 27");
  await expect(tip).toContainText("1,412 words");

  // Keyboard: Tab to the chart (it starts on today), then the arrows.
  await days.last().focus();
  for (let i = 0; i < 14; i++) await page.keyboard.press("ArrowLeft");
  await expect(busiest).toBeFocused();
  await expect(tip).toContainText("Oct 27");

  const september = months.and(page.getByRole("img", { name: /^September 2026: / }));
  await september.hover();
  const monthTip = page.getByRole("region", { name: "By month" }).locator(".chart-tip");
  await expect(monthTip).toContainText("September 2026");
  await expect(monthTip).toContainText(words(shared.byMonth.words[9]));
});

test("STAT-03: Patterns follow the chosen period", async ({ page }) => {
  await page.goto("/stats.html");
  for (const [grain, name] of [
    ["year", "Year"],
    ["month", "Month"],
    ["week", "Week"],
    ["day", "Day"],
  ]) {
    await choose(page, name);
    await patternsMatch(page, periodOf(grain, 0), grain);
    const next = page.getByRole("button", { name: `Next ${name.toLowerCase()}` });
    await expect(next).toBeDisabled();
    await page.getByRole("button", { name: `Previous ${name.toLowerCase()}` }).click();
    await patternsMatch(page, periodOf(grain, -1), grain);
    await expect(next).toBeEnabled();
  }
  await expect(page.getByText("No dictations yesterday.")).toBeVisible();
});

test("STAT-04: The calendar jumps to a shaded day", async ({ page }) => {
  await page.goto("/stats.html");
  await choose(page, "Day");
  await periodButton(page).click();
  const cal = page.getByRole("dialog", { name: "Choose a day" });
  await expect(cal.getByRole("heading")).toHaveText("November 2026");
  await expect(cal.getByRole("button", { name: /Nov 10, 2026/ })).toHaveAttribute("aria-current", "true");
  await expect(cal.getByRole("button", { name: /Nov 11, 2026/ })).toBeDisabled();
  await cal.getByRole("button", { name: "Previous month" }).click();
  await expect(cal.getByRole("heading")).toHaveText("October 2026");

  // Shaded against the busiest day ever, on a square-root scale (16% to 72%).
  const shadeOf = async (name: RegExp) =>
    cal.getByRole("button", { name }).evaluate((el) => (el as HTMLElement).style.getPropertyValue("--shade"));
  expect(await shadeOf(/Oct 27, 2026, 1,412 words/)).toBe("72%");
  expect(await shadeOf(/Oct 25, 2026, 41 words/)).toBe(`${Math.round(16 + 56 * Math.sqrt(41 / 1412))}%`);
  expect(await shadeOf(/Oct 20, 2026, no dictations/)).toBe("0%");

  await cal.getByRole("button", { name: "Tuesday, Oct 27, 2026, 1,412 words" }).click();
  await expect(cal).toBeHidden();
  await patternsMatch(page, periodOf("day", -14), "day");

  // Week: the day picked brings the whole week.
  await choose(page, "Week");
  await periodButton(page).click();
  const weeks = page.getByRole("dialog", { name: "Choose a week" });
  await expect(weeks.getByText("Picks the whole week")).toBeVisible();
  await weeks.getByRole("button", { name: /Nov 4, 2026/ }).click();
  await expect(periodButton(page)).toHaveText(periodOf("week", -1).label);
  await periodButton(page).click();
  await expect(weeks.locator("[aria-current='true']")).toHaveCount(7);
  await page.keyboard.press("Escape");

  // Month: a year of months.
  await choose(page, "Month");
  await periodButton(page).click();
  const monthsCal = page.getByRole("dialog", { name: "Choose a month" });
  await expect(monthsCal.getByRole("heading")).toHaveText("2026");
  await expect(monthsCal.getByRole("button", { name: /^December 2026/ })).toBeDisabled();
  await monthsCal.getByRole("button", { name: /^September 2026/ }).click();
  await patternsMatch(page, periodOf("month", -2), "month");

  // Year: a list.
  await choose(page, "Year");
  await periodButton(page).click();
  await page.getByRole("dialog", { name: "Choose a year" }).getByRole("button", { name: /^2025/ }).click();
  await patternsMatch(page, periodOf("year", -1), "year");
});

test("STAT-05: No dictations shows how to start", async ({ page }) => {
  await page.goto("/stats.html?stats=empty");
  await expect(page.getByRole("heading", { name: "No dictations yet" })).toBeVisible();
  await expect(
    page.getByText("Your words, pace and time saved show up here after your first dictation."),
  ).toBeVisible();
  await expect(page.getByText("Press Ctrl+Shift+Space anywhere to start.")).toBeVisible();
  await expect(page.getByRole("group")).toHaveCount(0);
  await expect(page.getByRole("list")).toHaveCount(0);
  await expect(page.getByRole("radio")).toHaveCount(0);
});

test("STAT-06: An empty period says so", async ({ page }) => {
  await page.goto("/stats.html");
  await choose(page, "Month");
  for (let i = 0; i < 8; i++) await page.getByRole("button", { name: "Previous month" }).click();
  await expect(periodButton(page)).toHaveText("March 2026");
  await expect(page.getByText("No dictations in March 2026.")).toBeVisible();
  await expect(page.getByRole("list", { name: /^Patterns for/ })).toHaveCount(0);
});

test("STAT-08: The window updates while open", async ({ page }) => {
  await page.goto("/stats.html");
  const t = shared.top;
  const card = (name: string) => page.getByRole("region", { name, exact: true }).locator(".stat-value");
  await expect(card("Today")).toHaveText(n(t.today));
  await page.evaluate(() =>
    window.loquiFake?.dictate("Please send the report to Sarah before Friday, thanks so very much."),
  );
  await expect(card("Today")).toHaveText(n(t.today + 12), { timeout: 1000 });
  await expect(card("This week")).toHaveText(n(t.thisWeek + 12), { timeout: 1000 });
  await expect(card("This month")).toHaveText(n(t.thisMonth + 12), { timeout: 1000 });
  await expect(page.getByText(`${n(t.allTimeWords + 12)} words all-time`)).toBeVisible({ timeout: 1000 });
});

test("A11Y-02: Stats work by keyboard and pass the accessibility scan", async ({ page }) => {
  await page.goto("/stats.html");
  await expect(chart(page, "Last 30 days")).toHaveCount(30);
  await noAxeViolations(page);

  // One stop per chart, and the period choice.
  const reached = await tabThrough(page);
  for (const control of ["Nov 10: 212 words", "All time"]) expect(reached).toContain(control);
  expect(reached.some((r) => r.startsWith("November 2026: "))).toBe(true);

  // Day by keyboard: the radio buttons wrap from All time back to Day.
  await page.getByRole("radio", { name: "All time" }).focus();
  await page.keyboard.press("ArrowLeft");
  await expect(page.getByRole("radio", { name: "Day" })).toBeChecked();
  await periodButton(page).focus();
  await page.keyboard.press("Enter");
  const cal = page.getByRole("dialog", { name: "Choose a day" });
  await expect(cal).toBeVisible();
  await expect(cal.getByRole("button", { name: /Nov 10, 2026, 212 words/ })).toBeFocused();
  await noAxeViolations(page);

  // Every day that can be picked is a button read out with its date and words.
  await cal.getByRole("button", { name: "Previous month" }).focus();
  await page.keyboard.press("Enter");
  await expect(cal.getByRole("heading")).toHaveText("October 2026");
  const octoberDays = cal.getByRole("button", { name: /Oct \d+, 2026, / });
  await expect(octoberDays).toHaveCount(31);
  for (const b of await octoberDays.all()) await expect(b).toBeEnabled();
  await octoberDays.nth(26).focus();
  await page.keyboard.press("Tab");
  await expect(octoberDays.nth(27)).toBeFocused();

  // Esc closes the calendar, not the window, and goes back to the period.
  await page.keyboard.press("Escape");
  await expect(cal).toBeHidden();
  await expect(periodButton(page)).toBeFocused();
  expect((await fake(page)).closed).toBe(false);

  // The bars by keyboard, read out with their date and words.
  await chart(page, "By hour of day").last().focus();
  await page.keyboard.press("Home");
  await expect(chart(page, "By hour of day").first()).toBeFocused();
  await expect(chart(page, "By hour of day").first()).toHaveAccessibleName(/^12–1 AM: /);

  await page.keyboard.press("Escape");
  expect((await fake(page)).closed).toBe(true);
});
