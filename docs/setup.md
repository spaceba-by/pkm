# PKM Agent System Setup Guide

This guide walks you through setting up the PKM Agent System on AWS.

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **Terraform** >= 1.5.0 installed
4. **Python** 3.12 or later
5. **rclone** for vault synchronization
6. **jq** for JSON processing (optional but recommended)

### Installing Prerequisites

#### macOS

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install awscli terraform python@3.12 rclone jq
```

#### Linux

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# rclone
curl https://rclone.org/install.sh | sudo bash

# jq
sudo apt install jq
```

#### Windows

1. Install [AWS CLI](https://aws.amazon.com/cli/)
2. Install [Terraform](https://www.terraform.io/downloads)
3. Install [Python](https://www.python.org/downloads/)
4. Install [rclone](https://rclone.org/downloads/)
5. Install [jq](https://stedolan.github.io/jq/download/)

## Step 1: AWS Configuration

### Configure AWS Credentials

```bash
aws configure
```

Provide:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

### Verify AWS Access

```bash
aws sts get-caller-identity
```

### Enable Bedrock Access

Amazon Bedrock requires explicit model access:

1. Go to AWS Console → Amazon Bedrock
2. Navigate to "Model access" in the left sidebar
3. Click "Manage model access"
4. Enable access to:
   - Claude 3 Haiku
   - Claude 3.5 Sonnet
5. Wait for access to be granted (usually instant)

Verify access:

```bash
aws bedrock list-foundation-models --region us-east-1 --query 'modelSummaries[?contains(modelId, `claude`)].modelId'
```

## Step 2: Clone and Configure Repository

```bash
git clone <repository-url>
cd pkm-agent-system
```

## Step 3: Choose S3 Bucket Name

Your S3 bucket name must be:
- Globally unique across all AWS accounts
- 3-63 characters long
- Lowercase letters, numbers, and hyphens only
- No underscores or periods

Example: `my-pkm-vault-12345`

## Step 4: Deploy Infrastructure

Run the deployment script:

```bash
cd scripts
./deploy.sh
```

The script will:
1. Validate Terraform configuration
2. Show deployment plan
3. Ask for confirmation
4. Deploy all AWS resources
5. Display outputs

This creates:
- S3 bucket for vault storage
- DynamoDB table for metadata
- 6 Lambda functions for processing
- EventBridge rules for scheduling
- Step Functions for workflows
- CloudWatch dashboards and alarms
- IAM roles and policies

**Deployment time:** ~5-10 minutes

## Step 5: Set Up Vault Sync

Configure bidirectional sync between local vault and S3:

```bash
./setup-sync.sh
```

Follow the prompts to:
1. Configure rclone remote
2. Specify local vault path
3. Test S3 connection
4. Initialize bisync
5. Set up automatic sync (every 5 minutes)

## Step 6: Verify Deployment

Test the system with a sample document:

```bash
./test-workflow.sh
```

This will:
1. Upload a test markdown document
2. Wait for processing
3. Verify metadata in DynamoDB
4. Check CloudWatch logs
5. List agent-generated outputs

## Step 7: Create Initial Vault Structure

Create a basic vault structure in your local vault:

```bash
cd /path/to/your/vault

mkdir -p daily projects reference ideas meetings
mkdir -p _agent/{summaries,reports,entities,classifications}

# Create a sample document
cat > daily/2026-01-11.md << 'EOF'
---
title: Daily Notes
date: 2026-01-11
tags: [daily, journal]
---

# January 11, 2026

Today I set up my PKM agent system. Excited to see automated summaries and entity extraction in action!

## Tasks
- [x] Deploy infrastructure
- [x] Configure sync
- [ ] Add more documents
EOF
```

Wait 5 minutes for sync to run, then check S3:

```bash
aws s3 ls s3://YOUR-BUCKET-NAME/daily/
```

## Configuration Options

### Customizing Schedules

Edit `terraform/variables.tf` to change schedules:

```hcl
variable "daily_summary_schedule" {
  default = "cron(0 6 * * ? *)"  # 6 AM UTC daily
}

variable "weekly_report_schedule" {
  default = "cron(0 20 ? * SUN *)"  # 8 PM UTC Sundays
}
```

Then redeploy:

```bash
cd terraform
terraform apply
```

### Adjusting Lambda Memory/Timeout

Edit `terraform/lambda.tf` to modify Lambda configurations:

```hcl
resource "aws_lambda_function" "classify_document" {
  timeout     = 30      # Increase if needed
  memory_size = 512     # Increase for better performance
  # ...
}
```

### Changing Bedrock Models

Edit `terraform/variables.tf`:

```hcl
variable "bedrock_haiku_model_id" {
  default = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "bedrock_sonnet_model_id" {
  default = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
```

## Troubleshooting

### Issue: "Access Denied" when deploying

**Solution:** Verify IAM permissions. Your AWS user needs:
- S3: Full access
- DynamoDB: Full access
- Lambda: Full access
- IAM: Role creation
- EventBridge: Full access
- Step Functions: Full access
- CloudWatch: Full access
- Bedrock: InvokeModel

### Issue: Bedrock "ModelNotFound" error

**Solution:** Enable model access in Bedrock console (see Step 1).

### Issue: Lambda timeout errors

**Solution:** Increase Lambda timeout in `terraform/lambda.tf` and redeploy.

### Issue: Sync not working

**Solution:**
1. Verify rclone config: `rclone config show`
2. Test connection: `rclone lsd pkm-s3:BUCKET_NAME`
3. Check logs:
   - macOS: `cat ~/.pkm-sync-error.log`
   - Linux: `journalctl --user -u pkm-sync.service`

### Issue: No agent outputs in S3

**Solution:**
1. Check CloudWatch logs for errors
2. Verify EventBridge rules are enabled
3. Ensure S3 bucket has EventBridge notifications enabled
4. Check Lambda execution role permissions

## Monitoring and Maintenance

### View CloudWatch Dashboard

```bash
# Get dashboard URL from Terraform outputs
terraform output cloudwatch_dashboard_url
```

Or navigate to: CloudWatch Console → Dashboards → pkm-agent-dashboard

### Check Lambda Logs

```bash
# List recent invocations
aws logs tail /aws/lambda/pkm-agent-classify-document --follow

# View all Lambda logs
aws logs tail /aws/lambda/pkm-agent-* --follow
```

### Monitor Costs

View current month's costs:

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "1 day ago" +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

Expected monthly costs (for 50-100 docs/month):
- S3: $0.50
- DynamoDB: $1-2
- Lambda: $2-5
- Bedrock: $10-15
- **Total: ~$15-20/month**

## Next Steps

1. **Add Documents:** Start adding markdown files to your vault
2. **Review Classifications:** Check `_agent/classifications/index.md`
3. **Explore Entities:** Browse `_agent/entities/` for extracted entities
4. **Read Summaries:** Daily summaries in `_agent/summaries/`
5. **Weekly Reviews:** Weekly reports in `_agent/reports/weekly/`

## Updating the System

To update Lambda functions or infrastructure:

```bash
cd scripts
./deploy.sh
```

Terraform will show what changed and ask for confirmation.

## Uninstalling

To remove all resources:

```bash
cd terraform
terraform destroy

# Stop sync service
# macOS:
launchctl stop com.pkm.sync
launchctl unload ~/Library/LaunchAgents/com.pkm.sync.plist

# Linux:
systemctl --user stop pkm-sync.timer
systemctl --user disable pkm-sync.timer
```

**Warning:** This will delete all data in S3 and DynamoDB. Back up your vault first!

## Support

- Issues: GitHub Issues
- Documentation: `/docs` directory
- Architecture: `docs/architecture.md`
- Sync Guide: `docs/sync-guide.md`
