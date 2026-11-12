import { type ReactNode, StrictMode, useEffect, useId, useRef } from "react";
import { createRoot } from "react-dom/client";
import { backend } from "./backend";
import { tokenCss } from "./tokens";
import "./styles.css";

/** Draw a screen: the look's tokens, the page, and Esc closing the window. */
export function mount(screen: ReactNode) {
  const style = document.createElement("style");
  style.textContent = tokenCss();
  document.head.append(style);
  // Esc closes the window, unless something inside used it first (a dialog,
  // the shortcut recorder).
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !event.defaultPrevented) backend.closeWindow();
  });
  const root = document.getElementById("root");
  if (root) createRoot(root).render(<StrictMode>{screen}</StrictMode>);
}

/** A Windows on/off switch. */
export function Toggle({
  label,
  on,
  onChange,
  describedBy,
}: {
  label: string;
  on: boolean;
  onChange: (on: boolean) => void;
  describedBy?: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      className="toggle"
      aria-checked={on}
      aria-label={label}
      aria-describedby={describedBy}
      onClick={() => onChange(!on)}
    />
  );
}

/** The shortcut drawn as key caps. */
export function KeyCaps({ keys, label }: { keys: string[]; label?: string }) {
  return (
    <span className="keycaps" role="img" aria-label={label ?? keys.join("+")}>
      {keys.map((key) => (
        <span key={key} className="keycap">
          {key}
        </span>
      ))}
    </span>
  );
}

/** A tick in a circle, filled when done. */
export function Tick({ done, label }: { done: boolean; label: string }) {
  return (
    <svg
      className={`tick${done ? " done" : ""}`}
      width="20"
      height="20"
      viewBox="0 0 20 20"
      role="img"
      aria-label={label}
    >
      <circle cx="10" cy="10" r="9" />
      {done && <path d="M6 10.5l2.6 2.6L14 7.5" />}
    </svg>
  );
}

export function TrashIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true" className="icon">
      <path d="M2.5 4h11M6 4V2.5h4V4M4 4l.7 9.5h6.6L12 4M6.6 6.5v5M9.4 6.5v5" />
    </svg>
  );
}

/**
 * Ask before something that can't be undone. A real modal dialog: focus stays
 * inside it, Esc is Cancel, and the window behind can't be used meanwhile.
 */
export function Confirm({
  open,
  title,
  message,
  action,
  onAnswer,
}: {
  open: boolean;
  title: string;
  message: string;
  action: string;
  onAnswer: (yes: boolean) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const cancel = useRef<HTMLButtonElement>(null);
  const titleId = useId();
  const messageId = useId();
  useEffect(() => {
    const d = dialog.current;
    if (!d) return;
    // Opened with the safe answer ready, so Enter can't delete by accident.
    if (open && !d.open) {
      d.showModal();
      cancel.current?.focus();
    }
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog
      ref={dialog}
      className="confirm"
      aria-labelledby={titleId}
      aria-describedby={messageId}
      onCancel={(event) => {
        event.preventDefault();
        onAnswer(false);
      }}
      onKeyDown={(event) => {
        // Esc answers Cancel here, and doesn't reach the window (which it would close).
        if (event.key === "Escape") {
          event.preventDefault();
          onAnswer(false);
        }
      }}
    >
      <h2 id={titleId} className="subtitle">
        {title}
      </h2>
      <p id={messageId} className="confirm-message">
        {message}
      </p>
      <div className="confirm-buttons">
        <button type="button" className="btn danger" onClick={() => onAnswer(true)}>
          {action}
        </button>
        <button ref={cancel} type="button" className="btn" onClick={() => onAnswer(false)}>
          Cancel
        </button>
      </div>
    </dialog>
  );
}

/** A failed save or load, said plainly where it happened. */
export function Problem({ text, onRetry }: { text: string | null; onRetry?: () => void }) {
  if (!text) return null;
  return (
    <div className="problem" role="alert">
      <span>{text}</span>
      {onRetry && (
        <button type="button" className="btn" onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  );
}

/** The error from a rejected command, as text. */
export const why = (error: unknown) => (typeof error === "string" ? error : String(error));
