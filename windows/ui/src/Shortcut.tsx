import { useEffect, useRef, useState } from "react";
import { backend } from "./backend";
import type { ShortcutView } from "./bindings";
import { KeyCaps, why } from "./ui";

/** A key as loqui names it, from where it is on the keyboard. Modifiers alone give null. */
function keyName(code: string): string | null {
  if (/^Key[A-Z]$/.test(code)) return code.slice(3);
  if (/^Digit\d$/.test(code)) return code.slice(5);
  if (code === "Space" || /^F\d{1,2}$/.test(code)) return code;
  if (/^(Control|Alt|Shift|Meta|OS)(Left|Right)?$/.test(code)) return null;
  return code;
}

/** What was pressed, as text loqui reads: "Ctrl+Alt+D". */
export function pressed(event: Pick<KeyboardEvent, "code" | "ctrlKey" | "altKey" | "shiftKey" | "metaKey">) {
  const key = keyName(event.code);
  if (!key) return null;
  const mods = [
    event.ctrlKey && "Ctrl",
    event.altKey && "Alt",
    event.shiftKey && "Shift",
    event.metaKey && "Win",
  ].filter(Boolean);
  return [...mods, key].join("+");
}

/**
 * Change the shortcut by pressing it, as on the Mac. While recording, loqui's
 * own shortcut is switched off, so pressing it is recorded rather than starting
 * a dictation. Esc cancels.
 */
export function ShortcutRecorder({
  shortcut,
  onSaved,
}: {
  shortcut: ShortcutView;
  onSaved: (s: ShortcutView) => void;
}) {
  const [recording, setRecording] = useState(false);
  const [hint, setHint] = useState<string | null>(null);
  const button = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!recording) return;
    backend.beginShortcut();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Tab" && !event.ctrlKey && !event.altKey) return;
      event.preventDefault();
      event.stopPropagation();
      if (event.repeat) return;
      if (event.code === "Escape") {
        setRecording(false);
        return;
      }
      const text = pressed(event);
      if (!text) return;
      backend.setShortcut(text).then(
        (saved) => {
          setHint(null);
          setRecording(false);
          onSaved(saved);
        },
        (e) => setHint(why(e)),
      );
    };
    // Before anything else on the page, so Esc doesn't close the window.
    window.addEventListener("keydown", onKey, true);
    return () => {
      window.removeEventListener("keydown", onKey, true);
      backend.endShortcut();
    };
  }, [recording, onSaved]);

  // After recording, focus stays on Change (not when the window first opens).
  const wasRecording = useRef(false);
  useEffect(() => {
    if (wasRecording.current && !recording) button.current?.focus();
    wasRecording.current = recording;
  }, [recording]);

  return (
    <div className="row shortcut-row">
      <div className="grow">
        <div id="shortcut-label">Dictation shortcut</div>
        <p className="caption" id="shortcut-help">
          Tap to start and stop, or hold to talk. Use Ctrl or Alt with a key, or a function key.
        </p>
        <p className="hint" role="status">
          {hint}
        </p>
      </div>
      {recording ? (
        <span className="muted">Press your shortcut</span>
      ) : (
        <KeyCaps keys={shortcut.keys} label={`Current shortcut: ${shortcut.text}`} />
      )}
      <button
        ref={button}
        type="button"
        className="btn"
        aria-describedby="shortcut-help"
        aria-pressed={recording}
        onClick={() => {
          setHint(null);
          setRecording(!recording);
        }}
        onBlur={() => setRecording(false)}
      >
        {recording ? "Cancel" : "Change"}
      </button>
    </div>
  );
}
