//! Loqui's rules and files, kept apart from Windows and the screens so they
//! build and test on any computer.
//!
//! The cleanup rules must give exactly what the Mac app gives: both run
//! `shared/cleanup-cases.json`, so a rule that drifts on one side fails there.

mod case_folds;
pub mod cleanup;
pub mod config;
pub mod timed_heal;

pub use cleanup::clean;
pub use config::CleanupConfig;
