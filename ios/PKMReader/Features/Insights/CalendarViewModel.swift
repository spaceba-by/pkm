import Foundation

/// Represents a single day in the calendar grid
struct CalendarDay: Identifiable, Equatable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

/// Represents a week row in the calendar grid
struct CalendarWeek: Identifiable, Equatable {
    let id: String
    let days: [CalendarDay]
    let weekStart: Date

    private static let weekIdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-'W'ww"
        return formatter
    }()

    init(days: [CalendarDay], weekStart: Date) {
        self.days = days
        self.weekStart = weekStart
        self.id = Self.weekIdFormatter.string(from: weekStart)
    }
}

/// View model managing the calendar grid state, month navigation, and insight date lookups
@MainActor
final class CalendarViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case error(Error)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): true
            case (.loaded, .loaded): true
            case let (.error(lhsErr), .error(rhsErr)):
                lhsErr.localizedDescription == rhsErr.localizedDescription
            default: false
            }
        }
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var displayedMonth: Date
    @Published private(set) var weeks: [CalendarWeek] = []
    @Published private(set) var summaries: [Summary] = []
    @Published private(set) var reports: [Report] = []

    private let apiClient: any APIClientProtocol
    private let calendar: Calendar
    private let today: Date

    private var summaryDateSet: Set<String> = []
    private var reportWeekSet: Set<String> = []
    private var summaryByDate: [String: Summary] = [:]
    private var reportByWeek: [String: Report] = [:]

    private let dateKeyFormatter: DateFormatter
    private let monthTitleFormatter: DateFormatter

    init(
        apiClient: any APIClientProtocol,
        calendar: Calendar = .current,
        today: Date = Date()
    ) {
        self.apiClient = apiClient
        self.calendar = calendar
        self.today = today

        let dkf = DateFormatter()
        dkf.dateFormat = "yyyy-MM-dd"
        dkf.timeZone = calendar.timeZone
        self.dateKeyFormatter = dkf

        let mtf = DateFormatter()
        mtf.dateFormat = "MMMM yyyy"
        mtf.timeZone = calendar.timeZone
        self.monthTitleFormatter = mtf

        // Start on the first day of the current month
        let components = calendar.dateComponents([.year, .month], from: today)
        self.displayedMonth = calendar.date(from: components) ?? today
        computeWeeks()
    }

    // MARK: - Public API

    func loadData() async {
        state = .loading
        await fetchData()
    }

    func refresh() async {
        await fetchData()
    }

    func navigateToPreviousMonth() {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = previous
        computeWeeks()
    }

    func navigateToNextMonth() {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
        computeWeeks()
    }

    func navigateToMonth(containing date: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        if let monthStart = calendar.date(from: components) {
            displayedMonth = monthStart
            computeWeeks()
        }
    }

    /// The displayed month/year as a formatted string (e.g. "January 2024")
    var displayedMonthTitle: String {
        monthTitleFormatter.string(from: displayedMonth)
    }

    /// Short weekday symbols starting from the calendar's first weekday
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1 // 0-indexed
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    func hasSummary(for date: Date) -> Bool {
        summaryDateSet.contains(dateKey(for: date))
    }

    func hasReport(forWeekContaining date: Date) -> Bool {
        let mondayKey = mondayKey(for: date)
        return reportWeekSet.contains(mondayKey)
    }

    func summaryForDate(_ date: Date) -> Summary? {
        summaryByDate[dateKey(for: date)]
    }

    func reportForWeek(_ weekRow: CalendarWeek) -> Report? {
        // Check if any Monday in this week row matches a report's weekOf date
        for day in weekRow.days {
            let weekday = calendar.component(.weekday, from: day.date)
            if weekday == 2 { // Monday
                if let report = reportByWeek[dateKey(for: day.date)] {
                    return report
                }
            }
        }
        return nil
    }

    /// Whether the displayed month has any insights at all
    var hasInsightsThisMonth: Bool {
        let monthComponents = calendar.dateComponents([.year, .month], from: displayedMonth)
        let hasSummary = summaries.contains { summary in
            guard let date = parseDate(summary.date) else { return false }
            let components = calendar.dateComponents([.year, .month], from: date)
            return components.year == monthComponents.year && components.month == monthComponents.month
        }
        let hasReport = reports.contains { report in
            guard let date = mondayDate(fromISOWeek: report.weekOf) else { return false }
            // A report's week may overlap with this month
            let components = calendar.dateComponents([.year, .month], from: date)
            return components.year == monthComponents.year && components.month == monthComponents.month
        }
        return hasSummary || hasReport
    }

    // MARK: - Grid Computation

    func computeWeeks() {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            weeks = []
            return
        }

        let offset = leadingDayOffset(for: monthStart)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

        var allDays = leadingDays(before: monthStart, count: offset)
        allDays += currentMonthDays(components: components, range: range, todayComponents: todayComponents)
        allDays += trailingDays(after: allDays)

        weeks = groupIntoWeeks(allDays)
    }

    private func leadingDayOffset(for monthStart: Date) -> Int {
        var offset = calendar.component(.weekday, from: monthStart) - calendar.firstWeekday
        if offset < 0 { offset += 7 }
        return offset
    }

    private func leadingDays(before monthStart: Date, count: Int) -> [CalendarDay] {
        guard count > 0 else { return [] }
        return (1...count).reversed().compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: -i, to: monthStart) else { return nil }
            let dayNum = calendar.component(.day, from: date)
            return CalendarDay(
                id: dateKey(for: date),
                date: date,
                dayNumber: dayNum,
                isCurrentMonth: false,
                isToday: false
            )
        }
    }

    private func currentMonthDays(
        components: DateComponents,
        range: Range<Int>,
        todayComponents: DateComponents
    ) -> [CalendarDay] {
        range.compactMap { day in
            var dayComponents = components
            dayComponents.day = day
            guard let date = calendar.date(from: dayComponents) else { return nil }
            let dc = calendar.dateComponents([.year, .month, .day], from: date)
            let isToday = dc == todayComponents
            return CalendarDay(
                id: dateKey(for: date),
                date: date,
                dayNumber: day,
                isCurrentMonth: true,
                isToday: isToday
            )
        }
    }

    private func trailingDays(after allDays: [CalendarDay]) -> [CalendarDay] {
        let remainder = allDays.count % 7
        guard remainder > 0, let lastDay = allDays.last?.date else { return [] }
        let trailingCount = 7 - remainder
        return (1...trailingCount).compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: i, to: lastDay) else { return nil }
            let dayNum = calendar.component(.day, from: date)
            return CalendarDay(
                id: dateKey(for: date),
                date: date,
                dayNumber: dayNum,
                isCurrentMonth: false,
                isToday: false
            )
        }
    }

    private func groupIntoWeeks(_ allDays: [CalendarDay]) -> [CalendarWeek] {
        stride(from: 0, to: allDays.count, by: 7).compactMap { i in
            let weekDays = Array(allDays[i..<min(i + 7, allDays.count)])
            guard let firstDay = weekDays.first else { return nil }
            return CalendarWeek(days: weekDays, weekStart: firstDay.date)
        }
    }

    // MARK: - Private

    private func fetchData() async {
        do {
            async let summariesResult = apiClient.listSummaries(limit: 365)
            async let reportsResult = apiClient.listReports(limit: 52)

            let (fetchedSummaries, fetchedReports) = try await (summariesResult, reportsResult)

            summaries = fetchedSummaries
            reports = fetchedReports

            buildLookups()
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .error(error)
        }
    }

    private func buildLookups() {
        summaryDateSet = Set(summaries.map(\.date))
        summaryByDate = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, $0) })

        // Reports have weekOf in ISO week format (e.g. "2026-W08").
        // Convert to Monday date strings so reportForWeek can look up by dateKey.
        var weekSet = Set<String>()
        var weekDict = [String: Report]()
        for report in reports {
            if let mondayDate = mondayDate(fromISOWeek: report.weekOf) {
                let key = dateKey(for: mondayDate)
                weekSet.insert(key)
                weekDict[key] = report
            }
        }
        reportWeekSet = weekSet
        reportByWeek = weekDict
    }

    private func dateKey(for date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    private func mondayKey(for date: Date) -> String {
        let monday = mondayOfWeek(containing: date)
        return dateKey(for: monday)
    }

    private func mondayOfWeek(containing date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        // Days to subtract to reach Monday
        let daysToMonday = (weekday == 1) ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -daysToMonday, to: date) ?? date
    }

    private func parseDate(_ string: String) -> Date? {
        dateKeyFormatter.date(from: string)
    }

    /// Parse an ISO week string like "2026-W08" into the Monday Date for that week
    private func mondayDate(fromISOWeek isoWeek: String) -> Date? {
        // Append "-1" for Monday (ISO day-of-week 1 = Monday)
        let isoWeekFormatter = DateFormatter()
        isoWeekFormatter.dateFormat = "YYYY-'W'ww-e"
        isoWeekFormatter.timeZone = calendar.timeZone
        isoWeekFormatter.locale = Locale(identifier: "en_US_POSIX")
        // ISO 8601 weeks start on Monday
        isoWeekFormatter.calendar = Calendar(identifier: .iso8601)
        return isoWeekFormatter.date(from: isoWeek + "-1")
    }
}
