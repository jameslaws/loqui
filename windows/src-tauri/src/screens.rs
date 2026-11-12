//! Every window loqui opens is made here, so each one gets the same quiet web
//! view: Microsoft's web view would otherwise reach Microsoft's servers by
//! itself (component updates, experiments, SmartScreen), which would break
//! loqui's promise that nothing leaves the PC. Its own background requests are
//! sent to a proxy that doesn't exist, and so go nowhere; loqui's pages are
//! served from inside the app and never touch the network.
//!
//! Screens opened from the tray menu are one instance each: opening one again
//! brings the open window to the front.

use tauri::{AppHandle, Manager, WebviewUrl, WebviewWindowBuilder};

/// Every web view in one app must share these arguments.
const QUIET: &str = "--disable-features=msWebOOUI,msPdfOOUI,msSmartScreenProtection \
     --disable-background-networking --disable-component-update --disable-domain-reliability \
     --disable-sync --no-pings --no-first-run \
     --proxy-server=http://127.0.0.1:9 --proxy-bypass-list=<-loopback>";

/// A window builder with the quiet web view.
pub fn builder<'a>(
    app: &'a AppHandle,
    label: &str,
    page: &str,
) -> WebviewWindowBuilder<'a, tauri::Wry, AppHandle> {
    WebviewWindowBuilder::new(app, label, WebviewUrl::App(page.into()))
        .additional_browser_args(QUIET)
}

/// Bring an open window to the front. False if it isn't open.
pub fn focus(app: &AppHandle, label: &str) -> bool {
    let Some(window) = app.get_webview_window(label) else {
        return false;
    };
    let _ = window.unminimize();
    let _ = window.show();
    let _ = window.set_focus();
    true
}
