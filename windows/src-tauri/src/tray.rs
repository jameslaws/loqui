//! The loqui icon in the notification area and its menu.

use crate::about;
use tauri::image::Image;
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::AppHandle;

const DARK_INK: &[u8] = include_bytes!("../icons/tray/mic-dark-ink.png");
const LIGHT_INK: &[u8] = include_bytes!("../icons/tray/mic-light-ink.png");
#[cfg(windows)]
const RECORDING: &[u8] = include_bytes!("../icons/tray/mic-recording.png");
#[cfg(windows)]
const RECORDING_DIM: &[u8] = include_bytes!("../icons/tray/mic-recording-dim.png");
const ID: &str = "loqui";

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

    TrayIconBuilder::with_id(ID)
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

#[cfg(windows)]
/// While loqui listens the icon is magenta and pulses: call this with
/// `Some(bright)` on each beat, and `None` when it stops.
pub fn show_recording(app: &AppHandle, beat: Option<bool>) {
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
