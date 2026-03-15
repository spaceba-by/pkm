# Task 0028: macOS Menu Bar App

**Status**: Done

## Specifications

Build a lightweight macOS menu bar application for managing rclone sync operations between the local Obsidian vault and S3. The menu bar app provides quick-access sync controls without requiring the full PKM reader app, targeting users who primarily interact with their vault through Obsidian on desktop.

### Key Features

- **Sync status indicator**: Menu bar icon reflects sync state (idle, syncing, error)
- **Manual sync trigger**: One-click sync execution
- **Sync schedule management**: Configure sync interval (currently 5 minutes via cron)
- **Recent sync log**: View last N sync results with timestamps and file counts
- **Conflict detection**: Alert when sync conflicts are detected
- **Quick document access**: Show recently modified documents with links to open in Obsidian

### Architecture

- Native SwiftUI macOS app using MenuBarExtra
- Wraps rclone CLI for sync operations
- Local configuration stored in UserDefaults
- No backend API dependency (operates directly with local vault and rclone)
- Optional: API integration for document counts and summary status

## Relevant Files

### New Files
- `macos/project.yml` — XcodeGen project definition
- `macos/PKMSync/App/PKMSyncApp.swift` — App entry point with MenuBarExtra and Settings scene
- `macos/PKMSync/Core/Configuration/SyncConfiguration.swift` — UserDefaults-backed configuration with rclone path resolution
- `macos/PKMSync/Core/Sync/SyncService.swift` — rclone bisync wrapper
- `macos/PKMSync/Core/Sync/RcloneOutputParser.swift` — Parser for rclone stdout/stderr stats
- `macos/PKMSync/Core/Sync/ProcessRunner.swift` — Async process execution wrapper
- `macos/PKMSync/Core/Scheduler/SyncScheduler.swift` — Timer-based sync scheduling with log management
- `macos/PKMSync/Core/Conflicts/ConflictService.swift` — Conflict file scanning and resolution
- `macos/PKMSync/Features/MenuBar/MenuBarView.swift` — Menu bar popover UI (status, log, conflicts, recent files)
- `macos/PKMSync/Features/MenuBar/MenuBarViewModel.swift` — Menu bar view model
- `macos/PKMSync/Features/Settings/SettingsView.swift` — Settings UI (vault, schedule, rclone, launch-at-login)
- `macos/PKMSync/Features/Settings/SettingsViewModel.swift` — Settings logic and rclone detection
- `macos/PKMSync/Models/` — SyncStatus, SyncLogEntry, ConflictFile models
- `macos/PKMSyncTests/` — 35 unit tests across 6 test files with 3 mock services

## Acceptance Criteria

- [x] Menu bar icon shows sync status (idle, syncing, error)
- [x] One-click manual sync triggers rclone
- [x] Sync interval is configurable
- [x] Recent sync log shows timestamps and file counts
- [x] Conflicts surfaced to user with resolution options
- [x] Recently modified documents listed with Obsidian open links
- [x] App launches at login (optional preference)
- [x] Unit tests for SyncService and SyncScheduler

## Implementation Steps

- [x] Step 1: Create macOS project with XcodeGen and MenuBarExtra
- [x] Step 2: Implement rclone wrapper (SyncService)
- [x] Step 3: Create sync scheduler with configurable interval
- [x] Step 4: Build menu bar popover UI (status, log, actions)
- [x] Step 5: Add conflict detection and alerting
- [x] Step 6: Add recently modified documents list
- [x] Step 7: Add launch-at-login preference
- [x] Step 8: Write unit tests
