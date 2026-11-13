import { useCallback, useEffect, useId, useState } from "react";
import icon from "./assets/icon-256.png";
import { backend } from "./backend";
import type { Welcome as Rows } from "./bindings";
import { KeyCaps, Problem, Tick, Toggle, why } from "./ui";

/** How often the microphone row looks again, so turning the switch on in Windows ticks it off by itself. */
const LOOK_EVERY_MS = 1000;

/** The welcome window: opens on first start, and from the tray menu's Welcome and setup. */
export function Welcome() {
  const [rows, setRows] = useState<Rows | null>(null);
  const [problem, setProblem] = useState<string | null>(null);
  const signInNote = useId();

  const look = useCallback(() => {
    backend.welcome().then(
      (r) => {
        setRows(r);
        setProblem(null);
      },
      (e) => setProblem(why(e)),
    );
  }, []);

  useEffect(() => {
    look();
    const timer = setInterval(look, LOOK_EVERY_MS);
    const stop = backend.onSettingsChanged(look);
    return () => {
      clearInterval(timer);
      stop();
    };
  }, [look]);

  if (!rows) {
    return (
      <main className="page welcome">
        <Problem text={problem} onRetry={look} />
      </main>
    );
  }

  const ready = rows.microphoneAllowed;
  const toggleSignIn = (on: boolean) => {
    setRows({ ...rows, startAtSignIn: on });
    backend.setStartAtSignIn(on).catch((e) => {
      setProblem(why(e));
      look();
    });
  };

  return (
    <main className="page welcome">
      <header className="welcome-head">
        <img src={icon} alt="" width={64} height={64} />
        <h1 className="subtitle">Welcome to loqui</h1>
        <p className="muted">Talk, and it’s text, anywhere on your PC.</p>
      </header>
      <Problem text={problem} />

      <section className="card welcome-row" aria-labelledby="mic-title">
        <Tick done={ready} label={ready ? "Done" : "Not done yet"} />
        <div className="grow">
          <h2 id="mic-title" className="strong">
            Microphone
          </h2>
          <p>loqui listens only while you dictate, and turns speech into text on this PC. Audio never leaves it.</p>
          {ready ? (
            <p className="caption">Allowed. loqui can hear you while you dictate.</p>
          ) : (
            <div className="welcome-action">
              <button type="button" className="btn primary" onClick={() => backend.openMicrophoneSettings()}>
                Open microphone settings
              </button>
              <p className="caption">Windows is blocking desktop apps from the microphone</p>
            </div>
          )}
        </div>
      </section>

      <section className="card welcome-row" aria-labelledby="shortcut-title">
        <Tick done label="Done" />
        <div className="grow">
          <h2 id="shortcut-title" className="strong">
            Your shortcut
          </h2>
          <p>Tap to start and stop, or hold to talk. Change it any time in Settings.</p>
          <KeyCaps keys={rows.shortcut.keys} label={rows.shortcut.text} />
        </div>
      </section>

      <section className="card welcome-row center" aria-labelledby="signin-title">
        <Tick done label="Done" />
        <div className="grow">
          <h2 id="signin-title" className="strong">
            Start loqui when you sign in
          </h2>
          <p id={signInNote} className="caption">
            So the shortcut is always ready
          </p>
        </div>
        <Toggle
          label="Start loqui when you sign in"
          describedBy={signInNote}
          on={rows.startAtSignIn}
          onChange={toggleSignIn}
        />
      </section>

      <footer className="welcome-foot">
        {ready ? (
          <p className="accent-text">{`You’re all set: press ${rows.shortcut.text} and start talking.`}</p>
        ) : (
          <p className="caption">Allow the microphone to finish.</p>
        )}
        {ready ? (
          <button
            type="button"
            className="btn primary"
            onClick={() => backend.finishWelcome().catch((e) => setProblem(why(e)))}
          >
            Finish
          </button>
        ) : (
          <button type="button" className="btn" onClick={() => backend.closeWindow()}>
            Finish later
          </button>
        )}
      </footer>
    </main>
  );
}
