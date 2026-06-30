import AppKit
import Combine

/// The user-configurable global trigger: a key plus its required modifiers.
/// `VoiceKeyService` matches incoming events against this; the Settings window
/// records new ones. Persisted in UserDefaults.
struct HotShortcut: Codable, Equatable {
    /// Virtual keycode (CGKeyCode / NSEvent.keyCode space).
    var keyCode: Int64
    /// Required modifiers — raw value of an `NSEvent.ModifierFlags` subset.
    var modifiers: UInt

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    /// Default trigger: ⌘R — familiar and works out of the box; fully reconfigurable.
    static let `default` = HotShortcut(keyCode: 15, modifiers: NSEvent.ModifierFlags.command.rawValue)

    /// Does this incoming event's modifier state EXACTLY match what the shortcut
    /// requires? Exact match means ⌘⇧R passes through when the shortcut is ⌘R.
    /// The fn flag is ignored — bare function keys arrive carrying it.
    func modifiersMatch(_ flags: CGEventFlags) -> Bool {
        let m = modifierFlags
        let pairs: [(NSEvent.ModifierFlags, CGEventFlags)] = [
            (.command, .maskCommand), (.control, .maskControl),
            (.option, .maskAlternate), (.shift, .maskShift),
        ]
        for (ns, cg) in pairs where m.contains(ns) != flags.contains(cg) { return false }
        return true
    }

    /// A combo is allowed as a global trigger only if it carries a real modifier
    /// (⌘/⌃/⌥) OR is a bare function key — otherwise it would hijack typing.
    static func isAcceptable(keyCode: Int64, modifiers: NSEvent.ModifierFlags) -> Bool {
        let hasModifier = !modifiers.intersection([.command, .control, .option]).isEmpty
        return hasModifier || functionKeyCodes.contains(keyCode)
    }

    /// F1–F15. Bare function keys are safe, conflict-light triggers.
    static let functionKeyCodes: Set<Int64> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, // F1–F12
        105, 107, 113,                                          // F13–F15
    ]

    /// Human-readable form, e.g. "⌘R", "⌃⌥Space", "F5".
    var display: String {
        let m = modifierFlags
        var s = ""
        if m.contains(.control) { s += "⌃" }
        if m.contains(.option) { s += "⌥" }
        if m.contains(.shift) { s += "⇧" }
        if m.contains(.command) { s += "⌘" }
        if m.contains(.function) { s += "fn " }
        return s + Self.keyName(keyCode)
    }

    static func keyName(_ code: Int64) -> String {
        if let f = functionKeyName[code] { return f }
        if let n = keyNames[code] { return n }
        return "key \(code)"
    }

    private static let functionKeyName: [Int64: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",
    ]

    private static let keyNames: [Int64: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

/// Stores the active shortcut in UserDefaults and publishes changes so the menu
/// bar label and Settings stay in sync. Accessed only from the main thread (the
/// event tap reads it inside `MainActor.assumeIsolated`; the recorder writes it
/// from the main-thread event monitor).
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    @Published var shortcut: HotShortcut { didSet { save() } }

    private let defaultsKey = "loqui.shortcut"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(HotShortcut.self, from: data) {
            shortcut = decoded
        } else {
            shortcut = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
