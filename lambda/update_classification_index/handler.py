"""Lambda function to update the classification index."""

import json
import logging

from dynamodb_client import DynamoDBClient
from s3_client import S3Client
from markdown_utils import create_classification_index

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Update the classification index in S3.

    Args:
        event: Event with classification and document_path (from classify-document)
        context: Lambda context

    Returns:
        Response dictionary
    """
    try:
        logger.info(f"Updating classification index")
        logger.info(f"Event: {json.dumps(event)}")

        # Initialize clients
        s3_client = S3Client()
        dynamodb_client = DynamoDBClient()

        # Get all classifications from DynamoDB
        classifications = dynamodb_client.get_all_classifications()

        logger.info(f"Retrieved classifications for index update")

        # Create classification index document
        index_content = create_classification_index(classifications)

        # Upload index to S3
        index_key = s3_client.put_agent_output(
            'classifications',
            'index.md',
            index_content
        )

        logger.info(f"Updated classification index: {index_key}")

        # Count total documents
        total_docs = sum(len(docs) for docs in classifications.values())

        return {
            'statusCode': 200,
            'body': json.dumps({
                'index_key': index_key,
                'total_documents': total_docs,
                'classifications': {k: len(v) for k, v in classifications.items()}
            })
        }

    except Exception as e:
        logger.error(f"Error updating classification index: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
