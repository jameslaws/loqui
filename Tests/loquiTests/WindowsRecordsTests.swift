import Foundation
import Testing
@testable import loqui

/// REC-01, the Mac half: the history and stats lines the Windows app writes
/// (`shared/fixtures/*-windows.jsonl`, checked against the Windows writer by
/// its own tests) decode with the Mac app's own record types, so steps 3 and 4
/// can show them the Mac's way.
struct WindowsRecordsTests {
    private func lines(_ name: String) throws -> [Data] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/fixtures/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n").map { Data($0.utf8) }
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @Test("REC-01: the Mac reads the Windows history file")
    func history() throws {
        let entries = try lines("history-windows.jsonl").map { try decoder.decode(HistoryEntry.self, from: $0) }
        #expect(entries.map(\.text) == [
            "Please send the report to Sarah before Friday, and copy the whole team.",
            "I use Loqui every day.",
        ])
        #expect(entries[0].at == ISO8601DateFormatter().date(from: "2026-11-12T14:03:22Z"))
    }

    @Test("REC-01: the Mac reads the Windows stats file")
    func stats() throws {
        let entries = try lines("dictation-log-windows.jsonl").map { try decoder.decode(DictationEntry.self, from: $0) }
        #expect(entries.map(\.words) == [13, 5])
        #expect(entries.map(\.seconds) == [5.5, nil])
        #expect(entries[1].at == ISO8601DateFormatter().date(from: "2026-11-12T14:05:00Z"))
    }
}
