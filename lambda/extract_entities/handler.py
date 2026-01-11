"""Lambda function to extract entities from markdown documents."""

import json
import logging
import os

from bedrock_client import BedrockClient
from dynamodb_client import DynamoDBClient
from s3_client import S3Client
from markdown_utils import create_entity_page, sanitize_filename

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Handle S3 event to extract entities from a markdown document.

    Args:
        event: S3 event from EventBridge
        context: Lambda context

    Returns:
        Response dictionary
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")

        # Extract S3 object details from EventBridge event
        detail = event.get('detail', {})
        bucket_name = detail.get('bucket', {}).get('name')
        object_key = detail.get('object', {}).get('key')

        if not bucket_name or not object_key:
            logger.error("Missing bucket name or object key in event")
            return {
                'statusCode': 400,
                'body': json.dumps('Invalid event format')
            }

        # Skip non-markdown files
        if not object_key.endswith('.md'):
            logger.info(f"Skipping non-markdown file: {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Skipped non-markdown file')
            }

        # Skip _agent and .obsidian directories
        if object_key.startswith('_agent/') or object_key.startswith('.obsidian/'):
            logger.info(f"Skipping system file: {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Skipped system file')
            }

        # Initialize clients
        s3_client = S3Client(bucket_name)
        dynamodb_client = DynamoDBClient()
        bedrock_client = BedrockClient()

        # Get document content
        logger.info(f"Extracting entities from: {object_key}")
        content = s3_client.get_object(object_key)

        if not content:
            logger.warning(f"Empty content for {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Empty document')
            }

        # Extract entities using Bedrock
        model_id = os.environ.get('BEDROCK_MODEL_ID')
        entities = bedrock_client.extract_entities(content, model_id)

        logger.info(f"Extracted entities from {object_key}: {entities}")

        # Store entities in DynamoDB
        dynamodb_client.store_entities(object_key, entities)

        # Create/update entity pages in S3
        total_entities = 0
        for entity_type, entity_list in entities.items():
            for entity_name in entity_list:
                # Get existing mentions for this entity
                existing_mentions = dynamodb_client.get_entity_mentions(
                    entity_type,
                    entity_name
                )

                # Create entity page with all mentions
                mentions = [
                    {
                        'path': path,
                        'context': f'Mentioned in {path}'
                    }
                    for path in existing_mentions
                ]

                entity_page_content = create_entity_page(
                    entity_name,
                    entity_type,
                    mentions
                )

                # Upload entity page
                entity_filename = f"{sanitize_filename(entity_name)}.md"
                s3_client.put_agent_output(
                    f"entities/{entity_type}",
                    entity_filename,
                    entity_page_content
                )

                total_entities += 1

        logger.info(f"Created/updated {total_entities} entity pages")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'document': object_key,
                'entities': entities,
                'entity_pages_created': total_entities
            })
        }

    except Exception as e:
        logger.error(f"Error extracting entities: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
