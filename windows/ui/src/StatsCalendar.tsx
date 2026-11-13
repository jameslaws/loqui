import { useEffect, useRef, useState } from "react";
import type { Calendar, Grain, Period } from "./bindings";
import { wordsText } from "./StatsChart";

const MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];
const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

const pad = (n: number) => String(n).padStart(2, "0");
const dayText = (y: number, m: number, d: number) => `${y}-${pad(m)}-${pad(d)}`;
const monthText = (y: number, m: number) => `${y}-${pad(m)}`;
const daysIn = (y: number, m: number) => new Date(Date.UTC(y, m, 0)).getUTCDate();
const weekdayOf = (y: number, m: number, d: number) => new Date(Date.UTC(y, m - 1, d)).getUTCDay();

/**
 * How dark a day or month is: its words against the busiest day or month
 * ever, not just this page's, so a quiet month looks quiet. A square root
 * keeps quiet days visible.
 */
export const shade = (words: number, busiest: number) => (words > 0 && busiest > 0 ? Math.sqrt(words / busiest) : 0);

/**
 * Jump straight to a period: a month of days (Day and Week), a year of
 * months (Month) or a list of years (Year), shaded by words so the busy day
 * you're after can be seen. Esc closes it.
 */
export function StatsCalendar({
  grain,
  period,
  calendar,
  onPick,
  onClose,
}: {
  grain: Grain;
  period: Period;
  calendar: Calendar;
  onPick: (day: string) => void;
  onClose: () => void;
}) {
  const start = period.first ?? calendar.today;
  const [year, setYear] = useState(Number(start.slice(0, 4)));
  const [month, setMonth] = useState(Number(start.slice(5, 7)));
  const box = useRef<HTMLDivElement>(null);
  const days = new Map(calendar.days.map((d) => [d.date, d.words]));
  const months = new Map(calendar.months.map((d) => [d.date, d.words]));
  const usable = (day: string) => calendar.firstDay !== null && day >= calendar.firstDay && day <= calendar.today;
  const chosen = (day: string) =>
    period.first !== null && period.last !== null && day >= period.first && day <= period.last;

  // Open on the chosen day (or the first one that can be picked).
  useEffect(() => {
    const target =
      box.current?.querySelector<HTMLButtonElement>("[aria-current='true']:not(:disabled)") ??
      box.current?.querySelector<HTMLButtonElement>(".pick:not(:disabled)");
    target?.focus();
  }, []);
  useEffect(() => {
    const away = (event: MouseEvent) => {
      if (!box.current?.contains(event.target as Node)) onClose();
    };
    document.addEventListener("mousedown", away);
    return () => document.removeEventListener("mousedown", away);
  }, [onClose]);

  const stepMonth = (by: number) => {
    const n = year * 12 + (month - 1) + by;
    setYear(Math.floor(n / 12));
    setMonth((n % 12) + 1);
  };
  const header = (title: string, step: (by: number) => void, unit: string) => (
    <div className="cal-head">
      <button type="button" className="btn quiet cal-step" aria-label={`Previous ${unit}`} onClick={() => step(-1)}>
        ‹
      </button>
      <h2 className="cal-title" aria-live="polite">
        {title}
      </h2>
      <button type="button" className="btn quiet cal-step" aria-label={`Next ${unit}`} onClick={() => step(1)}>
        ›
      </button>
    </div>
  );
  const cell = (
    key: string,
    text: string,
    label: string,
    words: number,
    busiest: number,
    can: boolean,
    on: boolean,
  ) => (
    <button
      key={key}
      type="button"
      className={`pick${on ? " on" : ""}`}
      style={{ "--shade": `${words > 0 ? Math.round(16 + 56 * shade(words, busiest)) : 0}%` } as React.CSSProperties}
      aria-label={`${label}, ${words > 0 ? wordsText(words) : "no dictations"}`}
      aria-current={on ? "true" : undefined}
      disabled={!can}
      title={words > 0 ? wordsText(words) : "No dictations"}
      onClick={() => onPick(key)}
    >
      {text}
    </button>
  );

  let body: React.ReactNode;
  let name: string;
  if (grain === "day" || grain === "week") {
    name = grain === "day" ? "Choose a day" : "Choose a week";
    const lead = (weekdayOf(year, month, 1) - calendar.firstWeekday + 7) % 7;
    const heads = Array.from({ length: 7 }, (_, i) => WEEKDAYS[(calendar.firstWeekday + i) % 7]);
    body = (
      <>
        {header(`${MONTHS[month - 1]} ${year}`, stepMonth, "month")}
        <div className="cal-grid cal-days" aria-hidden="true">
          {heads.map((d) => (
            <span key={d} className="cal-weekday">
              {d[0]}
            </span>
          ))}
        </div>
        <div className="cal-grid cal-days">
          {lead > 0 && <span style={{ gridColumn: `span ${lead}` }} />}
          {Array.from({ length: daysIn(year, month) }, (_, i) => {
            const day = dayText(year, month, i + 1);
            const label = `${WEEKDAYS[weekdayOf(year, month, i + 1)]}, ${MONTHS[month - 1].slice(0, 3)} ${i + 1}, ${year}`;
            return cell(day, String(i + 1), label, days.get(day) ?? 0, calendar.busiestDay, usable(day), chosen(day));
          })}
        </div>
        <p className="caption cal-note">{grain === "week" ? "Picks the whole week" : "Darker days had more words"}</p>
      </>
    );
  } else if (grain === "month") {
    name = "Choose a month";
    body = (
      <>
        {header(String(year), (by) => setYear(year + by), "year")}
        <div className="cal-grid cal-months">
          {MONTHS.map((m, i) => {
            const first = dayText(year, i + 1, 1);
            const last = dayText(year, i + 1, daysIn(year, i + 1));
            return cell(
              first,
              m.slice(0, 3),
              `${m} ${year}`,
              months.get(monthText(year, i + 1)) ?? 0,
              calendar.busiestMonth,
              usable(first) ||
                usable(last) ||
                (calendar.firstDay !== null && calendar.firstDay >= first && calendar.firstDay <= last),
              chosen(first),
            );
          })}
        </div>
      </>
    );
  } else {
    name = "Choose a year";
    body = (
      <ul className="cal-years">
        {calendar.years.map((y) => {
          const on = chosen(`${y.year}-01-01`);
          return (
            <li key={y.year}>
              <button
                type="button"
                className={`pick year${on ? " on" : ""}`}
                aria-current={on ? "true" : undefined}
                onClick={() => onPick(`${y.year}-01-01`)}
              >
                <span>{y.year}</span>
                <span className="caption">{wordsText(y.words)}</span>
              </button>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <div
      ref={box}
      className="card cal"
      role="dialog"
      aria-label={name}
      onKeyDown={(event) => {
        // Esc closes the calendar, and doesn't reach the window (which it would close).
        if (event.key === "Escape") {
          event.preventDefault();
          onClose();
        }
      }}
    >
      {body}
    </div>
  );
}
