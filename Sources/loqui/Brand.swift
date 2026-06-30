import AppKit
import SwiftUI

/// loqui brand magenta (#E91E63) — one source of truth, used by the HUD, stats,
/// history, and onboarding so the accent can never drift.
extension Color {
    static let loquiMagenta = Color(red: 233.0 / 255.0, green: 30.0 / 255.0, blue: 99.0 / 255.0)
}

extension NSColor {
    static let loquiMagenta = NSColor(red: 233.0 / 255.0, green: 30.0 / 255.0, blue: 99.0 / 255.0, alpha: 1)
}
