//! STAT-07: The Mac and Windows give the same figures.
//!
//! Runs `shared/stats-cases.json`, the same file the Mac's `swift test` runs,
//! and lists each figure group and period by its id. A failure names it.

use chrono::{DateTime, NaiveDate, Weekday};
use libtest_mimic::{Arguments, Failed, Trial};
use loqui_core::stats::{figures, read_log, Figures, Grain};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::sync::Arc;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct File {
    now: String,
    time_zone: String,
    first_weekday: u8,
    log: Vec<String>,
    skipped: usize,
    top: Value,
    last30_days: Value,
    by_month: Value,
    calendar: Value,
    periods: Vec<Value>,
}

/// The Mac's numbering: 1 is Sunday.
fn weekday(n: u8) -> Weekday {
    [
        Weekday::Sun,
        Weekday::Mon,
        Weekday::Tue,
        Weekday::Wed,
        Weekday::Thu,
        Weekday::Fri,
        Weekday::Sat,
    ][usize::from(n - 1)]
}

fn date(d: NaiveDate) -> String {
    d.format("%Y-%m-%d").to_string()
}

/// Each expected field against what Windows gives, all differences at once.
fn compare(expected: &Value, got: &Value) -> Result<(), Failed> {
    let mut wrong = Vec::new();
    for (key, want) in expected.as_object().into_iter().flatten() {
        let have = &got[key];
        if have != want {
            wrong.push(format!("{key}: expected {want}, got {have}"));
        }
    }
    if wrong.is_empty() {
        Ok(())
    } else {
        Err(wrong.join("\n").into())
    }
}

struct Sample {
    file: File,
    tz: chrono_tz::Tz,
    now: DateTime<chrono_tz::Tz>,
}

impl Sample {
    fn figures(&self, grain: Grain, offset: i32, first_weekday: u8) -> Figures {
        let entries = read_log(&self.file.log.join("\n"), &self.tz);
        figures(
            &entries,
            self.now.naive_local(),
            weekday(first_weekday),
            grain,
            offset,
        )
    }

    fn all_time(&self) -> Figures {
        self.figures(Grain::AllTime, 0, self.file.first_weekday)
    }
}

fn top(s: &Sample) -> Result<(), Failed> {
    let f = s.all_time();
    let got = json!({
        "allTimeWords": f.all_time_words, "dictations": f.dictations, "wordsEach": f.words_each,
        "today": f.today, "yesterday": f.yesterday,
        "thisWeek": f.this_week, "lastWeek": f.last_week,
        "thisMonth": f.this_month, "lastMonth": f.last_month,
    });
    compare(&s.file.top, &got)
}

fn last30_days(s: &Sample) -> Result<(), Failed> {
    let f = s.all_time();
    let got = json!({
        "first": date(f.last30_days[0].0),
        "words": f.last30_days.iter().map(|d| d.1).collect::<Vec<_>>(),
    });
    compare(&s.file.last30_days, &got)
}

fn by_month(s: &Sample) -> Result<(), Failed> {
    let f = s.all_time();
    let got = json!({
        "first": f.by_month[0].0.format("%Y-%m").to_string(),
        "words": f.by_month.iter().map(|m| m.1).collect::<Vec<_>>(),
    });
    compare(&s.file.by_month, &got)
}

fn calendar(s: &Sample) -> Result<(), Failed> {
    let f = s.all_time();
    let got = json!({
        "firstDay": f.first_day.map(date),
        "busiestDay": f.busiest_day,
        "busiestMonth": f.busiest_month,
    });
    compare(&s.file.calendar, &got)
}

fn skipped(s: &Sample) -> Result<(), Failed> {
    let read = read_log(&s.file.log.join("\n"), &s.tz).len();
    let skipped = s.file.log.len() - read;
    if skipped == s.file.skipped {
        Ok(())
    } else {
        Err(format!(
            "expected {} damaged lines skipped, got {skipped}",
            s.file.skipped
        )
        .into())
    }
}

fn period(s: &Sample, case: &Value) -> Result<(), Failed> {
    let grain: Grain = serde_json::from_value(case["grain"].clone()).map_err(|e| e.to_string())?;
    let offset = case["offset"].as_i64().ok_or("needs an offset")? as i32;
    let first_weekday = case["firstWeekday"]
        .as_u64()
        .map_or(s.file.first_weekday, |n| n as u8);
    let p = s.figures(grain, offset, first_weekday).period;

    // The Mac picks among equally busy days in no fixed order, so the sample
    // must have one busiest day in every period.
    let entries = read_log(&s.file.log.join("\n"), &s.tz);
    let mut by_day: BTreeMap<NaiveDate, u64> = BTreeMap::new();
    for e in &entries {
        if p.window.is_none_or(|(a, b)| (a..=b).contains(&e.at.date())) {
            *by_day.entry(e.at.date()).or_default() += e.words;
        }
    }
    let busiest = by_day.values().max().copied().unwrap_or(0);
    if busiest > 0 && by_day.values().filter(|&&w| w == busiest).count() > 1 {
        return Err("the sample has two equally busy days in this period".into());
    }

    let mut expected = case.clone();
    for key in ["id", "grain", "offset", "firstWeekday"] {
        expected.as_object_mut().map(|o| o.remove(key));
    }
    let got = json!({
        "label": p.label, "empty": p.empty,
        "byWeekday": p.by_weekday, "byHour": p.by_hour,
        "timeSavedMinutes": p.time_saved_minutes(),
        "paceMeasured": p.pace_measured, "speakingPace": p.speaking_pace,
        "currentStreak": p.current_streak, "longestStreak": p.longest_streak,
        "activeDays": p.active_days, "spanDays": p.span_days,
        "peakHours": p.peak_hours,
        "biggestDay": p.biggest_day.map(|(d, w)| json!({"date": date(d), "words": w})),
        "longestDictation": p.longest_dictation, "perActiveDay": p.per_active_day,
    });
    compare(&expected, &got)
}

fn main() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../shared/stats-cases.json"
    );
    let text = std::fs::read_to_string(path).expect("shared/stats-cases.json is readable");
    let file: File = serde_json::from_str(&text).expect("shared/stats-cases.json is valid");
    let tz: chrono_tz::Tz = file.time_zone.parse().expect("a known time zone");
    let now = DateTime::parse_from_rfc3339(&file.now)
        .expect("now is an ISO time")
        .with_timezone(&tz);
    let sample = Arc::new(Sample { file, tz, now });

    type Check = fn(&Sample) -> Result<(), Failed>;
    let fixed: [(&str, Check); 5] = [
        ("damaged lines are skipped", skipped),
        ("top of the window", top),
        ("last 30 days", last30_days),
        ("by month", by_month),
        ("calendar shading", calendar),
    ];
    let mut trials: Vec<Trial> = fixed
        .into_iter()
        .map(|(id, check)| {
            let s = Arc::clone(&sample);
            Trial::test(id, move || check(&s))
        })
        .collect();
    for case in sample.file.periods.clone() {
        let s = Arc::clone(&sample);
        let id = format!("period: {}", case["id"].as_str().unwrap_or("?"));
        trials.push(Trial::test(id, move || period(&s, &case)));
    }
    libtest_mimic::run(&Arguments::from_args(), trials).exit();
}
