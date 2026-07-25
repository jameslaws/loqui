import Foundation

extension Notification.Name {
    /// Posted after a dictation is logged, so an open Stats window refreshes.
    static let dictationRecorded = Notification.Name("LoquiDictationRecorded")
}

struct DictationEntry: Codable {
    let at: Date
    let words: Int
    /// How long the mic was live, in seconds. Optional because entries written
    /// before duration logging existed don't have it — those decode fine and
    /// simply sit out of the pace/time-saved figures.
    var seconds: Double?
}

/// Append-only local record of how much you dictate — one tiny line per
/// dictation (timestamp + word count + duration, never the text itself). Powers
/// the Dictation Stats window. Lives at
/// `~/Library/Application Support/Loqui/dictation-log.jsonl`.
final class DictationLog {
    static let shared = DictationLog()

    private var url: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Loqui", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("dictation-log.jsonl")
    }

    func record(words: Int, seconds: Double? = nil) {
        guard words > 0 else { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        // Sub-second and runaway durations are noise (a mis-fire, a stuck mic)
        // and would wreck the words-per-minute average, so drop them. The upper
        // bound tracks the recording ceiling in VoiceKeyCenter — a genuine
        // long-form dictation must keep its duration.
        let dur = seconds.flatMap { (1...1800).contains(Int($0)) ? $0 : nil }
        guard let data = try? enc.encode(DictationEntry(at: Date(), words: words, seconds: dur)),
              let json = String(data: data, encoding: .utf8)
        else { return }
        let line = json + "\n"
        let u = url
        if !FileManager.default.fileExists(atPath: u.path) {
            try? Data().write(to: u)
        }
        if let handle = try? FileHandle(forWritingTo: u) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            if let d = line.data(using: .utf8) { try? handle.write(contentsOf: d) }
        }
        NotificationCenter.default.post(name: .dictationRecorded, object: nil)
    }

    func load() -> [DictationEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return content
            .split(separator: "\n")
            .compactMap { try? dec.decode(DictationEntry.self, from: Data($0.utf8)) }
    }
}
