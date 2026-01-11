# DynamoDB table for PKM metadata
resource "aws_dynamodb_table" "metadata" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "PK"
  range_key      = "SK"

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
