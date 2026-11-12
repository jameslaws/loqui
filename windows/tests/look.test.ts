import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "vitest";
import tokens from "../design/tokens.json";

type Colours = Record<string, { $value: string }>;

/** WCAG 2.2 contrast ratio between two opaque hex colours. */
function contrast(a: string, b: string): number {
  const luminance = (hex: string) => {
    const [r, g, bl] = [1, 3, 5].map((i) => {
      const c = Number.parseInt(hex.slice(i, i + 2), 16) / 255;
      return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * bl;
  };
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

/** The approved look sheet's CSS variables, light and dark. */
function lookSheet() {
  const css = readFileSync(
    join(import.meta.dirname, "../../plans/windows-groundwork/mockups/win.css"),
    "utf8",
  ).replaceAll("\r\n", "\n");
  const vars = (block: string) =>
    Object.fromEntries([...block.matchAll(/--([\w-]+):\s*([^;]+);/g)].map((m) => [m[1], m[2].trim()]));
  const light = vars(css.slice(css.indexOf(":root {"), css.indexOf("}", css.indexOf(":root {"))));
  const darkStart = css.indexOf(":root {", css.indexOf("@media (prefers-color-scheme: dark)"));
  const dark = vars(css.slice(darkStart, css.indexOf("}", darkStart)));
  const rule = (selector: string) => css.slice(css.indexOf(`${selector} {`)).split("}")[0];
  return { css, light, dark, rule };
}

const cssName = (token: string) => token.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`).replace("card2", "card-2");

test("LOOK-01: The Windows look is one tokens file that meets contrast", () => {
  // Every declared text and background pair passes WCAG AA in both modes.
  const failures: string[] = [];
  for (const mode of ["light", "dark"] as const) {
    const colours = tokens.modes[mode].color as Colours;
    for (const pair of tokens.pairs) {
      const fg = colours[pair.foreground.replace("color.", "")].$value;
      const bg = colours[pair.background.replace("color.", "")].$value;
      const ratio = contrast(fg, bg);
      if (ratio < (pair.kind === "text" ? 4.5 : 3))
        failures.push(`${mode} ${pair.foreground} on ${pair.background}: ${ratio}`);
    }
  }
  expect(failures).toEqual([]);

  // The colours, spacing, corners and type match the approved look sheet.
  const sheet = lookSheet();
  for (const mode of ["light", "dark"] as const) {
    const colours = tokens.modes[mode].color as Colours;
    let compared = 0;
    for (const [name, token] of Object.entries(colours)) {
      const value = sheet[mode][cssName(name)] ?? sheet.light[cssName(name)];
      if (!value) continue;
      expect(token.$value.toUpperCase(), `${mode} ${name}`).toBe(value.toUpperCase());
      compared++;
    }
    // Everything but danger and the HUD colours is a variable on the sheet; those are checked below.
    expect(compared, mode).toBe(Object.keys(colours).length - 4);
  }
  const dangers = [...sheet.css.matchAll(/\.btn\.danger \{ color: (#\w{6})/g)].map((m) => m[1]);
  expect([tokens.modes.light.color.danger.$value, tokens.modes.dark.color.danger.$value]).toEqual(dangers);
  const hud = sheet.rule(".hud");
  expect(hud).toContain("rgba(28, 26, 25, 0.9)");
  expect(tokens.modes.light.color.hudSurface.$value).toBe("#1C1A19");
  expect(tokens.hudOpacity.$value).toBe(0.9);
  expect(sheet.rule(".hud .label")).toContain(tokens.modes.light.color.hudLabel.$value);
  for (const [name, token] of Object.entries(tokens.space)) expect(token.$value, name).toBe(sheet.light[name]);
  for (const [name, token] of Object.entries(tokens.radius)) expect(token.$value, name).toBe(sheet.light[`r-${name}`]);
  for (const [name, selector] of [
    ["title", ".title"],
    ["subtitle", ".subtitle"],
    ["caption", ".caption"],
    ["body", "\nbody"],
  ]) {
    const t = tokens.type[name as keyof typeof tokens.type].$value;
    expect(sheet.rule(selector), name).toContain(`font-size: ${t.fontSize}`);
    expect(sheet.rule(selector), name).toContain(`line-height: ${t.lineHeight}`);
  }
});
