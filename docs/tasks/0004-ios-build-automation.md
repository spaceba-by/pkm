# Task 0004: iOS Build & Test Automation

**Status**: Complete

## Specifications

iOS Phase 0: Set up the build and test automation foundation for the iOS app. Includes XcodeGen project generation, Fastlane build automation, SwiftLint code quality, GitHub Actions CI pipeline, and mock infrastructure for testing.

## Relevant Files

- `ios/project.yml` - XcodeGen project definition
- `ios/fastlane/Fastfile` - Fastlane build and test lanes
- `ios/.swiftlint.yml` - SwiftLint configuration
- `.github/workflows/ios-build.yml` - iOS build pipeline
- `.github/workflows/ios-test.yml` - iOS test pipeline
- `ios/PKMReader/` - SwiftUI app source (placeholder screens)
- `ios/PKMReaderTests/` - Unit test target
- `ios/PKMReaderUITests/` - UI test target
- `ios/.mise.toml` - Tool version management (Ruby, SwiftLint)
- `ios/CLAUDE.md` - iOS development instructions

## Acceptance Criteria

- [x] XcodeGen generates Xcode project from `project.yml`
- [x] Fastlane lanes for build, test, and lint
- [x] SwiftLint enforces code style rules
- [x] GitHub Actions runs iOS build on push
- [x] GitHub Actions runs iOS tests on PR
- [x] Mock service layer for testing without backend
- [x] Placeholder SwiftUI screens compile and render
- [x] Unit and UI test targets set up and passing
- [x] Swift 6 concurrency warnings resolved
- [x] Code coverage reporting configured (≥50% threshold)

## Implementation Steps

- [x] Step 1: Create XcodeGen project definition (`project.yml`)
- [x] Step 2: Set up Fastlane with build, test, and lint lanes
- [x] Step 3: Configure SwiftLint rules
- [x] Step 4: Create GitHub Actions workflows for iOS build and test
- [x] Step 5: Scaffold placeholder SwiftUI app with tab navigation
- [x] Step 6: Create mock service infrastructure for testing
- [x] Step 7: Set up unit test and UI test targets
- [x] Step 8: Resolve Swift 6 strict concurrency warnings
- [x] Step 9: Configure code coverage reporting with xcbeautify
- [x] Step 10: Set up mise for project-local tool management

## Summary of Changes

- Created XcodeGen-based project structure with `project.yml`
- Set up Fastlane for build automation (build, test, lint, coverage lanes)
- Configured SwiftLint for code quality enforcement
- Added `ios-build.yml` and `ios-test.yml` GitHub Actions workflows
- Scaffolded SwiftUI app with placeholder document list, detail, and settings screens
- Created mock infrastructure for API and auth services
- Set up unit test and UI test targets with XCTest
- Resolved Swift 6 strict concurrency warnings across all test targets
- Configured code coverage reporting with 50% minimum threshold
- Added mise for managing Ruby and SwiftLint versions
- Key commit: `f6aac15` (#17)
