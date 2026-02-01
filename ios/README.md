# PKMReader iOS App

iOS mobile app for the PKM (Personal Knowledge Management) system. Reads markdown documents from the S3 vault.

## Requirements

- macOS 14.0+
- Xcode 16.0+
- iOS 18.0+ deployment target
- Homebrew (for dependencies)

## Quick Start

```bash
# First-time setup (installs all dependencies)
./Scripts/bootstrap.sh

# Open in Xcode
open PKMReader.xcodeproj
```

## Development Commands

### Testing

```bash
# Run all tests via Fastlane
bundle exec fastlane test

# Run unit tests only
bundle exec fastlane unit_tests

# Run UI tests only
bundle exec fastlane ui_tests

# Or use xcodebuild directly
xcodebuild test \
  -project PKMReader.xcodeproj \
  -scheme PKMReader \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

### Code Quality

```bash
# Run SwiftLint
bundle exec fastlane lint

# Auto-fix SwiftLint issues
bundle exec fastlane lint_fix

# Format code with SwiftFormat
bundle exec fastlane format

# Check formatting (CI mode)
bundle exec fastlane format_check
```

### Building

```bash
# Build for development (simulator)
bundle exec fastlane build_dev

# Build release archive
bundle exec fastlane build_release
```

### Project Management

```bash
# Regenerate Xcode project from project.yml
./Scripts/generate-project.sh
# or
bundle exec fastlane generate_project

# Generate coverage report
bundle exec fastlane coverage_report
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
│   │   └── Networking/           # API client
│   ├── Features/                 # Feature modules
│   │   ├── Auth/
│   │   ├── DocumentDetail/
│   │   ├── DocumentList/
│   │   └── Search/
│   ├── Models/                   # Data models
│   ├── Resources/                # Assets, Info.plist
│   └── Shared/                   # Shared components
│
├── PKMReaderTests/               # Unit tests
│   ├── Core/
│   ├── Features/
│   ├── Fixtures/                 # Test data
│   ├── Helpers/                  # Test utilities
│   └── Mocks/                    # Mock implementations
│
├── PKMReaderUITests/             # UI tests
│   ├── Helpers/
│   ├── PageObjects/              # Page object pattern
│   └── Screens/
│
├── fastlane/                     # Fastlane configuration
├── Scripts/                      # Development scripts
├── project.yml                   # XcodeGen project definition
├── .swiftlint.yml               # SwiftLint rules
└── .swiftformat                 # SwiftFormat config
```

## Architecture

The app follows MVVM-C (Model-View-ViewModel-Coordinator) architecture:

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

- **Unit Tests**: ViewModels, Services, Models (60%+ of tests)
- **UI Tests**: Critical user flows with Page Object pattern
- **Mocks**: All protocol implementations have mock versions

## CI/CD

### Pull Request Checks

On every PR to `main`:
1. SwiftLint check (strict mode)
2. Build for testing
3. Run unit tests
4. Run UI tests
5. Code coverage check (60% minimum)

### Main Branch

On merge to `main`:
1. Build release archive
2. Upload build artifacts

## Configuration

### Environment Variables

For local development, no environment variables are required.

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
# Regenerate project from project.yml
xcodegen generate
```

### Tests failing to run

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/PKMReader-*

# Regenerate project
xcodegen generate
```

### SwiftLint warnings

```bash
# Auto-fix what can be fixed
bundle exec fastlane lint_fix

# Format code
bundle exec fastlane format
```
