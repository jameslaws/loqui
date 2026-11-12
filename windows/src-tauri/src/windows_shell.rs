//! The few things loqui asks Windows itself.

use std::ffi::c_void;
use std::ptr::{null, null_mut};
use windows_sys::Win32::Foundation::ERROR_SUCCESS;
use windows_sys::Win32::System::Registry::{RegGetValueW, HKEY_CURRENT_USER, RRF_RT_REG_DWORD};
use windows_sys::Win32::UI::Shell::ShellExecuteW;
use windows_sys::Win32::UI::WindowsAndMessaging::{
    MessageBoxW, IDYES, MB_ICONWARNING, MB_YESNO, SW_SHOWNORMAL,
};

const WEBVIEW_PAGE: &str = "https://developer.microsoft.com/microsoft-edge/webview2/";

fn wide(text: &str) -> Vec<u16> {
    text.encode_utf16().chain(Some(0)).collect()
}

/// Whether the taskbar is in light mode. Windows' own setting; dark if unreadable.
pub fn taskbar_is_light() -> bool {
    let key = wide(r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
    let name = wide("SystemUsesLightTheme");
    let mut value: u32 = 0;
    let mut size = std::mem::size_of::<u32>() as u32;
    // SAFETY: every pointer is valid for the call and `size` matches `value`.
    let status = unsafe {
        RegGetValueW(
            HKEY_CURRENT_USER,
            key.as_ptr(),
            name.as_ptr(),
            RRF_RT_REG_DWORD,
            null_mut(),
            (&mut value as *mut u32).cast::<c_void>(),
            &mut size,
        )
    };
    status == ERROR_SUCCESS && value == 1
}

/// One message, with the way to Microsoft's page for the missing web view.
pub fn explain_missing_webview() {
    let text = wide(
        "loqui needs Microsoft Edge WebView2, which comes with Windows 11 but is missing on this PC.\n\n\
         Open Microsoft's WebView2 page to install it?",
    );
    let title = wide("loqui");
    // SAFETY: both strings are null-terminated and outlive the call.
    let answer = unsafe {
        MessageBoxW(
            null_mut(),
            text.as_ptr(),
            title.as_ptr(),
            MB_YESNO | MB_ICONWARNING,
        )
    };
    if answer == IDYES {
        let open = wide("open");
        let page = wide(WEBVIEW_PAGE);
        // SAFETY: as above; the remaining pointers may be null.
        unsafe {
            ShellExecuteW(
                null_mut(),
                open.as_ptr(),
                page.as_ptr(),
                null(),
                null(),
                SW_SHOWNORMAL,
            );
        }
    }
}

/// Dictation couldn't start at all: say so once, and keep loqui running.
pub fn explain_no_dictation(why: &str) {
    let text = wide(&format!("loqui can't start dictation on this PC.\n\n{why}"));
    let title = wide("loqui");
    // SAFETY: both strings are null-terminated and outlive the call.
    unsafe {
        MessageBoxW(null_mut(), text.as_ptr(), title.as_ptr(), MB_ICONWARNING);
    }
}
