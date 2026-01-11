"""DynamoDB client utilities for PKM agent."""

import logging
import os
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class DynamoDBClient:
    """Client for interacting with DynamoDB metadata table."""

    def __init__(self, table_name: Optional[str] = None):
        """Initialize DynamoDB client.

        Args:
            table_name: DynamoDB table name. If None, uses DYNAMODB_TABLE_NAME env var.
        """
        self.table_name = table_name or os.environ.get('DYNAMODB_TABLE_NAME')
        if not self.table_name:
            raise ValueError("DynamoDB table name not provided")

        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table(self.table_name)
        logger.info(f"Initialized DynamoDB client for table {self.table_name}")

    def put_document_metadata(
        self,
        file_path: str,
        metadata: Dict[str, Any]
    ) -> None:
        """Store document metadata in DynamoDB.

        Args:
            file_path: Path to the document in S3
            metadata: Dictionary containing document metadata

        Raises:
            ClientError: If DynamoDB operation fails
        """
        try:
            item = {
                'PK': f'doc#{file_path}',
                'SK': 'metadata',
                **metadata
            }

            # Add timestamp if not present
            if 'modified' not in item:
                item['modified'] = datetime.utcnow().isoformat()

            self.table.put_item(Item=item)
            logger.info(f"Stored metadata for document: {file_path}")

        except ClientError as e:
            logger.error(f"Error storing document metadata: {e}")
            raise

    def get_document_metadata(self, file_path: str) -> Optional[Dict[str, Any]]:
        """Retrieve document metadata from DynamoDB.

        Args:
            file_path: Path to the document in S3

        Returns:
            Document metadata dictionary, or None if not found
        """
        try:
            response = self.table.get_item(
                Key={
                    'PK': f'doc#{file_path}',
                    'SK': 'metadata'
                }
            )

            if 'Item' in response:
                logger.info(f"Retrieved metadata for document: {file_path}")
                return response['Item']
            else:
                logger.info(f"No metadata found for document: {file_path}")
                return None

        except ClientError as e:
            logger.error(f"Error retrieving document metadata: {e}")
            raise

    def update_classification(
        self,
        file_path: str,
        classification: str
    ) -> None:
        """Update document classification.

        Args:
            file_path: Path to the document in S3
            classification: Classification label
        """
        try:
            self.table.update_item(
                Key={
                    'PK': f'doc#{file_path}',
                    'SK': 'metadata'
                },
                UpdateExpression='SET classification = :c, modified = :m',
                ExpressionAttributeValues={
                    ':c': classification,
                    ':m': datetime.utcnow().isoformat()
                }
            )
            logger.info(f"Updated classification for {file_path}: {classification}")

        except ClientError as e:
            logger.error(f"Error updating classification: {e}")
            raise

    def store_entities(
        self,
        file_path: str,
        entities: Dict[str, List[str]]
    ) -> None:
        """Store extracted entities for a document.

        Args:
            file_path: Path to the document in S3
            entities: Dictionary of entity types and lists
        """
        try:
            # Update document metadata with entities
            self.table.update_item(
                Key={
                    'PK': f'doc#{file_path}',
                    'SK': 'metadata'
                },
                UpdateExpression='SET entities = :e, modified = :m',
                ExpressionAttributeValues={
                    ':e': entities,
                    ':m': datetime.utcnow().isoformat()
                }
            )

            # Create entity index entries
            for entity_type, entity_list in entities.items():
                for entity_name in entity_list:
                    entity_key = f'entity#{entity_type}#{entity_name.lower()}'
                    self.table.put_item(
                        Item={
                            'PK': entity_key,
                            'SK': f'doc#{file_path}',
                            'entity_key': entity_key,
                            'entity_type': entity_type,
                            'entity_name': entity_name,
                            'document_path': file_path,
                            'modified': datetime.utcnow().isoformat()
                        }
                    )

            logger.info(f"Stored entities for {file_path}")

        except ClientError as e:
            logger.error(f"Error storing entities: {e}")
            raise

    def get_documents_by_classification(
        self,
        classification: str,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Query documents by classification.

        Args:
            classification: Classification label
            limit: Maximum number of results

        Returns:
            List of document metadata dictionaries
        """
        try:
            response = self.table.query(
                IndexName='classification-index',
                KeyConditionExpression=Key('classification').eq(classification),
                ScanIndexForward=False,  # Most recent first
                Limit=limit
            )

            logger.info(f"Found {len(response['Items'])} documents with classification: {classification}")
            return response['Items']

        except ClientError as e:
            logger.error(f"Error querying documents by classification: {e}")
            raise

    def get_all_classifications(self) -> Dict[str, List[str]]:
        """Get all documents grouped by classification.

        Returns:
            Dictionary mapping classifications to document paths
        """
        try:
            classifications = {}
            valid_types = ['meeting', 'idea', 'reference', 'journal', 'project']

            for classification in valid_types:
                docs = self.get_documents_by_classification(classification)
                doc_paths = [
                    doc['PK'].replace('doc#', '')
                    for doc in docs
                ]
                classifications[classification] = sorted(doc_paths)

            logger.info(f"Retrieved all classifications")
            return classifications

        except ClientError as e:
            logger.error(f"Error retrieving all classifications: {e}")
            raise

    def get_documents_modified_since(
        self,
        since: datetime,
        limit: int = 1000
    ) -> List[Dict[str, Any]]:
        """Get documents modified since a given datetime.

        Args:
            since: Datetime to query from
            limit: Maximum number of results

        Returns:
            List of document metadata dictionaries
        """
        try:
            since_iso = since.isoformat()

            response = self.table.scan(
                FilterExpression='begins_with(PK, :prefix) AND SK = :sk AND modified >= :since',
                ExpressionAttributeValues={
                    ':prefix': 'doc#',
                    ':sk': 'metadata',
                    ':since': since_iso
                },
                Limit=limit
            )

            logger.info(f"Found {len(response['Items'])} documents modified since {since_iso}")
            return response['Items']

        except ClientError as e:
            logger.error(f"Error querying documents by modification time: {e}")
            raise

    def get_entity_mentions(
        self,
        entity_type: str,
        entity_name: str
    ) -> List[str]:
        """Get all documents that mention a specific entity.

        Args:
            entity_type: Type of entity (people, organizations, etc.)
            entity_name: Name of the entity

        Returns:
            List of document paths
        """
        try:
            entity_key = f'entity#{entity_type}#{entity_name.lower()}'

            response = self.table.query(
                IndexName='entity-index',
                KeyConditionExpression=Key('entity_key').eq(entity_key)
            )

            doc_paths = [
                item['SK'].replace('doc#', '')
                for item in response['Items']
            ]

            logger.info(f"Found {len(doc_paths)} mentions of {entity_type}/{entity_name}")
            return doc_paths

        except ClientError as e:
            logger.error(f"Error querying entity mentions: {e}")
            raise

    def get_documents_by_tag(
        self,
        tag: str,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get documents with a specific tag.

        Args:
            tag: Tag name
            limit: Maximum number of results

        Returns:
            List of document metadata dictionaries
        """
        try:
            response = self.table.query(
                IndexName='tag-index',
                KeyConditionExpression=Key('tag_name').eq(tag),
                Limit=limit
            )

            logger.info(f"Found {len(response['Items'])} documents with tag: {tag}")
            return response['Items']

        except ClientError as e:
            logger.error(f"Error querying documents by tag: {e}")
            raise
