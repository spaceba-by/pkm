# Privacy Policy for PKM Reader

**Last updated:** [DATE]

## Overview

PKM Reader ("the App") is a mobile application that provides read access to your personal knowledge management system. This privacy policy explains how the App handles your data.

## Data Collection

### Data You Provide

- **Authentication credentials**: Your email and password are used to authenticate with AWS Cognito. Credentials are stored securely in the iOS Keychain and are never transmitted to any party other than the authentication service.

### Data Processed Automatically

- **Document content**: The App retrieves your documents from the PKM backend API. Document content is cached locally on your device for offline access.
- **AI-generated insights**: Daily summaries and weekly reports are generated server-side by Amazon Bedrock and retrieved by the App. No document content is sent to third-party AI services; all processing uses your own AWS account.

### Data We Do Not Collect

- We do not collect analytics or usage data.
- We do not use third-party tracking or advertising SDKs.
- We do not collect device identifiers for advertising purposes.
- We do not share any data with third parties.

## Data Storage

- **On-device**: Cached documents and authentication tokens are stored locally using iOS Keychain and the app sandbox. Data is encrypted at rest by iOS Data Protection.
- **Server-side**: Your documents and metadata are stored in AWS S3 and DynamoDB within your own AWS account. All data is encrypted at rest and in transit.

## Data Retention

- Cached data on device is cleared when you sign out or clear the cache in Settings.
- Server-side data retention is controlled by you through your AWS account.

## Third-Party Services

The App uses the following services, all within your own AWS account:

- **AWS Cognito** for authentication
- **AWS API Gateway** for API access
- **Amazon S3** for document storage
- **Amazon DynamoDB** for metadata storage
- **Amazon Bedrock** for AI-powered classification and summaries

No data is shared with third parties outside of your own AWS infrastructure.

## Your Rights

You have full control over your data:

- **Access**: All your data is accessible through the App and your AWS account.
- **Deletion**: You can delete cached data through the App settings. Server-side data can be deleted through your AWS account.
- **Portability**: Your documents remain in standard Markdown format in your S3 bucket.

## Security

- All network communication uses TLS encryption.
- Authentication tokens are stored in the iOS Keychain.
- The App does not store passwords.

## Children's Privacy

The App is not directed at children under 13 and does not knowingly collect data from children.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted in the App and on our website.

## Contact

For questions about this privacy policy, please contact us at:

- Email: [SUPPORT_EMAIL]
- Website: https://spaceba.by/support
