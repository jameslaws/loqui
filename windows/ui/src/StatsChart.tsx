import { type KeyboardEvent, useRef, useState } from "react";
import type { Bar } from "./bindings";

/** "1,412 words", "1 word". */
export const wordsText = (n: number) => `${n.toLocaleString("en-US")} ${n === 1 ? "word" : "words"}`;

const WIDTH = 600;
const GAP = 0.25;

/**
 * A bar chart, drawn as plain SVG in the look's colours. Pointing at a bar or
 * moving to it with the keyboard shows its date and words. The chart is one
 * stop for Tab; the arrow keys, Home and End move between bars, and each bar
 * is read out as "Oct 27: 1,412 words".
 */
export function BarChart({
  title,
  bars,
  height,
  tickEvery,
  ticksFromEnd = false,
}: {
  title: string;
  bars: Bar[];
  height: number;
  /** Label every nth bar on the axis. */
  tickEvery: number;
  /** Count the labelled bars back from the last one (the most recent day). */
  ticksFromEnd?: boolean;
}) {
  const [shown, setShown] = useState<number | null>(null);
  const [current, setCurrent] = useState(bars.length - 1);
  const refs = useRef<(SVGRectElement | null)[]>([]);
  const peak = Math.max(1, ...bars.map((b) => b.words));
  const column = WIDTH / bars.length;
  const focus = (i: number) => {
    setCurrent(i);
    refs.current[i]?.focus();
  };
  const onKey = (event: KeyboardEvent) => {
    const to = {
      ArrowRight: current + 1,
      ArrowLeft: current - 1,
      Home: 0,
      End: bars.length - 1,
    }[event.key];
    if (to === undefined) return;
    event.preventDefault();
    focus(Math.min(bars.length - 1, Math.max(0, to)));
  };
  const ticked = (i: number) => (ticksFromEnd ? bars.length - 1 - i : i) % tickEvery === 0;
  const tip = shown === null ? null : bars[shown];
  const middle = (i: number) => ((i + 0.5) / bars.length) * 100;

  return (
    <section className="card chart" aria-label={title}>
      <h3 className="chart-title">{title}</h3>
      <div className="chart-plot">
        {/* biome-ignore lint/a11y/useSemanticElements: an SVG can't be a fieldset; the group names the chart's bars */}
        <svg
          className="bars"
          viewBox={`0 0 ${WIDTH} ${height}`}
          preserveAspectRatio="none"
          width="100%"
          height={height}
          role="group"
          aria-label={title}
          onKeyDown={onKey}
          onMouseLeave={() => setShown(null)}
        >
          {bars.map((bar, i) => {
            const h = bar.words === 0 ? 0 : Math.max(2, (bar.words / peak) * (height - 4));
            const x = i * column;
            return (
              <g key={bar.label}>
                {/* The hover shade fills the column behind the bar. */}
                {/* biome-ignore lint/a11y/noInteractiveElementToNoninteractiveRole: a bar is a picture with a label that the arrow keys reach, as in charts read by screen readers */}
                <rect
                  ref={(el) => {
                    refs.current[i] = el;
                  }}
                  className="bar-hit"
                  x={x}
                  y={0}
                  width={column}
                  height={height}
                  role="img"
                  aria-label={`${bar.label}: ${wordsText(bar.words)}`}
                  tabIndex={i === current ? 0 : -1}
                  onMouseEnter={() => setShown(i)}
                  onFocus={() => {
                    setCurrent(i);
                    setShown(i);
                  }}
                  onBlur={() => setShown(null)}
                />
                <rect className="bar" x={x + (column * GAP) / 2} y={height - h} width={column * (1 - GAP)} height={h} />
              </g>
            );
          })}
        </svg>
        {tip && shown !== null && (
          <div
            className="chart-tip"
            aria-hidden="true"
            style={{ left: `clamp(60px, ${middle(shown)}%, calc(100% - 60px))` }}
          >
            <span className="caption">{tip.label}</span>
            <span className="chart-tip-words">{wordsText(tip.words)}</span>
          </div>
        )}
      </div>
      <div className="chart-axis" aria-hidden="true">
        {bars.map((bar, i) =>
          ticked(i) ? (
            <span key={bar.label} className="chart-tick" style={{ left: `${middle(i)}%` }}>
              {bar.tick}
            </span>
          ) : null,
        )}
      </div>
    </section>
  );
}
