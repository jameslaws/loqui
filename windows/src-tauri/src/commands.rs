//! What the screens can ask of loqui. Each command hands the work to
//! loqui-core's `Store` (which owns every file) or to Windows, then tells the
//! other open windows and the tray menu what changed. The argument and result
//! types are loqui-core's, exported to TypeScript in `ui/src/bindings.ts`.

use crate::tray;
use loqui_core::commands::{events, General, HistoryItem, ShortcutView, Store, Term, Welcome};
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::{AppHandle, Emitter, State, WebviewWindow};

type Answer<T = ()> = Result<T, String>;

fn unix_now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs() as i64)
}

/// History changed: refresh Recent and every open window that shows it.
pub fn history_changed(app: &AppHandle) {
    tray::refresh_recent(app);
    let _ = app.emit(events::HISTORY_CHANGED, ());
}

/// A dictation was counted: an open stats window shows it at once.
#[cfg(windows)]
pub fn stats_changed(app: &AppHandle) {
    let _ = app.emit(events::STATS_CHANGED, ());
}

fn settings_changed(app: &AppHandle) {
    let _ = app.emit(events::SETTINGS_CHANGED, ());
}

/// Put text on the clipboard, kept out of Windows' clipboard history and sync
/// like a dictation is.
pub fn copy_to_clipboard(app: &AppHandle, text: &str) -> Answer {
    #[cfg(windows)]
    {
        use tauri::Manager;
        let owner = app
            .get_webview_window("bubble")
            .and_then(|w| w.hwnd().ok())
            .map_or(std::ptr::null_mut(), |h| h.0 as _);
        crate::paste::set_clipboard(text, owner)
    }
    #[cfg(not(windows))]
    {
        let _ = (app, text);
        Err("the clipboard is only reached on Windows".into())
    }
}

#[tauri::command]
pub fn general(store: State<Store>) -> General {
    store.general()
}

/// Settings is recording a shortcut: the current one stops working until
/// `end_shortcut`, so pressing it records it instead of starting a dictation.
#[tauri::command]
pub fn begin_shortcut() {
    #[cfg(windows)]
    crate::hook::pause(true);
}

#[tauri::command]
pub fn end_shortcut() {
    #[cfg(windows)]
    crate::hook::pause(false);
}

#[tauri::command]
pub fn set_shortcut(app: AppHandle, store: State<Store>, pressed: String) -> Answer<ShortcutView> {
    let shortcut = store.set_shortcut(&pressed)?;
    #[cfg(windows)]
    crate::hook::set_shortcut(shortcut);
    store
        .records()
        .log(&format!("listening for {shortcut}"), unix_now());
    tray::set_shortcut(&app, &shortcut.to_string());
    settings_changed(&app);
    Ok(shortcut.into())
}

#[tauri::command]
pub fn set_fillers(store: State<Store>, remove: bool, fillers: Vec<String>) -> Answer {
    store.set_fillers(remove, &fillers)
}

#[tauri::command]
pub fn set_retention(app: AppHandle, store: State<Store>, days: i64) -> Answer {
    store.set_retention(days, unix_now())?;
    history_changed(&app);
    Ok(())
}

#[tauri::command]
pub fn set_start_at_sign_in(app: AppHandle, store: State<Store>, on: bool) -> Answer {
    store.set_start_at_sign_in(on)?;
    #[cfg(windows)]
    crate::windows_shell::start_at_sign_in(on)?;
    settings_changed(&app);
    Ok(())
}

#[tauri::command]
pub fn dictionary(store: State<Store>) -> Vec<Term> {
    store.dictionary()
}

#[tauri::command]
pub fn set_dictionary(store: State<Store>, terms: Vec<Term>) -> Answer {
    store.set_dictionary(&terms)
}

#[tauri::command]
pub fn history(store: State<Store>) -> Result<Vec<HistoryItem>, String> {
    store.history()
}

#[tauri::command]
pub fn delete_history(app: AppHandle, store: State<Store>, item: HistoryItem) -> Answer {
    store.delete_history(&item)?;
    history_changed(&app);
    Ok(())
}

#[tauri::command]
pub fn clear_history(app: AppHandle, store: State<Store>) -> Answer {
    store.clear_history()?;
    history_changed(&app);
    Ok(())
}

#[tauri::command]
pub fn copy_text(app: AppHandle, text: String) -> Answer {
    copy_to_clipboard(&app, &text)
}

#[tauri::command]
pub fn welcome(store: State<Store>) -> Welcome {
    let settings = store.settings().settings;
    #[cfg(windows)]
    let microphone_allowed = crate::windows_shell::microphone_allowed();
    #[cfg(not(windows))]
    let microphone_allowed = true;
    Welcome {
        microphone_allowed,
        shortcut: settings.shortcut.into(),
        start_at_sign_in: settings.start_at_sign_in,
    }
}

#[tauri::command]
pub fn open_microphone_settings() {
    #[cfg(windows)]
    crate::windows_shell::open_microphone_settings();
}

/// Finish: the welcome won't open by itself again.
#[tauri::command]
pub fn finish_welcome(store: State<Store>, window: WebviewWindow) -> Answer {
    store.finish_welcome()?;
    let _ = window.close();
    Ok(())
}

#[tauri::command]
pub fn close_window(window: WebviewWindow) {
    let _ = window.close();
}
