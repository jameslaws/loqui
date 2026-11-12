//! CLEAN-03: The Windows app passes every shared example.
//!
//! Runs `shared/cleanup-cases.json`, the same file the Mac's `swift test` runs,
//! and lists each example by its id. A failure names the example.

use libtest_mimic::{Arguments, Failed, Trial};
use loqui_core::{clean, timed_heal, CleanupConfig};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize)]
struct Segment {
    text: String,
    start: Option<f64>,
    end: Option<f64>,
}

#[derive(Deserialize)]
struct Case {
    id: String,
    config: Option<Value>,
    #[serde(rename = "in")]
    input: Option<String>,
    segments: Option<Vec<Segment>>,
    out: String,
}

#[derive(Deserialize)]
struct File {
    cases: Vec<Case>,
    #[serde(rename = "timedCases")]
    timed_cases: Vec<Case>,
}

/// Bank segments the way the recognizer hands them over: the gap is this
/// segment's start minus the last known end, and a segment without times keeps it.
fn bank_segments(segments: &[Segment], cfg: &CleanupConfig) -> String {
    let mut text = String::new();
    let mut last_end: Option<f64> = None;
    for s in segments {
        let gap = s.start.zip(last_end).map(|(start, end)| start - end);
        text = timed_heal::bank(&s.text, &text, gap, cfg).0;
        last_end = s.end.or(last_end);
    }
    text
}

fn run(case: &Case) -> Result<(), Failed> {
    // Overrides go through the real settings reader, so missing keys take defaults.
    let cfg = match &case.config {
        Some(v) => CleanupConfig::from_json(&v.to_string()).map_err(|e| e.to_string())?,
        None => CleanupConfig::default(),
    };
    let raw = match (&case.input, &case.segments) {
        (Some(input), _) => input.clone(),
        (None, Some(segments)) => bank_segments(segments, &cfg),
        (None, None) => return Err(format!("{} needs `in` or `segments`", case.id).into()),
    };
    let got = clean(&raw, &cfg);
    if got == case.out {
        Ok(())
    } else {
        Err(format!("FAIL {}: expected {:?}, got {:?}", case.id, case.out, got).into())
    }
}

fn main() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../shared/cleanup-cases.json"
    );
    let text = std::fs::read_to_string(path).expect("shared/cleanup-cases.json is readable");
    let file: File = serde_json::from_str(&text).expect("shared/cleanup-cases.json is valid");
    let trials = file
        .cases
        .into_iter()
        .chain(file.timed_cases)
        .map(|case| Trial::test(case.id.clone(), move || run(&case)))
        .collect();
    libtest_mimic::run(&Arguments::from_args(), trials).exit();
}
