# Task 0034: Local Vault Store, App Intents & Spotlight

**Status**: Planned

## Specifications

Build a shared, on-device store of vault metadata that serves three consumers: fast note loading in the iOS app, Siri / Shortcuts access via App Intents, and system-wide Spotlight search. The store is designed from the start to be fed from two sources (the backend API on iOS, the local vault filesystem on macOS) and to be read by multiple processes (the main app, widgets, and intent extensions) across iOS, iPadOS, and macOS.

### Problem

Every note tap in the iOS app is a full network round trip. `DocumentDetailViewModel` always calls `getDocument` because list responses never include content, so each open chains an Amplify token fetch, an API Gateway JWT check, a Babashka Lambda cold start, and sequential DynamoDB and S3 reads. The existing `DocumentCacheService` (SwiftData, 1-hour TTL) is not wired into any view model; only the Settings "clear cache" action and the performance tests reference it.

App Intents and Spotlight both require fast, local answers. Siri entity resolution must return in well under a second, and a Spotlight index that only contains documents the user has already browsed feels broken. Neither is achievable on top of per-request Lambda calls.

### Vault Scale

The vault holds roughly 13,000 S3 objects (as of 2026-11-14), including attachments and `_agent/` outputs. Metadata for that many documents is 10–15 MB on disk and well within SwiftData and Core Spotlight limits. The constraint is the initial sync, not storage:

| Path | Requests for a full sync | Verdict |
|---|---|---|
| Metadata via `GET /documents`, 100 per page | ~131 Lambda calls | Tolerable once, slow on first launch |
| Content via `GET /documents/{key}` | ~13,000 Lambda calls | Not acceptable |
| Metadata via a manifest file | 1 download | Target design |

### Design Decisions

**Mirror metadata, fetch content lazily.** All document metadata (key, title, classification, tags, created, modified) is mirrored locally. Content is fetched on open and cached, with background prefetch for the N most recently modified documents and anything the user has opened. Siri and Spotlight only need metadata; offline reading covers recently touched notes.

**Manifest replaces paging and tombstones.** The pipeline maintains a gzipped JSON manifest of every document's metadata under `_agent/manifest.json.gz`, regenerated on a schedule or on each metadata write. One new API endpoint serves it. The client diffs the manifest against the local store: new or newer entries are upserted, and any local key absent from the manifest is treated as deleted. This removes the need for backend tombstone records. Delta sync via the `all-documents-modified-index` GSI remains useful between manifest refreshes but is not load-bearing for correctness.

**Keep `DocumentCacheService`, delete `CacheServiceProtocol`.** Neither abstraction is in use. `DocumentCacheService` is already wired to the Settings clear-cache action and is the SwiftData-backed one, so it becomes the store. The generic key/value `CacheServiceProtocol`, `CacheKey`, and `MockCacheService` are removed.

**Shared package, App Group container.** The store, its schema, the Spotlight indexer, and the App Intents move into a Swift package imported by every target (iOS app, widgets, intent extensions, macOS reader). The SwiftData store file lives in an App Group container so widgets and extensions can read it. App Intents are discovered per target, so iOS and macOS each compile their own copy from the shared package.

**Two feeders, one store.** A `VaultFeeder` protocol abstracts where document records come from:

- `APIFeeder` (iOS): manifest download, delta sync via modified GSI, lazy content fetch.
- `FilesystemFeeder` (macOS): reads markdown directly from the configured vault path and watches it for changes. Classification, tags, and entities still come from the API or manifest since they live in DynamoDB, not in the file.

The S3 key and the vault-relative file path are the same string, so document identity, Spotlight identifiers, and deep links are identical on both platforms.

**Stale-while-revalidate, never authoritative.** S3 is the source of truth and Obsidian edits arrive via rclone outside the app. The list and detail views render from the store immediately, then revalidate using `modified`. Cached content is never used as the basis for an edit: the editor always opens from freshly fetched content and the fresh `modified` value.

**Write-through on every mutation.** Classification updates, edits, creates, and deletes performed in-app update the local store and the Spotlight index before anything else observes them. Widgets and intents are strictly read-only consumers of the store.

**Spotlight indexes metadata only.** The Spotlight index sits outside the app's data protection. Index titles, tags, and classification; do not index note bodies. Indexing is batched (500–1000 items) with Core Spotlight client state so a killed app resumes rather than restarts. The reindex-all delegate callback replays from the store.

**Local pagination.** Once metadata is mirrored, the Documents tab queries SwiftData directly for sort, classification filter, and tag filter. The `GET /documents` endpoint becomes a sync source and fallback, not the UI's data source.

### Cross-Platform Considerations

- **macOS has the vault on disk.** The sync app (`macos/`, bundle `by.spaceba.pkm.sync`) already keeps a local vault via rclone bisync. A macOS reader does not need an API-backed content cache; the `FilesystemFeeder` reads files directly. macOS Spotlight already indexes plain markdown in the vault folder, so the custom index there is primarily for deep linking into the app.
- **One app or two on macOS.** The sync app and the planned reader (Task 0029) are separate bundle IDs today. If they stay separate, the App Group and keychain access group must span all targets, and the sync app becomes the natural filesystem feeder. This decision should be made before the shared package is created.
- **Entitlements live in `project.yml`.** XcodeGen overwrites entitlements files on every `generate`. App Groups, keychain sharing, and URL types must be declared under `entitlements.properties` in each project's `project.yml`.
- **Unsandboxed macOS sync app.** The sync app is not sandboxed and runs rclone as a subprocess. Unsandboxed apps can still use App Groups, but the container path differs; resolve it via `containerURL(forSecurityApplicationGroupIdentifier:)` and never hardcode it.
- **Widgets are the strictest consumer.** They run in a separate process with tight memory and should not rely on network. They read the shared store and nothing else.

### Auth and Navigation Prerequisites

- **Amplify bootstrap must leave `RootView`.** `AuthService.configure()` is only called from `RootView.task`. An App Intent running in the background never renders `RootView`, so the first API call would fail. Move configuration to app init or a lazy shared initializer. Keychain items already use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, which is correct for background intents.
- **A document deep link does not exist.** `MainTabView.handleDeepLink` only switches tabs. Spotlight results and Siri "open note" both need a route to a specific document by key: a URL scheme in `project.yml` and a navigation path into the document stack.
- **Editor conflict token.** `DocumentEditorViewModel` sends `ifUnmodifiedSince` from the list's metadata rather than from the fetched content's metadata. This is a latent mismatch today and a cache makes it worse. The editor must use the `modified` value returned alongside the content it is editing.
- **Sign-out.** Clear the store and the Spotlight index on sign-out. Nothing does this today.

### Deferred Option: Direct S3 Access

Granting the Cognito Identity Pool's authenticated role read-only S3 access would let iOS sync like rclone does (one `ListObjectsV2` pass plus direct `GetObject` calls), bypassing Lambda and making full content mirroring realistic. Today that role can only invoke API Gateway (`terraform/cognito.tf`). The cost is that the API stops being the single access boundary and the reader/admin group distinction would need to be reflected in IAM. Keep as a later upgrade if lazy content proves insufficient.

## Relevant Files

### New Files

- `shared/PKMCore/` (or equivalent Swift package) — Shared package containing models, networking, store, indexer, and intents
- `shared/PKMCore/Sources/Store/VaultStore.swift` — Renamed and rewritten `DocumentCacheService` with background context and batched upserts
- `shared/PKMCore/Sources/Store/VaultFeeder.swift` — Feeder protocol
- `shared/PKMCore/Sources/Store/APIFeeder.swift` — Manifest download, delta sync, lazy content fetch
- `shared/PKMCore/Sources/Store/FilesystemFeeder.swift` — macOS vault directory reader and watcher
- `shared/PKMCore/Sources/Spotlight/SpotlightIndexer.swift` — Batched Core Spotlight indexing with client state
- `shared/PKMCore/Sources/Intents/DocumentEntity.swift` — `AppEntity` and `EntityQuery` backed by the store
- `shared/PKMCore/Sources/Intents/OpenDocumentIntent.swift`, `SearchDocumentsIntent.swift`, `ReadDocumentIntent.swift` — App Intents
- `lambda/functions/generate_manifest/handler.clj` — Builds `_agent/manifest.json.gz` from the modified GSI
- `lambda/functions/api_get_manifest/handler.clj` — Serves the manifest (or a presigned URL to it)
- `terraform/manifest.tf` — Manifest Lambda, schedule, and API route

### Modified Files

- `ios/PKMReader/Core/Cache/DocumentCacheService.swift` — Moved to shared package and rewritten
- `ios/PKMReader/Core/Cache/CachedDocument.swift` — Moved to shared package; schema extended
- `ios/PKMReader/Features/DocumentList/DocumentListViewModel.swift` — Read from store, local pagination and filters, trigger sync
- `ios/PKMReader/Features/DocumentDetail/DocumentDetailViewModel.swift` — Stale-while-revalidate from store
- `ios/PKMReader/Features/Editor/DocumentEditorViewModel.swift` — Use `modified` from fetched content for `ifUnmodifiedSince`
- `ios/PKMReader/App/PKMReaderApp.swift` — Amplify bootstrap, URL scheme handling
- `ios/PKMReader/App/MainTabView.swift` — Document deep link route
- `ios/PKMReader/Core/Auth/AuthService.swift` — Lazy shared configuration; clear store and index on sign-out
- `ios/PKMReader/Features/Settings/SettingsViewModel.swift` — Clear-cache wiring follows the moved store
- `ios/project.yml` — Shared package dependency, App Group, keychain group, URL types
- `macos/project.yml` — App Group and keychain group (if sync app feeds the store)
- `docs/tasks/0027-ios-extensions.md` — Spotlight indexing now provided by this task; widgets read the shared store

### Files to Delete

- `ios/PKMReader/Core/Cache/CacheServiceProtocol.swift` — Unused abstraction
- `ios/PKMReaderTests/Mocks/MockCacheService.swift` — Mock for the removed protocol

## Acceptance Criteria

- [ ] `CacheServiceProtocol`, `CacheKey`, and `MockCacheService` removed; `DocumentCacheService` is the single store
- [ ] Store, feeders, indexer, and intents live in a shared Swift package imported by the iOS app target
- [ ] SwiftData store file is located in an App Group container
- [ ] Manifest Lambda produces `_agent/manifest.json.gz` and a new API endpoint serves it
- [ ] Initial sync of all document metadata completes with a single manifest download plus batched upserts on a background context
- [ ] Documents absent from the manifest are removed from the store and the Spotlight index
- [ ] Delta sync via modified GSI runs on foreground and on a background refresh schedule
- [ ] Documents list renders from the store with local sort, classification, and tag filtering
- [ ] Document detail renders cached content immediately and revalidates using `modified`
- [ ] Content prefetched for the most recently modified documents and retained for opened documents
- [ ] Editor always opens from freshly fetched content and sends the matching `modified` as `ifUnmodifiedSince`
- [ ] Classification updates, edits, creates, and deletes write through to the store and Spotlight index
- [ ] Spotlight indexes title, tags, and classification only, in batches with client state; reindex-all callback implemented
- [ ] Tapping a Spotlight result opens the document via a URL-scheme deep link
- [ ] App Intents: open document, search documents, read document; entity query resolves from the store without network
- [ ] Intents work when the app is launched in the background (Amplify configured outside `RootView`)
- [ ] Sign-out clears the store and the Spotlight index
- [ ] `FilesystemFeeder` protocol conformance exists and is covered by unit tests (full macOS reader integration lands with Task 0029)
- [ ] Entitlements declared in `project.yml`, not in the generated entitlements file
- [ ] All existing iOS and Lambda tests continue to pass

## Implementation Steps

- [ ] Step 1: Decide App Group identifier, keychain access group, and whether the macOS reader and sync app share a bundle; record in this document
- [ ] Step 2: Create the shared Swift package; move models, networking, `DocumentCacheService`, and `CachedDocument` into it; delete `CacheServiceProtocol` and `MockCacheService`
- [ ] Step 3: Rewrite the store: App Group container location, background `ModelContext`, batched upserts keyed on a single fetch of existing identifiers, bulk delete of missing keys
- [ ] Step 4: Backend: `generate_manifest` Lambda on an EventBridge schedule writing `_agent/manifest.json.gz`; `api_get_manifest` endpoint; Terraform
- [ ] Step 5: Implement `VaultFeeder` protocol and `APIFeeder` (manifest diff, delta sync via modified GSI, lazy content fetch with prefetch)
- [ ] Step 6: Wire `DocumentListViewModel` to the store with local pagination and filters; trigger sync on appear and refresh
- [ ] Step 7: Wire `DocumentDetailViewModel` to stale-while-revalidate; fix editor `ifUnmodifiedSince` source
- [ ] Step 8: Write-through from all mutation paths (classification, edit, create, delete); clear store and index on sign-out
- [ ] Step 9: Move Amplify bootstrap out of `RootView`; add URL scheme and document deep link route
- [ ] Step 10: Implement `SpotlightIndexer` with batched indexing, client state, and reindex-all callback; index from store on sync completion and on write-through
- [ ] Step 11: Implement `DocumentEntity`, `EntityQuery`, and the open / search / read intents; verify background launch
- [ ] Step 12: Implement `FilesystemFeeder` with unit tests against a temporary vault directory
- [ ] Step 13: Update `docs/tasks/0027-ios-extensions.md` so widgets and the Share Extension consume the shared store
- [ ] Step 14: Run all checks — `mise run lint:fix && mise run test` in `ios/`, `bb test` in `lambda/`
