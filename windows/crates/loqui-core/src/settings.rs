//! `%LOCALAPPDATA%\Loqui\settings.json`: the Windows app's own settings.
//! Step 2 creates it with the shortcut and how long history is kept; step 3
//! adds fields and the screens. Read as forgivingly as `cleanup.json`: missing
//! keys take their defaults, and a file that won't parse is left untouched (so
//! a typo can be fixed) while the defaults are used.

use crate::shortcut::Shortcut;
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct Settings {
    pub shortcut: Shortcut,
    /// The Mac's meanings: -1 keeps no history, 0 keeps it forever, N keeps N days.
    pub history_retention_days: i64,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Stored {
    shortcut: Option<String>,
    history_retention_days: Option<i64>,
}

/// Settings as read, plus a line for the log when something fell back to a default.
#[derive(Debug, Clone, PartialEq)]
pub struct Loaded {
    pub settings: Settings,
    pub problem: Option<String>,
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
            },
            problem,
        })
    }

    pub fn to_json(&self) -> String {
        let stored = Stored {
            shortcut: Some(self.shortcut.to_string()),
            history_retention_days: Some(self.history_retention_days),
        };
        serde_json::to_string_pretty(&stored).expect("settings always serialize")
    }

    /// Load from `path`, creating it with the defaults if it's missing.
    pub fn load(path: &Path) -> Loaded {
        let fallback = |problem: String| Loaded {
            settings: Self::default(),
            problem: Some(problem),
        };
        match std::fs::read_to_string(path) {
            Ok(text) => Self::from_json(&text).unwrap_or_else(|e| {
                fallback(format!("settings.json can't be read ({e}); using the defaults and leaving the file as it is"))
            }),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                let defaults = Self::default();
                let saved = path
                    .parent()
                    .map_or(Ok(()), std::fs::create_dir_all)
                    .and_then(|()| std::fs::write(path, defaults.to_json()));
                Loaded {
                    settings: defaults,
                    problem: saved.err().map(|e| format!("couldn't create settings.json: {e}")),
                }
            }
            Err(e) => fallback(format!("settings.json can't be opened ({e}); using the defaults")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_keys_take_defaults_and_a_bad_shortcut_is_explained() {
        let loaded = Settings::from_json(r#"{"historyRetentionDays": -1}"#).unwrap();
        assert_eq!(loaded.settings.shortcut, Shortcut::default());
        assert_eq!(loaded.settings.history_retention_days, -1);
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
        let dir = std::env::temp_dir().join(format!("loqui-settings-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let path = dir.join("settings.json");

        let created = Settings::load(&path);
        assert_eq!(created.settings, Settings::default());
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            "{\n  \"shortcut\": \"Ctrl+Shift+Space\",\n  \"historyRetentionDays\": 0\n}"
        );

        std::fs::write(&path, "{ not json").unwrap();
        let broken = Settings::load(&path);
        assert_eq!(broken.settings, Settings::default());
        assert!(broken.problem.is_some());
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "{ not json");
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
