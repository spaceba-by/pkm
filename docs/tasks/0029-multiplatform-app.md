# Task 0029: iPad & macOS App

**Status**: Planned

**Depends on:** Task 0034 (Local Vault Mirror) for the shared package, store, feeders, Spotlight indexer, and App Intents.

## Specifications

Extend the PKM reading experience to iPad and macOS. iPad is handled inside the existing iOS app with adaptive layouts. macOS is handled by growing the existing sync app (`macos/`, bundle `by.spaceba.pkm.sync`, display name becoming "Sal") into the full reader, per the one-app decision recorded in Task 0034. The macOS app is **not** a macOS destination of the iOS project: the iOS project stays iOS-only, and both apps import the shared package from Task 0034 for models, networking, store, feeders, indexer, and intents.

The macOS app remains unsandboxed, Developer ID signed, notarized, GitHub-released, and self-updating, because rclone-based sync cannot run inside the App Sandbox.

### Platform Adaptations

**iPad:**
- Split view navigation (sidebar + detail) replacing tab bar on larger screens
- Keyboard shortcuts for common actions (search, refresh, navigation)
- Drag-and-drop support for document organization
- Multitasking support (Split View, Slide Over)

**macOS:**
- Sidebar navigation with collapsible sections
- Native menu bar with keyboard shortcuts
- Window management (multiple windows, resizable)
- System menu integration (File, Edit, View menus)
- The existing `MenuBarExtra` sync status item is retained alongside the reader windows
- Documents are read from the local vault directory through the `FilesystemFeeder`; classification, tags, and entities come from the Task 0034 manifest
- Sync conflicts (existing `ConflictService` / `DiffService`) are presented in the reader next to the affected note

### macOS Lifecycle Requirements (from the one-app decision)

- Activation policy switches to `.regular` while a reader window is open and back to `.accessory` when the last window closes; `LSUIElement` is removed from the build settings
- Closing windows never stops sync; Cmd-Q presents a confirmation stating that quitting stops sync, with "Close windows instead" as the default action
- `SyncScheduler` and `SyncService` run on an isolated actor with no dependency on UI state; reader view models hold no references into sync internals
- Self-update defers while any editor has unsaved changes or a sync phase is mid-run, and restores open windows after relaunch
- rclone continues to use its configured credentials; the reader authenticates via Cognito through Amplify. No credential unification in this task
- Escape hatch if crash coupling proves to be a problem in practice: split sync into an embedded login-item helper via `SMAppService` with XPC for status and conflicts, keeping a single bundle

### Code Sharing Strategy

- Models, networking, view models, store, feeders, indexer, and intents live in the Task 0034 shared Swift package
- Each app project (`ios/project.yml`, `macos/project.yml`) depends on the package; platform-specific views live in each app
- Shared SwiftUI views work across platforms; complex layouts use platform-specific implementations
- No `#if os(macOS)` in the iOS app target

## Relevant Files

### Modified Files
- `ios/project.yml` — iPad-optimized settings (no macOS target)
- `ios/PKMReader/App/MainTabView.swift` — Adaptive navigation (tabs on iPhone, split view on iPad)
- `ios/PKMReader/Features/*/` — iPad layout adaptations
- `macos/project.yml` — Shared package dependency, `WindowGroup` scenes, removal of `LSUIElement`, display name "Sal", DerivedData/SPM caching in CI
- `macos/PKMSync/App/PKMSyncApp.swift` — Reader `WindowGroup` alongside `MenuBarExtra`; activation policy switching; Quit confirmation
- `macos/PKMSync/Core/Scheduler/SyncScheduler.swift`, `Core/Sync/SyncService.swift` — Actor isolation from UI; completion hook for the `FilesystemFeeder`
- `macos/PKMSync/Core/Updates/UpdateInstaller.swift` — Defer on dirty editors or mid-sync; window restoration
- `.github/workflows/macos-build.yml`, `macos-test.yml` — Caching for the larger build

### New Files
- `ios/PKMReader/App/SidebarView.swift` — iPad sidebar navigation
- `macos/PKMSync/Features/Reader/` — macOS document list, detail, editor, insights, and graph views built on the shared package
- `macos/PKMSync/App/ActivationPolicyController.swift` — Dock icon and accessory-mode switching

## Acceptance Criteria

- [ ] iOS app runs on iPhone and iPad; iPad uses split view navigation on large screens
- [ ] macOS sync app presents reader windows with native sidebar navigation and menu bar, while retaining the menu bar sync item
- [ ] Keyboard shortcuts available on iPad and macOS
- [ ] All features functional across platforms (documents, search, tags, insights, graph)
- [ ] macOS reads documents via `FilesystemFeeder` from the synced vault directory; no S3 feeder on macOS
- [ ] Activation policy switches with window state; closing windows does not stop sync; Cmd-Q confirms before stopping sync
- [ ] Sync scheduler is isolated from UI and survives reader view errors
- [ ] Self-update defers on unsaved edits or mid-sync and restores windows after relaunch
- [ ] Sync conflicts shown in the reader next to the affected note
- [ ] Shared package used by both apps; no duplicated models or networking
- [ ] Platform-specific tests for iPad and macOS layouts; macOS CI uses build caching
- [ ] All existing iOS, macOS, and Lambda tests continue to pass

## Implementation Steps

- [ ] Step 1: Add the Task 0034 shared package as a dependency of `macos/project.yml`; remove `LSUIElement`; set display name "Sal"
- [ ] Step 2: Isolate `SyncScheduler` / `SyncService` on an actor and expose a completion hook; wire `FilesystemFeeder` to it
- [ ] Step 3: Add reader `WindowGroup`, `ActivationPolicyController`, and Quit confirmation to `PKMSyncApp`
- [ ] Step 4: Build macOS reader views (sidebar, list, detail, editor, insights, graph) on the shared package
- [ ] Step 5: Implement iPad split view, `SidebarView`, and keyboard shortcuts in the iOS app
- [ ] Step 6: Surface sync conflicts in the reader; gate self-update on dirty editors and mid-sync
- [ ] Step 6b: Add DerivedData and SPM caching to the macOS workflows
- [ ] Step 7: Add platform-specific tests
- [ ] Step 8: Verify all features across platforms
