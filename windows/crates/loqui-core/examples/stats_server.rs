//! For the screen tests in a browser: answers the stats window's requests with
//! the real figures from loqui-core, so the browser stand-in has no stats rules
//! of its own. One JSON request per line on stdin, one answer per line on stdout:
//!
//! `{"log": "<dictation-log.jsonl text>", "now": "2026-11-10T14:41:00Z",
//!   "timeZone": "America/New_York", "firstWeekday": 1, "shortcut": "Ctrl+Shift+Space",
//!   "request": {"grain": "day", "offset": 0, "jumpTo": null}}`
//!
//! `firstWeekday` counts as the Mac does: 1 is Sunday.

use chrono::{DateTime, Weekday};
use loqui_core::stats::{stats, StatsRequest};
use serde::Deserialize;
use std::io::{BufRead, Write};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Ask {
    log: String,
    now: String,
    time_zone: String,
    first_weekday: u8,
    shortcut: String,
    request: StatsRequest,
}

fn answer(line: &str) -> Result<String, String> {
    let ask: Ask = serde_json::from_str(line).map_err(|e| e.to_string())?;
    let tz: chrono_tz::Tz = ask.time_zone.parse().map_err(|e| format!("{e}"))?;
    let now = DateTime::parse_from_rfc3339(&ask.now)
        .map_err(|e| e.to_string())?
        .with_timezone(&tz);
    // chrono counts from Monday (0); the Mac from Sunday (1).
    let first_weekday = Some(ask.first_weekday)
        .filter(|n| (1..=7).contains(n))
        .and_then(|n| Weekday::try_from((n + 5) % 7).ok())
        .ok_or("firstWeekday is 1 to 7")?;
    let view = stats(&ask.log, &now, first_weekday, &ask.request, &ask.shortcut);
    serde_json::to_string(&view).map_err(|e| e.to_string())
}

fn main() {
    let mut out = std::io::stdout().lock();
    for line in std::io::stdin().lock().lines() {
        let Ok(line) = line else { break };
        let reply = match answer(&line) {
            Ok(json) => format!("{{\"ok\":{json}}}"),
            Err(e) => serde_json::json!({ "error": e }).to_string(),
        };
        if writeln!(out, "{reply}").and_then(|()| out.flush()).is_err() {
            break;
        }
    }
}
