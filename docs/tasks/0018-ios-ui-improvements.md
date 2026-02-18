# Task 0018: iOS UI Improvements

**Status**: Planned

## Specifications

A collection of iOS rendering and display improvements focused on better markdown content presentation in the document detail view. The app currently uses the Textual library (`StructuredText`) for markdown rendering. These improvements address gaps where content isn't rendered optimally.

### Improve YAML Front Matter Rendering

Documents from the Obsidian vault include YAML front matter blocks (delimited by `---`) at the top. Currently, the full markdown content including front matter is passed directly to `StructuredText`, which renders the YAML block as raw text. This is redundant since the metadata (classification, tags, entities, dates) is already displayed in the document detail header.

The fix should strip YAML front matter from the content before rendering. The `hasFrontmatter` flag on `DocumentMetadata` already indicates whether front matter is present and can be used to gate the stripping logic.

### Render Checkboxes

Obsidian-style markdown uses `- [ ]` and `- [x]` syntax for task lists / checkboxes. These should render as visual checkboxes (unchecked and checked respectively) rather than raw text. The checkboxes should be read-only since the app currently has no write support.

### Handle Internal Markdown Links

Obsidian uses `[[wikilink]]` syntax for internal links between documents. These should be rendered as tappable links that navigate to the linked document within the app (if it exists in the vault), rather than displaying the raw `[[...]]` bracket syntax. Standard markdown links (`[text](url)`) to external URLs should also open correctly.

## Relevant Files

- `ios/PKMReader/Features/DocumentDetail/DocumentDetailView.swift` - Document content rendering with `StructuredText`
- `ios/PKMReader/Features/DocumentDetail/DocumentDetailViewModel.swift` - Content loading and state management
- `ios/PKMReader/Models/Document.swift` - `DocumentMetadata.hasFrontmatter` flag
- `lambda/shared/markdown/utils.clj` - Backend front matter extraction regex and wikilink parsing (reference)

## Acceptance Criteria

- [ ] YAML front matter block is not visible in rendered document content
- [ ] Documents without front matter continue to render correctly
- [ ] Markdown checkboxes (`- [ ]` and `- [x]`) render as visual checkbox indicators
- [ ] Checked items are visually distinct from unchecked items
- [ ] Checkboxes are read-only (no toggle interaction)
- [ ] Internal `[[wikilinks]]` render as tappable links that navigate to the linked document
- [ ] Standard markdown links to external URLs open correctly
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Strip YAML front matter from document content - Add a content-processing step in `DocumentDetailViewModel` that removes the front matter block (everything between opening `---` and closing `---` at the start of the content) before passing it to the view. Use the `hasFrontmatter` flag to determine whether stripping is needed.
- [ ] Step 2: Render checkboxes in markdown content - Pre-process markdown content to convert `- [ ]` and `- [x]` patterns into rendered checkbox indicators that `StructuredText` can display. Evaluate whether Textual supports GitHub Flavored Markdown task lists natively, or implement a content transformation.
- [ ] Step 3: Handle internal markdown links - Pre-process `[[wikilink]]` syntax into tappable links that navigate to the corresponding document within the app. Resolve link targets against known document paths. Ensure standard markdown links to external URLs continue to work.
- [ ] Step 4: Add unit tests - Test front matter stripping with various edge cases (no front matter, empty front matter, front matter with special characters). Test checkbox rendering transformation. Test wikilink parsing and resolution.
- [ ] Step 5: Verify - Manual testing with real Obsidian vault documents containing front matter, checkboxes, and internal links.
