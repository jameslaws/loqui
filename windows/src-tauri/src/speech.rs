//! The speech thread: loads the model once when loqui starts, then turns each
//! dictation's audio into text segment by segment. A dictation that starts
//! before the model has loaded still records; its audio waits here and its
//! text arrives once the model is ready.

use crate::dictation::Event;
use loqui_speech::{threads, Engine, Files};
use std::sync::mpsc::{channel, Sender};
use std::time::Instant;

pub enum ToSpeech {
    /// A new dictation: its segment times count from here.
    Begin(u64),
    Audio(u64, Vec<f32>),
    /// The dictation stopped: finish its last segment.
    Finish(u64),
}

pub fn start(files: Files, events: Sender<Event>) -> std::io::Result<Sender<ToSpeech>> {
    let (tx, rx) = channel::<ToSpeech>();
    std::thread::Builder::new()
        .name("loqui speech".into())
        .spawn(move || {
            let started = Instant::now();
            let mut engine = Engine::load(&files, threads());
            let _ = events.send(Event::EngineLoaded(
                engine
                    .as_ref()
                    .map(|_| started.elapsed().as_secs_f64())
                    .map_err(Clone::clone),
            ));
            let mut current = 0;
            for message in rx {
                match (message, engine.as_mut()) {
                    (ToSpeech::Begin(id), engine) => {
                        current = id;
                        if let Ok(engine) = engine {
                            engine.reset();
                        }
                    }
                    (ToSpeech::Audio(id, samples), Ok(engine)) if id == current => {
                        for segment in engine.accept(&samples) {
                            let _ = events.send(Event::Segment(id, segment));
                        }
                    }
                    (ToSpeech::Audio(..), _) => {}
                    (ToSpeech::Finish(id), engine) => {
                        let ok = match engine {
                            Ok(engine) => {
                                if id == current {
                                    for segment in engine.finish() {
                                        let _ = events.send(Event::Segment(id, segment));
                                    }
                                }
                                true
                            }
                            Err(_) => false,
                        };
                        let _ = events.send(Event::Finished(id, ok));
                    }
                }
            }
        })?;
    Ok(tx)
}
