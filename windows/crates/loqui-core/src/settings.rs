//! `%LOCALAPPDATA%\Loqui\settings.json`: the Windows app's own settings. The
//! dictation part created it with the shortcut and how long history is kept;
//! the settings screens add whether loqui starts at sign-in and whether the
//! welcome was finished. Read as forgivingly as `cleanup.json`: missing keys
//! take their defaults, and a file that won't parse is left untouched (so a
//! typo can be fixed) while the defaults are used.
//!
//! Saving changes only the keys a change is about and keeps every other key in
//! the file, so a later part's settings (and anything typed in by hand) survive.

use crate::shortcut::Shortcut;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
pub struct Settings {
    pub shortcut: Shortcut,
    /// The Mac's meanings: -1 keeps no history, 0 keeps it forever, N keeps N days.
    pub history_retention_days: i64,
    /// Start loqui when you sign in to Windows (plan decision 11: on by default).
    pub start_at_sign_in: bool,
    /// The welcome window was finished, so it no longer opens by itself.
    pub onboarded: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            shortcut: Shortcut::default(),
            history_retention_days: 0,
            start_at_sign_in: true,
            onboarded: false,
        }
    }
}

/// What the settings screen says when the file is unreadable.
pub const UNREADABLE: &str = "Your settings file couldn't be read, so defaults are in use.";

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Stored {
    shortcut: Option<String>,
    history_retention_days: Option<i64>,
    start_at_sign_in: Option<bool>,
    onboarded: Option<bool>,
}

/// Settings as read, plus a line for the log when something fell back to a default.
#[derive(Debug, Clone, PartialEq)]
pub struct Loaded {
    pub settings: Settings,
    pub problem: Option<String>,
    /// The file exists but couldn't be read, so changes can't be saved into it.
    pub unreadable: bool,
}

impl Settings {
    pub fn from_json(text: &str) -> Result<Loaded, serde_json::Error> {
        let stored: Stored = serde_json::from_str(text)?;
        let defaults = Self::default();
        let (shortcut, problem) = match stored.shortcut {
            None => (defaults.shortcut, None),
            Some(text) => match Shortcut::parse(&text) {
                Some(s) => (s, None),
                None => (
                    defaults.shortcut,
                    Some(format!(
                        "settings.json: \"{text}\" can't be a shortcut (use Ctrl or Alt with a key, or F1 to F24); using {}",
                        defaults.shortcut
                    )),
                ),
            },
        };
        Ok(Loaded {
            settings: Self {
                shortcut,
                history_retention_days: stored
                    .history_retention_days
                    .unwrap_or(defaults.history_retention_days),
                start_at_sign_in: stored.start_at_sign_in.unwrap_or(defaults.start_at_sign_in),
                onboarded: stored.onboarded.unwrap_or(defaults.onboarded),
            },
            problem,
            unreadable: false,
        })
    }

    fn stored(&self) -> Map<String, Value> {
        let stored = Stored {
            shortcut: Some(self.shortcut.to_string()),
            history_retention_days: Some(self.history_retention_days),
            start_at_sign_in: Some(self.start_at_sign_in),
            onboarded: Some(self.onboarded),
        };
        match serde_json::to_value(stored) {
            Ok(Value::Object(map)) => map,
            _ => Map::new(),
        }
    }

    pub fn to_json(&self) -> String {
        pretty(&self.stored())
    }

    /// Load from `path`, creating it with the defaults if it's missing.
    pub fn load(path: &Path) -> Loaded {
        let fallback = |problem: String| Loaded {
            settings: Self::default(),
            problem: Some(problem),
            unreadable: true,
        };
        match std::fs::read_to_string(path) {
            Ok(text) => Self::from_json(&text).unwrap_or_else(|e| {
                fallback(format!("settings.json can't be read ({e}); using the defaults and leaving the file as it is"))
            }),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                let defaults = Self::default();
                let saved = write(path, &defaults.to_json());
                Loaded {
                    settings: defaults,
                    problem: saved
                        .err()
                        .map(|e| format!("couldn't create settings.json: {e}")),
                    unreadable: false,
                }
            }
            Err(e) => fallback(format!(
                "settings.json can't be opened ({e}); using the defaults"
            )),
        }
    }

    /// Change the settings and save them, keeping every key in the file that
    /// loqui doesn't own. An unreadable file is left alone and the change is
    /// refused with [`UNREADABLE`].
    pub fn update(path: &Path, change: impl FnOnce(&mut Settings)) -> Result<Settings, String> {
        let mut kept = match std::fs::read_to_string(path) {
            Ok(text) => match serde_json::from_str::<Value>(&text) {
                Ok(Value::Object(map)) if Self::from_json(&text).is_ok() => map,
                _ => return Err(UNREADABLE.into()),
            },
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Map::new(),
            Err(_) => return Err(UNREADABLE.into()),
        };
        let mut settings = Self::from_json(&pretty(&kept))
            .map(|l| l.settings)
            .unwrap_or_default();
        change(&mut settings);
        kept.extend(settings.stored());
        write(path, &pretty(&kept))
            .map_err(|e| format!("loqui couldn't save settings.json: {e}"))?;
        Ok(settings)
    }
}

fn pretty(map: &Map<String, Value>) -> String {
    serde_json::to_string_pretty(map).expect("settings always serialize")
}

fn write(path: &Path, text: &str) -> std::io::Result<()> {
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    std::fs::write(path, text)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(name: &str) -> std::path::PathBuf {
        let dir =
            std::env::temp_dir().join(format!("loqui-settings-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        dir.join("settings.json")
    }

    #[test]
    fn missing_keys_take_defaults_and_a_bad_shortcut_is_explained() {
        let loaded = Settings::from_json(r#"{"historyRetentionDays": -1}"#).unwrap();
        assert_eq!(loaded.settings.shortcut, Shortcut::default());
        assert_eq!(loaded.settings.history_retention_days, -1);
        assert!(loaded.settings.start_at_sign_in);
        assert!(!loaded.settings.onboarded);
        assert_eq!(loaded.problem, None);

        let loaded =
            Settings::from_json(r#"{"shortcut": "Shift+A", "historyRetentionDays": null}"#)
                .unwrap();
        assert_eq!(loaded.settings, Settings::default());
        assert!(loaded
            .problem
            .unwrap()
            .contains("\"Shift+A\" can't be a shortcut"));

        let loaded = Settings::from_json(r#"{"shortcut": "F9"}"#).unwrap();
        assert_eq!(loaded.settings.shortcut.to_string(), "F9");
    }

    #[test]
    fn a_broken_file_is_left_alone_and_a_missing_one_is_created() {
        let path = scratch("created");
        let created = Settings::load(&path);
        assert_eq!(created.settings, Settings::default());
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            "{\n  \"historyRetentionDays\": 0,\n  \"onboarded\": false,\n  \"shortcut\": \"Ctrl+Shift+Space\",\n  \"startAtSignIn\": true\n}"
        );

        std::fs::write(&path, "{ not json").unwrap();
        let broken = Settings::load(&path);
        assert_eq!(broken.settings, Settings::default());
        assert!(broken.problem.is_some() && broken.unreadable);
        assert_eq!(
            Settings::update(&path, |s| s.onboarded = true),
            Err(UNREADABLE.to_string())
        );
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "{ not json");
        std::fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[test]
    fn saving_keeps_keys_loqui_does_not_own() {
        let path = scratch("kept");
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, r#"{"shortcut": "F9", "channel": "test"}"#).unwrap();
        let saved = Settings::update(&path, |s| s.start_at_sign_in = false).unwrap();
        assert_eq!(saved.shortcut.to_string(), "F9");
        let text = std::fs::read_to_string(&path).unwrap();
        let value: Value = serde_json::from_str(&text).unwrap();
        assert_eq!(value["channel"], "test");
        assert_eq!(value["startAtSignIn"], false);
        assert_eq!(value["shortcut"], "F9");
        std::fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }
}
