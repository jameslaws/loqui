import { type KeyboardEvent, useCallback, useEffect, useId, useRef, useState } from "react";
import { backend } from "./backend";
import type { General as GeneralSettings, ShortcutView, Term } from "./bindings";
import { ShortcutRecorder } from "./Shortcut";
import { UpdatesCard } from "./UpdatesCard";
import { Confirm, Problem, Toggle, TrashIcon, why } from "./ui";

const TABS = ["General", "Dictionary"] as const;
type Tab = (typeof TABS)[number];

/** How long history is kept, in the Mac's meanings: -1 off, 0 forever, N days. */
const RETENTION: [number, string][] = [
  [-1, "Off: don’t save"],
  [7, "7 days"],
  [30, "30 days"],
  [90, "90 days"],
  [0, "Forever"],
];

/** Settings: General and Dictionary, as on the Mac. */
export function Settings() {
  const [tab, setTab] = useState<Tab>("General");
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  const onArrow = (event: KeyboardEvent) => {
    const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
    if (!step) return;
    const next = TABS[(TABS.indexOf(tab) + step + TABS.length) % TABS.length];
    setTab(next);
    tabs.current[TABS.indexOf(next)]?.focus();
  };
  return (
    <main className="page settings">
      <div className="tabs" role="tablist" aria-label="Settings" onKeyDown={onArrow}>
        {TABS.map((name, i) => (
          <button
            key={name}
            ref={(el) => {
              tabs.current[i] = el;
            }}
            type="button"
            role="tab"
            id={`tab-${name}`}
            className="tab"
            aria-selected={tab === name}
            aria-controls={`panel-${name}`}
            tabIndex={tab === name ? 0 : -1}
            onClick={() => setTab(name)}
          >
            {name}
          </button>
        ))}
      </div>
      <div role="tabpanel" id={`panel-${tab}`} aria-labelledby={`tab-${tab}`}>
        {tab === "General" ? <General /> : <Dictionary />}
      </div>
    </main>
  );
}

function General() {
  const [general, setGeneral] = useState<GeneralSettings | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [newFiller, setNewFiller] = useState("");
  const [confirmClear, setConfirmClear] = useState(false);
  const fillerLabel = useId();
  const signInLabel = useId();

  const load = useCallback(() => {
    backend.general().then(
      (g) => {
        setGeneral(g);
        setProblem(g.problem);
      },
      (e) => setProblem(why(e)),
    );
  }, []);
  useEffect(() => {
    load();
    return backend.onSettingsChanged(load);
  }, [load]);
  const onSaved = useCallback((shortcut: ShortcutView) => {
    setGeneral((g) => g && { ...g, shortcut });
  }, []);

  if (!general) return <Problem text={problem ?? "Loading…"} onRetry={problem ? load : undefined} />;

  /** Show the change at once; if loqui can't save it, say why and show what's saved. */
  const save = (change: Partial<GeneralSettings>, saving: Promise<void>) => {
    setGeneral({ ...general, ...change });
    saving.then(
      () => setProblem(null),
      (e) => {
        setProblem(why(e));
        load();
      },
    );
  };
  const setFillers = (removeFillers: boolean, fillers: string[]) =>
    save({ removeFillers, fillers }, backend.setFillers(removeFillers, fillers));
  const addFiller = () => {
    const word = newFiller.trim().toLowerCase();
    setNewFiller("");
    if (word && !general.fillers.includes(word)) setFillers(general.removeFillers, [...general.fillers, word]);
  };

  return (
    <>
      <Problem text={problem} />
      <h2 className="group-label">Shortcut</h2>
      <div className="card">
        <ShortcutRecorder shortcut={general.shortcut} onSaved={onSaved} />
      </div>

      <h2 className="group-label">Cleanup</h2>
      <div className="card">
        <div className="row">
          <span className="grow" id={fillerLabel}>
            Remove filler words
          </span>
          <Toggle
            label="Remove filler words"
            on={general.removeFillers}
            onChange={(on) => setFillers(on, general.fillers)}
          />
        </div>
        {general.removeFillers && (
          <>
            <div className="row">
              <ul className="chips" aria-labelledby={fillerLabel}>
                {general.fillers.map((word) => (
                  <li key={word} className="chip">
                    {word}
                    <button
                      type="button"
                      aria-label={`Remove ${word}`}
                      onClick={() =>
                        setFillers(
                          general.removeFillers,
                          general.fillers.filter((w) => w !== word),
                        )
                      }
                    >
                      ×
                    </button>
                  </li>
                ))}
              </ul>
            </div>
            <form
              className="row"
              onSubmit={(event) => {
                event.preventDefault();
                addFiller();
              }}
            >
              <input
                className="field grow"
                aria-label="Add a filler word"
                placeholder="Add a filler word"
                value={newFiller}
                onChange={(event) => setNewFiller(event.target.value)}
              />
              <button type="submit" className="btn" disabled={!newFiller.trim()}>
                Add
              </button>
            </form>
          </>
        )}
      </div>

      <h2 className="group-label">History</h2>
      <div className="card">
        <div className="row">
          <label className="grow" htmlFor="keep-history">
            Keep history
          </label>
          <select
            id="keep-history"
            className="field"
            value={general.historyRetentionDays}
            onChange={(event) => {
              const days = Number(event.target.value);
              save({ historyRetentionDays: days }, backend.setRetention(days));
            }}
          >
            {RETENTION.map(([days, label]) => (
              <option key={days} value={days}>
                {label}
              </option>
            ))}
          </select>
        </div>
        <div className="row">
          <span className="grow" id={signInLabel}>
            Start loqui when you sign in
          </span>
          <Toggle
            label="Start loqui when you sign in"
            on={general.startAtSignIn}
            onChange={(on) => save({ startAtSignIn: on }, backend.setStartAtSignIn(on))}
          />
        </div>
        <div className="row">
          <div className="grow">
            <div>Clear history</div>
            <p className="caption">Deletes every saved dictation on this PC</p>
          </div>
          <button type="button" className="btn danger" onClick={() => setConfirmClear(true)}>
            Clear history…
          </button>
        </div>
      </div>
      <UpdatesCard />
      <ClearHistory
        open={confirmClear}
        onDone={(failed) => {
          setConfirmClear(false);
          setProblem(failed);
        }}
      />
    </>
  );
}

/** Clear history asks first, as on the Mac. Shared with the history window. */
export function ClearHistory({ open, onDone }: { open: boolean; onDone: (problem: string | null) => void }) {
  return (
    <Confirm
      open={open}
      title="Clear all dictation history?"
      message="This deletes every saved dictation on this PC. It can’t be undone. Your stats are kept."
      action="Clear"
      onAnswer={(yes) => {
        if (!yes) return onDone(null);
        backend.clearHistory().then(
          () => onDone(null),
          (e) => onDone(why(e)),
        );
      }}
    />
  );
}

type Row = Term & { id: number };

function Dictionary() {
  const [rows, setRows] = useState<Row[] | null>(null);
  const [query, setQuery] = useState("");
  const [problem, setProblem] = useState<string | null>(null);
  const nextId = useRef(0);
  const focusNew = useRef<number | null>(null);

  const load = useCallback(() => {
    backend.dictionary().then(
      (terms) => {
        setRows(terms.map((t) => ({ ...t, id: nextId.current++ })));
        setProblem(null);
      },
      (e) => setProblem(why(e)),
    );
  }, []);
  useEffect(() => {
    load();
  }, [load]);

  if (!rows) return <Problem text={problem ?? "Loading…"} onRetry={problem ? load : undefined} />;

  const save = (next: Row[]) => {
    setRows(next);
    backend.setDictionary(next.map(({ heard, replacement }) => ({ heard, replacement }))).then(
      () => setProblem(null),
      (e) => setProblem(why(e)),
    );
  };
  const edit = (id: number, change: Partial<Term>) => save(rows.map((r) => (r.id === id ? { ...r, ...change } : r)));
  const add = () => {
    const id = nextId.current++;
    focusNew.current = id;
    setQuery("");
    setRows([{ id, heard: "", replacement: "" }, ...rows]);
  };
  const q = query.trim().toLowerCase();
  const shown = rows.filter((r) => !q || r.heard.toLowerCase().includes(q) || r.replacement.toLowerCase().includes(q));

  return (
    <>
      <div className="dictionary-bar">
        <input
          type="search"
          className="field grow"
          aria-label="Search the dictionary"
          placeholder="Search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        <button type="button" className="btn primary" onClick={add}>
          + Add term
        </button>
      </div>
      <Problem text={problem} />
      {rows.length === 0 ? (
        <div className="card empty">
          <p className="strong">Add words loqui mishears</p>
          <p className="caption">Names, brands and jargon: what loqui hears, and how you want it written.</p>
        </div>
      ) : shown.length === 0 ? (
        <div className="card empty">
          <p className="strong">No matches</p>
          <p className="caption">Try a different search.</p>
        </div>
      ) : (
        <ul className="card terms" aria-label="Dictionary">
          {shown.map((row) => (
            <li key={row.id} className="row">
              <input
                className="field grow"
                aria-label="Heard"
                placeholder="Heard"
                value={row.heard}
                ref={(el) => {
                  if (el && focusNew.current === row.id) {
                    focusNew.current = null;
                    el.focus();
                  }
                }}
                onChange={(event) => edit(row.id, { heard: event.target.value })}
              />
              <span aria-hidden="true" className="muted">
                →
              </span>
              <input
                className="field grow"
                aria-label={`Written as, for ${row.heard || "the new term"}`}
                placeholder="Written as"
                value={row.replacement}
                onChange={(event) => edit(row.id, { replacement: event.target.value })}
              />
              <button
                type="button"
                className="btn quiet"
                aria-label={`Delete ${row.heard || "the new term"}`}
                onClick={() => save(rows.filter((r) => r.id !== row.id))}
              >
                <TrashIcon />
              </button>
            </li>
          ))}
        </ul>
      )}
      <p className="caption dictionary-note">
        Anything loqui mishears → the spelling you want. Matched as whole words, any case.
      </p>
    </>
  );
}
