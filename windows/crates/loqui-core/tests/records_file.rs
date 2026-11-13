//! REC-01: History and stats records match the Mac's format.
//!
//! The fixtures in `shared/fixtures/` are what the Windows app writes; the
//! Mac's tests decode the same two files with the Mac app's own decoders.

use loqui_core::records::Records;
use std::path::{Path, PathBuf};

fn fixture(name: &str) -> String {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../../shared/fixtures")
        .join(name);
    std::fs::read_to_string(path).unwrap()
}

fn scratch(test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("loqui-records-{test}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    dir
}

const FIRST: i64 = 1_794_492_202; // 2026-11-12T14:03:22Z
const SECOND: i64 = 1_794_492_300; // 2026-11-12T14:05:00Z

#[test]
fn rec_01_history_and_stats_lines_are_the_macs_format() {
    let dir = scratch("format");
    let records = Records::new(&dir);
    records
        .record_history(
            "Please send the report to Sarah before Friday, and copy the whole team.",
            FIRST,
            0,
        )
        .unwrap();
    records.record_stats(13, Some(5.5), FIRST).unwrap();
    records
        .record_history("  I use Loqui every day.\n", SECOND, 0)
        .unwrap();
    // Under a second: the duration is noise and is left out, as on the Mac.
    records.record_stats(5, Some(0.4), SECOND).unwrap();

    assert_eq!(
        std::fs::read_to_string(records.history_path()).unwrap(),
        fixture("history-windows.jsonl")
    );
    assert_eq!(
        std::fs::read_to_string(records.stats_path()).unwrap(),
        fixture("dictation-log-windows.jsonl")
    );
    // The stats record never holds what was said.
    assert!(!std::fs::read_to_string(records.stats_path())
        .unwrap()
        .contains("Sarah"));
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn rec_01_history_off_writes_no_history_but_still_counts_stats() {
    let dir = scratch("off");
    let records = Records::new(&dir);
    records.record_history("Nothing kept.", FIRST, -1).unwrap();
    records.record_stats(2, Some(3.0), FIRST).unwrap();
    assert!(!records.history_path().exists());
    assert_eq!(
        std::fs::read_to_string(records.stats_path())
            .unwrap()
            .lines()
            .count(),
        1
    );
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn history_keeps_only_the_retention_window() {
    let dir = scratch("prune");
    let records = Records::new(&dir);
    let day = 86_400;
    records
        .record_history("ten days ago", FIRST - 10 * day, 7)
        .unwrap();
    records.record_history("yesterday", FIRST - day, 7).unwrap();
    records.prune_history(FIRST, 0).unwrap();
    assert_eq!(
        std::fs::read_to_string(records.history_path())
            .unwrap()
            .lines()
            .count(),
        2
    );
    records.prune_history(FIRST, 7).unwrap();
    let kept = std::fs::read_to_string(records.history_path()).unwrap();
    assert!(kept.contains("yesterday") && !kept.contains("ten days ago"));
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn the_cleanup_log_keeps_its_newest_half_past_two_megabytes() {
    let dir = scratch("audit");
    let records = Records::new(&dir);
    let raw = "x".repeat(1000);
    for i in 0..2100 {
        records.audit_diff(&format!("{i} {raw}"), "cleaned", FIRST);
    }
    let log = std::fs::read_to_string(records.cleanup_log_path()).unwrap();
    assert!(log.len() <= 2_000_000);
    assert!(log.starts_with("── "));
    assert!(log.contains("2099 "));
    records.audit_diff("same", "same", FIRST);
    assert_eq!(
        std::fs::read_to_string(records.cleanup_log_path()).unwrap(),
        log
    );
    std::fs::remove_dir_all(&dir).unwrap();
}
