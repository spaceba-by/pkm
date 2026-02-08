# Task 0007: iOS Enhanced Features

**Status**: In Progress

## Specifications

iOS Phase 3: Add search, tags browsing, AI summaries, weekly reports, and enhanced settings to the PKM Reader app. This transforms the app from a basic document browser into a full-featured read-only PKM client.

**Tab bar expansion**: The current 2-tab layout (Documents, Settings) expands to 5 tabs:

1. **Documents** (existing) - Document list with classification filter
2. **Search** (new) - Text search with debounced input and results list
3. **Tags** (new) - Browse all tags with counts, drill down to documents by tag
4. **Insights** (new) - Daily AI summaries and weekly reports, toggled via segmented control
5. **Settings** (existing, enhanced) - Add cache management and display preferences

**Key design decisions**:

- Summaries and reports share a single "Insights" tab with a `Picker` segment to keep tabs at 5 (iOS limit without "More")
- Search uses 300ms debounce to avoid excessive API calls while typing
- Tags view uses a two-level navigation: tag list -> documents with that tag
- Summary/report detail views load markdown content via `getDocument(key:)` (the S3 key from list responses doubles as the document key)
- All new view models follow the existing `State` enum pattern from `DocumentListViewModel`
- New `documentsByTag(tag:limit:)` method added to `APIClientProtocol` since the backend endpoint exists but the client doesn't expose it yet

## Relevant Files

### Existing files to modify

- `ios/PKMReader/App/MainTabView.swift` - Expand from 2 tabs to 5
- `ios/PKMReader/Core/Networking/APIClientProtocol.swift` - Add `documentsByTag` method
- `ios/PKMReader/Core/Networking/APIClient.swift` - Implement `documentsByTag`
- `ios/PKMReader/Core/Networking/APIEndpoints.swift` - Add documents-by-tag endpoint path
- `ios/PKMReader/Features/Settings/SettingsView.swift` - Add cache clear and preferences
- `ios/PKMReaderTests/Mocks/MockAPIClient.swift` - Add `documentsByTag` mock
- `ios/PKMReaderTests/Fixtures/TestFixtures.swift` - Add Summary and Report fixtures

### New files to create

- `ios/PKMReader/Features/Search/SearchView.swift` - Search UI with search bar and results
- `ios/PKMReader/Features/Search/SearchViewModel.swift` - Debounced search logic
- `ios/PKMReader/Features/Tags/TagsView.swift` - Tag list with counts
- `ios/PKMReader/Features/Tags/TagDocumentsView.swift` - Documents filtered by tag
- `ios/PKMReader/Features/Tags/TagsViewModel.swift` - Tag list loading
- `ios/PKMReader/Features/Tags/TagDocumentsViewModel.swift` - Documents-by-tag loading
- `ios/PKMReader/Features/Insights/InsightsView.swift` - Container with segment toggle
- `ios/PKMReader/Features/Insights/SummaryListView.swift` - Daily summary list
- `ios/PKMReader/Features/Insights/SummaryDetailView.swift` - Summary content view
- `ios/PKMReader/Features/Insights/ReportListView.swift` - Weekly report list
- `ios/PKMReader/Features/Insights/ReportDetailView.swift` - Report content view
- `ios/PKMReader/Features/Insights/SummariesViewModel.swift` - Summary list loading
- `ios/PKMReader/Features/Insights/ReportsViewModel.swift` - Report list loading
- `ios/PKMReader/Features/Insights/InsightDetailViewModel.swift` - Content loading for summary/report detail
- `ios/PKMReaderTests/Features/Search/SearchViewModelTests.swift` - Search VM tests
- `ios/PKMReaderTests/Features/Tags/TagsViewModelTests.swift` - Tags VM tests
- `ios/PKMReaderTests/Features/Tags/TagDocumentsViewModelTests.swift` - Tag documents VM tests
- `ios/PKMReaderTests/Features/Insights/SummariesViewModelTests.swift` - Summaries VM tests
- `ios/PKMReaderTests/Features/Insights/ReportsViewModelTests.swift` - Reports VM tests

## Acceptance Criteria

- [ ] Search view with text input, debounced queries, and navigable results list
- [ ] Tags browsing view with alphabetical tag list showing document counts
- [ ] Tag drill-down showing documents with a specific tag
- [ ] Daily summaries list showing AI-generated summary dates, tappable for content
- [ ] Weekly reports list showing report dates, tappable for content
- [ ] Summary and report detail views render markdown content
- [ ] Settings view includes cache clear button and display preferences
- [ ] MainTabView has 5 tabs: Documents, Search, Tags, Insights, Settings
- [ ] Pull-to-refresh on all list views (search results, tags, summaries, reports)
- [ ] Empty and error states handled on all new views
- [ ] All new view models covered by unit tests
- [ ] UI tests cover search, tag browsing, and insights flows
- [ ] `documentsByTag` method added to `APIClientProtocol` and `APIClient`
- [ ] MockAPIClient updated with `documentsByTag` support
- [ ] No SwiftLint errors
- [ ] CI pipeline passes

## Implementation Steps

- [x] Step 1: Add `documentsByTag` to API layer
  - Add `documentsByTag(tag: String, limit: Int) async throws -> [Document]` to `APIClientProtocol`
  - Implement in `APIClient` calling `GET /tags/{tag}/documents`
  - Add endpoint path to `APIEndpoints`
  - Update `MockAPIClient` with configurable result and call tracking
  - Add Summary/Report fixtures to `TestFixtures`

- [x] Step 2: Implement search feature
  - Create `SearchViewModel` with `State` enum (idle/loading/loaded/empty/error)
  - Add 300ms debounce using `Task` + `Task.sleep` on search text changes
  - Minimum 2-character query (matching backend requirement)
  - Create `SearchView` with `.searchable` modifier or custom search bar
  - Display results as `DocumentRowView` items with navigation to `DocumentDetailView`
  - Write `SearchViewModelTests` covering: debounce, empty query, results, error

- [x] Step 3: Implement tags browsing feature
  - Create `TagsViewModel` with `State` enum (loading/loaded/empty/error)
  - Create `TagsView` with alphabetical tag list, each row showing name + count
  - Create `TagDocumentsViewModel` loading documents for a specific tag
  - Create `TagDocumentsView` listing documents, navigating to `DocumentDetailView`
  - Write `TagsViewModelTests` and `TagDocumentsViewModelTests`

- [x] Step 4: Implement insights feature (summaries + reports)
  - Create `SummariesViewModel` with `State` enum, loads via `listSummaries(limit:)`
  - Create `ReportsViewModel` with `State` enum, loads via `listReports(limit:)`
  - Create `InsightDetailViewModel` to load markdown content via `getDocument(key:)`
  - Create `InsightsView` with `Picker` segment (Summaries / Reports)
  - Create `SummaryListView` showing date-sorted summary cards
  - Create `ReportListView` showing date-sorted report cards
  - Create `SummaryDetailView` and `ReportDetailView` rendering markdown
  - Write `SummariesViewModelTests` and `ReportsViewModelTests`

- [x] Step 5: Expand MainTabView and enhance Settings
  - Update `MainTabView` to 5 tabs: Documents, Search, Tags, Insights, Settings
  - Tab icons: doc.text, magnifyingglass, tag, lightbulb.max, gear
  - Enhance `SettingsView` with cache clear button (calls `CacheService`)
  - Add display preference toggles (e.g., compact list mode) using `@AppStorage`
  - Pass `apiClient` to all new tab views

- [x] Step 6: Add pull-to-refresh and polish
  - Add `.refreshable` to SearchView, TagsView, InsightsView list views
  - Ensure all views use shared components (LoadingView, ErrorView, EmptyStateView)
  - Verify navigation from all new views to DocumentDetailView works
  - Confirm accessibility identifiers on all new interactive elements

- [x] Step 7: Write UI tests
  - Test search flow: type query -> see results -> tap result -> see detail
  - Test tags flow: see tag list -> tap tag -> see documents -> tap document
  - Test insights flow: see summaries -> switch to reports -> tap item -> see detail
  - Test settings: tap clear cache button

- [x] Step 8: Final verification
  - Run all unit tests (`bb test` from lambda/ still passes)
  - Run iOS unit tests and UI tests
  - Verify no SwiftLint errors
  - Verify CI pipeline compatibility
  - Confirm code coverage >= 75%
