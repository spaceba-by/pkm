"""Lambda function to extract metadata from markdown documents."""

import json
import logging
from datetime import datetime

from dynamodb_client import DynamoDBClient
from s3_client import S3Client
from markdown_utils import parse_markdown_metadata

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Handle S3 event to extract metadata from a markdown document.

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

        # Get document content
        logger.info(f"Extracting metadata from: {object_key}")
        content = s3_client.get_object(object_key)

        if not content:
            logger.warning(f"Empty content for {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Empty document')
            }

        # Parse metadata (no Bedrock needed - pure parsing)
        metadata = parse_markdown_metadata(content)

        # Add timestamps
        metadata['modified'] = datetime.utcnow().isoformat()
        if 'created' not in metadata:
            metadata['created'] = metadata['modified']

        logger.info(f"Extracted metadata from {object_key}: {metadata.get('title')}")

        # Store metadata in DynamoDB
        dynamodb_client.put_document_metadata(object_key, metadata)

        # Store tag index entries if tags exist
        if metadata.get('tags'):
            for tag in metadata['tags']:
                try:
                    dynamodb_client.table.put_item(
                        Item={
                            'PK': f'tag#{tag}',
                            'SK': f'doc#{object_key}',
                            'tag_name': tag,
                            'document_path': object_key,
                            'modified': metadata['modified']
                        }
                    )
                except Exception as e:
                    logger.error(f"Error storing tag index for {tag}: {e}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'document': object_key,
                'metadata': {
                    'title': metadata.get('title'),
                    'tags': metadata.get('tags', []),
                    'links': len(metadata.get('links_to', []))
                }
            })
        }

    except Exception as e:
        logger.error(f"Error extracting metadata: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
