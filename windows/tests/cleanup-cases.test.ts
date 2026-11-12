import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "vitest";

type Segment = { text: string; start?: number; end?: number };
type Case = {
  id: string;
  rule: string;
  config?: Record<string, unknown>;
  in?: string;
  segments?: Segment[];
  out: string;
};

const file: { cases: Case[]; timedCases: Case[] } = JSON.parse(
  readFileSync(join(import.meta.dirname, "../../shared/cleanup-cases.json"), "utf8"),
);
const all = [...file.cases, ...file.timedCases];
const rules = [
  "fillers",
  "dictionary",
  "spoken-formatting",
  "tidy",
  "lone-i",
  "sentence-heal",
  "timed-heal",
  "capitals",
];

test("CLEAN-01: The cleanup rules are written down as shared examples", () => {
  expect(all.length).toBeGreaterThanOrEqual(60);
  expect(new Set(all.map((c) => c.id)).size).toBe(all.length);
  for (const rule of rules) {
    expect(all.filter((c) => c.rule === rule).length, rule).toBeGreaterThanOrEqual(3);
  }

  // Spoken formatting both on and off.
  const spoken = all.filter((c) => c.rule === "spoken-formatting");
  expect(spoken.some((c) => c.config?.spokenFormatting === true)).toBe(true);
  expect(spoken.some((c) => !c.config?.spokenFormatting)).toBe(true);

  // The dictionary: a longer phrase beside a shorter one, a whole-word miss, a case change.
  const dictionary = all.filter((c) => c.rule === "dictionary");
  const keys = (c: Case) => Object.keys((c.config?.dictionary ?? {}) as Record<string, string>);
  expect(dictionary.some((c) => keys(c).some((k) => keys(c).some((o) => o !== k && k.includes(o))))).toBe(true);
  expect(dictionary.some((c) => keys(c).some((k) => new RegExp(`\\w${k}|${k}\\w`, "i").test(c.out)))).toBe(true);
  expect(dictionary.some((c) => keys(c).some((k) => c.in?.includes(k.toUpperCase())))).toBe(true);

  // Healing takes a comma before which, whose and whom.
  for (const word of ["which", "whose", "whom"]) {
    expect(
      all.some((c) => c.rule === "sentence-heal" && c.out.includes(`, ${word}`)),
      word,
    ).toBe(true);
  }

  // Timed healing for and, but and so: short gap heals, long gap doesn't, no gap measured doesn't.
  const timed = file.timedCases;
  for (const word of ["and", "but", "so"]) {
    expect(
      timed.some((c) => c.out.includes(`. ${word[0].toUpperCase()}${word.slice(1)} `)),
      word,
    ).toBe(true);
    expect(
      timed.some((c) => c.out.includes(` ${word} `) && !c.segments?.[1]?.text.startsWith(word)),
      word,
    ).toBe(true);
  }
  expect(timed.some((c) => c.segments?.some((s) => s.start === undefined))).toBe(true);

  // Accented words and apostrophes.
  expect(all.some((c) => /[À-ž]/.test(c.in ?? "") && /[À-ž]/.test(c.out))).toBe(true);
  expect(all.some((c) => (c.in ?? "").includes("'"))).toBe(true);
});
