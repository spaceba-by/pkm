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

**The manifest is built from S3, joined with DynamoDB.** A `generate_manifest` Lambda lists the bucket with `ListObjectsV2` (roughly 14 pages for 13k objects) to produce the authoritative inventory of markdown keys with their S3 ETag, size, and last-modified date, then joins DynamoDB `METADATA` items (title, classification, tags, created, modified, entities) where they exist. Notes the pipeline has not processed yet, or that it skips, still appear with synthesized metadata (title from filename, classification unset). DynamoDB cannot be the sole source: extraction skips non-markdown files, `_agent/`, and `.obsidian/`, and metadata records do not retain S3 ETags. The manifest is written gzipped to `_agent/manifest.json.gz` on a schedule and served by one new API endpoint.

**Manifest scope and reconciliation.** The manifest declares its scope explicitly: markdown files outside `_agent/` and `.obsidian/`. The mirror holds only documents in that scope, and absence-based deletion applies only within it. `_agent/` outputs (daily summaries, weekly reports, search summaries) continue to be fetched by the Insights screens through `getDocument` and are never written into the mirror. This removes the need for backend tombstones.

**Change detection does not rely on `modified`.** The backend `modified` value is unreliable as a change signal: date resolution prefers frontmatter dates (`extract_metadata` `resolve-dates`), so an Obsidian edit that leaves the frontmatter untouched does not advance it, and classification deliberately preserves it while changing metadata. The client therefore compares every manifest entry against its local record field by field (or by a per-row hash computed by the manifest generator): any metadata difference upserts the row, and an ETag difference re-fetches the body. `modified` is display data and a sort key, not a version. There is no separate GSI-based delta sync: `GET /documents` has no modification cutoff parameter and the Identity Pool role cannot query DynamoDB, so the manifest refresh is the only incremental mechanism. Manifest regeneration runs on a short schedule (aligned with the 5-minute rclone cadence) and can later be made event-driven by chaining it to pipeline completion.

**Keep `DocumentCacheService`, delete `CacheServiceProtocol`.** Neither abstraction is in use. `DocumentCacheService` is already wired to the Settings clear-cache action and is the SwiftData-backed one, so it evolves into the store. The generic key/value `CacheServiceProtocol`, `CacheKey`, and `MockCacheService` are removed.

**Shared package, App Group container.** The store, the content directory, the Spotlight indexer, and the App Intents move into a Swift package imported by every target (iOS app, widgets, intent extensions, macOS reader). App Intents are discovered per target, so iOS and macOS each compile their own copy from the shared package.

**Two feeders, one store.** A `VaultFeeder` protocol abstracts where document records and bodies come from:

- `S3Feeder` (iOS): manifest download and comparison, direct S3 `GetObject` for bodies with bounded concurrency, resumable across launches.
- `FilesystemFeeder` (macOS): reads markdown directly from the configured vault path and watches it for changes. Classification, tags, and entities still come from the manifest since they live in DynamoDB, not in the file.

The S3 key and the vault-relative file path are the same string, so document identity, Spotlight identifiers, and deep links are identical on both platforms.

**Stale-while-revalidate for reading; fresh fetch for editing.** S3 is the source of truth and Obsidian edits arrive via rclone outside the app. The list and detail views render from the mirror immediately and revalidate against the manifest's ETag. The editor always opens from a fresh `getDocument` call and sends that response's `modified` as `ifUnmodifiedSince`. This fixes the client-side token mismatch (today the editor sends the list's `modified`, not the fetched content's) but does not by itself guarantee no silent overwrite: `api_update_document` checks the DynamoDB timestamp and then performs an unconditional S3 write, so an external rclone edit can race the check, and `modified` is a weak version for the reasons above.

**Body-bound conflict detection (backend).** Since the mirror and manifest carry S3 ETags, `api_get_document` returns the ETag from the same `GetObject` response as the content it returns (never from a separate `HeadObject` or the manifest), the client sends it back as `ifMatch`, and `api_update_document` writes with S3's conditional `If-Match` so the check is atomic at the object level. `api_create_document` replaces its exists-then-put check with `If-None-Match: *`, which has the same race today. Clients built with this task always send `ifMatch`; `ifUnmodifiedSince` stays only as a fallback for older builds, and once those are retired the endpoint rejects updates without `ifMatch`. On a 409 the editor keeps the user's draft, fetches the current body, and offers to reapply or discard; it never drops typed text. The guarantee the task claims is scoped to this: once the ETag path is in place, a stale mirror or a concurrent S3-side write yields a 409, never an overwrite. An Obsidian edit still sitting on the Mac between rclone runs is outside it: bisync resolves that against the app's write with `--conflict-resolve newer` and keeps the loser as a renamed copy, so nothing is lost silently, but the app's edit can end up in the copy.

**Write-through on every mutation.** Classification updates, edits, creates, and deletes performed in-app update the local store, the body file, and the Spotlight index before anything else observes them. Widgets and intents are strictly read-only consumers.

**Pending local mutations survive stale manifests.** The manifest is generated on a schedule, so one can predate a successful in-app mutation; applying it unconditionally would delete a newly created note, resurrect a deleted one, or roll back a classification change. Each manifest carries a `generatedAt` timestamp taken before its S3 listing begins. Each write-through records a per-field pending state on the local row (`pendingBodyETag`, `pendingClassification`, `pendingDeleted`, each with the mutation time). Reconciliation skips a pending field until a manifest both postdates the mutation and reflects the expected value: the key present with the expected ETag for creates and edits (the write endpoints return the new ETag), the key absent for deletes, the classification equal to the expected value. Body and metadata confirm independently because the classification Lambda runs asynchronously after the S3 event, so a manifest can show a new body with old metadata. If a manifest postdates the mutation by more than a grace window (15 minutes) and still does not reflect it, the row is flagged for the user as unconfirmed rather than rolled back silently, and a fresh `getDocument` resolves it.

**Spotlight indexes full text by default.** Each `CSSearchableItem` carries title, tags, classification, and the body as `textContent`. Indexing is batched (500–1000 items) with Core Spotlight client state so a killed app resumes rather than restarts, and the reindex-all delegate callback replays from the mirror. Core Spotlight's index is on-device only and never leaves the device; the one exposure is that note snippets are visible in Spotlight results to anyone holding the unlocked device. A Settings toggle allows body indexing to be disabled, which matters if an app lock is ever added.

**Local search and pagination.** Once the mirror is populated, the Documents tab queries SwiftData directly for sort, classification filter, and tag filter, and keyword search runs locally against the mirrored bodies. Semantic search stays on the API. `GET /documents` and `GET /search?mode=keyword` become fallbacks, not the UI's data source.

### Sync Lifecycle

1. **First launch after sign-in.** Download manifest, batch-upsert metadata, mark all bodies as pending. Start body fetch with bounded concurrency (on the order of 16–32 in flight). Show progress in the Documents tab and Settings. The app is fully browsable during this phase; opening a pending note fetches it immediately and out of order.
2. **Foreground refresh.** Fetch manifest, compare every entry field-wise, upsert changed metadata, fetch bodies whose ETag differs, delete in-scope keys missing from the manifest.
3. **Background.** `BGAppRefreshTask` for manifest refreshes; `BGProcessingTask` for completing a large initial or resumed body sync.
4. **Push.** Existing push notification infrastructure can later nudge a manifest refresh when the pipeline finishes processing a change.
5. **Authentication loss.** Any transition to `signedOut`, whether from an explicit sign-out or from `transitionToSignedOut()` on token or session failure, cancels in-flight sync and indexing, then deletes the store, the content directory, and the Spotlight index. Sync and indexing work carry a generation token checked before every write so a late completion cannot repopulate the mirror after cleanup. Re-authentication starts a fresh initial sync.

### Cross-Platform Considerations

- **macOS has the vault on disk.** The sync app (`macos/`, bundle `by.spaceba.pkm.sync`) already keeps a local vault via rclone bisync. The macOS reader does not need the S3 feeder; the `FilesystemFeeder` reads files directly. macOS Spotlight already indexes plain markdown in the vault folder, so the custom index there is primarily for deep linking into the app.
- **Decision (2026-11-15): one macOS app, one process.** The reader is built into the existing sync app rather than shipped as a macOS destination of the iOS project. Rationale and consequences are in "macOS: One App" below; Task 0029 is restructured accordingly.
- **Entitlements and Info.plist keys live in `project.yml`.** XcodeGen overwrites entitlements files on every `generate`, and the targets use `GENERATE_INFOPLIST_FILE`. App Groups and keychain sharing go under `entitlements.properties`. The document URL scheme is Info.plist configuration, not an entitlement: declare `CFBundleURLTypes` under the target's `info.properties` in `project.yml`, or the deep link scheme will not be registered.
- **Unsandboxed macOS sync app.** The sync app is not sandboxed and runs rclone as a subprocess. Unsandboxed apps can still use App Groups, but the container path differs; resolve it via `containerURL(forSecurityApplicationGroupIdentifier:)` and never hardcode it.
- **Widgets are the strictest consumer.** They run in a separate process with tight memory and should not rely on network. They read the shared store and nothing else.

### macOS: One App

The existing sync app is unsandboxed with hardened runtime, menu-bar only (`LSUIElement`), distributed as a signed and notarized GitHub release with its own self-updater, launches at login, and reaches S3 through rclone's own AWS credentials rather than Cognito. Sync cannot run inside the App Sandbox without bundling rclone and reworking credentials and bisync state, so a combined app is necessarily unsandboxed, Developer ID signed, and never on the Mac App Store. That is accepted.

**Why one app.** Sync completion triggers the `FilesystemFeeder` rescan and Spotlight update directly in-process with no App Group coordination, FSEvents bridging, or XPC. Sync conflicts (the existing `ConflictService` and `DiffService`) surface in the reader UI next to the note. There is one install, one update, and one login item, so the thing that syncs and the thing that reads can never skew.

**Identity.** The bundle identifier stays `by.spaceba.pkm.sync`; the self-updater matches installed copies by bundle, and renaming would orphan every installed copy from the `macos-v*` release chain. The display name becomes "Sal" (the iOS app's display name) and the Dock and menu bar represent one product. The `macos/` project imports the shared package and gains the reader features; the iOS project stays iOS-only.

**Risks and required mitigations.** These are acceptance criteria for Task 0029, not optional polish:

- *Lifecycle.* The app is no longer a pure menu bar item. Activation policy switches to `.regular` (Dock icon) while a window is open and back to `.accessory` when the last window closes. Closing windows never stops sync. Cmd-Q presents a confirmation stating that quitting stops sync, with a "Close windows instead" default.
- *Crash coupling.* Sync is the critical path for the whole system and a crash in the reader (graph rendering, a 13k-row list) would take the scheduler down with it. The scheduler and `SyncService` run on an isolated actor with no dependency on UI state, and reader view models never hold references into sync internals. If crash coupling bites in practice, the documented escape hatch is one bundle with two processes: sync as an embedded login-item helper registered via `SMAppService`, with XPC for status and conflicts.
- *Self-update.* The updater replaces the bundle and relaunches. It must defer while any editor has unsaved changes or a sync phase is mid-run, and the relaunch must restore open windows.
- *Credentials.* rclone keeps using its configured IAM keys; the reader uses Cognito through Amplify. Both live in one binary. Unifying them (feeding Identity Pool credentials to rclone via `env_auth`) would require S3 write permissions on the authenticated role, which this task deliberately withholds, so unification is out of scope.
- *CI.* The macOS build grows from roughly a minute toward the iOS build time; apply the same DerivedData and SPM caching the iOS workflows use.

**Shared identifiers (proposed defaults, confirm in Step 1).**

- App Group: `group.by.spaceba.pkm` on both platforms. On macOS the unsandboxed app and its future widget and intent extensions resolve the container via `containerURL(forSecurityApplicationGroupIdentifier:)`.
- Keychain access group: `$(AppIdentifierPrefix)by.spaceba.pkm.shared`, passed to Amplify's configuration so extensions share the Cognito session.

### Auth and Navigation Prerequisites

- **Amplify bootstrap must leave `RootView`.** `AuthService.configure()` is only called from `RootView.task`. An App Intent running in the background never renders `RootView`, so the first API or S3 call would fail. Move configuration to app init or a lazy shared initializer.
- **Background credential access must be verified, not assumed.** Production auth delegates credential storage to `AWSCognitoAuthPlugin`; the app's own `KeychainService` wrapper (which sets `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) is unused and says nothing about Amplify's items. Prerequisites to confirm before building intents or background sync: Amplify's keychain accessibility class permits access after first unlock without the device being unlocked; `amplifyconfiguration.json` is bundled in every target that authenticates (intent and widget extensions load from their own bundle, not the app's); and Amplify is configured with a shared keychain access group so extensions see the same session. Verify with an authenticated background-launch test (device locked after first unlock) as part of Step 14.
- **S3 client.** Amplify is already a dependency and `AWSAuthCognitoSession` exposes Identity Pool AWS credentials. Prefer the Amplify `AWSS3StoragePlugin` with explicit `StoragePath` values so no new SDK is introduced; fall back to a small SigV4 signer over `URLSession` if the plugin's path semantics get in the way.
- **A document deep link does not exist.** `MainTabView.handleDeepLink` only switches tabs. Spotlight results and Siri "open note" both need a route to a specific document by key: a URL scheme in `project.yml` and a navigation path into the document stack.
- **Editor conflict token.** `DocumentEditorViewModel` sends `ifUnmodifiedSince` from the list's metadata rather than from the fetched content's metadata. This is a latent mismatch today and a mirror makes it worse. The editor must use the `modified` value returned alongside the content it is editing.

### IAM Change

Add to the `cognito_authenticated` role policy in `terraform/cognito.tf`:

- `s3:GetObject` on `arn:aws:s3:::<vault-bucket>/*`
- Optionally `s3:ListBucket` on the bucket, used only as a reconciliation fallback; the manifest is the primary source of the key set.

No write permissions. Every object in the bucket is intentionally readable by any signed-in user, through the API and directly from S3 alike; there is no per-prefix or per-group read restriction.

That makes the set of users who can sign in the whole read boundary. The User Pool has no `admin_create_user_config`, so `allow_admin_create_user_only` defaults to false and anyone holding the (non-secret) app client ID can call `SignUp` and then read the vault. Set `allow_admin_create_user_only = true` so only admin-created users can sign in.

The bucket uses SSE-S3 (`AES256`), so no KMS grant is needed. The `generate_manifest` Lambda's execution role needs `s3:ListBucket` and `s3:GetObject` on the bucket and `dynamodb:Query` on the metadata table; `api_update_document` and `api_create_document` need no new permissions for conditional writes.

## Relevant Files

### New Files

- `shared/PKMCore/` (or equivalent Swift package) — Shared package containing models, networking, store, feeders, indexer, and intents
- `shared/PKMCore/Sources/Store/VaultStore.swift` — Evolved `DocumentCacheService` with background context, batched upserts, ETag and sync state
- `shared/PKMCore/Sources/Store/VaultContentDirectory.swift` — Reads and writes body files under the App Group container keyed by vault-relative path
- `shared/PKMCore/Sources/Store/VaultFeeder.swift` — Feeder protocol
- `shared/PKMCore/Sources/Store/S3Feeder.swift` — Manifest comparison with pending-mutation guard, direct S3 body fetch with bounded concurrency and resume
- `shared/PKMCore/Sources/Store/FilesystemFeeder.swift` — macOS vault directory reader; rescans on sync completion in-process and watches for Obsidian edits between runs
- `shared/PKMCore/Sources/Store/LocalSearch.swift` — Local keyword search over mirrored bodies
- `shared/PKMCore/Sources/Spotlight/SpotlightIndexer.swift` — Batched full-text Core Spotlight indexing with client state
- `shared/PKMCore/Sources/Intents/DocumentEntity.swift` — `AppEntity` and `EntityQuery` backed by the store
- `shared/PKMCore/Sources/Intents/OpenDocumentIntent.swift`, `SearchDocumentsIntent.swift`, `ReadDocumentIntent.swift` — App Intents
- `lambda/functions/generate_manifest/handler.clj` — Lists the bucket for the in-scope markdown inventory with ETags, joins DynamoDB metadata, writes `_agent/manifest.json.gz` with an explicit scope declaration and per-row hash
- `lambda/functions/api_get_manifest/handler.clj` — Serves the manifest (or a presigned URL to it)
- `terraform/manifest.tf` — Manifest Lambda, schedule, and API route

### Modified Files

- `terraform/cognito.tf` — Read-only S3 permissions on the authenticated Identity Pool role
- `lambda/functions/api_get_document/handler.clj` — Return the S3 ETag alongside content
- `lambda/functions/api_update_document/handler.clj` — Accept `ifMatch` and write with S3 conditional `If-Match`; keep `ifUnmodifiedSince` as fallback; return the new ETag
- `lambda/functions/api_create_document/handler.clj` — Write with `If-None-Match: *` instead of exists-then-put; return the new ETag so the client can record pending state
- `lambda/shared/aws/s3.clj` — `put-object` variant with `If-Match`; `get-object` variant returning ETag
- `ios/PKMReader/Core/Cache/DocumentCacheService.swift` — Moved to shared package and rewritten as `VaultStore`
- `ios/PKMReader/Core/Cache/CachedDocument.swift` — Moved to shared package; schema extended with ETag, body state, Spotlight state
- `ios/PKMReader/Features/DocumentList/DocumentListViewModel.swift` — Read from store, local pagination, filters, and keyword search; trigger sync; show sync progress
- `ios/PKMReader/Features/DocumentDetail/DocumentDetailViewModel.swift` — Render from mirror, revalidate against manifest state
- `ios/PKMReader/Features/Editor/DocumentEditorViewModel.swift` — Fresh `getDocument` before editing; use its `modified` for `ifUnmodifiedSince`
- `ios/PKMReader/App/PKMReaderApp.swift` — Amplify bootstrap, URL scheme handling, background task registration
- `ios/PKMReader/App/MainTabView.swift` — Document deep link route
- `ios/PKMReader/Core/Auth/AuthService.swift` — Lazy shared configuration; AWS credential access; publish auth-loss events that trigger mirror and index cleanup for both explicit sign-out and `transitionToSignedOut()`
- `ios/PKMReader/Features/Settings/SettingsViewModel.swift` — Clear-cache wiring follows the moved store; body indexing toggle; sync status
- `ios/project.yml` — Shared package dependency, Amplify Storage plugin, App Group and keychain group (`entitlements.properties`), `CFBundleURLTypes` (`info.properties`), background modes
- `macos/project.yml` — Shared package dependency, App Group and keychain group, `LSUIElement` removed in favor of runtime activation policy, `CFBundleURLTypes`, display name "Sal"
- `macos/PKMSync/App/PKMSyncApp.swift` — Adds `WindowGroup` reader scenes alongside the existing `MenuBarExtra`; activation policy switching (reader UI itself lands in Task 0029)
- `docs/tasks/0027-ios-extensions.md` — Spotlight indexing now provided by this task; widgets read the shared store

### Files to Delete

- `ios/PKMReader/Core/Cache/CacheServiceProtocol.swift` — Unused abstraction
- `ios/PKMReaderTests/Mocks/MockCacheService.swift` — Mock for the removed protocol

## Acceptance Criteria

- [ ] `CacheServiceProtocol`, `CacheKey`, and `MockCacheService` removed; `DocumentCacheService` lineage is the single store
- [ ] Store, content directory, feeders, indexer, and intents live in a shared Swift package imported by the iOS app target
- [ ] SwiftData store and content directory are located in an App Group container
- [ ] Identity Pool authenticated role has read-only `s3:GetObject` on the vault bucket and no write permissions
- [ ] User Pool self sign-up disabled (`allow_admin_create_user_only = true`)
- [ ] Manifest Lambda builds the inventory from `ListObjectsV2`, joins DynamoDB metadata, synthesizes metadata for unprocessed notes, and writes `_agent/manifest.json.gz` with scope declaration, ETags, and per-row hashes; a new API endpoint serves it
- [ ] `_agent/` documents are never written to the mirror; Insights screens continue to fetch them via `getDocument`
- [ ] Initial sync completes with one manifest download, batched metadata upserts on a background context, and direct S3 body fetches with bounded concurrency
- [ ] Body sync is resumable across app termination and completes under `BGProcessingTask` when the app is backgrounded
- [ ] Sync progress is visible while bodies are still arriving, and the app is browsable throughout
- [ ] In-scope documents absent from the manifest are removed from the store, the content directory, and the Spotlight index; out-of-scope keys are never evicted by reconciliation
- [ ] Metadata is upserted on any field difference regardless of `modified` ordering (covers frontmatter-dated edits and classification changes)
- [ ] Bodies are re-fetched when the manifest ETag differs from the locally stored ETag
- [ ] Manifest refresh runs on foreground and under `BGAppRefreshTask`; no other incremental sync path exists
- [ ] Documents list renders from the store with local sort, classification, tag filtering, and local keyword search
- [ ] Document detail renders mirrored content immediately with no network call when the body is present
- [ ] Editor fetches fresh content before editing and sends the matching `modified` as `ifUnmodifiedSince` and the ETag as `ifMatch`
- [ ] `api_update_document` performs an S3 conditional write on `If-Match` and returns 409 on mismatch; `api_create_document` writes with `If-None-Match: *`
- [ ] On a 409 the editor preserves the draft and offers reload and reapply
- [ ] Classification updates, edits, creates, and deletes write through to the store, body file, and Spotlight index
- [ ] Spotlight indexes title, tags, classification, and full body text in batches with client state; reindex-all callback implemented
- [ ] Settings toggle disables body indexing and triggers a reindex without bodies
- [ ] Tapping a Spotlight result opens the document via a URL-scheme deep link
- [ ] App Intents: open document, search documents, read document; entity query and read resolve from the mirror without network
- [ ] Intents work when the app is launched in the background (Amplify configured outside `RootView`); verified by an authenticated background-launch test with the device locked after first unlock
- [ ] Amplify keychain accessibility and shared access group confirmed; `amplifyconfiguration.json` bundled in every authenticating target
- [ ] Any transition to signed-out (explicit sign-out or token/session failure) cancels in-flight sync and indexing and clears the store, the content directory, and the Spotlight index; a late-completing sync cannot repopulate data after cleanup
- [ ] Manifests carry `generatedAt`; write-through records per-field pending state; reconciliation never rolls back a pending create, delete, edit, or classification change until a postdating manifest confirms it; unconfirmed mutations past the grace window are surfaced, not reverted
- [ ] `FilesystemFeeder` protocol conformance exists and is covered by unit tests; it is triggered in-process by `SyncService` completion (full macOS reader UI lands with Task 0029)
- [ ] Entitlements declared under `entitlements.properties` and `CFBundleURLTypes` under `info.properties` in `project.yml`
- [ ] All existing iOS and Lambda tests continue to pass; `terraform plan` shows only the intended IAM and manifest additions

## Implementation Steps

- [ ] Step 1: Confirm the proposed App Group (`group.by.spaceba.pkm`) and keychain access group (`$(AppIdentifierPrefix)by.spaceba.pkm.shared`); the one-app macOS decision is recorded above (2026-11-15)
- [ ] Step 2: Create the shared Swift package; move models, networking, `DocumentCacheService`, and `CachedDocument` into it; delete `CacheServiceProtocol` and `MockCacheService`
- [ ] Step 3: Rewrite the store: App Group container location, background `ModelContext`, batched upserts keyed on a single fetch of existing identifiers, bulk delete of missing keys, ETag and body state columns; add `VaultContentDirectory`
- [ ] Step 4: Backend: `generate_manifest` Lambda on an EventBridge schedule (S3 inventory joined with DynamoDB, scope declaration, ETags, row hashes) writing `_agent/manifest.json.gz`; `api_get_manifest` endpoint; Terraform
- [ ] Step 4b: Backend: return ETag from `api_get_document`; add `ifMatch` with S3 conditional `If-Match` to `api_update_document`
- [ ] Step 5: Terraform: read-only S3 policy on the Identity Pool authenticated role; disable User Pool self sign-up
- [ ] Step 6: iOS S3 access: Amplify Storage plugin (or SigV4 fallback) reading objects with Identity Pool credentials
- [ ] Step 7: Implement `VaultFeeder` protocol and `S3Feeder` (field-wise manifest comparison honoring pending-mutation state, scoped deletion, ETag-driven body fetch with bounded concurrency, resume state, progress reporting)
- [ ] Step 8: Register `BGAppRefreshTask` and `BGProcessingTask`; wire foreground refresh
- [ ] Step 9: Wire `DocumentListViewModel` to the store with local pagination, filters, keyword search, and sync progress
- [ ] Step 10: Wire `DocumentDetailViewModel` to the mirror; fix editor to fetch fresh and send its `modified` and ETag
- [ ] Step 11: Write-through from all mutation paths with per-field pending state and manifest confirmation; cleanup on any signed-out transition with cancellation and generation token
- [ ] Step 12: Move Amplify bootstrap out of `RootView`; verify Amplify keychain accessibility and configure shared access group; add `CFBundleURLTypes` and document deep link route
- [ ] Step 13: Implement `SpotlightIndexer` with full-text items, batching, client state, reindex-all callback, and the body indexing toggle
- [ ] Step 14: Implement `DocumentEntity`, `EntityQuery`, and the open / search / read intents; verify background launch
- [ ] Step 15: Implement `FilesystemFeeder` with unit tests against a temporary vault directory
- [ ] Step 16: Update `docs/tasks/0027-ios-extensions.md` so widgets and the Share Extension consume the shared store
- [ ] Step 17: Run all checks — `mise run lint:fix && mise run test` in `ios/`, `bb test` in `lambda/`, `terraform plan`
