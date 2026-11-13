//! Updates: loqui checks its update list as it starts, once a day after that,
//! and when asked (the tray menu's Check for updates, or Settings). A newer
//! version opens the update window; Install downloads it, Tauri's updater
//! refuses it unless it carries a signature from loqui's Windows update key,
//! and the update installer replaces loqui and starts it again. The speech
//! model and everything in `%LOCALAPPDATA%\Loqui` stay as they are.
//!
//! The update check is the only thing loqui sends over the internet. An
//! automatic check that can't reach the list says nothing; only a check by
//! hand says so.

use crate::screens;
use loqui_core::commands::{events, Store};
use loqui_core::records::iso8601;
use loqui_core::updates::{
    listed_size, megabytes, say, Feeds, Schedule, UpdateStatus, Updates, STABLE_FEED, TEST_FEED,
};
use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Emitter, Manager, State};
use tauri_plugin_updater::{Error, Update, UpdaterExt};

/// The lists this build reads. Release builds read the public ones; the
/// Windows checks and the release drill build loqui with their own.
const FEEDS: Feeds<'static> = Feeds {
    stable: match option_env!("LOQUI_STABLE_FEED") {
        Some(url) if !url.is_empty() => url,
        _ => STABLE_FEED,
    },
    test: match option_env!("LOQUI_TEST_FEED") {
        Some(url) if !url.is_empty() => url,
        _ => TEST_FEED,
    },
};

/// The update window.
const WINDOW: &str = "update";

/// Where checking and installing stand. One per app.
#[derive(Default)]
pub struct Checker {
    inner: Mutex<Inner>,
}

#[derive(Default)]
struct Inner {
    checked_at: Option<String>,
    status: Option<UpdateStatus>,
    offer: Option<Update>,
    /// Goes up each time "Get test versions" changes. A check that began
    /// before a change asked the other list, so its answer is dropped.
    channel_changes: u64,
}

fn unix_now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs() as i64)
}

fn log(app: &AppHandle, line: &str) {
    app.state::<Store>().records().log(line, unix_now());
}

/// What the Updates card and the update window show.
pub fn view(app: &AppHandle) -> Updates {
    let checker = app.state::<Checker>();
    let inner = checker.inner.lock().unwrap_or_else(|e| e.into_inner());
    let settings = app.state::<Store>().settings().settings;
    Updates {
        version: app.package_info().version.to_string(),
        test_versions: settings.channel == loqui_core::updates::Channel::Test,
        checked_at: inner.checked_at.clone(),
        status: inner.status.clone().unwrap_or(UpdateStatus::NotChecked),
    }
}

fn set(app: &AppHandle, change: impl FnOnce(&mut Inner)) {
    {
        let checker = app.state::<Checker>();
        let mut inner = checker.inner.lock().unwrap_or_else(|e| e.into_inner());
        change(&mut inner);
    }
    let _ = app.emit(events::UPDATES_CHANGED, ());
}

/// A check, download or install is under way.
fn busy(status: Option<&UpdateStatus>) -> bool {
    matches!(
        status,
        Some(UpdateStatus::Checking | UpdateStatus::Downloading { .. } | UpdateStatus::Installing)
    )
}

/// A check by hand begins: it says "Checking" at once, before any window can
/// show the last answer. False if a check, download or install is under way.
fn begin_by_hand(app: &AppHandle) -> bool {
    let began = {
        let checker = app.state::<Checker>();
        let mut inner = checker.inner.lock().unwrap_or_else(|e| e.into_inner());
        let free = !busy(inner.status.as_ref());
        if free {
            inner.status = Some(UpdateStatus::Checking);
        }
        free
    };
    if began {
        let _ = app.emit(events::UPDATES_CHANGED, ());
    }
    began
}

/// Get ready to check, and with `automatic`, check now and once a day.
pub fn start(app: &AppHandle, automatic: bool) {
    app.manage(Checker::default());
    if !automatic {
        return;
    }
    let app = app.clone();
    let spawned = std::thread::Builder::new()
        .name("loqui updates".into())
        .spawn(move || {
            let mut schedule = Schedule::starting(unix_now());
            loop {
                if schedule.due(unix_now()) {
                    tauri::async_runtime::block_on(check_now(&app, false));
                }
                let wait = schedule.wait(unix_now());
                std::thread::sleep(Duration::from_secs(wait.unsigned_abs()));
            }
        });
    if let Err(e) = spawned {
        eprintln!("loqui could not start its update checks: {e}");
    }
}

/// Check for updates, from the tray menu: the update window opens and says
/// what it found.
pub fn check(app: &AppHandle) {
    let began = begin_by_hand(app);
    open_window(app);
    if began {
        let app = app.clone();
        tauri::async_runtime::spawn(async move {
            check_now(&app, true).await;
        });
    }
}

/// Ask this PC's update list whether there's a newer version. A check by
/// hand has already begun (`begin_by_hand`); an automatic one waits its turn.
/// If "Get test versions" changes while a list is being asked, that answer
/// is for the other list: it's dropped, and a check by hand asks again.
async fn check_now(app: &AppHandle, by_hand: bool) {
    loop {
        let asked = {
            let checker = app.state::<Checker>();
            let inner = checker.inner.lock().unwrap_or_else(|e| e.into_inner());
            if !by_hand && busy(inner.status.as_ref()) {
                return;
            }
            inner.channel_changes
        };
        // Read after `asked`: a switch from here on makes this answer stale.
        let channel = app.state::<Store>().settings().settings.channel;
        let list = FEEDS.for_channel(channel);
        let found = ask(app, list).await;
        let now = iso8601(unix_now());
        let stored = match found {
            Ok(Some(update)) => {
                log(
                    app,
                    &format!("update check ({list}): {} is available", update.version),
                );
                let size_mb = listed_size(&update.raw_json, &platforms()).map(megabytes);
                let offered = settle(app, asked, |i| {
                    i.checked_at = Some(now);
                    i.status = Some(UpdateStatus::Available {
                        version: update.version.clone(),
                        notes: update.body.clone().unwrap_or_default(),
                        size_mb,
                    });
                    i.offer = Some(update);
                });
                if offered {
                    open_window(app);
                }
                offered
            }
            Ok(None) => {
                log(app, &format!("update check ({list}): up to date"));
                settle(app, asked, |i| {
                    i.checked_at = Some(now);
                    i.status = Some(UpdateStatus::UpToDate);
                    i.offer = None;
                })
            }
            Err(e) => {
                log(app, &format!("update check ({list}) failed: {e}"));
                // The daily check fails quietly: what the card said stays.
                !by_hand
                    || settle(app, asked, |i| {
                        i.status = Some(UpdateStatus::CheckFailed {
                            message: say::UNREACHABLE.into(),
                        })
                    })
            }
        };
        if stored || !by_hand {
            if !stored {
                log(app, &format!("update check ({list}): get test versions changed meanwhile; answer dropped"));
            }
            return;
        }
        log(
            app,
            &format!("update check ({list}): get test versions changed meanwhile; asking again"),
        );
    }
}

/// Store a check's answer, unless "Get test versions" changed while it was
/// asked: then nothing from it is offered. True if stored.
fn settle(app: &AppHandle, asked: u64, answer: impl FnOnce(&mut Inner)) -> bool {
    let mut stored = false;
    set(app, |i| {
        if i.channel_changes == asked {
            answer(i);
            stored = true;
        } else {
            i.offer = None;
        }
    });
    stored
}

/// Newer version, none, or couldn't tell.
async fn ask(app: &AppHandle, list: &str) -> Result<Option<Update>, String> {
    let url = list.parse().map_err(|e| format!("{e}"))?;
    let updater = app
        .updater_builder()
        .endpoints(vec![url])
        .and_then(|b| b.timeout(Duration::from_secs(30)).build())
        .map_err(|e| e.to_string())?;
    match updater.check().await {
        Ok(found) => Ok(found),
        // The list isn't there (yet): before the first public version there is
        // no public list, and that is the same as nothing newer.
        Err(Error::ReleaseNotFound) => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

/// The update list's names for this PC, the most exact first.
fn platforms() -> [&'static str; 2] {
    if cfg!(target_arch = "aarch64") {
        ["windows-aarch64-nsis", "windows-aarch64"]
    } else {
        ["windows-x86_64-nsis", "windows-x86_64"]
    }
}

/// Download the offered update, check its signature, and hand over to its
/// installer, which closes loqui and starts the new version.
async fn install(app: &AppHandle) {
    // Taken and marked as downloading in one step, so a second click can't start a second download.
    let offer = {
        let checker = app.state::<Checker>();
        let mut inner = checker.inner.lock().unwrap_or_else(|e| e.into_inner());
        if busy(inner.status.as_ref()) || inner.offer.is_none() {
            return;
        }
        inner.status = Some(UpdateStatus::Downloading { percent: None });
        inner.offer.clone()
    };
    let Some(update) = offer else { return };
    let _ = app.emit(events::UPDATES_CHANGED, ());
    let mut got = 0u64;
    let mut shown = None;
    let progress = app.clone();
    let downloaded = update
        .download(
            |chunk, total| {
                got += chunk as u64;
                let percent = total
                    .filter(|t| *t > 0)
                    .map(|t| ((got * 100) / t).min(100) as u8);
                if percent != shown {
                    shown = percent;
                    set(&progress, |i| {
                        i.status = Some(UpdateStatus::Downloading { percent })
                    });
                }
            },
            || {},
        )
        .await;
    let failed = |app: &AppHandle, message: &str| {
        set(app, |i| {
            i.status = Some(UpdateStatus::InstallFailed {
                message: message.into(),
            })
        });
    };
    let bytes = match downloaded {
        Ok(bytes) => bytes,
        Err(e) => {
            log(
                app,
                &format!("update {} not installed: {e}", update.version),
            );
            return failed(app, refused(&e, say::NOT_DOWNLOADED));
        }
    };
    log(
        app,
        &format!(
            "update {} downloaded and verified; installing",
            update.version
        ),
    );
    set(app, |i| i.status = Some(UpdateStatus::Installing));
    // On success this doesn't return: loqui closes and the installer runs.
    if let Err(e) = update.install(bytes) {
        log(app, &format!("update {} not started: {e}", update.version));
        failed(app, refused(&e, say::NOT_STARTED));
    }
}

/// What to tell the person when an update wasn't installed: a bad signature
/// is always said as such, anything else as `otherwise`.
fn refused(e: &Error, otherwise: &'static str) -> &'static str {
    match e {
        Error::Minisign(_)
        | Error::Base64(_)
        | Error::SignatureUtf8(_)
        | Error::SignedVersionMismatch { .. } => say::UNVERIFIED,
        _ => otherwise,
    }
}

fn open_window(app: &AppHandle) {
    if screens::focus(app, WINDOW) {
        return;
    }
    let opened = screens::builder(app, WINDOW, "update.html")
        .title("loqui update")
        .inner_size(600.0, 420.0)
        .resizable(false)
        .maximizable(false)
        .minimizable(false)
        .center()
        .focused(true)
        .build();
    if let Err(error) = opened {
        eprintln!("loqui could not open the update window: {error}");
    }
}

// What the Updates card and the update window can ask.

#[tauri::command]
pub fn updates(app: AppHandle) -> Updates {
    view(&app)
}

/// Check now, by hand; the answer comes back when the check is done.
#[tauri::command]
pub async fn check_for_updates(app: AppHandle) -> Updates {
    if begin_by_hand(&app) {
        check_now(&app, true).await;
    }
    view(&app)
}

#[tauri::command]
pub async fn install_update(app: AppHandle) {
    install(&app).await;
}

/// "Get test versions". Switching lists forgets what the other list offered:
/// turning it off never offers an older version, it waits for a newer public one.
#[tauri::command]
pub fn set_test_versions(
    app: AppHandle,
    store: State<'_, Store>,
    on: bool,
) -> Result<Updates, String> {
    store.set_test_versions(on)?;
    log(
        &app,
        &format!("get test versions: {}", if on { "on" } else { "off" }),
    );
    set(&app, |i| {
        // A check under way now asked the other list: its answer is dropped.
        i.channel_changes += 1;
        if !busy(i.status.as_ref()) {
            i.status = None;
            i.offer = None;
        }
    });
    let _ = app.emit(events::SETTINGS_CHANGED, ());
    Ok(view(&app))
}
