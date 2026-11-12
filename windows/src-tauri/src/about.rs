//! The About window, opened from the tray menu. Only one is ever open.

use tauri::{AppHandle, Manager, WebviewUrl, WebviewWindowBuilder};

const LABEL: &str = "about";

pub fn show(app: &AppHandle) {
    if let Some(window) = app.get_webview_window(LABEL) {
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
        return;
    }
    let opened = WebviewWindowBuilder::new(app, LABEL, WebviewUrl::App("index.html".into()))
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
