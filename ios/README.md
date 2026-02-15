# PKMReader iOS App

iOS mobile app for the PKM (Personal Knowledge Management) system. Reads markdown documents from the S3 vault via the PKM API.

## Current Status

- **Phase 0** ✅ - Build & Test Automation Foundation
- **Phase 1** ✅ - Backend API Infrastructure (Cognito + API Gateway + Lambda)
- **Phase 2** ✅ - iOS App Core (Auth, APIClient, Views)
- **Phase 3** ✅ - Enhanced Features (Search, Tags, Insights, Settings)
- **Phase 4** 🚧 - Polish & Release ← Current

## Requirements

- macOS 14.0+
- Xcode 26.0+
- iOS 26.0+ deployment target
- Homebrew (for dependencies)

## Quick Start

```bash
# First-time setup (installs all dependencies including mise, Ruby, Fastlane)
./Scripts/bootstrap.sh

# Open in Xcode
open PKMReader.xcodeproj
```

## Development Commands

All commands use [mise](https://mise.jdx.dev/) tasks for convenience. Run `mise tasks` to see all available tasks.

### Testing

```bash
mise run test          # Run all tests (unit + UI)
mise run test:unit     # Run unit tests only
mise run test:ui       # Run UI tests only
mise run coverage      # Run tests with coverage report
```

### Code Quality

```bash
mise run lint          # Run SwiftLint
mise run lint:fix      # Auto-fix SwiftLint issues
mise run format        # Format code with SwiftFormat
mise run format:check  # Check formatting (CI mode)
```

### Building

```bash
mise run build         # Build for development (simulator)
```

### Project Management

```bash
mise run generate      # Regenerate Xcode project from project.yml
mise run setup         # Re-run first-time setup
```

## Project Structure

```
ios/
├── PKMReader/                    # Main app target
│   ├── App/                      # App entry point
│   ├── Core/                     # Core services
│   │   ├── Auth/                 # Authentication
│   │   ├── Cache/                # Caching
│   │   ├── Configuration/        # Environment config
│   │   ├── Networking/           # API client
│   │   └── Testing/              # Mock services for UI tests
│   ├── Features/                 # Feature modules
│   │   ├── Auth/
│   │   ├── DocumentDetail/
│   │   ├── DocumentList/
│   │   ├── Insights/
│   │   ├── Search/
│   │   ├── Settings/
│   │   └── Tags/
│   ├── Models/                   # Data models
│   ├── Resources/                # Assets, Info.plist
│   └── Shared/                   # Shared components
│
├── PKMReaderTests/               # Unit tests
│   ├── Core/
│   ├── Features/
│   ├── Fixtures/                 # Test data
│   ├── Helpers/                  # Test utilities
│   ├── Mocks/                    # Mock implementations
│   ├── Performance/              # XCT performance benchmarks
│   └── Snapshots/                # Snapshot tests (swift-snapshot-testing)
│
├── PKMReaderUITests/             # UI tests
│   ├── Helpers/
│   ├── PageObjects/              # Page object pattern
│   └── Screens/
│
├── fastlane/                     # Fastlane configuration
├── Scripts/                      # Development scripts
├── project.yml                   # XcodeGen project definition
├── .mise.toml                    # mise configuration (Ruby, tasks)
├── .swiftlint.yml                # SwiftLint rules
└── .swiftformat                  # SwiftFormat config
```

## Architecture

The app follows MVVM (Model-View-ViewModel) architecture:

- **Models**: Codable data structures matching API responses
- **Views**: SwiftUI views for UI
- **ViewModels**: Observable objects managing view state
- **Services**: Protocol-based services for networking, auth, caching

### Key Protocols

All services have protocol interfaces for testability:

- `APIClientProtocol` - Network requests
- `AuthServiceProtocol` - Authentication
- `CacheServiceProtocol` - Local caching
- `KeychainServiceProtocol` - Secure storage

### Testing Strategy

- **Unit Tests**: ViewModels, Services, Models (target 20%+ coverage)
- **UI Tests**: Critical user flows with Page Object pattern
- **Mocks**: All protocol implementations have mock versions in `PKMReaderTests/Mocks/`

## CI/CD

### Pull Request Checks

On every PR to `main` (via `.github/workflows/ios-test.yml`):
1. SwiftLint check (strict mode)
2. Build for testing
3. Run unit tests
4. Run UI tests
5. Code coverage check (20% minimum)

### Main Branch

On merge to `main` (via `.github/workflows/ios-build.yml`):
1. Build release archive
2. Upload build artifacts

## Configuration

### Environment Variables

For local development, no environment variables are required. The project uses:
- **mise** for Ruby version management (configured in `.mise.toml`)
- **Bundler** for Ruby gem management (gems installed locally in `vendor/bundle`)
- **XcodeGen** for project generation (configured in `project.yml`)

For CI/CD (Phase 4+):
- `MATCH_PASSWORD` - Match certificate encryption password
- `MATCH_GIT_URL` - Match certificates repository
- `FASTLANE_USER` - Apple ID for signing
- `APPLE_TEAM_ID` - Apple Developer Team ID
- `ASC_KEY_ID` - App Store Connect API Key ID
- `ASC_ISSUER_ID` - App Store Connect API Issuer ID
- `ASC_KEY` - App Store Connect API Key (base64)

## Troubleshooting

### Xcode project out of sync

```bash
mise run generate
```

### Tests failing to run

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/PKMReader-*

# Regenerate project
mise run generate
```

### SwiftLint warnings

```bash
mise run lint:fix   # Auto-fix what can be fixed
mise run format     # Format code
```

### Ruby/Bundler issues

```bash
# Re-run setup to reinstall Ruby and gems
mise run setup
```
