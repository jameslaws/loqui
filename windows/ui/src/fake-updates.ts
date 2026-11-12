import type { Backend } from "./backend";
import type { Updates } from "./bindings";

/**
 * The update parts of the in-browser stand-in (fake-backend.ts). Start a page
 * with `?update=available`, `offline`, `uptodate` or `unverified` to choose
 * what the next check and install find; add `&found=1` to open as if the
 * daily check had already found it. A test can look inside with
 * `window.loquiUpdates`.
 */
export type UpdatesPart = Pick<
  Backend,
  "updates" | "checkForUpdates" | "installUpdate" | "setTestVersions" | "onUpdatesChanged"
>;

declare global {
  interface Window {
    loquiUpdates?: { state: Updates; checks: number; installs: number };
  }
}

// The stand-in's own copies of what loqui says; loqui-core's `say` is the real one.
const UNREACHABLE = "Couldn't reach the update server. Try again later.";
const UNVERIFIED = "This update couldn't be verified, so it wasn't installed.";

function available(): Updates["status"] {
  return {
    state: "available",
    version: "0.0.3",
    notes: "- The dictation bubble follows the screen you’re working on\n- Faster first dictation after the PC wakes",
    sizeMb: 12,
  };
}

export function fakeUpdates(ask: URLSearchParams): UpdatesPart {
  const scenario = ask.get("update") ?? "uptodate";
  const fake = {
    state: {
      version: "0.0.2",
      testVersions: ask.get("test") === "on",
      checkedAt: null,
      status: { state: "notChecked" },
    } as Updates,
    checks: 0,
    installs: 0,
  };
  if (ask.get("found")) {
    fake.state.checkedAt = new Date().toISOString();
    fake.state.status = available();
  }
  window.loquiUpdates = fake;
  const listeners = new Set<() => void>();
  const changed = (status: Updates["status"]) => {
    fake.state = { ...fake.state, status };
    for (const then of listeners) then();
  };

  return {
    updates: async () => ({ ...fake.state }),
    checkForUpdates: async () => {
      fake.checks++;
      if (scenario === "offline") changed({ state: "checkFailed", message: UNREACHABLE });
      else {
        fake.state.checkedAt = new Date().toISOString();
        changed(scenario === "uptodate" ? { state: "upToDate" } : available());
      }
      return { ...fake.state };
    },
    installUpdate: async () => {
      if (fake.state.status.state !== "available") return;
      fake.installs++;
      changed({ state: "downloading", percent: 40 });
      changed(scenario === "unverified" ? { state: "installFailed", message: UNVERIFIED } : { state: "installing" });
    },
    setTestVersions: async (on) => {
      fake.state.testVersions = on;
      changed({ state: "notChecked" });
      return { ...fake.state };
    },
    onUpdatesChanged: (then) => {
      listeners.add(then);
      return () => listeners.delete(then);
    },
  };
}
