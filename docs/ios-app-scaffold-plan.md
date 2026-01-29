# iOS App Scaffold Plan for PKM

## Overview

This document outlines the plan to create an iOS mobile app that interfaces with the PKM (Personal Knowledge Management) system. The initial version focuses on reading markdown documents from the S3 bucket (`notes.spaceba.by`).

**Key Principle**: Build and test automation is established FIRST (Phase 0), before any feature development begins. This ensures every feature can be tested in CI from day one.

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Architecture Plan](#architecture-plan)
3. [Phase 0: Build & Test Automation Foundation](#phase-0-build--test-automation-foundation) ← **Start Here**
4. [Phase 1: Backend API Infrastructure](#phase-1-backend-api-infrastructure)
5. [Phase 2: iOS App Scaffold](#phase-2-ios-app-scaffold)
6. [Phase 3: Implementation Roadmap](#phase-3-implementation-roadmap)
7. [Technical Decisions](#technical-decisions)

---

## Current State Analysis

### Existing Infrastructure
- **S3 Bucket**: `notes.spaceba.by` - contains markdown files and `_agent/` AI-generated content
- **DynamoDB Table**: `pkm-metadata` - stores document metadata, classifications, entities
- **Authentication**: IAM-based only (no user-facing auth)
- **API**: None - system is event-driven with no public API

### What's Missing for Mobile
1. Public API layer for mobile clients
2. User authentication system
3. iOS application codebase

---

## Architecture Plan

```
┌─────────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                           │
├─────────────────────────────────────────────────────────────────────┤
│  Views          │  ViewModels        │  Services                    │
│  - DocumentList │  - DocumentListVM  │  - APIClient                 │
│  - DocumentView │  - DocumentVM      │  - AuthService               │
│  - SearchView   │  - SearchVM        │  - CacheService              │
│  - SettingsView │                    │  - MarkdownRenderer          │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    API Gateway (REST)                               │
│  /documents       GET    - List documents with metadata             │
│  /documents/{key} GET    - Get single document content              │
│  /search          GET    - Search documents by query                │
│  /tags            GET    - List all tags                            │
│  /tags/{tag}      GET    - Get documents by tag                     │
│  /summaries       GET    - List daily summaries                     │
│  /reports         GET    - List weekly reports                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Amazon Cognito                                   │
│  - User Pool (email/password auth)                                  │
│  - Identity Pool (temporary AWS credentials)                        │
│  - JWT token validation                                             │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Lambda Functions (API)                           │
│  - pkm-api-list-documents                                           │
│  - pkm-api-get-document                                             │
│  - pkm-api-search                                                   │
│  - pkm-api-list-tags                                                │
└────────────────────────────┬────────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│   S3: notes.spaceba.by  │   │  DynamoDB: pkm-metadata │
│   (markdown content)    │   │  (metadata, search)     │
└─────────────────────────┘   └─────────────────────────┘
```

---

## Phase 0: Build & Test Automation Foundation

**This phase must be completed BEFORE any feature development begins.**

The goal is to establish a solid CI/CD foundation so that every feature added can be immediately tested in the pipeline. This follows the "test infrastructure first" principle.

### 0.1 Project Structure with Testing

```
ios/
├── PKMReader/
│   ├── App/
│   │   ├── PKMReaderApp.swift
│   │   └── AppDelegate.swift
│   │
│   ├── Core/
│   │   ├── Configuration/
│   │   │   ├── Environment.swift
│   │   │   └── Secrets.swift              # gitignored
│   │   │
│   │   ├── Networking/
│   │   │   ├── APIClient.swift
│   │   │   ├── APIClientProtocol.swift    # Protocol for mocking
│   │   │   ├── APIEndpoints.swift
│   │   │   └── APIError.swift
│   │   │
│   │   ├── Auth/
│   │   │   ├── AuthService.swift
│   │   │   ├── AuthServiceProtocol.swift  # Protocol for mocking
│   │   │   ├── KeychainService.swift
│   │   │   └── KeychainServiceProtocol.swift
│   │   │
│   │   └── Cache/
│   │       ├── CacheService.swift
│   │       └── CacheServiceProtocol.swift
│   │
│   ├── Models/
│   │   ├── Document.swift
│   │   ├── DocumentMetadata.swift
│   │   └── ...
│   │
│   ├── Features/
│   │   └── ... (feature modules)
│   │
│   ├── Shared/
│   │   ├── Components/
│   │   └── Extensions/
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
│
├── PKMReaderTests/                         # Unit tests
│   ├── Core/
│   │   ├── Networking/
│   │   │   └── APIClientTests.swift
│   │   ├── Auth/
│   │   │   └── AuthServiceTests.swift
│   │   └── Cache/
│   │       └── CacheServiceTests.swift
│   │
│   ├── Models/
│   │   └── DocumentTests.swift
│   │
│   ├── Features/
│   │   ├── DocumentList/
│   │   │   └── DocumentListViewModelTests.swift
│   │   └── ...
│   │
│   ├── Mocks/                              # Shared test mocks
│   │   ├── MockAPIClient.swift
│   │   ├── MockAuthService.swift
│   │   ├── MockKeychainService.swift
│   │   └── MockURLProtocol.swift
│   │
│   ├── Fixtures/                           # Test data
│   │   ├── document.json
│   │   ├── document_list.json
│   │   └── TestFixtures.swift
│   │
│   └── Helpers/
│       ├── XCTestCase+Async.swift
│       └── XCTestCase+JSON.swift
│
├── PKMReaderUITests/                       # UI tests
│   ├── Screens/
│   │   ├── DocumentListScreenTests.swift
│   │   ├── DocumentDetailScreenTests.swift
│   │   └── LoginScreenTests.swift
│   │
│   ├── PageObjects/                        # Page Object pattern
│   │   ├── DocumentListPage.swift
│   │   ├── DocumentDetailPage.swift
│   │   └── LoginPage.swift
│   │
│   ├── Helpers/
│   │   └── XCUIApplication+Launch.swift
│   │
│   └── TestPlan.xctestplan
│
├── PKMReaderSnapshotTests/                 # Snapshot tests (optional)
│   ├── __Snapshots__/
│   └── ComponentSnapshotTests.swift
│
├── fastlane/
│   ├── Fastfile
│   ├── Appfile
│   ├── Matchfile
│   └── Pluginfile
│
├── Scripts/
│   ├── bootstrap.sh                        # Setup script for new devs
│   ├── run-tests.sh                        # Local test runner
│   └── generate-mocks.sh                   # Mock generation (if using Sourcery)
│
├── .swiftlint.yml                          # SwiftLint config
├── .swiftformat                            # SwiftFormat config
├── Package.swift                           # Swift Package dependencies
├── project.yml                             # XcodeGen project definition
├── PKMReader.xcodeproj/
└── README.md
```

### 0.2 GitHub Actions Workflows

#### iOS Test Workflow (`.github/workflows/ios-test.yml`)

```yaml
name: iOS Tests

on:
  pull_request:
    branches: [main]
    paths:
      - 'ios/**'
      - '.github/workflows/ios-*.yml'

concurrency:
  group: ios-test-${{ github.head_ref || github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    name: Lint
    runs-on: macos-14

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install SwiftLint
        run: brew install swiftlint

      - name: Run SwiftLint
        working-directory: ios
        run: swiftlint lint --strict --reporter github-actions-logging

  build-and-test:
    name: Build & Test
    runs-on: macos-14
    needs: lint

    env:
      DEVELOPER_DIR: /Applications/Xcode_15.2.app/Contents/Developer
      SCHEME: PKMReader
      DESTINATION: 'platform=iOS Simulator,name=iPhone 15,OS=17.2'

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Cache Swift packages
        uses: actions/cache@v4
        with:
          path: |
            ios/.build
            ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-spm-${{ hashFiles('ios/Package.resolved') }}
          restore-keys: |
            ${{ runner.os }}-spm-

      - name: Install dependencies
        working-directory: ios
        run: |
          xcodebuild -resolvePackageDependencies \
            -project PKMReader.xcodeproj \
            -scheme $SCHEME

      - name: Build for testing
        working-directory: ios
        run: |
          set -o pipefail
          xcodebuild build-for-testing \
            -project PKMReader.xcodeproj \
            -scheme $SCHEME \
            -destination "$DESTINATION" \
            -configuration Debug \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            | xcpretty --color

      - name: Run unit tests
        working-directory: ios
        run: |
          set -o pipefail
          xcodebuild test-without-building \
            -project PKMReader.xcodeproj \
            -scheme $SCHEME \
            -destination "$DESTINATION" \
            -only-testing:PKMReaderTests \
            -resultBundlePath TestResults/unit-tests.xcresult \
            | xcpretty --color --report junit --output TestResults/unit-tests.xml

      - name: Run UI tests
        working-directory: ios
        run: |
          set -o pipefail
          xcodebuild test-without-building \
            -project PKMReader.xcodeproj \
            -scheme $SCHEME \
            -destination "$DESTINATION" \
            -only-testing:PKMReaderUITests \
            -resultBundlePath TestResults/ui-tests.xcresult \
            | xcpretty --color --report junit --output TestResults/ui-tests.xml

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: ios/TestResults/
          retention-days: 14

      - name: Publish test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Test Results
          path: ios/TestResults/*.xml
          reporter: java-junit

  code-coverage:
    name: Code Coverage
    runs-on: macos-14
    needs: build-and-test

    env:
      DEVELOPER_DIR: /Applications/Xcode_15.2.app/Contents/Developer
      SCHEME: PKMReader
      DESTINATION: 'platform=iOS Simulator,name=iPhone 15,OS=17.2'

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Cache Swift packages
        uses: actions/cache@v4
        with:
          path: |
            ios/.build
            ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-spm-${{ hashFiles('ios/Package.resolved') }}

      - name: Run tests with coverage
        working-directory: ios
        run: |
          set -o pipefail
          xcodebuild test \
            -project PKMReader.xcodeproj \
            -scheme $SCHEME \
            -destination "$DESTINATION" \
            -enableCodeCoverage YES \
            -resultBundlePath TestResults/coverage.xcresult \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            | xcpretty --color

      - name: Generate coverage report
        working-directory: ios
        run: |
          xcrun xccov view --report --json TestResults/coverage.xcresult > coverage.json
          # Extract coverage percentage
          COVERAGE=$(cat coverage.json | jq '.lineCoverage * 100 | floor')
          echo "## Code Coverage: ${COVERAGE}%" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

      - name: Check coverage threshold
        working-directory: ios
        run: |
          COVERAGE=$(cat coverage.json | jq '.lineCoverage * 100')
          THRESHOLD=60
          if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
            echo "::error::Code coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
            exit 1
          fi
          echo "Coverage ${COVERAGE}% meets threshold ${THRESHOLD}%"
```

#### iOS Build Workflow (`.github/workflows/ios-build.yml`)

```yaml
name: iOS Build

on:
  push:
    branches: [main]
    paths:
      - 'ios/**'
      - '.github/workflows/ios-*.yml'

concurrency:
  group: ios-build-${{ github.ref }}
  cancel-in-progress: false

jobs:
  build:
    name: Build Release
    runs-on: macos-14

    env:
      DEVELOPER_DIR: /Applications/Xcode_15.2.app/Contents/Developer
      SCHEME: PKMReader

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Cache Swift packages
        uses: actions/cache@v4
        with:
          path: |
            ios/.build
            ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-spm-${{ hashFiles('ios/Package.resolved') }}

      - name: Setup Ruby (for Fastlane)
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: ios

      - name: Install Fastlane
        working-directory: ios
        run: |
          gem install bundler
          bundle install

      - name: Build archive
        working-directory: ios
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          FASTLANE_USER: ${{ secrets.FASTLANE_USER }}
          FASTLANE_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
        run: bundle exec fastlane build_release

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: PKMReader-${{ github.sha }}
          path: ios/build/*.ipa
          retention-days: 30

    outputs:
      build_number: ${{ steps.build.outputs.build_number }}

  # Optional: Deploy to TestFlight
  deploy-testflight:
    name: Deploy to TestFlight
    needs: build
    runs-on: macos-14
    environment: testflight
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: PKMReader-${{ github.sha }}
          path: ios/build/

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: ios

      - name: Upload to TestFlight
        working-directory: ios
        env:
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY: ${{ secrets.ASC_KEY }}
        run: bundle exec fastlane upload_testflight
```

### 0.3 Fastlane Configuration

#### `ios/fastlane/Fastfile`

```ruby
default_platform(:ios)

platform :ios do
  # ================================
  # Setup & Configuration
  # ================================

  before_all do
    setup_ci if ENV['CI']
  end

  # ================================
  # Testing Lanes
  # ================================

  desc "Run all tests (unit + UI)"
  lane :test do
    run_tests(
      project: "PKMReader.xcodeproj",
      scheme: "PKMReader",
      devices: ["iPhone 15"],
      code_coverage: true,
      result_bundle: true,
      output_directory: "TestResults",
      xcargs: "CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO"
    )
  end

  desc "Run unit tests only"
  lane :unit_tests do
    run_tests(
      project: "PKMReader.xcodeproj",
      scheme: "PKMReader",
      devices: ["iPhone 15"],
      only_testing: ["PKMReaderTests"],
      code_coverage: true,
      result_bundle: true,
      output_directory: "TestResults/unit",
      xcargs: "CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO"
    )
  end

  desc "Run UI tests only"
  lane :ui_tests do
    run_tests(
      project: "PKMReader.xcodeproj",
      scheme: "PKMReader",
      devices: ["iPhone 15"],
      only_testing: ["PKMReaderUITests"],
      result_bundle: true,
      output_directory: "TestResults/ui",
      xcargs: "CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO"
    )
  end

  desc "Run snapshot tests"
  lane :snapshot_tests do
    run_tests(
      project: "PKMReader.xcodeproj",
      scheme: "PKMReader",
      devices: ["iPhone 15", "iPhone SE (3rd generation)", "iPad Pro (12.9-inch)"],
      only_testing: ["PKMReaderSnapshotTests"],
      result_bundle: true,
      output_directory: "TestResults/snapshots"
    )
  end

  # ================================
  # Code Quality Lanes
  # ================================

  desc "Run SwiftLint"
  lane :lint do
    swiftlint(
      mode: :lint,
      config_file: ".swiftlint.yml",
      strict: true,
      raise_if_swiftlint_error: true
    )
  end

  desc "Auto-fix SwiftLint issues"
  lane :lint_fix do
    swiftlint(
      mode: :fix,
      config_file: ".swiftlint.yml"
    )
  end

  desc "Run SwiftFormat"
  lane :format do
    sh("cd .. && swiftformat . --config .swiftformat")
  end

  desc "Check code formatting"
  lane :format_check do
    sh("cd .. && swiftformat . --config .swiftformat --lint")
  end

  # ================================
  # Build Lanes
  # ================================

  desc "Build for development"
  lane :build_dev do
    build_app(
      project: "PKMReader.xcodeproj",
      scheme: "PKMReader",
      configuration: "Debug",
      skip_codesigning: true,
      skip_archive: true,
      destination: "generic/platform=iOS Simulator"
    )
  end

  desc "Build release archive"
  lane :build_release do
    # Increment build number
    increment_build_number(
      build_number: ENV['BUILD_NUMBER'] || Time.now.strftime("%Y%m%d%H%M")
    )

    # Sync signing certificates
    sync_code_signing(
      type: "appstore",
      readonly: is_ci
    )

    # Build the app
    build_app(
      project: "PKMReader.xcodeproj",
      scheme: "PKMReader",
      configuration: "Release",
      export_method: "app-store",
      output_directory: "build",
      output_name: "PKMReader.ipa"
    )
  end

  # ================================
  # Deployment Lanes
  # ================================

  desc "Upload to TestFlight"
  lane :upload_testflight do
    api_key = app_store_connect_api_key(
      key_id: ENV['APP_STORE_CONNECT_API_KEY_ID'],
      issuer_id: ENV['APP_STORE_CONNECT_API_ISSUER_ID'],
      key_content: ENV['APP_STORE_CONNECT_API_KEY']
    )

    upload_to_testflight(
      api_key: api_key,
      ipa: "build/PKMReader.ipa",
      skip_waiting_for_build_processing: true,
      changelog: last_git_commit[:message]
    )
  end

  # ================================
  # Utility Lanes
  # ================================

  desc "Generate code coverage report"
  lane :coverage_report do
    xcov(
      project: "PKMReader.xcodeproj",
      scheme: "PKMReader",
      output_directory: "coverage",
      minimum_coverage_percentage: 60.0
    )
  end

  desc "Setup project for new developer"
  lane :setup do
    sh("cd .. && ./Scripts/bootstrap.sh")
  end
end
```

#### `ios/fastlane/Appfile`

```ruby
app_identifier("by.spaceba.pkm.reader")
apple_id(ENV['FASTLANE_USER'])
team_id(ENV['APPLE_TEAM_ID'])

for_platform :ios do
  for_lane :upload_testflight do
    app_identifier("by.spaceba.pkm.reader")
  end
end
```

#### `ios/fastlane/Matchfile`

```ruby
git_url(ENV['MATCH_GIT_URL'])
storage_mode("git")
type("appstore")
app_identifier(["by.spaceba.pkm.reader"])
username(ENV['FASTLANE_USER'])
```

### 0.4 Code Quality Configuration

#### `ios/.swiftlint.yml`

```yaml
# SwiftLint Configuration for PKMReader

disabled_rules:
  - trailing_comma
  - identifier_name

opt_in_rules:
  - array_init
  - attributes
  - closure_end_indentation
  - closure_spacing
  - collection_alignment
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - contains_over_first_not_nil
  - contains_over_range_nil_comparison
  - discouraged_object_literal
  - empty_collection_literal
  - empty_count
  - empty_string
  - enum_case_associated_values_count
  - explicit_init
  - extension_access_modifier
  - fallthrough
  - fatal_error_message
  - file_name
  - first_where
  - flatmap_over_map_reduce
  - force_unwrapping
  - identical_operands
  - implicit_return
  - implicitly_unwrapped_optional
  - joined_default_parameter
  - last_where
  - legacy_multiple
  - legacy_random
  - literal_expression_end_indentation
  - lower_acl_than_parent
  - modifier_order
  - multiline_arguments
  - multiline_function_chains
  - multiline_literal_brackets
  - multiline_parameters
  - operator_usage_whitespace
  - overridden_super_call
  - pattern_matching_keywords
  - prefer_self_type_over_type_of_self
  - prefer_zero_over_explicit_init
  - private_action
  - private_outlet
  - prohibited_super_call
  - reduce_into
  - redundant_nil_coalescing
  - redundant_type_annotation
  - single_test_class
  - sorted_first_last
  - static_operator
  - strong_iboutlet
  - toggle_bool
  - unavailable_function
  - unneeded_parentheses_in_closure_argument
  - unowned_variable_capture
  - untyped_error_in_catch
  - vertical_parameter_alignment_on_call
  - vertical_whitespace_closing_braces
  - vertical_whitespace_opening_braces
  - yoda_condition

included:
  - PKMReader
  - PKMReaderTests
  - PKMReaderUITests

excluded:
  - Pods
  - .build
  - DerivedData
  - PKMReader/Resources

# Customizations
line_length:
  warning: 120
  error: 200
  ignores_urls: true
  ignores_comments: true

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 500
  error: 1000

function_body_length:
  warning: 50
  error: 100

function_parameter_count:
  warning: 6
  error: 8

type_name:
  min_length: 2
  max_length: 50

nesting:
  type_level: 3
  function_level: 3

cyclomatic_complexity:
  warning: 15
  error: 25

reporter: "xcode"
```

#### `ios/.swiftformat`

```
# SwiftFormat Configuration

--swiftversion 5.9

# File options
--exclude Pods,.build,DerivedData

# Format options
--indent 4
--tabwidth 4
--maxwidth 120
--wraparguments before-first
--wrapparameters before-first
--wrapcollections before-first
--closingparen balanced
--funcattributes prev-line
--typeattributes prev-line
--varattributes prev-line

# Enabled rules
--enable blankLinesBetweenScopes
--enable blankLinesAtStartOfScope
--enable blankLinesAtEndOfScope
--enable consecutiveSpaces
--enable duplicateImports
--enable elseOnSameLine
--enable emptyBraces
--enable indent
--enable leadingDelimiters
--enable redundantBreak
--enable redundantExtensionACL
--enable redundantFileprivate
--enable redundantGet
--enable redundantInit
--enable redundantLet
--enable redundantNilInit
--enable redundantObjc
--enable redundantParens
--enable redundantPattern
--enable redundantRawValues
--enable redundantReturn
--enable redundantSelf
--enable redundantType
--enable redundantVoidReturnType
--enable semicolons
--enable sortedImports
--enable spaceAroundBraces
--enable spaceAroundBrackets
--enable spaceAroundComments
--enable spaceAroundGenerics
--enable spaceAroundOperators
--enable spaceAroundParens
--enable spaceInsideBraces
--enable spaceInsideBrackets
--enable spaceInsideComments
--enable spaceInsideGenerics
--enable spaceInsideParens
--enable strongOutlets
--enable strongifiedSelf
--enable trailingClosures
--enable trailingCommas
--enable trailingSpace
--enable typeSugar
--enable void
--enable wrapArguments
--enable wrapAttributes
--enable yodaConditions

# Disabled rules
--disable acronyms
--disable markTypes
--disable organizeDeclarations
```

### 0.5 Test Infrastructure

#### Mock Protocols Pattern

Each service should have a protocol to enable mocking:

```swift
// Core/Networking/APIClientProtocol.swift
protocol APIClientProtocol {
    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse

    func getDocument(key: String) async throws -> Document
    func search(query: String, limit: Int) async throws -> [Document]
    func listTags() async throws -> [Tag]
}

// Make the real client conform
extension APIClient: APIClientProtocol {}
```

#### Mock Implementation

```swift
// PKMReaderTests/Mocks/MockAPIClient.swift
import Foundation
@testable import PKMReader

final class MockAPIClient: APIClientProtocol {
    // Configurable responses
    var listDocumentsResult: Result<DocumentListResponse, Error> = .success(
        DocumentListResponse(documents: [], nextCursor: nil)
    )
    var getDocumentResult: Result<Document, Error>?
    var searchResult: Result<[Document], Error> = .success([])
    var listTagsResult: Result<[Tag], Error> = .success([])

    // Call tracking
    private(set) var listDocumentsCallCount = 0
    private(set) var lastListDocumentsClassification: DocumentClassification?
    private(set) var getDocumentCallCount = 0
    private(set) var lastGetDocumentKey: String?
    private(set) var searchCallCount = 0
    private(set) var lastSearchQuery: String?

    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse {
        listDocumentsCallCount += 1
        lastListDocumentsClassification = classification
        return try listDocumentsResult.get()
    }

    func getDocument(key: String) async throws -> Document {
        getDocumentCallCount += 1
        lastGetDocumentKey = key

        if let result = getDocumentResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func search(query: String, limit: Int) async throws -> [Document] {
        searchCallCount += 1
        lastSearchQuery = query
        return try searchResult.get()
    }

    func listTags() async throws -> [Tag] {
        return try listTagsResult.get()
    }

    // Reset for test isolation
    func reset() {
        listDocumentsCallCount = 0
        lastListDocumentsClassification = nil
        getDocumentCallCount = 0
        lastGetDocumentKey = nil
        searchCallCount = 0
        lastSearchQuery = nil
    }
}
```

#### Test Fixtures

```swift
// PKMReaderTests/Fixtures/TestFixtures.swift
import Foundation
@testable import PKMReader

enum TestFixtures {
    static func loadJSON<T: Decodable>(_ filename: String) -> T {
        let bundle = Bundle(for: BundleToken.self)
        let url = bundle.url(forResource: filename, withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(T.self, from: data)
    }

    static var sampleDocument: Document {
        Document(
            id: "test/sample.md",
            title: "Sample Document",
            content: "# Sample\n\nThis is a test document.",
            metadata: DocumentMetadata(
                classification: .reference,
                tags: ["test", "sample"],
                linksTo: [],
                entities: nil,
                created: Date(),
                modified: Date(),
                hasFrontmatter: true
            )
        )
    }

    static var sampleDocuments: [Document] {
        [
            sampleDocument,
            Document(
                id: "meetings/weekly.md",
                title: "Weekly Meeting",
                content: nil,
                metadata: DocumentMetadata(
                    classification: .meeting,
                    tags: ["meeting", "weekly"],
                    linksTo: [],
                    entities: DocumentEntities(
                        people: ["John Doe"],
                        organizations: nil,
                        concepts: nil,
                        locations: nil
                    ),
                    created: Date(),
                    modified: Date(),
                    hasFrontmatter: true
                )
            )
        ]
    }
}

private class BundleToken {}
```

#### Example Unit Test

```swift
// PKMReaderTests/Features/DocumentList/DocumentListViewModelTests.swift
import XCTest
@testable import PKMReader

@MainActor
final class DocumentListViewModelTests: XCTestCase {
    private var sut: DocumentListViewModel!
    private var mockAPIClient: MockAPIClient!

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = DocumentListViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Load Documents

    func test_loadDocuments_success_updatesStateToLoaded() async {
        // Given
        let documents = TestFixtures.sampleDocuments
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: documents, nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then
        if case .loaded(let loadedDocs) = sut.state {
            XCTAssertEqual(loadedDocs.count, documents.count)
            XCTAssertEqual(loadedDocs.first?.id, documents.first?.id)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_loadDocuments_emptyResult_updatesStateToEmpty() async {
        // Given
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [], nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadDocuments_failure_updatesStateToError() async {
        // Given
        mockAPIClient.listDocumentsResult = .failure(APIError.invalidResponse)

        // When
        await sut.loadDocuments()

        // Then
        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    // MARK: - Classification Filter

    func test_loadDocuments_withClassification_passesFilterToAPI() async {
        // Given
        sut.selectedClassification = .meeting
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [], nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertEqual(mockAPIClient.lastListDocumentsClassification, .meeting)
    }

    // MARK: - Pagination

    func test_loadDocuments_withNextCursor_setsHasMorePages() async {
        // Given
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(
                documents: TestFixtures.sampleDocuments,
                nextCursor: "next-page-token"
            )
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertTrue(sut.hasMorePages)
    }

    func test_loadNextPage_appendsDocuments() async {
        // Given
        let firstPage = [TestFixtures.sampleDocument]
        let secondPage = [TestFixtures.sampleDocuments[1]]

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: firstPage, nextCursor: "page2")
        )
        await sut.loadDocuments()

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: secondPage, nextCursor: nil)
        )

        // When
        await sut.loadNextPage()

        // Then
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 2)
        } else {
            XCTFail("Expected loaded state")
        }
    }
}
```

#### Example UI Test with Page Objects

```swift
// PKMReaderUITests/PageObjects/DocumentListPage.swift
import XCTest

final class DocumentListPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var navigationTitle: XCUIElement {
        app.navigationBars["Documents"].firstMatch
    }

    var documentList: XCUIElement {
        app.collectionViews.firstMatch
    }

    var filterButton: XCUIElement {
        app.buttons["Filter"].firstMatch
    }

    var searchField: XCUIElement {
        app.searchFields.firstMatch
    }

    var loadingIndicator: XCUIElement {
        app.activityIndicators.firstMatch
    }

    var emptyStateView: XCUIElement {
        app.staticTexts["No Documents"].firstMatch
    }

    func documentRow(at index: Int) -> XCUIElement {
        documentList.cells.element(boundBy: index)
    }

    func documentRow(withTitle title: String) -> XCUIElement {
        documentList.cells.containing(.staticText, identifier: title).firstMatch
    }

    // MARK: - Actions

    func tapDocument(at index: Int) {
        documentRow(at: index).tap()
    }

    func tapDocument(withTitle title: String) {
        documentRow(withTitle: title).tap()
    }

    func tapFilterButton() {
        filterButton.tap()
    }

    func search(for query: String) {
        searchField.tap()
        searchField.typeText(query)
    }

    func pullToRefresh() {
        documentList.swipeDown()
    }

    // MARK: - Assertions

    func assertIsDisplayed() {
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5))
    }

    func assertDocumentCount(_ count: Int) {
        XCTAssertEqual(documentList.cells.count, count)
    }

    func assertShowsEmptyState() {
        XCTAssertTrue(emptyStateView.waitForExistence(timeout: 5))
    }

    func assertShowsLoading() {
        XCTAssertTrue(loadingIndicator.exists)
    }
}

// PKMReaderUITests/Screens/DocumentListScreenTests.swift
import XCTest

final class DocumentListScreenTests: XCTestCase {
    private var app: XCUIApplication!
    private var documentListPage: DocumentListPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-api"]
        app.launch()

        documentListPage = DocumentListPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        documentListPage = nil
    }

    func test_documentList_displaysDocuments() {
        documentListPage.assertIsDisplayed()
        documentListPage.assertDocumentCount(2) // Based on mock data
    }

    func test_tapDocument_navigatesToDetail() {
        documentListPage.tapDocument(at: 0)

        let detailPage = DocumentDetailPage(app: app)
        detailPage.assertIsDisplayed()
    }

    func test_search_filtersDocuments() {
        documentListPage.search(for: "meeting")

        // Wait for search results
        let predicate = NSPredicate(format: "cells.count == 1")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: documentListPage.documentList
        )
        wait(for: [expectation], timeout: 5)
    }

    func test_pullToRefresh_reloadsDocuments() {
        documentListPage.pullToRefresh()
        documentListPage.assertShowsLoading()
    }
}
```

### 0.6 Bootstrap Script

```bash
#!/bin/bash
# ios/Scripts/bootstrap.sh
# Setup script for new developers

set -e

echo "🚀 Setting up PKMReader development environment..."

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install it first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
brew bundle --file=- <<EOF
brew "swiftlint"
brew "swiftformat"
brew "xcbeautify"
EOF

# Install Ruby dependencies for Fastlane
echo "💎 Installing Fastlane..."
if ! command -v bundle &> /dev/null; then
    gem install bundler
fi
bundle install

# Resolve Swift packages
echo "📚 Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project PKMReader.xcodeproj -scheme PKMReader

# Create Secrets.swift if it doesn't exist
if [ ! -f "PKMReader/Core/Configuration/Secrets.swift" ]; then
    echo "🔐 Creating Secrets.swift template..."
    cat > PKMReader/Core/Configuration/Secrets.swift << 'SWIFT'
// This file is gitignored. Copy from Secrets.swift.template and fill in values.
import Foundation

enum Secrets {
    static let cognitoUserPoolId = "YOUR_USER_POOL_ID"
    static let cognitoClientId = "YOUR_CLIENT_ID"
    static let apiBaseURL = "https://api.example.com"
}
SWIFT
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Copy PKMReader/Core/Configuration/Secrets.swift.template to Secrets.swift"
echo "  2. Fill in your API credentials"
echo "  3. Open PKMReader.xcodeproj in Xcode"
echo ""
echo "Useful commands:"
echo "  bundle exec fastlane test      # Run all tests"
echo "  bundle exec fastlane lint      # Run SwiftLint"
echo "  bundle exec fastlane format    # Format code"
```

### 0.7 Test Plan Configuration

Create an Xcode Test Plan for consistent test execution:

```xml
<!-- ios/PKMReaderTests/TestPlan.xctestplan -->
{
  "configurations" : [
    {
      "name" : "Default",
      "options" : {
        "language" : "en",
        "region" : "US",
        "testTimeoutsEnabled" : true,
        "defaultTestExecutionTimeAllowance" : 60,
        "maximumTestExecutionTimeAllowance" : 180
      }
    }
  ],
  "defaultOptions" : {
    "codeCoverage" : {
      "targets" : [
        {
          "containerPath" : "container:PKMReader.xcodeproj",
          "identifier" : "PKMReader",
          "name" : "PKMReader"
        }
      ]
    },
    "targetForVariableExpansion" : {
      "containerPath" : "container:PKMReader.xcodeproj",
      "identifier" : "PKMReader",
      "name" : "PKMReader"
    }
  },
  "testTargets" : [
    {
      "parallelizable" : true,
      "target" : {
        "containerPath" : "container:PKMReader.xcodeproj",
        "identifier" : "PKMReaderTests",
        "name" : "PKMReaderTests"
      }
    },
    {
      "parallelizable" : false,
      "target" : {
        "containerPath" : "container:PKMReader.xcodeproj",
        "identifier" : "PKMReaderUITests",
        "name" : "PKMReaderUITests"
      }
    }
  ],
  "version" : 1
}
```

### 0.8 Phase 0 Deliverables Checklist

| Item | Description | CI Verified |
|------|-------------|-------------|
| Xcode project structure | Project with all targets configured | ✓ Build passes |
| Unit test target | `PKMReaderTests` with sample tests | ✓ Tests run |
| UI test target | `PKMReaderUITests` with page objects | ✓ Tests run |
| SwiftLint | Configured and passing | ✓ Lint check |
| SwiftFormat | Configured | ✓ Format check |
| Fastlane | All lanes working | ✓ `fastlane test` |
| GitHub Actions | Test workflow on PR | ✓ PR checks pass |
| GitHub Actions | Build workflow on merge | ✓ Artifacts uploaded |
| Mock infrastructure | Protocols + mock implementations | ✓ Unit tests use mocks |
| Test fixtures | Sample data for tests | ✓ Tests use fixtures |
| Code coverage | 60% threshold enforced | ✓ Coverage check |
| Bootstrap script | New dev setup works | Manual verification |

### 0.9 CI/CD Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Pull Request                                     │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    ios-test.yml Workflow                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────┐     ┌─────────────────┐     ┌─────────────────┐          │
│   │  Lint    │────▶│  Build & Test   │────▶│  Code Coverage  │          │
│   │(SwiftLint)│     │ (Unit + UI)     │     │  (60% minimum)  │          │
│   └──────────┘     └─────────────────┘     └─────────────────┘          │
│                            │                        │                    │
│                            ▼                        ▼                    │
│                    ┌───────────────┐        ┌─────────────┐             │
│                    │ Test Results  │        │  Coverage   │             │
│                    │  (JUnit XML)  │        │   Report    │             │
│                    └───────────────┘        └─────────────┘             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 │ Merge to main
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    ios-build.yml Workflow                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────────┐     ┌─────────────────┐     ┌──────────────────┐    │
│   │    Build     │────▶│  Archive IPA    │────▶│   TestFlight     │    │
│   │   Release    │     │  (Fastlane)     │     │    (optional)    │    │
│   └──────────────┘     └─────────────────┘     └──────────────────┘    │
│         │                      │                                        │
│         ▼                      ▼                                        │
│   ┌──────────────┐     ┌─────────────────┐                             │
│   │ Code Signing │     │  Build Artifact │                             │
│   │   (Match)    │     │   (30 days)     │                             │
│   └──────────────┘     └─────────────────┘                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Backend API Infrastructure

### 1.1 Cognito User Authentication

**File**: `terraform/cognito.tf`

```hcl
# User Pool for authentication
resource "aws_cognito_user_pool" "pkm_users" {
  name = "pkm-users"

  # Password policy
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Email verification
  auto_verified_attributes = ["email"]

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Schema
  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable            = true
  }
}

# App client for iOS
resource "aws_cognito_user_pool_client" "ios_client" {
  name         = "pkm-ios-client"
  user_pool_id = aws_cognito_user_pool.pkm_users.id

  generate_secret = false  # Required for mobile apps

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Token validity
  access_token_validity  = 1   # hours
  id_token_validity      = 1   # hours
  refresh_token_validity = 30  # days
}

# Identity Pool for AWS credentials
resource "aws_cognito_identity_pool" "pkm_identity" {
  identity_pool_name = "pkm_identity_pool"

  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.ios_client.id
    provider_name           = aws_cognito_user_pool.pkm_users.endpoint
    server_side_token_check = false
  }
}
```

### 1.2 API Gateway + Lambda Functions

**File**: `terraform/api_gateway.tf`

```hcl
resource "aws_apigatewayv2_api" "pkm_api" {
  name          = "pkm-mobile-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
    max_age       = 300
  }
}

# Cognito authorizer
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.pkm_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.ios_client.id]
    issuer   = "https://${aws_cognito_user_pool.pkm_users.endpoint}"
  }
}
```

### 1.3 API Lambda Functions

**New Lambda functions for API** (Babashka/Clojure, consistent with existing codebase):

| Function | Endpoint | Purpose |
|----------|----------|---------|
| `pkm-api-list-documents` | `GET /documents` | List documents with pagination |
| `pkm-api-get-document` | `GET /documents/{key}` | Get document content + metadata |
| `pkm-api-search` | `GET /search?q=...` | Full-text search via DynamoDB |
| `pkm-api-list-tags` | `GET /tags` | List all unique tags |
| `pkm-api-documents-by-tag` | `GET /tags/{tag}/documents` | Get documents by tag |
| `pkm-api-list-summaries` | `GET /summaries` | List daily summaries |
| `pkm-api-list-reports` | `GET /reports` | List weekly reports |

**Example handler** (`lambda/functions/api_list_documents/handler.clj`):

```clojure
(ns handler
  (:require [shared.aws.dynamodb :as ddb]
            [shared.aws.s3 :as s3]
            [cheshire.core :as json]))

(defn handler [event]
  (let [params (get event "queryStringParameters" {})
        limit (Integer/parseInt (get params "limit" "50"))
        cursor (get params "cursor")
        classification (get params "classification")

        ;; Query DynamoDB for document metadata
        results (if classification
                  (ddb/query-by-classification classification limit cursor)
                  (ddb/scan-documents limit cursor))]

    {:statusCode 200
     :headers {"Content-Type" "application/json"}
     :body (json/generate-string
            {:documents (:items results)
             :nextCursor (:cursor results)})}))
```

---

## Phase 2: iOS App Scaffold

### 2.1 Project Structure

```
ios/
├── PKMReader/
│   ├── App/
│   │   ├── PKMReaderApp.swift        # App entry point
│   │   └── AppDelegate.swift         # App lifecycle
│   │
│   ├── Core/
│   │   ├── Configuration/
│   │   │   ├── Environment.swift     # API URLs, Cognito config
│   │   │   └── Secrets.swift         # Sensitive config (gitignored)
│   │   │
│   │   ├── Networking/
│   │   │   ├── APIClient.swift       # HTTP client with auth
│   │   │   ├── APIEndpoints.swift    # Endpoint definitions
│   │   │   └── APIError.swift        # Error types
│   │   │
│   │   ├── Auth/
│   │   │   ├── AuthService.swift     # Cognito authentication
│   │   │   ├── KeychainService.swift # Secure token storage
│   │   │   └── AuthState.swift       # Auth state management
│   │   │
│   │   └── Cache/
│   │       ├── CacheService.swift    # Local document caching
│   │       └── CachePolicy.swift     # Cache invalidation rules
│   │
│   ├── Models/
│   │   ├── Document.swift            # Document model
│   │   ├── DocumentMetadata.swift    # Metadata model
│   │   ├── Tag.swift                 # Tag model
│   │   ├── Summary.swift             # Daily summary model
│   │   └── Report.swift              # Weekly report model
│   │
│   ├── Features/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   ├── LoginViewModel.swift
│   │   │   └── SignUpView.swift
│   │   │
│   │   ├── DocumentList/
│   │   │   ├── DocumentListView.swift
│   │   │   ├── DocumentListViewModel.swift
│   │   │   ├── DocumentRowView.swift
│   │   │   └── FilterSheet.swift
│   │   │
│   │   ├── DocumentDetail/
│   │   │   ├── DocumentDetailView.swift
│   │   │   ├── DocumentDetailViewModel.swift
│   │   │   └── MarkdownRenderer.swift
│   │   │
│   │   ├── Search/
│   │   │   ├── SearchView.swift
│   │   │   └── SearchViewModel.swift
│   │   │
│   │   ├── Tags/
│   │   │   ├── TagsView.swift
│   │   │   └── TagsViewModel.swift
│   │   │
│   │   ├── Summaries/
│   │   │   ├── SummariesView.swift
│   │   │   └── SummaryDetailView.swift
│   │   │
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── SettingsViewModel.swift
│   │
│   ├── Shared/
│   │   ├── Components/
│   │   │   ├── LoadingView.swift
│   │   │   ├── ErrorView.swift
│   │   │   ├── EmptyStateView.swift
│   │   │   └── TagChip.swift
│   │   │
│   │   └── Extensions/
│   │       ├── Date+Extensions.swift
│   │       ├── String+Extensions.swift
│   │       └── View+Extensions.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── Info.plist
│
├── PKMReader.xcodeproj/
├── PKMReaderTests/
├── PKMReaderUITests/
└── README.md
```

### 2.2 Key Models

**Document.swift**:
```swift
import Foundation

struct Document: Identifiable, Codable {
    let id: String           // S3 key
    let title: String
    let content: String?     // Markdown content (optional, loaded on demand)
    let metadata: DocumentMetadata

    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }
}

struct DocumentMetadata: Codable {
    let classification: DocumentClassification
    let tags: [String]
    let linksTo: [String]
    let entities: DocumentEntities?
    let created: Date
    let modified: Date
    let hasFrontmatter: Bool
}

enum DocumentClassification: String, Codable, CaseIterable {
    case meeting
    case idea
    case reference
    case journal
    case project

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .meeting: return "person.3"
        case .idea: return "lightbulb"
        case .reference: return "book"
        case .journal: return "book.closed"
        case .project: return "folder"
        }
    }
}

struct DocumentEntities: Codable {
    let people: [String]?
    let organizations: [String]?
    let concepts: [String]?
    let locations: [String]?
}
```

### 2.3 Core Services

**APIClient.swift**:
```swift
import Foundation

actor APIClient {
    private let baseURL: URL
    private let authService: AuthService
    private let session: URLSession

    init(baseURL: URL, authService: AuthService) {
        self.baseURL = baseURL
        self.authService = authService
        self.session = URLSession.shared
    }

    func listDocuments(
        classification: DocumentClassification? = nil,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> DocumentListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("documents"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: String(limit))]

        if let classification {
            queryItems.append(.init(name: "classification", value: classification.rawValue))
        }
        if let cursor {
            queryItems.append(.init(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        return try await request(url: components.url!)
    }

    func getDocument(key: String) async throws -> Document {
        let url = baseURL.appendingPathComponent("documents/\(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)")
        return try await request(url: url)
    }

    func search(query: String, limit: Int = 20) async throws -> [Document] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "limit", value: String(limit))
        ]
        return try await request(url: components.url!)
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let token = try await authService.getAccessToken()

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

struct DocumentListResponse: Codable {
    let documents: [Document]
    let nextCursor: String?
}

enum APIError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case unauthorized
}
```

**AuthService.swift**:
```swift
import Foundation
import AWSCognitoIdentityProvider

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: CognitoUser?

    private let userPool: AWSCognitoIdentityUserPool
    private let keychainService: KeychainService

    init() {
        // Configure Cognito
        let config = AWSCognitoIdentityUserPoolConfiguration(
            clientId: Environment.cognitoClientId,
            clientSecret: nil,
            poolId: Environment.cognitoUserPoolId
        )
        userPool = AWSCognitoIdentityUserPool(configuration: config)
        keychainService = KeychainService()

        // Check for existing session
        Task {
            await checkExistingSession()
        }
    }

    func signIn(email: String, password: String) async throws {
        let user = userPool.getUser(email)
        let session = try await user.authenticatePassword(password)

        // Store tokens securely
        try keychainService.store(token: session.accessToken, forKey: .accessToken)
        try keychainService.store(token: session.refreshToken, forKey: .refreshToken)

        isAuthenticated = true
        currentUser = CognitoUser(email: email)
    }

    func signOut() async {
        keychainService.deleteAll()
        isAuthenticated = false
        currentUser = nil
    }

    func getAccessToken() async throws -> String {
        guard let token = keychainService.retrieve(forKey: .accessToken) else {
            throw AuthError.notAuthenticated
        }

        // Check if token is expired and refresh if needed
        if isTokenExpired(token) {
            return try await refreshToken()
        }

        return token
    }

    private func refreshToken() async throws -> String {
        guard let refreshToken = keychainService.retrieve(forKey: .refreshToken) else {
            throw AuthError.notAuthenticated
        }

        let session = try await userPool.refresh(refreshToken: refreshToken)
        try keychainService.store(token: session.accessToken, forKey: .accessToken)

        return session.accessToken
    }

    private func checkExistingSession() async {
        if let token = keychainService.retrieve(forKey: .accessToken),
           !isTokenExpired(token) {
            isAuthenticated = true
        }
    }

    private func isTokenExpired(_ token: String) -> Bool {
        // Decode JWT and check exp claim
        // Implementation omitted for brevity
        return false
    }
}

enum AuthError: Error {
    case notAuthenticated
    case invalidCredentials
    case networkError
}

struct CognitoUser {
    let email: String
}
```

### 2.4 Main Views

**DocumentListView.swift**:
```swift
import SwiftUI

struct DocumentListView: View {
    @StateObject private var viewModel: DocumentListViewModel
    @State private var showingFilter = false

    init(apiClient: APIClient) {
        _viewModel = StateObject(wrappedValue: DocumentListViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView()

                case .loaded(let documents):
                    documentList(documents)

                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadDocuments() }
                    }

                case .empty:
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Documents",
                        message: "Your vault is empty"
                    )
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilter) {
                FilterSheet(
                    selectedClassification: $viewModel.selectedClassification,
                    onApply: {
                        Task { await viewModel.loadDocuments() }
                    }
                )
            }
            .searchable(text: $viewModel.searchText)
            .refreshable {
                await viewModel.loadDocuments()
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
    }

    private func documentList(_ documents: [Document]) -> some View {
        List {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .task {
                        await viewModel.loadNextPage()
                    }
            }
        }
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document, apiClient: viewModel.apiClient)
        }
    }
}

struct DocumentRowView: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: document.metadata.classification.icon)
                    .foregroundStyle(.secondary)
                Text(document.displayTitle)
                    .font(.headline)
            }

            if !document.metadata.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(document.metadata.tags, id: \.self) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
            }

            Text(document.metadata.modified, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

**DocumentDetailView.swift**:
```swift
import SwiftUI
import MarkdownUI

struct DocumentDetailView: View {
    let document: Document
    let apiClient: APIClient

    @StateObject private var viewModel: DocumentDetailViewModel

    init(document: Document, apiClient: APIClient) {
        self.document = document
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: DocumentDetailViewModel(
            document: document,
            apiClient: apiClient
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata header
                metadataSection

                Divider()

                // Markdown content
                switch viewModel.contentState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()

                case .loaded(let content):
                    Markdown(content)
                        .markdownTheme(.gitHub)
                        .padding(.horizontal)

                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadContent() }
                    }
                }
            }
        }
        .navigationTitle(document.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Classification badge
            HStack {
                Image(systemName: document.metadata.classification.icon)
                Text(document.metadata.classification.displayName)
            }
            .font(.subheadline)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.2))
            .clipShape(Capsule())

            // Tags
            if !document.metadata.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(document.metadata.tags, id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                }
            }

            // Entities
            if let entities = document.metadata.entities {
                entitiesSection(entities)
            }

            // Dates
            HStack {
                Label(document.metadata.created, style: .date)
                Spacer()
                Text("Modified: \(document.metadata.modified, style: .relative)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func entitiesSection(_ entities: DocumentEntities) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let people = entities.people, !people.isEmpty {
                entityRow(icon: "person", label: "People", items: people)
            }
            if let orgs = entities.organizations, !orgs.isEmpty {
                entityRow(icon: "building.2", label: "Organizations", items: orgs)
            }
            if let concepts = entities.concepts, !concepts.isEmpty {
                entityRow(icon: "lightbulb", label: "Concepts", items: concepts)
            }
            if let locations = entities.locations, !locations.isEmpty {
                entityRow(icon: "mappin", label: "Locations", items: locations)
            }
        }
    }

    private func entityRow(icon: String, label: String, items: [String]) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .frame(width: 20)
            Text(items.joined(separator: ", "))
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
```

---

## Phase 3: Implementation Roadmap

### Sprint 0: CI/CD Foundation (Week 1) ← **Critical: Complete First**

| Task | Priority | Effort | CI Verification |
|------|----------|--------|-----------------|
| Create Xcode project with targets (app, unit tests, UI tests) | High | Medium | Build passes |
| Configure SwiftLint + SwiftFormat | High | Low | Lint check passes |
| Set up Fastlane with test/build lanes | High | Medium | `fastlane test` works |
| Create `.github/workflows/ios-test.yml` | High | Medium | PR checks run |
| Create `.github/workflows/ios-build.yml` | High | Medium | Build artifacts upload |
| Implement mock infrastructure (protocols, mocks) | High | Medium | Sample unit test passes |
| Create test fixtures and helpers | Medium | Low | Tests use fixtures |
| Set up code coverage with 60% threshold | Medium | Low | Coverage check enforced |
| Create bootstrap script for new devs | Low | Low | Script runs successfully |

**Deliverables**:
- Xcode project skeleton with all targets
- CI pipeline that runs on every PR
- Mock infrastructure ready for feature development
- 100% of infrastructure testable from day one

**Exit Criteria** (must pass before Sprint 1):
- [ ] `fastlane lint` passes
- [ ] `fastlane test` passes (with sample tests)
- [ ] GitHub Actions PR workflow runs successfully
- [ ] Code coverage reporting works
- [ ] At least one unit test and one UI test exist

### Sprint 1: Backend Foundation (Week 2-3)

| Task | Priority | Effort | Tests Required |
|------|----------|--------|----------------|
| Add Cognito user pool and identity pool | High | Medium | Terraform validate |
| Create API Gateway with Cognito authorizer | High | Medium | Terraform validate |
| Implement `pkm-api-list-documents` Lambda | High | Low | Unit tests (bb test) |
| Implement `pkm-api-get-document` Lambda | High | Low | Unit tests (bb test) |
| Add API infrastructure to Terraform | High | Medium | Terraform plan |
| Write API integration tests | Medium | Medium | Integration test suite |

**Deliverables**:
- Terraform modules for Cognito + API Gateway
- 2 working API endpoints with authentication
- API documentation
- Integration tests for API endpoints

### Sprint 2: Core iOS App (Week 4-5)

| Task | Priority | Effort | Tests Required |
|------|----------|--------|----------------|
| Implement AuthService with Cognito SDK | High | High | Unit tests for auth flows |
| Implement APIClient | High | Medium | Unit tests with MockURLProtocol |
| Implement KeychainService | High | Low | Unit tests for storage |
| Build DocumentListViewModel | High | Medium | Unit tests for all states |
| Build DocumentListView | High | Medium | UI tests for list interactions |
| Build DocumentDetailViewModel | High | Medium | Unit tests for loading |
| Build DocumentDetailView with Markdown | High | Medium | UI tests for rendering |
| Add local caching with SwiftData | Medium | Medium | Unit tests for cache |

**Deliverables**:
- Working iOS app with login (tested)
- Document list and detail views (tested)
- Offline reading capability (tested)
- Minimum 70% code coverage

**Test Coverage Requirements**:
| Component | Minimum Coverage |
|-----------|-----------------|
| ViewModels | 80% |
| Services | 80% |
| Models | 90% |
| Views | 60% (UI tests) |

### Sprint 3: Enhanced Features (Week 6-7)

| Task | Priority | Effort | Tests Required |
|------|----------|--------|----------------|
| Implement search API Lambda | High | Low | Unit tests |
| Implement SearchViewModel | High | Medium | Unit tests for search states |
| Build SearchView | High | Medium | UI tests for search flow |
| Implement tags API Lambda | Medium | Low | Unit tests |
| Implement TagsViewModel | Medium | Medium | Unit tests |
| Build TagsView | Medium | Medium | UI tests |
| Add summaries/reports endpoints | Medium | Medium | Unit tests |
| Build SummariesView | Medium | Medium | UI tests |
| Build SettingsView | Low | Low | UI tests |
| Add pull-to-refresh and pagination | Medium | Low | UI tests |

**Deliverables**:
- Full-featured read-only PKM app
- Search functionality (tested)
- Browse by tags and classifications (tested)
- Minimum 75% code coverage

### Sprint 4: Polish & Release (Week 8-9)

| Task | Priority | Effort | Tests Required |
|------|----------|--------|----------------|
| Add comprehensive error handling | High | Medium | Unit tests for error states |
| Implement retry logic with exponential backoff | High | Medium | Unit tests |
| Add offline mode indicators | Medium | Low | UI tests |
| Add accessibility support | Medium | Medium | Accessibility audit |
| Add snapshot tests for key screens | Medium | Medium | Snapshot test suite |
| Performance testing and optimization | Medium | Medium | Performance benchmarks |
| App Store submission preparation | High | Medium | Manual QA checklist |
| Documentation | Medium | Low | - |

**Deliverables**:
- Production-ready iOS app
- App Store submission
- User documentation
- Minimum 80% code coverage
- All UI flows covered by UI tests

### Sprint Timeline Summary

```
Week 1:     [Sprint 0: CI/CD Foundation        ]
Week 2-3:   [Sprint 1: Backend API             ]
Week 4-5:   [Sprint 2: Core iOS App            ]
Week 6-7:   [Sprint 3: Enhanced Features       ]
Week 8-9:   [Sprint 4: Polish & Release        ]
```

### Continuous Integration Gates

Every PR must pass these checks before merge:

| Check | Requirement | Blocking |
|-------|-------------|----------|
| SwiftLint | No errors | Yes |
| SwiftFormat | No changes needed | Yes |
| Unit Tests | All pass | Yes |
| UI Tests | All pass | Yes |
| Code Coverage | ≥60% (Sprint 0-1), ≥70% (Sprint 2), ≥80% (Sprint 4) | Yes |
| Build | Release build succeeds | Yes |

### Test Pyramid Strategy

```
                    ┌───────────────┐
                    │   E2E Tests   │  ← Few, slow, high confidence
                    │   (Manual)    │
                    ├───────────────┤
                    │   UI Tests    │  ← Critical user flows
                    │   (~20%)      │
                    ├───────────────┤
                    │ Integration   │  ← API + Service boundaries
                    │   (~20%)      │
                    ├───────────────┤
                    │  Unit Tests   │  ← Fast, isolated, comprehensive
                    │   (~60%)      │
                    └───────────────┘
```

**Test Distribution Goals**:
- **Unit Tests (60%)**: ViewModels, Services, Models, Utilities
- **Integration Tests (20%)**: API client with mock server, Cache + persistence
- **UI Tests (20%)**: Critical user journeys, Accessibility checks

---

## Local Development Commands

### Quick Reference

```bash
# Navigate to iOS directory
cd ios

# First-time setup
./Scripts/bootstrap.sh

# Run all tests
bundle exec fastlane test

# Run unit tests only (faster)
bundle exec fastlane unit_tests

# Run UI tests only
bundle exec fastlane ui_tests

# Run linter
bundle exec fastlane lint

# Auto-fix lint issues
bundle exec fastlane lint_fix

# Format code
bundle exec fastlane format

# Check formatting (CI mode)
bundle exec fastlane format_check

# Build for development
bundle exec fastlane build_dev

# Generate code coverage report
bundle exec fastlane coverage_report

# Run tests with xcodebuild directly (alternative)
xcodebuild test \
  -project PKMReader.xcodeproj \
  -scheme PKMReader \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

### Pre-commit Checklist

Before pushing code, ensure:
```bash
bundle exec fastlane lint      # No SwiftLint errors
bundle exec fastlane format_check  # Code is formatted
bundle exec fastlane test      # All tests pass
```

### IDE Setup (Xcode)

1. Install SwiftLint Xcode plugin or add build phase:
   ```bash
   if which swiftlint > /dev/null; then
     swiftlint
   else
     echo "warning: SwiftLint not installed"
   fi
   ```

2. Enable "Treat Warnings as Errors" for Release builds

3. Configure test scheme to gather code coverage

---

## Technical Decisions

### Why Cognito?
- Native AWS integration with existing infrastructure
- Built-in user management, MFA support
- Free tier covers initial usage
- Easy integration with API Gateway

### Why REST vs GraphQL?
- Simpler implementation for read-only use case
- Better caching with HTTP semantics
- Consistent with existing Lambda patterns in codebase
- Can migrate to GraphQL/AppSync later if needed

### Why SwiftUI?
- Modern, declarative UI framework
- Better async/await support
- Less boilerplate than UIKit
- iOS 16+ is acceptable minimum deployment target

### Why SwiftData for Caching?
- Native Apple framework (iOS 17+)
- Automatic CloudKit sync potential
- Type-safe Swift integration
- Alternative: Core Data for iOS 16 support

### Markdown Rendering
- Use `MarkdownUI` package (swift-markdown-ui)
- Supports GitHub Flavored Markdown
- Customizable themes
- Good performance

---

## Dependencies

### iOS App
```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PKMReader",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PKMReader", targets: ["PKMReader"])
    ],
    dependencies: [
        // UI
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),

        // AWS
        .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm", from: "2.33.0"),

        // Testing (development only)
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
    ],
    targets: [
        .target(
            name: "PKMReader",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "AWSCognitoIdentityProvider", package: "aws-sdk-ios-spm"),
            ]
        ),
        .testTarget(
            name: "PKMReaderTests",
            dependencies: [
                "PKMReader",
            ]
        ),
        .testTarget(
            name: "PKMReaderSnapshotTests",
            dependencies: [
                "PKMReader",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
```

### Fastlane Gemfile (`ios/Gemfile`)
```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.219"
gem "xcpretty", "~> 0.3"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
```

### Fastlane Plugins (`ios/fastlane/Pluginfile`)
```ruby
gem "fastlane-plugin-xcov"
```

### Backend (Clojure/Babashka)
- Existing dependencies sufficient
- May need additional JSON schema validation

---

## CI/CD Secrets Configuration

### GitHub Repository Secrets

Configure these secrets in GitHub repository settings (`Settings > Secrets and variables > Actions`):

| Secret | Description | Required For |
|--------|-------------|--------------|
| `MATCH_PASSWORD` | Password for match certificate encryption | Code signing |
| `MATCH_GIT_URL` | Git URL for match certificates repo | Code signing |
| `FASTLANE_USER` | Apple ID email | App Store Connect |
| `FASTLANE_PASSWORD` | Apple ID password or app-specific password | App Store Connect |
| `APPLE_TEAM_ID` | Apple Developer Team ID | Code signing |
| `ASC_KEY_ID` | App Store Connect API Key ID | TestFlight upload |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID | TestFlight upload |
| `ASC_KEY` | App Store Connect API Key (base64) | TestFlight upload |

### Environment Protection Rules

Configure environment protection for `testflight`:
- Required reviewers for production deployments
- Only allow deployments from `main` branch

### Minimal Secrets for Sprint 0

For Sprint 0 (CI foundation), only these are needed:
- None! Sprint 0 uses simulator builds with no code signing

Code signing secrets are only required starting Sprint 4 for TestFlight/App Store deployment.

---

## Security Considerations

1. **Authentication**: All API endpoints require valid Cognito JWT
2. **Authorization**: Single-tenant initially (one user pool = one vault)
3. **Token Storage**: iOS Keychain for secure token storage
4. **HTTPS**: All API traffic over TLS
5. **Rate Limiting**: API Gateway throttling (1000 req/sec default)
6. **Audit Logging**: CloudWatch logs for all API calls

---

## Future Enhancements (Post-MVP)

1. **Write Support**: Create/edit documents from mobile
2. **Offline Sync**: Full offline capability with conflict resolution
3. **Push Notifications**: Alerts for new summaries/reports
4. **Widgets**: iOS home screen widgets for recent docs
5. **Spotlight Integration**: Search PKM from iOS Spotlight
6. **Share Extension**: Save content to PKM from other apps
7. **iPad Support**: Optimized layout for larger screens
8. **macOS App**: Catalyst or native SwiftUI Mac app

---

## File Locations Summary

### New Backend Files
```
terraform/
├── cognito.tf           # User authentication
├── api_gateway.tf       # REST API
└── api_lambda.tf        # API Lambda functions

lambda/functions/
├── api_list_documents/
│   └── handler.clj
├── api_get_document/
│   └── handler.clj
├── api_search/
│   └── handler.clj
└── api_list_tags/
    └── handler.clj
```

### New iOS App Files
```
ios/
├── PKMReader/           # Main app target
├── PKMReader.xcodeproj/ # Xcode project
├── PKMReaderTests/      # Unit tests
└── README.md            # iOS-specific docs
```

---

## Success Metrics

1. **Functional**: Can browse and read all vault documents
2. **Performance**: Document list loads in < 2 seconds
3. **Reliability**: 99.9% API uptime
4. **Usability**: Clean, intuitive interface
5. **Security**: No unauthorized access possible
