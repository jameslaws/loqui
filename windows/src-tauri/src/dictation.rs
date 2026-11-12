//! Dictation on Windows (VoiceKeyCenter on the Mac): press the shortcut,
//! speak, and the cleaned text lands where you were typing.
//!
//! One thread runs it all from a queue of events: shortcut presses from the
//! keyboard hook, levels from the microphone, text from the speech thread.
//! Nothing here waits on the network; loqui never uses it.

use crate::bubble::{self, Bubble};
use crate::mic::{self, MicError, Outlets};
use crate::speech::{self, ToSpeech};
use crate::{hook, paste, tray};
use loqui_core::dictation::{word_count, Alarm, Meter, Transcript, Watchdog};
use loqui_core::records::{self, Records};
use loqui_core::voice_key::{Action, Edge, Gesture};
use loqui_core::{clean, CleanupConfig, Settings};
use loqui_speech::{Files, Segment};
use std::path::PathBuf;
use std::sync::mpsc::{channel, Receiver, RecvTimeoutError, Sender};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Manager};

pub enum Event {
    /// The shortcut went down or up, at this many seconds on loqui's clock.
    Key(Edge, f64),
    /// The microphone's level over the last 20 ms.
    Level(f64),
    Segment(u64, Segment),
    /// The speech thread has finished a dictation; false if it has no model.
    Finished(u64, bool),
    /// The model loaded in this many seconds, or why it didn't.
    EngineLoaded(Result<f64, String>),
}

/// How long the bubble's notices stay up. The Mac's 1.8 s, and a little more
/// for the longer clipboard message.
const NOTICE: f64 = 1.8;
const LONG_NOTICE: f64 = 3.0;
/// A beat of the tray icon's pulse.
const BEAT: Duration = Duration::from_millis(400);
/// The bubble's waveform is redrawn about 30 times a second.
const LEVEL_EVERY: Duration = Duration::from_millis(33);
/// A pause before Ctrl+V so the clipboard has settled (the Mac's 80 ms).
const BEFORE_PASTE: Duration = Duration::from_millis(80);

fn unix_now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs() as i64)
}

/// Start watching for the shortcut and loading the speech model.
pub fn start(app: &AppHandle) -> Result<(), String> {
    let data = records::data_dir().ok_or("Windows didn't say where local app data goes")?;
    let records = Records::new(&data);
    let loaded = Settings::load(&data.join("settings.json"));
    if let Some(problem) = &loaded.problem {
        records.log(problem, unix_now());
    }
    let settings = loaded.settings;
    let _ = records.prune_history(unix_now(), settings.history_retention_days);

    let clock = Instant::now();
    let (events, inbox) = channel();
    let root = app.path().resource_dir().map_err(|e| e.to_string())?;
    let speech = speech::start(Files::under(&root), events.clone()).map_err(|e| e.to_string())?;
    // The shortcut works from the first moment; presses wait in the queue.
    hook::start(settings.shortcut, events.clone(), clock)
        .map_err(|e| format!("the keyboard hook failed: {e}"))?;
    let bubble = Bubble::create(app).map_err(|e| e.to_string())?;
    records.log(&format!("listening for {}", settings.shortcut), unix_now());

    let center = Center {
        app: app.clone(),
        records,
        data,
        clock,
        events,
        speech,
        bubble,
        gesture: Gesture::default(),
        session: None,
        next_id: 0,
    };
    std::thread::Builder::new()
        .name("loqui dictation".into())
        .spawn(move || center.run(&inbox))
        .map_err(|e| e.to_string())?;
    Ok(())
}

struct Center {
    app: AppHandle,
    records: Records,
    data: PathBuf,
    clock: Instant,
    events: Sender<Event>,
    speech: Sender<ToSpeech>,
    bubble: Bubble,
    gesture: Gesture,
    session: Option<Session>,
    next_id: u64,
}

struct Session {
    id: u64,
    cfg: CleanupConfig,
    transcript: Transcript,
    phase: Phase,
}

enum Phase {
    Recording(Recording),
    /// Stopped; waiting for the last segment's text.
    Finishing {
        reason: &'static str,
        spoken: f64,
    },
}

struct Recording {
    capture: mic::Capture,
    started: Instant,
    watchdog: Watchdog,
    meter: Meter,
    beat: (Instant, bool),
    drawn: Instant,
}

impl Center {
    fn run(mut self, inbox: &Receiver<Event>) {
        loop {
            match inbox.recv_timeout(Duration::from_millis(40)) {
                Ok(event) => self.handle(event),
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => return,
            }
            self.tick();
        }
    }

    fn log(&self, message: &str) {
        self.records.log(message, unix_now());
    }

    fn seconds(&self) -> f64 {
        self.clock.elapsed().as_secs_f64()
    }

    fn recording(&mut self) -> Option<&mut Recording> {
        match &mut self.session {
            Some(Session {
                phase: Phase::Recording(r),
                ..
            }) => Some(r),
            _ => None,
        }
    }

    fn handle(&mut self, event: Event) {
        match event {
            Event::Key(Edge::Press, at) => {
                let recording = self.recording().is_some();
                match self.gesture.press(at, recording) {
                    Action::Start => self.start_recording(),
                    Action::Stop(reason) => self.stop_recording(reason),
                }
            }
            Event::Key(Edge::Release, at) => {
                if let Some(Action::Stop(reason)) = self.gesture.release(at) {
                    self.stop_recording(reason);
                }
            }
            Event::Level(rms) => self.level(rms),
            Event::Segment(id, segment) => {
                let Some(session) = self.session.as_mut().filter(|s| s.id == id) else {
                    return;
                };
                let boundary =
                    session
                        .transcript
                        .add(&segment.text, segment.start, segment.end, &session.cfg);
                if let (Some(b), true) = (boundary, session.cfg.audit_log) {
                    self.records.audit_boundary(b.gap, &b.word, b.healed);
                }
            }
            Event::Finished(id, ok) => {
                if self
                    .session
                    .as_ref()
                    .is_some_and(|s| s.id == id && matches!(s.phase, Phase::Finishing { .. }))
                {
                    self.complete(ok);
                }
            }
            Event::EngineLoaded(Ok(seconds)) => {
                self.log(&format!("speech model loaded in {seconds:.1}s"))
            }
            Event::EngineLoaded(Err(e)) => self.log(&format!("speech model FAILED to load: {e}")),
        }
    }

    fn level(&mut self, rms: f64) {
        let now = self.seconds();
        let Some(r) = self.recording() else { return };
        let reading = r.meter.push(rms);
        r.watchdog.heard(now, reading.speaking);
        if r.drawn.elapsed() >= LEVEL_EVERY {
            r.drawn = Instant::now();
            self.bubble.level(reading.level);
        }
    }

    fn tick(&mut self) {
        self.bubble.tick(Instant::now());
        let now = self.seconds();
        let app = self.app.clone();
        let Some(r) = self.recording() else { return };
        let alarm = r.watchdog.check(now);
        if r.beat.0.elapsed() >= BEAT {
            r.beat = (Instant::now(), !r.beat.1);
            tray::show_recording(&app, Some(r.beat.1));
        }
        match alarm {
            Some(Alarm::Starved(seconds)) => self.log(&format!(
                "WARNING: no audio for {seconds}s; the mic dropped out and text after this point is lost"
            )),
            Some(Alarm::Stop(reason)) => {
                self.log(&format!("watchdog stop: {reason}"));
                self.gesture.reset();
                self.stop_recording(reason);
            }
            None => {}
        }
    }

    fn start_recording(&mut self) {
        // Not while the last dictation is still finishing.
        if self.session.is_some() {
            return;
        }
        self.next_id += 1;
        let id = self.next_id;
        let cfg = CleanupConfig::load(&self.data.join("cleanup.json"));
        let _ = self.speech.send(ToSpeech::Begin(id));
        let outlets = Outlets {
            id,
            speech: self.speech.clone(),
            events: self.events.clone(),
            records: self.records.clone(),
        };
        match mic::start(outlets) {
            Ok(capture) => {
                let now = Instant::now();
                self.session = Some(Session {
                    id,
                    cfg,
                    transcript: Transcript::default(),
                    phase: Phase::Recording(Recording {
                        capture,
                        started: now,
                        watchdog: Watchdog::new(self.seconds()),
                        meter: Meter::default(),
                        beat: (now, true),
                        drawn: now,
                    }),
                });
                tray::show_recording(&self.app, Some(true));
                self.bubble.listening();
            }
            Err(e) => {
                self.gesture.reset();
                let message = match &e {
                    MicError::Blocked => bubble::MIC_BLOCKED,
                    MicError::Missing => bubble::NO_MIC,
                    MicError::Other(_) => bubble::MIC_FAILED,
                };
                self.log(&format!("the microphone didn't open: {e}"));
                self.bubble.notice(message, NOTICE);
            }
        }
    }

    fn stop_recording(&mut self, reason: &'static str) {
        let Some(session) = self.session.as_mut() else {
            return;
        };
        let Phase::Recording(r) = &session.phase else {
            return;
        };
        let spoken = r.started.elapsed().as_secs_f64();
        let Phase::Recording(r) =
            std::mem::replace(&mut session.phase, Phase::Finishing { reason, spoken })
        else {
            return;
        };
        // Waits until every sample heard is with the speech thread.
        r.capture.stop();
        let _ = self.speech.send(ToSpeech::Finish(session.id));
        tray::show_recording(&self.app, None);
        self.bubble.finishing();
    }

    /// Clean the text, keep the records, and paste it where the cursor is.
    fn complete(&mut self, engine_ok: bool) {
        let Some(session) = self.session.take() else {
            return;
        };
        let Phase::Finishing { reason, spoken } = session.phase else {
            return;
        };
        let secs = spoken as u64;
        if !engine_ok {
            self.log(&format!(
                "dictation ended ({reason}) after {secs}s, but the speech model isn't loaded"
            ));
            self.bubble.notice(bubble::NO_ENGINE, LONG_NOTICE);
            return;
        }
        let raw = session.transcript.text().trim();
        if raw.is_empty() {
            self.log(&format!(
                "dictation ended ({reason}) after {secs}s with no text"
            ));
            self.bubble.hide();
            return;
        }
        let now = unix_now();
        let text = clean(raw, &session.cfg);
        if session.cfg.audit_log {
            self.records.audit_diff(raw, &text, now);
        }
        let words = word_count(&text);
        self.log(&format!(
            "dictation ended ({reason}) — {words} words in {secs}s"
        ));
        if let Err(e) = self.records.record_stats(words, Some(spoken), now) {
            self.log(&format!("couldn't save the stats line: {e}"));
        }
        let retention = Settings::load(&self.data.join("settings.json"))
            .settings
            .history_retention_days;
        if let Err(e) = self.records.record_history(&text, now, retention) {
            self.log(&format!("couldn't save the history line: {e}"));
        }

        if let Err(e) =
            paste::set_clipboard(&text, self.bubble.hwnd().unwrap_or(std::ptr::null_mut()))
        {
            self.log(&format!("nothing pasted: {e}"));
            self.bubble.notice(bubble::NO_CLIPBOARD, LONG_NOTICE);
            return;
        }
        if paste::target_refuses() {
            self.log(
                "paste skipped: the window runs as administrator; the text is on the clipboard",
            );
            self.bubble.notice(bubble::PASTE_REFUSED, LONG_NOTICE);
            return;
        }
        self.bubble.pasted();
        let records = self.records.clone();
        std::thread::spawn(move || {
            std::thread::sleep(BEFORE_PASTE);
            if !paste::press_ctrl_v() {
                records.log("Windows didn't take loqui's Ctrl+V", unix_now());
            }
        });
    }
}
