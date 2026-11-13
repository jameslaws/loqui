import { type ReactNode, useCallback, useEffect, useState } from "react";
import icon from "./assets/icon-256.png";
import { backend } from "./backend";
import type { Updates } from "./bindings";
import { Problem, why } from "./ui";
import "./update.css";

/** Release notes as the window shows them: "- " lines become a list, others stay sentences. */
export function noteLines(notes: string) {
  return notes
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => ({ item: line.startsWith("- ") || line.startsWith("* "), text: line.replace(/^[-*] /, "") }));
}

function Notes({ notes }: { notes: string }) {
  const lines = noteLines(notes);
  if (lines.length === 0) return <p className="muted">This version has no notes.</p>;
  const items = lines.filter((l) => l.item);
  const said = lines.filter((l) => !l.item);
  return (
    <>
      {said.map((l) => (
        <p key={l.text}>{l.text}</p>
      ))}
      {items.length > 0 && (
        <ul>
          {items.map((l) => (
            <li key={l.text}>{l.text}</li>
          ))}
        </ul>
      )}
    </>
  );
}

/**
 * The update window: opens when a check finds a newer version, and from the
 * tray menu's Check for updates, where it says what the check found.
 */
export function Update() {
  const [updates, setUpdates] = useState<Updates | null>(null);
  const [problem, setProblem] = useState<string | null>(null);

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
      <main className="page update">
        <Problem text={problem ?? "Loading…"} onRetry={problem ? load : undefined} />
      </main>
    );
  }

  const s = updates.status;
  const close = () => backend.closeWindow();
  const head = (title: string, line: string) => (
    <header className="update-head">
      <img src={icon} alt="" width={56} height={56} />
      <div>
        <h1 className="subtitle">{title}</h1>
        <p className="muted">{line}</p>
      </div>
    </header>
  );
  const foot = (buttons: ReactNode) => (
    <footer className="update-foot">
      <p className="caption">Updates are checked once a day. Nothing else is sent.</p>
      {buttons}
    </footer>
  );
  const closeButton = (
    <button type="button" className="btn primary" onClick={close}>
      Close
    </button>
  );

  if (s.state === "available") {
    const size = s.sizeMb ? `The download is about ${s.sizeMb} MB; your` : "Your";
    return (
      <main className="page update">
        {head(
          "A new version of loqui is ready",
          `loqui ${s.version} is available. You have ${updates.version}. ${size} speech model stays as it is.`,
        )}
        <section className="update-notes" aria-label="What’s new">
          <h2 className="strong">What’s new</h2>
          <Notes notes={s.notes} />
        </section>
        <Problem text={problem} />
        {foot(
          <>
            <button type="button" className="btn" onClick={close}>
              Later
            </button>
            <button
              type="button"
              className="btn primary"
              onClick={() => backend.installUpdate().catch((e) => setProblem(why(e)))}
            >
              Install and restart loqui
            </button>
          </>,
        )}
      </main>
    );
  }

  if (s.state === "downloading" || s.state === "installing") {
    const installing = s.state === "installing";
    return (
      <main className="page update">
        {head(
          "Updating loqui",
          installing ? "Installing; loqui will start again by itself." : "Downloading the update…",
        )}
        <progress
          className="update-progress"
          max={100}
          value={installing ? 100 : (s.percent ?? undefined)}
          aria-label="Downloading the update"
        />
        {foot(null)}
      </main>
    );
  }

  if (s.state === "checkFailed" || s.state === "installFailed") {
    return (
      <main className="page update">
        {head(s.state === "checkFailed" ? "loqui couldn’t check for updates" : "loqui wasn’t updated", s.message)}
        {foot(
          <>
            <button type="button" className="btn" onClick={close}>
              Close
            </button>
            <button
              type="button"
              className="btn primary"
              onClick={() => backend.checkForUpdates().then(setUpdates, (e) => setProblem(why(e)))}
            >
              Try again
            </button>
          </>,
        )}
      </main>
    );
  }

  if (s.state === "upToDate") {
    return (
      <main className="page update">
        {head("loqui is up to date", `You have the newest version, ${updates.version}.`)}
        {foot(closeButton)}
      </main>
    );
  }

  return (
    <main className="page update">
      {head("Checking for updates…", `You have ${updates.version}.`)}
      {foot(closeButton)}
    </main>
  );
}
