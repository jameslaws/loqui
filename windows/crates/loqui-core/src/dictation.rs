//! What happens during one dictation that doesn't depend on Windows: the text
//! built up from speech segments, the live level for the bubble, and the
//! safety stops. Mirrors VoiceKeyCenter and VoiceTranscriber on the Mac.

use crate::timed_heal::{self, Boundary};
use crate::CleanupConfig;

/// The text heard so far, built from segments the engine cut at pauses.
#[derive(Debug, Default)]
pub struct Transcript {
    text: String,
    last_end: Option<f64>,
}

impl Transcript {
    /// Add a segment heard between `start` and `end` seconds into the
    /// recording. The pause since the previous segment decides whether a
    /// period between them was a real full stop (TimedHeal).
    pub fn add(
        &mut self,
        segment: &str,
        start: f64,
        end: f64,
        cfg: &CleanupConfig,
    ) -> Option<Boundary> {
        let gap = self.last_end.map(|last| (start - last).max(0.0));
        self.last_end = Some(end);
        let (text, boundary) = timed_heal::bank(segment, &self.text, gap, cfg);
        self.text = text;
        boundary
    }

    pub fn text(&self) -> &str {
        &self.text
    }
}

/// Words as the Mac counts them: runs of non-space.
pub fn word_count(text: &str) -> usize {
    text.split_whitespace().count()
}

/// The microphone level for the bubble's waveform, normalised against the
/// loudest sound heard recently so it follows your voice at your mic's level,
/// with room noise and breath gated out. The same numbers as the Mac.
#[derive(Debug, Clone)]
pub struct Meter {
    peak: f64,
    smoothed: f64,
}

impl Default for Meter {
    fn default() -> Self {
        Self {
            peak: 0.02,
            smoothed: 0.0,
        }
    }
}

/// One reading: the level to draw (0 to 1) and whether it counts as speech.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Reading {
    pub level: f64,
    pub speaking: bool,
}

impl Meter {
    pub fn push(&mut self, rms: f64) -> Reading {
        self.peak = rms.max(self.peak * 0.995);
        let raw = if self.peak > 0.004 {
            (rms / self.peak).min(1.0)
        } else {
            0.0
        };
        let gated = if raw < 0.22 { 0.0 } else { (raw - 0.22) / 0.78 };
        if gated > self.smoothed {
            self.smoothed += (gated - self.smoothed) * 0.65;
        } else {
            self.smoothed *= 0.88;
        }
        Reading {
            level: self.smoothed,
            speaking: gated > 0.0,
        }
    }
}

/// Root mean square of a block of samples.
pub fn rms(samples: &[f32]) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    let sum: f64 = samples.iter().map(|s| f64::from(*s) * f64::from(*s)).sum();
    (sum / samples.len() as f64).sqrt()
}

/// Stops after this much silence: a lost key-up shows up as silence.
pub const SILENCE_LIMIT: f64 = 120.0;
/// A pure backstop, long enough never to end a genuine dictation.
pub const SESSION_CEILING: f64 = 1800.0;
const STARVED_AFTER: f64 = 5.0;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Alarm {
    /// No audio has arrived for a while: the microphone dropped out.
    Starved(u64),
    Stop(&'static str),
}

/// The safety stops, checked every few seconds while recording.
#[derive(Debug, Clone)]
pub struct Watchdog {
    started: f64,
    last_speech: f64,
    last_audio: f64,
    warned: bool,
}

impl Watchdog {
    pub fn new(now: f64) -> Self {
        Self {
            started: now,
            last_speech: now,
            last_audio: now,
            warned: false,
        }
    }

    pub fn heard(&mut self, now: f64, speaking: bool) {
        self.last_audio = now;
        if speaking {
            self.last_speech = now;
        }
    }

    pub fn check(&mut self, now: f64) -> Option<Alarm> {
        if now - self.last_speech > SILENCE_LIMIT {
            return Some(Alarm::Stop("120s of silence, assuming a lost key-up"));
        }
        if now - self.started > SESSION_CEILING {
            return Some(Alarm::Stop("30-minute absolute ceiling"));
        }
        let starved = now - self.last_audio;
        if starved > STARVED_AFTER && !self.warned {
            self.warned = true;
            return Some(Alarm::Starved(starved as u64));
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_short_pause_before_and_heals_a_long_one_does_not() {
        let cfg = CleanupConfig::default();
        let mut t = Transcript::default();
        assert_eq!(t.add("We shipped it.", 0.0, 1.5, &cfg), None);
        let healed = t.add("And it works.", 1.8, 3.0, &cfg).unwrap();
        assert!(healed.healed);
        assert_eq!(t.text(), "We shipped it and it works.");
        let kept = t.add("And then we slept.", 4.0, 5.0, &cfg).unwrap();
        assert!(!kept.healed);
        assert_eq!(t.text(), "We shipped it and it works. And then we slept.");
    }

    #[test]
    fn silence_stops_it_after_two_minutes_and_speech_keeps_it_going() {
        let mut w = Watchdog::new(0.0);
        for t in 1..=119 {
            w.heard(f64::from(t), false);
            assert_eq!(w.check(f64::from(t)), None);
        }
        w.heard(119.0, true);
        w.heard(200.0, false);
        assert_eq!(w.check(200.0), None);
        w.heard(239.5, false);
        assert_eq!(
            w.check(239.5),
            Some(Alarm::Stop("120s of silence, assuming a lost key-up"))
        );
    }

    #[test]
    fn the_ceiling_stops_even_a_talker_and_starvation_warns_once() {
        let mut w = Watchdog::new(0.0);
        w.heard(1800.0, true);
        assert_eq!(
            w.check(1800.5),
            Some(Alarm::Stop("30-minute absolute ceiling"))
        );

        let mut w = Watchdog::new(0.0);
        assert_eq!(w.check(6.0), Some(Alarm::Starved(6)));
        assert_eq!(w.check(7.0), None);
    }

    #[test]
    fn the_meter_ignores_room_noise_and_follows_a_voice() {
        let mut m = Meter::default();
        assert!(!m.push(0.0).speaking);
        let voice = m.push(0.3);
        assert!(voice.speaking && voice.level > 0.5);
        // Quiet hiss well under the recent peak is gated out, and the level falls.
        let hiss = m.push(0.02);
        assert!(!hiss.speaking && hiss.level < voice.level);
        assert!((rms(&[0.5, -0.5]) - 0.5).abs() < 1e-9);
    }
}
