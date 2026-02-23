# Task 0033: Unified Documents View

**Status**: Complete ✅

## Specifications

Consolidate the Documents, Search, and Tags tabs into a single "Documents" tab. The current 6-tab layout (Documents, Search, Tags, Insights, Settings, Graph) has significant overlap — all three tabs display documents using the same `DocumentRowView` and navigate to the same `DocumentDetailView`. Merging them reduces navigation friction and simplifies the tab bar to 4 tabs: Documents, Insights, Settings, Graph.

### Design Overview

**Search**: Integrated directly into the Documents tab via `.searchable(text:prompt:)`. Typing in the search bar switches the view from browse mode to search results with a keyword/semantic mode picker. Browse state is preserved while searching.

**Tags**: Integrated into an expanded FilterSheet (presented as a sheet/popover) with both Classification and Tags sections. Selecting a tag filters the document list inline rather than navigating to a separate view.

**Search Monitors**: Remain accessible from the unified Documents view via a toolbar button (binoculars icon). All SearchMonitor files in `Features/Search/` are kept unchanged.

**Result**: 4 tabs — Documents, Insights, Settings, Graph.

### Architecture

#### ViewModel: Expand `DocumentListViewModel`

Absorb search and tag-filtering logic into the existing ViewModel rather than creating a new one.

- **Dual state tracks**: Keep existing `state` (browse mode) + add `searchState: SearchState` (search mode). View checks `isSearchActive` to decide which state to render. Browse state is preserved while searching.
- **Search**: `searchText` with `didSet` triggers 300ms debounced search via `apiClient.search()`. `searchMode` (keyword/semantic) toggles re-trigger search.
- **Tag filter**: `selectedTag: Tag?` — when set, `fetchDocuments()` calls `documentsByTag` instead of `listDocuments`. Pagination disabled in tag-filtered mode.
- **Tag + Classification**: When both active, fetch by tag then client-side filter by classification (the API doesn't support combining both).
- **Tags list**: `tags: [Tag]` loaded lazily for the FilterSheet.

#### View: Unified `DocumentListView`

- Add `.searchable(text:prompt:)` for search bar
- When `isSearchActive`: render search results (from `searchState`), show keyword/semantic picker, hide sort menu
- When not searching: render browse list (from `state`) with existing pagination, sort, filter
- Toolbar: create (+), sort, filter, search monitors (binoculars icon)
- Search idle state shows "Enter at least 2 characters" hint

#### FilterSheet: Expand with Tags

- **Classification section** (existing, unchanged)
- **Tags section** (new): searchable list of all tags with counts, single-select, tap to toggle
- Active filter indicator on filter button (filled icon when any filter active)
- Detents: `.medium` and `.large`

#### MainTabView: 4 Tabs

Remove Search (tag 1) and Tags (tag 2). Renumber: Documents (0), Insights (1), Settings (2), Graph (3).

## Relevant Files

### Files to Modify

- `ios/PKMReader/App/MainTabView.swift` — Remove 2 tabs, renumber
- `ios/PKMReader/Features/DocumentList/DocumentListViewModel.swift` — Add search state, debounce, tag filtering, tags loading
- `ios/PKMReader/Features/DocumentList/DocumentListView.swift` — Add .searchable, search mode picker, search monitors button, conditional browse/search rendering
- `ios/PKMReader/Features/DocumentList/FilterSheet.swift` — Add Tags section with searchable tag list
- `ios/PKMReaderTests/Features/DocumentList/DocumentListViewModelTests.swift` — Add search + tag filter tests
- `ios/PKMReaderUITests/Screens/DocumentListScreenTests.swift` — Add search + filter UI tests
- `ios/PKMReaderUITests/PageObjects/DocumentListPage.swift` — Add search/filter page object methods
- `ios/PKMReaderUITests/Screens/SearchMonitorScreenTests.swift` — Update navigation path

### Files to Delete

- `ios/PKMReader/Features/Search/SearchView.swift` — Merged into DocumentListView
- `ios/PKMReader/Features/Search/SearchViewModel.swift` — Merged into DocumentListViewModel
- `ios/PKMReader/Features/Tags/TagsView.swift` — Merged into DocumentListView
- `ios/PKMReader/Features/Tags/TagsViewModel.swift` — Merged into DocumentListViewModel
- `ios/PKMReader/Features/Tags/TagDocumentsView.swift` — Merged into DocumentListView
- `ios/PKMReader/Features/Tags/TagDocumentsViewModel.swift` — Merged into DocumentListViewModel
- `ios/PKMReaderTests/Features/Search/SearchViewModelTests.swift` — Tests migrated to DocumentListViewModelTests
- `ios/PKMReaderTests/Features/Tags/TagsViewModelTests.swift` — Tests migrated
- `ios/PKMReaderTests/Features/Tags/TagDocumentsViewModelTests.swift` — Tests migrated
- `ios/PKMReaderTests/Snapshots/Screens/SearchViewSnapshotTests.swift` — View removed
- `ios/PKMReaderTests/Snapshots/Screens/TagsViewSnapshotTests.swift` — View removed
- `ios/PKMReaderUITests/Screens/SearchScreenTests.swift` — Tests migrated
- `ios/PKMReaderUITests/Screens/TagsScreenTests.swift` — Tests migrated
- `ios/PKMReaderUITests/PageObjects/SearchPage.swift` — Merged into DocumentListPage
- `ios/PKMReaderUITests/PageObjects/TagsPage.swift` — Merged into DocumentListPage

### Files to Keep (no changes)

- `ios/PKMReader/Features/Search/SearchMonitor*.swift` — All SearchMonitor views and view models

## Acceptance Criteria

- [x] Documents tab integrates search bar via `.searchable` with keyword/semantic mode toggle
- [x] FilterSheet includes both Classification and Tags sections
- [x] Selecting a tag filters the document list inline
- [x] Tag + classification filters work together (fetch by tag, client-side filter by classification)
- [x] Search monitors accessible via toolbar binoculars button
- [x] Tab bar shows 4 tabs: Documents, Insights, Settings, Graph
- [x] Browse state preserved while searching
- [x] Search debounced at 300ms with "Enter at least 2 characters" hint
- [x] All existing unit tests migrated and passing
- [x] All existing UI tests migrated and passing
- [x] Lint checks pass
- [x] Old Search and Tags files deleted

## Implementation Steps

- [x] Step 1: Expand `DocumentListViewModel` — Add `SearchState`, `searchText` debounce, `searchMode`, `selectedTag`, `tags`, tag-filtered fetching
- [x] Step 2: Expand `FilterSheet` — Add Tags section with searchable tag list, single-select tag filter
- [x] Step 3: Rewrite `DocumentListView` — Add `.searchable`, conditional browse/search content, search mode picker, search monitors toolbar button
- [x] Step 4: Update `MainTabView` — Remove Search and Tags tabs, renumber to 4 tabs
- [x] Step 5: Migrate unit tests — Move search + tag tests into `DocumentListViewModelTests`, delete old test files
- [x] Step 6: Update UI tests — Merge search/tag UI tests into Documents page object and screen tests, update SearchMonitor navigation
- [x] Step 7: Delete obsolete files — Remove old views, VMs, tests, snapshots
- [x] Step 8: Regenerate Xcode project — `mise run generate`
- [x] Step 9: Run all checks — `mise run lint:fix && mise run test`

## Summary of Changes

### PR #107: feat: unify Documents, Search, and Tags into single tab (Task 0033)

- Expanded `DocumentListViewModel` with search state (debounced text, keyword/semantic mode), tag filtering, and lazy tag loading
- Expanded `FilterSheet` with Tags section alongside existing Classification filters
- Rewrote `DocumentListView` with `.searchable`, conditional browse/search rendering, search mode picker, and search monitors toolbar button
- Reduced `MainTabView` from 6 tabs to 4 (Documents, Insights, Settings, Graph)
- Migrated all search and tag unit tests into `DocumentListViewModelTests`
- Migrated search and tag UI tests into `DocumentListScreenTests` with updated page objects
- Deleted 15 obsolete files: SearchView, SearchViewModel, TagsView, TagsViewModel, TagDocumentsView, TagDocumentsViewModel, and their associated tests, snapshots, and page objects
- Updated snapshot reference images for new unified document list layout
- 29 files changed, 749 insertions, 1406 deletions
