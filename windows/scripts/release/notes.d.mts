// Types for notes.mjs, for the checks that read what releases say.
export const SMARTSCREEN: string;
export function releasePage(page: { version: string; test: boolean; signed: boolean; changes: string }): string;
export function changesSince(since: string, max?: number): string;
