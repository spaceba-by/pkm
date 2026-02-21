# Task 0027: iOS Widgets, Spotlight & Share Extension

**Status**: Planned

## Specifications

Extend the iOS app with system-level integrations: home screen widgets for at-a-glance PKM status, Spotlight indexing for system-wide document search, and a Share Extension for clipping content from other apps into the PKM vault.

### Widgets

- **Recent Summary Widget** (small/medium): Shows the latest daily summary title and date
- **Document Count Widget** (small): Shows total document count and recent activity
- **Search Monitor Widget** (medium): Shows active monitors with latest novelty scores
- Widgets use WidgetKit with timeline-based updates

### Spotlight Integration

- Index document titles, tags, and classifications using CoreSpotlight
- Search results deep link into the app's document detail view
- Index updated incrementally when documents are fetched from API

### Share Extension

- Accept text, URLs, and images from other apps
- Create new PKM documents via the write API (Task 0010)
- Minimal UI: title field, optional tags, content preview
- Requires shared keychain for authentication token access

**Depends on:** Task 0021 (Push Notifications) for widget update triggers.

## Relevant Files

### New Files
- `ios/PKMReader/Widgets/` — WidgetKit extension target
- `ios/PKMReader/ShareExtension/` — Share Extension target
- `ios/PKMReader/Core/Spotlight/SpotlightIndexer.swift` — CoreSpotlight integration

### Modified Files
- `ios/project.yml` — Add widget and share extension targets, app groups
- `ios/PKMReader/Core/Networking/APIClient.swift` — Shared keychain access for extensions

## Acceptance Criteria

- [ ] Small, medium widget sizes display PKM summary data
- [ ] Widgets refresh on timeline schedule and notification triggers
- [ ] Documents indexed in Spotlight with title, tags, and classification
- [ ] Spotlight search results navigate to document detail view
- [ ] Share Extension accepts text and URLs from other apps
- [ ] Share Extension creates documents via write API
- [ ] Shared keychain enables authentication across app and extensions
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Add WidgetKit extension target to project.yml
- [ ] Step 2: Create Recent Summary and Document Count widgets
- [ ] Step 3: Create Search Monitor widget
- [ ] Step 4: Implement CoreSpotlight indexing in document fetch flow
- [ ] Step 5: Add Spotlight search result handling with deep linking
- [ ] Step 6: Add Share Extension target to project.yml with app groups
- [ ] Step 7: Create Share Extension UI and write API integration
- [ ] Step 8: Configure shared keychain for cross-extension authentication
- [ ] Step 9: Write unit tests for indexing and widget timeline logic
