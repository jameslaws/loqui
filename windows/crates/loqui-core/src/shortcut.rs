//! The dictation shortcut: one key plus the modifiers that must be held with it.
//!
//! Stored in `settings.json` as the text people see, such as "Ctrl+Shift+Space",
//! and set in Settings by pressing it (the recorder). Keys are Windows
//! virtual-key codes. The rules mirror the Mac's `HotShortcut`: Ctrl or Alt with
//! a key, or a bare function key, so a shortcut can never hijack plain typing.

use std::fmt;

/// Which modifiers are held. Left and right count the same.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Mods {
    pub ctrl: bool,
    pub alt: bool,
    pub shift: bool,
    pub win: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Shortcut {
    /// Windows virtual-key code of the main key.
    pub key: u16,
    pub mods: Mods,
}

/// What the recorder says about a shortcut that would get in the way of typing.
pub const REFUSED: &str = "Use Ctrl or Alt with a key, or a function key.";

const VK_SPACE: u16 = 0x20;
const VK_F1: u16 = 0x70;
const VK_F24: u16 = 0x87;

impl Default for Shortcut {
    /// Ctrl+Shift+Space: free in nearly every Windows app (plan decision 3).
    fn default() -> Self {
        Self {
            key: VK_SPACE,
            mods: Mods {
                ctrl: true,
                shift: true,
                ..Mods::default()
            },
        }
    }
}

impl Shortcut {
    /// Read "Ctrl+Shift+Space", "Alt+R" or "F9". Case and spaces don't matter.
    /// `None` for anything unknown or not allowed as a shortcut.
    pub fn parse(text: &str) -> Option<Self> {
        let mut mods = Mods::default();
        let mut key = None;
        for part in text.split('+').map(str::trim) {
            match part.to_ascii_lowercase().as_str() {
                "ctrl" | "control" => mods.ctrl = true,
                "alt" => mods.alt = true,
                "shift" => mods.shift = true,
                "win" | "windows" => mods.win = true,
                other if key.is_none() => key = Some(key_code(other)?),
                _ => return None,
            }
        }
        let shortcut = Self { key: key?, mods };
        shortcut.is_allowed().then_some(shortcut)
    }

    /// A shortcut someone pressed in the recorder, or why it can't be one.
    pub fn from_pressed(text: &str) -> Result<Self, &'static str> {
        Self::parse(text).ok_or(REFUSED)
    }

    /// The key caps to draw: "Ctrl", "Shift", "Space".
    pub fn keys(&self) -> Vec<String> {
        let m = self.mods;
        [
            (m.ctrl, "Ctrl"),
            (m.alt, "Alt"),
            (m.shift, "Shift"),
            (m.win, "Win"),
        ]
        .into_iter()
        .filter(|(on, _)| *on)
        .map(|(_, name)| name.to_string())
        .chain(Some(key_name(self.key)))
        .collect()
    }

    /// Ctrl or Alt with a key, or a bare F1 to F24.
    pub fn is_allowed(&self) -> bool {
        self.mods.ctrl || self.mods.alt || (VK_F1..=VK_F24).contains(&self.key)
    }

    /// Whether a key-down with these modifiers held is this shortcut. The
    /// modifiers must match exactly, so Ctrl+Alt+Shift+Space passes through
    /// when the shortcut is Ctrl+Shift+Space.
    pub fn matches(&self, key: u16, held: Mods) -> bool {
        key == self.key && held == self.mods
    }
}

impl fmt::Display for Shortcut {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.keys().join("+"))
    }
}

fn key_code(name: &str) -> Option<u16> {
    let bytes = name.as_bytes();
    match name {
        "space" => Some(VK_SPACE),
        _ if bytes.len() == 1 && bytes[0].is_ascii_alphanumeric() => {
            Some(u16::from(bytes[0].to_ascii_uppercase()))
        }
        _ => {
            let n: u16 = name.strip_prefix('f')?.parse().ok()?;
            (1..=24).contains(&n).then(|| VK_F1 + n - 1)
        }
    }
}

fn key_name(key: u16) -> String {
    match key {
        VK_SPACE => "Space".into(),
        VK_F1..=VK_F24 => format!("F{}", key - VK_F1 + 1),
        _ => match u8::try_from(key) {
            Ok(b) if b.is_ascii_alphanumeric() => char::from(b).to_string(),
            _ => format!("key {key}"),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_and_writes_the_text_people_see() {
        for text in ["Ctrl+Shift+Space", "Alt+R", "F9", "Ctrl+Alt+Win+7", "F24"] {
            assert_eq!(Shortcut::parse(text).unwrap().to_string(), text);
        }
        assert_eq!(
            Shortcut::parse(" ctrl + shift + space "),
            Some(Shortcut::default())
        );
    }

    #[test]
    fn refuses_shortcuts_that_would_hijack_typing() {
        for text in [
            "Space",
            "Shift+A",
            "R",
            "Win+R",
            "Ctrl+Shift",
            "Ctrl+Banana",
            "F25",
            "Ctrl+A+B",
            "",
        ] {
            assert_eq!(Shortcut::parse(text), None, "{text}");
        }
    }

    #[test]
    fn the_recorder_takes_ctrl_or_alt_with_a_key_or_a_bare_function_key() {
        assert_eq!(Shortcut::from_pressed("Shift+A"), Err(REFUSED));
        assert_eq!(Shortcut::from_pressed("A"), Err(REFUSED));
        let d = Shortcut::from_pressed("Ctrl+Alt+D").unwrap();
        assert_eq!(d.keys(), ["Ctrl", "Alt", "D"]);
        assert_eq!(Shortcut::from_pressed("F8").unwrap().keys(), ["F8"]);
        assert_eq!(Shortcut::default().keys(), ["Ctrl", "Shift", "Space"]);
    }

    #[test]
    fn modifiers_must_match_exactly() {
        let s = Shortcut::default();
        let held = |ctrl, alt, shift| Mods {
            ctrl,
            alt,
            shift,
            win: false,
        };
        assert!(s.matches(VK_SPACE, held(true, false, true)));
        assert!(!s.matches(VK_SPACE, held(true, false, false)));
        assert!(!s.matches(VK_SPACE, held(true, true, true)));
        assert!(!s.matches(u16::from(b'A'), held(true, false, true)));
    }
}
