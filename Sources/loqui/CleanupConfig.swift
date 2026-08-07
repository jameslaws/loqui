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
    /// Judged on text alone, so this list has to stay high-precision.
    var continuationWords: [String]
    /// Words that are BOTH common sentence openers and common mid-sentence
    /// pause points — "and" above all. Text can't tell those apart, so these
    /// are only healed when the measured pause is short enough to rule out a
    /// deliberate full stop.
    var timedHealWords: [String]
    /// The gap, in seconds, under which a sentence break is treated as a
    /// hesitation rather than an intended stop.
    var maxPauseSeconds: Double
    /// Record raw-vs-cleaned diffs to ~/Library/Logs/LoquiCleanup.log so the
    /// rules can be audited against real dictations. Local, like everything else.
    var auditLog: Bool

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
        // Deliberately tight, and "and" is deliberately NOT here. Replaying
        // these rules over 319 real transcripts, "and" alone accounted for 236
        // of 263 edits, and most of them were merging sentences that genuinely
        // started with "And" — trading split sentences for run-ons. Same reason
        // "but", "so" and "then" are absent: they're legitimate openers.
        continuationWords: ["or", "nor", "which", "whose", "whom", "than", "because"],
        // These get healed only with timing evidence behind them.
        timedHealWords: ["and", "but", "so"],
        // A starting guess, not a measured value. Every boundary is logged with
        // its actual gap, so this can be set from your own speech instead.
        maxPauseSeconds: 0.5,
        auditLog: true
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
        case timedHealWords, maxPauseSeconds, auditLog
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
        timedHealWords = try c.decodeIfPresent([String].self, forKey: .timedHealWords) ?? d.timedHealWords
        maxPauseSeconds = try c.decodeIfPresent(Double.self, forKey: .maxPauseSeconds) ?? d.maxPauseSeconds
        auditLog = try c.decodeIfPresent(Bool.self, forKey: .auditLog) ?? d.auditLog
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
