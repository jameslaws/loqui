import SwiftUI

/// Jump straight to a period instead of stepping to it.
///
/// The grids are shaded by word volume, which is the point: stepping back
/// twelve times to reach a particular day is tedious, but so is a plain date
/// picker when you don't already know the date. Shading turns "which day was
/// that big one?" into something you can see and click.
///
/// Shading is on an ABSOLUTE scale (against the busiest day/month ever), not
/// renormalized per screen, so a quiet month reads as quiet instead of being
/// stretched to look busy. A square root keeps the low end visible anyway.
struct PeriodPicker: View {
    @ObservedObject var model: StatsModel
    @Binding var isPresented: Bool

    /// The month (or year) being browsed — independent of what's selected, so
    /// you can look around without changing the stats behind the popover.
    @State private var cursor = Date()

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            switch model.grain {
            case .day, .week:
                header(cursor.formatted(.dateTime.month(.wide).year())) { shift(.month, $0) }
                weekdayHeadings
                dayGrid
                if model.grain == .week {
                    Text("Picks the whole week")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            case .month:
                header(cursor.formatted(.dateTime.year())) { shift(.year, $0) }
                monthGrid
            case .year:
                yearList
            case .allTime:
                EmptyView()
            }
        }
        .padding(14)
        .frame(width: 290)
        .onAppear { cursor = model.selectedWindow?.start ?? Date() }
    }

    // MARK: chrome

    private func header(_ title: String, _ step: @escaping (Int) -> Void) -> some View {
        HStack {
            chevron("chevron.left") { step(-1) }
            Spacer()
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            chevron("chevron.right") { step(1) }
        }
    }

    private func chevron(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shift(_ comp: Calendar.Component, _ delta: Int) {
        if let moved = cal.date(byAdding: comp, value: delta, to: cursor) { cursor = moved }
    }

    /// Same grid definition as the days below, so the columns can't drift apart.
    private var weekColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var weekdayHeadings: some View {
        LazyVGrid(columns: weekColumns, spacing: 0) {
            ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// `veryShortWeekdaySymbols` is always Sunday-first; rotate it to wherever
    /// this locale actually starts the week.
    private var orderedWeekdaySymbols: [String] {
        let symbols = cal.veryShortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    // MARK: day grid

    private var dayGrid: some View {
        LazyVGrid(columns: weekColumns, spacing: 4) {
            ForEach(Array(monthSlots.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 28)
                }
            }
        }
    }

    /// Leading blanks so the 1st lands under the right weekday, then the days.
    private var monthSlots: [Date?] {
        guard let month = cal.dateInterval(of: .month, for: cursor),
              let count = cal.range(of: .day, in: .month, for: cursor)?.count
        else { return [] }
        let leading = (cal.component(.weekday, from: month.start) - cal.firstWeekday + 7) % 7
        let days = (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: month.start) }
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    private func dayCell(_ day: Date) -> some View {
        let words = model.dayVolume[cal.startOfDay(for: day)] ?? 0
        let usable = selectable(day)
        // For the week grain this lights up all seven days at once, because
        // the selected window IS the week — the highlight falls out for free.
        let selected = model.selectedWindow?.contains(day) ?? false
        return Button {
            model.jump(to: day)
            isPresented = false
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.caption.weight(selected ? .bold : .regular))
                .foregroundStyle(foreground(words, usable: usable))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(shade(words, peak: model.maxDayVolume),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected ? Color.loquiMagenta : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!usable)
        .opacity(usable ? 1 : 0.25)
        .help(words > 0 ? "\(words.formatted()) words" : "No dictations")
    }

    // MARK: month + year

    private var monthGrid: some View {
        let year = cal.component(.year, from: cursor)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                         spacing: 6) {
            ForEach(1...12, id: \.self) { month in
                monthCell(year: year, month: month)
            }
        }
    }

    private func monthCell(year: Int, month: Int) -> some View {
        let start = cal.date(from: DateComponents(year: year, month: month)) ?? Date()
        let words = model.monthVolume[start] ?? 0
        let usable = selectable(start) || selectable(monthEnd(start))
        let selected = model.selectedWindow?.contains(start) ?? false
        return Button {
            model.jump(to: start)
            isPresented = false
        } label: {
            Text(start.formatted(.dateTime.month(.abbreviated)))
                .font(.caption.weight(selected ? .bold : .regular))
                .foregroundStyle(foreground(words, usable: usable, peak: model.maxMonthVolume))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(shade(words, peak: model.maxMonthVolume),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected ? Color.loquiMagenta : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!usable)
        .opacity(usable ? 1 : 0.25)
        .help(words > 0 ? "\(words.formatted()) words" : "No dictations")
    }

    private var yearList: some View {
        VStack(spacing: 4) {
            ForEach(availableYears, id: \.self) { year in
                let start = cal.date(from: DateComponents(year: year)) ?? Date()
                let words = yearWords(year)
                let selected = model.selectedWindow?.contains(start) ?? false
                Button {
                    model.jump(to: start)
                    isPresented = false
                } label: {
                    HStack {
                        Text(String(year)).font(.callout.weight(selected ? .bold : .regular))
                        Spacer()
                        Text("\(words.formatted()) words")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(selected ? Color.loquiMagenta.opacity(0.18) : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var availableYears: [Int] {
        guard let first = model.firstDay else { return [] }
        let from = cal.component(.year, from: first)
        let to = cal.component(.year, from: Date())
        return Array(from...max(from, to)).reversed()
    }

    private func yearWords(_ year: Int) -> Int {
        model.monthVolume
            .filter { cal.component(.year, from: $0.key) == year }
            .values.reduce(0, +)
    }

    // MARK: shading

    private func monthEnd(_ start: Date) -> Date {
        cal.dateInterval(of: .month, for: start).map { $0.end.addingTimeInterval(-1) } ?? start
    }

    /// Nothing before your first dictation or after today is worth visiting.
    private func selectable(_ date: Date) -> Bool {
        guard let first = model.firstDay else { return false }
        return date >= first && cal.startOfDay(for: date) <= cal.startOfDay(for: Date())
    }

    private func shade(_ words: Int, peak: Int) -> Color {
        guard words > 0, peak > 0 else { return .clear }
        return Color.loquiMagenta.opacity(0.16 + 0.72 * intensity(words, peak))
    }

    private func foreground(_ words: Int, usable: Bool, peak: Int? = nil) -> Color {
        guard usable else { return .secondary }
        let ceiling = peak ?? model.maxDayVolume
        guard words > 0, ceiling > 0 else { return .primary }
        // Once the fill is dark enough, dark-on-dark stops being legible.
        return intensity(words, ceiling) > 0.6 ? .white : .primary
    }

    private func intensity(_ words: Int, _ peak: Int) -> Double {
        (Double(words) / Double(peak)).squareRoot()
    }
}
