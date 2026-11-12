import type { Backend } from "./backend";
import type { General, HistoryItem, Term } from "./bindings";
import { fakeUpdates } from "./fake-updates";
import { defaultFillers, sampleDictionary, sampleHistory } from "./sample";

/**
 * A stand-in for loqui, for the screen tests in a plain browser. It keeps the
 * same promises in memory and lets a test look inside (`window.loquiFake`).
 * The real rules live in loqui-core and are tested there; this only answers
 * the way loqui answers. Start it with `?history=empty`, `?stats=empty`,
 * `?mic=blocked` or `?problem=1` in the page's address. Stats come from
 * loqui-core itself, through the page server (ui/fake-stats.ts).
 */
export interface FakeState {
  shortcut: string;
  removeFillers: boolean;
  fillers: string[];
  retention: number;
  startAtSignIn: boolean;
  onboarded: boolean;
  microphoneAllowed: boolean;
  dictionary: Term[];
  history: HistoryItem[];
  clipboard: string;
  hookPaused: boolean;
  closed: boolean;
  problem: string | null;
  /** Dictations counted for stats since the page opened, on top of the shared sample. */
  statsAdded: { words: number; seconds: number }[];
}

declare global {
  interface Window {
    loquiFake?: { state: FakeState; allowMicrophone(): void; dictate(text: string): void };
  }
}

const keysOf = (text: string) => text.split("+");
// The stand-in's own copy of the recorder's answer; loqui-core's is the real one.
const allowed = (text: string) =>
  /(^|\+)(Ctrl|Alt)\+/.test(text) ? /\+([A-Z0-9]|Space|F\d+)$/.test(text) : /^F([1-9]|1\d|2[0-4])$/.test(text);

export function fakeBackend(): Backend {
  const ask = new URLSearchParams(location.search);
  const state: FakeState = {
    shortcut: "Ctrl+Shift+Space",
    removeFillers: true,
    fillers: [...defaultFillers],
    retention: 0,
    startAtSignIn: true,
    onboarded: false,
    microphoneAllowed: ask.get("mic") !== "blocked",
    dictionary: [...sampleDictionary],
    history: ask.get("history") === "empty" ? [] : [...sampleHistory],
    clipboard: "",
    hookPaused: false,
    closed: false,
    problem: ask.get("problem") ? "Your settings file couldn't be read, so defaults are in use." : null,
    statsAdded: [],
  };
  const listeners = { history: new Set<() => void>(), settings: new Set<() => void>(), stats: new Set<() => void>() };
  const emit = (which: keyof typeof listeners) => {
    for (const then of listeners[which]) then();
  };
  const subscribe = (which: keyof typeof listeners) => (then: () => void) => {
    listeners[which].add(then);
    return () => listeners[which].delete(then);
  };
  const shortcut = () => ({ text: state.shortcut, keys: keysOf(state.shortcut) });
  const done = async () => {};

  window.loquiFake = {
    state,
    allowMicrophone: () => {
      state.microphoneAllowed = true;
    },
    dictate: (text) => {
      const words = text.split(/\s+/).filter(Boolean).length;
      state.statsAdded.push({ words, seconds: Math.max(1, Math.round((words / 150) * 60)) });
      emit("stats");
      if (state.retention < 0) return;
      state.history.unshift({ at: new Date().toISOString().replace(/\.\d+Z$/, "Z"), text });
      emit("history");
    },
  };

  return {
    general: async (): Promise<General> => ({
      shortcut: shortcut(),
      removeFillers: state.removeFillers,
      fillers: [...state.fillers],
      historyRetentionDays: state.retention,
      startAtSignIn: state.startAtSignIn,
      problem: state.problem,
    }),
    beginShortcut: async () => {
      state.hookPaused = true;
    },
    endShortcut: async () => {
      state.hookPaused = false;
    },
    setShortcut: async (pressed) => {
      if (!allowed(pressed)) throw "Use Ctrl or Alt with a key, or a function key.";
      state.shortcut = pressed;
      emit("settings");
      return shortcut();
    },
    setFillers: async (remove, fillers) => {
      state.removeFillers = remove;
      state.fillers = [...new Set(fillers.map((f) => f.trim().toLowerCase()).filter(Boolean))];
    },
    setRetention: async (days) => {
      state.retention = days;
      if (days > 0) {
        const cutoff = Date.now() - days * 86_400_000;
        state.history = state.history.filter((h) => Date.parse(h.at) >= cutoff);
      }
      emit("history");
    },
    setStartAtSignIn: async (on) => {
      state.startAtSignIn = on;
      emit("settings");
    },
    dictionary: async () => [...state.dictionary].sort((a, b) => a.heard.localeCompare(b.heard)),
    setDictionary: async (terms) => {
      state.dictionary = terms
        .map((t) => ({ heard: t.heard.trim().toLowerCase(), replacement: t.replacement.trim() }))
        .filter((t) => t.heard && t.replacement);
    },
    history: async () => [...state.history],
    deleteHistory: async (item) => {
      state.history = state.history.filter((h) => h.at !== item.at || h.text !== item.text);
      emit("history");
    },
    clearHistory: async () => {
      state.history = [];
      emit("history");
    },
    copyText: async (text) => {
      state.clipboard = text;
    },
    welcome: async () => ({
      microphoneAllowed: state.microphoneAllowed,
      shortcut: shortcut(),
      startAtSignIn: state.startAtSignIn,
    }),
    openMicrophoneSettings: done,
    finishWelcome: async () => {
      state.onboarded = true;
      state.closed = true;
    },
    closeWindow: async () => {
      state.closed = true;
    },
    stats: async (request) => {
      const answer = await fetch("/__fake/stats", {
        method: "POST",
        body: JSON.stringify({
          request,
          empty: ask.get("stats") === "empty",
          added: state.statsAdded,
          shortcut: state.shortcut,
        }),
      });
      if (!answer.ok) throw await answer.text();
      return answer.json();
    },
    onHistoryChanged: subscribe("history"),
    onSettingsChanged: subscribe("settings"),
    onStatsChanged: subscribe("stats"),
    ...fakeUpdates(ask),
  };
}
