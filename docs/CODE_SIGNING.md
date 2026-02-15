# Code Signing Guide for PKMReader

This document describes how to configure code signing for the PKMReader iOS app using Fastlane Match.

## Overview

PKMReader uses [Fastlane Match](https://docs.fastlane.tools/actions/match/) to manage certificates and provisioning profiles. Match stores signing credentials in a private Git repository, ensuring all developers and CI share the same profiles.

**App Details:**
- Bundle ID: `by.spaceba.pkm.reader`
- Team ID: `TPXD65QGEQ`
- Signing style: Automatic (development), Match (CI/release)

## Prerequisites

- Apple Developer Program membership
- Access to the Match certificates Git repository
- Fastlane installed (`bundle install` in `ios/`)

## Match Git Repository Setup

1. Create a **private** Git repository to store certificates (e.g., `github.com/your-org/pkm-certificates`).

2. Set the `MATCH_GIT_URL` environment variable or update `ios/fastlane/Matchfile`:
   ```
   git_url("https://github.com/your-org/pkm-certificates")
   ```

3. Generate certificates and profiles:
   ```bash
   cd ios
   bundle exec fastlane match development
   bundle exec fastlane match appstore
   ```
   Match will prompt for a passphrase to encrypt the repository. Store this passphrase securely.

## Environment Variables

### Local Development

For local builds, Xcode Automatic signing (configured in `project.yml`) handles code signing. No additional setup is needed for simulator builds.

For device/archive builds, set these in your shell profile or a `.env` file:

| Variable | Description |
|----------|-------------|
| `MATCH_GIT_URL` | URL of the private certificates Git repository |
| `MATCH_PASSWORD` | Passphrase used to encrypt the Match repository |
| `FASTLANE_USER` | Apple ID email address |
| `APPLE_TEAM_ID` | Apple Developer Team ID (`TPXD65QGEQ`) |

### CI/CD (GitHub Secrets)

Configure these secrets in the GitHub repository settings under Settings > Secrets and variables > Actions:

| Secret | Description |
|--------|-------------|
| `MATCH_GIT_URL` | URL of the private certificates Git repository |
| `MATCH_PASSWORD` | Passphrase for the Match encrypted repository |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64-encoded `username:token` for Git auth |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID |
| `ASC_KEY` | App Store Connect API private key contents (p8) |

#### Generating `MATCH_GIT_BASIC_AUTHORIZATION`

This value is a base64-encoded `username:token` string using a GitHub fine-grained PAT. The token expires after 1 year and must be regenerated.

1. Go to https://github.com/settings/tokens?type=beta (fine-grained tokens)
2. Click **Generate new token**
3. **Resource owner**: select `spaceba-by` (the org, not your personal account)
4. **Repository access**: "Only select repositories" → select the certificates repo
5. **Permissions** → Repository permissions → **Contents**: Read and write
6. Generate the token
7. If the org requires approval, an org admin must approve at `https://github.com/organizations/spaceba-by/settings/personal-access-tokens/active`
8. Base64-encode using your **personal GitHub username** (not the org name):
   ```bash
   echo -n "your-github-username:github_pat_xxxxx" | base64
   ```

#### Generating App Store Connect API key secrets

`ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY` all come from the same API key:

1. Go to https://appstoreconnect.apple.com/access/integrations/api
2. Click **Generate API Key**
3. Name it (e.g., "CI TestFlight"), set role to **App Manager**
4. After creation:
   - **`ASC_KEY_ID`**: the Key ID shown in the table
   - **`ASC_ISSUER_ID`**: shown at the top of the API Keys page
   - **`ASC_KEY`**: download the `.p8` file (one-time download), then base64-encode it:
     ```bash
     base64 < AuthKey_XXXXXXXXXX.p8
     ```

#### Secret rotation schedule

| Secret | Rotation | How to regenerate |
|--------|----------|-------------------|
| `MATCH_GIT_BASIC_AUTHORIZATION` | Annually (PAT expiry) | Repeat steps above with a new fine-grained PAT |
| `MATCH_PASSWORD` | Only if compromised | Re-run `fastlane match` with new passphrase, update all developers |
| `ASC_KEY` | Does not expire | Only regenerate if key is revoked |

## New Developer Onboarding

1. Clone the project and install dependencies:
   ```bash
   cd ios
   bundle install
   xcodegen generate
   ```

2. For simulator development, no signing setup is needed. Xcode Automatic signing handles it.

3. For device builds, obtain the Match passphrase from the team and set environment variables:
   ```bash
   export MATCH_GIT_URL="https://github.com/your-org/pkm-certificates"
   export MATCH_PASSWORD="<passphrase>"
   ```

4. Download existing certificates (read-only mode, will not create new ones):
   ```bash
   cd ios
   bundle exec fastlane match development --readonly
   bundle exec fastlane match appstore --readonly
   ```

5. Open `PKMReader.xcodeproj` in Xcode. The signing certificates should be available automatically.

## Regenerating Certificates

If certificates expire or are revoked:

1. **Nuke existing certificates** (requires write access to the Match repo):
   ```bash
   cd ios
   bundle exec fastlane match nuke development
   bundle exec fastlane match nuke distribution
   ```

2. **Generate new certificates**:
   ```bash
   bundle exec fastlane match development
   bundle exec fastlane match appstore
   ```

3. **Notify all developers** to re-download:
   ```bash
   bundle exec fastlane match development --readonly
   bundle exec fastlane match appstore --readonly
   ```

4. **Update CI secrets** if the Match passphrase changed.

## CI/CD Code Signing

The `ios-build.yml` workflow automatically detects whether signing secrets are configured:

- **Without secrets**: builds an unsigned simulator binary (safe default)
- **With secrets**: builds a signed archive and uploads to TestFlight

To enable signed builds and TestFlight deployment:

1. Set up all required GitHub Secrets listed above.
2. Optionally create a `testflight` GitHub Environment (Settings → Environments) for deployment protection rules.
3. Push a change to `ios/` on `main` to trigger the workflow.

See the `build_release` lane in `ios/fastlane/Fastfile` for the signing logic. The lane:
- Increments the build number
- Syncs certificates via Match (readonly in CI)
- Switches the PKMReader target to manual signing via `update_code_signing_settings` (SPM packages keep automatic signing)
- Builds a signed IPA to `ios/build/PKMReader.ipa`

## Fastlane Configuration Files

| File | Purpose |
|------|---------|
| `ios/fastlane/Appfile` | App identifier and team configuration |
| `ios/fastlane/Matchfile` | Match storage mode, types, and app identifiers |
| `ios/fastlane/Fastfile` | Build and deployment lanes |

## Troubleshooting

**"No matching provisioning profiles found"**
- Run `bundle exec fastlane match development --readonly` to download profiles.
- Verify your Apple ID is part of the team.

**"Could not create a new signing request"**
- Check that `MATCH_PASSWORD` is correct.
- Ensure you have network access to the Match Git repository.

**CI build fails with signing error**
- Verify all GitHub Secrets are configured.
- Check that the App Store Connect API key has not expired.
- Ensure the Match repository is accessible with `MATCH_GIT_BASIC_AUTHORIZATION`.

**"Code signing is required for product type 'Application'"**
- For simulator-only builds, pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`.
- For device/archive builds, ensure Match certificates are installed.
