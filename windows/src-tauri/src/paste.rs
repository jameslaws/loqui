//! Putting the text where you were typing: on the clipboard, then Ctrl+V.
//!
//! The clipboard copy is marked so Windows keeps it out of clipboard history
//! and doesn't sync it to the person's Microsoft account (plan decision 4).
//! A window running at a higher level than loqui (run as administrator)
//! ignores keys typed by loqui, so loqui doesn't try; the text is on the
//! clipboard and the bubble says to press Ctrl+V.

use crate::hook;
use std::time::{Duration, Instant};
use windows_sys::Win32::Foundation::{CloseHandle, GlobalFree, HANDLE, HWND};
use windows_sys::Win32::Security::{
    GetSidSubAuthority, GetSidSubAuthorityCount, GetTokenInformation, TokenIntegrityLevel,
    TOKEN_MANDATORY_LABEL, TOKEN_QUERY,
};
use windows_sys::Win32::System::DataExchange::{
    CloseClipboard, EmptyClipboard, OpenClipboard, RegisterClipboardFormatW, SetClipboardData,
};
use windows_sys::Win32::System::Memory::{GlobalAlloc, GlobalLock, GlobalUnlock, GMEM_MOVEABLE};
use windows_sys::Win32::System::Ole::CF_UNICODETEXT;
use windows_sys::Win32::System::Threading::{
    GetCurrentProcess, OpenProcess, OpenProcessToken, PROCESS_QUERY_LIMITED_INFORMATION,
};
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{VK_CONTROL, VK_V};
use windows_sys::Win32::UI::WindowsAndMessaging::{GetForegroundWindow, GetWindowThreadProcessId};

fn wide(text: &str) -> Vec<u16> {
    text.encode_utf16().chain(Some(0)).collect()
}

/// A movable global block holding `bytes`, as the clipboard wants. The
/// clipboard owns it once `SetClipboardData` accepts it.
fn global(bytes: &[u8]) -> Option<HANDLE> {
    // SAFETY: the block is allocated, locked, filled within its size and unlocked.
    unsafe {
        let block = GlobalAlloc(GMEM_MOVEABLE, bytes.len());
        if block.is_null() {
            return None;
        }
        let at = GlobalLock(block).cast::<u8>();
        if at.is_null() {
            GlobalFree(block);
            return None;
        }
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), at, bytes.len());
        GlobalUnlock(block);
        Some(block)
    }
}

fn put(format: u32, bytes: &[u8]) -> bool {
    let Some(block) = global(bytes) else {
        return false;
    };
    // SAFETY: the clipboard is open; on failure the block is still ours to free.
    unsafe {
        if SetClipboardData(format, block).is_null() {
            GlobalFree(block);
            return false;
        }
    }
    true
}

/// Put `text` on the clipboard, kept out of history and cloud sync.
pub fn set_clipboard(text: &str) -> Result<(), String> {
    // Another program may hold the clipboard for a moment.
    let mut open = false;
    for _ in 0..20 {
        // SAFETY: no pointers; a null owner is allowed.
        if unsafe { OpenClipboard(std::ptr::null_mut()) } != 0 {
            open = true;
            break;
        }
        std::thread::sleep(Duration::from_millis(25));
    }
    if !open {
        return Err("the clipboard is busy".into());
    }
    let text: Vec<u8> = wide(text).iter().flat_map(|u| u.to_le_bytes()).collect();
    // SAFETY: the clipboard is open on this thread until CloseClipboard.
    let ok = unsafe {
        EmptyClipboard();
        let mut ok = put(u32::from(CF_UNICODETEXT), &text);
        for name in ["CanIncludeInClipboardHistory", "CanUploadToCloudClipboard"] {
            let format = RegisterClipboardFormatW(wide(name).as_ptr());
            ok &= format != 0 && put(format, &0u32.to_le_bytes());
        }
        CloseClipboard();
        ok
    };
    if ok {
        Ok(())
    } else {
        Err("Windows didn't take the text onto the clipboard".into())
    }
}

/// The integrity level (low, medium, high, system) of a process token.
fn integrity(token: HANDLE) -> Option<u32> {
    let mut size = 0u32;
    // SAFETY: the first call only reports the size; the buffer is that size
    // and the label and SID pointers point inside it.
    unsafe {
        GetTokenInformation(
            token,
            TokenIntegrityLevel,
            std::ptr::null_mut(),
            0,
            &mut size,
        );
        let mut buffer = vec![0u8; size as usize];
        if GetTokenInformation(
            token,
            TokenIntegrityLevel,
            buffer.as_mut_ptr().cast(),
            size,
            &mut size,
        ) == 0
        {
            return None;
        }
        let label = &*buffer.as_ptr().cast::<TOKEN_MANDATORY_LABEL>();
        let sid = label.Label.Sid;
        let count = *GetSidSubAuthorityCount(sid);
        Some(*GetSidSubAuthority(sid, u32::from(count) - 1))
    }
}

fn process_integrity(process: HANDLE) -> Option<u32> {
    let mut token: HANDLE = std::ptr::null_mut();
    // SAFETY: `token` is closed after use.
    unsafe {
        if OpenProcessToken(process, TOKEN_QUERY, &mut token) == 0 {
            return None;
        }
        let level = integrity(token);
        CloseHandle(token);
        level
    }
}

/// Whether the window you're typing in runs above loqui (as administrator),
/// so it would ignore loqui's Ctrl+V. If it can't be told, loqui tries.
pub fn target_refuses() -> bool {
    // SAFETY: plain queries; the process handle is closed after use.
    unsafe {
        let window: HWND = GetForegroundWindow();
        if window.is_null() {
            return false;
        }
        let mut pid = 0u32;
        GetWindowThreadProcessId(window, &mut pid);
        let process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
        if process.is_null() {
            return false;
        }
        let theirs = process_integrity(process);
        CloseHandle(process);
        let ours = process_integrity(GetCurrentProcess());
        matches!((theirs, ours), (Some(t), Some(o)) if t > o)
    }
}

/// Press Ctrl+V for the person, once they've let go of Shift, Alt and the
/// Windows key (held, they'd turn it into a different shortcut).
pub fn press_ctrl_v() -> bool {
    let waited = Instant::now();
    while hook::modifiers_held() && waited.elapsed() < Duration::from_secs(1) {
        std::thread::sleep(Duration::from_millis(15));
    }
    let sent = hook::type_keys(&[
        (VK_CONTROL, false),
        (VK_V, false),
        (VK_V, true),
        (VK_CONTROL, true),
    ]);
    sent == 4
}
