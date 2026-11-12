//! CLEAN-05: A Mac settings file loads unchanged on Windows.
//!
//! The fixtures in `shared/fixtures/` are cleanup.json files as the Mac app
//! writes them (the Mac's tests check the full one byte for byte).

use loqui_core::CleanupConfig;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

fn fixture(name: &str) -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../../shared/fixtures")
        .join(name)
}

/// A private copy of a fixture in a fresh folder, so loading can't touch the original.
fn scratch_copy(name: &str, test: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("loqui-core-{test}-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("cleanup.json");
    std::fs::copy(fixture(name), &path).unwrap();
    path
}

fn words(list: &[&str]) -> Vec<String> {
    list.iter().map(|w| w.to_string()).collect()
}

#[test]
fn clean_05_a_mac_settings_file_loads_unchanged_on_windows() {
    // The full file: every value, including the four dictionary terms.
    let full = CleanupConfig::load(&scratch_copy("cleanup-mac-full.json", "full"));
    let terms = BTreeMap::from([
        ("and slash or".to_string(), "and/or".to_string()),
        ("loki".to_string(), "loqui".to_string()),
        ("sarah k".to_string(), "Sara K.".to_string()),
        ("zoe".to_string(), "Zoë".to_string()),
    ]);
    assert_eq!(
        full,
        CleanupConfig {
            dictionary: terms,
            remove_fillers: true,
            fillers: words(&["um", "uh", "like"]),
            spoken_formatting: true,
            heal_sentence_splits: true,
            continuation_words: words(&["or", "nor", "which", "whose", "whom", "than", "because"]),
            timed_heal_words: words(&["and", "but"]),
            max_pause_seconds: 0.6,
            audit_log: false,
        }
    );

    // The old file: its terms and its one setting, defaults for the rest.
    let old = CleanupConfig::load(&scratch_copy("cleanup-mac-old.json", "old"));
    let defaults = CleanupConfig::default();
    assert_eq!(
        old,
        CleanupConfig {
            dictionary: BTreeMap::from([
                ("jira".to_string(), "Jira".to_string()),
                ("loki".to_string(), "loqui".to_string()),
            ]),
            remove_fillers: false,
            ..defaults.clone()
        }
    );

    // The broken file: defaults for this read, and the file left byte for byte.
    let broken_path = scratch_copy("cleanup-mac-broken.json", "broken");
    let before = std::fs::read(&broken_path).unwrap();
    assert_eq!(CleanupConfig::load(&broken_path), defaults);
    assert_eq!(std::fs::read(&broken_path).unwrap(), before);
}

#[test]
fn a_missing_settings_file_is_created_with_the_defaults() {
    let dir = std::env::temp_dir().join(format!("loqui-core-missing-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    let path = dir.join("Loqui").join("cleanup.json");

    assert_eq!(CleanupConfig::load(&path), CleanupConfig::default());
    let written = std::fs::read_to_string(&path).unwrap();
    assert_eq!(
        CleanupConfig::from_json(&written).unwrap(),
        CleanupConfig::default()
    );
}
