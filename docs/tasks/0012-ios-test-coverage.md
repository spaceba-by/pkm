# Task 0012: iOS Test Coverage

**Status**: Planned

## Specifications

Improve iOS test coverage to build confidence that all Task 0007 features work correctly end-to-end. The current unit tests verify ViewModel logic but leave gaps in UI integration, navigation flows, and several untested components.

Three areas of work:

1. **Missing unit tests**: `InsightDetailViewModel` has no test coverage, and Settings cache/preference logic is untested
2. **Mock API infrastructure for UI tests**: All 4 UI test files (Search, Tags, Insights, Settings) are skipped with `XCTSkip("Deferred: Requires mock API infrastructure")`. Implement a launch argument-based mock mode so the app can run against fake data in UI tests without hitting AWS
3. **Enable and expand UI tests**: With mock infrastructure in place, un-skip UI tests and verify end-to-end flows: tab navigation, list-to-detail navigation, pull-to-refresh, empty/error states, and markdown rendering

## Relevant Files

### Unit tests to add

- `ios/PKMReaderTests/Features/Insights/InsightDetailViewModelTests.swift` (new)
- `ios/PKMReaderTests/Features/Settings/SettingsViewTests.swift` (new)

### Mock API infrastructure

- `ios/PKMReader/Core/Networking/MockURLProtocol.swift` (new, or similar approach)
- `ios/PKMReader/App/PKMReaderApp.swift` - Add launch argument detection for mock mode
- `ios/PKMReaderTests/Mocks/MockAPIClient.swift` - Existing mock, may need updates

### UI tests to enable

- `ios/PKMReaderUITests/Screens/SearchScreenTests.swift` - Remove XCTSkip, implement tests
- `ios/PKMReaderUITests/Screens/TagsScreenTests.swift` - Remove XCTSkip, implement tests
- `ios/PKMReaderUITests/Screens/InsightsScreenTests.swift` - Remove XCTSkip, implement tests
- `ios/PKMReaderUITests/Screens/SettingsScreenTests.swift` - Remove XCTSkip, implement tests

### Page objects (already scaffolded)

- `ios/PKMReaderUITests/PageObjects/SearchPage.swift`
- `ios/PKMReaderUITests/PageObjects/TagsPage.swift`
- `ios/PKMReaderUITests/PageObjects/InsightsPage.swift`

## Acceptance Criteria

- [ ] `InsightDetailViewModel` covered by unit tests (load success, load error, state transitions)
- [ ] Settings cache clear and preference toggles covered by unit tests
- [ ] Mock API infrastructure allows UI tests to run without AWS credentials
- [ ] Search UI test: type query → see results → tap result → see detail
- [ ] Tags UI test: see tag list → tap tag → see documents → tap document
- [ ] Insights UI test: see summaries → switch to reports → tap item → see detail
- [ ] Settings UI test: tap clear cache button, toggle preferences
- [ ] 5-tab layout verified in UI tests
- [ ] Pull-to-refresh verified on at least one list view
- [ ] Empty and error states verified in UI tests
- [ ] All UI tests pass in CI pipeline
- [ ] Code coverage ≥ 40%

## Implementation Steps

- [ ] Step 1: Add `InsightDetailViewModel` unit tests
  - Test load success via `getDocument(key:)`
  - Test load error state
  - Test state transitions (loading → loaded, loading → error)

- [ ] Step 2: Add Settings unit tests
  - Test cache clear calls `DocumentCacheService`
  - Test `@AppStorage` preference toggles

- [ ] Step 3: Implement mock API infrastructure for UI tests
  - Add launch argument (e.g., `--mock-api`) detection in app entry point
  - Create in-process mock that returns fixture data for all API endpoints
  - Wire mock into dependency injection when launch argument is present

- [ ] Step 4: Enable and implement Search UI tests
  - Remove `XCTSkip` from `SearchScreenTests`
  - Test full search flow using `SearchPage` page object
  - Verify empty state, results display, navigation to detail

- [ ] Step 5: Enable and implement Tags UI tests
  - Remove `XCTSkip` from `TagsScreenTests`
  - Test tag list display and drill-down navigation
  - Verify document list under a tag, navigation to detail

- [ ] Step 6: Enable and implement Insights UI tests
  - Remove `XCTSkip` from `InsightsScreenTests`
  - Test segment switching between summaries and reports
  - Test tapping an item and viewing detail with rendered markdown

- [ ] Step 7: Enable and implement Settings UI tests
  - Remove `XCTSkip` from `SettingsScreenTests`
  - Test cache clear button interaction
  - Test preference toggles

- [ ] Step 8: Verify CI and coverage
  - Confirm all UI tests pass in GitHub Actions
  - Verify code coverage meets ≥ 40% threshold
  - Update coverage threshold in `ios-test.yml` if needed
