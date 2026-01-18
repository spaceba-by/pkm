# PKM Agent System

An intelligent, serverless AWS system for automating Personal Knowledge Management (PKM) workflows. Automatically classifies documents, extracts entities, and generates daily summaries and weekly reports from your markdown vault.

## Features

- **Automatic Classification:** Categorizes documents as meetings, ideas, references, journals, or projects
- **Entity Extraction:** Identifies people, organizations, concepts, and locations
- **Daily Summaries:** Generates concise summaries of each day's activity (runs at 6 AM UTC)
- **Weekly Reports:** Creates comprehensive weekly reviews with themes and follow-ups
- **Bidirectional Sync:** Seamlessly syncs between local vault and AWS S3
- **Obsidian Compatible:** Works with standard Obsidian vault structure
- **Cost Effective:** ~$15-20/month for typical usage (50-100 docs/month)

## Architecture

```
Local Vault ↔ rclone ↔ S3 → EventBridge → Lambda → Bedrock
                        │                    │
                        └────────────────────┴──→ DynamoDB
                                                  │
Agent Outputs ← rclone ←────────────────────────┘
```

**AWS Services Used:**
- **S3:** Vault storage (source of truth)
- **DynamoDB:** Metadata and entity index
- **Lambda:** 6 serverless functions for processing
- **Bedrock:** Claude 3 models for AI capabilities
- **EventBridge:** Event routing and scheduling
- **Step Functions:** Workflow orchestration
- **CloudWatch:** Monitoring and logging

## Quick Start

### Prerequisites

- AWS Account with Bedrock access
- AWS CLI configured
- Terraform >= 1.5.0
- [Babashka](https://github.com/babashka/babashka) >= 1.3.0
- rclone

### Installation

```bash
# 1. Clone repository
git clone <repository-url>
cd pkm-agent-system

# 2. Deploy infrastructure
cd scripts
./deploy.sh

# 3. Set up vault sync
./setup-sync.sh

# 4. Test the system
./test-workflow.sh
```

**Total setup time:** ~15 minutes

## Documentation

- **[Setup Guide](docs/setup.md)** - Complete installation and configuration
- **[Architecture](docs/architecture.md)** - Technical architecture and design
- **[Sync Guide](docs/sync-guide.md)** - Vault synchronization setup
- **[Prompts](docs/prompts.md)** - Bedrock prompt templates
- **[PRD](pkm-agent-system-prd.md)** - Complete product requirements

## Usage

### Creating Documents

Create markdown files in your local vault:

```markdown
---
title: Daily Notes
date: 2026-01-11
tags: [daily, journal]
---

# January 11, 2026

Today I worked on...

## Tasks
- [x] Deploy PKM agent
- [ ] Write first summary
```

### Automatic Processing

1. **Save file** → Syncs to S3 within 5 minutes
2. **S3 triggers processing:**
   - Classification (meeting/idea/reference/journal/project)
   - Entity extraction (people, orgs, concepts, locations)
   - Metadata parsing (tags, links, frontmatter)
3. **Results stored** in DynamoDB and S3
4. **Agent outputs** sync back to local `_agent/` directory

### Generated Outputs

Check the `_agent/` directory for:

```
_agent/
├── summaries/           # Daily summaries
│   └── 2026-01-11.md
├── reports/             # Weekly reports
│   └── weekly/
│       └── 2026-W02.md
├── entities/            # Extracted entities
│   ├── people/
│   │   └── alice.md
│   ├── organizations/
│   │   └── acme-corp.md
│   └── concepts/
│       └── machine-learning.md
└── classifications/     # Document index
    └── index.md
```

## Repository Structure

```
pkm-agent-system/
├── README.md              # This file
├── pkm-agent-system-prd.md  # Product requirements
├── docs/                  # Documentation
│   ├── setup.md
│   ├── architecture.md
│   ├── sync-guide.md
│   └── prompts.md
├── terraform/             # Infrastructure as Code
│   ├── main.tf
│   ├── s3.tf
│   ├── dynamodb.tf
│   ├── lambda.tf
│   ├── eventbridge.tf
│   ├── stepfunctions.tf
│   ├── iam.tf
│   ├── cloudwatch.tf
│   ├── variables.tf
│   └── outputs.tf
├── lambda/                # Lambda functions (Babashka/Clojure)
│   ├── bb.edn             # Babashka configuration
│   ├── deps.edn           # Clojure dependencies
│   ├── shared/            # Shared utilities
│   │   ├── aws/
│   │   │   ├── bedrock.clj
│   │   │   ├── dynamodb.clj
│   │   │   ├── s3.clj
│   │   │   └── lambda.clj
│   │   └── markdown/
│   │       └── utils.clj
│   ├── functions/         # Individual lambda functions
│   │   ├── classify_document/
│   │   ├── extract_entities/
│   │   ├── extract_metadata/
│   │   ├── generate_daily_summary/
│   │   ├── generate_weekly_report/
│   │   └── update_classification_index/
│   └── tests/             # Babashka tests
├── stepfunctions/         # Step Functions workflows
│   └── weekly_report_workflow.json
├── scripts/               # Deployment and setup scripts
│   ├── deploy.sh
│   ├── setup-sync.sh
│   └── test-workflow.sh
└── sync/                  # Sync configuration
    ├── rclone.conf.template
    ├── com.pkm.sync.plist.template
    └── README.md
```

## Configuration

### Customize Schedules

Edit `terraform/variables.tf`:

```hcl
variable "daily_summary_schedule" {
  default = "cron(0 6 * * ? *)"  # 6 AM UTC
}

variable "weekly_report_schedule" {
  default = "cron(0 20 ? * SUN *)"  # 8 PM UTC Sunday
}
```

### Adjust Lambda Resources

Edit `terraform/lambda.tf`:

```hcl
resource "aws_lambda_function" "classify_document" {
  timeout     = 30
  memory_size = 512
}
```

### Change AI Models

Edit `terraform/variables.tf`:

```hcl
variable "bedrock_haiku_model_id" {
  default = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "bedrock_sonnet_model_id" {
  default = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
```

## Monitoring

### CloudWatch Dashboard

```bash
# Get dashboard URL
cd terraform
terraform output cloudwatch_dashboard_url
```

### View Lambda Logs

```bash
# Tail logs for all functions
aws logs tail /aws/lambda/pkm-agent-* --follow

# Specific function
aws logs tail /aws/lambda/pkm-agent-classify-document --follow
```

### Check Sync Status

```bash
# macOS
tail -f ~/.pkm-sync.log

# Linux
journalctl --user -u pkm-sync.service -f
```

## Cost Breakdown

**Estimated monthly cost for 100 documents:**

| Service | Cost |
|---------|------|
| S3 Storage & Requests | $0.50 |
| DynamoDB (on-demand) | $1.50 |
| Lambda Invocations | $3.00 |
| Bedrock (Haiku) | $0.50 |
| Bedrock (Sonnet) | $5.00 |
| CloudWatch | $2.00 |
| EventBridge | $0.10 |
| **Total** | **~$12.60** |

**Scales linearly:** ~$25/month for 200 docs, ~$50/month for 500 docs

## Troubleshooting

### Issue: Bedrock "Access Denied"

**Solution:** Enable model access in Bedrock console
```bash
# Navigate to AWS Console → Amazon Bedrock → Model access
# Enable Claude 3 Haiku and Claude 3.5 Sonnet
```

### Issue: Sync Not Working

**Solution:**
```bash
# Test rclone connection
rclone lsd pkm-s3:BUCKET_NAME

# Check AWS credentials
aws sts get-caller-identity

# Reinitialize sync
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME --resync
```

### Issue: No Agent Outputs

**Solution:**
1. Check CloudWatch logs for errors
2. Verify EventBridge rules are enabled
3. Test Lambda manually:
   ```bash
   aws lambda invoke \
     --function-name pkm-agent-classify-document \
     --payload '{"test": "event"}' \
     response.json
   ```

## Development

### Running Tests

```bash
# Run all tests with Babashka
cd lambda
bb test
```

### Local Development

```bash
# Start REPL for interactive development
cd lambda
bb repl

# Test utilities in REPL
(require '[markdown.utils :as md])
(md/extract-frontmatter "---\ntitle: Test\n---\nContent")
```

### Updating Infrastructure

```bash
cd terraform
terraform plan
terraform apply
```

## Roadmap

- [x] Core document processing
- [x] Daily summaries
- [x] Weekly reports
- [x] Entity extraction
- [x] Classification index
- [ ] Semantic search with OpenSearch
- [ ] Interactive chat interface
- [ ] Task extraction and tracking
- [ ] Knowledge graph visualization
- [ ] Email/calendar integration
- [ ] Mobile app for capture

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

- **Documentation:** See `/docs` directory
- **Issues:** GitHub Issues
- **Questions:** GitHub Discussions

## Acknowledgments

- Built with [Amazon Bedrock](https://aws.amazon.com/bedrock/)
- Inspired by [Obsidian](https://obsidian.md/)
- Sync powered by [rclone](https://rclone.org/)

---

**Created with Claude Code** | [View PRD](pkm-agent-system-prd.md)
