# Task 0017: Insights Calendar Design

**Status**: Planned

## Specifications

Redesign the Insights tab to use a monthly calendar view instead of the current segmented list picker. The calendar provides a natural, time-oriented way to browse daily summaries and weekly reports since all insights are inherently associated with specific time periods.

### Current State

- **Insights tab**: Segmented control switches between flat lists of Summaries and Reports
- **Summaries**: Listed chronologically with date strings (YYYY-MM-DD), tapping navigates to markdown detail view
- **Reports**: Listed chronologically with "Week of YYYY-MM-DD" labels, tapping navigates to markdown detail view
- **Data**: Summaries keyed by date (`_agent/summaries/YYYY-MM-DD.md`), reports keyed by week start Monday (`_agent/reports/weekly/YYYY-MM-DD.md`)

### Design Goals

- Replace the segmented list UI with a monthly calendar grid
- Visually indicate which days have an associated daily summary
- Visually indicate which weeks have an associated weekly report
- Support month-to-month navigation similar to the iOS Calendar app
- Maintain access to the existing detail views (summary and report markdown rendering)
- Provide an intuitive, glanceable overview of knowledge management activity over time

### Calendar Behavior

- **Monthly grid**: Standard 7-column calendar grid (Sun–Sat or locale-aware) showing one month at a time
- **Month navigation**: Swipe horizontally or use chevron buttons to move between months, with the current month/year displayed as a title (matching iOS Calendar app conventions)
- **Today indicator**: Highlight the current day distinctly
- **Summary indicators**: Days with a daily summary should display a visible dot or marker beneath the date number
- **Report indicators**: Weeks with a weekly report should display a visual indicator along the week row (e.g., a subtle side bar, background highlight, or icon at the start/end of the row)
- **Tap interactions**:
  - Tapping a day with a summary navigates to the `SummaryDetailView`
  - Tapping a week's report indicator navigates to the `ReportDetailView`
  - Tapping a day without a summary has no navigation effect (or shows a subtle empty state)
- **Data loading**: Fetch summaries and reports on tab load; the calendar overlays indicators based on the available date sets
- **Scrollback**: Support navigating to past months where data exists; no arbitrary future navigation needed

## Relevant Files

### Views (modified/replaced)

- `ios/PKMReader/Features/Insights/InsightsView.swift` - Replace segmented control with calendar view
- `ios/PKMReader/Features/Insights/SummaryListView.swift` - Remove (replaced by calendar)
- `ios/PKMReader/Features/Insights/ReportListView.swift` - Remove (replaced by calendar)
- `ios/PKMReader/Features/Insights/SummaryDetailView.swift` - Keep (navigation target from calendar)
- `ios/PKMReader/Features/Insights/ReportDetailView.swift` - Keep (navigation target from calendar)

### New Views

- `ios/PKMReader/Features/Insights/CalendarView.swift` (new) - Monthly calendar grid component
- `ios/PKMReader/Features/Insights/CalendarDayCell.swift` (new) - Individual day cell with summary/report indicators
- `ios/PKMReader/Features/Insights/CalendarHeaderView.swift` (new) - Month/year title with navigation chevrons
- `ios/PKMReader/Features/Insights/WeekReportIndicator.swift` (new) - Visual indicator for weeks with reports

### View Models (modified/new)

- `ios/PKMReader/Features/Insights/SummariesViewModel.swift` - Retain for data fetching, adapt interface
- `ios/PKMReader/Features/Insights/ReportsViewModel.swift` - Retain for data fetching, adapt interface
- `ios/PKMReader/Features/Insights/CalendarViewModel.swift` (new) - Manages displayed month, navigation, date-to-insight mapping
- `ios/PKMReader/Features/Insights/InsightDetailViewModel.swift` - Keep unchanged

### Models

- `ios/PKMReader/Models/Summary.swift` - Unchanged
- `ios/PKMReader/Models/Report.swift` - Unchanged

### Tests (new/modified)

- `ios/PKMReaderTests/Features/Insights/CalendarViewModelTests.swift` (new)
- `ios/PKMReaderTests/Features/Insights/SummariesViewModelTests.swift` - Update if interface changes
- `ios/PKMReaderTests/Features/Insights/ReportsViewModelTests.swift` - Update if interface changes
- `ios/PKMReaderUITests/Screens/InsightsScreenTests.swift` - Update for calendar interactions
- `ios/PKMReaderUITests/PageObjects/InsightsPage.swift` - Update page object for calendar elements

### Mock/Test Data

- `ios/PKMReader/Core/Testing/UITestAPIClient.swift` - Expand fixture data to span multiple months
- `ios/PKMReaderTests/Fixtures/TestFixtures.swift` - Add multi-month summary/report fixtures

## Acceptance Criteria

- [ ] UI mockups designed and approved before implementation begins
- [ ] Monthly calendar grid displays with correct day layout for each month
- [ ] Month-to-month navigation via swipe and/or chevron buttons
- [ ] Days with daily summaries show a visual indicator (dot/marker)
- [ ] Weeks with weekly reports show a distinct visual indicator
- [ ] Today's date is visually highlighted
- [ ] Tapping a day with a summary navigates to SummaryDetailView
- [ ] Tapping a week's report indicator navigates to ReportDetailView
- [ ] Days without content are visually distinct and non-navigable
- [ ] Calendar handles months with no data gracefully
- [ ] Pull-to-refresh reloads summary and report data
- [ ] Existing detail views (SummaryDetailView, ReportDetailView) remain functional
- [ ] CalendarViewModel has unit test coverage
- [ ] UI tests updated for calendar-based navigation
- [ ] Snapshot tests added for calendar states (loaded, empty month, today highlight)
- [ ] Accessibility: VoiceOver labels for days, summary/report indicators, month navigation

## Implementation Steps

- [ ] Step 1: UI Mockup Design
  - Create ASCII or SwiftUI preview mockups of the calendar layout
  - Mockup monthly grid showing day numbers in a 7-column grid
  - Mockup summary dot indicators on days with content
  - Mockup week-level report indicators (sidebar, highlight, or icon)
  - Mockup month navigation header with chevrons and month/year title
  - Mockup selected-day state and today highlight
  - Mockup empty month state
  - Document interaction model: what happens on tap of day, week indicator, empty day
  - Present mockups for review and approval before proceeding

- [ ] Step 2: CalendarViewModel and Data Layer
  - Create `CalendarViewModel` managing: displayed month/year, navigation, date sets
  - Compute calendar grid data: first weekday offset, number of days, week rows
  - Build lookup sets from Summary dates and Report weekOf dates
  - Expose methods: `hasSummary(for date: Date) -> Bool`, `hasReport(for weekStarting: Date) -> Bool`
  - Expose `summaryForDate(_ date: Date) -> Summary?` and `reportForWeek(_ date: Date) -> Report?`
  - Handle month navigation (next/previous) with boundary logic
  - Load summaries and reports via existing view models or direct API calls
  - Unit tests for grid computation, date lookups, month navigation

- [ ] Step 3: Calendar UI Components
  - Implement `CalendarHeaderView` with month/year title and left/right chevron buttons
  - Implement `CalendarDayCell` showing date number, summary dot, today highlight, tap gesture
  - Implement `WeekReportIndicator` for rows with an associated weekly report
  - Implement `CalendarView` composing header, weekday labels row, and day grid
  - Support swipe gesture for month navigation (horizontal swipe or `TabView` with page style)
  - Style to match iOS system calendar conventions (SF Symbols, system colors)

- [ ] Step 4: Integrate Calendar into InsightsView
  - Replace segmented control and list views with `CalendarView`
  - Wire tap on summary day to navigate to `SummaryDetailView`
  - Wire tap on report indicator to navigate to `ReportDetailView`
  - Implement pull-to-refresh on the calendar view
  - Handle loading and error states
  - Remove `SummaryListView` and `ReportListView` (or keep as fallback if desired)

- [ ] Step 5: Accessibility and Polish
  - Add VoiceOver labels: "[Date], daily summary available" or "[Date], no summary"
  - Add VoiceOver hints for report indicators: "Double tap to view weekly report"
  - Add accessibility traits for interactive day cells
  - Add `@ScaledMetric` for Dynamic Type support on calendar cell sizes
  - Style today indicator, summary dots, and report indicators with system semantic colors
  - Test with VoiceOver and Dynamic Type at various sizes

- [ ] Step 6: Tests and Snapshots
  - Update `InsightsScreenTests` UI tests for calendar navigation and tapping
  - Update `InsightsPage` page object for calendar elements
  - Add `CalendarViewModelTests`: month navigation, date lookup, grid computation, edge cases
  - Add snapshot tests: calendar with data, empty month, today highlighted
  - Expand mock fixtures in `UITestAPIClient` and `TestFixtures` to cover multiple months
  - Verify existing detail view tests still pass
