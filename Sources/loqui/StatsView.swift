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

struct HourWords: Identifiable {
    var id: Int { hour }
    let hour: Int
    let words: Int
}

/// Sustained typing speed for an average adult. The baseline "time saved"
/// is measured against — deliberately conservative, since a fast typist
/// would beat it and the figure should never feel inflated.
private let typingWPM = 40.0

/// Size of the window the Patterns section is scoped to. Paired with an offset
/// (0 = the current one, -1 = the one before it) this addresses a *specific*
/// period — "July 2026" — rather than a vague "this month", which was ambiguous
/// about which month it meant and offered no way to look back at all.
enum StatsGrain: String, CaseIterable, Identifiable {
    case allTime, year, month, week, day

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allTime: "All time"
        case .year: "Year"
        case .month: "Month"
        case .week: "Week"
        case .day: "Day"
        }
    }

    var component: Calendar.Component? {
        switch self {
        case .allTime: nil
        case .year: .year
        case .month: .month
        case .week: .weekOfYear
        case .day: .day
        }
    }
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
    @Published var byHour: [HourWords] = []
    @Published var biggestDayWords = 0
    @Published var biggestDayDate: Date?
    @Published var peakHours = "—"
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var activeDays = 0
    @Published var spanDays = 0
    @Published var longestDictation = 0
    @Published var avgPerActiveDay = 0
    @Published var timeSaved: TimeInterval = 0
    @Published var speakingPace = 0
    @Published var paceMeasured = false
    /// True when the selected period contains no dictations at all — the tiles
    /// would otherwise be a wall of zeroes with no explanation.
    @Published var periodEmpty = false

    /// Names the selected window exactly — "July 2026", "Aug 2 – 8", "Yesterday"
    /// — so the figures are never ambiguous about which period they describe.
    @Published var periodLabel = "All time"

    /// Scopes the Patterns section (its two charts and all eight tiles).
    /// Everything above it — the totals, the three cards, the daily and monthly
    /// charts — is inherently time-scoped already and stays put.
    @Published private(set) var grain: StatsGrain = .allTime
    /// 0 is the current period, -1 the one before it, and so on. Never
    /// positive: there is nothing to show in the future.
    @Published private(set) var offset = 0

    func select(_ newGrain: StatsGrain) {
        guard newGrain != grain else { return }
        grain = newGrain
        offset = 0          // a new granularity always lands on the present
        reload()
    }

    func step(_ delta: Int) {
        offset = min(0, offset + delta)
        reload()
    }

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

        // ---- Everything below is scoped to the selected period. ----

        // A concrete window, not an open-ended "since" — stepping back to July
        // has to exclude August as well as June.
        let window: DateInterval? = grain.component.flatMap { comp in
            cal.date(byAdding: comp, value: offset, to: now)
                .flatMap { cal.dateInterval(of: comp, for: $0) }
        }
        periodLabel = Self.label(for: grain, window: window, cal: cal, now: now)
        let scoped = window.map { w in entries.filter { w.contains($0.at) } } ?? entries
        periodEmpty = scoped.isEmpty

        var scopedByDay: [Date: Int] = [:]
        for e in scoped { scopedByDay[cal.startOfDay(for: e.at), default: 0] += e.words }
        let scopedWords = scoped.reduce(0) { $0 + $1.words }

        var wd: [Int: Int] = [:]
        for e in scoped { wd[cal.component(.weekday, from: e.at), default: 0] += e.words }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        byWeekday = (1...7).map { LabeledWords(label: names[$0 - 1], words: wd[$0] ?? 0) }

        if let biggest = scopedByDay.max(by: { $0.value < $1.value }) {
            biggestDayWords = biggest.value
            biggestDayDate = biggest.key
        } else { biggestDayWords = 0; biggestDayDate = nil }

        // Hour-of-day distribution, and the busiest 3-hour window in it. The
        // window wraps past midnight so a late-night habit reads as
        // "10 PM–1 AM" rather than being split across the end of the array.
        var hourly = [Int](repeating: 0, count: 24)
        for e in scoped { hourly[cal.component(.hour, from: e.at)] += e.words }
        byHour = (0..<24).map { HourWords(hour: $0, words: hourly[$0]) }

        var peakStart = 0, peakSum = -1
        for start in 0..<24 {
            let sum = (0..<3).reduce(0) { $0 + hourly[($1 + start) % 24] }
            if sum > peakSum { peakSum = sum; peakStart = start }
        }
        peakHours = peakSum > 0 ? Self.hourRange(peakStart, peakStart + 3) : "—"

        // MARK: streaks & consistency

        let activeSet = Set(scopedByDay.keys)
        let sortedDays = activeSet.sorted()

        // A streak shouldn't look broken just because you haven't dictated yet
        // today, so an untouched today falls back to counting from yesterday.
        var streak = 0
        if !activeSet.isEmpty {
            var probe = activeSet.contains(today0)
                ? today0
                : (cal.date(byAdding: .day, value: -1, to: today0) ?? today0)
            while activeSet.contains(probe) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: probe) else { break }
                probe = prev
            }
        }
        currentStreak = streak

        var best = 0, run = 0
        var previous: Date?
        for day in sortedDays {
            if let p = previous, let next = cal.date(byAdding: .day, value: 1, to: p),
               cal.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        longestStreak = best

        // Consistency: days you actually dictated, over the days that were
        // available to dictate in. Clamped at both ends — never before your
        // first ever dictation, and never past today, so the current month
        // reads "5 of 7" on the 7th rather than "5 of 31".
        let firstEver = entries.map { cal.startOfDay(for: $0.at) }.min() ?? today0
        let winStart = max(window.map { cal.startOfDay(for: $0.start) } ?? firstEver, firstEver)
        let winEnd = min(window.map { cal.startOfDay(for: $0.end.addingTimeInterval(-1)) } ?? today0,
                         today0)
        spanDays = max((cal.dateComponents([.day], from: winStart, to: winEnd).day ?? 0) + 1, 1)
        activeDays = activeSet.count

        avgPerActiveDay = activeSet.isEmpty ? 0 : scopedWords / activeSet.count
        longestDictation = scoped.map(\.words).max() ?? 0

        // MARK: pace & time saved

        let timed = scoped.compactMap { e in e.seconds.map { (words: e.words, secs: $0) } }
        let timedWords = timed.reduce(0) { $0 + $1.words }
        let timedSecs = timed.reduce(0.0) { $0 + $1.secs }
        paceMeasured = timedSecs > 0
        speakingPace = paceMeasured ? Int(round(Double(timedWords) / (timedSecs / 60))) : 0

        // Entries logged before duration tracking existed get filled in at your
        // measured pace (or a typical speaking rate, until there's enough
        // measured data to have one), which is why the figure is shown as "≈".
        let assumedPace = paceMeasured ? Double(speakingPace) : 150.0
        let spokenSecs = scoped.reduce(0.0) { $0 + ($1.seconds ?? Double($1.words) / assumedPace * 60) }
        timeSaved = max(0, Double(scopedWords) / typingWPM * 60 - spokenSecs)
    }

    /// Names the window in the way a person would: "July 2026", "Aug 2 – 8",
    /// "Jul 28 – Aug 3", "Yesterday". Weeks collapse the month when both ends
    /// share it.
    static func label(for grain: StatsGrain, window: DateInterval?,
                      cal: Calendar, now: Date) -> String {
        guard let window else { return "All time" }
        let start = window.start
        let last = window.end.addingTimeInterval(-1)
        switch grain {
        case .allTime:
            return "All time"
        case .year:
            return start.formatted(.dateTime.year())
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        case .week:
            let from = start.formatted(.dateTime.month(.abbreviated).day())
            let to = cal.isDate(start, equalTo: last, toGranularity: .month)
                ? last.formatted(.dateTime.day())
                : last.formatted(.dateTime.month(.abbreviated).day())
            return "\(from) – \(to)"
        case .day:
            if cal.isDateInToday(start) { return "Today" }
            if cal.isDateInYesterday(start) { return "Yesterday" }
            return start.formatted(.dateTime.month(.abbreviated).day().year())
        }
    }

    /// "7–10 AM", "9 AM–12 PM", "10 PM–1 AM" — the meridiem collapses to one
    /// when both ends share it.
    static func hourRange(_ from: Int, _ to: Int) -> String {
        func parts(_ h: Int) -> (String, String) {
            let m = ((h % 24) + 24) % 24
            let hour12 = m % 12 == 0 ? 12 : m % 12
            return ("\(hour12)", m < 12 ? "AM" : "PM")
        }
        let (a, aMer) = parts(from), (b, bMer) = parts(to)
        return aMer == bMer ? "\(a)–\(b) \(aMer)" : "\(a) \(aMer)–\(b) \(bMer)"
    }
}

struct StatsView: View {
    @StateObject private var model = StatsModel()
    @State private var selDaily: Date?
    @State private var selMonthly: Date?
    @State private var selWeekday: String?
    @State private var selHour: Int?

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
                        // The picker heads this group because it governs
                        // everything below it — both charts and all the tiles.
                        patternsHeader
                        weekdayChart
                        hourChart
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
                        // Without `y: .disabled` the chart grows its y-domain to
                        // fit the tooltip, so hovering rescaled the axis and
                        // visibly shrank every bar. Let it overflow instead —
                        // this matches the other three charts.
                        .annotation(position: .top, spacing: 4,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            tooltip(fullWeekday(w.label), w.words)
                        }
                }
            }
            .chartXScale(domain: model.byWeekday.map(\.label))
            .chartXSelection(value: $selWeekday)
        }
    }

    private var hourChart: some View {
        chartCard("By hour of day", height: 130) {
            Chart {
                ForEach(model.byHour) { h in
                    BarMark(x: .value("Hour", h.hour), y: .value("Words", h.words))
                        .foregroundStyle(statsMagenta.opacity(0.85))
                }
                if let sel = selHour, let h = model.byHour.first(where: { $0.hour == sel }) {
                    RuleMark(x: .value("Hour", h.hour))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .annotation(position: .top, spacing: 4,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            tooltip(StatsModel.hourRange(h.hour, h.hour + 1), h.words)
                        }
                }
            }
            .chartXScale(domain: -0.5...23.5)
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = value.as(Int.self) { Text(Self.axisHour(h)) }
                    }
                }
            }
            .chartXSelection(value: $selHour)
        }
    }

    /// Compact axis tick — "12a", "3a", "12p" — so all eight fit without crowding.
    private static func axisHour(_ h: Int) -> String {
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return "\(hour12)\(h < 12 ? "a" : "p")"
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
            // Totals live here rather than in the grid below — they're the
            // frame for everything else, and repeating them as tiles wastes
            // slots on numbers already on screen.
            Text("\(model.allTimeWords.formatted()) words all-time · \(model.totalDictations.formatted()) dictations · \(model.avgPerDictation.formatted()) words each")
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

    private var patternsHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Patterns").font(.headline)
                Spacer(minLength: 12)
                Picker("", selection: Binding(get: { model.grain },
                                              set: { model.select($0) })) {
                    ForEach(StatsGrain.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            // Which period, spelled out — the whole point of the stepper is
            // that you never have to infer it.
            if model.grain != .allTime {
                HStack(spacing: 10) {
                    stepButton("chevron.left", -1, enabled: true)
                    Text(model.periodLabel)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 170)
                    // Nothing to show in the future.
                    stepButton("chevron.right", 1, enabled: model.offset < 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }

    private func stepButton(_ symbol: String, _ delta: Int, enabled: Bool) -> some View {
        Button { model.step(delta) } label: {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    @ViewBuilder
    private var insights: some View {
        // A grid of eight zeroes reads as broken rather than as empty, so say
        // so plainly instead of rendering it.
        if model.periodEmpty {
            Text(model.periodLabel == "Today"
                 ? "No dictations yet today."
                 : "No dictations in \(model.periodLabel).")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else {
            tiles
        }
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            insight("Time saved", timeSavedValue,
                    model.paceMeasured ? "vs typing at \(Int(typingWPM)) wpm"
                                       : "estimated vs typing at \(Int(typingWPM)) wpm")
            insight("Speaking pace",
                    model.paceMeasured ? "\(model.speakingPace.formatted()) wpm" : "—",
                    model.paceMeasured ? "\(paceMultiple)× faster than typing"
                                       : "measured from new dictations")
            // "Your current streak, during March" isn't a coherent idea — a
            // streak is anchored to today. Under a filter the tile retitles to
            // the longest run inside that window instead, so every tile still
            // describes the period you picked.
            if model.grain == .allTime {
                insight("Current streak", streakValue(model.currentStreak),
                        model.longestStreak > 0 ? "best: \(streakValue(model.longestStreak))" : nil)
            } else {
                insight("Longest streak", streakValue(model.longestStreak), "consecutive days")
            }
            insight("Days active", "\(model.activeDays) of \(model.spanDays)", spanDescription)
            insight("Peak hours", model.peakHours, "when you dictate most")
            insight("Highest volume day",
                    model.biggestDayDate != nil ? "\(model.biggestDayWords.formatted()) words" : "—",
                    model.biggestDayDate.map { $0.formatted(.dateTime.month(.abbreviated).day().year()) })
            insight("Longest dictation", "\(model.longestDictation.formatted()) words", "in a single go")
            insight("Per active day", "\(model.avgPerActiveDay.formatted()) words",
                    "on days you dictate")
        }
    }

    /// Explains the "days active" denominator. A period still in progress is
    /// measured against the days elapsed so far, not its full length.
    private var spanDescription: String {
        if model.grain == .allTime { return "days since you started" }
        return model.offset == 0 ? "days so far" : "days in the period"
    }

    private var timeSavedValue: String {
        let mins = Int(model.timeSaved / 60)
        if mins < 60 { return "≈\(mins) min" }
        return "≈\(mins / 60)h \(mins % 60)m"
    }

    private func streakValue(_ days: Int) -> String {
        "\(days) \(days == 1 ? "day" : "days")"
    }

    private var paceMultiple: String {
        (Double(model.speakingPace) / typingWPM).formatted(.number.precision(.fractionLength(1)))
    }

    private func insight(_ title: String, _ value: String, _ detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.caption2).tracking(1).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded))
            if let detail {
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
        }
        // Fill the row height so tiles with and without a detail line still
        // present as one even grid.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
