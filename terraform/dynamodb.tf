# DynamoDB table for PKM metadata
resource "aws_dynamodb_table" "metadata" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "tag_name"
    type = "S"
  }

  attribute {
    name = "classification"
    type = "S"
  }

  attribute {
    name = "modified"
    type = "S"
  }

  attribute {
    name = "entity_key"
    type = "S"
  }

  attribute {
    name = "created"
    type = "S"
  }

  attribute {
    name = "monitor_status"
    type = "S"
  }

  attribute {
    name = "next_execution"
    type = "S"
  }

  # GSI for listing all documents by modified date
  global_secondary_index {
    name            = "all-documents-modified-index"
    hash_key        = "SK"
    range_key       = "modified"
    projection_type = "ALL"
  }

  # GSI for listing all documents by created date
  global_secondary_index {
    name            = "all-documents-created-index"
    hash_key        = "SK"
    range_key       = "created"
    projection_type = "ALL"
  }

  # GSI for tag-based queries
  global_secondary_index {
    name            = "tag-index"
    hash_key        = "tag_name"
    range_key       = "SK"
    projection_type = "ALL"
  }

  # GSI for classification-based queries
  global_secondary_index {
    name            = "classification-index"
    hash_key        = "classification"
    range_key       = "modified"
    projection_type = "ALL"
  }

  # GSI for entity-based queries
  global_secondary_index {
    name            = "entity-index"
    hash_key        = "entity_key"
    range_key       = "SK"
    projection_type = "ALL"
  }

  # GSI for search monitor schedule polling
  global_secondary_index {
    name            = "search-schedule-index"
    hash_key        = "monitor_status"
    range_key       = "next_execution"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-metadata"
  }
}
