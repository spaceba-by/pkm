# Task 0006: iOS App Core Scaffold

**Status**: Complete

## Specifications

iOS Phase 2: Implement the core iOS app with authentication, API integration, and document browsing. Includes Cognito auth flow, API client with token management, SwiftUI views with MVVM architecture, SwiftData caching, and comprehensive test coverage.

## Relevant Files

- `ios/PKMReader/Services/AuthService.swift` - Cognito authentication via AWS Amplify
- `ios/PKMReader/Services/APIClient.swift` - HTTP client with JWT token management
- `ios/PKMReader/Services/KeychainService.swift` - Secure token storage
- `ios/PKMReader/Services/CacheService.swift` - SwiftData-based response caching
- `ios/PKMReader/Models/` - Document, Summary, Report, Classification models
- `ios/PKMReader/Views/Auth/` - Login and authentication views
- `ios/PKMReader/Views/Documents/` - Document list and detail views
- `ios/PKMReader/Views/Components/` - Shared UI components
- `ios/PKMReader/ViewModels/` - MVVM view models
- `ios/PKMReader/Navigation/` - App navigation and root view
- `ios/PKMReaderTests/` - Unit tests
- `ios/PKMReaderUITests/` - UI tests for auth and document flows

## Acceptance Criteria

- [x] User can sign in with Cognito credentials
- [x] User can sign out
- [x] Document list loads and displays from API
- [x] Document list can be filtered by classification
- [x] Document detail view shows content with markdown rendering
- [x] Pull-to-refresh works on document list
- [x] Pagination loads more documents
- [x] Error states display appropriately
- [x] Empty states display appropriately
- [x] App persists auth state across launches
- [x] All unit tests pass
- [x] All UI tests pass
- [x] Code coverage ≥70%
- [x] No SwiftLint errors
- [x] CI pipeline passes

## Implementation Steps

- [x] Step 1: Add AWS Amplify dependency and configure authentication
- [x] Step 2: Implement `AuthService` with sign-in, sign-out, and session management
- [x] Step 3: Implement `APIClient` with JWT token injection and error handling
- [x] Step 4: Implement `KeychainService` for secure token storage
- [x] Step 5: Create data models (Document, Summary, Report, ClassificationCount)
- [x] Step 6: Build authentication views (LoginView, AuthenticatedView)
- [x] Step 7: Build document list view with classification filtering
- [x] Step 8: Build document detail view with markdown rendering
- [x] Step 9: Implement MVVM view models with async data loading
- [x] Step 10: Add SwiftData caching layer
- [x] Step 11: Set up app navigation and root view
- [x] Step 12: Write unit tests for services and view models
- [x] Step 13: Write UI tests for auth and document browsing flows

## Summary of Changes

- Integrated AWS Amplify for Cognito authentication
- Implemented `AuthService` with sign-in, sign-out, token refresh, and session persistence
- Built `APIClient` with automatic JWT injection, retry logic, and error handling
- Created `KeychainService` for secure credential storage
- Implemented `CacheService` using SwiftData for offline document caching
- Built complete MVVM architecture with reactive view models
- Created SwiftUI views for login, document list (with classification filter), and document detail (with markdown rendering)
- Added pull-to-refresh and pagination support
- Created shared UI components for loading, error, and empty states
- Wrote unit tests for services and view models
- Wrote UI tests covering login flow and document browsing
- Achieved ≥70% code coverage with all CI checks passing
- Key commit: `f1f2068` (#20)
