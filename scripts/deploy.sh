#!/bin/bash

# PKM Agent System Deployment Script
# This script deploys the infrastructure and Lambda functions using Terraform

set -e

echo "======================================"
echo "PKM Agent System Deployment"
echo "======================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    exit 1
fi

echo "✓ All prerequisites met"
echo ""

# Get bucket name from user if not set
if [ -z "$S3_BUCKET_NAME" ]; then
    echo "Enter your S3 bucket name (must be globally unique):"
    read -r S3_BUCKET_NAME
fi

if [ -z "$S3_BUCKET_NAME" ]; then
    echo "Error: S3 bucket name is required"
    exit 1
fi

# Get AWS region
if [ -z "$AWS_REGION" ]; then
    AWS_REGION=$(aws configure get region)
    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="us-east-1"
    fi
    echo "Using AWS region: $AWS_REGION"
fi

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

echo ""
echo "======================================"
echo "Step 1: Initialize Terraform"
echo "======================================"
terraform init

echo ""
echo "======================================"
echo "Step 2: Validate Terraform"
echo "======================================"
terraform validate

echo ""
echo "======================================"
echo "Step 3: Plan deployment"
echo "======================================"
terraform plan \
    -var="s3_bucket_name=$S3_BUCKET_NAME" \
    -var="aws_region=$AWS_REGION" \
    -out=tfplan

echo ""
echo "======================================"
echo "Step 4: Apply deployment"
echo "======================================"
echo "Review the plan above."
echo "Do you want to proceed with deployment? (yes/no)"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

terraform apply tfplan

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Run ./setup-sync.sh to configure rclone sync"
echo "2. Upload some markdown files to test the system"
echo "3. Check CloudWatch logs to verify processing"
echo ""

# Save outputs to file
terraform output -json > ../outputs.json
echo "Terraform outputs saved to outputs.json"

echo ""
echo "S3 Bucket: $S3_BUCKET_NAME"
echo "Region: $AWS_REGION"
echo ""
