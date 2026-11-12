//! The loqui icon in the notification area and its menu: what the shortcut
//! is, the windows, Recent (the last five dictations, a click copies one),
//! and Quit.

use crate::{about, screens, stats, updates};
use loqui_core::commands::Store;
use std::sync::Mutex;
use tauri::image::Image;
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem, Submenu};
use tauri::tray::TrayIconBuilder;
use tauri::{AppHandle, Manager, Wry};

const DARK_INK: &[u8] = include_bytes!("../icons/tray/mic-dark-ink.png");
const LIGHT_INK: &[u8] = include_bytes!("../icons/tray/mic-light-ink.png");
#[cfg(windows)]
const RECORDING: &[u8] = include_bytes!("../icons/tray/mic-recording.png");
#[cfg(windows)]
const RECORDING_DIM: &[u8] = include_bytes!("../icons/tray/mic-recording-dim.png");
const ID: &str = "loqui";
const RECENT: usize = 5;
const NO_DICTATIONS: &str = "No dictations yet";

/// The parts of the menu that change while loqui runs.
struct Live {
    status: MenuItem<Wry>,
    recent: Submenu<Wry>,
    state: Mutex<State>,
}

#[derive(Default)]
struct State {
    shortcut: String,
    listening: bool,
    /// The full text behind each Recent item, in menu order.
    texts: Vec<String>,
}

/// The menu's first line: how to start, or how to stop.
fn status_line(shortcut: &str, listening: bool) -> String {
    if listening {
        format!("Listening: press {shortcut} to stop")
    } else {
        format!("Press {shortcut} to dictate")
    }
}

pub fn install(app: &AppHandle, shortcut: &str) -> tauri::Result<()> {
    let item = |id: &str, text: &str| MenuItem::with_id(app, id, text, true, None::<&str>);
    let status = MenuItem::with_id(
        app,
        "status",
        status_line(shortcut, false),
        false,
        None::<&str>,
    )?;
    let recent = Submenu::with_id(app, "recent", "Recent", true)?;
    let menu = Menu::with_items(
        app,
        &[
            &status,
            &PredefinedMenuItem::separator(app)?,
            &item("stats", "Dictation stats\u{2026}")?,
            &item("history", "Dictation history\u{2026}")?,
            &recent,
            &PredefinedMenuItem::separator(app)?,
            &item("settings", "Settings\u{2026}")?,
            &PredefinedMenuItem::separator(app)?,
            &item("welcome", "Welcome and setup\u{2026}")?,
            &item("updates", "Check for updates\u{2026}")?,
            &item("about", "About loqui")?,
            &PredefinedMenuItem::separator(app)?,
            &item("quit", "Quit loqui")?,
        ],
    )?;
    app.manage(Live {
        status,
        recent,
        state: Mutex::new(State {
            shortcut: shortcut.to_string(),
            ..State::default()
        }),
    });
    refresh_recent(app);

    TrayIconBuilder::with_id(ID)
        .icon(Image::from_bytes(icon_for_taskbar())?)
        .tooltip("loqui")
        .menu(&menu)
        .show_menu_on_left_click(true)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "stats" => stats::open(app),
            "history" => screens::history(app),
            "settings" => screens::settings(app),
            "welcome" => screens::welcome(app),
            "updates" => updates::check(app),
            "about" => about::show(app),
            "quit" => app.exit(0),
            id => {
                if let Some(n) = id.strip_prefix("recent-").and_then(|n| n.parse().ok()) {
                    copy_recent(app, n);
                }
            }
        })
        .build(app)?;
    Ok(())
}

fn live(app: &AppHandle) -> Option<tauri::State<'_, Live>> {
    app.try_state::<Live>()
}

/// Rebuild Recent from the history file: after a dictation, a delete or a clear.
pub fn refresh_recent(app: &AppHandle) {
    let (Some(live), Some(store)) = (live(app), app.try_state::<Store>()) else {
        return;
    };
    let items = store.recent(RECENT);
    for old in live.recent.items().unwrap_or_default() {
        let _ = live.recent.remove(&old);
    }
    if items.is_empty() {
        if let Ok(none) = MenuItem::with_id(app, "recent-none", NO_DICTATIONS, false, None::<&str>)
        {
            let _ = live.recent.append(&none);
        }
    }
    for (n, (label, _)) in items.iter().enumerate() {
        if let Ok(entry) = MenuItem::with_id(app, format!("recent-{n}"), label, true, None::<&str>)
        {
            let _ = live.recent.append(&entry);
        }
    }
    if let Ok(mut state) = live.state.lock() {
        state.texts = items.into_iter().map(|(_, text)| text).collect();
    };
}

fn copy_recent(app: &AppHandle, n: usize) {
    let Some(live) = live(app) else { return };
    let text = live.state.lock().ok().and_then(|s| s.texts.get(n).cloned());
    if let Some(text) = text {
        let _ = crate::commands::copy_to_clipboard(app, &text);
    }
}

fn show_status(app: &AppHandle, change: impl FnOnce(&mut State)) {
    let Some(live) = live(app) else { return };
    let Ok(mut state) = live.state.lock() else {
        return;
    };
    change(&mut state);
    let _ = live
        .status
        .set_text(status_line(&state.shortcut, state.listening));
}

/// The shortcut changed in Settings.
pub fn set_shortcut(app: &AppHandle, shortcut: &str) {
    show_status(app, |s| s.shortcut = shortcut.to_string());
}

/// A dark microphone on a light taskbar, a light one on a dark taskbar.
fn icon_for_taskbar() -> &'static [u8] {
    #[cfg(windows)]
    let light_taskbar = crate::windows_shell::taskbar_is_light();
    #[cfg(not(windows))]
    let light_taskbar = false;

    if light_taskbar {
        DARK_INK
    } else {
        LIGHT_INK
    }
}

#[cfg(windows)]
/// While loqui listens the icon is magenta and pulses: call this with
/// `Some(bright)` on each beat, and `None` when it stops.
pub fn show_recording(app: &AppHandle, beat: Option<bool>) {
    let listening = beat.is_some();
    if live(app).is_some_and(|l| l.state.lock().is_ok_and(|s| s.listening != listening)) {
        show_status(app, |s| s.listening = listening);
    }
    let Some(tray) = app.tray_by_id(ID) else {
        return;
    };
    let (icon, tip) = match beat {
        Some(true) => (RECORDING, "loqui is listening"),
        Some(false) => (RECORDING_DIM, "loqui is listening"),
        None => (icon_for_taskbar(), "loqui"),
    };
    if let Ok(image) = Image::from_bytes(icon) {
        let _ = tray.set_icon(Some(image));
    }
    let _ = tray.set_tooltip(Some(tip));
}

#[cfg(test)]
mod tests {
    use super::status_line;

    #[test]
    fn menu_01_the_first_line_names_the_current_shortcut() {
        assert_eq!(
            status_line("Ctrl+Shift+Space", false),
            "Press Ctrl+Shift+Space to dictate"
        );
        assert_eq!(
            status_line("Ctrl+Alt+D", true),
            "Listening: press Ctrl+Alt+D to stop"
        );
    }
}
