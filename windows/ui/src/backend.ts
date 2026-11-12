import type { General, HistoryItem, ShortcutView, Stats, StatsRequest, Term, Updates, Welcome } from "./bindings";
import { events } from "./bindings";

/**
 * Everything a screen can ask of loqui. In the app these are Rust commands
 * (src-tauri/src/commands.rs) over loqui-core; in a plain browser, for the
 * screen tests, a stand-in keeps the same promises in memory (fake-backend.ts).
 * Screens never read or write files themselves.
 */
export interface Backend {
  general(): Promise<General>;
  beginShortcut(): Promise<void>;
  endShortcut(): Promise<void>;
  /** Resolves with the saved shortcut, or rejects with why it can't be one. */
  setShortcut(pressed: string): Promise<ShortcutView>;
  setFillers(remove: boolean, fillers: string[]): Promise<void>;
  setRetention(days: number): Promise<void>;
  setStartAtSignIn(on: boolean): Promise<void>;
  dictionary(): Promise<Term[]>;
  setDictionary(terms: Term[]): Promise<void>;
  history(): Promise<HistoryItem[]>;
  deleteHistory(item: HistoryItem): Promise<void>;
  clearHistory(): Promise<void>;
  copyText(text: string): Promise<void>;
  welcome(): Promise<Welcome>;
  openMicrophoneSettings(): Promise<void>;
  finishWelcome(): Promise<void>;
  closeWindow(): Promise<void>;
  stats(request: StatsRequest): Promise<Stats>;
  /** Call `then` whenever history changes; returns how to stop. */
  onHistoryChanged(then: () => void): () => void;
  onSettingsChanged(then: () => void): () => void;
  /** A dictation was counted for stats. */
  onStatsChanged(then: () => void): () => void;
  /** The Updates card and the update window. */
  updates(): Promise<Updates>;
  /** Check now; resolves when the check is done. */
  checkForUpdates(): Promise<Updates>;
  /** Download, verify and install the offered update; loqui then restarts. */
  installUpdate(): Promise<void>;
  setTestVersions(on: boolean): Promise<Updates>;
  onUpdatesChanged(then: () => void): () => void;
}

async function tauriBackend(): Promise<Backend> {
  const { invoke } = await import("@tauri-apps/api/core");
  const { listen } = await import("@tauri-apps/api/event");
  const on = (name: string) => (then: () => void) => {
    const stop = listen(name, then);
    return () => {
      stop.then((unlisten) => unlisten());
    };
  };
  return {
    general: () => invoke("general"),
    beginShortcut: () => invoke("begin_shortcut"),
    endShortcut: () => invoke("end_shortcut"),
    setShortcut: (pressed) => invoke("set_shortcut", { pressed }),
    setFillers: (remove, fillers) => invoke("set_fillers", { remove, fillers }),
    setRetention: (days) => invoke("set_retention", { days }),
    setStartAtSignIn: (on) => invoke("set_start_at_sign_in", { on }),
    dictionary: () => invoke("dictionary"),
    setDictionary: (terms) => invoke("set_dictionary", { terms }),
    history: () => invoke("history"),
    deleteHistory: (item) => invoke("delete_history", { item }),
    clearHistory: () => invoke("clear_history"),
    copyText: (text) => invoke("copy_text", { text }),
    welcome: () => invoke("welcome"),
    openMicrophoneSettings: () => invoke("open_microphone_settings"),
    finishWelcome: () => invoke("finish_welcome"),
    closeWindow: () => invoke("close_window"),
    stats: (request) => invoke("stats", { request }),
    onHistoryChanged: on(events.historyChanged),
    onSettingsChanged: on(events.settingsChanged),
    onStatsChanged: on(events.statsChanged),
    updates: () => invoke("updates"),
    checkForUpdates: () => invoke("check_for_updates"),
    installUpdate: () => invoke("install_update"),
    setTestVersions: (on) => invoke("set_test_versions", { on }),
    onUpdatesChanged: on(events.updatesChanged),
  };
}

const inApp = "__TAURI_INTERNALS__" in window;

/** loqui itself, or the in-memory stand-in when the page runs in a browser. */
export const backend: Backend = inApp
  ? await tauriBackend()
  : await import("./fake-backend").then((m) => m.fakeBackend());
