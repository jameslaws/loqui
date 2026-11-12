//! The timed half of sentence healing (TimedHeal.swift on the Mac).
//!
//! When a finished segment arrives after text that ends in a period, the pause
//! between them decides whether that period was a real full stop or a
//! hesitation the recognizer read as one. Only `timed_heal_words` qualify, and
//! only when a gap was measured and it is no longer than `max_pause_seconds`.

use crate::CleanupConfig;
use regex::Regex;
use std::sync::LazyLock;

/// A sentence boundary and the pause in front of it, for the cleanup log.
#[derive(Debug, Clone, PartialEq)]
pub struct Boundary {
    pub gap: f64,
    pub word: String,
    pub healed: bool,
}

static EDGE_PUNCTUATION: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^\p{P}+|\p{P}+$").expect("valid pattern"));

/// The banked text after adding `segment`, plus the boundary it crossed when
/// a gap was measured across a period.
pub fn bank(
    segment: &str,
    finalized: &str,
    gap: Option<f64>,
    cfg: &CleanupConfig,
) -> (String, Option<Boundary>) {
    let trimmed = segment.trim();
    if trimmed.is_empty() {
        return (finalized.to_string(), None);
    }
    if finalized.is_empty() || !finalized.ends_with('.') {
        return (append(trimmed, finalized), None);
    }

    let first = trimmed.split(char::is_whitespace).next().unwrap_or("");
    let word = EDGE_PUNCTUATION
        .replace_all(&first.to_lowercase(), "")
        .into_owned();
    let eligible = cfg.heal_sentence_splits
        && cfg.timed_heal_words.contains(&word)
        && gap.is_some_and(|g| g <= cfg.max_pause_seconds);
    let boundary = gap.map(|gap| Boundary {
        gap,
        word,
        healed: eligible,
    });

    if !eligible {
        return (append(trimmed, finalized), boundary);
    }
    // Drop the period the pause caused and carry on mid-sentence.
    let kept = &finalized[..finalized.len() - 1];
    (format!("{kept} {}", lowercase_first(trimmed)), boundary)
}

fn append(trimmed: &str, finalized: &str) -> String {
    if finalized.is_empty() {
        trimmed.to_string()
    } else {
        format!("{finalized} {trimmed}")
    }
}

fn lowercase_first(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        Some(f) => f.to_lowercase().chain(chars).collect(),
        None => String::new(),
    }
}
