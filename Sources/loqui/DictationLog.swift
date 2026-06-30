import Foundation

extension Notification.Name {
    /// Posted after a dictation is logged, so an open Stats window refreshes.
    static let dictationRecorded = Notification.Name("LoquiDictationRecorded")
}

struct DictationEntry: Codable {
    let at: Date
    let words: Int
}

/// Append-only local record of how much you dictate — one tiny line per
/// dictation (timestamp + word count, never the text itself). Powers the
/// Dictation Stats window. Lives at
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

    func record(words: Int) {
        guard words > 0 else { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(DictationEntry(at: Date(), words: words)),
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
