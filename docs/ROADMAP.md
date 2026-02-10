# PKM Development Roadmap

System for Personal Knowledge Management (PKM), based on obsidian style markdown files.

## Overview

Automatically processes markdown documents from an Obsidian vault: classifies them, extracts entities, and generates daily summaries and weekly reports using Claude models via Amazon Bedrock. Provides a mobile iOS app for user interface.

## Development Workflow

1. **Task Planning**

    - Study the existing code base and understand the current state
    - Update `ROADMAP.md` to include the new task
    - Priority tasks should be inserted after the last completed task

2. **Task Creation**

    - Study the existing code base and understand the current state
    - Create a new task file in the `docs/tasks` directory
    - Name format: `XXXX-description.md` (e.g., `0001-initial-infrastructure.md`)
    - Include high-level specifications, relevant files, acceptance criteria, and implementation steps
    - Refer to last completed task in the `docs/tasks` directory for examples. For example, if the current task is `0012`, refer to `0011` and `0010` for examples.
    - Note that these examples are completed tasks, so the content reflects the final state of completed tasks (checked boxes and summary of changes). For the new task, the document should contain empty boxes and no summary of changes. Refer to `0000-sample.md` as the sample for initial state.

3. **Task Implementation**

    - Follow the specifications in the task file
    - Implement features and functionality
    - Update step progress within the task file after each step
    - Stop after completing each step and wait for further instructions

4. **Roadmap Updates**

    - Mark completed tasks with ✅ in the road map
    - Add reference to the task file (e.g., `See: [0001-initial-infrastructure](tasks/0001-initial-infrastructure.md)`)

## Development Phases

### Completed

- **Task 0001: Initial Infrastructure** ✅

  - See: [0001-initial-infrastructure](tasks/0001-initial-infrastructure.md)
  - Terraform: S3, DynamoDB, EventBridge, Step Functions, IAM, CloudWatch
  - Remote state backend with S3 and DynamoDB locking

- **Task 0002: Processing Lambda Functions** ✅

  - See: [0002-processing-lambdas](tasks/0002-processing-lambdas.md)
  - 6 processing Lambdas (classify, extract entities/metadata, daily summary, weekly report, classification index)
  - Migrated from Python to Babashka/Clojure with bblf runtime
  - 27 unit tests, 158 assertions

- **Task 0003: CI/CD Pipeline** ✅

  - See: [0003-ci-cd-pipeline](tasks/0003-ci-cd-pipeline.md)
  - GitHub Actions for Lambda build/test
  - Automatic Terraform plan on PR, apply on merge
  - GitHub OIDC authentication for AWS

- **Task 0004: iOS Build & Test Automation** ✅

  - See: [0004-ios-build-automation](tasks/0004-ios-build-automation.md)
  - XcodeGen, Fastlane, SwiftLint, GitHub Actions CI
  - Mock infrastructure for testing
  - Swift 6 concurrency compliance

- **Task 0005: Backend API Infrastructure** ✅

  - See: [0005-backend-api](tasks/0005-backend-api.md)
  - Cognito User Pool and Identity Pool
  - API Gateway HTTP API with JWT authorization
  - 8 API Lambda functions for document access

- **Task 0006: iOS App Core Scaffold** ✅

  - See: [0006-ios-app-scaffold](tasks/0006-ios-app-scaffold.md)
  - Auth flow with AWS Amplify/Cognito
  - APIClient, KeychainService, CacheService
  - SwiftUI views with MVVM architecture
  - Document list with classification filtering, document detail with markdown rendering

- **Task 0007: iOS Enhanced Features** ✅

  - See: [0007-ios-enhanced-features](tasks/0007-ios-enhanced-features.md)
  - Search view with debounced text input
  - Tags browsing with drill-down to documents by tag
  - Insights tab combining daily summaries and weekly reports
  - Enhanced settings with cache management and preferences
  - 5-tab layout: Documents, Search, Tags, Insights, Settings

- **Task 0012: iOS Test Coverage** ✅

  - See: [0012-ios-test-coverage](tasks/0012-ios-test-coverage.md)
  - Unit tests for InsightDetailViewModel and SettingsViewModel
  - Mock API infrastructure (`--mock-api` launch argument) for UI tests
  - 16 UI tests enabled across Search, Tags, Insights, Settings
  - Code coverage above 60%

### Planned

- **Task 0008: iOS Polish & Release**

  - See: [0008-ios-polish-release](tasks/0008-ios-polish-release.md)
  - Comprehensive error handling and retry logic
  - Accessibility support (VoiceOver, Dynamic Type)
  - Snapshot tests, performance optimization
  - App Store submission

- **Task 0009: Semantic Search**

  - See: [0009-semantic-search](tasks/0009-semantic-search.md)
  - OpenSearch integration for full-text search
  - Relevance scoring and result highlighting
  - Filter by date range, classification, tags

- **Task 0010: Write Support & Admin API**

  - See: [0010-write-support](tasks/0010-write-support.md)
  - Create/edit/delete documents from mobile
  - Cognito user groups for admin authorization
  - Document editor with markdown preview

- **Task 0011: Knowledge Graph Visualization**

  - See: [0011-knowledge-graph](tasks/0011-knowledge-graph.md)
  - Entity relationship mapping from extracted entities
  - Interactive graph visualization in iOS app
  - Navigate documents by entity connections

### Future Ideas (not yet scoped)

- Interactive chat interface to query PKM
- Automated task extraction and tracking
- Email/calendar integration for context
- Push notifications for new summaries/reports
- iOS widgets, Spotlight search, Share Extension
- iPad and macOS app support
- Real-time collaboration features
- Custom agent workflows (user-defined)
