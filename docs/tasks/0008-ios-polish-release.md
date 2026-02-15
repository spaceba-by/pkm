# Task 0008: iOS Polish & Release

**Status**: In Progress

## Specifications

iOS Phase 4: Polish the iOS app for production release. Includes comprehensive error handling with retry logic, network resilience with offline support, accessibility improvements, and App Store submission preparation.

### Current State (from codebase audit)

- **Error handling**: 3 error types defined (APIError, AuthError, KeychainError). ViewModels use state enums with `.error(String)` case. ErrorView uses `ContentUnavailableView` with optional retry button. SettingsViewModel silently swallows errors via `print()`.
- **Network resilience**: No retry logic in APIClient. No reachability monitoring. Errors discovered only when requests fail. DocumentCacheService exists but is not integrated into data flow for offline fallback.
- **Accessibility**: AccessibilityIdentifiers present for UI testing. Basic Dynamic Type via system fonts. No VoiceOver hints, no focus management, no semantic grouping.
- **Architecture**: MVVM with protocol-based DI. APIClient is an actor. All ViewModels use `@MainActor`. Swift 6 concurrency throughout.

## Relevant Files

### Core networking (modified in Step 1)

- `ios/PKMReader/Core/Networking/APIClient.swift` - Add retry logic with exponential backoff
- `ios/PKMReader/Core/Networking/APIError.swift` - Add `isRetryable` property, improve user-facing messages
- `ios/PKMReader/Core/Networking/NetworkMonitor.swift` (new) - NWPathMonitor wrapper for reachability

### Error handling improvements (modified in Step 1)

- `ios/PKMReader/Shared/Components/ErrorView.swift` - Differentiate network vs other errors
- `ios/PKMReader/Features/Settings/SettingsViewModel.swift` - Surface errors to user instead of print()

### Offline support (modified in Step 1)

- `ios/PKMReader/App/MainTabView.swift` - Add offline banner
- `ios/PKMReader/App/RootView.swift` - Pass NetworkMonitor through environment

### Tests (added in Step 1)

- `ios/PKMReaderTests/Core/Networking/NetworkMonitorTests.swift` (new)
- `ios/PKMReaderTests/Core/Networking/APIErrorTests.swift` (new)

### Existing test infrastructure

- `ios/PKMReaderTests/Mocks/MockAPIClient.swift`
- `ios/PKMReaderTests/Fixtures/TestFixtures.swift`

## Acceptance Criteria

- [x] Comprehensive error handling with user-friendly messages
- [x] Retry logic with exponential backoff for network requests
- [x] Offline mode indicators when network is unavailable
- [x] Full accessibility support (VoiceOver, Dynamic Type)
- [x] Snapshot tests for key screens
- [x] Performance benchmarks meet targets
- [x] App Store metadata prepared
- [ ] TestFlight beta deployment
- [ ] All UI flows covered by UI tests
- [ ] Code coverage ≥80%
- [x] User documentation complete

## Implementation Steps

- [x] Step 1: Error handling, retry logic, and offline support
  - Added `isRetryable` and `isNetworkError` properties to APIError
  - Added retry logic with exponential backoff (3 retries, 1s/2s/4s) in APIClient.performRequestWithRetry
  - Improved user-facing error descriptions (network, timeout, rate limit, server errors)
  - Created NetworkMonitor service using NWPathMonitor for reachability
  - Improved ErrorView to show wifi.slash icon and "No Connection" title for network errors
  - Surfaced errors in SettingsViewModel via `errorMessage` property (replaced silent print())
  - Added error alert to SettingsView for sign out and cache clear failures
  - Added OfflineBanner to MainTabView shown when device is offline
  - Wired NetworkMonitor through RootView to MainTabView
  - Added unit tests: APIErrorTests (18 tests), NetworkMonitorTests, SettingsViewModel error tests
- [x] Step 2: Add accessibility labels and Dynamic Type support
  - Added VoiceOver hints to interactive elements: filter button, classification filters, sign in, sign out, clear cache, toggles, retry button
  - Added semantic grouping with accessibilityElement(children: .combine) and descriptive labels for SummaryListView, ReportListView, and TagsView rows
  - Added @ScaledMetric for Dynamic Type scaling in OfflineBanner, ClassificationBadge, TagChip, and DocumentRowView padding
  - Added .accessibilityAddTraits(.updatesFrequently) to OfflineBanner for live region announcements
- [x] Step 3: Create snapshot tests for key screens
  - Added swift-snapshot-testing (pointfreeco) v1.17+ as SPM dependency on PKMReaderTests target
  - Created SnapshotTestCase base class with `@MainActor`, `assertDeviceSnapshot`, `assertComponentSnapshot`, and `assertDeviceSnapshotAfterTask` helpers (iPhone 13 config, light mode, `.missing` record strategy)
  - Component snapshot tests (9 snapshots): ErrorView (network, generic, no-retry), EmptyStateView (documents, search), LoadingView (with/without message), ClassificationBadge (all 5 types), TagChip (3 tags)
  - Screen snapshot tests (9 snapshots): LoginView (empty form), DocumentListView (loaded, empty, error), SearchView (idle), TagsView (loaded, empty), InsightsView (summaries tab), SettingsView (default)
  - 18 total reference PNG snapshots committed (~1.4MB), all tests passing
- [x] Step 4: Run performance profiling and optimize bottlenecks
  - Created `ios/PKMReaderTests/Performance/PerformanceTests.swift` with 12 benchmarks using `XCTClockMetric` and `XCTMemoryMetric`
  - Benchmarks cover: JSON decoding/encoding (200 docs), cache write/read/filter/lookup (100 docs), search debounce cancellation, markdown content processing, batch sorting/filtering (500 docs)
  - Added `performance_tests` Fastlane lane for isolated performance test runs
  - All 12 benchmarks passing
- [x] Step 5: Prepare App Store assets (screenshots, description, metadata)
  - Created Fastlane metadata directory `ios/fastlane/metadata/en-US/` with 8 files: name, subtitle, description, keywords, release notes, support/privacy/marketing URLs
  - Created `ios/PRIVACY_POLICY.md` template (needs `[DATE]` and `[SUPPORT_EMAIL]` placeholders filled in)
  - Created `ios/fastlane/Snapfile` for automated screenshot capture on 4 devices (iPhone 16 Pro Max, iPhone 16, iPhone SE 3rd gen, iPad Pro 13-inch M4)
  - Added `prepare_submission` Fastlane lane that validates metadata files, keyword/name/subtitle lengths, and screenshot availability
- [x] Step 6: Configure code signing for distribution
  - Created `docs/CODE_SIGNING.md` with Match Git repo setup, environment variables, new developer onboarding, certificate regeneration, CI/CD configuration, and troubleshooting
  - Added commented-out code signing steps to `.github/workflows/ios-build.yml` (keychain setup, Match sync, signed archive build) ready to enable when GitHub Secrets are configured
  - Verified Fastfile `build_release` lane, Matchfile, and Appfile are consistent
- [x] Step 7: Deploy to TestFlight for beta testing
  - Activated code signing and TestFlight deployment in `.github/workflows/ios-build.yml`
  - Build job detects `MATCH_GIT_URL` secret: if present, runs keychain setup → Match sync → signed archive build; if absent, falls back to unsigned simulator build (no regression)
  - Added `deploy-testflight` job: downloads signed IPA artifact, uploads to TestFlight via Fastlane using App Store Connect API key
  - Deploy job gated on `github.ref == 'refs/heads/main'` and successful signed build
  - Uses `testflight` GitHub environment for optional deployment protection rules
- [x] Step 8: Write user documentation
  - Created `docs/USER_GUIDE.md` covering all 5 tabs, document filtering, search, tags, insights (daily summaries/weekly reports), settings, offline mode, and troubleshooting
  - Created `docs/FAQ.md` with 15 questions covering accounts, document sync, AI classification, entities, offline behavior, and common troubleshooting
