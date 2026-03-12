@testable import PKMReader
import XCTest

final class MarkdownProcessorTests: XCTestCase {
    // MARK: - Frontmatter Stripping

    func test_process_stripsFrontmatter() {
        let content = "---\ntitle: Test\ntags: [a, b]\n---\n# Hello\n\nBody text"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "# Hello\n\nBody text")
    }

    func test_process_noFrontmatter_passesThrough() {
        let content = "# No Front Matter\n\nJust content."
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "# No Front Matter\n\nJust content.")
    }

    func test_process_emptyFrontmatter() {
        let content = "---\n---\n# After empty front matter"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "# After empty front matter")
    }

    func test_process_frontmatterWithSpecialChars() {
        let content = "---\ntitle: \"Test: Special & Chars\"\ndescription: 'It\\'s a test'\n---\n# Content"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "# Content")
    }

    // MARK: - Checkbox Rendering

    func test_process_uncheckedCheckboxes() {
        let content = "- [ ] Todo item\n- [ ] Another item"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "- ☐ Todo item\n- ☐ Another item")
    }

    func test_process_checkedCheckboxes() {
        let content = "- [x] Done item\n- [X] Also done"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "- ☑ Done item\n- ☑ Also done")
    }

    func test_process_mixedCheckboxes() {
        let content = "- [x] Done\n- [ ] Not done\n- [X] Also done"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "- ☑ Done\n- ☐ Not done\n- ☑ Also done")
    }

    func test_process_nestedCheckboxes() {
        let content = "- [x] Parent\n  - [ ] Child\n    - [x] Grandchild"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "- ☑ Parent\n  - ☐ Child\n    - ☑ Grandchild")
    }

    // MARK: - Wikilink Conversion

    func test_process_simpleWikilink() {
        let content = "See [[My Page]] for details"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "See [My Page](pkm:My%20Page) for details")
    }

    func test_process_wikilinkWithDisplayText() {
        let content = "See [[target-page|Display Text]] here"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "See [Display Text](pkm:target-page) here")
    }

    func test_process_multipleWikilinks() {
        let content = "Link to [[PageA]] and [[PageB|Page B]]"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(result, "Link to [PageA](pkm:PageA) and [Page B](pkm:PageB)")
    }

    // MARK: - All Transformations Combined

    func test_process_allTransformations() {
        let content = "---\ntitle: Test\n---\n# Tasks\n\n- [x] Read [[Documentation]]\n- [ ] Review [[Code|the code]]"
        let result = MarkdownProcessor.process(content)
        XCTAssertEqual(
            result,
            "# Tasks\n\n- ☑ Read [Documentation](pkm:Documentation)\n- ☐ Review [the code](pkm:Code)"
        )
    }
}
