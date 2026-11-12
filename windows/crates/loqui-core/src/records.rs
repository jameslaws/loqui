//! loqui's files on Windows, all under `%LOCALAPPDATA%\Loqui` (never the
//! roaming profile), in the Mac app's formats so steps 3 and 4 can read them:
//!
//! - `history.jsonl`: one line per dictation, `{"at": ISO time, "text": cleaned text}`
//!   (TranscriptionHistory.swift), kept as the retention setting says.
//! - `dictation-log.jsonl`: `{"at", "words", "seconds"}` and never the text
//!   (DictationLog.swift), for stats.
//! - `logs\voice-key.log`: what happened, never what was said.
//! - `logs\cleanup.log`: what cleanup changed (CleanupAudit.swift), capped at 2 MB.

use serde::{Deserialize, Serialize};
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};

/// `%LOCALAPPDATA%\Loqui`.
pub fn data_dir() -> Option<PathBuf> {
    let base = std::env::var_os("LOCALAPPDATA")?;
    Some(Path::new(&base).join("Loqui"))
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub at: String,
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DictationEntry {
    pub at: String,
    pub words: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub seconds: Option<f64>,
}

/// The longest dictation that keeps its duration: the 30-minute ceiling.
const MAX_SECONDS: f64 = 1800.0;
/// The cleanup log keeps its newest half once it passes this size.
const AUDIT_LIMIT: usize = 2_000_000;
const DAY: i64 = 86_400;

/// One folder of loqui files. Tests point it anywhere.
#[derive(Debug, Clone)]
pub struct Records {
    dir: PathBuf,
}

impl Records {
    pub fn new(dir: impl Into<PathBuf>) -> Self {
        Self { dir: dir.into() }
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }

    pub fn history_path(&self) -> PathBuf {
        self.dir.join("history.jsonl")
    }

    pub fn stats_path(&self) -> PathBuf {
        self.dir.join("dictation-log.jsonl")
    }

    pub fn voice_key_log_path(&self) -> PathBuf {
        self.dir.join("logs").join("voice-key.log")
    }

    pub fn cleanup_log_path(&self) -> PathBuf {
        self.dir.join("logs").join("cleanup.log")
    }

    /// Save a dictation's cleaned text, unless history is off (-1).
    pub fn record_history(&self, text: &str, now: i64, retention_days: i64) -> std::io::Result<()> {
        let text = text.trim();
        if retention_days < 0 || text.is_empty() {
            return Ok(());
        }
        let entry = HistoryEntry {
            at: iso8601(now),
            text: text.to_string(),
        };
        append_line(&self.history_path(), &json_line(&entry))
    }

    /// Count a dictation for stats: words and how long the mic was live.
    /// Sub-second and runaway durations are left out, as on the Mac.
    pub fn record_stats(
        &self,
        words: usize,
        seconds: Option<f64>,
        now: i64,
    ) -> std::io::Result<()> {
        if words == 0 {
            return Ok(());
        }
        let seconds = seconds.filter(|s| (1.0..MAX_SECONDS + 1.0).contains(s));
        let entry = DictationEntry {
            at: iso8601(now),
            words,
            seconds,
        };
        append_line(&self.stats_path(), &json_line(&entry))
    }

    /// Drop history older than the retention window. Nothing to do for
    /// forever (0) or off (-1). Lines that don't parse are kept.
    pub fn prune_history(&self, now: i64, retention_days: i64) -> std::io::Result<()> {
        if retention_days <= 0 {
            return Ok(());
        }
        let path = self.history_path();
        let Ok(content) = fs::read_to_string(&path) else {
            return Ok(());
        };
        let cutoff = now - retention_days * DAY;
        let kept: Vec<&str> = content
            .lines()
            .filter(|line| {
                serde_json::from_str::<HistoryEntry>(line)
                    .ok()
                    .and_then(|e| parse_iso8601(&e.at))
                    .is_none_or(|at| at >= cutoff)
            })
            .collect();
        if kept.len() == content.lines().count() {
            return Ok(());
        }
        let body: String = kept.iter().map(|l| format!("{l}\n")).collect();
        fs::write(path, body)
    }

    /// A line in the voice key log. Callers never pass what was said.
    pub fn log(&self, message: &str, now: i64) {
        let _ = append_capped(
            &self.voice_key_log_path(),
            &format!("{}  {message}\n", iso8601(now)),
        );
    }

    /// Both versions of a dictation, only when cleanup changed something.
    pub fn audit_diff(&self, raw: &str, cleaned: &str, now: i64) {
        if raw == cleaned {
            return;
        }
        let entry = format!(
            "── {}\nRAW:     {raw}\nCLEANED: {cleaned}\n\n",
            iso8601(now)
        );
        let _ = append_capped(&self.cleanup_log_path(), &entry);
    }

    /// One sentence boundary and the pause in front of it.
    pub fn audit_boundary(&self, gap: f64, word: &str, healed: bool) {
        let mark = if healed { "  → HEALED" } else { "" };
        let line = format!("   gap {gap:.2}s before \"{word}\"{mark}\n");
        let _ = append_capped(&self.cleanup_log_path(), &line);
    }
}

fn json_line<T: Serialize>(value: &T) -> String {
    serde_json::to_string(value).expect("records always serialize") + "\n"
}

fn append_line(path: &Path, line: &str) -> std::io::Result<()> {
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir)?;
    }
    OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)?
        .write_all(line.as_bytes())
}

/// Append, then keep only the newest half once the file passes 2 MB, starting
/// at a record boundary so the file never opens mid-entry.
fn append_capped(path: &Path, text: &str) -> std::io::Result<()> {
    append_line(path, text)?;
    if fs::metadata(path)?.len() <= AUDIT_LIMIT as u64 {
        return Ok(());
    }
    let content = fs::read_to_string(path)?;
    let mut start = content.len() - AUDIT_LIMIT / 2;
    while !content.is_char_boundary(start) {
        start += 1;
    }
    let tail = &content[start..];
    let tidy = tail.find("── ").map_or(tail, |i| &tail[i..]);
    fs::write(path, tidy)
}

/// Seconds since 1970 as `2026-11-12T14:03:22Z`, the way the Mac's
/// `JSONEncoder` writes dates.
pub fn iso8601(unix: i64) -> String {
    let (days, secs) = (unix.div_euclid(DAY), unix.rem_euclid(DAY));
    let (y, m, d) = civil_from_days(days);
    format!(
        "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        secs / 3600,
        secs % 3600 / 60,
        secs % 60
    )
}

/// Reads `2026-11-12T14:03:22Z`, with optional fractional seconds and a
/// `+hh:mm` offset in place of `Z`.
pub fn parse_iso8601(text: &str) -> Option<i64> {
    let b = text.as_bytes();
    let num = |r: std::ops::Range<usize>| -> Option<i64> { text.get(r)?.parse().ok() };
    if b.len() < 20
        || b[4] != b'-'
        || b[7] != b'-'
        || b[10] != b'T'
        || b[13] != b':'
        || b[16] != b':'
    {
        return None;
    }
    let (y, mo, d, h, mi, s) = (
        num(0..4)?,
        num(5..7)?,
        num(8..10)?,
        num(11..13)?,
        num(14..16)?,
        num(17..19)?,
    );
    let mut rest = &text[19..];
    if let Some(frac) = rest.strip_prefix('.') {
        rest = frac.trim_start_matches(|c: char| c.is_ascii_digit());
    }
    let offset = match rest.as_bytes() {
        [b'Z'] => 0,
        [sign @ (b'+' | b'-'), ..] if rest.len() == 6 && &rest[3..4] == ":" => {
            let minutes = rest[1..3].parse::<i64>().ok()? * 60 + rest[4..6].parse::<i64>().ok()?;
            if *sign == b'+' {
                minutes * 60
            } else {
                -minutes * 60
            }
        }
        _ => return None,
    };
    let valid = (1..=12).contains(&mo) && (1..=31).contains(&d) && h < 24 && mi < 60 && s < 61;
    valid.then(|| days_from_civil(y, mo, d) * DAY + h * 3600 + mi * 60 + s - offset)
}

// Howard Hinnant's calendar algorithms (public domain).
fn civil_from_days(z: i64) -> (i64, i64, i64) {
    let z = z + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    (yoe + era * 400 + i64::from(m <= 2), m, d)
}

fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y.rem_euclid(400);
    let mp = if m > 2 { m - 3 } else { m + 9 };
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dates_round_trip_like_the_macs() {
        // 2026-11-12 14:03:22 UTC
        let t = 1_794_492_202;
        assert_eq!(iso8601(t), "2026-11-12T14:03:22Z");
        assert_eq!(parse_iso8601("2026-11-12T14:03:22Z"), Some(t));
        assert_eq!(parse_iso8601("2026-11-12T14:03:22.250Z"), Some(t));
        assert_eq!(parse_iso8601("2026-11-12T09:03:22-05:00"), Some(t));
        assert_eq!(iso8601(0), "1970-01-01T00:00:00Z");
        assert_eq!(iso8601(951_782_400), "2000-02-29T00:00:00Z");
        assert_eq!(parse_iso8601("2026-13-12T14:03:22Z"), None);
        assert_eq!(parse_iso8601("yesterday"), None);
    }
}
