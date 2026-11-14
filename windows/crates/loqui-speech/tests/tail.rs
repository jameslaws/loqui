//! DICT-04: the end of a dictation becomes text. These run the real engine and
//! model, so `pnpm fetch:speech` must have put them in `src-tauri` first (the
//! Windows checks do).
//!
//! `ask.wav` is John F. Kennedy's inaugural address (1961, public domain), the
//! Parakeet model's own English test recording, at 16 kHz: "Ask not what your
//! country can do for you," a second of silence, then "Ask", and the recording
//! stops as the word ends, as when you let go of the shortcut right after it.

use loqui_speech::{read_wav, threads, Engine, Files, Segment, SAMPLE_RATE};
use std::path::Path;

fn engine() -> Engine {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../src-tauri");
    Engine::load(&Files::under(&root), threads())
        .unwrap_or_else(|e| panic!("{e}: run `pnpm fetch:speech` in windows/ first"))
}

fn ask() -> Vec<f32> {
    let bytes = std::fs::read(Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/ask.wav"))
        .expect("tests/ask.wav");
    read_wav(&bytes).expect("sound in tests/ask.wav")
}

/// Fed in 20 ms blocks, as the microphone passes them on, then stopped.
fn dictate(engine: &mut Engine, samples: &[f32]) -> Vec<Segment> {
    engine.reset();
    let mut segments = Vec::new();
    for block in samples.chunks(320) {
        segments.extend(engine.accept(block));
    }
    segments.extend(engine.finish());
    segments
}

fn seconds(samples: &[f32]) -> f64 {
    samples.len() as f64 / f64::from(SAMPLE_RATE)
}

#[test]
fn a_short_last_word_said_just_before_the_stop_is_kept() {
    let audio = ask();
    let segments = dictate(&mut engine(), &audio);
    let [first, last] = &segments[..] else {
        panic!("expected the sentence and the last word, got {segments:?}");
    };
    assert!(first.text.contains("country"), "{segments:?}");
    // The sentence ends by 1.95 s; "Ask" comes after the second of silence.
    assert!(
        last.start >= 1.9 && last.end >= seconds(&audio),
        "{segments:?}"
    );
    assert!(!last.text.is_empty(), "{segments:?}");
}

#[test]
fn every_sample_before_the_stop_reaches_the_last_segment() {
    // Stopped mid-sentence, 1.5 s in: not a whole number of the detector's windows.
    let audio = ask();
    let cut = &audio[..24_000];
    let segments = dictate(&mut engine(), cut);
    let last = segments.last().expect("text for the half sentence");
    assert!(last.end >= seconds(cut), "{segments:?}");
}

#[test]
fn silence_before_the_stop_adds_nothing() {
    // The sentence and the second of silence, stopped before "Ask".
    let audio = ask();
    let segments = dictate(&mut engine(), &audio[..46_400]);
    assert_eq!(segments.len(), 1, "{segments:?}");
    assert!(segments[0].text.contains("country"), "{segments:?}");
}
