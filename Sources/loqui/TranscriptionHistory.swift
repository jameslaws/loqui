import Foundation

extension Notification.Name {
    /// Posted when the history changes (new entry, delete, clear) so an open
    /// History window and the menu's Recent list refresh.
    static let transcriptionHistoryChanged = Notification.Name("LoquiTranscriptionHistoryChanged")
}

struct HistoryEntry: Codable, Identifiable, Equatable {
    let at: Date
    let text: String
    var id: String { "\(at.timeIntervalSinceReferenceDate):\(text)" }
}

/// Local, on-device log of full transcription text — the source for the History
/// window and the menu's Recent list. Kept separate from `DictationLog` (which
/// stores only word counts for stats) so a retention prune never touches stats.
/// Lives at `~/Library/Application Support/Loqui/history.jsonl`.
final class TranscriptionHistory {
    static let shared = TranscriptionHistory()

    /// Retention, in UserDefaults as days: `-1` = off (don't store), `0` =
    /// forever, `N` = keep the last N days. Default `0` (forever).
    static let retentionKey = "loqui.history.retentionDays"
    static var retentionDays: Int {
        UserDefaults.standard.object(forKey: retentionKey) == nil
            ? 0 : UserDefaults.standard.integer(forKey: retentionKey)
    }

    private var url: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Loqui", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.jsonl")
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    func record(text: String) {
        guard Self.retentionDays >= 0 else { return }   // -1 = off → don't store
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let data = try? encoder().encode(HistoryEntry(at: Date(), text: trimmed)),
              let json = String(data: data, encoding: .utf8) else { return }
        append(json + "\n")
        NotificationCenter.default.post(name: .transcriptionHistoryChanged, object: nil)
    }

    private func append(_ line: String) {
        let u = url
        if !FileManager.default.fileExists(atPath: u.path) { try? Data().write(to: u) }
        guard let handle = try? FileHandle(forWritingTo: u) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        if let d = line.data(using: .utf8) { try? handle.write(contentsOf: d) }
    }

    /// All entries, newest first.
    func load() -> [HistoryEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let dec = decoder()
        return content.split(separator: "\n")
            .compactMap { try? dec.decode(HistoryEntry.self, from: Data($0.utf8)) }
            .sorted { $0.at > $1.at }
    }

    func recent(_ n: Int) -> [HistoryEntry] { Array(load().prefix(n)) }

    func deleteAll() {
        try? FileManager.default.removeItem(at: url)
        NotificationCenter.default.post(name: .transcriptionHistoryChanged, object: nil)
    }

    func delete(_ entry: HistoryEntry) {
        rewrite(load().filter { $0 != entry })
    }

    /// Drop entries older than the retention window. No-op for forever/off.
    func prune() {
        let days = Self.retentionDays
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        rewrite(load().filter { $0.at >= cutoff })
    }

    private func rewrite(_ entries: [HistoryEntry]) {
        let enc = encoder()
        let body = entries
            .sorted { $0.at < $1.at }   // store oldest-first; load() re-sorts newest-first
            .compactMap { try? enc.encode($0) }
            .compactMap { String(data: $0, encoding: .utf8) }
            .joined(separator: "\n")
        try? (body.isEmpty ? "" : body + "\n").write(to: url, atomically: true, encoding: .utf8)
        NotificationCenter.default.post(name: .transcriptionHistoryChanged, object: nil)
    }
}
