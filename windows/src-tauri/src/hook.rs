//! Watching the keyboard for the shortcut (the Mac's event tap).
//!
//! A low-level keyboard hook on its own thread with a message loop. Windows
//! silently removes a hook that answers slowly, so the callback only asks
//! `KeyFilter` whether this is the shortcut and posts a press or release to
//! loqui's dictation thread. It acts only on the shortcut and records no keys.

use crate::dictation::Event;
use loqui_core::voice_key::{Edge, KeyFilter};
use loqui_core::{Mods, Shortcut};
use std::sync::mpsc::Sender;
use std::sync::{Mutex, OnceLock};
use std::time::Instant;
use windows_sys::Win32::Foundation::{LPARAM, LRESULT, WPARAM};
use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    GetAsyncKeyState, SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT, KEYEVENTF_KEYUP,
    VIRTUAL_KEY, VK_CONTROL, VK_LWIN, VK_MENU, VK_RWIN, VK_SHIFT,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    CallNextHookEx, GetMessageW, SetWindowsHookExW, HC_ACTION, KBDLLHOOKSTRUCT, MSG,
    WH_KEYBOARD_LL, WM_KEYDOWN, WM_KEYUP, WM_SYSKEYDOWN, WM_SYSKEYUP,
};

/// Marks the keys loqui types itself (its Ctrl+V), so the hook lets them by.
/// Other injected keys are treated like typing: the checks rely on that.
pub const OWN_KEYS: usize = 0x4C51_5549; // "LQUI"

/// An unassigned key, tapped after an Alt or Windows-key shortcut so letting
/// go of Alt doesn't open the app's menu bar, or Windows the Start menu.
const MASK_KEY: VIRTUAL_KEY = 0xE8;

struct Watch {
    shortcut: Shortcut,
    /// Settings is recording a new shortcut: every key goes to it untouched.
    paused: bool,
    filter: KeyFilter,
    events: Sender<Event>,
    clock: Instant,
}

static WATCH: OnceLock<Mutex<Watch>> = OnceLock::new();

/// Start watching for `shortcut`. Presses and releases go to `events`.
pub fn start(shortcut: Shortcut, events: Sender<Event>, clock: Instant) -> std::io::Result<()> {
    let watch = Watch {
        shortcut,
        paused: false,
        filter: KeyFilter::default(),
        events,
        clock,
    };
    if WATCH.set(Mutex::new(watch)).is_err() {
        return Ok(());
    }
    let (ready, installed) = std::sync::mpsc::channel();
    std::thread::Builder::new()
        .name("loqui keyboard".into())
        .spawn(move || {
            // SAFETY: a null module name means this program; the callback is a
            // plain function that lives as long as the program.
            let hook = unsafe {
                SetWindowsHookExW(
                    WH_KEYBOARD_LL,
                    Some(callback),
                    GetModuleHandleW(std::ptr::null()),
                    0,
                )
            };
            let _ = ready.send(!hook.is_null());
            if hook.is_null() {
                return;
            }
            // The hook's callbacks arrive through this thread's message loop.
            let mut msg: MSG = unsafe { std::mem::zeroed() };
            // SAFETY: `msg` is a valid MSG to fill.
            while unsafe { GetMessageW(&mut msg, std::ptr::null_mut(), 0, 0) } > 0 {}
        })?;
    match installed.recv() {
        Ok(true) => Ok(()),
        _ => Err(std::io::Error::last_os_error()),
    }
}

fn with_watch(change: impl FnOnce(&mut Watch)) {
    if let Some(Ok(mut w)) = WATCH.get().map(Mutex::lock) {
        change(&mut w);
    }
}

/// Watch for a new shortcut from now on; the old one reaches apps again.
pub fn set_shortcut(shortcut: Shortcut) {
    with_watch(|w| {
        w.shortcut = shortcut;
        w.filter = KeyFilter::default();
    });
}

/// Stop acting on the shortcut while Settings records a new one (the Mac's
/// suspend), or start again.
pub fn pause(paused: bool) {
    with_watch(|w| {
        w.paused = paused;
        w.filter = KeyFilter::default();
    });
}

fn held(key: VIRTUAL_KEY) -> bool {
    // SAFETY: no pointers; the high bit means the key is down.
    unsafe { GetAsyncKeyState(i32::from(key)) < 0 }
}

fn mods() -> Mods {
    Mods {
        ctrl: held(VK_CONTROL),
        alt: held(VK_MENU),
        shift: held(VK_SHIFT),
        win: held(VK_LWIN) || held(VK_RWIN),
    }
}

unsafe extern "system" fn callback(code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    if code == HC_ACTION as i32 {
        // SAFETY: for HC_ACTION, lparam points at the event's KBDLLHOOKSTRUCT.
        let event = unsafe { &*(lparam as *const KBDLLHOOKSTRUCT) };
        if event.dwExtraInfo != OWN_KEYS && consider(event.vkCode as u16, wparam as u32) {
            return 1;
        }
    }
    // SAFETY: passing the event on, unchanged.
    unsafe { CallNextHookEx(std::ptr::null_mut(), code, wparam, lparam) }
}

/// Whether to swallow this key event.
fn consider(key: u16, message: u32) -> bool {
    let Some(watch) = WATCH.get() else {
        return false;
    };
    let (verdict, mask) = {
        let Ok(mut w) = watch.lock() else {
            return false;
        };
        if w.paused {
            return false;
        }
        let now = w.clock.elapsed().as_secs_f64();
        let shortcut = w.shortcut;
        let verdict = match message {
            WM_KEYDOWN | WM_SYSKEYDOWN => w.filter.key_down(&shortcut, key, mods(), now),
            WM_KEYUP | WM_SYSKEYUP => w.filter.key_up(key),
            _ => return false,
        };
        if let Some(edge) = verdict.edge {
            let _ = w.events.send(Event::Key(edge, now));
        }
        let mask = verdict.edge == Some(Edge::Press) && (shortcut.mods.alt || shortcut.mods.win);
        (verdict, mask)
    };
    if mask {
        tap(MASK_KEY);
    }
    verdict.swallow
}

fn key(vk: VIRTUAL_KEY, flags: u32) -> INPUT {
    INPUT {
        r#type: INPUT_KEYBOARD,
        Anonymous: INPUT_0 {
            ki: KEYBDINPUT {
                wVk: vk,
                wScan: 0,
                dwFlags: flags,
                time: 0,
                dwExtraInfo: OWN_KEYS,
            },
        },
    }
}

/// Type keys as loqui (marked, so the hook ignores them). Each entry is a
/// key and whether it's a key-up.
pub fn type_keys(keys: &[(VIRTUAL_KEY, bool)]) -> u32 {
    let inputs: Vec<INPUT> = keys
        .iter()
        .map(|&(vk, up)| key(vk, if up { KEYEVENTF_KEYUP } else { 0 }))
        .collect();
    // SAFETY: the slice and its length and element size match.
    unsafe {
        SendInput(
            inputs.len() as u32,
            inputs.as_ptr(),
            std::mem::size_of::<INPUT>() as i32,
        )
    }
}

fn tap(vk: VIRTUAL_KEY) {
    type_keys(&[(vk, false), (vk, true)]);
}

/// Whether any modifier is still held.
pub fn modifiers_held() -> bool {
    let m = mods();
    m.alt || m.shift || m.win
}
