"""Lambda function to classify markdown documents."""

import json
import logging
import os
from datetime import datetime

import boto3

# Import shared utilities from Lambda layer
from bedrock_client import BedrockClient
from dynamodb_client import DynamoDBClient
from s3_client import S3Client
from markdown_utils import parse_markdown_metadata

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Handle S3 event to classify a markdown document.

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

        # Skip _agent directory files
        if object_key.startswith('_agent/') or '/_agent/' in object_key:
            logger.info(f"Skipping agent-generated file: {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Skipped agent-generated file')
            }

        # Skip .obsidian directory files
        if object_key.startswith('.obsidian/') or '/.obsidian/' in object_key:
            logger.info(f"Skipping .obsidian file: {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Skipped .obsidian file')
            }

        # Initialize clients
        s3_client = S3Client(bucket_name)
        dynamodb_client = DynamoDBClient()
        bedrock_client = BedrockClient()

        # Get document content
        logger.info(f"Processing document: {object_key}")
        content = s3_client.get_object(object_key)

        if not content:
            logger.warning(f"Empty content for {object_key}")
            return {
                'statusCode': 200,
                'body': json.dumps('Empty document')
            }

        # Parse metadata
        metadata = parse_markdown_metadata(content)

        # Classify document using Bedrock
        model_id = os.environ.get('BEDROCK_MODEL_ID')
        classification = bedrock_client.classify_document(content, model_id)

        logger.info(f"Classified {object_key} as: {classification}")

        # Store classification in DynamoDB
        metadata['classification'] = classification
        metadata['modified'] = datetime.utcnow().isoformat()
        dynamodb_client.put_document_metadata(object_key, metadata)

        # Invoke update-classification-index Lambda
        update_index_lambda = os.environ.get('UPDATE_INDEX_LAMBDA')
        if update_index_lambda:
            lambda_client = boto3.client('lambda')
            lambda_client.invoke(
                FunctionName=update_index_lambda,
                InvocationType='Event',  # Async invocation
                Payload=json.dumps({
                    'classification': classification,
                    'document_path': object_key
                })
            )
            logger.info(f"Triggered classification index update")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'document': object_key,
                'classification': classification
            })
        }

    except Exception as e:
        logger.error(f"Error processing document: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
