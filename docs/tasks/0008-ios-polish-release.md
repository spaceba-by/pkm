# Task 0008: iOS Polish & Release

**Status**: Planned

## Specifications

iOS Phase 4: Polish the iOS app for production release. Includes comprehensive error handling with retry logic, accessibility support, snapshot tests, performance optimization, and App Store submission preparation.

## Relevant Files

- `ios/PKMReader/` - All app source files
- `ios/PKMReaderTests/` - Unit tests
- `ios/PKMReaderUITests/` - UI tests
- `ios/fastlane/Fastfile` - Build automation
- `.github/workflows/ios-build.yml` - Build pipeline
- `.github/workflows/ios-test.yml` - Test pipeline

## Acceptance Criteria

- [ ] Comprehensive error handling with user-friendly messages
- [ ] Retry logic with exponential backoff for network requests
- [ ] Offline mode indicators when network is unavailable
- [ ] Full accessibility support (VoiceOver, Dynamic Type)
- [ ] Snapshot tests for key screens
- [ ] Performance benchmarks meet targets
- [ ] App Store submission package prepared
- [ ] All UI flows covered by UI tests
- [ ] Code coverage ≥80%
- [ ] User documentation complete

## Implementation Steps

- [ ] Step 1: Audit and improve error handling across all views
- [ ] Step 2: Implement retry logic with exponential backoff in APIClient
- [ ] Step 3: Add offline mode detection and indicators
- [ ] Step 4: Add accessibility labels and Dynamic Type support
- [ ] Step 5: Create snapshot tests for key screens
- [ ] Step 6: Run performance profiling and optimize bottlenecks
- [ ] Step 7: Prepare App Store assets (screenshots, description, metadata)
- [ ] Step 8: Configure code signing for distribution
- [ ] Step 9: Submit to App Store review
- [ ] Step 10: Write user documentation
