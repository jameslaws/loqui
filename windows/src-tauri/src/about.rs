//! The About window, opened from the tray menu. Only one is ever open.

use crate::screens;
use tauri::AppHandle;

const LABEL: &str = "about";

pub fn show(app: &AppHandle) {
    if screens::focus(app, LABEL) {
        return;
    }
    let opened = screens::builder(app, LABEL, "about.html")
        .title("About loqui")
        .inner_size(440.0, 330.0)
        .resizable(false)
        .maximizable(false)
        .minimizable(false)
        .center()
        .focused(true)
        .build();
    if let Err(error) = opened {
        eprintln!("loqui could not open the About window: {error}");
    }
}
