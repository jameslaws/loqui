import Foundation
import Testing
@testable import loqui

/// STAT-07, the Mac half: every figure in `shared/stats-cases.json` comes out
/// of the Mac's own `StatsModel` exactly as written. The Windows core runs the
/// same file, so a stats rule that drifts on either side fails there.
@MainActor
struct SharedStatsCasesTests {
    private struct Series: Decodable {
        let first: String
        let words: [Int]
    }

    private struct File: Decodable {
        let now: String
        let timeZone: String
        let firstWeekday: Int
        let log: [String]
        let skipped: Int
        let top: [String: Int]
        let last30Days: Series
        let byMonth: Series
        let calendar: [String: JSONValue]
        let periods: [[String: JSONValue]]
    }

    /// Just enough JSON to compare expected values with what the Mac gives.
    enum JSONValue: Decodable, Equatable, CustomStringConvertible {
        case int(Int), bool(Bool), string(String), ints([Int]), day(String, Int), null

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { self = .null }
            else if let b = try? c.decode(Bool.self) { self = .bool(b) }
            else if let i = try? c.decode(Int.self) { self = .int(i) }
            else if let s = try? c.decode(String.self) { self = .string(s) }
            else if let a = try? c.decode([Int].self) { self = .ints(a) }
            else {
                let d = try c.decode([String: JSONValue].self)
                guard case .string(let date)? = d["date"], case .int(let words)? = d["words"] else {
                    throw DecodingError.dataCorruptedError(in: c, debugDescription: "unexpected value")
                }
                self = .day(date, words)
            }
        }

        var description: String {
            switch self {
            case .int(let i): "\(i)"
            case .bool(let b): "\(b)"
            case .string(let s): s.debugDescription
            case .ints(let a): "\(a)"
            case .day(let d, let w): "\(d): \(w)"
            case .null: "null"
            }
        }
    }

    private static let fileURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // loquiTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // repo root
        .appendingPathComponent("shared/stats-cases.json")

    private let file: File
    private let entries: [DictationEntry]
    private let now: Date

    init() throws {
        file = try JSONDecoder().decode(File.self, from: Data(contentsOf: Self.fileURL))
        entries = DictationLog.entries(from: file.log.joined(separator: "\n"))
        now = try #require(ISO8601DateFormatter().date(from: file.now))
    }

    private func calendar(firstWeekday: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: file.timeZone)!
        cal.locale = Locale(identifier: "en_US")
        cal.firstWeekday = firstWeekday
        return cal
    }

    private func model(_ grain: StatsGrain, _ offset: Int, firstWeekday: Int? = nil) -> StatsModel {
        StatsModel(entries: entries, now: now, calendar: calendar(firstWeekday: firstWeekday ?? file.firstWeekday),
                   grain: grain, offset: offset)
    }

    private func text(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: file.timeZone)
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Records each difference under the case's id, and says which passed.
    private func check(_ id: String, _ expected: [String: JSONValue], _ got: [String: JSONValue]) -> Bool {
        var ok = true
        for (key, want) in expected.sorted(by: { $0.key < $1.key }) where got[key] != want {
            Issue.record("FAIL \(id): \(key) expected \(want), got \(got[key].map(\.description) ?? "nothing")")
            ok = false
        }
        print("\(ok ? "PASS" : "FAIL") \(id)")
        return ok
    }

    @Test("STAT-07: The Mac and Windows give the same figures")
    func everySharedFigure() {
        var passed = 0
        var total = 0
        func count(_ ok: Bool) { total += 1; if ok { passed += 1 } }

        count(check("damaged lines are skipped", ["skipped": .int(file.skipped)],
                    ["skipped": .int(file.log.count - entries.count)]))

        let all = model(.allTime, 0)
        count(check("top of the window", file.top.mapValues { .int($0) }, [
            "allTimeWords": .int(all.allTimeWords), "dictations": .int(all.totalDictations),
            "wordsEach": .int(all.avgPerDictation), "today": .int(all.todayWords),
            "yesterday": .int(all.yesterdayWords), "thisWeek": .int(all.weekWords),
            "lastWeek": .int(all.lastWeekWords), "thisMonth": .int(all.monthWords),
            "lastMonth": .int(all.lastMonthWords),
        ]))
        count(check("last 30 days",
                    ["first": .string(file.last30Days.first), "words": .ints(file.last30Days.words)],
                    ["first": .string(all.last30Days.first.map { text($0.date, "yyyy-MM-dd") } ?? ""),
                     "words": .ints(all.last30Days.map(\.words))]))
        count(check("by month",
                    ["first": .string(file.byMonth.first), "words": .ints(file.byMonth.words)],
                    ["first": .string(all.byMonth.first.map { text($0.date, "yyyy-MM") } ?? ""),
                     "words": .ints(all.byMonth.map(\.words))]))
        count(check("calendar shading", file.calendar, [
            "firstDay": all.firstDay.map { .string(text($0, "yyyy-MM-dd")) } ?? .null,
            "busiestDay": .int(all.maxDayVolume), "busiestMonth": .int(all.maxMonthVolume),
        ]))

        for var c in file.periods {
            guard case .string(let id)? = c.removeValue(forKey: "id"),
                  case .string(let grainName)? = c.removeValue(forKey: "grain"),
                  let grain = StatsGrain(rawValue: grainName),
                  case .int(let offset)? = c.removeValue(forKey: "offset")
            else {
                Issue.record("a period needs an id, a grain and an offset")
                continue
            }
            var firstWeekday: Int?
            if case .int(let n)? = c.removeValue(forKey: "firstWeekday") { firstWeekday = n }
            let m = model(grain, offset, firstWeekday: firstWeekday)
            count(check("period: \(id)", c, [
                "label": .string(m.periodLabel), "empty": .bool(m.periodEmpty),
                "byWeekday": .ints(m.byWeekday.map(\.words)), "byHour": .ints(m.byHour.map(\.words)),
                "timeSavedMinutes": .int(Int(m.timeSaved / 60)),
                "paceMeasured": .bool(m.paceMeasured), "speakingPace": .int(m.speakingPace),
                "currentStreak": .int(m.currentStreak), "longestStreak": .int(m.longestStreak),
                "activeDays": .int(m.activeDays), "spanDays": .int(m.spanDays),
                "peakHours": .string(m.peakHours),
                "biggestDay": m.biggestDayDate.map { .day(text($0, "yyyy-MM-dd"), m.biggestDayWords) } ?? .null,
                "longestDictation": .int(m.longestDictation), "perActiveDay": .int(m.avgPerActiveDay),
            ]))
        }
        print("Shared stats figures passed: \(passed) of \(total)")
    }
}
