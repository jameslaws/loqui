// Made by loqui-core (crates/loqui-core/src/commands.rs). Don't edit by hand:
// `LOQUI_WRITE_BINDINGS=1 cargo test -p loqui-core` writes it again.

export type ShortcutView = { text: string, keys: Array<string>, };

export type General = { shortcut: ShortcutView, removeFillers: boolean, fillers: Array<string>, 
/**
 * -1 keeps no history, 0 keeps it forever, N keeps N days.
 */
historyRetentionDays: number, startAtSignIn: boolean, 
/**
 * Set when a settings file couldn't be read: say so, and that defaults are in use.
 */
problem: string | null, };

export type Term = { heard: string, replacement: string, };

export type HistoryItem = { at: string, text: string, };

export type Welcome = { 
/**
 * Windows lets desktop apps use the microphone.
 */
microphoneAllowed: boolean, shortcut: ShortcutView, startAtSignIn: boolean, };

export type UpdateStatus = { "state": "notChecked" } | { "state": "checking" } | { "state": "upToDate" } | { "state": "available", version: string, 
/**
 * The release notes: one change per line, each starting "- ".
 */
notes: string, 
/**
 * The download, in whole megabytes, when the list says.
 */
sizeMb: number | null, } | { "state": "downloading", percent: number | null, } | { "state": "installing" } | { "state": "checkFailed", message: string, } | { "state": "installFailed", message: string, };

export type Updates = { 
/**
 * The version running now.
 */
version: string, 
/**
 * "Get test versions" is on.
 */
testVersions: boolean, 
/**
 * When the last check finished (ISO 8601, UTC), if there was one.
 */
checkedAt: string | null, status: UpdateStatus, };

export const events = { historyChanged: "history-changed", settingsChanged: "settings-changed", updatesChanged: "updates-changed" } as const;
