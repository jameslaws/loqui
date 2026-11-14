// DIAG ONLY (branch diag-dict04-ending, never merged): the last sentences of a
// recording, decoded ten times with the start nudged a little each time, as
// the live segment boundaries move. Prints the final segment's text.
use loqui_speech::{read_wav, threads, Engine, Files};
use std::path::Path;
fn main() {
    let a: Vec<String> = std::env::args().collect();
    let mut e = Engine::load(&Files::under(Path::new(&a[1])), threads()).unwrap();
    for f in &a[2..] {
        let s = read_wav(&std::fs::read(f).unwrap()).unwrap();
        let from = s.len().saturating_sub(12 * 16_000);
        let mut ok = Vec::new();
        for k in 0..10 {
            let mut v = vec![0.0f32; 8000 + k * 336];
            v.extend_from_slice(&s[from..]);
            e.reset();
            let mut segs = Vec::new();
            for b in v.chunks(320) { segs.extend(e.accept(b)); }
            segs.extend(e.finish());
            ok.push(segs.last().map_or(String::new(), |x| x.text.clone()));
        }
        println!("{}", Path::new(f).file_name().unwrap().to_string_lossy());
        for t in ok { println!("    {t}"); }
    }
}
