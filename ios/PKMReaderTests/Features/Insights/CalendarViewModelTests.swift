import XCTest
@testable import PKMReader

@MainActor
final class CalendarViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: CalendarViewModel!
    private var mockAPIClient: MockAPIClient!
    private var calendar: Calendar!
    // swiftlint:enable implicitly_unwrapped_optional

    private let fixedToday = CalendarViewModelTests.staticMakeDate(year: 2024, month: 1, day: 15)

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "UTC")!
        sut = CalendarViewModel(apiClient: mockAPIClient, calendar: calendar, today: fixedToday)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        calendar = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    func test_initialMonth_isCurrentMonth() {
        XCTAssertEqual(sut.displayedMonthTitle, "January 2024")
    }

    // MARK: - Grid Computation

    func test_computeWeeks_january2024_has5Weeks() {
        // January 2024: Mon Jan 1 - Wed Jan 31
        // With Sunday start: row 1 starts Dec 31 (Sun), last row ends Feb 3 (Sat)
        XCTAssertEqual(sut.weeks.count, 5)
    }

    func test_computeWeeks_firstWeekHasCorrectDays() {
        // Jan 2024 starts on Monday, so first row: Dec 31 (Sun), Jan 1-6
        let firstWeek = sut.weeks[0]
        XCTAssertEqual(firstWeek.days.count, 7)
        // First day should be from previous month (Dec 31)
        XCTAssertFalse(firstWeek.days[0].isCurrentMonth)
        XCTAssertEqual(firstWeek.days[0].dayNumber, 31) // Dec 31
        // Second day should be Jan 1
        XCTAssertTrue(firstWeek.days[1].isCurrentMonth)
        XCTAssertEqual(firstWeek.days[1].dayNumber, 1)
    }

    func test_computeWeeks_lastWeekHasTrailingDays() throws {
        // Jan 31 is a Wednesday, so last row needs Thu-Sat trailing
        let lastWeek = try XCTUnwrap(sut.weeks.last)
        let trailingDays = lastWeek.days.filter { !$0.isCurrentMonth }
        XCTAssertFalse(trailingDays.isEmpty)
    }

    func test_computeWeeks_todayIsMarked() {
        let allDays = sut.weeks.flatMap(\.days)
        let todayDays = allDays.filter(\.isToday)
        XCTAssertEqual(todayDays.count, 1)
        XCTAssertEqual(todayDays.first?.dayNumber, 15)
    }

    // MARK: - Month Navigation

    func test_navigateToNextMonth_updatesTitle() {
        sut.navigateToNextMonth()
        XCTAssertEqual(sut.displayedMonthTitle, "February 2024")
    }

    func test_navigateToPreviousMonth_updatesTitle() {
        sut.navigateToPreviousMonth()
        XCTAssertEqual(sut.displayedMonthTitle, "December 2023")
    }

    func test_navigateMultipleMonths() {
        sut.navigateToNextMonth()
        sut.navigateToNextMonth()
        sut.navigateToNextMonth()
        XCTAssertEqual(sut.displayedMonthTitle, "April 2024")
    }

    func test_navigateToMonth_setsCorrectMonth() {
        let targetDate = makeDate(year: 2024, month: 6, day: 10)
        sut.navigateToMonth(containing: targetDate)
        XCTAssertEqual(sut.displayedMonthTitle, "June 2024")
    }

    // MARK: - Data Loading

    func test_loadData_success_setsLoadedState() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mockAPIClient.listReportsResult = .success(TestFixtures.sampleReports)
        await sut.loadData()
        XCTAssertEqual(sut.state, .loaded)
    }

    func test_loadData_error_setsErrorState() async {
        mockAPIClient.listSummariesResult = .failure(APIError.networkError)
        await sut.loadData()
        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    func test_loadData_storesSummariesAndReports() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mockAPIClient.listReportsResult = .success(TestFixtures.sampleReports)
        await sut.loadData()
        XCTAssertEqual(sut.summaries.count, 3)
        XCTAssertEqual(sut.reports.count, 3)
    }

    // MARK: - Summary Lookups

    func test_hasSummary_returnsTrueForDatesWithSummaries() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mockAPIClient.listReportsResult = .success([])
        await sut.loadData()

        let jan3 = makeDate(year: 2024, month: 1, day: 3)
        XCTAssertTrue(sut.hasSummary(for: jan3))
    }

    func test_hasSummary_returnsFalseForDatesWithoutSummaries() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mockAPIClient.listReportsResult = .success([])
        await sut.loadData()

        let jan10 = makeDate(year: 2024, month: 1, day: 10)
        XCTAssertFalse(sut.hasSummary(for: jan10))
    }

    func test_summaryForDate_returnsSummary() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mockAPIClient.listReportsResult = .success([])
        await sut.loadData()

        let jan2 = makeDate(year: 2024, month: 1, day: 2)
        let summary = sut.summaryForDate(jan2)
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.date, "2024-01-02")
    }

    func test_summaryForDate_returnsNilForNoSummary() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mockAPIClient.listReportsResult = .success([])
        await sut.loadData()

        let jan5 = makeDate(year: 2024, month: 1, day: 5)
        XCTAssertNil(sut.summaryForDate(jan5))
    }

    // MARK: - Report Lookups

    func test_hasReport_returnsTrueForWeeksWithReports() async {
        mockAPIClient.listSummariesResult = .success([])
        mockAPIClient.listReportsResult = .success(TestFixtures.sampleReports)
        await sut.loadData()

        // Jan 15 is a Monday (start of a report week)
        let jan15 = makeDate(year: 2024, month: 1, day: 15)
        XCTAssertTrue(sut.hasReport(forWeekContaining: jan15))
    }

    func test_hasReport_returnsFalseForWeeksWithoutReports() async {
        mockAPIClient.listSummariesResult = .success([])
        mockAPIClient.listReportsResult = .success(TestFixtures.sampleReports)
        await sut.loadData()

        let jan22 = makeDate(year: 2024, month: 1, day: 22)
        XCTAssertFalse(sut.hasReport(forWeekContaining: jan22))
    }

    func test_reportForWeek_returnsReport() async {
        mockAPIClient.listSummariesResult = .success([])
        mockAPIClient.listReportsResult = .success(TestFixtures.sampleReports)
        await sut.loadData()

        // The third week row (index 2) should contain Jan 14-20, Monday = Jan 15
        let week = sut.weeks[2]
        let report = sut.reportForWeek(week)
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.weekOf, "2024-01-15")
    }

    // MARK: - hasInsightsThisMonth

    func test_hasInsightsThisMonth_trueWhenSummariesExist() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        mockAPIClient.listReportsResult = .success([])
        await sut.loadData()
        XCTAssertTrue(sut.hasInsightsThisMonth)
    }

    func test_hasInsightsThisMonth_falseForEmptyMonth() async {
        mockAPIClient.listSummariesResult = .success([])
        mockAPIClient.listReportsResult = .success([])
        await sut.loadData()

        sut.navigateToNextMonth() // Feb 2024 - no data
        XCTAssertFalse(sut.hasInsightsThisMonth)
    }

    // MARK: - Weekday Symbols

    func test_weekdaySymbols_startWithSunday() {
        // Calendar firstWeekday = 1 (Sunday)
        let symbols = sut.weekdaySymbols
        XCTAssertEqual(symbols.first, "S") // Sunday
        XCTAssertEqual(symbols.count, 7)
    }

    // MARK: - February Edge Case

    func test_february2024_leapYear_has29Days() {
        sut.navigateToNextMonth() // Feb 2024
        let allDays = sut.weeks.flatMap(\.days).filter(\.isCurrentMonth)
        XCTAssertEqual(allDays.count, 29)
    }

    // MARK: - State Equality

    func test_stateEquality() {
        XCTAssertEqual(CalendarViewModel.State.loading, CalendarViewModel.State.loading)
        XCTAssertEqual(CalendarViewModel.State.loaded, CalendarViewModel.State.loaded)
        XCTAssertNotEqual(CalendarViewModel.State.loading, CalendarViewModel.State.loaded)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Self.staticMakeDate(year: year, month: month, day: day)
    }

    // swiftlint:disable:next force_unwrapping
    fileprivate static let utcTimeZone = TimeZone(identifier: "UTC")!

    fileprivate static func staticMakeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = utcTimeZone
        // Safe: valid year/month/day always produce a date
        // swiftlint:disable:next force_unwrapping
        return calendar.date(from: components)!
    }
}
