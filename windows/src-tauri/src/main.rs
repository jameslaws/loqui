//! loqui for Windows: it sits in the notification area, and when you press
//! the shortcut and speak, clean text lands wherever you're typing. The
//! speech is turned into text on the PC itself.

// No console window behind the app in release builds.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod about;
#[cfg(windows)]
mod bubble;
#[cfg(windows)]
mod dictation;
#[cfg(windows)]
mod hook;
#[cfg(windows)]
mod mic;
#[cfg(windows)]
mod paste;
#[cfg(windows)]
mod speech;
mod tray;
#[cfg(windows)]
mod windows_shell;

use tauri::RunEvent;

fn main() {
    // Windows 11 includes the web view the screens are drawn in. If it is
    // missing, say so and point to Microsoft's page instead of downloading it.
    #[cfg(windows)]
    if tauri::webview_version().is_err() {
        windows_shell::explain_missing_webview();
        return;
    }

    tauri::Builder::default()
        .setup(|app| {
            tray::install(app.handle())?;
            #[cfg(windows)]
            if let Err(e) = dictation::start(app.handle()) {
                windows_shell::explain_no_dictation(&e);
            }
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("loqui could not start")
        .run(|_app, event| {
            // Closing the About window must not end loqui; only Quit does.
            if let RunEvent::ExitRequested {
                code: None, api, ..
            } = event
            {
                api.prevent_exit();
            }
        });
}
