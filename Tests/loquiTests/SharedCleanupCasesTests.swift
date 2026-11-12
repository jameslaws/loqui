import Foundation
import Testing
@testable import loqui

/// The Mac half of the shared cleanup contract: every example in
/// `shared/cleanup-cases.json` must come out exactly as written. The Windows
/// core runs the same file, so a rule that drifts on either side fails there.
struct SharedCleanupCasesTests {
    private struct Segment: Decodable {
        let text: String
        let start: Double?
        let end: Double?
    }

    private struct Case: Decodable {
        let id: String
        let config: CleanupConfig?
        let `in`: String?
        let segments: [Segment]?
        let out: String
    }

    private struct File: Decodable {
        let cases: [Case]
        let timedCases: [Case]
    }

    private static let casesURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // loquiTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // repo root
        .appendingPathComponent("shared/cleanup-cases.json")

    @Test("CLEAN-02: The Mac app passes every shared example")
    func everySharedExample() throws {
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: Self.casesURL))
        let cleanup = TextCleanup()
        var passed = 0

        for c in file.cases + file.timedCases {
            let cfg = c.config ?? .defaults
            let raw = try #require(c.in ?? c.segments.map { Self.bankSegments($0, cfg) },
                                   "\(c.id): needs `in` or `segments`")
            let got = cleanup.process(raw, config: cfg)
            if got == c.out {
                passed += 1
                print("PASS \(c.id)")
            } else {
                Issue.record("FAIL \(c.id): expected \(c.out.debugDescription), got \(got.debugDescription)")
            }
        }
        print("Shared cleanup examples passed: \(passed) of \(file.cases.count + file.timedCases.count)")
    }

    /// Bank segments the way VoiceTranscriber does: the gap is this segment's
    /// start minus the last known end, and a segment without times keeps it.
    private static func bankSegments(_ segments: [Segment], _ cfg: CleanupConfig) -> String {
        var text = ""
        var lastEnd: Double?
        for s in segments {
            let gap = s.start.flatMap { start in lastEnd.map { start - $0 } }
            text = TimedHeal.bank(s.text, after: text, gap: gap, config: cfg).text
            lastEnd = s.end ?? lastEnd
        }
        return text
    }
}

/// The Windows core's CLEAN-05 test loads `shared/fixtures/cleanup-mac-full.json`
/// as a file written by the Mac app. This keeps that true.
struct MacSettingsFixtureTests {
    @Test("The full settings fixture is byte for byte what the Mac app writes")
    func fullFixtureMatchesTheMacEncoder() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/fixtures/cleanup-mac-full.json")
        var cfg = CleanupConfig.defaults
        cfg.dictionary = ["loki": "loqui", "sarah k": "Sara K.", "and slash or": "and/or", "zoe": "Zoë"]
        cfg.fillers = ["um", "uh", "like"]
        cfg.spokenFormatting = true
        cfg.timedHealWords = ["and", "but"]
        cfg.maxPauseSeconds = 0.6
        cfg.auditLog = false
        // The same encoder settings as CleanupConfigFile.save.
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let written = try #require(String(data: enc.encode(cfg), encoding: .utf8))
        #expect(written == (try String(contentsOf: url, encoding: .utf8)))
    }
}
