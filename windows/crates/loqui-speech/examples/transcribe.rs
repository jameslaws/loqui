//! Turn a 16 kHz mono 16-bit WAV into text the way loqui does, printing each
//! segment and its times. For checking the engine on any computer:
//! `cargo run --release -p loqui-speech --example transcribe -- <folder with engine/ and models/> <file.wav>`

use loqui_speech::{threads, Engine, Files};
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

    let samples = read_wav(Path::new(wav));
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

fn read_wav(path: &Path) -> Vec<f32> {
    let bytes = std::fs::read(path).expect("readable WAV");
    let mut i = 12;
    while i + 8 <= bytes.len() {
        let id = &bytes[i..i + 4];
        let len = u32::from_le_bytes(bytes[i + 4..i + 8].try_into().unwrap()) as usize;
        if id == b"data" {
            let end = (i + 8 + len).min(bytes.len());
            return bytes[i + 8..end]
                .as_chunks::<2>()
                .0
                .iter()
                .map(|b| f32::from(i16::from_le_bytes(*b)) / 32_768.0)
                .collect();
        }
        i += 8 + len + (len & 1);
    }
    panic!("no data in {}", path.display());
}
