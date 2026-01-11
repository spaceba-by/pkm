"""Markdown parsing and manipulation utilities for PKM agent."""

import logging
import re
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple

import yaml

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def extract_frontmatter(content: str) -> Tuple[Optional[Dict[str, Any]], str]:
    """Extract YAML frontmatter from markdown content.

    Args:
        content: Markdown file content

    Returns:
        Tuple of (frontmatter dict, content without frontmatter)
    """
    # Match YAML frontmatter pattern
    pattern = r'^---\s*\n(.*?)\n---\s*\n(.*)$'
    match = re.match(pattern, content, re.DOTALL)

    if match:
        try:
            frontmatter_str = match.group(1)
            body = match.group(2)
            frontmatter = yaml.safe_load(frontmatter_str)
            logger.info("Extracted frontmatter successfully")
            return frontmatter or {}, body
        except yaml.YAMLError as e:
            logger.error(f"Error parsing YAML frontmatter: {e}")
            return None, content
    else:
        logger.info("No frontmatter found")
        return None, content


def extract_wikilinks(content: str) -> List[str]:
    """Extract wikilinks from markdown content.

    Args:
        content: Markdown content

    Returns:
        List of wikilink targets
    """
    # Match [[link]] and [[link|display]] patterns
    pattern = r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]'
    matches = re.findall(pattern, content)

    # Clean and deduplicate
    links = list(set([link.strip() for link in matches]))
    logger.info(f"Extracted {len(links)} wikilinks")
    return links


def extract_tags(content: str, frontmatter: Optional[Dict[str, Any]] = None) -> List[str]:
    """Extract tags from frontmatter and content.

    Args:
        content: Markdown content
        frontmatter: Parsed frontmatter dictionary

    Returns:
        List of tags
    """
    tags = set()

    # Extract from frontmatter
    if frontmatter:
        if 'tags' in frontmatter:
            fm_tags = frontmatter['tags']
            if isinstance(fm_tags, list):
                tags.update([str(tag).strip() for tag in fm_tags])
            elif isinstance(fm_tags, str):
                tags.update([tag.strip() for tag in fm_tags.split(',')])

    # Extract inline hashtags
    hashtag_pattern = r'(?:^|\s)#([a-zA-Z0-9_-]+)'
    inline_tags = re.findall(hashtag_pattern, content)
    tags.update(inline_tags)

    logger.info(f"Extracted {len(tags)} tags")
    return list(tags)


def extract_title(content: str, frontmatter: Optional[Dict[str, Any]] = None) -> str:
    """Extract document title from frontmatter or first heading.

    Args:
        content: Markdown content
        frontmatter: Parsed frontmatter dictionary

    Returns:
        Document title
    """
    # Check frontmatter first
    if frontmatter and 'title' in frontmatter:
        return str(frontmatter['title']).strip()

    # Look for first H1 heading
    h1_pattern = r'^#\s+(.+)$'
    match = re.search(h1_pattern, content, re.MULTILINE)
    if match:
        return match.group(1).strip()

    # Default to "Untitled"
    return "Untitled"


def create_frontmatter(metadata: Dict[str, Any]) -> str:
    """Create YAML frontmatter from metadata dictionary.

    Args:
        metadata: Metadata dictionary

    Returns:
        YAML frontmatter string with delimiters
    """
    yaml_str = yaml.dump(metadata, default_flow_style=False, allow_unicode=True)
    return f"---\n{yaml_str}---\n"


def create_summary_document(
    date: str,
    summary_content: str,
    source_docs: List[str],
    doc_count: int
) -> str:
    """Create a formatted daily summary markdown document.

    Args:
        date: Date in YYYY-MM-DD format
        summary_content: Summary text
        source_docs: List of source document paths
        doc_count: Number of source documents

    Returns:
        Complete markdown document
    """
    frontmatter = {
        'generated': datetime.utcnow().isoformat() + 'Z',
        'agent': 'summarization',
        'period': 'daily',
        'source_docs': doc_count,
        'tags': ['agent-generated', 'summary']
    }

    doc_links = '\n'.join([f"- [[{doc}]]" for doc in source_docs])

    content = f"""{create_frontmatter(frontmatter)}
# Daily Summary - {date}

{summary_content}

## Source Documents
{doc_links}

---
*Generated automatically by PKM agent*
"""

    return content


def create_weekly_report_document(
    week: str,
    report_content: str,
    source_count: int
) -> str:
    """Create a formatted weekly report markdown document.

    Args:
        week: Week in YYYY-Www format (e.g., 2026-W02)
        report_content: Report text
        source_count: Number of source documents analyzed

    Returns:
        Complete markdown document
    """
    frontmatter = {
        'generated': datetime.utcnow().isoformat() + 'Z',
        'agent': 'reporting',
        'period': 'weekly',
        'week': week,
        'source_docs': source_count,
        'tags': ['agent-generated', 'weekly-report']
    }

    content = f"""{create_frontmatter(frontmatter)}
# Weekly Report - {week}

{report_content}

---
*Generated automatically by PKM agent*
"""

    return content


def create_entity_page(
    entity_name: str,
    entity_type: str,
    mentions: List[Dict[str, str]]
) -> str:
    """Create a formatted entity page markdown document.

    Args:
        entity_name: Name of the entity
        entity_type: Type of entity (person, organization, concept, location)
        mentions: List of mention dictionaries with 'path' and 'context'

    Returns:
        Complete markdown document
    """
    frontmatter = {
        'type': entity_type,
        'mentioned_in': [m['path'] for m in mentions],
        'last_updated': datetime.utcnow().isoformat() + 'Z'
    }

    mentions_text = '\n'.join([
        f"- [[{m['path']}]] - {m.get('context', '')}"
        for m in mentions
    ])

    content = f"""{create_frontmatter(frontmatter)}
# {entity_name}

## Mentions
{mentions_text}
"""

    return content


def create_classification_index(
    classifications: Dict[str, List[str]]
) -> str:
    """Create a formatted classification index markdown document.

    Args:
        classifications: Dictionary mapping classification types to document paths

    Returns:
        Complete markdown document
    """
    frontmatter = {
        'generated': datetime.utcnow().isoformat() + 'Z',
        'tags': ['index', 'agent-generated']
    }

    # Build sections for each classification type
    sections = []
    classification_order = ['meeting', 'idea', 'reference', 'journal', 'project']

    for classification in classification_order:
        if classification in classifications and classifications[classification]:
            docs = classifications[classification]
            doc_links = '\n'.join([f"- [[{doc}]]" for doc in sorted(docs)])
            sections.append(f"## {classification.capitalize()}\n{doc_links}")

    sections_text = '\n\n'.join(sections)

    content = f"""{create_frontmatter(frontmatter)}
# Document Classifications

{sections_text}
"""

    return content


def sanitize_filename(name: str) -> str:
    """Sanitize a string for use as a filename.

    Args:
        name: Original name

    Returns:
        Sanitized filename-safe string
    """
    # Replace spaces with hyphens
    name = name.replace(' ', '-')

    # Remove or replace invalid characters
    name = re.sub(r'[^\w\-.]', '', name)

    # Convert to lowercase
    name = name.lower()

    # Remove leading/trailing hyphens
    name = name.strip('-')

    return name


def get_week_string(date: datetime) -> str:
    """Get ISO week string for a date.

    Args:
        date: Date to get week for

    Returns:
        Week string in YYYY-Www format (e.g., 2026-W02)
    """
    year, week, _ = date.isocalendar()
    return f"{year}-W{week:02d}"


def parse_markdown_metadata(content: str) -> Dict[str, Any]:
    """Parse markdown content and extract all metadata.

    Args:
        content: Markdown file content

    Returns:
        Dictionary containing all extracted metadata
    """
    frontmatter, body = extract_frontmatter(content)
    tags = extract_tags(body, frontmatter)
    title = extract_title(body, frontmatter)
    wikilinks = extract_wikilinks(body)

    metadata = {
        'title': title,
        'tags': tags,
        'links_to': wikilinks,
        'has_frontmatter': frontmatter is not None
    }

    # Include frontmatter fields
    if frontmatter:
        if 'date' in frontmatter:
            metadata['date'] = str(frontmatter['date'])
        if 'created' in frontmatter:
            metadata['created'] = str(frontmatter['created'])
        if 'modified' in frontmatter:
            metadata['modified'] = str(frontmatter['modified'])

        # Include any other frontmatter fields
        for key, value in frontmatter.items():
            if key not in ['title', 'tags', 'date', 'created', 'modified']:
                metadata[key] = value

    logger.info(f"Parsed metadata: {len(tags)} tags, {len(wikilinks)} links")
    return metadata
