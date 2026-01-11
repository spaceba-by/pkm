# Bedrock Prompt Templates

This document contains all the prompts used with Amazon Bedrock for document processing.

## Overview

The PKM Agent System uses two Claude models:
- **Claude 3 Haiku:** Fast, cost-effective for classification and entity extraction
- **Claude 3.5 Sonnet:** Higher quality for summaries and reports

All prompts are designed to be:
- Clear and specific
- Consistent in format
- Easy to parse programmatically
- Optimized for token efficiency

## Classification Prompt

**Used by:** `classify-document` Lambda
**Model:** Claude 3 Haiku
**Temperature:** 0.0 (deterministic)
**Max Tokens:** 10

```
Classify this markdown document into exactly one of these categories:
- meeting (notes from meetings or calls)
- idea (brainstorms, concepts, proposals)
- reference (documentation, how-tos, factual info)
- journal (personal reflections, daily logs)
- project (project plans, specs, tracking)

Return ONLY the category name, nothing else.

Document:
{content}
```

**Expected Output:** Single word (e.g., `meeting`)

**Example:**
```
Input:
---
title: Q1 Planning Session
---
# Q1 Planning

Met with the team to discuss Q1 goals...

Output:
meeting
```

## Entity Extraction Prompt

**Used by:** `extract-entities` Lambda
**Model:** Claude 3 Haiku
**Temperature:** 0.0 (deterministic)
**Max Tokens:** 500

```
Extract named entities from this markdown document.
Return valid JSON only, no other text:
{
  "people": ["name1", "name2"],
  "organizations": ["org1", "org2"],
  "concepts": ["concept1", "concept2"],
  "locations": ["place1", "place2"]
}

Document:
{content}
```

**Expected Output:** JSON object with four arrays

**Example:**
```
Input:
Met with Alice and Bob from Acme Corp to discuss machine learning project...

Output:
{
  "people": ["Alice", "Bob"],
  "organizations": ["Acme Corp"],
  "concepts": ["machine learning"],
  "locations": []
}
```

## Daily Summary Prompt

**Used by:** `generate-daily-summary` Lambda
**Model:** Claude 3.5 Sonnet
**Temperature:** 0.7 (creative)
**Max Tokens:** 1000

```
Analyze these documents created or modified today and provide a concise summary.
Focus on: key themes, important updates, decisions made, and action items.
Write in second person ("You worked on...", "You decided...").
Keep it under 500 words.

Documents:
{documents}
```

**Documents Format:**
```
## path/to/doc1.md
[document content]

## path/to/doc2.md
[document content]
```

**Expected Output:** Markdown-formatted summary in second person

**Example:**
```
Input:
## daily/2026-01-11.md
Worked on PKM agent system design. Finalized architecture...

## projects/pkm-spec.md
Updated technical requirements for the agent system...

Output:
You had a productive day focusing on the PKM Agent System. The main effort went into finalizing the architecture design and updating technical specifications.

Key highlights:
- Completed architecture design with S3, Lambda, and Bedrock
- Updated project specifications with detailed requirements
- Made decisions on using Claude models for AI processing

The work sets a solid foundation for implementation next week.
```

## Weekly Report Prompt

**Used by:** `generate-weekly-report` Lambda
**Model:** Claude 3.5 Sonnet
**Temperature:** 0.7 (creative)
**Max Tokens:** 2048

```
Analyze this week's PKM activity and provide:

1. Overview: 2-3 sentences summarizing the week
2. Key Themes: 3-5 major themes across documents
3. Recommended Follow-ups: 3-5 specific actions to take

Base your analysis on these documents and daily summaries:
{week_data}

Format your response in markdown suitable for a weekly review.
```

**Week Data Format:** JSON object containing:
```json
{
  "week": "2026-W02",
  "start_date": "2026-01-06",
  "end_date": "2026-01-12",
  "document_count": 42,
  "classification_counts": {
    "meeting": 8,
    "idea": 5,
    "reference": 12,
    "journal": 15,
    "project": 2
  },
  "daily_summaries": [
    {
      "date": "2026-01-06",
      "content": "..."
    }
  ],
  "documents": [
    {
      "path": "daily/2026-01-06.md",
      "title": "Daily Notes",
      "classification": "journal",
      "tags": ["daily"]
    }
  ]
}
```

**Expected Output:** Structured markdown report

**Example:**
```
## Overview

You had an exceptionally productive week, creating 42 documents across diverse topics. The week showed strong focus on project planning and daily reflection, with significant progress on the PKM Agent System project.

## Key Themes

1. **PKM Agent System Development**: Major focus on designing and planning the new personal knowledge management automation system
2. **Daily Reflection Practice**: Consistent journaling with 15 daily entries showing commitment to self-reflection
3. **Technical Research**: Extensive reference documentation on AWS services, Python libraries, and AI/ML concepts
4. **Team Collaboration**: 8 meeting notes indicating active engagement with colleagues and stakeholders
5. **Idea Generation**: 5 new ideas captured around productivity tools and workflow improvements

## Recommended Follow-ups

1. Begin implementation of PKM Agent System infrastructure - architecture is well-defined and ready for execution
2. Schedule follow-up meetings on the 3 action items identified across various meetings this week
3. Review and synthesize the technical research documents into actionable insights
4. Explore one of the productivity ideas captured this week - particularly the automation workflow concept
5. Continue daily journaling practice as it's providing valuable self-awareness and pattern recognition
```

## Customizing Prompts

### Modifying Classification Categories

Edit `lambda/shared/bedrock_client.py`:

```python
prompt = f"""Classify this markdown document into exactly one of these categories:
- meeting (notes from meetings or calls)
- idea (brainstorms, concepts, proposals)
- reference (documentation, how-tos, factual info)
- journal (personal reflections, daily logs)
- project (project plans, specs, tracking)
- research (academic, investigation, analysis)  # NEW
- personal (private, sensitive content)         # NEW

Return ONLY the category name, nothing else.

Document:
{content}"""
```

Also update:
1. `markdown_utils.py` → `create_classification_index()` to include new categories
2. `dynamodb_client.py` → `get_all_classifications()` valid_types list

### Adjusting Summary Tone

For first-person instead of second-person:

```python
prompt = f"""Analyze these documents created or modified today and provide a concise summary.
Focus on: key themes, important updates, decisions made, and action items.
Write in first person ("I worked on...", "I decided...").  # CHANGED
Keep it under 500 words.

Documents:
{documents}"""
```

### Adding New Entity Types

Edit `lambda/shared/bedrock_client.py`:

```python
prompt = f"""Extract named entities from this markdown document.
Return valid JSON only, no other text:
{{
  "people": ["name1", "name2"],
  "organizations": ["org1", "org2"],
  "concepts": ["concept1", "concept2"],
  "locations": ["place1", "place2"],
  "technologies": ["tech1", "tech2"],  # NEW
  "events": ["event1", "event2"]       # NEW
}}

Document:
{content}"""
```

### Increasing Summary Length

```python
prompt = f"""Analyze these documents created or modified today and provide a comprehensive summary.
Focus on: key themes, important updates, decisions made, and action items.
Write in second person ("You worked on...", "You decided...").
Keep it under 1000 words.  # CHANGED from 500

Include a separate section for each major theme or project.  # NEW

Documents:
{documents}"""
```

## Prompt Engineering Best Practices

1. **Be Specific:** Clearly define what you want
2. **Use Examples:** Few-shot prompting improves accuracy
3. **Set Constraints:** Specify format, length, style
4. **Test Iteratively:** Try prompts with sample data
5. **Temperature Selection:**
   - 0.0 for factual, deterministic tasks (classification)
   - 0.7 for creative tasks (summaries)
   - 1.0 for maximum creativity (not recommended here)

## Testing Prompts

### Test Classification

```python
from bedrock_client import BedrockClient

client = BedrockClient()
content = """
---
title: Team Standup
date: 2026-01-11
---

# Daily Standup

Quick check-in with the team...
"""

classification = client.classify_document(
    content,
    "anthropic.claude-3-haiku-20240307-v1:0"
)
print(f"Classification: {classification}")
```

### Test Entity Extraction

```python
from bedrock_client import BedrockClient

client = BedrockClient()
content = """
Met with Sarah and John from Microsoft to discuss
the Azure integration project in Seattle.
"""

entities = client.extract_entities(
    content,
    "anthropic.claude-3-haiku-20240307-v1:0"
)
print(f"Entities: {entities}")
```

### Test Summary Generation

```python
from bedrock_client import BedrockClient

client = BedrockClient()
documents = [
    {
        'path': 'daily/2026-01-11.md',
        'content': 'Worked on PKM system...'
    }
]

summary = client.generate_summary(
    documents,
    "anthropic.claude-3-5-sonnet-20241022-v2:0"
)
print(f"Summary: {summary}")
```

## Cost Optimization

### Token Usage Guidelines

| Operation | Avg Input Tokens | Avg Output Tokens | Cost (Haiku) | Cost (Sonnet) |
|-----------|------------------|-------------------|--------------|---------------|
| Classification | 500 | 5 | $0.0001 | $0.0015 |
| Entity Extraction | 500 | 50 | $0.0001 | $0.0015 |
| Daily Summary | 5000 | 500 | $0.0013 | $0.018 |
| Weekly Report | 20000 | 1000 | $0.005 | $0.063 |

### Reducing Token Usage

1. **Truncate Long Documents:**
   ```python
   content = content[:2000]  # Limit to ~500 tokens
   ```

2. **Summarize Before Summarizing:**
   ```python
   # For weekly reports, use daily summaries instead of full docs
   ```

3. **Batch Processing:**
   ```python
   # Process multiple classifications in one call
   ```

4. **Caching:**
   ```python
   # Cache classification results in DynamoDB
   ```

## Monitoring Prompt Performance

### CloudWatch Metrics

Track in CloudWatch:
- Average response tokens by function
- Total token usage per day/month
- Bedrock invocation count
- Bedrock error rate

### Sample Queries

```bash
# Total Bedrock invocations today
aws logs filter-pattern "Invoking model" \
  --log-group-name /aws/lambda/pkm-agent-classify-document \
  --start-time $(date -d "today" +%s)000

# Average classification latency
aws logs filter-pattern "Received response" \
  --log-group-name /aws/lambda/pkm-agent-classify-document
```

## Troubleshooting

### Issue: Inconsistent Classifications

**Solution:** Lower temperature to 0.0, add more examples to prompt

### Issue: Entity Extraction Missing Entities

**Solution:** Increase max_tokens, add specific examples in prompt

### Issue: Summary Too Generic

**Solution:** Add more specific instructions, provide example summaries

### Issue: JSON Parsing Errors

**Solution:** Add "Return ONLY valid JSON, no explanatory text" to prompt

## References

- [Claude Model Documentation](https://docs.anthropic.com/claude/docs)
- [Prompt Engineering Guide](https://docs.anthropic.com/claude/docs/prompt-engineering)
- [Amazon Bedrock User Guide](https://docs.aws.amazon.com/bedrock/)
