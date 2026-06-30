import AppKit
import Charts
import SwiftUI

private let statsMagenta = Color.loquiMagenta

struct DatedWords: Identifiable {
    var id: Date { date }
    let date: Date
    let words: Int
}

struct LabeledWords: Identifiable {
    let id = UUID()
    let label: String
    let words: Int
}

/// Computes every figure on the dashboard from the dictation log. Reloads on
/// open AND whenever a new dictation is recorded, so an open window updates live.
@MainActor
final class StatsModel: ObservableObject {
    @Published var allTimeWords = 0
    @Published var totalDictations = 0
    @Published var avgPerDictation = 0
    @Published var todayWords = 0
    @Published var yesterdayWords = 0
    @Published var weekWords = 0
    @Published var lastWeekWords = 0
    @Published var monthWords = 0
    @Published var lastMonthWords = 0
    @Published var last30Days: [DatedWords] = []
    @Published var byMonth: [DatedWords] = []
    @Published var byWeekday: [LabeledWords] = []
    @Published var bestDayWords = 0
    @Published var bestDayDate: Date?
    @Published var peakTime = "—"

    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: .dictationRecorded, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() {
        let cal = Calendar.current
        let now = Date()
        let entries = DictationLog.shared.load()

        allTimeWords = entries.reduce(0) { $0 + $1.words }
        totalDictations = entries.count
        avgPerDictation = entries.isEmpty ? 0 : allTimeWords / entries.count

        func sum(_ pred: (DictationEntry) -> Bool) -> Int {
            entries.filter(pred).reduce(0) { $0 + $1.words }
        }

        todayWords = sum { cal.isDateInToday($0.at) }
        yesterdayWords = sum { cal.isDateInYesterday($0.at) }

        let weekItv = cal.dateInterval(of: .weekOfYear, for: now)
        weekWords = sum { weekItv?.contains($0.at) ?? false }
        if let ws = weekItv?.start,
           let lastWeekStart = cal.date(byAdding: .day, value: -7, to: ws),
           let lastWeekItv = cal.dateInterval(of: .weekOfYear, for: lastWeekStart) {
            lastWeekWords = sum { lastWeekItv.contains($0.at) }
        } else { lastWeekWords = 0 }

        let monthItv = cal.dateInterval(of: .month, for: now)
        monthWords = sum { monthItv?.contains($0.at) ?? false }
        if let ms = monthItv?.start,
           let lastMonthStart = cal.date(byAdding: .month, value: -1, to: ms),
           let lastMonthItv = cal.dateInterval(of: .month, for: lastMonthStart) {
            lastMonthWords = sum { lastMonthItv.contains($0.at) }
        } else { lastMonthWords = 0 }

        var byDay: [Date: Int] = [:]
        for e in entries { byDay[cal.startOfDay(for: e.at), default: 0] += e.words }

        let today0 = cal.startOfDay(for: now)
        last30Days = (0...29).reversed().compactMap { i in
            cal.date(byAdding: .day, value: -i, to: today0).map { DatedWords(date: $0, words: byDay[$0] ?? 0) }
        }

        var byMonthDict: [Date: Int] = [:]
        for e in entries {
            if let m = cal.date(from: cal.dateComponents([.year, .month], from: e.at)) {
                byMonthDict[m, default: 0] += e.words
            }
        }
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? today0
        byMonth = (0...11).reversed().compactMap { i in
            cal.date(byAdding: .month, value: -i, to: thisMonth).map { DatedWords(date: $0, words: byMonthDict[$0] ?? 0) }
        }

        var wd: [Int: Int] = [:]
        for e in entries { wd[cal.component(.weekday, from: e.at), default: 0] += e.words }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        byWeekday = (1...7).map { LabeledWords(label: names[$0 - 1], words: wd[$0] ?? 0) }

        if let best = byDay.max(by: { $0.value < $1.value }) {
            bestDayWords = best.value
            bestDayDate = best.key
        } else { bestDayWords = 0; bestDayDate = nil }

        var buckets: [String: Int] = ["Morning": 0, "Afternoon": 0, "Evening": 0, "Night": 0]
        for e in entries {
            switch cal.component(.hour, from: e.at) {
            case 5..<12: buckets["Morning", default: 0] += e.words
            case 12..<17: buckets["Afternoon", default: 0] += e.words
            case 17..<22: buckets["Evening", default: 0] += e.words
            default: buckets["Night", default: 0] += e.words
            }
        }
        peakTime = entries.isEmpty ? "—" : (buckets.max(by: { $0.value < $1.value })?.key ?? "—")
    }
}

struct StatsView: View {
    @StateObject private var model = StatsModel()
    @State private var selDaily: Date?
    @State private var selMonthly: Date?
    @State private var selWeekday: String?

    var body: some View {
        Group {
            if model.totalDictations == 0 {
                empty
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        cardsRow
                        dailyChart
                        monthlyChart
                        weekdayChart
                        insights
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 640, height: 760)
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }

    // MARK: charts (with hover tooltips)

    private var dailyChart: some View {
        chartCard("Last 30 days", height: 165) {
            Chart {
                ForEach(model.last30Days) { d in
                    BarMark(x: .value("Day", d.date, unit: .day), y: .value("Words", d.words))
                        .foregroundStyle(statsMagenta.gradient)
                }
                if let pt = nearest(model.last30Days, to: selDaily) {
                    marker(at: pt.date, unit: .day, label: dayLabel(pt.date), words: pt.words)
                }
            }
            .chartXSelection(value: $selDaily)
        }
    }

    private var monthlyChart: some View {
        chartCard("By month", height: 165) {
            Chart {
                ForEach(model.byMonth) { m in
                    BarMark(x: .value("Month", m.date, unit: .month), y: .value("Words", m.words))
                        .foregroundStyle(statsMagenta.gradient)
                }
                if let pt = nearest(model.byMonth, to: selMonthly) {
                    marker(at: pt.date, unit: .month, label: monthLabel(pt.date), words: pt.words)
                }
            }
            .chartXSelection(value: $selMonthly)
        }
    }

    private var weekdayChart: some View {
        chartCard("By weekday", height: 130) {
            Chart {
                ForEach(model.byWeekday) { w in
                    BarMark(x: .value("Day", w.label), y: .value("Words", w.words))
                        .foregroundStyle(statsMagenta.opacity(0.85))
                }
                if let sel = selWeekday, let w = model.byWeekday.first(where: { $0.label == sel }) {
                    RuleMark(x: .value("Day", w.label))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .annotation(position: .top, spacing: 4) { tooltip(fullWeekday(w.label), w.words) }
                }
            }
            .chartXScale(domain: model.byWeekday.map(\.label))
            .chartXSelection(value: $selWeekday)
        }
    }

    private func marker(at date: Date, unit: Calendar.Component, label: String, words: Int) -> some ChartContent {
        RuleMark(x: .value("x", date, unit: unit))
            .foregroundStyle(Color.secondary.opacity(0.25))
            .annotation(position: .top, spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                tooltip(label, words)
            }
    }

    private func tooltip(_ label: String, _ words: Int) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(words.formatted()) words").font(.caption.weight(.semibold)).foregroundStyle(statsMagenta)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.secondary.opacity(0.2)))
    }

    private func nearest(_ data: [DatedWords], to date: Date?) -> DatedWords? {
        guard let date else { return nil }
        return data.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func dayLabel(_ d: Date) -> String { d.formatted(.dateTime.month(.abbreviated).day()) }
    private func monthLabel(_ d: Date) -> String { d.formatted(.dateTime.month(.wide).year()) }
    private func fullWeekday(_ abbr: String) -> String {
        ["Sun": "Sunday", "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday",
         "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday"][abbr] ?? abbr
    }

    // MARK: cards + insights

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform").font(.system(size: 34)).foregroundStyle(statsMagenta)
            Text("No dictations yet").font(.title3.weight(.semibold))
            Text("Press \(ShortcutStore.shared.shortcut.display) and start talking — your stats will show up here.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dictation").font(.system(size: 26, weight: .bold, design: .serif))
            Text("\(model.allTimeWords.formatted()) words all-time · \(model.totalDictations.formatted()) dictations")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var cardsRow: some View {
        HStack(spacing: 12) {
            statCard("Today", model.todayWords, model.yesterdayWords, "yesterday")
            statCard("This week", model.weekWords, model.lastWeekWords, "last week")
            statCard("This month", model.monthWords, model.lastMonthWords, "last month")
        }
    }

    private func statCard(_ title: String, _ value: Int, _ prev: Int, _ prevLabel: String) -> some View {
        let (sub, up) = compare(value, prev, prevLabel)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption2).tracking(1).foregroundStyle(.secondary)
            Text(value.formatted()).font(.system(size: 25, weight: .semibold, design: .rounded))
            Text(sub).font(.caption2)
                .foregroundStyle(up ? AnyShapeStyle(statsMagenta) : AnyShapeStyle(.secondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compare(_ now: Int, _ prev: Int, _ label: String) -> (String, Bool) {
        if prev == 0 { return ("\(prev.formatted()) \(label)", false) }
        let pct = Int(round(Double(now - prev) / Double(prev) * 100))
        let up = pct >= 0
        return ("\(prev.formatted()) \(label)  \(up ? "▲" : "▼")\(abs(pct))%", up)
    }

    private func chartCard<C: View>(_ title: String, height: CGFloat, @ViewBuilder _ chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            chart().frame(height: height)
        }
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Patterns").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                insight("Best day", model.bestDayDate != nil ? "\(model.bestDayWords.formatted()) words" : "—")
                insight("Most active", model.peakTime)
                insight("Avg per dictation", "\(model.avgPerDictation) words")
                insight("Total dictations", model.totalDictations.formatted())
            }
        }
    }

    private func insight(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.caption2).tracking(1).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
