"""Lambda function to generate daily summaries."""

import json
import logging
import os
from datetime import datetime, timedelta

from bedrock_client import BedrockClient
from dynamodb_client import DynamoDBClient
from s3_client import S3Client
from markdown_utils import create_summary_document

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Generate a daily summary of PKM activity.

    Args:
        event: EventBridge scheduled event (optional date override)
        context: Lambda context

    Returns:
        Response dictionary
    """
    try:
        logger.info(f"Generating daily summary")

        # Allow date override from event (for testing)
        if event.get('date'):
            target_date = datetime.fromisoformat(event['date'])
        else:
            # Default to yesterday (summary runs at 6 AM for previous day)
            target_date = datetime.utcnow() - timedelta(days=1)

        date_str = target_date.strftime('%Y-%m-%d')
        logger.info(f"Target date: {date_str}")

        # Initialize clients
        s3_client = S3Client()
        dynamodb_client = DynamoDBClient()
        bedrock_client = BedrockClient()

        # Query documents modified in the last 24 hours
        since = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
        until = since + timedelta(days=1)

        logger.info(f"Querying documents modified between {since} and {until}")
        recent_docs = dynamodb_client.get_documents_modified_since(since)

        # Filter documents within the target day
        day_docs = [
            doc for doc in recent_docs
            if since.isoformat() <= doc.get('modified', '') < until.isoformat()
        ]

        logger.info(f"Found {len(day_docs)} documents for {date_str}")

        if not day_docs:
            logger.info("No documents to summarize")
            return {
                'statusCode': 200,
                'body': json.dumps('No documents to summarize')
            }

        # Retrieve full content for each document
        documents = []
        for doc in day_docs[:20]:  # Limit to 20 most recent
            doc_path = doc['PK'].replace('doc#', '')

            # Skip agent-generated documents
            if doc_path.startswith('_agent/'):
                continue

            try:
                content = s3_client.get_object(doc_path)
                if content:
                    documents.append({
                        'path': doc_path,
                        'content': content[:2000],  # Limit content size
                        'title': doc.get('title', 'Untitled')
                    })
            except Exception as e:
                logger.error(f"Error retrieving {doc_path}: {e}")

        if not documents:
            logger.info("No valid documents to summarize")
            return {
                'statusCode': 200,
                'body': json.dumps('No valid documents to summarize')
            }

        logger.info(f"Summarizing {len(documents)} documents")

        # Generate summary using Bedrock
        model_id = os.environ.get('BEDROCK_MODEL_ID')
        summary_content = bedrock_client.generate_summary(documents, model_id)

        # Create summary document
        source_paths = [doc['path'] for doc in documents]
        summary_doc = create_summary_document(
            date_str,
            summary_content,
            source_paths,
            len(documents)
        )

        # Upload summary to S3
        summary_key = s3_client.put_agent_output(
            'summaries',
            f'{date_str}.md',
            summary_doc
        )

        logger.info(f"Created daily summary: {summary_key}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'date': date_str,
                'summary_key': summary_key,
                'document_count': len(documents)
            })
        }

    except Exception as e:
        logger.error(f"Error generating daily summary: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
