import type { HistoryItem, Term } from "./bindings";

/**
 * The plan's sample data: six dictations and four dictionary terms. The screen
 * tests start from it in a browser, and the Windows check writes it into
 * loqui's files before photographing the real windows.
 */
export const sampleHistory: HistoryItem[] = [
  {
    at: "2026-11-10T14:30:00Z",
    text: "Thanks for sending the draft over. I think the second section works well, but the opening is too long.",
  },
  {
    at: "2026-11-10T11:30:00Z",
    text: "Can we move Thursday’s call to Friday afternoon? I’ll send notes before then.",
  },
  {
    at: "2026-11-10T02:30:00Z",
    text: "Reminder to pick up the dry cleaning and call the dentist about the appointment next week.",
  },
  { at: "2026-11-09T23:30:00Z", text: "The headline should say what changes for the reader, not what we built." },
  {
    at: "2026-11-09T20:30:00Z",
    text: "Let’s ship the pricing page first and come back to the onboarding emails on Monday.",
  },
  { at: "2026-11-09T15:00:00Z", text: "Book a table for the team lunch next Wednesday at noon." },
];

export const sampleDictionary: Term[] = [
  { heard: "loki", replacement: "Loqui" },
  { heard: "ninja forms", replacement: "Ninja Forms" },
  { heard: "sarah k", replacement: "Sara K." },
  { heard: "saturday drive", replacement: "Saturday Drive" },
];

export const defaultFillers = ["um", "umm", "uh", "uhh", "uhm", "er", "erm", "hmm", "mhm"];
