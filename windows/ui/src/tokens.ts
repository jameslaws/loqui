import tokens from "../../design/tokens.json";

type Mode = keyof typeof tokens.modes;

const px = (name: string, group: Record<string, { $value: string }>) =>
  Object.entries(group).map(([key, t]) => `--${name}-${key}: ${t.$value};`);

function colours(mode: Mode): string {
  return Object.entries(tokens.modes[mode].color)
    .map(([key, t]) => `--color-${key}: ${t.$value};`)
    .join(" ");
}

/** design/tokens.json as CSS variables: colours per light and dark, the rest shared. */
export function tokenCss(): string {
  const fonts = Object.entries(tokens.font).map(
    ([key, t]) => `--font-${key}: ${t.$value.map((f) => (f.includes(" ") ? `"${f}"` : f)).join(", ")};`,
  );
  const type = Object.entries(tokens.type).flatMap(([key, t]) => [
    `--type-${key}-size: ${t.$value.fontSize};`,
    `--type-${key}-line: ${t.$value.lineHeight};`,
    `--type-${key}-weight: ${t.$value.fontWeight};`,
  ]);
  const shared = [...fonts, ...type, ...px("space", tokens.space), ...px("radius", tokens.radius)].join(" ");
  return `:root { ${shared} ${colours("light")} }
@media (prefers-color-scheme: dark) { :root { ${colours("dark")} } }`;
}
