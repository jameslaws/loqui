import { useCallback, useEffect, useRef, useState } from "react";
import { backend } from "./backend";
import type { Stats as Figures, Grain, StatsRequest } from "./bindings";
import { StatsCalendar } from "./StatsCalendar";
import { BarChart } from "./StatsChart";
import { Problem, why } from "./ui";
import "./stats.css";

const GRAINS: [Grain, string][] = [
  ["allTime", "All time"],
  ["year", "Year"],
  ["month", "Month"],
  ["week", "Week"],
  ["day", "Day"],
];

/**
 * Dictation stats, as on the Mac: the totals, today, this week and this
 * month, the last 30 days and 12 months, and Patterns for any period, picked
 * with the arrows or the shaded calendar. loqui-core works out every figure;
 * this only draws them. Updates while open.
 */
export function Stats() {
  const [request, setRequest] = useState<StatsRequest>({ grain: "allTime", offset: 0, jumpTo: null });
  const [stats, setStats] = useState<Figures | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const [picking, setPicking] = useState(false);
  const periodButton = useRef<HTMLButtonElement>(null);
  // The latest period asked for: an answer to an earlier one is dropped, so a
  // slow answer never replaces a newer one.
  const latest = useRef(request);
  latest.current = request;

  const load = useCallback(() => {
    backend.stats(request).then(
      (answer) => {
        if (latest.current !== request) return;
        setStats(answer);
        setProblem(null);
        // A jump lands on a period: keep it as the one to step from and reload.
        if (request.jumpTo !== null)
          setRequest({ grain: answer.period.grain, offset: answer.period.offset, jumpTo: null });
      },
      (e) => {
        if (latest.current === request) setProblem(why(e));
      },
    );
  }, [request]);
  useEffect(() => {
    load();
    const stopStats = backend.onStatsChanged(load);
    const stopSettings = backend.onSettingsChanged(load);
    return () => {
      stopStats();
      stopSettings();
    };
  }, [load]);

  if (!stats) {
    return (
      <main className="page stats">
        <Problem text={problem ?? "Loading…"} onRetry={problem ? load : undefined} />
      </main>
    );
  }

  if (stats.empty) {
    return (
      <main className="page stats">
        <h1 className="title">Dictation</h1>
        <Problem text={problem} onRetry={load} />
        <div className="empty stats-empty">
          <h2 className="strong">No dictations yet</h2>
          <p className="muted">
            Your words, pace and time saved show up here after your first dictation.
            <br />
            {`Press ${stats.shortcut} anywhere to start.`}
          </p>
        </div>
      </main>
    );
  }

  const { period } = stats;
  const choose = (grain: Grain) => {
    setPicking(false);
    if (grain !== request.grain) setRequest({ grain, offset: 0, jumpTo: null });
  };
  const unit = GRAINS.find(([g]) => g === period.grain)?.[1].toLowerCase() ?? "";

  return (
    <main className="page stats">
      <header>
        <h1 className="title">Dictation</h1>
        <p className="muted">{stats.summary}</p>
      </header>
      <Problem text={problem} onRetry={load} />

      <div className="stat-cards">
        {stats.cards.map((card) => (
          <section key={card.title} className="card stat-card" aria-label={card.title}>
            <h2 className="caption">{card.title}</h2>
            <p className="stat-value">{card.value}</p>
            <p className={`caption${card.up ? " up" : ""}`}>{card.compare}</p>
          </section>
        ))}
      </div>

      <BarChart title="Last 30 days" bars={stats.last30Days} height={150} tickEvery={7} ticksFromEnd />
      <BarChart title="By month" bars={stats.byMonth} height={150} tickEvery={3} />

      <div className="patterns-head">
        <h2 className="patterns-title">Patterns</h2>
        <GrainPicker grain={request.grain} onChoose={choose} />
      </div>
      {period.grain !== "allTime" && (
        <div className="period">
          <button
            type="button"
            className="btn quiet period-step"
            aria-label={`Previous ${unit}`}
            onClick={() => {
              setPicking(false);
              // From the last step asked for, so quick clicks each count.
              setRequest((r) => ({ grain: r.grain, offset: r.offset - 1, jumpTo: null }));
            }}
          >
            ‹
          </button>
          <div className="period-pick">
            <button
              ref={periodButton}
              type="button"
              className="btn period-label"
              aria-haspopup="dialog"
              aria-expanded={picking}
              aria-label={`${period.label}, choose a ${unit}`}
              onClick={() => setPicking(!picking)}
            >
              {period.label}
              <svg width="10" height="10" viewBox="0 0 10 10" aria-hidden="true" className="icon">
                <path d="M2 3.5l3 3 3-3" />
              </svg>
            </button>
            {picking && (
              <StatsCalendar
                grain={period.grain}
                period={period}
                calendar={stats.calendar}
                onPick={(day) => {
                  setPicking(false);
                  setRequest({ grain: period.grain, offset: period.offset, jumpTo: day });
                  periodButton.current?.focus();
                }}
                onClose={() => {
                  setPicking(false);
                  periodButton.current?.focus();
                }}
              />
            )}
          </div>
          <button
            type="button"
            className="btn quiet period-step"
            aria-label={`Next ${unit}`}
            disabled={period.offset >= 0}
            onClick={() => {
              setPicking(false);
              setRequest((r) => ({ grain: r.grain, offset: Math.min(0, r.offset + 1), jumpTo: null }));
            }}
          >
            ›
          </button>
        </div>
      )}

      <BarChart title="By weekday" bars={period.byWeekday} height={110} tickEvery={1} />
      <BarChart title="By hour of day" bars={period.byHour} height={110} tickEvery={3} />

      {period.emptyText ? (
        <p className="muted period-empty">{period.emptyText}</p>
      ) : (
        <ul className="tiles" aria-label={`Patterns for ${period.label}`}>
          {period.tiles.map((tile) => (
            <li key={tile.title} className="card tile">
              <h3 className="caption">{tile.title}</h3>
              <p className="tile-value">{tile.value}</p>
              {tile.detail && <p className="caption">{tile.detail}</p>}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}

/** All time, Year, Month, Week, Day: one choice; the arrow keys move it, as with any radio buttons. */
function GrainPicker({ grain, onChoose }: { grain: Grain; onChoose: (grain: Grain) => void }) {
  return (
    <fieldset className="segmented">
      <legend className="visually-hidden">Patterns for</legend>
      {GRAINS.map(([g, name]) => (
        <label key={g}>
          <input
            type="radio"
            name="grain"
            value={g}
            aria-label={name}
            checked={g === grain}
            onChange={() => onChoose(g)}
          />
          {name}
        </label>
      ))}
    </fieldset>
  );
}
