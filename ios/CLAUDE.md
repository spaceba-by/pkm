# CLAUDE.md - iOS App Development Guide

This file provides guidance for Claude Code sessions working on the PKMReader iOS app.

## Project Overview

PKMReader is an iOS app for browsing, creating, and editing markdown documents from the PKM (Personal Knowledge Management) system. It connects to a serverless AWS backend API with Cognito authentication.

**Current Status**: Core app complete (Tasks 0001-0018). Ongoing feature development tracked in `docs/tasks/` and `docs/ROADMAP.md`.

## Common Commands

All commands should be run from the `ios/` directory using mise tasks:

```bash
mise run test          # Run all tests (unit + UI)
mise run test:unit     # Run unit tests only (faster)
mise run test:ui       # Run UI tests only
mise run lint          # Check code with SwiftLint
mise run lint:fix      # Auto-fix SwiftLint issues
mise run format        # Format code with SwiftFormat
mise run generate      # Regenerate Xcode project from project.yml
```

## Key Files

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen project definition - edit this, not the .xcodeproj |
| `.mise.toml` | Ruby version + mise tasks |
| `.swiftlint.yml` | Linting rules |
| `.swiftformat` | Formatting rules |
| `fastlane/Fastfile` | CI/CD automation lanes |

## Architecture Patterns

### MVVM with Protocol-Based Services

```
View (SwiftUI) → ViewModel (@MainActor, @Observable) → Service Protocol → Implementation
                                                                      ↘ Mock (for tests)
```

### Adding a New Feature

1. Create model in `PKMReader/Models/`
2. Create service protocol in `PKMReader/Core/<Service>/`
3. Create ViewModel in `PKMReader/Features/<Feature>/`
4. Create View in `PKMReader/Features/<Feature>/`
5. Create mock in `PKMReaderTests/Mocks/`
6. Create unit tests in `PKMReaderTests/Features/<Feature>/`
7. Create UI tests if needed in `PKMReaderUITests/`

### Testing Patterns

**Unit Tests** use mock services:
```swift
@MainActor
final class SomeViewModelTests: XCTestCase {
    private var sut: SomeViewModel!
    private var mockAPIClient: MockAPIClient!

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = SomeViewModel(apiClient: mockAPIClient)
    }
}
```

**UI Tests** use Page Objects:
```swift
final class SomeScreenTests: XCTestCase {
    private var app: XCUIApplication!
    private var somePage: SomePage!

    override func setUpWithError() throws {
        app = XCUIApplication()
        app.launchForTesting()
        somePage = SomePage(app: app)
    }
}
```

## Swift 6 Considerations

This project uses Swift 6 with strict concurrency. Key requirements:

- Mark async closures as `@Sendable` when passing to `Task {}`
- Use `@MainActor` for ViewModels and UI-related code
- Protocols for services should be `Sendable`
- Mock implementations need `@unchecked Sendable` if they have mutable state

## Project Generation

The Xcode project is generated from `project.yml` using XcodeGen. After editing `project.yml`:

```bash
mise run generate
```

**Never edit the .xcodeproj directly** - changes will be lost on regeneration.

To add new source files:
1. Create the file in the appropriate directory
2. Run `mise run generate` - XcodeGen auto-discovers files

## Local Builds & Testing

### Simulator Selection

The available simulators depend on the installed Xcode and iOS SDK versions. Do **not** hardcode simulator names or OS versions — always check what's available first:

```bash
xcodebuild -scheme PKMReader -showdestinations 2>/dev/null | grep "iOS Simulator"
```

### Building

```bash
# Build for testing (compiles app + test targets)
xcodebuild build-for-testing -scheme PKMReader \
  -destination 'platform=iOS Simulator,name=<SIMULATOR>,OS=<VERSION>' -quiet

# Build release
xcodebuild build -scheme PKMReader -configuration Release \
  -destination 'platform=iOS Simulator,name=<SIMULATOR>,OS=<VERSION>' -quiet
```

### Running Tests

```bash
# Run unit tests only (fastest)
xcodebuild test-without-building -scheme PKMReader \
  -destination 'platform=iOS Simulator,name=<SIMULATOR>,OS=<VERSION>' \
  -only-testing:PKMReaderTests -quiet

# Run all tests (unit + UI)
xcodebuild test-without-building -scheme PKMReader \
  -destination 'platform=iOS Simulator,name=<SIMULATOR>,OS=<VERSION>' -quiet
```

### Adding New Source Files

After creating new `.swift` files, you **must** regenerate the Xcode project so XcodeGen picks them up:

```bash
mise run generate
```

Without this step, builds will fail with "cannot find type in scope" errors for types defined in the new files.

## CI/CD

- **PR checks**: `.github/workflows/ios-test.yml` - lint, build, test, coverage
- **Main branch**: `.github/workflows/ios-build.yml` - signed build + TestFlight deployment (falls back to unsigned simulator build when signing secrets are not configured)

Coverage threshold is 78% (enforced in CI).

## Implementation Plan Reference

See `docs/tasks/` for task specifications and `docs/ROADMAP.md` for current status and completed tasks.

## Deployment Target

- **iOS**: 26.0+
- **Xcode**: 26.0+
- Defined in `project.yml` under `options.deploymentTarget.iOS`

## DO NOT

- Edit `.xcodeproj` files directly (use `project.yml`)
- Commit `vendor/bundle/` or `DerivedData/`
- Skip writing tests for new features
- Use force unwrapping (`!`) without good reason
- Ignore SwiftLint warnings
