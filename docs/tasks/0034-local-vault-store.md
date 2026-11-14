# Task 0034: Local Vault Mirror, App Intents & Spotlight

**Status**: Planned

## Specifications

Build a shared, on-device mirror of the vault (all document metadata and all markdown content) that serves three consumers: instant note loading in the iOS app, Siri / Shortcuts access via App Intents, and full-text system-wide Spotlight search. The mirror is designed from the start to be fed from two sources (S3 plus the backend manifest on iOS, the local vault filesystem on macOS) and to be read by multiple processes (the main app, widgets, and intent extensions) across iOS, iPadOS, and macOS.

### Problem

Every note tap in the iOS app is a full network round trip. `DocumentDetailViewModel` always calls `getDocument` because list responses never include content, so each open chains an Amplify token fetch, an API Gateway JWT check, a Babashka Lambda cold start, and sequential DynamoDB and S3 reads. The existing `DocumentCacheService` (SwiftData, 1-hour TTL) is not wired into any view model; only the Settings "clear cache" action and the performance tests reference it.

App Intents and Spotlight both require fast, local answers. Siri entity resolution must return in well under a second, Siri read-aloud needs the note body without a network fetch, and full-text Spotlight search requires every body to be indexed. None of this is achievable on top of per-request Lambda calls.

### Vault Scale

The vault holds roughly 13,000 S3 objects (as of 2026-11-14), including attachments and `_agent/` outputs. Metadata for that many documents is 10–15 MB; content at a few KB per note is tens of MB. Both fit comfortably on device and within Core Spotlight limits. The constraint is the initial sync path, not storage:

| Path | Requests for a full sync | Verdict |
|---|---|---|
| Metadata via `GET /documents`, 100 per page | ~131 Lambda calls | Tolerable once, slow on first launch |
| Content via `GET /documents/{key}` | ~13,000 Lambda calls | Not acceptable |
| Metadata via a manifest file | 1 download | Target design |
| Content via direct S3 `GetObject` with Identity Pool credentials | ~13,000 S3 requests, parallel, no Lambda | Target design |

### Design Decisions

**Mirror everything: metadata and content.** Full-text Spotlight search is a priority, and Siri read-aloud needs bodies locally. Partial content caching would make Spotlight inconsistent (a miss could mean "not in the vault" or "not fetched yet"), so all markdown content is mirrored. The app is usable as soon as metadata has synced; content streams in behind it with visible progress.

**Content is fetched directly from S3, not through Lambda.** The Cognito Identity Pool's authenticated role is granted read-only `s3:GetObject` on the vault bucket (today it can only invoke API Gateway, see `terraform/cognito.tf`). The iOS client obtains AWS credentials from the existing Amplify session and reads objects directly, the same way rclone does on macOS. This removes ~13k Lambda invocations from the initial sync and lets S3 absorb the parallelism. Writes stay on the API: create, update, delete, and classification changes continue to go through the admin-gated Lambda endpoints so the processing pipeline and authorization checks are unchanged. The API remains the single write boundary; S3 becomes a second read path.

**Content lives as files, not as rows.** Bodies are written to a local vault directory inside the App Group container, mirroring the S3 key as the vault-relative path. SwiftData holds metadata, the S3 ETag of the locally stored body, sync state, and Spotlight state. This keeps tens of MB of text out of SQLite, means iOS and macOS converge on the same shape (a directory of markdown plus a metadata store), and leaves the door open to exposing the mirror through the Files app later.

**Manifest drives metadata, deletions, and content change detection.** The pipeline maintains a gzipped JSON manifest of every document's metadata (key, title, classification, tags, created, modified, S3 ETag) under `_agent/manifest.json.gz`, regenerated on a schedule or on each metadata write. One new API endpoint serves it. The client diffs the manifest against the local store: new or newer entries are upserted and their bodies fetched when the ETag differs from the local copy; any local key absent from the manifest is deleted locally along with its body and Spotlight item. This removes the need for backend tombstones. Delta sync via the `all-documents-modified-index` GSI remains useful between manifest refreshes but is not load-bearing for correctness.

**Keep `DocumentCacheService`, delete `CacheServiceProtocol`.** Neither abstraction is in use. `DocumentCacheService` is already wired to the Settings clear-cache action and is the SwiftData-backed one, so it evolves into the store. The generic key/value `CacheServiceProtocol`, `CacheKey`, and `MockCacheService` are removed.

**Shared package, App Group container.** The store, the content directory, the Spotlight indexer, and the App Intents move into a Swift package imported by every target (iOS app, widgets, intent extensions, macOS reader). App Intents are discovered per target, so iOS and macOS each compile their own copy from the shared package.

**Two feeders, one store.** A `VaultFeeder` protocol abstracts where document records and bodies come from:

- `S3Feeder` (iOS): manifest download, delta sync via modified GSI, direct S3 `GetObject` for bodies with bounded concurrency, resumable across launches.
- `FilesystemFeeder` (macOS): reads markdown directly from the configured vault path and watches it for changes. Classification, tags, and entities still come from the manifest since they live in DynamoDB, not in the file.

The S3 key and the vault-relative file path are the same string, so document identity, Spotlight identifiers, and deep links are identical on both platforms.

**Stale-while-revalidate for reading; fresh fetch for editing.** S3 is the source of truth and Obsidian edits arrive via rclone outside the app. The list and detail views render from the mirror immediately and revalidate against the manifest's `modified` and ETag. The editor always opens from a fresh `getDocument` call and sends that response's `modified` as `ifUnmodifiedSince`, so a stale mirror can never cause a silent overwrite.

**Write-through on every mutation.** Classification updates, edits, creates, and deletes performed in-app update the local store, the body file, and the Spotlight index before anything else observes them. Widgets and intents are strictly read-only consumers.

**Spotlight indexes full text by default.** Each `CSSearchableItem` carries title, tags, classification, and the body as `textContent`. Indexing is batched (500–1000 items) with Core Spotlight client state so a killed app resumes rather than restarts, and the reindex-all delegate callback replays from the mirror. Core Spotlight's index is on-device only and never leaves the device; the one exposure is that note snippets are visible in Spotlight results to anyone holding the unlocked device. A Settings toggle allows body indexing to be disabled, which matters if an app lock is ever added.

**Local search and pagination.** Once the mirror is populated, the Documents tab queries SwiftData directly for sort, classification filter, and tag filter, and keyword search runs locally against the mirrored bodies. Semantic search stays on the API. `GET /documents` and `GET /search?mode=keyword` become fallbacks, not the UI's data source.

### Sync Lifecycle

1. **First launch after sign-in.** Download manifest, batch-upsert metadata, mark all bodies as pending. Start body fetch with bounded concurrency (on the order of 16–32 in flight). Show progress in the Documents tab and Settings. The app is fully browsable during this phase; opening a pending note fetches it immediately and out of order.
2. **Foreground refresh.** Fetch manifest, diff, fetch changed bodies, delete missing keys.
3. **Background.** `BGAppRefreshTask` for manifest deltas; `BGProcessingTask` for completing a large initial or resumed body sync.
4. **Push.** Existing push notification infrastructure can later nudge a manifest refresh when the pipeline finishes processing a change.
5. **Sign-out.** Delete the store, the content directory, and the Spotlight index.

### Cross-Platform Considerations

- **macOS has the vault on disk.** The sync app (`macos/`, bundle `by.spaceba.pkm.sync`) already keeps a local vault via rclone bisync. A macOS reader does not need the S3 feeder; the `FilesystemFeeder` reads files directly. macOS Spotlight already indexes plain markdown in the vault folder, so the custom index there is primarily for deep linking into the app.
- **One app or two on macOS.** The sync app and the planned reader (Task 0029) are separate bundle IDs today. If they stay separate, the App Group and keychain access group must span all targets, and the sync app becomes the natural filesystem feeder. This decision should be made before the shared package is created.
- **Entitlements live in `project.yml`.** XcodeGen overwrites entitlements files on every `generate`. App Groups, keychain sharing, and URL types must be declared under `entitlements.properties` in each project's `project.yml`.
- **Unsandboxed macOS sync app.** The sync app is not sandboxed and runs rclone as a subprocess. Unsandboxed apps can still use App Groups, but the container path differs; resolve it via `containerURL(forSecurityApplicationGroupIdentifier:)` and never hardcode it.
- **Widgets are the strictest consumer.** They run in a separate process with tight memory and should not rely on network. They read the shared store and nothing else.

### Auth and Navigation Prerequisites

- **Amplify bootstrap must leave `RootView`.** `AuthService.configure()` is only called from `RootView.task`. An App Intent running in the background never renders `RootView`, so the first API or S3 call would fail. Move configuration to app init or a lazy shared initializer. Keychain items already use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, which is correct for background intents and background sync.
- **S3 client.** Amplify is already a dependency and `AWSAuthCognitoSession` exposes Identity Pool AWS credentials. Prefer the Amplify `AWSS3StoragePlugin` with explicit `StoragePath` values so no new SDK is introduced; fall back to a small SigV4 signer over `URLSession` if the plugin's path semantics get in the way.
- **A document deep link does not exist.** `MainTabView.handleDeepLink` only switches tabs. Spotlight results and Siri "open note" both need a route to a specific document by key: a URL scheme in `project.yml` and a navigation path into the document stack.
- **Editor conflict token.** `DocumentEditorViewModel` sends `ifUnmodifiedSince` from the list's metadata rather than from the fetched content's metadata. This is a latent mismatch today and a mirror makes it worse. The editor must use the `modified` value returned alongside the content it is editing.

### IAM Change

Add to the `cognito_authenticated` role policy in `terraform/cognito.tf`:

- `s3:GetObject` on `arn:aws:s3:::<vault-bucket>/*`
- Optionally `s3:ListBucket` on the bucket, scoped to be used only as a reconciliation fallback; the manifest is the primary source of the key set.

No write permissions. Both the `admin` and `reader` Cognito groups can already read every document through the API, so read-only S3 access does not widen what either group can see.

## Relevant Files

### New Files

- `shared/PKMCore/` (or equivalent Swift package) — Shared package containing models, networking, store, feeders, indexer, and intents
- `shared/PKMCore/Sources/Store/VaultStore.swift` — Evolved `DocumentCacheService` with background context, batched upserts, ETag and sync state
- `shared/PKMCore/Sources/Store/VaultContentDirectory.swift` — Reads and writes body files under the App Group container keyed by vault-relative path
- `shared/PKMCore/Sources/Store/VaultFeeder.swift` — Feeder protocol
- `shared/PKMCore/Sources/Store/S3Feeder.swift` — Manifest diff, delta sync via modified GSI, direct S3 body fetch with bounded concurrency and resume
- `shared/PKMCore/Sources/Store/FilesystemFeeder.swift` — macOS vault directory reader and watcher
- `shared/PKMCore/Sources/Store/LocalSearch.swift` — Local keyword search over mirrored bodies
- `shared/PKMCore/Sources/Spotlight/SpotlightIndexer.swift` — Batched full-text Core Spotlight indexing with client state
- `shared/PKMCore/Sources/Intents/DocumentEntity.swift` — `AppEntity` and `EntityQuery` backed by the store
- `shared/PKMCore/Sources/Intents/OpenDocumentIntent.swift`, `SearchDocumentsIntent.swift`, `ReadDocumentIntent.swift` — App Intents
- `lambda/functions/generate_manifest/handler.clj` — Builds `_agent/manifest.json.gz` (including S3 ETags) from the modified GSI
- `lambda/functions/api_get_manifest/handler.clj` — Serves the manifest (or a presigned URL to it)
- `terraform/manifest.tf` — Manifest Lambda, schedule, and API route

### Modified Files

- `terraform/cognito.tf` — Read-only S3 permissions on the authenticated Identity Pool role
- `ios/PKMReader/Core/Cache/DocumentCacheService.swift` — Moved to shared package and rewritten as `VaultStore`
- `ios/PKMReader/Core/Cache/CachedDocument.swift` — Moved to shared package; schema extended with ETag, body state, Spotlight state
- `ios/PKMReader/Features/DocumentList/DocumentListViewModel.swift` — Read from store, local pagination, filters, and keyword search; trigger sync; show sync progress
- `ios/PKMReader/Features/DocumentDetail/DocumentDetailViewModel.swift` — Render from mirror, revalidate against manifest state
- `ios/PKMReader/Features/Editor/DocumentEditorViewModel.swift` — Fresh `getDocument` before editing; use its `modified` for `ifUnmodifiedSince`
- `ios/PKMReader/App/PKMReaderApp.swift` — Amplify bootstrap, URL scheme handling, background task registration
- `ios/PKMReader/App/MainTabView.swift` — Document deep link route
- `ios/PKMReader/Core/Auth/AuthService.swift` — Lazy shared configuration; AWS credential access; clear mirror and index on sign-out
- `ios/PKMReader/Features/Settings/SettingsViewModel.swift` — Clear-cache wiring follows the moved store; body indexing toggle; sync status
- `ios/project.yml` — Shared package dependency, Amplify Storage plugin, App Group, keychain group, URL types, background modes
- `macos/project.yml` — App Group and keychain group (if sync app feeds the store)
- `docs/tasks/0027-ios-extensions.md` — Spotlight indexing now provided by this task; widgets read the shared store

### Files to Delete

- `ios/PKMReader/Core/Cache/CacheServiceProtocol.swift` — Unused abstraction
- `ios/PKMReaderTests/Mocks/MockCacheService.swift` — Mock for the removed protocol

## Acceptance Criteria

- [ ] `CacheServiceProtocol`, `CacheKey`, and `MockCacheService` removed; `DocumentCacheService` lineage is the single store
- [ ] Store, content directory, feeders, indexer, and intents live in a shared Swift package imported by the iOS app target
- [ ] SwiftData store and content directory are located in an App Group container
- [ ] Identity Pool authenticated role has read-only `s3:GetObject` on the vault bucket and no write permissions
- [ ] Manifest Lambda produces `_agent/manifest.json.gz` including S3 ETags, and a new API endpoint serves it
- [ ] Initial sync completes with one manifest download, batched metadata upserts on a background context, and direct S3 body fetches with bounded concurrency
- [ ] Body sync is resumable across app termination and completes under `BGProcessingTask` when the app is backgrounded
- [ ] Sync progress is visible while bodies are still arriving, and the app is browsable throughout
- [ ] Documents absent from the manifest are removed from the store, the content directory, and the Spotlight index
- [ ] Bodies are re-fetched when the manifest ETag differs from the locally stored ETag
- [ ] Delta sync via modified GSI runs on foreground and under `BGAppRefreshTask`
- [ ] Documents list renders from the store with local sort, classification, tag filtering, and local keyword search
- [ ] Document detail renders mirrored content immediately with no network call when the body is present
- [ ] Editor fetches fresh content before editing and sends the matching `modified` as `ifUnmodifiedSince`
- [ ] Classification updates, edits, creates, and deletes write through to the store, body file, and Spotlight index
- [ ] Spotlight indexes title, tags, classification, and full body text in batches with client state; reindex-all callback implemented
- [ ] Settings toggle disables body indexing and triggers a reindex without bodies
- [ ] Tapping a Spotlight result opens the document via a URL-scheme deep link
- [ ] App Intents: open document, search documents, read document; entity query and read resolve from the mirror without network
- [ ] Intents work when the app is launched in the background (Amplify configured outside `RootView`)
- [ ] Sign-out clears the store, the content directory, and the Spotlight index
- [ ] `FilesystemFeeder` protocol conformance exists and is covered by unit tests (full macOS reader integration lands with Task 0029)
- [ ] Entitlements declared in `project.yml`, not in the generated entitlements file
- [ ] All existing iOS and Lambda tests continue to pass; `terraform plan` shows only the intended IAM and manifest additions

## Implementation Steps

- [ ] Step 1: Decide App Group identifier, keychain access group, and whether the macOS reader and sync app share a bundle; record in this document
- [ ] Step 2: Create the shared Swift package; move models, networking, `DocumentCacheService`, and `CachedDocument` into it; delete `CacheServiceProtocol` and `MockCacheService`
- [ ] Step 3: Rewrite the store: App Group container location, background `ModelContext`, batched upserts keyed on a single fetch of existing identifiers, bulk delete of missing keys, ETag and body state columns; add `VaultContentDirectory`
- [ ] Step 4: Backend: `generate_manifest` Lambda on an EventBridge schedule writing `_agent/manifest.json.gz` with ETags; `api_get_manifest` endpoint; Terraform
- [ ] Step 5: Terraform: read-only S3 policy on the Identity Pool authenticated role
- [ ] Step 6: iOS S3 access: Amplify Storage plugin (or SigV4 fallback) reading objects with Identity Pool credentials
- [ ] Step 7: Implement `VaultFeeder` protocol and `S3Feeder` (manifest diff, delta sync, bounded-concurrency body fetch, resume state, progress reporting)
- [ ] Step 8: Register `BGAppRefreshTask` and `BGProcessingTask`; wire foreground refresh
- [ ] Step 9: Wire `DocumentListViewModel` to the store with local pagination, filters, keyword search, and sync progress
- [ ] Step 10: Wire `DocumentDetailViewModel` to the mirror; fix editor to fetch fresh and use its `modified`
- [ ] Step 11: Write-through from all mutation paths; clear store, content directory, and index on sign-out
- [ ] Step 12: Move Amplify bootstrap out of `RootView`; add URL scheme and document deep link route
- [ ] Step 13: Implement `SpotlightIndexer` with full-text items, batching, client state, reindex-all callback, and the body indexing toggle
- [ ] Step 14: Implement `DocumentEntity`, `EntityQuery`, and the open / search / read intents; verify background launch
- [ ] Step 15: Implement `FilesystemFeeder` with unit tests against a temporary vault directory
- [ ] Step 16: Update `docs/tasks/0027-ios-extensions.md` so widgets and the Share Extension consume the shared store
- [ ] Step 17: Run all checks — `mise run lint:fix && mise run test` in `ios/`, `bb test` in `lambda/`, `terraform plan`
