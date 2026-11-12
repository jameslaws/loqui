//! Dictation stats: every figure and every line of text the stats window
//! shows, worked out from the dictation record (`dictation-log.jsonl`) the way
//! the Mac's `StatsModel` does. The window only draws what this returns.
//!
//! `shared/stats-cases.json` holds a sample record and the figures both apps
//! must give for it, so the Mac and Windows can't drift apart.
//!
//! All of it is counted in the PC's own time: a dictation at 11:30 PM belongs
//! to that day, wherever the clocks change.

use crate::records::{parse_iso8601, DictationEntry};
use chrono::{
    DateTime, Datelike, Days, Months, NaiveDate, NaiveDateTime, TimeZone, Timelike, Weekday,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use ts_rs::TS;

/// Typing speed "time saved" is measured against: a sustained rate for an
/// average adult, kept low so the figure never feels inflated.
pub const TYPING_WPM: f64 = 40.0;
/// A typical speaking rate, used for old entries with no duration until
/// there's a measured pace.
const ASSUMED_PACE: f64 = 150.0;

const MONTHS: [&str; 12] = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
];
const WEEKDAYS: [&str; 7] = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
];

/// How much time the Patterns section covers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub enum Grain {
    AllTime,
    Year,
    Month,
    Week,
    Day,
}

/// Which period the screen wants: `offset` 0 is the current one, -1 the one
/// before it. `jumpTo` (a day, `2026-10-27`) picks the period holding that day
/// instead, as the calendar does.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct StatsRequest {
    pub grain: Grain,
    pub offset: i32,
    pub jump_to: Option<String>,
}

/// Everything the stats window shows.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct Stats {
    /// No dictations at all: the window says how to start instead.
    pub empty: bool,
    /// The dictation shortcut, for the empty window.
    pub shortcut: String,
    /// "51,104 words all-time · 687 dictations · 74 words each".
    pub summary: String,
    /// Today, This week, This month.
    pub cards: Vec<Card>,
    pub last30_days: Vec<Bar>,
    /// The last 12 months, this one last.
    pub by_month: Vec<Bar>,
    pub period: Period,
    pub calendar: Calendar,
}

/// One of the three cards at the top.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct Card {
    pub title: String,
    pub value: String,
    /// "1,997 last week · ▼ 65%".
    pub compare: String,
    /// Level with or ahead of the period before.
    pub up: bool,
}

/// One bar in a chart.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
pub struct Bar {
    /// What the bar is, in full: "Oct 27", "September 2026", "Monday", "9–10 AM".
    pub label: String,
    /// The same, short enough for the axis: "Oct 27", "Sep 2026", "Mon", "9a".
    pub tick: String,
    pub words: u32,
}

/// The Patterns section: the period chosen and its figures.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct Period {
    pub grain: Grain,
    pub offset: i32,
    /// The period spelled out as the Mac does: "July 2026", "Aug 2 – 8", "Yesterday".
    pub label: String,
    /// First and last day of the period (`2026-10-25`), or none for all time.
    pub first: Option<String>,
    pub last: Option<String>,
    /// Said in place of the tiles when the period has no dictations.
    pub empty_text: Option<String>,
    /// Sunday first.
    pub by_weekday: Vec<Bar>,
    /// Midnight first.
    pub by_hour: Vec<Bar>,
    pub tiles: Vec<Tile>,
}

/// One of the eight tiles under the charts.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
pub struct Tile {
    pub title: String,
    pub value: String,
    pub detail: Option<String>,
}

/// What the calendar picker shades and allows.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct Calendar {
    pub today: String,
    /// The first day with a dictation: nothing before it can be picked.
    pub first_day: Option<String>,
    /// 0 is Sunday: the calendar's first column.
    pub first_weekday: u8,
    /// Every day with dictations.
    pub days: Vec<DayWords>,
    /// Every month with dictations (`2026-10`).
    pub months: Vec<DayWords>,
    /// Shading is against the busiest day and month ever.
    pub busiest_day: u32,
    pub busiest_month: u32,
    /// From this year back to the first dictation's.
    pub years: Vec<YearWords>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
pub struct DayWords {
    pub date: String,
    pub words: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
pub struct YearWords {
    pub year: i32,
    pub words: u32,
}

/// One dictation, in the PC's own time.
#[derive(Debug, Clone, PartialEq)]
pub struct Entry {
    pub at: NaiveDateTime,
    pub words: u64,
    pub seconds: Option<f64>,
}

/// Read the dictation record into local time. Lines that don't read are skipped.
pub fn read_log<Tz: TimeZone>(content: &str, tz: &Tz) -> Vec<Entry> {
    content
        .lines()
        .filter_map(|line| {
            let e: DictationEntry = serde_json::from_str(line).ok()?;
            let unix = parse_iso8601(&e.at)?;
            let at = tz.timestamp_opt(unix, 0).single()?.naive_local();
            Some(Entry {
                at,
                words: e.words as u64,
                seconds: e.seconds,
            })
        })
        .collect()
}

/// Every figure, before it becomes text: what both apps must agree on.
#[derive(Debug, Clone, PartialEq)]
pub struct Figures {
    pub all_time_words: u64,
    pub dictations: u64,
    pub words_each: u64,
    pub today: u64,
    pub yesterday: u64,
    pub this_week: u64,
    pub last_week: u64,
    pub this_month: u64,
    pub last_month: u64,
    pub last30_days: Vec<(NaiveDate, u64)>,
    /// Keyed by the month's first day.
    pub by_month: Vec<(NaiveDate, u64)>,
    pub day_volume: BTreeMap<NaiveDate, u64>,
    pub month_volume: BTreeMap<NaiveDate, u64>,
    pub busiest_day: u64,
    pub busiest_month: u64,
    pub first_day: Option<NaiveDate>,
    pub today_date: NaiveDate,
    pub period: PeriodFigures,
}

/// The Patterns figures for the chosen period.
#[derive(Debug, Clone, PartialEq)]
pub struct PeriodFigures {
    pub grain: Grain,
    pub offset: i32,
    /// First and last day.
    pub window: Option<(NaiveDate, NaiveDate)>,
    pub label: String,
    pub empty: bool,
    /// Sunday first.
    pub by_weekday: [u64; 7],
    pub by_hour: [u64; 24],
    /// The busiest day; the earliest of equals.
    pub biggest_day: Option<(NaiveDate, u64)>,
    pub peak_hours: String,
    pub current_streak: u64,
    pub longest_streak: u64,
    pub active_days: u64,
    pub span_days: i64,
    pub longest_dictation: u64,
    pub per_active_day: u64,
    /// Seconds.
    pub time_saved: f64,
    pub speaking_pace: u64,
    pub pace_measured: bool,
}

impl PeriodFigures {
    pub fn time_saved_minutes(&self) -> u64 {
        (self.time_saved / 60.0) as u64
    }
}

fn day_after(d: NaiveDate) -> NaiveDate {
    d.checked_add_days(Days::new(1)).unwrap_or(d)
}

fn days_before(d: NaiveDate, n: u64) -> NaiveDate {
    d.checked_sub_days(Days::new(n)).unwrap_or(d)
}

fn month_start(d: NaiveDate) -> NaiveDate {
    d.with_day(1).unwrap_or(d)
}

fn add_months(d: NaiveDate, n: i32) -> NaiveDate {
    let shifted = if n >= 0 {
        d.checked_add_months(Months::new(n.unsigned_abs()))
    } else {
        d.checked_sub_months(Months::new(n.unsigned_abs()))
    };
    shifted.unwrap_or(d)
}

fn add_days(d: NaiveDate, n: i64) -> NaiveDate {
    let shifted = if n >= 0 {
        d.checked_add_days(Days::new(n.unsigned_abs()))
    } else {
        d.checked_sub_days(Days::new(n.unsigned_abs()))
    };
    shifted.unwrap_or(d)
}

/// The first day of the week holding `d`.
pub fn week_start(d: NaiveDate, first_weekday: Weekday) -> NaiveDate {
    let back = (d.weekday().num_days_from_sunday() + 7 - first_weekday.num_days_from_sunday()) % 7;
    days_before(d, u64::from(back))
}

/// The first and last day of the period `offset` steps from the one holding `today`.
fn window(
    grain: Grain,
    offset: i32,
    today: NaiveDate,
    first_weekday: Weekday,
) -> Option<(NaiveDate, NaiveDate)> {
    let (start, next) = match grain {
        Grain::AllTime => return None,
        Grain::Day => {
            let d = add_days(today, i64::from(offset));
            (d, day_after(d))
        }
        Grain::Week => {
            let s = add_days(week_start(today, first_weekday), 7 * i64::from(offset));
            (s, add_days(s, 7))
        }
        Grain::Month => {
            let s = add_months(month_start(today), offset);
            (s, add_months(s, 1))
        }
        Grain::Year => {
            let s = NaiveDate::from_ymd_opt(today.year() + offset, 1, 1)?;
            (s, NaiveDate::from_ymd_opt(s.year() + 1, 1, 1)?)
        }
    };
    Some((start, days_before(next, 1)))
}

/// How many steps back the period holding `day` is (never ahead of now).
pub fn offset_of(grain: Grain, day: NaiveDate, today: NaiveDate, first_weekday: Weekday) -> i32 {
    let months = |d: NaiveDate| d.year() * 12 + d.month0() as i32;
    let steps = match grain {
        Grain::AllTime => 0,
        Grain::Day => (day - today).num_days() as i32,
        Grain::Week => {
            ((week_start(day, first_weekday) - week_start(today, first_weekday)).num_days() / 7)
                as i32
        }
        Grain::Month => months(day) - months(today),
        Grain::Year => day.year() - today.year(),
    };
    steps.min(0)
}

fn short_month(d: NaiveDate) -> &'static str {
    &MONTHS[d.month0() as usize][..3]
}

/// "Oct 27".
fn day_label(d: NaiveDate) -> String {
    format!("{} {}", short_month(d), d.day())
}

/// "Oct 27, 2026".
pub fn long_day_label(d: NaiveDate) -> String {
    format!("{}, {}", day_label(d), d.year())
}

/// "September 2026".
fn month_label(d: NaiveDate) -> String {
    format!("{} {}", MONTHS[d.month0() as usize], d.year())
}

/// Names the period the way a person would: "July 2026", "Aug 2 – 8",
/// "Jul 28 – Aug 3", "Yesterday". Weeks say the month once when both ends share it.
fn period_label(grain: Grain, window: Option<(NaiveDate, NaiveDate)>, today: NaiveDate) -> String {
    let Some((start, last)) = window else {
        return "All time".into();
    };
    match grain {
        Grain::AllTime => "All time".into(),
        Grain::Year => start.year().to_string(),
        Grain::Month => month_label(start),
        Grain::Week => {
            let to = if (start.year(), start.month()) == (last.year(), last.month()) {
                last.day().to_string()
            } else {
                day_label(last)
            };
            format!("{} – {to}", day_label(start))
        }
        Grain::Day if start == today => "Today".into(),
        Grain::Day if start == days_before(today, 1) => "Yesterday".into(),
        Grain::Day => long_day_label(start),
    }
}

/// "7–10 AM", "9 AM–12 PM", "10 PM–1 AM": one AM or PM when both ends share it.
pub fn hour_range(from: u32, to: u32) -> String {
    let parts = |h: u32| {
        let h = h % 24;
        let twelve = if h.is_multiple_of(12) { 12 } else { h % 12 };
        (twelve, if h < 12 { "AM" } else { "PM" })
    };
    let ((a, a_mer), (b, b_mer)) = (parts(from), parts(to));
    if a_mer == b_mer {
        format!("{a}–{b} {a_mer}")
    } else {
        format!("{a} {a_mer}–{b} {b_mer}")
    }
}

/// Work out every figure for `now` (the PC's local time) and the chosen period.
pub fn figures(
    entries: &[Entry],
    now: NaiveDateTime,
    first_weekday: Weekday,
    grain: Grain,
    offset: i32,
) -> Figures {
    let today = now.date();
    let offset = offset.min(0);
    let sum = |from: NaiveDate, to: NaiveDate| -> u64 {
        entries
            .iter()
            .filter(|e| (from..=to).contains(&e.at.date()))
            .map(|e| e.words)
            .sum()
    };
    let all_time_words: u64 = entries.iter().map(|e| e.words).sum();
    let dictations = entries.len() as u64;

    let yesterday = days_before(today, 1);
    let week = week_start(today, first_weekday);
    let last_week_start = days_before(week, 7);
    let month = month_start(today);
    let last_month_start = add_months(month, -1);

    let mut day_volume: BTreeMap<NaiveDate, u64> = BTreeMap::new();
    let mut month_volume: BTreeMap<NaiveDate, u64> = BTreeMap::new();
    for e in entries {
        *day_volume.entry(e.at.date()).or_default() += e.words;
        *month_volume.entry(month_start(e.at.date())).or_default() += e.words;
    }
    let last30_days = (0..30)
        .rev()
        .map(|i| {
            let d = days_before(today, i);
            (d, day_volume.get(&d).copied().unwrap_or(0))
        })
        .collect();
    let by_month = (0..12)
        .rev()
        .map(|i| {
            let m = add_months(month, -i);
            (m, month_volume.get(&m).copied().unwrap_or(0))
        })
        .collect();

    Figures {
        all_time_words,
        dictations,
        words_each: all_time_words.checked_div(dictations).unwrap_or(0),
        today: sum(today, today),
        yesterday: sum(yesterday, yesterday),
        this_week: sum(week, add_days(week, 6)),
        last_week: sum(last_week_start, days_before(week, 1)),
        this_month: sum(month, days_before(add_months(month, 1), 1)),
        last_month: sum(last_month_start, days_before(month, 1)),
        last30_days,
        by_month,
        busiest_day: day_volume.values().copied().max().unwrap_or(0),
        busiest_month: month_volume.values().copied().max().unwrap_or(0),
        first_day: day_volume.keys().next().copied(),
        day_volume,
        month_volume,
        today_date: today,
        period: period_figures(entries, today, first_weekday, grain, offset),
    }
}

fn period_figures(
    entries: &[Entry],
    today: NaiveDate,
    first_weekday: Weekday,
    grain: Grain,
    offset: i32,
) -> PeriodFigures {
    let window = window(grain, offset, today, first_weekday);
    let scoped: Vec<&Entry> = entries
        .iter()
        .filter(|e| window.is_none_or(|(from, to)| (from..=to).contains(&e.at.date())))
        .collect();

    let mut by_day: BTreeMap<NaiveDate, u64> = BTreeMap::new();
    let mut by_weekday = [0; 7];
    let mut by_hour = [0; 24];
    for e in &scoped {
        *by_day.entry(e.at.date()).or_default() += e.words;
        by_weekday[e.at.weekday().num_days_from_sunday() as usize] += e.words;
        by_hour[e.at.hour() as usize] += e.words;
    }
    let scoped_words: u64 = scoped.iter().map(|e| e.words).sum();

    // The busiest three hours in a row, wrapping past midnight so a late habit
    // reads "10 PM–1 AM".
    let (mut peak_start, mut peak_sum) = (0, None);
    for start in 0..24 {
        let s: u64 = (0..3).map(|i| by_hour[(start + i) % 24]).sum();
        if peak_sum.is_none_or(|best| s > best) {
            (peak_start, peak_sum) = (start, Some(s));
        }
    }
    let peak_hours = match peak_sum {
        Some(s) if s > 0 => hour_range(peak_start as u32, peak_start as u32 + 3),
        _ => "—".into(),
    };

    let mut biggest_day: Option<(NaiveDate, u64)> = None;
    for (&d, &w) in &by_day {
        if biggest_day.is_none_or(|(_, best)| w > best) {
            biggest_day = Some((d, w));
        }
    }

    // A streak isn't broken just because you haven't dictated yet today.
    let mut current_streak = 0;
    if !by_day.is_empty() {
        let mut probe = if by_day.contains_key(&today) {
            today
        } else {
            days_before(today, 1)
        };
        while by_day.contains_key(&probe) {
            current_streak += 1;
            probe = days_before(probe, 1);
        }
    }
    let (mut longest_streak, mut run, mut previous) = (0, 0, None);
    for &d in by_day.keys() {
        run = if previous.is_some_and(|p| day_after(p) == d) {
            run + 1
        } else {
            1
        };
        longest_streak = longest_streak.max(run);
        previous = Some(d);
    }

    // Days you dictated, over the days you could have: never before your first
    // dictation, never past today.
    let first_ever = entries.iter().map(|e| e.at.date()).min().unwrap_or(today);
    let from = window.map_or(first_ever, |(s, _)| s).max(first_ever);
    let to = window.map_or(today, |(_, l)| l).min(today);
    let span_days = ((to - from).num_days() + 1).max(1);
    let active_days = by_day.len() as u64;

    let (mut timed_words, mut timed_secs) = (0, 0.0);
    for e in &scoped {
        if let Some(s) = e.seconds {
            timed_words += e.words;
            timed_secs += s;
        }
    }
    let pace_measured = timed_secs > 0.0;
    let speaking_pace = if pace_measured {
        (timed_words as f64 / (timed_secs / 60.0)).round() as u64
    } else {
        0
    };
    // Entries from before durations were kept are filled in at the measured
    // pace, or a typical one until there is one: hence the "≈".
    let assumed = if pace_measured {
        speaking_pace as f64
    } else {
        ASSUMED_PACE
    };
    let spoken = scoped.iter().fold(0.0, |total, e| {
        total + e.seconds.unwrap_or(e.words as f64 / assumed * 60.0)
    });
    let time_saved = (scoped_words as f64 / TYPING_WPM * 60.0 - spoken).max(0.0);

    PeriodFigures {
        grain,
        offset,
        window,
        label: period_label(grain, window, today),
        empty: scoped.is_empty(),
        by_weekday,
        by_hour,
        biggest_day,
        peak_hours,
        current_streak,
        longest_streak,
        active_days,
        span_days,
        longest_dictation: scoped.iter().map(|e| e.words).max().unwrap_or(0),
        per_active_day: scoped_words.checked_div(active_days).unwrap_or(0),
        time_saved,
        speaking_pace,
        pace_measured,
    }
}

/// "51,104".
pub fn group(n: u64) -> String {
    let digits = n.to_string();
    let mut out = String::new();
    for (i, c) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i).is_multiple_of(3) {
            out.push(',');
        }
        out.push(c);
    }
    out
}

fn plural(n: u64, one: &str, many: &str) -> String {
    format!("{} {}", group(n), if n == 1 { one } else { many })
}

fn words(n: u64) -> String {
    plural(n, "word", "words")
}

fn clamp(n: u64) -> u32 {
    u32::try_from(n).unwrap_or(u32::MAX)
}

fn card(title: &str, now: u64, before: u64, before_label: &str) -> Card {
    let (compare, up) = if before == 0 {
        (format!("0 {before_label}"), false)
    } else {
        let pct = ((now as f64 - before as f64) / before as f64 * 100.0).round() as i64;
        let arrow = if pct >= 0 { "▲" } else { "▼" };
        (
            format!("{} {before_label} · {arrow} {}%", group(before), pct.abs()),
            pct >= 0,
        )
    };
    Card {
        title: title.into(),
        value: group(now),
        compare,
        up,
    }
}

fn tile(title: &str, value: String, detail: Option<String>) -> Tile {
    Tile {
        title: title.into(),
        value,
        detail,
    }
}

fn days(n: u64) -> String {
    plural(n, "day", "days")
}

fn tiles(p: &PeriodFigures) -> Vec<Tile> {
    let typing = TYPING_WPM as u64;
    let minutes = p.time_saved_minutes();
    let saved = if minutes < 60 {
        format!("≈{minutes} min")
    } else {
        format!("≈{}h {}m", minutes / 60, minutes % 60)
    };
    let (pace, pace_detail) = if p.pace_measured {
        (
            format!("{} wpm", group(p.speaking_pace)),
            format!(
                "{:.1}× faster than typing",
                p.speaking_pace as f64 / TYPING_WPM
            ),
        )
    } else {
        ("—".into(), "measured from new dictations".into())
    };
    // A current streak is tied to today, so a chosen period shows its longest run instead.
    let streak = if p.grain == Grain::AllTime {
        tile(
            "Current streak",
            days(p.current_streak),
            (p.longest_streak > 0).then(|| format!("best: {}", days(p.longest_streak))),
        )
    } else {
        tile(
            "Longest streak",
            days(p.longest_streak),
            Some("consecutive days".into()),
        )
    };
    let span = if p.grain == Grain::AllTime {
        "days since you started"
    } else if p.offset == 0 {
        "days so far"
    } else {
        "days in the period"
    };
    vec![
        tile(
            "Time saved",
            saved,
            Some(if p.pace_measured {
                format!("vs typing at {typing} wpm")
            } else {
                format!("estimated vs typing at {typing} wpm")
            }),
        ),
        tile("Speaking pace", pace, Some(pace_detail)),
        streak,
        tile(
            "Days active",
            format!(
                "{} of {}",
                group(p.active_days),
                group(p.span_days.max(0) as u64)
            ),
            Some(span.into()),
        ),
        tile(
            "Peak hours",
            p.peak_hours.clone(),
            Some("when you dictate most".into()),
        ),
        tile(
            "Highest volume day",
            p.biggest_day.map_or("—".into(), |(_, w)| words(w)),
            p.biggest_day.map(|(d, _)| long_day_label(d)),
        ),
        tile(
            "Longest dictation",
            words(p.longest_dictation),
            Some("in a single go".into()),
        ),
        tile(
            "Per active day",
            words(p.per_active_day),
            Some("on days you dictate".into()),
        ),
    ]
}

fn date_text(d: NaiveDate) -> String {
    d.format("%Y-%m-%d").to_string()
}

/// "12a", "3p": short enough for eight on the axis.
fn hour_tick(h: usize) -> String {
    let twelve = if h.is_multiple_of(12) { 12 } else { h % 12 };
    format!("{twelve}{}", if h < 12 { "a" } else { "p" })
}

/// Everything the window shows, as text and bars.
pub fn view(f: &Figures, shortcut: &str, first_weekday: Weekday) -> Stats {
    let p = &f.period;
    let empty_text = p.empty.then(|| {
        if p.label == "Today" {
            "No dictations yet today.".to_string()
        } else {
            format!("No dictations in {}.", p.label)
        }
    });
    let bar = |label: String, tick: String, words: u64| Bar {
        label,
        tick,
        words: clamp(words),
    };
    let first_year = f.first_day.map_or(f.today_date.year(), |d| d.year());
    let years = (first_year..=f.today_date.year().max(first_year))
        .rev()
        .map(|year| YearWords {
            year,
            words: clamp(
                f.month_volume
                    .iter()
                    .filter(|(m, _)| m.year() == year)
                    .map(|(_, w)| w)
                    .sum(),
            ),
        })
        .collect();
    Stats {
        empty: f.dictations == 0,
        shortcut: shortcut.into(),
        summary: format!(
            "{} all-time · {} · {} each",
            words(f.all_time_words),
            plural(f.dictations, "dictation", "dictations"),
            words(f.words_each)
        ),
        cards: vec![
            card("Today", f.today, f.yesterday, "yesterday"),
            card("This week", f.this_week, f.last_week, "last week"),
            card("This month", f.this_month, f.last_month, "last month"),
        ],
        last30_days: f
            .last30_days
            .iter()
            .map(|&(d, w)| bar(day_label(d), day_label(d), w))
            .collect(),
        by_month: f
            .by_month
            .iter()
            .map(|&(m, w)| {
                bar(
                    month_label(m),
                    format!("{} {}", short_month(m), m.year()),
                    w,
                )
            })
            .collect(),
        period: Period {
            grain: p.grain,
            offset: p.offset,
            label: p.label.clone(),
            first: p.window.map(|(s, _)| date_text(s)),
            last: p.window.map(|(_, l)| date_text(l)),
            empty_text,
            by_weekday: WEEKDAYS
                .iter()
                .zip(p.by_weekday)
                .map(|(name, w)| bar(name.to_string(), name[..3].to_string(), w))
                .collect(),
            by_hour: (0..24)
                .map(|h| {
                    bar(
                        hour_range(h as u32, h as u32 + 1),
                        hour_tick(h),
                        p.by_hour[h],
                    )
                })
                .collect(),
            tiles: tiles(p),
        },
        calendar: Calendar {
            today: date_text(f.today_date),
            first_day: f.first_day.map(date_text),
            first_weekday: first_weekday.num_days_from_sunday() as u8,
            days: f
                .day_volume
                .iter()
                .map(|(&d, &w)| DayWords {
                    date: date_text(d),
                    words: clamp(w),
                })
                .collect(),
            months: f
                .month_volume
                .iter()
                .map(|(&m, &w)| DayWords {
                    date: m.format("%Y-%m").to_string(),
                    words: clamp(w),
                })
                .collect(),
            busiest_day: clamp(f.busiest_day),
            busiest_month: clamp(f.busiest_month),
            years,
        },
    }
}

/// The stats window's answer for a request, from the record's text and the
/// time now in the PC's own time zone.
pub fn stats<Tz: TimeZone>(
    log: &str,
    now: &DateTime<Tz>,
    first_weekday: Weekday,
    request: &StatsRequest,
    shortcut: &str,
) -> Stats {
    let entries = read_log(log, &now.timezone());
    let now = now.naive_local();
    let jumped = request
        .jump_to
        .as_deref()
        .and_then(|d| NaiveDate::parse_from_str(d, "%Y-%m-%d").ok())
        .map(|d| offset_of(request.grain, d, now.date(), first_weekday));
    let offset = jumped.unwrap_or(request.offset);
    view(
        &figures(&entries, now, first_weekday, request.grain, offset),
        shortcut,
        first_weekday,
    )
}

/// The stats types for the screens' TypeScript file.
pub(crate) fn typescript_decls(cfg: &ts_rs::Config) -> Vec<String> {
    vec![
        Grain::decl(cfg),
        StatsRequest::decl(cfg),
        Stats::decl(cfg),
        Card::decl(cfg),
        Bar::decl(cfg),
        Period::decl(cfg),
        Tile::decl(cfg),
        Calendar::decl(cfg),
        DayWords::decl(cfg),
        YearWords::decl(cfg),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn at(text: &str) -> NaiveDateTime {
        NaiveDateTime::parse_from_str(text, "%Y-%m-%d %H:%M").unwrap()
    }

    fn entry(when: &str, words: u64, seconds: Option<f64>) -> Entry {
        Entry {
            at: at(when),
            words,
            seconds,
        }
    }

    fn day(text: &str) -> NaiveDate {
        NaiveDate::parse_from_str(text, "%Y-%m-%d").unwrap()
    }

    #[test]
    fn hour_ranges_say_am_or_pm_once_when_both_ends_share_it() {
        assert_eq!(hour_range(7, 10), "7–10 AM");
        assert_eq!(hour_range(9, 12), "9 AM–12 PM");
        assert_eq!(hour_range(22, 25), "10 PM–1 AM");
        assert_eq!(hour_range(23, 24), "11 PM–12 AM");
        assert_eq!(hour_range(0, 1), "12–1 AM");
    }

    #[test]
    fn periods_are_named_as_on_the_mac() {
        let today = day("2026-11-10");
        let sunday = Weekday::Sun;
        let label = |g, o| period_label(g, window(g, o, today, sunday), today);
        assert_eq!(label(Grain::Day, 0), "Today");
        assert_eq!(label(Grain::Day, -1), "Yesterday");
        assert_eq!(label(Grain::Day, -14), "Oct 27, 2026");
        assert_eq!(label(Grain::Week, 0), "Nov 8 – 14");
        assert_eq!(label(Grain::Week, -2), "Oct 25 – 31");
        assert_eq!(label(Grain::Week, -1), "Nov 1 – 7");
        assert_eq!(label(Grain::Week, -6), "Sep 27 – Oct 3");
        assert_eq!(label(Grain::Month, -8), "March 2026");
        assert_eq!(label(Grain::Month, -11), "December 2025");
        assert_eq!(label(Grain::Year, -1), "2025");
        assert_eq!(label(Grain::AllTime, 0), "All time");
        // A week that starts on Monday where the PC says so.
        assert_eq!(
            period_label(
                Grain::Week,
                window(Grain::Week, 0, today, Weekday::Mon),
                today
            ),
            "Nov 9 – 15"
        );
    }

    #[test]
    fn the_calendar_jumps_to_the_period_holding_a_day_never_ahead_of_now() {
        let today = day("2026-11-10");
        let sun = Weekday::Sun;
        assert_eq!(offset_of(Grain::Day, day("2026-10-27"), today, sun), -14);
        assert_eq!(offset_of(Grain::Week, day("2026-10-27"), today, sun), -2);
        assert_eq!(offset_of(Grain::Week, day("2026-11-08"), today, sun), 0);
        assert_eq!(offset_of(Grain::Month, day("2026-09-15"), today, sun), -2);
        assert_eq!(offset_of(Grain::Year, day("2025-01-01"), today, sun), -1);
        assert_eq!(offset_of(Grain::Day, day("2026-12-01"), today, sun), 0);
    }

    #[test]
    fn a_streak_still_counts_before_todays_first_dictation() {
        let log = [
            entry("2026-11-07 09:00", 10, None),
            entry("2026-11-08 09:00", 10, None),
            entry("2026-11-09 23:59", 10, None),
        ];
        let f = figures(
            &log,
            at("2026-11-10 08:00"),
            Weekday::Sun,
            Grain::AllTime,
            0,
        );
        assert_eq!(f.period.current_streak, 3);
        assert_eq!(f.period.longest_streak, 3);
        // Two days missed and it's gone, but the best is kept.
        let f = figures(
            &log,
            at("2026-11-12 08:00"),
            Weekday::Sun,
            Grain::AllTime,
            0,
        );
        assert_eq!(f.period.current_streak, 0);
        let v = view(&f, "Ctrl+Shift+Space", Weekday::Sun);
        assert_eq!(v.period.tiles[2].value, "0 days");
        assert_eq!(v.period.tiles[2].detail.as_deref(), Some("best: 3 days"));
    }

    #[test]
    fn time_saved_and_pace_come_from_timed_dictations_only() {
        // 300 words in 120 s: 150 wpm. 300 words typed at 40 wpm take 450 s.
        let log = [
            entry("2026-11-10 09:00", 150, Some(60.0)),
            entry("2026-11-10 09:05", 150, Some(60.0)),
        ];
        let f = figures(&log, at("2026-11-10 10:00"), Weekday::Sun, Grain::Day, 0);
        assert_eq!(f.period.speaking_pace, 150);
        assert_eq!(f.period.time_saved, 330.0);
        let tiles = view(&f, "", Weekday::Sun).period.tiles;
        assert_eq!(tiles[0].value, "≈5 min");
        assert_eq!(tiles[1].value, "150 wpm");
        assert_eq!(tiles[1].detail.as_deref(), Some("3.8× faster than typing"));

        // No durations at all: an estimate at a typical pace, and no pace shown.
        let log = [entry("2026-11-10 09:00", 6000, None)];
        let f = figures(&log, at("2026-11-10 10:00"), Weekday::Sun, Grain::Day, 0);
        let tiles = view(&f, "", Weekday::Sun).period.tiles;
        assert_eq!(tiles[0].value, "≈1h 50m");
        assert_eq!(
            tiles[0].detail.as_deref(),
            Some("estimated vs typing at 40 wpm")
        );
        assert_eq!(tiles[1].value, "—");
    }

    #[test]
    fn cards_compare_with_the_period_before() {
        assert_eq!(card("Today", 212, 0, "yesterday").compare, "0 yesterday");
        let week = card("This week", 704, 1997, "last week");
        assert_eq!(week.compare, "1,997 last week · ▼ 65%");
        assert!(!week.up);
        assert!(card("This month", 100, 100, "last month").up);
        assert_eq!(group(51_104), "51,104");
        assert_eq!(group(1_234_567), "1,234,567");
        assert_eq!(group(999), "999");
    }

    #[test]
    fn stat_06_an_empty_period_says_so_instead_of_zero_tiles() {
        let log = [entry("2026-02-10 09:00", 10, None)];
        let f = figures(&log, at("2026-11-10 10:00"), Weekday::Sun, Grain::Month, -8);
        let v = view(&f, "", Weekday::Sun);
        assert_eq!(
            v.period.empty_text.as_deref(),
            Some("No dictations in March 2026.")
        );
        let f = figures(&log, at("2026-11-10 10:00"), Weekday::Sun, Grain::Day, 0);
        assert_eq!(
            view(&f, "", Weekday::Sun).period.empty_text.as_deref(),
            Some("No dictations yet today.")
        );
    }

    #[test]
    fn stat_05_no_dictations_at_all_is_marked_empty_with_the_shortcut() {
        let v = stats(
            "",
            &chrono::Utc::now(),
            Weekday::Sun,
            &StatsRequest {
                grain: Grain::AllTime,
                offset: 0,
                jump_to: None,
            },
            "Ctrl+Alt+D",
        );
        assert!(v.empty);
        assert_eq!(v.shortcut, "Ctrl+Alt+D");
    }

    #[test]
    fn days_active_never_counts_before_the_first_dictation_or_after_today() {
        let log = [
            entry("2026-11-03 09:00", 10, None),
            entry("2026-11-05 09:00", 10, None),
        ];
        let f = figures(&log, at("2026-11-10 10:00"), Weekday::Sun, Grain::Month, 0);
        assert_eq!((f.period.active_days, f.period.span_days), (2, 8));
        let tiles = view(&f, "", Weekday::Sun).period.tiles;
        assert_eq!(tiles[3].value, "2 of 8");
        assert_eq!(tiles[3].detail.as_deref(), Some("days so far"));
    }
}
