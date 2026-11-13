//! One shortcut, two gestures (VoiceKeyService.swift on the Mac).
//!
//! Tap it to start and tap again to stop, or hold it while talking and let go.
//! Recording starts the moment the key goes down; the 0.35 s hold threshold
//! only decides what letting go does.
//!
//! Split in two because Windows removes keyboard hooks that answer slowly:
//! [`KeyFilter`] runs inside the hook and only decides whether a key event is
//! the shortcut, and [`Gesture`] turns presses and releases into start and stop
//! on loqui's own thread. Times are seconds on any steady clock.

use crate::shortcut::{Mods, Shortcut};

/// What the hook should do with a key event, and what it means for dictation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Verdict {
    /// Keep the event from the app underneath.
    pub swallow: bool,
    pub edge: Option<Edge>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Edge {
    Press,
    Release,
}

const PASS: Verdict = Verdict {
    swallow: false,
    edge: None,
};
const SWALLOW: Verdict = Verdict {
    swallow: true,
    edge: None,
};

/// Longer than Windows' slowest key repeat (a 1 s delay), so a key-down this
/// long after the last one can't be a repeat: its key-up was lost.
const LOST_UP_AFTER: f64 = 1.2;

/// Decides, inside the keyboard hook, which events are the shortcut.
#[derive(Debug, Default)]
pub struct KeyFilter {
    /// The shortcut's key while it is down, so its repeats and key-up are claimed.
    held: Option<u16>,
    last: f64,
}

impl KeyFilter {
    pub fn key_down(&mut self, shortcut: &Shortcut, key: u16, mods: Mods, now: f64) -> Verdict {
        if self.held == Some(key) {
            if now - self.last <= LOST_UP_AFTER {
                // Holding the key repeats it: swallow the repeats, they mean nothing.
                self.last = now;
                return SWALLOW;
            }
            self.held = None;
        }
        if !shortcut.matches(key, mods) {
            return PASS;
        }
        self.held = Some(key);
        self.last = now;
        Verdict {
            swallow: true,
            edge: Some(Edge::Press),
        }
    }

    /// The key-up is matched by key alone: a modifier may already be up.
    pub fn key_up(&mut self, key: u16) -> Verdict {
        if self.held != Some(key) {
            return PASS;
        }
        self.held = None;
        Verdict {
            swallow: true,
            edge: Some(Edge::Release),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    Start,
    Stop(&'static str),
}

#[derive(Debug, Clone, Copy, PartialEq, Default)]
enum State {
    #[default]
    Idle,
    /// Pressed at this time; recording started.
    Down(f64),
    /// This press stopped a recording: its release means nothing.
    SwallowUp,
}

/// Presses and releases into start and stop.
#[derive(Debug, Default)]
pub struct Gesture {
    state: State,
}

pub const HOLD_THRESHOLD: f64 = 0.35;

impl Gesture {
    pub fn press(&mut self, now: f64, recording: bool) -> Action {
        // A press while a gesture is in flight means its release was lost;
        // start over rather than leave the shortcut dead.
        if recording {
            self.state = State::SwallowUp;
            Action::Stop("toggle press")
        } else {
            self.state = State::Down(now);
            Action::Start
        }
    }

    pub fn release(&mut self, now: f64) -> Option<Action> {
        let state = std::mem::take(&mut self.state);
        match state {
            // Held past the threshold: push-to-talk, so letting go stops it.
            State::Down(at) if now - at >= HOLD_THRESHOLD => {
                Some(Action::Stop("push-to-talk release"))
            }
            // A tap: keep recording until the next press.
            _ => None,
        }
    }

    /// Back to idle, after a watchdog stop.
    pub fn reset(&mut self) {
        self.state = State::Idle;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SPACE: u16 = 0x20;
    const CTRL_SHIFT: Mods = Mods {
        ctrl: true,
        alt: false,
        shift: true,
        win: false,
    };

    fn press() -> Verdict {
        Verdict {
            swallow: true,
            edge: Some(Edge::Press),
        }
    }

    fn release() -> Verdict {
        Verdict {
            swallow: true,
            edge: Some(Edge::Release),
        }
    }

    #[test]
    fn the_shortcut_and_its_repeats_never_reach_the_app() {
        let s = Shortcut::default();
        let mut f = KeyFilter::default();
        assert_eq!(f.key_down(&s, SPACE, CTRL_SHIFT, 0.0), press());
        // Two seconds of key repeat, every 33 ms.
        for i in 1..60 {
            assert_eq!(
                f.key_down(&s, SPACE, CTRL_SHIFT, f64::from(i) * 0.033),
                SWALLOW
            );
        }
        // Shift let go first: the key-up still belongs to the shortcut.
        assert_eq!(f.key_up(SPACE), release());
    }

    #[test]
    fn other_keys_and_other_modifiers_pass_through() {
        let s = Shortcut::default();
        let mut f = KeyFilter::default();
        let ctrl_only = Mods {
            shift: false,
            ..CTRL_SHIFT
        };
        let ctrl_alt_shift = Mods {
            alt: true,
            ..CTRL_SHIFT
        };
        assert_eq!(f.key_down(&s, SPACE, ctrl_only, 0.0), PASS);
        assert_eq!(f.key_up(SPACE), PASS);
        assert_eq!(f.key_down(&s, SPACE, ctrl_alt_shift, 1.0), PASS);
        assert_eq!(f.key_up(SPACE), PASS);
        assert_eq!(f.key_down(&s, u16::from(b'A'), Mods::default(), 2.0), PASS);
    }

    #[test]
    fn a_lost_key_up_does_not_leave_the_shortcut_dead() {
        let s = Shortcut::default();
        let mut f = KeyFilter::default();
        assert_eq!(f.key_down(&s, SPACE, CTRL_SHIFT, 0.0), press());
        // No key-up ever came; the next real press is a press, not a repeat.
        assert_eq!(f.key_down(&s, SPACE, CTRL_SHIFT, 5.0), press());
    }

    #[test]
    fn tap_starts_and_the_next_tap_stops() {
        let mut g = Gesture::default();
        assert_eq!(g.press(0.0, false), Action::Start);
        assert_eq!(g.release(0.1), None);
        assert_eq!(g.press(3.0, true), Action::Stop("toggle press"));
        assert_eq!(g.release(3.1), None);
    }

    #[test]
    fn hold_talks_until_let_go_and_does_not_stick() {
        let mut g = Gesture::default();
        assert_eq!(g.press(0.0, false), Action::Start);
        assert_eq!(g.release(4.0), Some(Action::Stop("push-to-talk release")));
        // A short tap after a hold starts a new dictation.
        assert_eq!(g.press(5.0, false), Action::Start);
        assert_eq!(g.release(5.1), None);
    }

    #[test]
    fn the_hold_threshold_is_the_macs() {
        let mut g = Gesture::default();
        g.press(0.0, false);
        assert_eq!(g.release(0.34), None);
        g.reset();
        g.press(1.0, false);
        assert_eq!(g.release(1.35), Some(Action::Stop("push-to-talk release")));
    }
}
