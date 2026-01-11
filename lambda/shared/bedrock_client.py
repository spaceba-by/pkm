"""Amazon Bedrock client utilities for PKM agent."""

import json
import logging
import os
from typing import Dict, Any, Optional

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class BedrockClient:
    """Client for interacting with Amazon Bedrock."""

    def __init__(self, region: Optional[str] = None):
        """Initialize Bedrock client.

        Args:
            region: AWS region. If None, uses environment or default region.
        """
        self.region = region or os.environ.get('AWS_REGION', 'us-east-1')
        self.client = boto3.client('bedrock-runtime', region_name=self.region)
        logger.info(f"Initialized Bedrock client in region {self.region}")

    def invoke_model(
        self,
        model_id: str,
        prompt: str,
        max_tokens: int = 2048,
        temperature: float = 1.0,
        system_prompt: Optional[str] = None
    ) -> str:
        """Invoke Bedrock model with the given prompt.

        Args:
            model_id: Bedrock model ID (e.g., anthropic.claude-3-haiku-20240307-v1:0)
            prompt: User prompt
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature (0.0-1.0)
            system_prompt: Optional system prompt

        Returns:
            Model response text

        Raises:
            ClientError: If Bedrock API call fails
        """
        try:
            # Prepare request body for Claude models
            request_body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": max_tokens,
                "temperature": temperature,
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            }

            if system_prompt:
                request_body["system"] = system_prompt

            logger.info(f"Invoking model {model_id} with prompt length {len(prompt)}")

            response = self.client.invoke_model(
                modelId=model_id,
                body=json.dumps(request_body)
            )

            response_body = json.loads(response['body'].read())

            # Extract text from Claude response
            if 'content' in response_body and len(response_body['content']) > 0:
                response_text = response_body['content'][0]['text']
                logger.info(f"Received response of length {len(response_text)}")
                return response_text
            else:
                logger.error(f"Unexpected response format: {response_body}")
                raise ValueError("Unexpected Bedrock response format")

        except ClientError as e:
            logger.error(f"Bedrock API error: {e}")
            raise
        except Exception as e:
            logger.error(f"Error invoking Bedrock model: {e}")
            raise

    def classify_document(self, content: str, model_id: str) -> str:
        """Classify a document using Bedrock.

        Args:
            content: Document content to classify
            model_id: Bedrock model ID

        Returns:
            Classification label (meeting, idea, reference, journal, project)
        """
        prompt = f"""Classify this markdown document into exactly one of these categories:
- meeting (notes from meetings or calls)
- idea (brainstorms, concepts, proposals)
- reference (documentation, how-tos, factual info)
- journal (personal reflections, daily logs)
- project (project plans, specs, tracking)

Return ONLY the category name, nothing else.

Document:
{content}"""

        response = self.invoke_model(
            model_id=model_id,
            prompt=prompt,
            max_tokens=10,
            temperature=0.0
        )

        # Extract and validate classification
        classification = response.strip().lower()
        valid_classifications = ['meeting', 'idea', 'reference', 'journal', 'project']

        if classification in valid_classifications:
            return classification
        else:
            logger.warning(f"Invalid classification '{classification}', defaulting to 'reference'")
            return 'reference'

    def extract_entities(self, content: str, model_id: str) -> Dict[str, list]:
        """Extract named entities from a document.

        Args:
            content: Document content
            model_id: Bedrock model ID

        Returns:
            Dictionary with entity types as keys and entity lists as values
        """
        prompt = f"""Extract named entities from this markdown document.
Return valid JSON only, no other text:
{{
  "people": ["name1", "name2"],
  "organizations": ["org1", "org2"],
  "concepts": ["concept1", "concept2"],
  "locations": ["place1", "place2"]
}}

Document:
{content}"""

        response = self.invoke_model(
            model_id=model_id,
            prompt=prompt,
            max_tokens=500,
            temperature=0.0
        )

        try:
            # Parse JSON response
            entities = json.loads(response.strip())

            # Validate structure
            expected_keys = ['people', 'organizations', 'concepts', 'locations']
            for key in expected_keys:
                if key not in entities:
                    entities[key] = []

            logger.info(f"Extracted entities: {sum(len(v) for v in entities.values())} total")
            return entities

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse entities JSON: {e}")
            return {
                'people': [],
                'organizations': [],
                'concepts': [],
                'locations': []
            }

    def generate_summary(self, documents: list, model_id: str) -> str:
        """Generate a summary from multiple documents.

        Args:
            documents: List of document dictionaries with 'path' and 'content'
            model_id: Bedrock model ID

        Returns:
            Generated summary text
        """
        docs_text = "\n\n".join([
            f"## {doc['path']}\n{doc['content']}"
            for doc in documents
        ])

        prompt = f"""Analyze these documents created or modified today and provide a concise summary.
Focus on: key themes, important updates, decisions made, and action items.
Write in second person ("You worked on...", "You decided...").
Keep it under 500 words.

Documents:
{docs_text}"""

        return self.invoke_model(
            model_id=model_id,
            prompt=prompt,
            max_tokens=1000,
            temperature=0.7
        )

    def generate_weekly_report(self, week_data: Dict[str, Any], model_id: str) -> str:
        """Generate a weekly report.

        Args:
            week_data: Dictionary with week's activity data
            model_id: Bedrock model ID

        Returns:
            Generated weekly report text
        """
        week_data_str = json.dumps(week_data, indent=2)

        prompt = f"""Analyze this week's PKM activity and provide:

1. Overview: 2-3 sentences summarizing the week
2. Key Themes: 3-5 major themes across documents
3. Recommended Follow-ups: 3-5 specific actions to take

Base your analysis on these documents and daily summaries:
{week_data_str}

Format your response in markdown suitable for a weekly review."""

        return self.invoke_model(
            model_id=model_id,
            prompt=prompt,
            max_tokens=2048,
            temperature=0.7
        )
