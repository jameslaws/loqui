import { readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "vitest";

const project = readFileSync(join(import.meta.dirname, "../../PROJECT.md"), "utf8").replaceAll("\r\n", "\n");
const front = project.split("---")[1] ?? "";
const field = (name: string) => front.match(new RegExp(`^${name}:\\s*(\\S+)`, "m"))?.[1];
const section = (heading: string) => project.split(`## ${heading}\n`)[1]?.split("\n## ")[0]?.trim() ?? "";

test("PLACE-01: Where Loqui runs is recorded", () => {
  expect(field("access")).toBe("public");
  expect(field("staging")).toMatch(/^https:\/\//);
  expect(field("production")).toMatch(/^https:\/\//);

  // Every section is written, and none of the template's prompts are left.
  const template = [
    "One or two sentences",
    "The access level above",
    "The stack guide's defaults",
    "address, host",
    "What deploys staging",
    "Rules only this project needs",
  ];
  for (const prompt of template) expect(project, prompt).not.toContain(prompt);
  for (const heading of ["Who it's for", "Stack", "Where it runs", "How it ships", "Commands", "Project rules"]) {
    expect(section(heading).length, heading).toBeGreaterThan(80);
  }

  expect(section("Stack")).toMatch(/Tauri/);
  expect(section("Stack")).toMatch(/Why Tauri for Windows:/);
  expect(section("Where it runs")).toMatch(/Staging:/);
  expect(section("Where it runs")).toMatch(/Production:/);
  expect(section("How it ships")).toMatch(/Going back:/);
  for (const command of ["dev", "check", "check:changed", "test:contracts", "test:acceptance", "start"]) {
    expect(section("Commands"), command).toContain(`\`pnpm ${command}\``);
  }
});
