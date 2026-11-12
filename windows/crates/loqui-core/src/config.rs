//! The cleanup settings file, `cleanup.json`, in exactly the Mac app's format:
//! same keys, same defaults, and the same forgiving read. A file from an older
//! build fills its missing keys with defaults, and a file that won't parse is
//! left untouched (so a typo can be fixed) while defaults are used for that read.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CleanupConfig {
    /// Spoken phrase to written form, applied as whole words in any case.
    pub dictionary: BTreeMap<String, String>,
    pub remove_fillers: bool,
    pub fillers: Vec<String>,
    /// "new line" and "new paragraph" become line breaks.
    pub spoken_formatting: bool,
    /// Stitch back sentences the recognizer split at a mid-sentence pause.
    pub heal_sentence_splits: bool,
    /// Words that almost never open a sentence, so a period before one is a pause.
    pub continuation_words: Vec<String>,
    /// Words healed only when the measured pause is short enough.
    pub timed_heal_words: Vec<String>,
    /// The pause, in seconds, under which a sentence break counts as a hesitation.
    pub max_pause_seconds: f64,
    /// Keep a local log of what cleanup changed.
    pub audit_log: bool,
}

/// What the settings screen says when `cleanup.json` is unreadable.
pub const UNREADABLE: &str =
    "Your cleanup.json couldn't be read, so defaults are in use. Fix or delete it to save changes here.";

impl Default for CleanupConfig {
    /// The Mac app's shipped defaults (CleanupConfig.defaults in CleanupConfig.swift).
    fn default() -> Self {
        let words = |list: &[&str]| list.iter().map(|w| w.to_string()).collect();
        Self {
            dictionary: BTreeMap::new(),
            remove_fillers: true,
            fillers: words(&["um", "umm", "uh", "uhh", "uhm", "er", "erm", "hmm", "mhm"]),
            spoken_formatting: false,
            heal_sentence_splits: true,
            continuation_words: words(&["or", "nor", "which", "whose", "whom", "than", "because"]),
            timed_heal_words: words(&["and", "but", "so"]),
            max_pause_seconds: 0.5,
            audit_log: true,
        }
    }
}

/// Every key optional, and `null` counts as missing, matching the Mac's
/// `decodeIfPresent`. A key with the wrong type still fails the whole file.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct StoredConfig {
    dictionary: Option<BTreeMap<String, String>>,
    remove_fillers: Option<bool>,
    fillers: Option<Vec<String>>,
    spoken_formatting: Option<bool>,
    heal_sentence_splits: Option<bool>,
    continuation_words: Option<Vec<String>>,
    timed_heal_words: Option<Vec<String>>,
    max_pause_seconds: Option<f64>,
    audit_log: Option<bool>,
}

impl CleanupConfig {
    /// Read settings from JSON text, filling any missing key with its default.
    pub fn from_json(text: &str) -> serde_json::Result<Self> {
        let s: StoredConfig = serde_json::from_str(text)?;
        let d = Self::default();
        Ok(Self {
            dictionary: s.dictionary.unwrap_or(d.dictionary),
            remove_fillers: s.remove_fillers.unwrap_or(d.remove_fillers),
            fillers: s.fillers.unwrap_or(d.fillers),
            spoken_formatting: s.spoken_formatting.unwrap_or(d.spoken_formatting),
            heal_sentence_splits: s.heal_sentence_splits.unwrap_or(d.heal_sentence_splits),
            continuation_words: s.continuation_words.unwrap_or(d.continuation_words),
            timed_heal_words: s.timed_heal_words.unwrap_or(d.timed_heal_words),
            max_pause_seconds: s.max_pause_seconds.unwrap_or(d.max_pause_seconds),
            audit_log: s.audit_log.unwrap_or(d.audit_log),
        })
    }

    /// Pretty JSON with sorted keys, like the Mac writes.
    pub fn to_json(&self) -> String {
        // Going through a Value sorts the keys.
        let value = serde_json::to_value(self).expect("settings always serialize");
        serde_json::to_string_pretty(&value).expect("settings always serialize")
    }

    /// Where Windows keeps the file: `%LOCALAPPDATA%\Loqui\cleanup.json`,
    /// never the roaming profile.
    pub fn path() -> Option<PathBuf> {
        Some(crate::records::data_dir()?.join("cleanup.json"))
    }

    /// Load from `path`. A missing file is created with the defaults. A file
    /// that can't be read or parsed is left exactly as it is and the defaults
    /// are used for this read.
    pub fn load(path: &Path) -> Self {
        match std::fs::read(path) {
            Ok(bytes) => std::str::from_utf8(&bytes)
                .ok()
                .and_then(|text| Self::from_json(text).ok())
                .unwrap_or_default(),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                let defaults = Self::default();
                // Seeding is a convenience; the defaults stand even if it fails.
                let _ = defaults.save(path);
                defaults
            }
            Err(_) => Self::default(),
        }
    }

    /// Change the settings a screen owns and save them. Every other key in the
    /// file stays as it was (the sentence-healing words, the pause length,
    /// anything typed by hand), as the Mac's Settings window keeps them. A file
    /// that can't be read is left alone and the change is refused.
    pub fn update(path: &Path, change: impl FnOnce(&mut Self)) -> Result<Self, String> {
        let mut kept = match std::fs::read_to_string(path) {
            Ok(text) => match serde_json::from_str::<serde_json::Value>(&text) {
                Ok(serde_json::Value::Object(map)) if Self::from_json(&text).is_ok() => map,
                _ => return Err(UNREADABLE.into()),
            },
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => serde_json::Map::new(),
            Err(_) => return Err(UNREADABLE.into()),
        };
        let mut cfg = Self::from_json(&serde_json::Value::Object(kept.clone()).to_string())
            .unwrap_or_default();
        change(&mut cfg);
        if let serde_json::Value::Object(owned) =
            serde_json::to_value(&cfg).expect("settings always serialize")
        {
            kept.extend(owned);
        }
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
        }
        let text = serde_json::to_string_pretty(&kept).expect("settings always serialize");
        std::fs::write(path, text).map_err(|e| format!("loqui couldn't save cleanup.json: {e}"))?;
        Ok(cfg)
    }

    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir)?;
        }
        std::fs::write(path, self.to_json())
    }
}
