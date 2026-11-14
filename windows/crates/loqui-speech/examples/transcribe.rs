//! Turn a 16 kHz mono 16-bit WAV into text the way loqui does, printing each
//! segment and its times. For checking the engine on any computer:
//! `cargo run --release -p loqui-speech --example transcribe -- <folder with engine/ and models/> <file.wav>`

use loqui_speech::{read_wav, threads, Engine, Files};
use std::path::Path;
use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let [_, root, wav] = &args[..] else {
        eprintln!("usage: transcribe <folder> <file.wav>");
        std::process::exit(2);
    };
    let started = Instant::now();
    let mut engine = Engine::load(&Files::under(Path::new(root)), threads()).unwrap_or_else(|e| {
        eprintln!("{e}");
        std::process::exit(1);
    });
    println!("loaded in {:.2}s", started.elapsed().as_secs_f64());

    let samples = std::fs::read(wav)
        .ok()
        .and_then(|bytes| read_wav(&bytes))
        .unwrap_or_else(|| panic!("no sound in {wav}"));
    let seconds = samples.len() as f64 / 16_000.0;
    let started = Instant::now();
    engine.reset();
    let mut segments = Vec::new();
    for block in samples.chunks(1600) {
        segments.extend(engine.accept(block));
    }
    let before_finish = started.elapsed().as_secs_f64();
    segments.extend(engine.finish());
    let total = started.elapsed().as_secs_f64();
    for s in &segments {
        println!("{:7.2} {:7.2}  {}", s.start, s.end, s.text);
    }
    println!(
        "{seconds:.1}s of audio: {before_finish:.2}s while feeding, {:.2}s to finish",
        total - before_finish
    );
}
