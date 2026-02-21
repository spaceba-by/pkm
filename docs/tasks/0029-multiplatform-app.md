# Task 0029: iPad & macOS App

**Status**: Planned

## Specifications

Extend the PKM Reader iOS app into a multi-platform SwiftUI application supporting iPad and macOS. The existing iOS app (6-tab layout with Documents, Search, Tags, Insights, Settings, Graph) shares its models, networking, and view models across platforms, with platform-adaptive UI layouts.

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
- Touch Bar support (if applicable)

### Code Sharing Strategy

- Models, networking, and view models shared via conditional compilation
- Platform-specific views use `#if os(iOS)` / `#if os(macOS)` where needed
- Shared SwiftUI views work across platforms; complex layouts use platform-specific implementations
- Single XcodeGen project with multiple platform targets

## Relevant Files

### Modified Files
- `ios/project.yml` — Add macOS and iPad-optimized targets
- `ios/PKMReader/App/MainTabView.swift` — Platform-adaptive navigation (tabs vs sidebar)
- `ios/PKMReader/Features/*/` — Platform-specific layout adaptations

### New Files
- `ios/PKMReader/App/SidebarView.swift` — macOS/iPad sidebar navigation
- `ios/PKMReader/Platform/` — Platform-specific view implementations

## Acceptance Criteria

- [ ] App compiles and runs on iOS, iPadOS, and macOS
- [ ] iPad uses split view navigation on large screens
- [ ] macOS uses native sidebar navigation and menu bar
- [ ] Keyboard shortcuts available on iPad and macOS
- [ ] All features functional across platforms (documents, search, tags, insights, graph)
- [ ] Models and networking code shared without duplication
- [ ] Platform-specific tests for iPad and macOS layouts
- [ ] All existing iOS tests continue to pass

## Implementation Steps

- [ ] Step 1: Add macOS destination to XcodeGen project
- [ ] Step 2: Extract shared code into platform-agnostic modules
- [ ] Step 3: Create SidebarView for macOS/iPad navigation
- [ ] Step 4: Add conditional compilation for platform-specific views
- [ ] Step 5: Implement iPad split view and keyboard shortcuts
- [ ] Step 6: Implement macOS menu bar and window management
- [ ] Step 7: Add platform-specific tests
- [ ] Step 8: Verify all features across platforms
