"""S3 client utilities for PKM agent."""

import logging
import os
from typing import Optional

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class S3Client:
    """Client for interacting with S3 vault bucket."""

    def __init__(self, bucket_name: Optional[str] = None):
        """Initialize S3 client.

        Args:
            bucket_name: S3 bucket name. If None, uses S3_BUCKET_NAME env var.
        """
        self.bucket_name = bucket_name or os.environ.get('S3_BUCKET_NAME')
        if not self.bucket_name:
            raise ValueError("S3 bucket name not provided")

        self.s3 = boto3.client('s3')
        logger.info(f"Initialized S3 client for bucket {self.bucket_name}")

    def get_object(self, key: str) -> str:
        """Retrieve an object from S3.

        Args:
            key: S3 object key

        Returns:
            Object content as string

        Raises:
            ClientError: If S3 operation fails
        """
        try:
            response = self.s3.get_object(
                Bucket=self.bucket_name,
                Key=key
            )

            content = response['Body'].read().decode('utf-8')
            logger.info(f"Retrieved object from S3: {key} ({len(content)} bytes)")
            return content

        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchKey':
                logger.warning(f"Object not found in S3: {key}")
                return ""
            else:
                logger.error(f"Error retrieving object from S3: {e}")
                raise

    def put_object(self, key: str, content: str, content_type: str = 'text/markdown') -> None:
        """Upload an object to S3.

        Args:
            key: S3 object key
            content: Content to upload
            content_type: MIME type of content

        Raises:
            ClientError: If S3 operation fails
        """
        try:
            self.s3.put_object(
                Bucket=self.bucket_name,
                Key=key,
                Body=content.encode('utf-8'),
                ContentType=content_type
            )

            logger.info(f"Uploaded object to S3: {key} ({len(content)} bytes)")

        except ClientError as e:
            logger.error(f"Error uploading object to S3: {e}")
            raise

    def delete_object(self, key: str) -> None:
        """Delete an object from S3.

        Args:
            key: S3 object key

        Raises:
            ClientError: If S3 operation fails
        """
        try:
            self.s3.delete_object(
                Bucket=self.bucket_name,
                Key=key
            )

            logger.info(f"Deleted object from S3: {key}")

        except ClientError as e:
            logger.error(f"Error deleting object from S3: {e}")
            raise

    def object_exists(self, key: str) -> bool:
        """Check if an object exists in S3.

        Args:
            key: S3 object key

        Returns:
            True if object exists, False otherwise
        """
        try:
            self.s3.head_object(
                Bucket=self.bucket_name,
                Key=key
            )
            return True

        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                return False
            else:
                logger.error(f"Error checking object existence: {e}")
                raise

    def list_objects(self, prefix: str = '') -> list:
        """List objects in S3 with a given prefix.

        Args:
            prefix: Key prefix to filter objects

        Returns:
            List of object keys
        """
        try:
            paginator = self.s3.get_paginator('list_objects_v2')
            pages = paginator.paginate(
                Bucket=self.bucket_name,
                Prefix=prefix
            )

            keys = []
            for page in pages:
                if 'Contents' in page:
                    keys.extend([obj['Key'] for obj in page['Contents']])

            logger.info(f"Listed {len(keys)} objects with prefix: {prefix}")
            return keys

        except ClientError as e:
            logger.error(f"Error listing objects: {e}")
            raise

    def get_markdown_content(self, key: str) -> str:
        """Retrieve markdown file content from S3.

        Args:
            key: S3 object key for markdown file

        Returns:
            Markdown content as string
        """
        if not key.endswith('.md'):
            logger.warning(f"Key does not end with .md: {key}")

        return self.get_object(key)

    def put_markdown_content(self, key: str, content: str) -> None:
        """Upload markdown file to S3.

        Args:
            key: S3 object key for markdown file
            content: Markdown content
        """
        if not key.endswith('.md'):
            logger.warning(f"Key does not end with .md: {key}")

        self.put_object(key, content, content_type='text/markdown')

    def put_agent_output(
        self,
        output_type: str,
        filename: str,
        content: str
    ) -> str:
        """Upload agent-generated content to S3 _agent/ directory.

        Args:
            output_type: Type of output (summaries, reports, entities, classifications)
            filename: Filename for the output
            content: Content to upload

        Returns:
            S3 key where content was uploaded
        """
        key = f'_agent/{output_type}/{filename}'
        self.put_markdown_content(key, content)
        logger.info(f"Uploaded agent output: {key}")
        return key

    def get_daily_summary(self, date_str: str) -> Optional[str]:
        """Retrieve daily summary for a specific date.

        Args:
            date_str: Date in YYYY-MM-DD format

        Returns:
            Summary content, or None if not found
        """
        key = f'_agent/summaries/{date_str}.md'
        content = self.get_object(key)
        return content if content else None

    def get_weekly_report(self, week_str: str) -> Optional[str]:
        """Retrieve weekly report for a specific week.

        Args:
            week_str: Week in YYYY-Www format (e.g., 2026-W02)

        Returns:
            Report content, or None if not found
        """
        key = f'_agent/reports/weekly/{week_str}.md'
        content = self.get_object(key)
        return content if content else None
