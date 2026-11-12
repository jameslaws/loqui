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

export const events = { historyChanged: "history-changed", settingsChanged: "settings-changed" } as const;
