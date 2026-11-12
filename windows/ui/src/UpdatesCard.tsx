import { useCallback, useEffect, useId, useState } from "react";
import { backend } from "./backend";
import type { Updates } from "./bindings";
import { Problem, Toggle, why } from "./ui";

/** "checked today at 9:12 AM", "checked Nov 10 at 9:12 AM": local time, as Windows shows it. */
export function checkedWhen(iso: string, now = new Date()) {
  const at = new Date(iso);
  const time = at.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const sameDay = at.toDateString() === now.toDateString();
  const day = sameDay ? "today" : at.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  return `checked ${day} at ${time}`;
}

/** The line under the version: where the last check stands. */
export function statusLine(updates: Updates) {
  const s = updates.status;
  switch (s.state) {
    case "notChecked":
      return "Not checked yet";
    case "checking":
      return "Checking for updates…";
    case "upToDate":
      return updates.checkedAt ? `Up to date · ${checkedWhen(updates.checkedAt)}` : "Up to date";
    case "available":
      return `loqui ${s.version} is ready to install`;
    case "downloading":
      return s.percent === null ? "Downloading the update…" : `Downloading the update… ${s.percent}%`;
    case "installing":
      return "Installing the update…";
    case "checkFailed":
    case "installFailed":
      return s.message;
  }
}

/** Settings, General: the version, Check for updates, and Get test versions. */
export function UpdatesCard() {
  const [updates, setUpdates] = useState<Updates | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const testNote = useId();

  const load = useCallback(() => {
    backend.updates().then(
      (u) => {
        setUpdates(u);
        setProblem(null);
      },
      (e) => setProblem(why(e)),
    );
  }, []);
  useEffect(() => {
    load();
    return backend.onUpdatesChanged(load);
  }, [load]);

  if (!updates) {
    return (
      <>
        <h2 className="group-label">Updates</h2>
        <Problem text={problem ?? "Loading…"} onRetry={problem ? load : undefined} />
      </>
    );
  }
  const busy = ["checking", "downloading", "installing"].includes(updates.status.state);
  const failed = updates.status.state === "checkFailed" || updates.status.state === "installFailed";

  return (
    <>
      <h2 className="group-label">Updates</h2>
      <Problem text={problem} />
      <div className="card">
        <div className="row">
          <div className="grow">
            <div>loqui {updates.version}</div>
            <p className={failed ? "caption problem-text" : "caption"} role="status">
              {statusLine(updates)}
            </p>
          </div>
          <button
            type="button"
            className="btn"
            disabled={busy}
            onClick={() => backend.checkForUpdates().then(setUpdates, (e) => setProblem(why(e)))}
          >
            Check for updates
          </button>
        </div>
        <div className="row">
          <div className="grow">
            <div>Get test versions</div>
            <p className="caption" id={testNote}>
              Try new versions before everyone else. They may have rough edges.
            </p>
          </div>
          <Toggle
            label="Get test versions"
            describedBy={testNote}
            on={updates.testVersions}
            onChange={(on) => {
              setUpdates({ ...updates, testVersions: on });
              backend.setTestVersions(on).then(setUpdates, (e) => {
                setProblem(why(e));
                load();
              });
            }}
          />
        </div>
      </div>
      <p className="caption settings-foot">
        The update check is the only thing loqui sends over the internet. It asks GitHub whether a newer version exists.
      </p>
    </>
  );
}
