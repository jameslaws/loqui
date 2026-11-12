//! The few things loqui asks Windows itself.

use std::ffi::c_void;
use std::ptr::{null, null_mut};
use windows_sys::Win32::Foundation::ERROR_SUCCESS;
use windows_sys::Win32::System::Registry::{
    RegDeleteKeyValueW, RegGetValueW, RegSetKeyValueW, HKEY, HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE,
    REG_SZ, RRF_RT_REG_DWORD, RRF_RT_REG_SZ,
};
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
        open(WEBVIEW_PAGE);
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

/// A text value from the registry, if it's there.
fn registry_text(root: HKEY, key: &str, name: &str) -> Option<String> {
    let (key, name) = (wide(key), wide(name));
    let mut buffer = [0u16; 512];
    let mut size = std::mem::size_of_val(&buffer) as u32;
    // SAFETY: every pointer is valid for the call and `size` is the buffer's size in bytes.
    let status = unsafe {
        RegGetValueW(
            root,
            key.as_ptr(),
            name.as_ptr(),
            RRF_RT_REG_SZ,
            null_mut(),
            buffer.as_mut_ptr().cast::<c_void>(),
            &mut size,
        )
    };
    if status != ERROR_SUCCESS {
        return None;
    }
    let len = buffer.iter().position(|&c| c == 0).unwrap_or(buffer.len());
    Some(String::from_utf16_lossy(&buffer[..len]))
}

const MICROPHONE: &str =
    r"Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone";

/// Whether Windows lets desktop apps use the microphone: the PC-wide switch,
/// "Let apps access your microphone" and "Let desktop apps access your
/// microphone" all on. loqui only reads them; it never changes them.
pub fn microphone_allowed() -> bool {
    let desktop = format!(r"{MICROPHONE}\NonPackaged");
    let switches = [
        (HKEY_LOCAL_MACHINE, MICROPHONE),
        (HKEY_CURRENT_USER, MICROPHONE),
        (HKEY_CURRENT_USER, desktop.as_str()),
    ];
    for (root, key) in switches {
        if registry_text(root, key, "Value").is_some_and(|v| v.eq_ignore_ascii_case("Deny")) {
            return false;
        }
    }
    true
}

fn open(target: &str) {
    let (verb, target) = (wide("open"), wide(target));
    // SAFETY: both strings are null-terminated; the rest may be null.
    unsafe {
        ShellExecuteW(
            null_mut(),
            verb.as_ptr(),
            target.as_ptr(),
            null(),
            null(),
            SW_SHOWNORMAL,
        );
    }
}

/// Windows Settings, Privacy & security, Microphone.
pub fn open_microphone_settings() {
    open("ms-settings:privacy-microphone");
}

const RUN: &str = r"Software\Microsoft\Windows\CurrentVersion\Run";

/// Start loqui when this person signs in, or not: the per-user Run entry, so
/// no administrator is needed.
pub fn start_at_sign_in(on: bool) -> Result<(), String> {
    let (key, name) = (wide(RUN), wide("loqui"));
    let status = if on {
        let exe = std::env::current_exe().map_err(|e| e.to_string())?;
        let value = wide(&format!("\"{}\"", exe.display()));
        // SAFETY: the strings are null-terminated and `value`'s size is given in bytes.
        unsafe {
            RegSetKeyValueW(
                HKEY_CURRENT_USER,
                key.as_ptr(),
                name.as_ptr(),
                REG_SZ,
                value.as_ptr().cast::<c_void>(),
                (value.len() * 2) as u32,
            )
        }
    } else {
        // SAFETY: as above.
        match unsafe { RegDeleteKeyValueW(HKEY_CURRENT_USER, key.as_ptr(), name.as_ptr()) } {
            2 => ERROR_SUCCESS, // ERROR_FILE_NOT_FOUND: already gone
            status => status,
        }
    };
    if status == ERROR_SUCCESS {
        Ok(())
    } else {
        Err(format!(
            "Windows didn't save the sign-in setting (error {status})"
        ))
    }
}
