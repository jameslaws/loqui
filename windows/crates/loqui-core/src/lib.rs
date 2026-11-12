//! Loqui's rules and files, kept apart from Windows and the screens so they
//! build and test on any computer.
//!
//! The cleanup rules must give exactly what the Mac app gives: both run
//! `shared/cleanup-cases.json`, so a rule that drifts on one side fails there.

mod case_folds;
pub mod cleanup;
pub mod commands;
pub mod config;
pub mod dictation;
pub mod records;
pub mod settings;
pub mod shortcut;
pub mod stats;
pub mod timed_heal;
pub mod voice_key;

pub use cleanup::clean;
pub use config::CleanupConfig;
pub use settings::Settings;
pub use shortcut::{Mods, Shortcut};
