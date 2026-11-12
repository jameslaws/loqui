import { useCallback, useEffect, useState } from "react";
import { backend } from "./backend";
import type { HistoryItem, ShortcutView } from "./bindings";
import { ClearHistory } from "./Settings";
import { Problem, TrashIcon, why } from "./ui";

const when = new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" });
const COPIED_FOR_MS = 1200;

/** Dictation history: newest first, searchable, copy or delete any one. Updates while open. */
export function History() {
  const [items, setItems] = useState<HistoryItem[] | null>(null);
  const [shortcut, setShortcut] = useState<ShortcutView | null>(null);
  const [query, setQuery] = useState("");
  const [copied, setCopied] = useState<HistoryItem | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);

  const load = useCallback(() => {
    backend.history().then(
      (list) => {
        setItems(list);
        setProblem(null);
      },
      (e) => setProblem(why(e)),
    );
  }, []);
  const loadShortcut = useCallback(() => {
    backend.general().then(
      (g) => setShortcut(g.shortcut),
      () => {},
    );
  }, []);
  useEffect(() => {
    load();
    loadShortcut();
    const stopHistory = backend.onHistoryChanged(load);
    const stopSettings = backend.onSettingsChanged(loadShortcut);
    return () => {
      stopHistory();
      stopSettings();
    };
  }, [load, loadShortcut]);
  useEffect(() => {
    if (!copied) return;
    const timer = setTimeout(() => setCopied(null), COPIED_FOR_MS);
    return () => clearTimeout(timer);
  }, [copied]);

  if (!items) {
    return (
      <main className="page history">
        <Problem text={problem ?? "Loading…"} onRetry={problem ? load : undefined} />
      </main>
    );
  }

  const q = query.trim().toLowerCase();
  const shown = items.filter((item) => !q || item.text.toLowerCase().includes(q));
  const copy = (item: HistoryItem) =>
    backend.copyText(item.text).then(
      () => setCopied(item),
      (e) => setProblem(why(e)),
    );
  const remove = (item: HistoryItem) => backend.deleteHistory(item).catch((e) => setProblem(why(e)));

  if (items.length === 0) {
    return (
      <main className="page history">
        <Problem text={problem} />
        <div className="empty history-empty">
          <h1 className="subtitle">No dictations yet</h1>
          <p className="muted">{`Press ${shortcut?.text ?? "your shortcut"} anywhere and start talking.`}</p>
        </div>
      </main>
    );
  }

  return (
    <main className="page history">
      <h1 className="visually-hidden">Dictation history</h1>
      <div className="history-bar">
        <input
          type="search"
          className="field grow"
          aria-label="Search dictations"
          placeholder="Search dictations"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        <button type="button" className="btn danger" onClick={() => setConfirmClear(true)}>
          Clear all…
        </button>
      </div>
      <Problem text={problem} />
      {shown.length === 0 ? (
        <div className="card empty">
          <p className="strong">No matches</p>
          <p className="caption">Try a different search.</p>
        </div>
      ) : (
        <ul className="card entries" aria-label="Dictations, newest first">
          {shown.map((item) => {
            const isCopied = copied?.at === item.at && copied.text === item.text;
            return (
              <li key={`${item.at}${item.text}`} className="row entry">
                <div className="grow">
                  <p className="entry-text">{item.text}</p>
                  <p className="caption">
                    <time dateTime={item.at}>{when.format(new Date(item.at))}</time>
                  </p>
                </div>
                <button type="button" className="btn quiet" onClick={() => copy(item)}>
                  {isCopied ? "Copied" : "Copy"}
                </button>
                <button
                  type="button"
                  className="btn quiet"
                  aria-label={`Delete the dictation from ${when.format(new Date(item.at))}`}
                  onClick={() => remove(item)}
                >
                  <TrashIcon />
                </button>
              </li>
            );
          })}
        </ul>
      )}
      <ClearHistory
        open={confirmClear}
        onDone={(failed) => {
          setConfirmClear(false);
          setProblem(failed);
        }}
      />
    </main>
  );
}
