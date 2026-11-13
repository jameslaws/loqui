// Types for version.mjs, for the checks of version numbers.
export function parse(version: string): number[];
export function compare(a: string, b: string): number;
export function next(version: string): string;
