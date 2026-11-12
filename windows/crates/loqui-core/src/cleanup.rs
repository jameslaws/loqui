//! Instant cleanup of a finished transcript (TextCleanup.swift on the Mac):
//! spelling dictionary, filler removal, spoken formatting, spacing and
//! punctuation tidy, a lone "i", sentence healing and capitals. Every rule only
//! makes safe edits, so the output is predictable.
//!
//! The patterns are the Mac's, case-insensitive and Unicode-aware, and must
//! give the same result on every example in `shared/cleanup-cases.json`.

use crate::case_folds::MULTI_CHAR_FOLDS;
use crate::CleanupConfig;
use regex::{Captures, NoExpand, Regex};
use std::sync::LazyLock;

fn pattern(p: &str) -> Regex {
    Regex::new(&format!("(?i){p}")).expect("cleanup patterns are valid")
}

static RUNS_OF_SPACE: LazyLock<Regex> = LazyLock::new(|| pattern(r"[ \t]{2,}"));
static SPACE_BEFORE_PUNCTUATION: LazyLock<Regex> = LazyLock::new(|| pattern(r" +([,.!?;:])"));
static SPACE_BEFORE_NEWLINE: LazyLock<Regex> = LazyLock::new(|| pattern(r"[ \t]+\n"));
static LINE_START_LITTER: LazyLock<Regex> = LazyLock::new(|| pattern(r"(?m)^[ \t,]+"));
static LONE_I: LazyLock<Regex> = LazyLock::new(|| pattern(r"\bi\b"));
static SENTENCE_START: LazyLock<Regex> = LazyLock::new(|| pattern(r"(^|[.!?]\s+|\n+)([a-z])"));

/// Continuation words that open a relative clause, so the join takes a comma.
const COMMA_BEFORE_JOIN: [&str; 3] = ["which", "whose", "whom"];

/// Clean `raw` with the given settings.
pub fn clean(raw: &str, cfg: &CleanupConfig) -> String {
    let mut text = raw.to_string();
    if cfg.spoken_formatting {
        text = replace_word(&text, "new paragraph", "\n\n");
        text = replace_word(&text, "new line", "\n");
    }
    if cfg.remove_fillers && !cfg.fillers.is_empty() {
        text = remove_fillers(&text, &cfg.fillers);
    }
    // Longest phrases first so they win over their fragments. Equal lengths go
    // in alphabetical order so the result never depends on map order.
    let mut entries: Vec<_> = cfg.dictionary.iter().collect();
    entries.sort_by(|a, b| {
        b.0.chars()
            .count()
            .cmp(&a.0.chars().count())
            .then(a.0.cmp(b.0))
    });
    for (key, value) in entries {
        text = replace_word(&text, key, value);
    }
    text = tidy(&text);
    text = LONE_I.replace_all(&text, "I").into_owned();
    if cfg.heal_sentence_splits {
        text = heal_sentence_splits(&text, &cfg.continuation_words);
    }
    text = capitalize_sentences(&text);
    text.trim().to_string()
}

/// Whole-word, any-case replacement; the replacement is used literally.
fn replace_word(text: &str, phrase: &str, replacement: &str) -> String {
    let re = pattern(&format!(r"\b{}\b", any_case(phrase)));
    re.replace_all(text, NoExpand(replacement)).into_owned()
}

fn alternation(words: &[String]) -> String {
    words
        .iter()
        .map(|w| any_case(w))
        .collect::<Vec<_>>()
        .join("|")
}

/// A pattern for `phrase` in any case, the way the Mac matches it. The Mac's
/// matching uses full case folding, so "strasse" also finds "straße" and
/// "office" finds "oﬃce"; Rust's `(?i)` only folds one character to one
/// character. So the phrase is folded first, and wherever the folded text could
/// have come from a single character (ss from ß, ffi from ﬃ), that character
/// is allowed too.
fn any_case(phrase: &str) -> String {
    let folded: Vec<char> = phrase
        .chars()
        .flat_map(
            |c| match MULTI_CHAR_FOLDS.iter().find(|(from, _)| *from == c) {
                Some((_, to)) => to.chars().collect::<Vec<_>>(),
                None => c.to_lowercase().collect(),
            },
        )
        .collect();
    let mut out = String::new();
    let mut i = 0;
    while i < folded.len() {
        // The longest folded run starting here that a single character folds to.
        let longest = MULTI_CHAR_FOLDS
            .iter()
            .map(|(_, to)| to.chars().count())
            .filter(|&len| {
                let run: String = folded[i..].iter().take(len).collect();
                run.chars().count() == len && MULTI_CHAR_FOLDS.iter().any(|(_, to)| *to == run)
            })
            .max();
        match longest {
            Some(len) => {
                let run: String = folded[i..i + len].iter().collect();
                let mut choices = vec![regex::escape(&run)];
                choices.extend(
                    MULTI_CHAR_FOLDS
                        .iter()
                        .filter(|(_, to)| *to == run)
                        .map(|(from, _)| regex::escape(&from.to_string())),
                );
                out.push_str(&format!("(?:{})", choices.join("|")));
                i += len;
            }
            None => {
                out.push_str(&regex::escape(&folded[i].to_string()));
                i += 1;
            }
        }
    }
    out
}

fn remove_fillers(text: &str, fillers: &[String]) -> String {
    let re = pattern(&format!(r"\b(?:{})\b,?", alternation(fillers)));
    re.replace_all(text, "").into_owned()
}

/// Collapse runs of spaces, drop space before punctuation and before a line
/// break, and strip spaces and commas left at the start of a line.
fn tidy(text: &str) -> String {
    let t = RUNS_OF_SPACE.replace_all(text, " ");
    let t = SPACE_BEFORE_PUNCTUATION.replace_all(&t, "${1}");
    let t = SPACE_BEFORE_NEWLINE.replace_all(&t, "\n");
    LINE_START_LITTER.replace_all(&t, "").into_owned()
}

/// A period in front of a word that essentially never opens a sentence is a
/// pause the recognizer read as a full stop: drop it. A line break is a
/// deliberate break, so only a period followed by spaces on the same line counts.
fn heal_sentence_splits(text: &str, words: &[String]) -> String {
    let words: Vec<String> = words
        .iter()
        .filter(|w| !w.trim().is_empty())
        .cloned()
        .collect();
    if words.is_empty() {
        return text.to_string();
    }
    let re = pattern(&format!(r"\.[ \t]+({})\b", alternation(&words)));
    re.replace_all(text, |caps: &Captures| {
        let word = caps[1].to_lowercase();
        let joiner = if COMMA_BEFORE_JOIN.contains(&word.as_str()) {
            ", "
        } else {
            " "
        };
        format!("{joiner}{word}")
    })
    .into_owned()
}

/// Capitalize the first letter of the text and of each sentence.
fn capitalize_sentences(text: &str) -> String {
    SENTENCE_START
        .replace_all(text, |caps: &Captures| {
            format!("{}{}", &caps[1], caps[2].to_uppercase())
        })
        .into_owned()
}
