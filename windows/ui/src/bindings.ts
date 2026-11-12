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

export type Grain = "allTime" | "year" | "month" | "week" | "day";

export type StatsRequest = { grain: Grain, offset: number, jumpTo: string | null, };

export type Stats = { 
/**
 * No dictations at all: the window says how to start instead.
 */
empty: boolean, 
/**
 * The dictation shortcut, for the empty window.
 */
shortcut: string, 
/**
 * "51,104 words all-time · 687 dictations · 74 words each".
 */
summary: string, 
/**
 * Today, This week, This month.
 */
cards: Array<Card>, last30Days: Array<Bar>, 
/**
 * The last 12 months, this one last.
 */
byMonth: Array<Bar>, period: Period, calendar: Calendar, };

export type Card = { title: string, value: string, 
/**
 * "1,997 last week · ▼ 65%".
 */
compare: string, 
/**
 * Level with or ahead of the period before.
 */
up: boolean, };

export type Bar = { 
/**
 * What the bar is, in full: "Oct 27", "September 2026", "Monday", "9–10 AM".
 */
label: string, 
/**
 * The same, short enough for the axis: "Oct 27", "Sep 2026", "Mon", "9a".
 */
tick: string, words: number, };

export type Period = { grain: Grain, offset: number, 
/**
 * The period spelled out as the Mac does: "July 2026", "Aug 2 – 8", "Yesterday".
 */
label: string, 
/**
 * First and last day of the period (`2026-10-25`), or none for all time.
 */
first: string | null, last: string | null, 
/**
 * Said in place of the tiles when the period has no dictations.
 */
emptyText: string | null, 
/**
 * Sunday first.
 */
byWeekday: Array<Bar>, 
/**
 * Midnight first.
 */
byHour: Array<Bar>, tiles: Array<Tile>, };

export type Tile = { title: string, value: string, detail: string | null, };

export type Calendar = { today: string, 
/**
 * The first day with a dictation: nothing before it can be picked.
 */
firstDay: string | null, 
/**
 * 0 is Sunday: the calendar's first column.
 */
firstWeekday: number, 
/**
 * Every day with dictations.
 */
days: Array<DayWords>, 
/**
 * Every month with dictations (`2026-10`).
 */
months: Array<DayWords>, 
/**
 * Shading is against the busiest day and month ever.
 */
busiestDay: number, busiestMonth: number, 
/**
 * From this year back to the first dictation's.
 */
years: Array<YearWords>, };

export type DayWords = { date: string, words: number, };

export type YearWords = { year: number, words: number, };

export const events = { historyChanged: "history-changed", settingsChanged: "settings-changed", statsChanged: "stats-changed" } as const;
