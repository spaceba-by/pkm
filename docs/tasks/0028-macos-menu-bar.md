# Task 0028: macOS Menu Bar App

**Status**: Planned

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
- `macos/PKMSync/` — macOS menu bar app project
- `macos/PKMSync/App/PKMSyncApp.swift` — App entry point with MenuBarExtra
- `macos/PKMSync/Core/SyncService.swift` — rclone wrapper and sync management
- `macos/PKMSync/Core/SyncScheduler.swift` — Timer-based sync scheduling
- `macos/PKMSync/Views/SyncStatusView.swift` — Menu bar popover content
- `macos/project.yml` — XcodeGen project definition

## Acceptance Criteria

- [ ] Menu bar icon shows sync status (idle, syncing, error)
- [ ] One-click manual sync triggers rclone
- [ ] Sync interval is configurable
- [ ] Recent sync log shows timestamps and file counts
- [ ] Conflicts surfaced to user with resolution options
- [ ] Recently modified documents listed with Obsidian open links
- [ ] App launches at login (optional preference)
- [ ] Unit tests for SyncService and SyncScheduler

## Implementation Steps

- [ ] Step 1: Create macOS project with XcodeGen and MenuBarExtra
- [ ] Step 2: Implement rclone wrapper (SyncService)
- [ ] Step 3: Create sync scheduler with configurable interval
- [ ] Step 4: Build menu bar popover UI (status, log, actions)
- [ ] Step 5: Add conflict detection and alerting
- [ ] Step 6: Add recently modified documents list
- [ ] Step 7: Add launch-at-login preference
- [ ] Step 8: Write unit tests
