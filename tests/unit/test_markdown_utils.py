"""Unit tests for markdown_utils module."""

import pytest
from datetime import datetime
from lambda.shared.markdown_utils import (
    extract_frontmatter,
    extract_wikilinks,
    extract_tags,
    extract_title,
    create_frontmatter,
    sanitize_filename,
    get_week_string,
    parse_markdown_metadata
)


def test_extract_frontmatter():
    """Test frontmatter extraction."""
    content = """---
title: Test Document
date: 2026-01-11
tags: [test, example]
---

# Content

Some text here."""

    frontmatter, body = extract_frontmatter(content)

    assert frontmatter is not None
    assert frontmatter['title'] == 'Test Document'
    assert frontmatter['date'] == '2026-01-11'
    assert frontmatter['tags'] == ['test', 'example']
    assert '# Content' in body


def test_extract_frontmatter_no_frontmatter():
    """Test extraction when no frontmatter present."""
    content = "# Just a heading\n\nSome content."

    frontmatter, body = extract_frontmatter(content)

    assert frontmatter is None
    assert body == content


def test_extract_wikilinks():
    """Test wikilink extraction."""
    content = """
    This links to [[page1]] and [[page2|Display Text]].
    Also mentions [[another-page]].
    """

    links = extract_wikilinks(content)

    assert 'page1' in links
    assert 'page2' in links
    assert 'another-page' in links
    assert len(links) == 3


def test_extract_tags():
    """Test tag extraction from frontmatter and content."""
    frontmatter = {'tags': ['front-tag1', 'front-tag2']}
    content = "Some content with #inline-tag and #another-tag."

    tags = extract_tags(content, frontmatter)

    assert 'front-tag1' in tags
    assert 'front-tag2' in tags
    assert 'inline-tag' in tags
    assert 'another-tag' in tags


def test_extract_title_from_frontmatter():
    """Test title extraction from frontmatter."""
    frontmatter = {'title': 'Document Title'}
    content = "# Heading"

    title = extract_title(content, frontmatter)

    assert title == 'Document Title'


def test_extract_title_from_heading():
    """Test title extraction from first H1 heading."""
    content = "# Main Title\n\nSome content."

    title = extract_title(content)

    assert title == 'Main Title'


def test_extract_title_default():
    """Test default title when none found."""
    content = "Just some content without title."

    title = extract_title(content)

    assert title == 'Untitled'


def test_create_frontmatter():
    """Test frontmatter creation."""
    metadata = {
        'title': 'Test',
        'date': '2026-01-11',
        'tags': ['test']
    }

    yaml_str = create_frontmatter(metadata)

    assert yaml_str.startswith('---\n')
    assert yaml_str.endswith('---\n')
    assert 'title: Test' in yaml_str
    assert 'date: ' in yaml_str


def test_sanitize_filename():
    """Test filename sanitization."""
    assert sanitize_filename('Test File Name') == 'test-file-name'
    assert sanitize_filename('File/With\\Special:Chars') == 'filewithspecialchars'
    assert sanitize_filename('  Leading and Trailing  ') == 'leading-and-trailing'
    assert sanitize_filename('UPPERCASE') == 'uppercase'


def test_get_week_string():
    """Test week string generation."""
    date = datetime(2026, 1, 11)  # Sunday of week 2
    week_str = get_week_string(date)

    assert week_str == '2026-W02'


def test_parse_markdown_metadata():
    """Test complete metadata parsing."""
    content = """---
title: Integration Test
date: 2026-01-11
tags: [test, integration]
---

# Test Document

This links to [[other-doc]] and has #inline-tag.

## Section

More content here.
"""

    metadata = parse_markdown_metadata(content)

    assert metadata['title'] == 'Integration Test'
    assert 'test' in metadata['tags']
    assert 'integration' in metadata['tags']
    assert 'inline-tag' in metadata['tags']
    assert 'other-doc' in metadata['links_to']
    assert metadata['has_frontmatter'] is True
    assert metadata['date'] == '2026-01-11'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
