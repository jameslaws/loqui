//! loqui for Windows: it sits in the notification area, and when you press
//! the shortcut and speak, clean text lands wherever you're typing. The
//! speech is turned into text on the PC itself.

// No console window behind the app in release builds.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod about;
#[cfg(windows)]
mod bubble;
mod commands;
#[cfg(windows)]
mod dictation;
#[cfg(windows)]
mod hook;
#[cfg(windows)]
mod mic;
#[cfg(windows)]
mod paste;
mod screens;
#[cfg(windows)]
mod speech;
mod stats;
mod tray;
mod updates;
#[cfg(windows)]
mod windows_shell;

use loqui_core::commands::Store;
use tauri::{Manager, RunEvent};

fn main() {
    // Windows 11 includes the web view the screens are drawn in. If it is
    // missing, say so and point to Microsoft's page instead of downloading it.
    #[cfg(windows)]
    if tauri::webview_version().is_err() {
        windows_shell::explain_missing_webview();
        return;
    }

    tauri::Builder::default()
        .plugin(tauri_plugin_updater::Builder::new().build())
        .invoke_handler(tauri::generate_handler![
            commands::general,
            commands::begin_shortcut,
            commands::end_shortcut,
            commands::set_shortcut,
            commands::set_fillers,
            commands::set_retention,
            commands::set_start_at_sign_in,
            commands::dictionary,
            commands::set_dictionary,
            commands::history,
            commands::delete_history,
            commands::clear_history,
            commands::copy_text,
            commands::welcome,
            commands::open_microphone_settings,
            commands::finish_welcome,
            commands::close_window,
            stats::stats,
            updates::updates,
            updates::check_for_updates,
            updates::install_update,
            updates::set_test_versions,
        ])
        .setup(|app| {
            let dir = loqui_core::records::data_dir()
                .unwrap_or_else(|| std::env::temp_dir().join("Loqui"));
            let store = Store::new(dir);
            let settings = store.settings().settings;
            app.manage(store);
            tray::install(app.handle(), &settings.shortcut.to_string())?;
            // Checks as loqui starts and once a day; not from development builds,
            // which Check for updates still can.
            updates::start(app.handle(), !cfg!(debug_assertions));
            #[cfg(windows)]
            {
                if let Err(e) = dictation::start(app.handle()) {
                    windows_shell::explain_no_dictation(&e);
                }
                // Keep the sign-in entry pointing at this copy of loqui (an
                // update or a move changes where it is). Not for development builds.
                if !cfg!(debug_assertions) {
                    let _ = windows_shell::start_at_sign_in(settings.start_at_sign_in);
                }
            }
            if !settings.onboarded {
                screens::welcome(app.handle());
            }
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("loqui could not start")
        .run(|_app, event| {
            // Closing a window must not end loqui; only Quit does.
            if let RunEvent::ExitRequested {
                code: None, api, ..
            } = event
            {
                api.prevent_exit();
            }
        });
}
