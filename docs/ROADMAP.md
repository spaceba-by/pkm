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
  - 4-tab layout: Documents, Insights, Settings, Graph

- **Task 0012: iOS Test Coverage** ✅

  - See: [0012-ios-test-coverage](tasks/0012-ios-test-coverage.md)
  - Unit tests for InsightDetailViewModel and SettingsViewModel
  - Mock API infrastructure (`--mock-api` launch argument) for UI tests
  - 16 UI tests enabled across Search, Tags, Insights, Settings
  - Code coverage above 60%

- **Task 0014: Classification System Improvements** ✅

  - See: [0014-classification-improvements](tasks/0014-classification-improvements.md)
  - Enhanced classification prompt with system prompt, category descriptions, metadata signals, JSON confidence response
  - Classification feedback/correction API (PUT /documents/classification/{key+}) with override flag
  - Bulk reclassification Lambda with dry-run mode, classification filtering, override respect
  - Classification index optimization: scheduled every 6 hours instead of per-document
  - iOS: tappable ClassificationBadge with picker to change classification

- **Task 0008: iOS Polish & Release** ✅

  - See: [0008-ios-polish-release](tasks/0008-ios-polish-release.md)
  - Error handling, retry logic, offline support, accessibility, snapshot tests, performance profiling
  - App Store metadata, code signing, TestFlight deployment, user documentation
  - Full UI test coverage (DocumentList, DocumentDetail, Search, Tags, Insights, Settings)
  - Code coverage 80%+ (267 unit tests, 39 UI tests, CI threshold 78%)

- **Task 0016: Backfill Pre-Existing Documents** ✅

  - See: [0016-backfill-existing-documents](tasks/0016-backfill-existing-documents.md)
  - Paginated `list-all-objects` in `s3.clj` for S3 ListObjectsV2 with ContinuationToken
  - Babashka CLI script (`scripts/backfill.clj`) with dry-run, execute, prefix, limit, delay options
  - Detects unprocessed S3 documents missing from DynamoDB, triggers extract_metadata, classify_document, extract_entities

- **Task 0018: iOS UI Improvements** ✅

  - See: [0018-ios-ui-improvements](tasks/0018-ios-ui-improvements.md)
  - Strip YAML front matter from rendered document content (already shown in metadata header)
  - Render markdown checkboxes (`- [ ]` / `- [x]`) as visual checkbox indicators
  - Handle internal `[[wikilinks]]` as tappable navigation links
  - Fix unfiltered document list returning too few results (DynamoDB scan limit issue)

- **Task 0015: Document Deletion Cleanup** ✅

  - See: [0015-document-deletion-cleanup](tasks/0015-document-deletion-cleanup.md)
  - New `delete_document` Lambda triggered by S3 "Object Deleted" EventBridge events
  - Cascade-delete DynamoDB records (METADATA, tag index, entity index)
  - Bulk reclassify stale record cleanup
  - Fixes orphaned DynamoDB data when files are deleted from Obsidian vault

- **Task 0009: Semantic Search** ✅

  - See: [0009-semantic-search](tasks/0009-semantic-search.md)
  - In-memory vector index with cosine similarity search
  - Document chunking by heading structure, embeddings via Bedrock Titan or OpenAI
  - Incremental indexing pipeline with S3-persisted index
  - iOS search mode toggle (keyword/semantic) with protocol extension
  - CLI indexing script with dry-run, stats, and prefix/limit filtering

- **Task 0010: Write Support & Admin API** ✅

  - See: [0010-write-support](tasks/0010-write-support.md)
  - Cognito user groups (admin, reader) for role-based access control
  - 3 new API endpoints: create, update, delete documents (admin only)
  - Document editor with markdown preview, conflict detection
  - Lambda-level group-based authorization via Cognito JWT claims

- **Task 0011: Knowledge Graph Visualization** ✅

  - See: [0011-knowledge-graph](tasks/0011-knowledge-graph.md)
  - API endpoint (GET /graph) with entity relationship mapping from extracted entities
  - Interactive force-directed graph visualization in iOS app with Canvas rendering
  - 4-tab layout: Documents, Insights, Settings, Graph
  - Navigate documents by entity connections, color-coded by classification/type

- **Task 0017: Insights Calendar Design** ✅

  - See: [0017-insights-calendar-design](tasks/0017-insights-calendar-design.md)
  - Replace Insights tab segmented list with monthly calendar grid view
  - Visual indicators for days with daily summaries and weeks with weekly reports
  - Month-to-month navigation matching iOS Calendar app conventions
  - Accessibility support for calendar interactions

- **Task 0013: Persistent Search** ✅

  - See: [0013-persistent-search](tasks/0013-persistent-search.md)
  - Search monitors with configurable terms, schedule, and novelty threshold
  - Periodic web search execution via Brave Search API
  - AI-driven summarization and comparison agent (Bedrock Sonnet)
  - Threshold-based flagging for significant updates with notification event records

- **Task 0019: Persistent Search UI** ✅

  - See: [0019-persistent-search-ui](tasks/0019-persistent-search-ui.md)
  - iOS views for managing search monitors (create, list, edit, delete, view summaries)
  - Backend API already complete (7 endpoints from Task 0013)
  - SearchMonitor model, views, and view models following existing patterns

- **Task 0020: Secrets Management** ✅

  - See: [0020-secrets-management](tasks/0020-secrets-management.md)
  - Centralize Terraform secrets resources into dedicated `secrets.tf`
  - Generalize IAM policy for multi-secret support
  - Extend secrets_manager.clj with multi-key caching

- **Task 0033: Unified Documents View** ✅

  - See: [0033-unified-documents-view](tasks/0033-unified-documents-view.md)
  - Consolidated Documents, Search, and Tags tabs into a single Documents tab
  - Integrated search bar with keyword/semantic mode, expanded FilterSheet with tags
  - Reduced tab bar from 6 tabs to 4: Documents, Insights, Settings, Graph

- **Task 0021: Push Notifications** ✅

  - See: [0021-push-notifications](tasks/0021-push-notifications.md)
  - AWS SNS Platform Application with APNs integration for iOS push notifications
  - Notification dispatch Lambda triggered by DynamoDB Stream on notification records
  - Device token registration API, notification list/acknowledge API
  - Daily summary and weekly report Lambdas create notification records
  - iOS NotificationService and NotificationHandler with deep linking

- **Task 0022: Webhook Receiving & Classification** ✅

  - See: [0022-webhook-receiving](tasks/0022-webhook-receiving.md)
  - API endpoint for receiving external webhooks (GitHub, email, custom)
  - HMAC signature verification, classification, and routing
  - Admin CRUD API for webhook source management

- **Task 0023: Command Interface** ✅

  - See: [0023-command-interface](tasks/0023-command-interface.md)
  - Chat API with Bedrock-powered reasoning agent querying PKM data
  - @sal command parsing in PKM notes, async command_process Lambda
  - Conversation state in DynamoDB, response delivery via API and S3
  - iOS chat view

- **Task 0024: Automated Task Extraction** ✅

  - See: [0024-task-extraction](tasks/0024-task-extraction.md)
  - extract_tasks Lambda runs in parallel with document processing pipeline
  - Pattern matching (checkboxes, TODOs) and AI detection for meetings/projects
  - Task index in DynamoDB with open/completed partitions
  - API endpoints (GET /tasks, GET /tasks/stats) for browsing extracted tasks

- **Task 0028: macOS Menu Bar App** ✅

  - See: [0028-macos-menu-bar](tasks/0028-macos-menu-bar.md)
  - Native SwiftUI menu bar app (PKMSync) wrapping rclone bisync for vault sync
  - Sync status indicator, manual sync, configurable schedule, sync log viewer
  - Conflict detection and resolution, launch-at-login, check-for-updates

- **Task 0025: Self-Improvement Dispatch** ✅

  - See: [0025-self-improvement-dispatch](tasks/0025-self-improvement-dispatch.md)
  - Job dispatch infrastructure with dual execution targets: ECS Fargate sandbox and local agent polling API
  - Agent types stored in DynamoDB define execution config per job type
  - 8 new Lambdas (dispatch_job, collect_results, 6 job/agent-type API endpoints), Terraform gated by `enable_dispatch` flag
  - iOS dispatch job views with navigation from Insights

### Planned

#### Tier 4 — Advanced Agents

- **Task 0026: Custom Agent Workflows**

  - See: [0026-custom-agent-workflows](tasks/0026-custom-agent-workflows.md)
  - User-defined automation rules with configurable triggers and prompt templates
  - Workflow execution engine using Bedrock
  - Depends on: Task 0023

#### Tier 5 — Platform Expansion

- **Task 0027: iOS Widgets, Spotlight & Share Extension**

  - See: [0027-ios-extensions](tasks/0027-ios-extensions.md)
  - Home screen widgets, Spotlight indexing, Share Extension for content clipping
  - Depends on: Task 0021

- **Task 0029: iPad & macOS App**

  - See: [0029-multiplatform-app](tasks/0029-multiplatform-app.md)
  - Multi-platform SwiftUI app with platform-adaptive layouts
  - Split view (iPad), sidebar navigation (macOS), shared code extraction

#### Tier 6 — Integrations & Advanced

- **Task 0030: F5-TTS Speech Generation**

  - See: [0030-f5-tts-speech](tasks/0030-f5-tts-speech.md)
  - Text-to-speech for summaries and reports using F5-TTS
  - Voice clone, S3 audio storage, iOS playback

- **Task 0031: Email/Calendar Integration**

  - See: [0031-email-calendar-integration](tasks/0031-email-calendar-integration.md)
  - OAuth-based email and calendar provider connections
  - Periodic sync, markdown conversion, processing pipeline integration
  - Depends on: Task 0020 ✅

- **Task 0032: Real-time Collaboration**

  - See: [0032-realtime-collaboration](tasks/0032-realtime-collaboration.md)
  - WebSocket-based multi-user document editing and sharing
  - Conflict resolution, presence indicators, activity feed
