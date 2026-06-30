import Foundation

/// The single source of truth for transcript-cleanup settings, shared by
/// `TextCleanup` (which applies them) and the Settings window (which edits
/// them). Persisted as `~/Library/Application Support/Loqui/cleanup.json`.
struct CleanupConfig: Codable, Equatable {
    var dictionary: [String: String]
    var removeFillers: Bool
    var fillers: [String]
    var spokenFormatting: Bool

    // Shipped defaults are generic — the spelling dictionary starts empty so a
    // fresh install carries no personal data. The user builds their own via the
    // Settings window. (James's existing dictionary rides along in his migrated
    // cleanup.json, so his running copy keeps his terms.)
    static let defaults = CleanupConfig(
        dictionary: [:],
        removeFillers: true,
        // Only the unambiguous fillers by default — "like", "you know", "so",
        // "I mean" are real words too, so they're left out unless added.
        fillers: ["um", "umm", "uh", "uhh", "uhm", "er", "erm", "hmm", "mhm"],
        // Off by default: "new paragraph" / "new line" can be literal content.
        spokenFormatting: false
    )
}

/// Disk persistence. Used directly by `TextCleanup` (re-read on every cleanup
/// so edits are live) and by the Settings store.
enum CleanupConfigFile {
    static var url: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Loqui", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("cleanup.json")
    }

    /// Load, seeding the file with defaults on first run. A file that exists
    /// but won't parse is left untouched (so a typo can be fixed) and defaults
    /// are returned for this read.
    static func load() -> CleanupConfig {
        let u = url
        if FileManager.default.fileExists(atPath: u.path) {
            if let data = try? Data(contentsOf: u),
               let cfg = try? JSONDecoder().decode(CleanupConfig.self, from: data) {
                return cfg
            }
            return .defaults
        }
        save(.defaults)
        return .defaults
    }

    static func save(_ cfg: CleanupConfig) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(cfg) { try? data.write(to: url) }
    }
}
