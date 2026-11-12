//! The dictation bubble (the Mac's HUD): a see-through window that stays on
//! top at the bottom centre of the screen you're working on. It is never
//! activated and ignores the mouse, so the cursor stays where you're typing.
//!
//! loqui tells the page what to show by calling `window.bubble(state)`, so the
//! page needs no access to loqui at all. The window's title names the phase
//! too ("loqui listening"), which is how the Windows check watches it.

use crate::screens;
use std::time::{Duration, Instant};
use tauri::{AppHandle, WebviewWindow};
use windows_sys::Win32::Foundation::{HWND, RECT};
use windows_sys::Win32::Graphics::Gdi::{
    GetMonitorInfoW, MonitorFromWindow, MONITORINFO, MONITOR_DEFAULTTOPRIMARY,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    GetForegroundWindow, GetWindowLongPtrW, GetWindowRect, SetWindowLongPtrW, SetWindowPos,
    ShowWindow, GWL_EXSTYLE, HWND_TOPMOST, SWP_NOACTIVATE, SWP_NOSIZE, SWP_SHOWWINDOW, SW_HIDE,
    SW_SHOWNOACTIVATE, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW,
};

pub const MIC_BLOCKED: &str =
    "Windows is blocking the microphone. Turn on \u{201c}Let desktop apps access your microphone\u{201d} in Settings, then try again.";
pub const NO_MIC: &str = "loqui can't find a microphone.";
pub const MIC_FAILED: &str = "loqui can't use the microphone right now. Try again in a moment.";
pub const PASTE_REFUSED: &str =
    "This window won\u{2019}t accept typing from loqui. Your text is on the clipboard: press Ctrl+V.";
pub const NO_CLIPBOARD: &str =
    "loqui couldn't reach the clipboard, so nothing was pasted. Try again.";
pub const NO_ENGINE: &str = "loqui couldn't load its speech model. Reinstall loqui to fix it.";

pub struct Bubble {
    window: WebviewWindow,
    hide_at: Option<Instant>,
}

impl Bubble {
    /// Made hidden when loqui starts, so it's ready the first time it's needed.
    pub fn create(app: &AppHandle) -> tauri::Result<Self> {
        let window = screens::builder(app, "bubble", "bubble.html")
            .title("loqui hidden")
            .inner_size(720.0, 200.0)
            .transparent(true)
            .decorations(false)
            .shadow(false)
            .resizable(false)
            .always_on_top(true)
            .skip_taskbar(true)
            .focused(false)
            .focusable(false)
            .visible(false)
            .build()?;
        window.set_ignore_cursor_events(true)?;
        let hwnd = window.hwnd()?.0 as HWND;
        // SAFETY: the window is ours and alive.
        unsafe {
            let style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
            SetWindowLongPtrW(
                hwnd,
                GWL_EXSTYLE,
                style | (WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW) as isize,
            );
        }
        Ok(Self {
            window,
            hide_at: None,
        })
    }

    pub fn hwnd(&self) -> Option<HWND> {
        self.window.hwnd().ok().map(|h| h.0 as HWND)
    }

    fn send(&self, phase: &str, level: f64, message: &str) {
        let state = serde_json::json!({ "phase": phase, "level": level, "message": message });
        let _ = self
            .window
            .eval(format!("window.bubble && window.bubble({state})"));
    }

    fn title(&self, phase: &str, message: &str) {
        let title = if message.is_empty() {
            format!("loqui {phase}")
        } else {
            format!("loqui {phase}: {message}")
        };
        let _ = self.window.set_title(&title);
    }

    /// Bottom centre of the screen holding the window you're typing in, shown
    /// without taking the cursor.
    fn show(&self) {
        let Some(hwnd) = self.hwnd() else { return };
        // SAFETY: plain window queries and moves; every struct is sized.
        unsafe {
            let monitor = MonitorFromWindow(GetForegroundWindow(), MONITOR_DEFAULTTOPRIMARY);
            let mut info: MONITORINFO = std::mem::zeroed();
            info.cbSize = std::mem::size_of::<MONITORINFO>() as u32;
            let mut own: RECT = std::mem::zeroed();
            if GetMonitorInfoW(monitor, &mut info) == 0 || GetWindowRect(hwnd, &mut own) == 0 {
                return;
            }
            let work = info.rcWork;
            let (w, h) = (own.right - own.left, own.bottom - own.top);
            let x = work.left + (work.right - work.left - w) / 2;
            let y = work.bottom - h;
            SetWindowPos(
                hwnd,
                HWND_TOPMOST,
                x,
                y,
                0,
                0,
                SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW,
            );
            ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        }
    }

    fn present(&mut self, phase: &str, message: &str, seconds: Option<f64>) {
        self.title(phase, message);
        self.send(phase, 0.0, message);
        self.show();
        self.hide_at = seconds.map(|s| Instant::now() + Duration::from_secs_f64(s));
    }

    pub fn listening(&mut self) {
        self.present("listening", "", None);
    }

    /// The live microphone level, many times a second while listening.
    pub fn level(&self, level: f64) {
        self.send("listening", level, "");
    }

    pub fn finishing(&mut self) {
        self.present("finishing", "", None);
    }

    pub fn pasted(&mut self) {
        self.present("pasted", "", Some(0.9));
    }

    pub fn notice(&mut self, message: &str, seconds: f64) {
        self.present("notice", message, Some(seconds));
    }

    pub fn hide(&mut self) {
        self.hide_at = None;
        if let Some(hwnd) = self.hwnd() {
            // SAFETY: the window is ours.
            unsafe { ShowWindow(hwnd, SW_HIDE) };
        }
        self.title("hidden", "");
        self.send("hidden", 0.0, "");
    }

    /// Hide a pasted or notice bubble once its time is up.
    pub fn tick(&mut self, now: Instant) {
        if self.hide_at.is_some_and(|at| now >= at) {
            self.hide();
        }
    }
}
