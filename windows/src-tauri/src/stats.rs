//! Dictation stats, from the tray menu: the window, and the figures it asks
//! for. loqui-core works out every figure from the dictation record, in the
//! PC's own time zone, with weeks starting on the day Windows' region
//! settings say.

use crate::screens;
use loqui_core::commands::Store;
use loqui_core::stats::{Stats, StatsRequest};
use tauri::{AppHandle, State};

pub fn open(app: &AppHandle) {
    screens::stats(app);
}

#[tauri::command]
pub fn stats(store: State<Store>, request: StatsRequest) -> Result<Stats, String> {
    store.stats(&request, &chrono::Local::now(), first_weekday())
}

/// The first day of the week in Windows' region settings ("0" is Monday).
#[cfg(windows)]
fn first_weekday() -> chrono::Weekday {
    use windows_sys::Win32::Globalization::{GetLocaleInfoEx, LOCALE_IFIRSTDAYOFWEEK};
    let mut text = [0u16; 4];
    // SAFETY: a null name is the user's own locale; the buffer and its length match.
    let written = unsafe {
        GetLocaleInfoEx(
            std::ptr::null(),
            LOCALE_IFIRSTDAYOFWEEK,
            text.as_mut_ptr(),
            text.len() as i32,
        )
    };
    (written > 1)
        .then(|| char::from_u32(u32::from(text[0])))
        .flatten()
        .and_then(|c| c.to_digit(10))
        .and_then(|n| chrono::Weekday::try_from(n as u8).ok())
        .unwrap_or(chrono::Weekday::Sun)
}

#[cfg(not(windows))]
fn first_weekday() -> chrono::Weekday {
    chrono::Weekday::Sun
}
