# Task 0019: Persistent Search UI

**Status**: Complete

## Specifications

Add iOS views for managing persistent search monitors. The backend API is fully implemented (Task 0013) with 7 endpoints for CRUD operations, monitor details, and summary retrieval. This task adds the iOS models, views, and view models to expose the persistent search functionality to users.

### Design Overview

The persistent search UI integrates into the existing iOS app as a new section accessible from the Search tab. Users can create search monitors with configurable terms, schedule intervals, and novelty thresholds. Each monitor displays its execution status, recent summaries, and flagged significant updates.

**Navigation Flow:**
- Search tab gains a "Search Monitors" section or toggle above the existing keyword/semantic search
- Monitor list shows all monitors with status indicators (active/paused), next execution time, and last novelty score
- Tapping a monitor navigates to a detail view showing configuration and chronological summaries
- Create/edit forms with validation matching backend constraints
- Swipe-to-delete on monitor list with confirmation

### Backend API (already implemented)

| Method | Endpoint | Lambda | Purpose |
|--------|----------|--------|---------|
| POST | /searches | api_search_monitors | Create monitor |
| GET | /searches | api_search_monitors | List monitors |
| GET | /searches/{id} | api_search_monitor_detail | Monitor + recent summaries |
| PUT | /searches/{id} | api_search_monitors | Update monitor |
| DELETE | /searches/{id} | api_search_monitors | Delete monitor |
| GET | /searches/{id}/summaries | api_search_summaries | List summaries |
| GET | /searches/{id}/summaries/{timestamp} | api_search_summaries | Get specific summary |

### Data Models

**SearchMonitor:**
```
id: String (UUID)
name: String (required, non-blank)
description: String (optional, defaults to "")
searchTerms: [String] (required, non-empty)
intervalHours: Int (1-168, default 6)
noveltyThreshold: Double (0.0-1.0, default 0.3)
status: "active" | "paused"
lastExecuted: String? (ISO-8601)
nextExecution: String (ISO-8601)
created: String (ISO-8601)
modified: String (ISO-8601)
```

**SearchSummary:**
```
timestamp: String (ISO-8601)
summary: String
topics: [String]
noveltyScore: Double (0.0-1.0)
significantUpdate: Bool
newItems: [String]
changedItems: [String]
removedItems: [String]
analysis: String?
```

### API Response Shapes

- `GET /searches` → `{ monitors: [SearchMonitor], count: Int }`
- `GET /searches/{id}` → `{ monitor: SearchMonitor, summaries: [SearchSummary], summaryCount: Int }`
- `GET /searches/{id}/summaries` → `{ summaries: [SearchSummary], count: Int, monitorId: String }`
- `POST /searches` → `SearchMonitor`
- `PUT /searches/{id}` → `SearchMonitor`
- `DELETE /searches/{id}` → `{ deleted: Bool, id: String }`

## Relevant Files

### New Files
- `ios/PKMReader/Models/SearchMonitor.swift` — SearchMonitor and SearchSummary models
- `ios/PKMReader/Features/Search/SearchMonitorListView.swift` — Monitor list view
- `ios/PKMReader/Features/Search/SearchMonitorDetailView.swift` — Monitor detail with summaries
- `ios/PKMReader/Features/Search/SearchMonitorFormView.swift` — Create/edit monitor form
- `ios/PKMReader/Features/Search/SearchMonitorListViewModel.swift` — List view model
- `ios/PKMReader/Features/Search/SearchMonitorDetailViewModel.swift` — Detail view model
- `ios/PKMReader/Features/Search/SearchSummaryView.swift` — Summary detail rendering
- `ios/PKMReaderTests/Features/Search/SearchMonitorListViewModelTests.swift` — List VM tests
- `ios/PKMReaderTests/Features/Search/SearchMonitorDetailViewModelTests.swift` — Detail VM tests

### Modified Files
- `ios/PKMReader/Core/Networking/APIClientProtocol.swift` — Add 7 search monitor methods
- `ios/PKMReader/Core/Networking/APIClient.swift` — Implement search monitor API calls
- `ios/PKMReader/Core/Networking/APIEndpoints.swift` — Add search monitor endpoints
- `ios/PKMReader/Core/Testing/UITestAPIClient.swift` — Add mock search monitor data
- `ios/PKMReaderTests/Mocks/MockAPIClient.swift` — Add search monitor mock methods
- `ios/PKMReader/Features/Search/SearchView.swift` — Add monitor list navigation

### Reference Files (existing patterns)
- `ios/PKMReader/Features/Insights/CalendarViewModel.swift` — View model pattern
- `ios/PKMReader/Models/Summary.swift` — Model pattern (Identifiable, Codable, Hashable, Sendable)
- `lambda/functions/api_search_monitors/handler.clj` — Backend validation rules

## Acceptance Criteria

- [x] SearchMonitor and SearchSummary models created as Codable/Sendable structs
- [x] APIClientProtocol extended with 7 search monitor methods
- [x] APIClient implements all search monitor API calls following existing patterns
- [x] Monitor list view displays all monitors with status, next execution, and novelty indicators
- [x] Monitor detail view shows configuration and chronological summaries
- [x] Create form validates: non-blank name, non-empty search terms, intervalHours 1-168, threshold 0.0-1.0
- [x] Edit form pre-populates existing values and supports partial updates
- [x] Pause/resume toggle on monitor detail view
- [x] Swipe-to-delete with confirmation dialog
- [x] Summary detail view renders summary text, topics, novelty score, new/changed/removed items
- [x] Significant updates visually highlighted in summary list
- [x] Pull-to-refresh on monitor list and detail views
- [x] UITestAPIClient provides fixture search monitor data
- [x] MockAPIClient supports configurable results for all 7 methods
- [x] Unit tests for SearchMonitorListViewModel (list, create, delete, error states)
- [x] Unit tests for SearchMonitorDetailViewModel (load, update, pause/resume, summaries)
- [x] All existing tests continue to pass

## Implementation Steps

- [x] Step 1: Create SearchMonitor and SearchSummary models with response wrapper structs
- [x] Step 2: Add search monitor methods to APIClientProtocol
- [x] Step 3: Implement API calls in APIClient following existing GET/POST/PUT/DELETE patterns
- [x] Step 4: Add endpoints to APIEndpoints
- [x] Step 5: Create SearchMonitorListViewModel with list, create, and delete operations
- [x] Step 6: Create SearchMonitorListView with monitor cards showing status, terms, schedule
- [x] Step 7: Create SearchMonitorFormView for create and edit with input validation
- [x] Step 8: Create SearchMonitorDetailViewModel with load, update, pause/resume, and summary fetching
- [x] Step 9: Create SearchMonitorDetailView showing monitor config and summary timeline
- [x] Step 10: Create SearchSummaryView for rendering individual summary details
- [x] Step 11: Integrate monitor list into SearchView (section or navigation link)
- [x] Step 12: Add fixture data to UITestAPIClient and MockAPIClient
- [x] Step 13: Write unit tests for both view models
- [x] Step 14: Verify all existing tests pass, run linting
