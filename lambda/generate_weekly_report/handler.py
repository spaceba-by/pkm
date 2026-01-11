"""Lambda function to generate weekly reports."""

import json
import logging
import os
from datetime import datetime, timedelta

from bedrock_client import BedrockClient
from dynamodb_client import DynamoDBClient
from s3_client import S3Client
from markdown_utils import create_weekly_report_document, get_week_string

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """Generate a weekly report of PKM activity.

    Args:
        event: Step Function input or EventBridge scheduled event
        context: Lambda context

    Returns:
        Response dictionary
    """
    try:
        logger.info(f"Generating weekly report")

        # Allow date override from event (for testing)
        if event.get('date'):
            target_date = datetime.fromisoformat(event['date'])
        else:
            # Default to last week (report runs on Sunday for previous week)
            target_date = datetime.utcnow() - timedelta(days=7)

        week_str = get_week_string(target_date)
        logger.info(f"Target week: {week_str}")

        # Calculate week boundaries (Monday to Sunday)
        year, week, _ = target_date.isocalendar()
        week_start = datetime.strptime(f'{year}-W{week:02d}-1', '%Y-W%W-%w')
        week_end = week_start + timedelta(days=7)

        logger.info(f"Week range: {week_start} to {week_end}")

        # Initialize clients
        s3_client = S3Client()
        dynamodb_client = DynamoDBClient()
        bedrock_client = BedrockClient()

        # Query documents modified during the week
        logger.info(f"Querying documents modified since {week_start}")
        week_docs = dynamodb_client.get_documents_modified_since(week_start)

        # Filter documents within the target week
        week_docs_filtered = [
            doc for doc in week_docs
            if week_start.isoformat() <= doc.get('modified', '') < week_end.isoformat()
        ]

        logger.info(f"Found {len(week_docs_filtered)} documents for {week_str}")

        # Retrieve daily summaries for the week
        daily_summaries = []
        for i in range(7):
            day = week_start + timedelta(days=i)
            day_str = day.strftime('%Y-%m-%d')
            summary = s3_client.get_daily_summary(day_str)
            if summary:
                daily_summaries.append({
                    'date': day_str,
                    'content': summary
                })

        logger.info(f"Found {len(daily_summaries)} daily summaries")

        # Compile week data for analysis
        week_data = {
            'week': week_str,
            'start_date': week_start.strftime('%Y-%m-%d'),
            'end_date': (week_end - timedelta(days=1)).strftime('%Y-%m-%d'),
            'document_count': len(week_docs_filtered),
            'daily_summaries': daily_summaries,
            'documents': []
        }

        # Include sample of documents (up to 30)
        for doc in week_docs_filtered[:30]:
            doc_path = doc['PK'].replace('doc#', '')

            # Skip agent-generated documents
            if doc_path.startswith('_agent/'):
                continue

            week_data['documents'].append({
                'path': doc_path,
                'title': doc.get('title', 'Untitled'),
                'classification': doc.get('classification', 'unknown'),
                'tags': doc.get('tags', [])
            })

        # Classify documents by type for metrics
        classification_counts = {}
        for doc in week_docs_filtered:
            classification = doc.get('classification', 'unknown')
            classification_counts[classification] = classification_counts.get(classification, 0) + 1

        week_data['classification_counts'] = classification_counts

        logger.info(f"Generating report with {len(week_data['documents'])} documents")

        # Generate report using Bedrock
        model_id = os.environ.get('BEDROCK_MODEL_ID')
        report_content = bedrock_client.generate_weekly_report(week_data, model_id)

        # Create report document
        report_doc = create_weekly_report_document(
            week_str,
            report_content,
            len(week_docs_filtered)
        )

        # Upload report to S3
        report_key = s3_client.put_agent_output(
            'reports/weekly',
            f'{week_str}.md',
            report_doc
        )

        logger.info(f"Created weekly report: {report_key}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'week': week_str,
                'report_key': report_key,
                'document_count': len(week_docs_filtered),
                'daily_summaries_count': len(daily_summaries)
            })
        }

    except Exception as e:
        logger.error(f"Error generating weekly report: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
