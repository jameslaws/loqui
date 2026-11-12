//! The loqui icon in the notification area and its menu.

use crate::about;
use tauri::image::Image;
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::AppHandle;

const DARK_INK: &[u8] = include_bytes!("../icons/tray/mic-dark-ink.png");
const LIGHT_INK: &[u8] = include_bytes!("../icons/tray/mic-light-ink.png");

pub fn install(app: &AppHandle) -> tauri::Result<()> {
    let running = MenuItem::with_id(app, "running", "loqui is running", false, None::<&str>)?;
    let about = MenuItem::with_id(app, "about", "About loqui", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit loqui", true, None::<&str>)?;
    let menu = Menu::with_items(
        app,
        &[
            &running,
            &PredefinedMenuItem::separator(app)?,
            &about,
            &PredefinedMenuItem::separator(app)?,
            &quit,
        ],
    )?;

    TrayIconBuilder::with_id("loqui")
        .icon(Image::from_bytes(icon_for_taskbar())?)
        .tooltip("loqui")
        .menu(&menu)
        .show_menu_on_left_click(true)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "about" => about::show(app),
            "quit" => app.exit(0),
            _ => {}
        })
        .build(app)?;
    Ok(())
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
