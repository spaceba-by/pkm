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
- [ ] Full accessibility support (VoiceOver, Dynamic Type)
- [ ] Snapshot tests for key screens
- [ ] Performance benchmarks meet targets
- [ ] App Store submission package prepared
- [ ] All UI flows covered by UI tests
- [ ] Code coverage ≥80%
- [ ] User documentation complete

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
- [ ] Step 2: Add accessibility labels and Dynamic Type support
  - Add VoiceOver hints and descriptions to interactive elements
  - Verify Dynamic Type scaling across all views
  - Add semantic grouping for complex UI elements
  - Test with VoiceOver and accessibility inspector
- [ ] Step 3: Create snapshot tests for key screens
- [ ] Step 4: Run performance profiling and optimize bottlenecks
- [ ] Step 5: Prepare App Store assets (screenshots, description, metadata)
- [ ] Step 6: Configure code signing for distribution
- [ ] Step 7: Submit to App Store review
- [ ] Step 8: Write user documentation
