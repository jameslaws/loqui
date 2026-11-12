import { useEffect, useRef, useState } from "react";

/** What the bubble shows. loqui sets it from Rust by calling `window.bubble`. */
export type Phase = "hidden" | "listening" | "finishing" | "pasted" | "notice";
export interface BubbleState {
  phase: Phase;
  /** The microphone level, 0 to 1, while listening. */
  level: number;
  /** The words of a notice. */
  message: string;
}

declare global {
  interface Window {
    bubble?: (state: BubbleState) => void;
  }
}

const BARS = 21;

/**
 * One bar's height: a bell envelope, tallest in the middle, whose size swells
 * with the live level, plus a shimmer so it moves like a voice. The Mac's numbers.
 */
export function barHeight(i: number, t: number, level: number): number {
  const c = (BARS - 1) / 2;
  const d = Math.abs(i - c) / c;
  const env = 0.3 + 0.7 * Math.cos((d * Math.PI) / 2);
  const osc = 0.2 + 0.8 * (0.5 + 0.5 * Math.sin(t * 9 + i * 0.85));
  const amp = level ** 0.45;
  return 3 + 33 * env * (0.05 + amp * 0.95) * osc;
}

function Waveform({ level }: { level: { current: number } }) {
  const bars = useRef<(HTMLElement | null)[]>([]);
  useEffect(() => {
    const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
    let shown = 0;
    let frame = 0;
    const draw = (ms: number) => {
      // Light smoothing, so the waveform swells and settles instead of snapping.
      shown = shown * 0.25 + level.current * 0.75;
      const t = still ? 0 : ms / 1000;
      bars.current.forEach((bar, i) => {
        if (bar) bar.style.height = `${barHeight(i, t, shown)}px`;
      });
      frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(frame);
  }, [level]);
  return (
    <span className="bars" aria-hidden="true">
      {Array.from({ length: BARS }, (_, i) => (
        <i
          // biome-ignore lint/suspicious/noArrayIndexKey: a fixed row of bars that never reorders
          key={i}
          ref={(el) => {
            bars.current[i] = el;
          }}
        />
      ))}
    </span>
  );
}

/** The dictation bubble at the bottom of the screen. It never takes the cursor. */
export function Bubble() {
  const [state, setState] = useState<BubbleState>({ phase: "hidden", level: 0, message: "" });
  const level = useRef(0);

  useEffect(() => {
    window.bubble = (next) => {
      level.current = next.level;
      setState((now) => (now.phase === next.phase && now.message === next.message ? now : next));
    };
    return () => {
      window.bubble = undefined;
    };
  }, []);

  const { phase, message } = state;
  if (phase === "hidden") return <output className="sr-only" />;

  return (
    <div className="stage">
      <output className="hud" aria-live="polite">
        {phase === "listening" || phase === "finishing" ? (
          <>
            <span className="q" aria-hidden="true">
              “
            </span>
            {phase === "listening" ? (
              <Waveform level={level} />
            ) : (
              <span className="spinner" aria-hidden="true" />
            )}
            <span className="q" aria-hidden="true">
              ”
            </span>
            <span className="sr-only">{phase === "listening" ? "loqui is listening" : "loqui is finishing"}</span>
          </>
        ) : phase === "pasted" ? (
          <>
            <span className="mark" aria-hidden="true">
              ✔
            </span>
            <span className="label">Pasted</span>
          </>
        ) : (
          <>
            <span className="mark" aria-hidden="true">
              ⚠
            </span>
            <span className="note">{message}</span>
          </>
        )}
      </output>
    </div>
  );
}
