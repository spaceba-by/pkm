# Task 0018: iOS UI Improvements

**Status**: Complete

## Specifications

A collection of iOS rendering, display, and data loading improvements. The app currently uses the Textual library (`StructuredText`) for markdown rendering. These improvements address gaps where content isn't rendered optimally and where the document list doesn't load the expected number of results.

### Improve YAML Front Matter Rendering

Documents from the Obsidian vault include YAML front matter blocks (delimited by `---`) at the top. Currently, the full markdown content including front matter is passed directly to `StructuredText`, which renders the YAML block as raw text. This is redundant since the metadata (classification, tags, entities, dates) is already displayed in the document detail header.

The fix should strip YAML front matter from the content before rendering. Detection should be done directly on the content string by matching `---` delimiters at the start (regex approach), rather than relying on the `hasFrontmatter` flag on `DocumentMetadata`. The flag is not reliably preserved through the cache layer: `CachedDocument.toDocument()` always sets `hasFrontmatter: false`, so any document loaded from cache would incorrectly skip stripping even when front matter is present in the content.

### Render Checkboxes

Obsidian-style markdown uses `- [ ]` and `- [x]` syntax for task lists / checkboxes. These should render as visual checkboxes (unchecked and checked respectively) rather than raw text. The checkboxes should be read-only since the app currently has no write support.

### Handle Internal Markdown Links

Obsidian uses `[[wikilink]]` syntax for internal links between documents. These should be rendered as tappable links that navigate to the linked document within the app (if it exists in the vault), rather than displaying the raw `[[...]]` bracket syntax. Standard markdown links (`[text](url)`) to external URLs should also open correctly.

### Fix Unfiltered Document List Returning Too Few Results

The main Documents view with no classification filter shows only ~5 documents, while filtered views (e.g., by classification) return many more. The `api_list_documents` Lambda uses a DynamoDB `Scan` with a filter expression (`SK = :sk` where SK is `METADATA`) and a `limit` parameter. The DynamoDB `Scan` limit caps items **examined**, not items **returned** — so when the table contains many non-METADATA items (tags, entities, classification index entries), a scan with limit=50 may examine 50 items but only return a few that match the filter. Filtered views likely use a GSI query which doesn't have this problem.

The fix should ensure the unfiltered document list reliably returns the requested number of documents, either by paginating through scan results until enough matches are collected, or by using an index-based query instead of a scan.

## Relevant Files

- `ios/PKMReader/Features/DocumentDetail/DocumentDetailView.swift` - Document content rendering with `StructuredText`
- `ios/PKMReader/Features/DocumentDetail/DocumentDetailViewModel.swift` - Content loading and state management
- `ios/PKMReader/Models/Document.swift` - `DocumentMetadata.hasFrontmatter` flag
- `lambda/shared/markdown/utils.clj` - Backend front matter extraction regex and wikilink parsing (reference)
- `lambda/functions/api_list_documents/handler.clj` - Document list API handler with DynamoDB scan
- `lambda/shared/aws/dynamodb.clj` - DynamoDB scan/query operations
- `ios/PKMReader/Features/DocumentList/DocumentListViewModel.swift` - Document list view model with pagination

## Acceptance Criteria

- [x] YAML front matter block is not visible in rendered document content
- [x] Documents without front matter continue to render correctly
- [x] Markdown checkboxes (`- [ ]` and `- [x]`) render as visual checkbox indicators
- [x] Checked items are visually distinct from unchecked items
- [x] Checkboxes are read-only (no toggle interaction)
- [x] Internal `[[wikilinks]]` render as tappable links that navigate to the linked document
- [x] Standard markdown links to external URLs open correctly
- [x] Unfiltered document list returns the expected number of documents (matching filtered view totals)
- [x] All existing tests continue to pass

## Implementation Steps

- [x] Step 1: Strip YAML front matter from document content - Add a content-processing step in `DocumentDetailViewModel` that removes the front matter block (everything between opening `---` and closing `---` at the start of the content) before passing it to the view. Detect front matter directly by regex-matching the content (e.g. `/\A---\n[\s\S]*?\n---\n?/`), regardless of the `hasFrontmatter` flag. Do not rely on the flag: `CachedDocument.toDocument()` always sets it to `false`, so cached documents would silently skip stripping despite still containing front matter in the content string.
- [x] Step 2: Render checkboxes in markdown content - Pre-process markdown content to convert `- [ ]` and `- [x]` patterns into rendered checkbox indicators that `StructuredText` can display. Evaluate whether Textual supports GitHub Flavored Markdown task lists natively, or implement a content transformation.
- [x] Step 3: Handle internal markdown links - Pre-process `[[wikilink]]` syntax into tappable links that navigate to the corresponding document within the app. Resolve link targets against known document paths. Ensure standard markdown links to external URLs continue to work.
- [x] Step 4: Fix unfiltered document list scan - Investigate and fix the `api_list_documents` Lambda so that unfiltered scans return the requested number of METADATA documents. Either accumulate results across multiple scan pages until the limit is met, or switch to an index-based query. Update unit tests for the handler.
- [x] Step 5: Add unit tests - Test front matter stripping with various edge cases (no front matter, empty front matter, front matter with special characters). Test checkbox rendering transformation. Test wikilink parsing and resolution.
- [x] Step 6: Verify - Manual testing with real Obsidian vault documents containing front matter, checkboxes, and internal links.
