//! What loqui's screens can ask for, and what they get back. The screens never
//! touch files: they call these through the app, which hands them to a
//! [`Store`]. The types are exported to TypeScript (`ui/src/bindings.ts`), so
//! the screens and Rust can't disagree about them; `cargo test` fails if that
//! file is out of date.

use crate::records::{self, HistoryEntry, Records};
use crate::settings::{Loaded, Settings};
use crate::shortcut::Shortcut;
use crate::updates::{Channel, UpdateStatus, Updates};
use crate::CleanupConfig;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use ts_rs::TS;

/// The dictation shortcut as text ("Ctrl+Shift+Space") and as key caps.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
pub struct ShortcutView {
    pub text: String,
    pub keys: Vec<String>,
}

impl From<Shortcut> for ShortcutView {
    fn from(s: Shortcut) -> Self {
        Self {
            text: s.to_string(),
            keys: s.keys(),
        }
    }
}

/// Settings, General.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct General {
    pub shortcut: ShortcutView,
    pub remove_fillers: bool,
    pub fillers: Vec<String>,
    /// -1 keeps no history, 0 keeps it forever, N keeps N days.
    #[ts(type = "number")]
    pub history_retention_days: i64,
    pub start_at_sign_in: bool,
    /// Set when a settings file couldn't be read: say so, and that defaults are in use.
    pub problem: Option<String>,
}

/// One dictionary entry: what loqui hears, and how it should be written.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
pub struct Term {
    pub heard: String,
    pub replacement: String,
}

/// One saved dictation. `at` is the time it was saved (ISO 8601, UTC).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
pub struct HistoryItem {
    pub at: String,
    pub text: String,
}

/// The welcome window's rows.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct Welcome {
    /// Windows lets desktop apps use the microphone.
    pub microphone_allowed: bool,
    pub shortcut: ShortcutView,
    pub start_at_sign_in: bool,
}

/// The names of the events loqui sends every open screen.
pub mod events {
    /// History gained, lost or cleared entries.
    pub const HISTORY_CHANGED: &str = "history-changed";
    /// A setting changed in another window.
    pub const SETTINGS_CHANGED: &str = "settings-changed";
    /// A dictation was counted for stats.
    pub const STATS_CHANGED: &str = "stats-changed";
    /// An update check started, finished, or an update is downloading.
    pub const UPDATES_CHANGED: &str = "updates-changed";
}

/// Reads and writes loqui's files for the screens.
#[derive(Debug, Clone)]
pub struct Store {
    records: Records,
}

impl Store {
    pub fn new(dir: impl Into<PathBuf>) -> Self {
        Self {
            records: Records::new(dir),
        }
    }

    pub fn records(&self) -> &Records {
        &self.records
    }

    fn settings_path(&self) -> PathBuf {
        self.records.dir().join("settings.json")
    }

    fn cleanup_path(&self) -> PathBuf {
        self.records.dir().join("cleanup.json")
    }

    pub fn settings(&self) -> Loaded {
        Settings::load(&self.settings_path())
    }

    fn update(&self, change: impl FnOnce(&mut Settings)) -> Result<Settings, String> {
        Settings::update(&self.settings_path(), change)
    }

    fn cleanup(&self) -> (CleanupConfig, Option<String>) {
        let path = self.cleanup_path();
        let unreadable = match std::fs::read_to_string(&path) {
            Ok(text) => CleanupConfig::from_json(&text).is_err(),
            Err(e) => e.kind() != std::io::ErrorKind::NotFound,
        };
        let cfg = CleanupConfig::load(&path);
        (
            cfg,
            unreadable.then(|| crate::config::UNREADABLE.to_string()),
        )
    }

    pub fn general(&self) -> General {
        let loaded = self.settings();
        let (cfg, cleanup_problem) = self.cleanup();
        let problem = loaded
            .unreadable
            .then(|| crate::settings::UNREADABLE.to_string())
            .or(cleanup_problem);
        General {
            shortcut: loaded.settings.shortcut.into(),
            remove_fillers: cfg.remove_fillers,
            fillers: cfg.fillers,
            history_retention_days: loaded.settings.history_retention_days,
            start_at_sign_in: loaded.settings.start_at_sign_in,
            problem,
        }
    }

    /// Save a shortcut pressed in the recorder, or say why it can't be one.
    pub fn set_shortcut(&self, pressed: &str) -> Result<Shortcut, String> {
        let shortcut = Shortcut::from_pressed(pressed).map_err(str::to_string)?;
        self.update(|s| s.shortcut = shortcut)?;
        Ok(shortcut)
    }

    /// Filler words as the Mac saves them: trimmed, lower case, no blanks or repeats.
    pub fn set_fillers(&self, remove: bool, fillers: &[String]) -> Result<(), String> {
        let mut clean: Vec<String> = Vec::new();
        for word in fillers.iter().map(|w| w.trim().to_lowercase()) {
            if !word.is_empty() && !clean.contains(&word) {
                clean.push(word);
            }
        }
        CleanupConfig::update(&self.cleanup_path(), |c| {
            c.remove_fillers = remove;
            c.fillers = clean;
        })
        .map(drop)
    }

    /// Keep history for this long, and drop what's now too old at once.
    pub fn set_retention(&self, days: i64, now: i64) -> Result<(), String> {
        let saved = self.update(|s| s.history_retention_days = days)?;
        self.records
            .prune_history(now, saved.history_retention_days)
            .map_err(|e| format!("loqui couldn't tidy the history: {e}"))
    }

    pub fn set_start_at_sign_in(&self, on: bool) -> Result<Settings, String> {
        self.update(|s| s.start_at_sign_in = on)
    }

    /// "Get test versions": on reads the test update list, off the public one.
    pub fn set_test_versions(&self, on: bool) -> Result<Settings, String> {
        self.update(|s| s.channel = if on { Channel::Test } else { Channel::Stable })
    }

    /// The welcome was finished: it won't open by itself again.
    pub fn finish_welcome(&self) -> Result<(), String> {
        self.update(|s| s.onboarded = true).map(drop)
    }

    /// The dictionary, sorted by what loqui hears.
    pub fn dictionary(&self) -> Vec<Term> {
        self.cleanup()
            .0
            .dictionary
            .into_iter()
            .map(|(heard, replacement)| Term { heard, replacement })
            .collect()
    }

    /// Replace the dictionary, as the Mac saves it: heard words trimmed and in
    /// lower case, replacements trimmed, rows missing either side left out.
    /// Every other cleanup setting stays as it was.
    pub fn set_dictionary(&self, terms: &[Term]) -> Result<(), String> {
        let dictionary = terms
            .iter()
            .map(|t| {
                (
                    t.heard.trim().to_lowercase(),
                    t.replacement.trim().to_string(),
                )
            })
            .filter(|(h, r)| !h.is_empty() && !r.is_empty())
            .collect();
        CleanupConfig::update(&self.cleanup_path(), |c| c.dictionary = dictionary).map(drop)
    }

    pub fn history(&self) -> Vec<HistoryItem> {
        self.records
            .history()
            .into_iter()
            .map(|e| HistoryItem {
                at: e.at,
                text: e.text,
            })
            .collect()
    }

    pub fn delete_history(&self, item: &HistoryItem) -> Result<(), String> {
        let entry = HistoryEntry {
            at: item.at.clone(),
            text: item.text.clone(),
        };
        self.records
            .delete_history(&entry)
            .map_err(|e| format!("loqui couldn't delete it: {e}"))
    }

    pub fn clear_history(&self) -> Result<(), String> {
        self.records
            .clear_history()
            .map_err(|e| format!("loqui couldn't clear the history: {e}"))
    }

    /// The stats window's figures for a period, counted in the time zone of
    /// `now` (the PC's own) with weeks starting on `first_weekday`.
    pub fn stats<Tz: chrono::TimeZone>(
        &self,
        request: &crate::stats::StatsRequest,
        now: &chrono::DateTime<Tz>,
        first_weekday: chrono::Weekday,
    ) -> crate::stats::Stats {
        let log = std::fs::read_to_string(self.records.stats_path()).unwrap_or_default();
        let shortcut = self.settings().settings.shortcut.to_string();
        crate::stats::stats(&log, now, first_weekday, request, &shortcut)
    }

    /// The tray menu's Recent list: the last `n` dictations as (one line, full text).
    pub fn recent(&self, n: usize) -> Vec<(String, String)> {
        self.records
            .history()
            .into_iter()
            .take(n)
            .map(|e| (records::one_line(&e.text), e.text))
            .collect()
    }
}

/// Every type the screens use, as one TypeScript file.
pub fn typescript() -> String {
    let cfg = ts_rs::Config::default();
    let decls = [
        ShortcutView::decl(&cfg),
        General::decl(&cfg),
        Term::decl(&cfg),
        HistoryItem::decl(&cfg),
        Welcome::decl(&cfg),
        UpdateStatus::decl(&cfg),
        Updates::decl(&cfg),
    ];
    let decls = decls
        .into_iter()
        .chain(crate::stats::typescript_decls(&cfg));
    let mut out = String::from(
        "// Made by loqui-core (crates/loqui-core/src/commands.rs). Don't edit by hand:\n\
         // `LOQUI_WRITE_BINDINGS=1 cargo test -p loqui-core` writes it again.\n\n",
    );
    for decl in decls {
        out.push_str("export ");
        out.push_str(&decl);
        out.push_str("\n\n");
    }
    out.push_str(&format!(
        "export const events = {{ historyChanged: \"{}\", settingsChanged: \"{}\", statsChanged: \"{}\", updatesChanged: \"{}\" }} as const;\n",
        events::HISTORY_CHANGED,
        events::SETTINGS_CHANGED,
        events::STATS_CHANGED,
        events::UPDATES_CHANGED
    ));
    out
}

/// Where the TypeScript file lives, from the crate's folder.
pub fn typescript_path(crate_dir: &Path) -> PathBuf {
    crate_dir.join("../../ui/src/bindings.ts")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn store(name: &str) -> Store {
        let dir = std::env::temp_dir().join(format!("loqui-store-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        Store::new(dir)
    }

    #[test]
    fn the_typescript_types_are_up_to_date() {
        let path = typescript_path(Path::new(env!("CARGO_MANIFEST_DIR")));
        let made = typescript();
        if std::env::var_os("LOQUI_WRITE_BINDINGS").is_some() {
            std::fs::write(&path, &made).unwrap();
        }
        let current = std::fs::read_to_string(&path)
            .unwrap_or_default()
            .replace("\r\n", "\n");
        assert_eq!(current, made, "ui/src/bindings.ts is out of date: run LOQUI_WRITE_BINDINGS=1 cargo test -p loqui-core");
    }

    #[test]
    fn set_01_a_refused_shortcut_is_explained_and_an_accepted_one_saved() {
        let s = store("shortcut");
        assert_eq!(
            s.set_shortcut("Shift+A"),
            Err("Use Ctrl or Alt with a key, or a function key.".into())
        );
        assert_eq!(s.general().shortcut.text, "Ctrl+Shift+Space");
        s.set_shortcut("Ctrl+Alt+D").unwrap();
        assert_eq!(s.general().shortcut.keys, ["Ctrl", "Alt", "D"]);
        s.set_shortcut("F8").unwrap();
        assert_eq!(s.settings().settings.shortcut.to_string(), "F8");
        std::fs::remove_dir_all(s.records().dir()).unwrap();
    }

    #[test]
    fn set_02_filler_words_are_added_removed_and_switched_off() {
        let s = store("fillers");
        let said = "I like, um, the plan";
        let clean = |s: &Store| crate::clean(said, &CleanupConfig::load(&s.cleanup_path()));
        let mut fillers = s.general().fillers;
        fillers.push(" Like ".into());
        s.set_fillers(true, &fillers).unwrap();
        assert_eq!(s.general().fillers.last().unwrap(), "like");
        assert_eq!(clean(&s), "I the plan");
        fillers.pop();
        s.set_fillers(true, &fillers).unwrap();
        assert_eq!(clean(&s), "I like, the plan");
        s.set_fillers(false, &fillers).unwrap();
        assert_eq!(clean(&s), "I like, um, the plan");
        std::fs::remove_dir_all(s.records().dir()).unwrap();
    }

    #[test]
    fn set_03_retention_drops_old_entries_at_once() {
        let s = store("retention");
        let now = 1_800_000_000;
        let day = 86_400;
        for age in [40, 10, 1] {
            s.records()
                .record_history(&format!("{age} days old"), now - age * day, 0)
                .unwrap();
        }
        let texts = |s: &Store| s.history().into_iter().map(|h| h.text).collect::<Vec<_>>();
        s.set_retention(30, now).unwrap();
        assert_eq!(texts(&s), ["1 days old", "10 days old"]);
        s.set_retention(7, now).unwrap();
        assert_eq!(texts(&s), ["1 days old"]);
        s.set_retention(-1, now).unwrap();
        let off = s.settings().settings.history_retention_days;
        s.records().record_history("not kept", now, off).unwrap();
        assert_eq!(texts(&s), ["1 days old"]);
        s.set_retention(0, now).unwrap();
        s.records().record_history("kept", now + 1, 0).unwrap();
        s.set_retention(0, now + 400 * day).unwrap();
        assert_eq!(texts(&s), ["kept", "1 days old"]);
        std::fs::remove_dir_all(s.records().dir()).unwrap();
    }

    #[test]
    fn dictn_01_the_dictionary_saves_and_keeps_every_other_field() {
        let s = store("dictionary");
        std::fs::create_dir_all(s.records().dir()).unwrap();
        std::fs::write(
            s.cleanup_path(),
            r#"{"dictionary": {"loki": "Loqui", "sarah k": "Sara K."}, "timedHealWords": ["and"], "maxPauseSeconds": 0.8, "somethingNew": 1}"#,
        )
        .unwrap();
        let mut terms = s.dictionary();
        assert_eq!(terms[0].heard, "loki");
        terms.retain(|t| t.heard != "loki");
        terms[0].replacement = "Sara K".into();
        terms.push(Term {
            heard: " Grayson ".into(),
            replacement: "Greyson".into(),
        });
        terms.push(Term {
            heard: "half done".into(),
            replacement: " ".into(),
        });
        s.set_dictionary(&terms).unwrap();

        let saved: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(s.cleanup_path()).unwrap()).unwrap();
        assert_eq!(
            saved["dictionary"],
            serde_json::json!({"grayson": "Greyson", "sarah k": "Sara K"})
        );
        assert_eq!(saved["timedHealWords"], serde_json::json!(["and"]));
        assert_eq!(saved["maxPauseSeconds"], 0.8);
        assert_eq!(saved["somethingNew"], 1);
        let cfg = CleanupConfig::load(&s.cleanup_path());
        assert_eq!(crate::clean("grayson called", &cfg), "Greyson called");
        std::fs::remove_dir_all(s.records().dir()).unwrap();
    }

    #[test]
    fn an_unreadable_file_is_reported_and_never_overwritten() {
        let s = store("unreadable");
        std::fs::create_dir_all(s.records().dir()).unwrap();
        std::fs::write(s.cleanup_path(), "{ oops").unwrap();
        assert!(s.general().problem.unwrap().contains("couldn't be read"));
        assert!(s.set_dictionary(&[]).is_err());
        assert_eq!(std::fs::read_to_string(s.cleanup_path()).unwrap(), "{ oops");
        std::fs::remove_dir_all(s.records().dir()).unwrap();
    }
}
