# iOS App Phase 2: iOS App Scaffold - Detailed Implementation Plan

**Status: 🚧 IN PROGRESS**

## Overview

Phase 2 builds the core iOS application scaffold on top of the foundation established in Phase 0 (CI/CD) and Phase 1 (Backend API). This phase delivers:

1. **AWS Amplify Integration** - Cognito authentication with secure token management
2. **Core Service Implementations** - APIClient, AuthService, KeychainService, CacheService
3. **SwiftUI Views** - Login, DocumentList, DocumentDetail, and shared components
4. **Markdown Rendering** - Native markdown display with syntax highlighting
5. **App Navigation** - Authentication flow and tab-based navigation

**Prerequisites**: Phase 0 (Build & Test Automation) and Phase 1 (Backend API) are complete.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Task Breakdown](#task-breakdown)
3. [2.1 Dependencies & Project Configuration](#21-dependencies--project-configuration)
4. [2.2 Authentication Service](#22-authentication-service)
5. [2.3 API Client Implementation](#23-api-client-implementation)
6. [2.4 Keychain Service](#24-keychain-service)
7. [2.5 Cache Service with SwiftData](#25-cache-service-with-swiftdata)
8. [2.6 Shared UI Components](#26-shared-ui-components)
9. [2.7 Authentication Views](#27-authentication-views)
10. [2.8 Document List Feature](#28-document-list-feature)
11. [2.9 Document Detail Feature](#29-document-detail-feature)
12. [2.10 App Navigation & Root View](#210-app-navigation--root-view)
13. [2.11 Additional Models](#211-additional-models)
14. [2.12 Testing](#212-testing)
15. [Deliverables Checklist](#deliverables-checklist)
16. [Implementation Order](#implementation-order)
17. [Exit Criteria](#exit-criteria)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PKMReaderApp                                     │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     RootView                                      │   │
│  │  ┌─────────────────┐     ┌──────────────────────────────────┐   │   │
│  │  │   LoginView     │ OR  │         MainTabView              │   │   │
│  │  │                 │     │  ┌──────────┐ ┌──────────┐       │   │   │
│  │  │                 │     │  │ Documents│ │ Settings │       │   │   │
│  │  └─────────────────┘     │  └──────────┘ └──────────┘       │   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
┌────────────────────────────────┴────────────────────────────────────────┐
│                         ViewModels (@MainActor)                          │
│  LoginViewModel  │  DocumentListViewModel  │  DocumentDetailViewModel   │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
┌────────────────────────────────┴────────────────────────────────────────┐
│                         Services (Protocols)                             │
│  AuthService  │  APIClient  │  KeychainService  │  CacheService         │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  AWS Amplify    │   │   URLSession    │   │   SwiftData     │
│  (Cognito)      │   │   (HTTPS)       │   │   (Local Cache) │
└─────────────────┘   └─────────────────┘   └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Backend (Phase 1)                                │
│  Cognito User Pool  │  API Gateway  │  Lambda Functions  │  DynamoDB    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Task Breakdown

### Sprint Summary

| Task Group | Est. Effort | Priority | Dependencies |
|------------|-------------|----------|--------------|
| 2.1 Dependencies & Project Config | Low | High | None |
| 2.2 Authentication Service | High | High | 2.1 |
| 2.3 API Client | Medium | High | 2.2 |
| 2.4 Keychain Service | Low | High | None |
| 2.5 Cache Service | Medium | Medium | None |
| 2.6 Shared UI Components | Low | High | None |
| 2.7 Authentication Views | Medium | High | 2.2, 2.6 |
| 2.8 Document List Feature | Medium | High | 2.3, 2.6 |
| 2.9 Document Detail Feature | Medium | High | 2.3, 2.6 |
| 2.10 App Navigation | Medium | High | 2.7, 2.8 |
| 2.11 Additional Models | Low | Medium | None |
| 2.12 Testing | High | High | All above |

---

## 2.1 Dependencies & Project Configuration

### 2.1.1 Add Swift Package Dependencies

**Update**: `ios/project.yml`

```yaml
name: PKMReader

options:
  bundleIdPrefix: by.spaceba.pkm
  deploymentTarget:
    iOS: "18.0"
  xcodeVersion: "16.0"
  developmentLanguage: en
  usesTabs: false
  indentWidth: 4
  tabWidth: 4

packages:
  MarkdownUI:
    url: https://github.com/gonzalezreal/swift-markdown-ui
    from: "2.4.0"
  Amplify:
    url: https://github.com/aws-amplify/amplify-swift
    from: "2.40.0"

settings:
  base:
    ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS: YES
    ENABLE_USER_SCRIPT_SANDBOXING: true
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    GENERATE_INFOPLIST_FILE: YES
    CODE_SIGN_IDENTITY: ""
    CODE_SIGNING_REQUIRED: NO
    CODE_SIGNING_ALLOWED: NO
    STRING_CATALOG_GENERATE_SYMBOLS: YES
  configs:
    Debug:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG
      DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
    Release:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: ""
      DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
      SWIFT_OPTIMIZATION_LEVEL: -O

targets:
  PKMReader:
    type: application
    platform: iOS
    sources:
      - path: PKMReader
        excludes:
          - "**/.DS_Store"
    settings:
      base:
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        PRODUCT_BUNDLE_IDENTIFIER: by.spaceba.pkm.reader
        PRODUCT_NAME: PKMReader
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/Frameworks"
        ENABLE_PREVIEWS: YES
    dependencies:
      - package: MarkdownUI
      - package: Amplify
        product: Amplify
      - package: Amplify
        product: AWSCognitoAuthPlugin

  # ... rest of targets unchanged
```

### 2.1.2 Create Amplify Configuration

**File**: `ios/PKMReader/Resources/amplifyconfiguration.json`

```json
{
    "UserAgent": "aws-amplify-cli/0.1.0",
    "Version": "1.0",
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "1.0",
                "IdentityManager": {
                    "Default": {}
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "COGNITO_USER_POOL_ID",
                        "AppClientId": "COGNITO_CLIENT_ID",
                        "Region": "us-east-1"
                    }
                },
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "PoolId": "COGNITO_IDENTITY_POOL_ID",
                            "Region": "us-east-1"
                        }
                    }
                },
                "Auth": {
                    "Default": {
                        "authenticationFlowType": "USER_SRP_AUTH"
                    }
                }
            }
        }
    }
}
```

> **Note**: Replace placeholder values with actual Terraform outputs:
> - `COGNITO_USER_POOL_ID` → `terraform output cognito_user_pool_id`
> - `COGNITO_CLIENT_ID` → `terraform output cognito_client_id`
> - `COGNITO_IDENTITY_POOL_ID` → `terraform output cognito_identity_pool_id`

### 2.1.3 Update Environment Configuration

**Update**: `ios/PKMReader/Core/Configuration/Environment.swift`

```swift
import Foundation

/// Environment configuration for the PKMReader app.
/// These are PUBLIC identifiers, not secrets.
enum Environment {
    #if DEBUG
    // Development environment
    // swiftlint:disable:next force_unwrapping
    static let apiBaseURL = URL(string: "https://api-dev.pkm.spaceba.by")!
    static let cognitoUserPoolId = "us-east-1_XXXXXXXXX"  // From terraform output
    static let cognitoClientId = "xxxxxxxxxxxxxxxxxxxxx"  // From terraform output
    static let cognitoIdentityPoolId = "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    #else
    // Production environment
    // swiftlint:disable:next force_unwrapping
    static let apiBaseURL = URL(string: "https://api.pkm.spaceba.by")!
    static let cognitoUserPoolId = "us-east-1_YYYYYYYYY"
    static let cognitoClientId = "yyyyyyyyyyyyyyyyyyyyy"
    static let cognitoIdentityPoolId = "us-east-1:yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
    #endif

    static let cognitoRegion = "us-east-1"

    /// App version from bundle
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Build number from bundle
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
```

---

## 2.2 Authentication Service

### 2.2.1 Implement AuthService

**File**: `ios/PKMReader/Core/Auth/AuthService.swift`

```swift
import Amplify
import AWSCognitoAuthPlugin
import Foundation

/// Manages authentication state and operations using AWS Cognito via Amplify
actor AuthService: AuthServiceProtocol {
    /// Shared instance for app-wide use
    static let shared = AuthService()

    /// Published authentication state (observable from MainActor)
    @MainActor
    @Published private(set) var authState: AuthState = .unknown

    private init() {}

    /// Configure Amplify - call once at app startup
    func configure() async throws {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
            await checkAuthStatus()
        } catch {
            await MainActor.run {
                authState = .signedOut
            }
            throw AuthError.unknown("Failed to configure Amplify: \(error.localizedDescription)")
        }
    }

    /// Check current authentication status
    func checkAuthStatus() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            await MainActor.run {
                authState = session.isSignedIn ? .signedIn : .signedOut
            }
        } catch {
            await MainActor.run {
                authState = .signedOut
            }
        }
    }

    var isAuthenticated: Bool {
        get async {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                return session.isSignedIn
            } catch {
                return false
            }
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Amplify.Auth.signIn(username: email, password: password)

            if result.isSignedIn {
                await MainActor.run {
                    authState = .signedIn
                }
            } else if case .confirmSignUp = result.nextStep {
                throw AuthError.accountNotConfirmed
            } else {
                throw AuthError.invalidCredentials
            }
        } catch let error as AuthError {
            throw error
        } catch let authError as Amplify.AuthError {
            throw mapAmplifyError(authError)
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    /// Sign out the current user
    func signOut() async throws {
        _ = await Amplify.Auth.signOut()
        await MainActor.run {
            authState = .signedOut
        }
    }

    /// Get the current access token for API requests
    func getAccessToken() async throws -> String {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()

            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                throw AuthError.notAuthenticated
            }

            let tokens = try cognitoSession.getCognitoTokens().get()
            return tokens.accessToken
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.notAuthenticated
        }
    }

    /// Map Amplify errors to our AuthError type
    private func mapAmplifyError(_ error: Amplify.AuthError) -> AuthError {
        switch error {
        case .notAuthorized:
            return .invalidCredentials
        case .service(_, _, let underlyingError):
            if let cognitoError = underlyingError as? AWSCognitoAuthError {
                switch cognitoError {
                case .userNotFound:
                    return .invalidCredentials
                case .userNotConfirmed:
                    return .accountNotConfirmed
                case .invalidPassword:
                    return .invalidPassword
                case .usernameExists:
                    return .userAlreadyExists
                default:
                    return .unknown(error.localizedDescription)
                }
            }
            return .unknown(error.localizedDescription)
        case .invalidState:
            return .notAuthenticated
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
```

### 2.2.2 Add AuthState Enum

**File**: `ios/PKMReader/Core/Auth/AuthState.swift`

```swift
import Foundation

/// Represents the current authentication state of the app
enum AuthState: Equatable, Sendable {
    /// Initial state before checking authentication
    case unknown

    /// User is signed in
    case signedIn

    /// User is signed out
    case signedOut
}
```

### 2.2.3 Update AuthServiceProtocol

**Update**: `ios/PKMReader/Core/Auth/AuthServiceProtocol.swift`

Add the following extension:

```swift
// Add protocol for observing auth state from views
@MainActor
protocol AuthStateObservable: AnyObject {
    var authState: AuthState { get }
}

extension AuthService: AuthStateObservable {}
```

---

## 2.3 API Client Implementation

### 2.3.1 Implement APIClient

**File**: `ios/PKMReader/Core/Networking/APIClient.swift`

```swift
import Foundation

/// HTTP client for PKM API with authentication
actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let authService: any AuthServiceProtocol
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = Environment.apiBaseURL,
        authService: any AuthServiceProtocol,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.authService = authService
        self.session = session

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - APIClientProtocol

    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("documents"),
            resolvingAgainstBaseURL: false
        )

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let classification {
            queryItems.append(URLQueryItem(name: "classification", value: classification.rawValue))
        }

        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        return try await performRequest(url: url)
    }

    func getDocument(key: String) async throws -> Document {
        guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }

        let url = baseURL.appendingPathComponent("documents/\(encodedKey)")
        return try await performRequest(url: url)
    }

    func search(query: String, limit: Int) async throws -> [Document] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: SearchResponse = try await performRequest(url: url)
        return response.results
    }

    func listTags() async throws -> [Tag] {
        let url = baseURL.appendingPathComponent("tags")
        let response: TagListResponse = try await performRequest(url: url)
        return response.tags
    }

    func listClassifications() async throws -> [ClassificationCount] {
        let url = baseURL.appendingPathComponent("classifications")
        let response: ClassificationListResponse = try await performRequest(url: url)
        return response.classifications
    }

    func listSummaries(limit: Int) async throws -> [Summary] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("summaries"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: SummaryListResponse = try await performRequest(url: url)
        return response.summaries
    }

    func listReports(limit: Int) async throws -> [Report] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("reports"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: ReportListResponse = try await performRequest(url: url)
        return response.reports
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let token = try await authService.getAccessToken()

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Types

struct SearchResponse: Codable, Sendable {
    let query: String
    let results: [Document]
    let count: Int
}

struct TagListResponse: Codable, Sendable {
    let tags: [Tag]
    let count: Int
}

struct ClassificationListResponse: Codable, Sendable {
    let classifications: [ClassificationCount]
}

struct SummaryListResponse: Codable, Sendable {
    let summaries: [Summary]
    let count: Int
}

struct ReportListResponse: Codable, Sendable {
    let reports: [Report]
    let count: Int
}
```

### 2.3.2 Update APIError

**Update**: `ios/PKMReader/Core/Networking/APIError.swift`

```swift
import Foundation

/// Errors that can occur during API requests
enum APIError: Error, Equatable, Sendable {
    /// The URL could not be constructed
    case invalidURL

    /// The response was not a valid HTTP response
    case invalidResponse

    /// HTTP error with status code
    case httpError(statusCode: Int)

    /// Failed to decode the response
    case decodingError(Error)

    /// User is not authenticated (401)
    case unauthorized

    /// Resource not found (404)
    case notFound

    /// Network error
    case networkError(Error)

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.notFound, .notFound):
            true
        case let (.httpError(lhsCode), .httpError(rhsCode)):
            lhsCode == rhsCode
        case (.decodingError, .decodingError),
             (.networkError, .networkError):
            true // Can't easily compare errors
        default:
            false
        }
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse:
            "Invalid server response"
        case .httpError(let statusCode):
            "Server error (\(statusCode))"
        case .decodingError:
            "Failed to process server response"
        case .unauthorized:
            "Please sign in again"
        case .notFound:
            "Document not found"
        case .networkError:
            "Network error. Please check your connection."
        }
    }
}
```

---

## 2.4 Keychain Service

### 2.4.1 Implement KeychainService

**File**: `ios/PKMReader/Core/Auth/KeychainService.swift`

```swift
import Foundation
import Security

/// Service for securely storing sensitive data in the iOS Keychain
final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "by.spaceba.pkm.reader") {
        self.service = service
    }

    func save(_ data: Data, for key: String) throws {
        // Delete existing item first
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func load(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed(status)
        }
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func saveString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(data, for: key)
    }

    func loadString(key: String) throws -> String? {
        guard let data = try load(key: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

/// Errors that can occur during Keychain operations
enum KeychainError: Error, Equatable, Sendable {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
}

extension KeychainError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Failed to save to keychain (status: \(status))"
        case .loadFailed(let status):
            "Failed to load from keychain (status: \(status))"
        case .deleteFailed(let status):
            "Failed to delete from keychain (status: \(status))"
        case .encodingFailed:
            "Failed to encode data"
        }
    }
}
```

### 2.4.2 Update KeychainServiceProtocol

**Update**: `ios/PKMReader/Core/Auth/KeychainServiceProtocol.swift`

```swift
import Foundation

/// Protocol defining the keychain service interface for testability
protocol KeychainServiceProtocol: Sendable {
    /// Save data to the keychain
    func save(_ data: Data, for key: String) throws

    /// Load data from the keychain
    func load(key: String) throws -> Data?

    /// Delete data from the keychain
    func delete(key: String) throws

    /// Save a string to the keychain
    func saveString(_ string: String, for key: String) throws

    /// Load a string from the keychain
    func loadString(key: String) throws -> String?
}
```

---

## 2.5 Cache Service with SwiftData

### 2.5.1 Create SwiftData Models

**File**: `ios/PKMReader/Core/Cache/CachedDocument.swift`

```swift
import Foundation
import SwiftData

/// SwiftData model for caching document metadata locally
@Model
final class CachedDocument {
    /// The unique identifier (S3 key) of the document
    @Attribute(.unique) var id: String

    /// The title of the document
    var title: String

    /// The markdown content (cached on demand)
    var content: String?

    /// Classification as raw string
    var classification: String

    /// Tags as JSON-encoded array
    var tagsJSON: String

    /// When the document was created
    var created: Date

    /// When the document was last modified
    var modified: Date

    /// When this cache entry was last updated
    var cachedAt: Date

    init(from document: Document) {
        self.id = document.id
        self.title = document.title
        self.content = document.content
        self.classification = document.metadata.classification.rawValue
        self.tagsJSON = (try? JSONEncoder().encode(document.metadata.tags))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.created = document.metadata.created
        self.modified = document.metadata.modified
        self.cachedAt = Date()
    }

    /// Convert back to a Document
    func toDocument() -> Document {
        let tags = (try? JSONDecoder().decode(
            [String].self,
            from: tagsJSON.data(using: .utf8) ?? Data()
        )) ?? []

        return Document(
            id: id,
            title: title,
            content: content,
            metadata: DocumentMetadata(
                classification: DocumentClassification(rawValue: classification) ?? .reference,
                tags: tags,
                linksTo: [],
                entities: nil,
                created: created,
                modified: modified,
                hasFrontmatter: false
            )
        )
    }
}
```

### 2.5.2 Implement CacheService

**File**: `ios/PKMReader/Core/Cache/CacheService.swift`

```swift
import Foundation
import SwiftData

/// Service for caching documents locally using SwiftData
@MainActor
final class CacheService: CacheServiceProtocol {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// Maximum age for cached items (in seconds)
    private let maxCacheAge: TimeInterval = 3600 // 1 hour

    init() throws {
        let schema = Schema([CachedDocument.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = modelContainer.mainContext
    }

    /// For testing - use in-memory storage
    init(inMemory: Bool) throws {
        let schema = Schema([CachedDocument.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = modelContainer.mainContext
    }

    func cacheDocuments(_ documents: [Document]) async {
        for document in documents {
            // Check if already cached
            let id = document.id
            let descriptor = FetchDescriptor<CachedDocument>(
                predicate: #Predicate { $0.id == id }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                // Update existing
                existing.title = document.title
                existing.content = document.content
                existing.classification = document.metadata.classification.rawValue
                existing.modified = document.metadata.modified
                existing.cachedAt = Date()
            } else {
                // Insert new
                let cached = CachedDocument(from: document)
                modelContext.insert(cached)
            }
        }

        try? modelContext.save()
    }

    func getCachedDocuments(classification: DocumentClassification?) async -> [Document]? {
        var descriptor = FetchDescriptor<CachedDocument>(
            sortBy: [SortDescriptor(\.modified, order: .reverse)]
        )

        if let classification {
            let classValue = classification.rawValue
            descriptor.predicate = #Predicate { $0.classification == classValue }
        }

        descriptor.fetchLimit = 100

        guard let cached = try? modelContext.fetch(descriptor), !cached.isEmpty else {
            return nil
        }

        // Check if cache is fresh
        let cutoff = Date().addingTimeInterval(-maxCacheAge)
        let freshCache = cached.filter { $0.cachedAt > cutoff }

        guard !freshCache.isEmpty else {
            return nil
        }

        return freshCache.map { $0.toDocument() }
    }

    func getCachedDocument(id: String) async -> Document? {
        let descriptor = FetchDescriptor<CachedDocument>(
            predicate: #Predicate { $0.id == id }
        )

        guard let cached = try? modelContext.fetch(descriptor).first else {
            return nil
        }

        // Check freshness
        let cutoff = Date().addingTimeInterval(-maxCacheAge)
        guard cached.cachedAt > cutoff else {
            return nil
        }

        return cached.toDocument()
    }

    func clearCache() async {
        try? modelContext.delete(model: CachedDocument.self)
        try? modelContext.save()
    }

    func clearStaleCache() async {
        let cutoff = Date().addingTimeInterval(-maxCacheAge)
        let descriptor = FetchDescriptor<CachedDocument>(
            predicate: #Predicate { $0.cachedAt < cutoff }
        )

        if let stale = try? modelContext.fetch(descriptor) {
            for item in stale {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
}
```

### 2.5.3 Update CacheServiceProtocol

**Update**: `ios/PKMReader/Core/Cache/CacheServiceProtocol.swift`

```swift
import Foundation

/// Protocol defining the cache service interface for testability
@MainActor
protocol CacheServiceProtocol: Sendable {
    /// Cache a list of documents
    func cacheDocuments(_ documents: [Document]) async

    /// Get cached documents, optionally filtered by classification
    func getCachedDocuments(classification: DocumentClassification?) async -> [Document]?

    /// Get a single cached document by ID
    func getCachedDocument(id: String) async -> Document?

    /// Clear all cached data
    func clearCache() async

    /// Clear only stale cache entries
    func clearStaleCache() async
}
```

---

## 2.6 Shared UI Components

### 2.6.1 LoadingView

**File**: `ios/PKMReader/Shared/Components/LoadingView.swift`

```swift
import SwiftUI

/// A centered loading indicator with optional message
struct LoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

#Preview {
    LoadingView(message: "Loading documents...")
}
```

### 2.6.2 ErrorView

**File**: `ios/PKMReader/Shared/Components/ErrorView.swift`

```swift
import SwiftUI

/// A view displaying an error with a retry button
struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry") {
                retryAction()
            }
            .buttonStyle(.bordered)
        }
        .accessibilityIdentifier("ErrorView")
    }
}

#Preview {
    ErrorView(error: APIError.networkError(URLError(.notConnectedToInternet))) {
        print("Retry tapped")
    }
}
```

### 2.6.3 EmptyStateView

**File**: `ios/PKMReader/Shared/Components/EmptyStateView.swift`

```swift
import SwiftUI

/// A view displaying an empty state with icon, title, and message
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
        .accessibilityIdentifier("EmptyStateView")
    }
}

#Preview {
    EmptyStateView(
        icon: "doc.text",
        title: "No Documents",
        message: "Your vault is empty"
    )
}
```

### 2.6.4 TagChip

**File**: `ios/PKMReader/Shared/Components/TagChip.swift`

```swift
import SwiftUI

/// A small pill-shaped tag display
struct TagChip: View {
    let tag: String

    var body: some View {
        Text("#\(tag)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Tag: \(tag)")
    }
}

#Preview {
    HStack {
        TagChip(tag: "meeting")
        TagChip(tag: "project")
        TagChip(tag: "idea")
    }
    .padding()
}
```

### 2.6.5 ClassificationBadge

**File**: `ios/PKMReader/Shared/Components/ClassificationBadge.swift`

```swift
import SwiftUI

/// A badge showing the document classification
struct ClassificationBadge: View {
    let classification: DocumentClassification

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: classification.icon)
            Text(classification.displayName)
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(classification.color.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityLabel("Classification: \(classification.displayName)")
    }
}

// Add color property to DocumentClassification
extension DocumentClassification {
    var color: Color {
        switch self {
        case .meeting: .blue
        case .idea: .yellow
        case .reference: .green
        case .journal: .purple
        case .project: .orange
        }
    }
}

#Preview {
    VStack {
        ForEach(DocumentClassification.allCases, id: \.self) { classification in
            ClassificationBadge(classification: classification)
        }
    }
    .padding()
}
```

---

## 2.7 Authentication Views

### 2.7.1 LoginView

**File**: `ios/PKMReader/Features/Auth/LoginView.swift`

```swift
import SwiftUI

/// Login screen for user authentication
struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    init(authService: any AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and title
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.accent)

                        Text("PKM Reader")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Sign in to access your vault")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Login form
                    VStack(spacing: 16) {
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .accessibilityIdentifier("EmailField")

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await viewModel.signIn() } }
                            .accessibilityIdentifier("PasswordField")
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                    // Error message
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .accessibilityIdentifier("ErrorMessage")
                    }

                    // Sign in button
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                    .accessibilityIdentifier("SignInButton")

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    LoginView(authService: MockAuthService())
}
```

### 2.7.2 LoginViewModel

**File**: `ios/PKMReader/Features/Auth/LoginViewModel.swift`

```swift
import Foundation

/// View model for the login screen
@MainActor
final class LoginViewModel: ObservableObject {
    /// User's email address
    @Published var email = ""

    /// User's password
    @Published var password = ""

    /// Whether a sign-in operation is in progress
    @Published private(set) var isLoading = false

    /// Error message to display
    @Published private(set) var error: String?

    /// Whether the form is valid for submission
    var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        email.contains("@")
    }

    private let authService: any AuthServiceProtocol

    init(authService: any AuthServiceProtocol) {
        self.authService = authService
    }

    /// Attempt to sign in with current credentials
    func signIn() async {
        guard isValid else { return }

        isLoading = true
        error = nil

        do {
            try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch let authError as AuthError {
            error = authError.localizedDescription
        } catch {
            error = "An unexpected error occurred"
        }

        isLoading = false
    }
}
```

---

## 2.8 Document List Feature

### 2.8.1 DocumentListView

**File**: `ios/PKMReader/Features/DocumentList/DocumentListView.swift`

```swift
import SwiftUI

/// Main view for displaying the list of documents
struct DocumentListView: View {
    @StateObject private var viewModel: DocumentListViewModel
    @State private var showingFilter = false

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DocumentListViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView(message: "Loading documents...")

                case .loaded(let documents):
                    documentList(documents)

                case .error(let errorMessage):
                    ErrorView(error: APIError.networkError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage]))) {
                        Task { await viewModel.loadDocuments() }
                    }

                case .empty:
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Documents",
                        message: viewModel.selectedClassification != nil
                            ? "No \(viewModel.selectedClassification!.displayName.lowercased()) documents found"
                            : "Your vault is empty"
                    )
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    filterButton
                }
            }
            .sheet(isPresented: $showingFilter) {
                FilterSheet(
                    selectedClassification: $viewModel.selectedClassification,
                    onApply: {
                        Task { await viewModel.loadDocuments() }
                    }
                )
                .presentationDetents([.medium])
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
    }

    private var filterButton: some View {
        Button {
            showingFilter = true
        } label: {
            Image(systemName: viewModel.selectedClassification != nil
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter documents")
        .accessibilityIdentifier("FilterButton")
    }

    private func documentList(_ documents: [Document]) -> some View {
        List {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
                .accessibilityIdentifier("DocumentRow_\(document.id)")
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task {
                        await viewModel.loadNextPage()
                    }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document, apiClient: viewModel.apiClient)
        }
        .accessibilityIdentifier("DocumentList")
    }
}

#Preview {
    DocumentListView(apiClient: MockAPIClient())
}
```

### 2.8.2 DocumentRowView

**File**: `ios/PKMReader/Features/DocumentList/DocumentRowView.swift`

```swift
import SwiftUI

/// A row displaying document information in a list
struct DocumentRowView: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with classification icon
            HStack(spacing: 8) {
                Image(systemName: document.metadata.classification.icon)
                    .foregroundStyle(document.metadata.classification.color)
                    .accessibilityHidden(true)

                Text(document.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
            }

            // Tags
            if !document.metadata.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(document.metadata.tags.prefix(5), id: \.self) { tag in
                            TagChip(tag: tag)
                        }
                        if document.metadata.tags.count > 5 {
                            Text("+\(document.metadata.tags.count - 5)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Modified date
            Text(document.metadata.modified, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.displayTitle), \(document.metadata.classification.displayName)")
    }
}

#Preview {
    List {
        DocumentRowView(document: Document(
            id: "test/sample.md",
            title: "Sample Document with a Long Title That Might Wrap",
            content: nil,
            metadata: DocumentMetadata(
                classification: .meeting,
                tags: ["meeting", "weekly", "team", "planning", "Q1", "review"],
                linksTo: [],
                entities: nil,
                created: Date(),
                modified: Date().addingTimeInterval(-3600),
                hasFrontmatter: true
            )
        ))
    }
    .listStyle(.plain)
}
```

### 2.8.3 FilterSheet

**File**: `ios/PKMReader/Features/DocumentList/FilterSheet.swift`

```swift
import SwiftUI

/// Sheet for filtering documents by classification
struct FilterSheet: View {
    @Binding var selectedClassification: DocumentClassification?
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Classification") {
                    // All documents option
                    Button {
                        selectedClassification = nil
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.primary)
                            Text("All Documents")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedClassification == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .accessibilityIdentifier("Filter_All")

                    // Classification options
                    ForEach(DocumentClassification.allCases, id: \.self) { classification in
                        Button {
                            selectedClassification = classification
                        } label: {
                            HStack {
                                Image(systemName: classification.icon)
                                    .foregroundStyle(classification.color)
                                Text(classification.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedClassification == classification {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                        .accessibilityIdentifier("Filter_\(classification.rawValue)")
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .accessibilityIdentifier("ApplyFilterButton")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FilterSheet(selectedClassification: .constant(.meeting)) {
        print("Applied")
    }
}
```

---

## 2.9 Document Detail Feature

### 2.9.1 DocumentDetailView

**File**: `ios/PKMReader/Features/DocumentDetail/DocumentDetailView.swift`

```swift
import MarkdownUI
import SwiftUI

/// View for displaying a single document with its content
struct DocumentDetailView: View {
    let document: Document
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: DocumentDetailViewModel

    init(document: Document, apiClient: any APIClientProtocol) {
        self.document = document
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: DocumentDetailViewModel(
            document: document,
            apiClient: apiClient
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata header
                metadataSection
                    .padding(.horizontal)

                Divider()

                // Content
                contentSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(document.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
        }
        .accessibilityIdentifier("DocumentDetailView")
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Classification badge
            ClassificationBadge(classification: document.metadata.classification)

            // Tags
            if !document.metadata.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(document.metadata.tags, id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                }
            }

            // Entities
            if let entities = document.metadata.entities {
                entitiesSection(entities)
            }

            // Dates
            HStack {
                Label {
                    Text(document.metadata.created, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Text("Modified \(document.metadata.modified, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.contentState {
        case .loading:
            LoadingView(message: "Loading content...")
                .frame(minHeight: 200)

        case .loaded(let content):
            Markdown(content)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
                .accessibilityIdentifier("DocumentContent")

        case .error(let error):
            ErrorView(error: error) {
                Task { await viewModel.loadContent() }
            }
        }
    }

    @ViewBuilder
    private func entitiesSection(_ entities: DocumentEntities) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let people = entities.people, !people.isEmpty {
                entityRow(icon: "person", items: people)
            }
            if let orgs = entities.organizations, !orgs.isEmpty {
                entityRow(icon: "building.2", items: orgs)
            }
            if let concepts = entities.concepts, !concepts.isEmpty {
                entityRow(icon: "lightbulb", items: concepts)
            }
            if let locations = entities.locations, !locations.isEmpty {
                entityRow(icon: "mappin", items: locations)
            }
        }
    }

    private func entityRow(icon: String, items: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(.secondary)

            Text(items.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DocumentDetailView(
            document: Document(
                id: "test/sample.md",
                title: "Sample Document",
                content: "# Hello World\n\nThis is a sample document with **bold** and *italic* text.",
                metadata: DocumentMetadata(
                    classification: .reference,
                    tags: ["test", "sample", "preview"],
                    linksTo: [],
                    entities: DocumentEntities(
                        people: ["John Doe", "Jane Smith"],
                        organizations: ["Acme Corp"],
                        concepts: ["Testing"],
                        locations: nil
                    ),
                    created: Date().addingTimeInterval(-86400 * 7),
                    modified: Date(),
                    hasFrontmatter: true
                )
            ),
            apiClient: MockAPIClient()
        )
    }
}
```

### 2.9.2 DocumentDetailViewModel

**File**: `ios/PKMReader/Features/DocumentDetail/DocumentDetailViewModel.swift`

```swift
import Foundation

/// View model for the document detail screen
@MainActor
final class DocumentDetailViewModel: ObservableObject {
    /// Possible states for content loading
    enum ContentState: Equatable {
        case loading
        case loaded(String)
        case error(Error)

        static func == (lhs: ContentState, rhs: ContentState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                true
            case let (.loaded(lhsContent), .loaded(rhsContent)):
                lhsContent == rhsContent
            case (.error, .error):
                true
            default:
                false
            }
        }
    }

    /// Current state of content loading
    @Published private(set) var contentState: ContentState = .loading

    /// The document being displayed
    let document: Document

    private let apiClient: any APIClientProtocol

    init(document: Document, apiClient: any APIClientProtocol) {
        self.document = document
        self.apiClient = apiClient

        // If content already loaded, use it
        if let content = document.content {
            contentState = .loaded(content)
        }
    }

    /// Load the document content from the API
    func loadContent() async {
        // Skip if already loaded
        if case .loaded = contentState {
            return
        }

        contentState = .loading

        do {
            let fullDocument = try await apiClient.getDocument(key: document.id)
            if let content = fullDocument.content {
                contentState = .loaded(content)
            } else {
                contentState = .loaded("*No content available*")
            }
        } catch {
            contentState = .error(error)
        }
    }
}
```

### 2.9.3 FlowLayout

**File**: `ios/PKMReader/Shared/Components/FlowLayout.swift`

```swift
import SwiftUI

/// A layout that arranges views in a flowing horizontal layout that wraps to new lines
struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets

        for (subview, offset) in zip(subviews, offsets) {
            subview.place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for size in sizes {
            if currentX + size.width > maxWidth, currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (offsets, CGSize(width: totalWidth, height: totalHeight))
    }
}
```

---

## 2.10 App Navigation & Root View

### 2.10.1 RootView

**File**: `ios/PKMReader/App/RootView.swift`

```swift
import SwiftUI

/// Root view that handles auth state and navigation
struct RootView: View {
    @StateObject private var authService = AuthService.shared
    @State private var isInitialized = false

    var body: some View {
        Group {
            if !isInitialized {
                LoadingView(message: "Initializing...")
            } else {
                switch authService.authState {
                case .unknown:
                    LoadingView(message: "Checking authentication...")

                case .signedOut:
                    LoginView(authService: authService)

                case .signedIn:
                    MainTabView(authService: authService)
                }
            }
        }
        .task {
            do {
                try await authService.configure()
                isInitialized = true
            } catch {
                print("Failed to initialize auth: \(error)")
                isInitialized = true
            }
        }
    }
}

#Preview {
    RootView()
}
```

### 2.10.2 MainTabView

**File**: `ios/PKMReader/App/MainTabView.swift`

```swift
import SwiftUI

/// Main tab-based navigation after authentication
struct MainTabView: View {
    let authService: AuthService
    @State private var selectedTab = 0

    private var apiClient: APIClient {
        APIClient(authService: authService)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DocumentListView(apiClient: apiClient)
                .tabItem {
                    Label("Documents", systemImage: "doc.text")
                }
                .tag(0)

            SettingsView(authService: authService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .accessibilityIdentifier("MainTabView")
    }
}

#Preview {
    MainTabView(authService: AuthService.shared)
}
```

### 2.10.3 SettingsView

**File**: `ios/PKMReader/Features/Settings/SettingsView.swift`

```swift
import SwiftUI

/// Settings screen with user info and sign out
struct SettingsView: View {
    let authService: any AuthServiceProtocol
    @State private var isSigningOut = false
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Text("Sign Out")
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)
                    .accessibilityIdentifier("SignOutButton")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(Environment.appVersion) (\(Environment.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func signOut() async {
        isSigningOut = true
        do {
            try await authService.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
        isSigningOut = false
    }
}

#Preview {
    SettingsView(authService: MockAuthService())
}
```

### 2.10.4 Update PKMReaderApp

**Update**: `ios/PKMReader/App/PKMReaderApp.swift`

```swift
import SwiftUI

@main
struct PKMReaderApp: App {
    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            configureForUITesting()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    #if DEBUG
    private func configureForUITesting() {
        // Clear any cached state for clean UI tests
        UserDefaults.standard.removePersistentDomain(
            forName: Bundle.main.bundleIdentifier ?? ""
        )
    }
    #endif
}
```

---

## 2.11 Additional Models

### 2.11.1 Summary Model

**File**: `ios/PKMReader/Models/Summary.swift`

```swift
import Foundation

/// A daily summary generated by the AI agent
struct Summary: Identifiable, Codable, Sendable {
    /// The S3 key of the summary file
    let id: String

    /// The date of the summary (YYYY-MM-DD)
    let date: String

    /// When the summary was last modified
    let modified: Date
}
```

### 2.11.2 Report Model

**File**: `ios/PKMReader/Models/Report.swift`

```swift
import Foundation

/// A weekly report generated by the AI agent
struct Report: Identifiable, Codable, Sendable {
    /// The S3 key of the report file
    let id: String

    /// The week start date (YYYY-MM-DD)
    let weekOf: String

    /// When the report was last modified
    let modified: Date
}
```

### 2.11.3 ClassificationCount Model

**File**: `ios/PKMReader/Models/ClassificationCount.swift`

```swift
import Foundation

/// Count of documents per classification
struct ClassificationCount: Codable, Sendable {
    /// The classification name
    let name: String

    /// Display-friendly name
    let displayName: String

    /// Number of documents
    let count: Int

    /// SF Symbol icon name
    let icon: String
}
```

---

## 2.12 Testing

### 2.12.1 Update MockAPIClient

**Update**: `ios/PKMReaderTests/Mocks/MockAPIClient.swift`

Add new methods to match updated protocol:

```swift
// Add these properties and methods to existing MockAPIClient

var listClassificationsResult: Result<[ClassificationCount], Error> = .success([])
var listSummariesResult: Result<[Summary], Error> = .success([])
var listReportsResult: Result<[Report], Error> = .success([])

func listClassifications() async throws -> [ClassificationCount] {
    try listClassificationsResult.get()
}

func listSummaries(limit: Int) async throws -> [Summary] {
    try listSummariesResult.get()
}

func listReports(limit: Int) async throws -> [Report] {
    try listReportsResult.get()
}
```

### 2.12.2 AuthService Unit Tests

**File**: `ios/PKMReaderTests/Core/Auth/AuthServiceTests.swift`

```swift
import XCTest
@testable import PKMReader

@MainActor
final class AuthServiceTests: XCTestCase {
    // Note: Full AuthService tests require mocking Amplify
    // These tests focus on the public interface behavior

    func test_initialAuthState_isUnknown() {
        // AuthService.shared starts in unknown state before configure()
        // This is tested through integration tests
    }
}
```

### 2.12.3 LoginViewModel Unit Tests

**File**: `ios/PKMReaderTests/Features/Auth/LoginViewModelTests.swift`

```swift
import XCTest
@testable import PKMReader

@MainActor
final class LoginViewModelTests: XCTestCase {
    private var sut: LoginViewModel!
    private var mockAuthService: MockAuthService!

    override func setUp() async throws {
        mockAuthService = MockAuthService()
        sut = LoginViewModel(authService: mockAuthService)
    }

    override func tearDown() async throws {
        sut = nil
        mockAuthService = nil
    }

    // MARK: - Validation

    func test_isValid_withEmptyEmail_returnsFalse() {
        sut.email = ""
        sut.password = "password123"

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_withEmptyPassword_returnsFalse() {
        sut.email = "test@example.com"
        sut.password = ""

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_withInvalidEmail_returnsFalse() {
        sut.email = "notanemail"
        sut.password = "password123"

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_withValidCredentials_returnsTrue() {
        sut.email = "test@example.com"
        sut.password = "password123"

        XCTAssertTrue(sut.isValid)
    }

    // MARK: - Sign In

    func test_signIn_success_clearsError() async {
        sut.email = "test@example.com"
        sut.password = "password123"
        mockAuthService.signInResult = .success(())

        await sut.signIn()

        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func test_signIn_failure_setsError() async {
        sut.email = "test@example.com"
        sut.password = "wrongpassword"
        mockAuthService.signInResult = .failure(AuthError.invalidCredentials)

        await sut.signIn()

        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func test_signIn_setsLoadingDuringRequest() async {
        sut.email = "test@example.com"
        sut.password = "password123"

        let expectation = XCTestExpectation(description: "Loading state set")
        mockAuthService.signInDelay = 0.1
        mockAuthService.signInResult = .success(())

        Task {
            await sut.signIn()
        }

        // Check loading state after a brief delay
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        XCTAssertTrue(sut.isLoading)
    }
}
```

### 2.12.4 DocumentDetailViewModel Unit Tests

**File**: `ios/PKMReaderTests/Features/DocumentDetail/DocumentDetailViewModelTests.swift`

```swift
import XCTest
@testable import PKMReader

@MainActor
final class DocumentDetailViewModelTests: XCTestCase {
    private var sut: DocumentDetailViewModel!
    private var mockAPIClient: MockAPIClient!

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    // MARK: - Initial State

    func test_initialState_withContent_isLoaded() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        if case .loaded(let content) = sut.contentState {
            XCTAssertEqual(content, document.content)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_initialState_withoutContent_isLoading() {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        XCTAssertEqual(sut.contentState, .loading)
    }

    // MARK: - Load Content

    func test_loadContent_success_updatesState() async {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        let fullDocument = Document(
            id: "test.md",
            title: "Test",
            content: "# Full Content",
            metadata: TestFixtures.sampleDocument.metadata
        )

        mockAPIClient.getDocumentResult = .success(fullDocument)
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        if case .loaded(let content) = sut.contentState {
            XCTAssertEqual(content, "# Full Content")
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_loadContent_failure_updatesStateToError() async {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )

        mockAPIClient.getDocumentResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        if case .error = sut.contentState {
            // Expected
        } else {
            XCTFail("Expected error state")
        }
    }

    func test_loadContent_alreadyLoaded_doesNotReload() async {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        XCTAssertEqual(mockAPIClient.getDocumentCallCount, 0)
    }
}
```

### 2.12.5 UI Test Updates

**Update**: `ios/PKMReaderUITests/Screens/DocumentListScreenTests.swift`

Add tests for the filter functionality:

```swift
func test_filterButton_opensFilterSheet() {
    documentListPage.assertIsDisplayed()
    documentListPage.tapFilterButton()

    // Verify filter sheet appears
    let filterSheet = app.sheets.firstMatch
    XCTAssertTrue(filterSheet.waitForExistence(timeout: 5))
}
```

---

## Deliverables Checklist

### Core Services

| Item | File | Status |
|------|------|--------|
| AuthService implementation | `Core/Auth/AuthService.swift` | ⬜ |
| AuthState enum | `Core/Auth/AuthState.swift` | ⬜ |
| APIClient implementation | `Core/Networking/APIClient.swift` | ⬜ |
| KeychainService implementation | `Core/Auth/KeychainService.swift` | ⬜ |
| CacheService with SwiftData | `Core/Cache/CacheService.swift` | ⬜ |
| CachedDocument model | `Core/Cache/CachedDocument.swift` | ⬜ |

### Views & Components

| Item | File | Status |
|------|------|--------|
| LoadingView | `Shared/Components/LoadingView.swift` | ⬜ |
| ErrorView | `Shared/Components/ErrorView.swift` | ⬜ |
| EmptyStateView | `Shared/Components/EmptyStateView.swift` | ⬜ |
| TagChip | `Shared/Components/TagChip.swift` | ⬜ |
| ClassificationBadge | `Shared/Components/ClassificationBadge.swift` | ⬜ |
| FlowLayout | `Shared/Components/FlowLayout.swift` | ⬜ |
| LoginView | `Features/Auth/LoginView.swift` | ⬜ |
| LoginViewModel | `Features/Auth/LoginViewModel.swift` | ⬜ |
| DocumentListView | `Features/DocumentList/DocumentListView.swift` | ⬜ |
| DocumentRowView | `Features/DocumentList/DocumentRowView.swift` | ⬜ |
| FilterSheet | `Features/DocumentList/FilterSheet.swift` | ⬜ |
| DocumentDetailView | `Features/DocumentDetail/DocumentDetailView.swift` | ⬜ |
| DocumentDetailViewModel | `Features/DocumentDetail/DocumentDetailViewModel.swift` | ⬜ |
| SettingsView | `Features/Settings/SettingsView.swift` | ⬜ |
| RootView | `App/RootView.swift` | ⬜ |
| MainTabView | `App/MainTabView.swift` | ⬜ |

### Models

| Item | File | Status |
|------|------|--------|
| Summary model | `Models/Summary.swift` | ⬜ |
| Report model | `Models/Report.swift` | ⬜ |
| ClassificationCount model | `Models/ClassificationCount.swift` | ⬜ |

### Configuration

| Item | File | Status |
|------|------|--------|
| project.yml with dependencies | `project.yml` | ⬜ |
| amplifyconfiguration.json | `Resources/amplifyconfiguration.json` | ⬜ |
| Environment.swift updates | `Core/Configuration/Environment.swift` | ⬜ |

### Testing

| Item | Status |
|------|--------|
| LoginViewModel unit tests | ⬜ |
| DocumentDetailViewModel unit tests | ⬜ |
| MockAuthService updates | ⬜ |
| MockAPIClient updates | ⬜ |
| UI tests for login flow | ⬜ |
| UI tests for document list | ⬜ |

---

## Implementation Order

### Week 1: Foundation & Auth

1. Add dependencies to `project.yml`
2. Create Amplify configuration
3. Implement `KeychainService`
4. Implement `AuthService` with Amplify
5. Add `AuthState` enum
6. Implement `LoginView` and `LoginViewModel`
7. Write auth unit tests

### Week 2: Core Views & Navigation

1. Create all shared UI components
2. Implement `APIClient`
3. Implement `DocumentListView` and `DocumentRowView`
4. Implement `FilterSheet`
5. Implement `DocumentDetailView` and `DocumentDetailViewModel`
6. Create `RootView` and `MainTabView`
7. Update `PKMReaderApp`

### Week 3: Caching & Polish

1. Implement `CacheService` with SwiftData
2. Add `CachedDocument` model
3. Integrate caching into views
4. Implement `SettingsView`
5. Add additional models (Summary, Report, ClassificationCount)

### Week 4: Testing & Integration

1. Write remaining unit tests
2. Update UI tests for new flows
3. Integration testing with real backend
4. Bug fixes and polish
5. Code coverage verification (≥70%)

---

## Exit Criteria

Phase 2 is complete when:

- [ ] User can sign in with Cognito credentials
- [ ] User can sign out
- [ ] Document list loads and displays from API
- [ ] Document list can be filtered by classification
- [ ] Document detail view shows content with markdown rendering
- [ ] Pull-to-refresh works on document list
- [ ] Pagination loads more documents
- [ ] Error states display appropriately
- [ ] Empty states display appropriately
- [ ] App persists auth state across launches
- [ ] All unit tests pass
- [ ] All UI tests pass
- [ ] Code coverage ≥70%
- [ ] No SwiftLint errors
- [ ] CI pipeline passes

---

## Next Steps (Phase 3)

After Phase 2 completion, Phase 3 (Enhanced Features) will add:

- Search functionality with SearchView
- Tags browsing with TagsView
- Daily summaries view
- Weekly reports view
- Enhanced offline support
- Performance optimizations
