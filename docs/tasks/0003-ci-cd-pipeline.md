# Task 0003: CI/CD Pipeline

**Status**: Complete

## Specifications

Set up continuous integration and deployment pipelines using GitHub Actions. Includes automated Lambda build/test, Terraform plan/apply, and supporting IAM infrastructure for GitHub OIDC authentication.

## Relevant Files

- `.github/workflows/build.yml` - Lambda build pipeline
- `.github/workflows/test.yml` - Lambda test pipeline
- `terraform/iam.tf` - GitHub Actions OIDC role and policies
- `terraform/s3_artifacts.tf` - Lambda artifact storage bucket
- `scripts/deploy.sh` - Deployment script

## Acceptance Criteria

- [x] GitHub Actions workflow builds all Lambda functions on push
- [x] GitHub Actions workflow runs unit tests on push/PR
- [x] Terraform plan runs automatically on PRs
- [x] Terraform apply deploys automatically on merge to main
- [x] GitHub OIDC authentication for AWS access (no static credentials)
- [x] Lambda artifacts uploaded to S3 for deployment
- [x] State lock conflicts handled gracefully in CI

## Implementation Steps

- [x] Step 1: Create GitHub Actions workflow for Lambda build
- [x] Step 2: Create GitHub Actions workflow for Lambda tests
- [x] Step 3: Configure GitHub OIDC provider in Terraform
- [x] Step 4: Add IAM role and policies for GitHub Actions
- [x] Step 5: Add automatic Terraform deployment pipeline
- [x] Step 6: Configure S3 artifact bucket with lifecycle policies
- [x] Step 7: Fix state lock conflicts in concurrent CI runs
- [x] Step 8: Fix IAM permissions for various AWS services

## Summary of Changes

- Created `build.yml` workflow for building Lambda ZIP artifacts
- Created `test.yml` workflow for running Babashka unit tests
- Added automatic Terraform plan on PRs and apply on merge to main
- Configured GitHub OIDC federation for secure AWS authentication
- Set up S3 artifact bucket with lifecycle rules to clean old builds
- Fixed Terraform state lock conflicts for concurrent pipeline runs
- Iteratively fixed IAM permissions for S3, Lambda, CloudWatch, Step Functions
- Key commits: `458b1c8` (#10, CI/CD pipeline), `c6e5014` (#12, Terraform auto-deploy), `8c6960e` (#14, state lock fix), `41bbed5` (#15, IAM permissions)
