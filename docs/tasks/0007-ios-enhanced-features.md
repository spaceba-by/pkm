# Task 0007: iOS Enhanced Features

**Status**: Planned

## Specifications

iOS Phase 3: Add enhanced features to the iOS app including search functionality, tags browsing, daily summaries view, weekly reports view, and settings. This transforms the app from a basic document browser into a full-featured PKM reader.

## Relevant Files

- `ios/PKMReader/Views/Search/` - Search view (to be created)
- `ios/PKMReader/Views/Tags/` - Tags browsing view (to be created)
- `ios/PKMReader/Views/Summaries/` - Daily summaries view (to be created)
- `ios/PKMReader/Views/Reports/` - Weekly reports view (to be created)
- `ios/PKMReader/Views/Settings/` - Settings view (to be created)
- `ios/PKMReader/ViewModels/` - View models for new features
- `lambda/functions/api_search/handler.clj` - Existing search API
- `lambda/functions/api_list_tags/handler.clj` - Existing tags API
- `lambda/functions/api_list_summaries/handler.clj` - Existing summaries API
- `lambda/functions/api_list_reports/handler.clj` - Existing reports API

## Acceptance Criteria

- [ ] Search view with text input and real-time results
- [ ] Tags browsing view with tag counts and document lists
- [ ] Daily summaries view showing AI-generated summaries
- [ ] Weekly reports view showing AI-generated reports
- [ ] Settings view with user preferences
- [ ] Pull-to-refresh and pagination on all list views
- [ ] All new features covered by unit tests
- [ ] All new features covered by UI tests
- [ ] Code coverage ≥75%

## Implementation Steps

- [ ] Step 1: Implement `SearchViewModel` with debounced search
- [ ] Step 2: Build `SearchView` with search bar and results list
- [ ] Step 3: Implement `TagsViewModel` with tag listing and filtering
- [ ] Step 4: Build `TagsView` with tag list and document drill-down
- [ ] Step 5: Implement `SummariesViewModel` for daily summary listing
- [ ] Step 6: Build `SummariesView` with summary cards
- [ ] Step 7: Implement `ReportsViewModel` for weekly report listing
- [ ] Step 8: Build `ReportsView` with report cards
- [ ] Step 9: Build `SettingsView` with user preferences
- [ ] Step 10: Add pull-to-refresh and pagination to all new views
- [ ] Step 11: Write unit tests for all new view models
- [ ] Step 12: Write UI tests for all new user flows
