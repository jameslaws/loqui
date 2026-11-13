//! Updates: which list loqui reads, when it checks, and what it says. The app
//! does the asking and installing (Tauri's updater, which refuses anything not
//! signed with loqui's Windows update key); these are the rules around it, kept
//! here so they test on any computer.
//!
//! Two lists, chosen by "Get test versions" in Settings: the public one on
//! GitHub Pages, and the test one, a file on a fixed GitHub pre-release that
//! every test version replaces. Pages only serves the main branch, which test
//! versions never reach, so the test list can't live there too.

use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// The public update list: versions James approved.
pub const STABLE_FEED: &str = "https://jameslaws.github.io/loqui/windows/stable.json";
/// The test update list: every change merged into staging.
pub const TEST_FEED: &str =
    "https://github.com/jameslaws/loqui/releases/download/windows-test-feed/beta.json";

/// Which versions this PC is offered. Saved as `channel` in settings.json.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Channel {
    /// Only versions James approved.
    #[default]
    Stable,
    /// Every test version too ("Get test versions" on).
    Test,
}

/// The two update lists' addresses. Release builds use [`Feeds::PUBLIC`];
/// the checks and the drill build loqui with their own lists.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Feeds<'a> {
    pub stable: &'a str,
    pub test: &'a str,
}

impl<'a> Feeds<'a> {
    pub const PUBLIC: Feeds<'static> = Feeds {
        stable: STABLE_FEED,
        test: TEST_FEED,
    };

    pub fn for_channel(&self, channel: Channel) -> &'a str {
        match channel {
            Channel::Stable => self.stable,
            Channel::Test => self.test,
        }
    }
}

/// Seconds between automatic checks: once a day.
pub const DAY: i64 = 86_400;
/// The longest loqui sleeps between looking at the clock, so a PC that slept
/// through a check time catches up soon after it wakes.
pub const TICK: i64 = 600;

/// When the automatic check is due: as loqui starts, then a day after each
/// automatic check. Checking by hand doesn't move it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Schedule {
    next: i64,
}

impl Schedule {
    pub fn starting(now: i64) -> Self {
        Self { next: now }
    }

    /// True when a check is due now; the next one is then a day away.
    pub fn due(&mut self, now: i64) -> bool {
        if now < self.next {
            return false;
        }
        self.next = now + DAY;
        true
    }

    /// How long to sleep before looking again.
    pub fn wait(&self, now: i64) -> i64 {
        (self.next - now).clamp(1, TICK)
    }
}

/// What a person reads about updates. One home for each line.
pub mod say {
    pub const UP_TO_DATE: &str = "loqui is up to date";
    pub const UNREACHABLE: &str = "Couldn't reach the update server. Try again later.";
    pub const UNVERIFIED: &str = "This update couldn't be verified, so it wasn't installed.";
    pub const NOT_DOWNLOADED: &str = "The update couldn't be downloaded. Try again later.";
    pub const NOT_STARTED: &str = "The update couldn't be started. Try again later.";
}

/// Where an update check stands, for the Updates card and the update window.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(tag = "state", rename_all = "camelCase")]
pub enum UpdateStatus {
    /// No check yet since loqui started.
    NotChecked,
    Checking,
    UpToDate,
    /// A newer version is on this PC's list.
    Available {
        version: String,
        /// The release notes: one change per line, each starting "- ".
        notes: String,
        /// The download, in whole megabytes, when the list says.
        #[serde(rename = "sizeMb")]
        #[ts(type = "number | null")]
        size_mb: Option<u64>,
    },
    /// Downloading it; `percent` once the size is known.
    Downloading {
        #[ts(type = "number | null")]
        percent: Option<u8>,
    },
    /// Downloaded and checked; loqui is closing so the installer can run.
    Installing,
    /// A check by hand couldn't get an answer.
    CheckFailed {
        message: String,
    },
    /// The offered update wasn't installed, and why.
    InstallFailed {
        message: String,
    },
}

/// The Updates card in Settings, and the update window.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, TS)]
#[serde(rename_all = "camelCase")]
pub struct Updates {
    /// The version running now.
    pub version: String,
    /// "Get test versions" is on.
    pub test_versions: bool,
    /// When the last check finished (ISO 8601, UTC), if there was one.
    pub checked_at: Option<String>,
    pub status: UpdateStatus,
}

/// Megabytes, rounded, as the update window says them ("about 12 MB").
pub fn megabytes(bytes: u64) -> u64 {
    ((bytes as f64) / 1_048_576.0).round().max(1.0) as u64
}

/// An update list entry's download size for this PC, if the list gives one.
/// The release workflow writes `size` beside each platform's `url` and
/// `signature`; Tauri's updater ignores it.
pub fn listed_size(list: &serde_json::Value, platforms: &[&str]) -> Option<u64> {
    platforms
        .iter()
        .find_map(|p| list["platforms"][*p]["size"].as_u64())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn upd_04_it_checks_at_start_and_once_a_day() {
        // 25 hours of loqui running on a fake clock, waking as the app does.
        // A check by hand never touches the schedule (the app asks the list
        // straight away), so it adds one request to these two; the Windows
        // check counts the start and by-hand requests at the list itself.
        let start = 1_800_000_000;
        let mut schedule = Schedule::starting(start);
        let (mut automatic, mut now) = (Vec::new(), start);
        while now <= start + 25 * 3600 {
            if schedule.due(now) {
                automatic.push((now - start) / 3600);
            }
            now += schedule.wait(now);
        }
        assert_eq!(automatic, [0, 24]);
    }

    #[test]
    fn a_pc_that_slept_through_the_check_checks_soon_after_it_wakes() {
        let mut schedule = Schedule::starting(0);
        assert!(schedule.due(0));
        // Asleep from hour 2 to hour 30: the wait it was given ends, the clock
        // has jumped, and the overdue check runs once, not once per missed day.
        assert!(schedule.due(30 * 3600));
        assert!(!schedule.due(30 * 3600 + TICK));
        assert!(schedule.wait(30 * 3600) <= TICK);
    }

    #[test]
    fn chan_02_the_switch_picks_the_list() {
        assert_eq!(Feeds::PUBLIC.for_channel(Channel::Stable), STABLE_FEED);
        assert_eq!(Feeds::PUBLIC.for_channel(Channel::Test), TEST_FEED);
        assert_eq!(Channel::default(), Channel::Stable);
        assert_eq!(serde_json::to_string(&Channel::Test).unwrap(), "\"test\"");
        // The public list never moves with releases ("latest" would skip test
        // versions and pre-releases), and both lists are GitHub's.
        assert!(!STABLE_FEED.contains("latest") && !TEST_FEED.contains("latest"));
        assert!(STABLE_FEED.starts_with("https://jameslaws.github.io/"));
        assert!(TEST_FEED.starts_with("https://github.com/jameslaws/loqui/releases/download/"));
    }

    #[test]
    fn the_listed_size_is_read_for_this_pc_and_said_in_megabytes() {
        let list = serde_json::json!({
            "version": "0.0.4",
            "platforms": {
                "windows-x86_64": {"url": "u", "signature": "s", "size": 12_582_912},
                "windows-aarch64": {"url": "u", "signature": "s"}
            }
        });
        let bytes = listed_size(&list, &["windows-x86_64-nsis", "windows-x86_64"]).unwrap();
        assert_eq!(megabytes(bytes), 12);
        assert_eq!(listed_size(&list, &["windows-aarch64"]), None);
        assert_eq!(megabytes(200_000), 1);
    }
}
