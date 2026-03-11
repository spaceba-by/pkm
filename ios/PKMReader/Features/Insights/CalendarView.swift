import SwiftUI

/// Monthly calendar grid composing the header, weekday labels, and day cells with report indicators
struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onSummaryTap: (Summary) -> Void
    let onReportTap: (Report) -> Void

    var body: some View {
        VStack(spacing: 8) {
            CalendarHeaderView(
                title: viewModel.displayedMonthTitle,
                onPrevious: { viewModel.navigateToPreviousMonth() },
                onNext: { viewModel.navigateToNextMonth() }
            )

            weekdayLabels

            calendarGrid
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        viewModel.navigateToNextMonth()
                    } else if value.translation.width > 50 {
                        viewModel.navigateToPreviousMonth()
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("CalendarView")
    }

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            // Spacer for report indicator column
            Color.clear.frame(width: 6)

            ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            ForEach(viewModel.weeks) { week in
                weekRow(week)
            }
        }
        .padding(.horizontal, 8)
    }

    private func weekRow(_ week: CalendarWeek) -> some View {
        let report = viewModel.reportForWeek(week)
        return HStack(spacing: 0) {
            WeekReportIndicator(
                hasReport: report != nil,
                isUnread: report.map { !$0.viewed } ?? false,
                onTap: report.map { r in { onReportTap(r) } }
            )

            Spacer().frame(width: 3)

            ForEach(week.days) { day in
                let summary = day.isCurrentMonth ? viewModel.summaryForDate(day.date) : nil
                CalendarDayCell(
                    day: day,
                    hasSummary: summary != nil,
                    isUnread: summary.map { !$0.viewed } ?? false,
                    onTap: summary.map { s in { onSummaryTap(s) } }
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}
