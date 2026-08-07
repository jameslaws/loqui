import Foundation

/// The single source of truth for transcript-cleanup settings, shared by
/// `TextCleanup` (which applies them) and the Settings window (which edits
/// them). Persisted as `~/Library/Application Support/Loqui/cleanup.json`.
struct CleanupConfig: Codable, Equatable {
    var dictionary: [String: String]
    var removeFillers: Bool
    var fillers: [String]
    var spokenFormatting: Bool
    /// Stitch back sentences the recognizer split at a mid-sentence pause.
    var healSentenceSplits: Bool
    /// Words that almost never begin a real sentence, so a period in front of
    /// one is far more likely a pause artifact than an intended full stop.
    var continuationWords: [String]

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
        spokenFormatting: false,
        healSentenceSplits: true,
        // Deliberately tight. Merging a sentence that WAS intentional produces
        // a run-on, which is its own kind of mess — so this ships with only the
        // words that essentially never open a sentence. "but", "so" and "then"
        // are left out precisely because they're common, legitimate openers;
        // add them here if the split-sentence problem outweighs the run-ons.
        continuationWords: ["and", "or", "nor", "which", "whose", "whom", "than", "because"]
    )
}

/// Decoded field by field with per-key fallbacks, so a `cleanup.json` written
/// by an older build — which has none of the newer keys — still loads with the
/// user's dictionary intact. Strict decoding would fail the whole file and
/// silently reset it to defaults, quietly throwing away their terms.
extension CleanupConfig {
    private enum CodingKeys: String, CodingKey {
        case dictionary, removeFillers, fillers, spokenFormatting
        case healSentenceSplits, continuationWords
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = CleanupConfig.defaults
        dictionary = try c.decodeIfPresent([String: String].self, forKey: .dictionary) ?? d.dictionary
        removeFillers = try c.decodeIfPresent(Bool.self, forKey: .removeFillers) ?? d.removeFillers
        fillers = try c.decodeIfPresent([String].self, forKey: .fillers) ?? d.fillers
        spokenFormatting = try c.decodeIfPresent(Bool.self, forKey: .spokenFormatting) ?? d.spokenFormatting
        healSentenceSplits = try c.decodeIfPresent(Bool.self, forKey: .healSentenceSplits) ?? d.healSentenceSplits
        continuationWords = try c.decodeIfPresent([String].self, forKey: .continuationWords) ?? d.continuationWords
    }
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
