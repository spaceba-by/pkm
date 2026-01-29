# iOS App Scaffold Plan for PKM

## Overview

This document outlines the plan to create an iOS mobile app that interfaces with the PKM (Personal Knowledge Management) system. The initial version focuses on reading markdown documents from the S3 bucket (`notes.spaceba.by`).

---

## Current State Analysis

### Existing Infrastructure
- **S3 Bucket**: `notes.spaceba.by` - contains markdown files and `_agent/` AI-generated content
- **DynamoDB Table**: `pkm-metadata` - stores document metadata, classifications, entities
- **Authentication**: IAM-based only (no user-facing auth)
- **API**: None - system is event-driven with no public API

### What's Missing for Mobile
1. Public API layer for mobile clients
2. User authentication system
3. iOS application codebase

---

## Architecture Plan

```
┌─────────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                           │
├─────────────────────────────────────────────────────────────────────┤
│  Views          │  ViewModels        │  Services                    │
│  - DocumentList │  - DocumentListVM  │  - APIClient                 │
│  - DocumentView │  - DocumentVM      │  - AuthService               │
│  - SearchView   │  - SearchVM        │  - CacheService              │
│  - SettingsView │                    │  - MarkdownRenderer          │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    API Gateway (REST)                               │
│  /documents       GET    - List documents with metadata             │
│  /documents/{key} GET    - Get single document content              │
│  /search          GET    - Search documents by query                │
│  /tags            GET    - List all tags                            │
│  /tags/{tag}      GET    - Get documents by tag                     │
│  /summaries       GET    - List daily summaries                     │
│  /reports         GET    - List weekly reports                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Amazon Cognito                                   │
│  - User Pool (email/password auth)                                  │
│  - Identity Pool (temporary AWS credentials)                        │
│  - JWT token validation                                             │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Lambda Functions (API)                           │
│  - pkm-api-list-documents                                           │
│  - pkm-api-get-document                                             │
│  - pkm-api-search                                                   │
│  - pkm-api-list-tags                                                │
└────────────────────────────┬────────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│   S3: notes.spaceba.by  │   │  DynamoDB: pkm-metadata │
│   (markdown content)    │   │  (metadata, search)     │
└─────────────────────────┘   └─────────────────────────┘
```

---

## Phase 1: Backend API Infrastructure

### 1.1 Cognito User Authentication

**File**: `terraform/cognito.tf`

```hcl
# User Pool for authentication
resource "aws_cognito_user_pool" "pkm_users" {
  name = "pkm-users"

  # Password policy
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Email verification
  auto_verified_attributes = ["email"]

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Schema
  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable            = true
  }
}

# App client for iOS
resource "aws_cognito_user_pool_client" "ios_client" {
  name         = "pkm-ios-client"
  user_pool_id = aws_cognito_user_pool.pkm_users.id

  generate_secret = false  # Required for mobile apps

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Token validity
  access_token_validity  = 1   # hours
  id_token_validity      = 1   # hours
  refresh_token_validity = 30  # days
}

# Identity Pool for AWS credentials
resource "aws_cognito_identity_pool" "pkm_identity" {
  identity_pool_name = "pkm_identity_pool"

  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.ios_client.id
    provider_name           = aws_cognito_user_pool.pkm_users.endpoint
    server_side_token_check = false
  }
}
```

### 1.2 API Gateway + Lambda Functions

**File**: `terraform/api_gateway.tf`

```hcl
resource "aws_apigatewayv2_api" "pkm_api" {
  name          = "pkm-mobile-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
    max_age       = 300
  }
}

# Cognito authorizer
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.pkm_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.ios_client.id]
    issuer   = "https://${aws_cognito_user_pool.pkm_users.endpoint}"
  }
}
```

### 1.3 API Lambda Functions

**New Lambda functions for API** (Babashka/Clojure, consistent with existing codebase):

| Function | Endpoint | Purpose |
|----------|----------|---------|
| `pkm-api-list-documents` | `GET /documents` | List documents with pagination |
| `pkm-api-get-document` | `GET /documents/{key}` | Get document content + metadata |
| `pkm-api-search` | `GET /search?q=...` | Full-text search via DynamoDB |
| `pkm-api-list-tags` | `GET /tags` | List all unique tags |
| `pkm-api-documents-by-tag` | `GET /tags/{tag}/documents` | Get documents by tag |
| `pkm-api-list-summaries` | `GET /summaries` | List daily summaries |
| `pkm-api-list-reports` | `GET /reports` | List weekly reports |

**Example handler** (`lambda/functions/api_list_documents/handler.clj`):

```clojure
(ns handler
  (:require [shared.aws.dynamodb :as ddb]
            [shared.aws.s3 :as s3]
            [cheshire.core :as json]))

(defn handler [event]
  (let [params (get event "queryStringParameters" {})
        limit (Integer/parseInt (get params "limit" "50"))
        cursor (get params "cursor")
        classification (get params "classification")

        ;; Query DynamoDB for document metadata
        results (if classification
                  (ddb/query-by-classification classification limit cursor)
                  (ddb/scan-documents limit cursor))]

    {:statusCode 200
     :headers {"Content-Type" "application/json"}
     :body (json/generate-string
            {:documents (:items results)
             :nextCursor (:cursor results)})}))
```

---

## Phase 2: iOS App Scaffold

### 2.1 Project Structure

```
ios/
├── PKMReader/
│   ├── App/
│   │   ├── PKMReaderApp.swift        # App entry point
│   │   └── AppDelegate.swift         # App lifecycle
│   │
│   ├── Core/
│   │   ├── Configuration/
│   │   │   ├── Environment.swift     # API URLs, Cognito config
│   │   │   └── Secrets.swift         # Sensitive config (gitignored)
│   │   │
│   │   ├── Networking/
│   │   │   ├── APIClient.swift       # HTTP client with auth
│   │   │   ├── APIEndpoints.swift    # Endpoint definitions
│   │   │   └── APIError.swift        # Error types
│   │   │
│   │   ├── Auth/
│   │   │   ├── AuthService.swift     # Cognito authentication
│   │   │   ├── KeychainService.swift # Secure token storage
│   │   │   └── AuthState.swift       # Auth state management
│   │   │
│   │   └── Cache/
│   │       ├── CacheService.swift    # Local document caching
│   │       └── CachePolicy.swift     # Cache invalidation rules
│   │
│   ├── Models/
│   │   ├── Document.swift            # Document model
│   │   ├── DocumentMetadata.swift    # Metadata model
│   │   ├── Tag.swift                 # Tag model
│   │   ├── Summary.swift             # Daily summary model
│   │   └── Report.swift              # Weekly report model
│   │
│   ├── Features/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   ├── LoginViewModel.swift
│   │   │   └── SignUpView.swift
│   │   │
│   │   ├── DocumentList/
│   │   │   ├── DocumentListView.swift
│   │   │   ├── DocumentListViewModel.swift
│   │   │   ├── DocumentRowView.swift
│   │   │   └── FilterSheet.swift
│   │   │
│   │   ├── DocumentDetail/
│   │   │   ├── DocumentDetailView.swift
│   │   │   ├── DocumentDetailViewModel.swift
│   │   │   └── MarkdownRenderer.swift
│   │   │
│   │   ├── Search/
│   │   │   ├── SearchView.swift
│   │   │   └── SearchViewModel.swift
│   │   │
│   │   ├── Tags/
│   │   │   ├── TagsView.swift
│   │   │   └── TagsViewModel.swift
│   │   │
│   │   ├── Summaries/
│   │   │   ├── SummariesView.swift
│   │   │   └── SummaryDetailView.swift
│   │   │
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── SettingsViewModel.swift
│   │
│   ├── Shared/
│   │   ├── Components/
│   │   │   ├── LoadingView.swift
│   │   │   ├── ErrorView.swift
│   │   │   ├── EmptyStateView.swift
│   │   │   └── TagChip.swift
│   │   │
│   │   └── Extensions/
│   │       ├── Date+Extensions.swift
│   │       ├── String+Extensions.swift
│   │       └── View+Extensions.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── Info.plist
│
├── PKMReader.xcodeproj/
├── PKMReaderTests/
├── PKMReaderUITests/
└── README.md
```

### 2.2 Key Models

**Document.swift**:
```swift
import Foundation

struct Document: Identifiable, Codable {
    let id: String           // S3 key
    let title: String
    let content: String?     // Markdown content (optional, loaded on demand)
    let metadata: DocumentMetadata

    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }
}

struct DocumentMetadata: Codable {
    let classification: DocumentClassification
    let tags: [String]
    let linksTo: [String]
    let entities: DocumentEntities?
    let created: Date
    let modified: Date
    let hasFrontmatter: Bool
}

enum DocumentClassification: String, Codable, CaseIterable {
    case meeting
    case idea
    case reference
    case journal
    case project

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .meeting: return "person.3"
        case .idea: return "lightbulb"
        case .reference: return "book"
        case .journal: return "book.closed"
        case .project: return "folder"
        }
    }
}

struct DocumentEntities: Codable {
    let people: [String]?
    let organizations: [String]?
    let concepts: [String]?
    let locations: [String]?
}
```

### 2.3 Core Services

**APIClient.swift**:
```swift
import Foundation

actor APIClient {
    private let baseURL: URL
    private let authService: AuthService
    private let session: URLSession

    init(baseURL: URL, authService: AuthService) {
        self.baseURL = baseURL
        self.authService = authService
        self.session = URLSession.shared
    }

    func listDocuments(
        classification: DocumentClassification? = nil,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> DocumentListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("documents"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: String(limit))]

        if let classification {
            queryItems.append(.init(name: "classification", value: classification.rawValue))
        }
        if let cursor {
            queryItems.append(.init(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        return try await request(url: components.url!)
    }

    func getDocument(key: String) async throws -> Document {
        let url = baseURL.appendingPathComponent("documents/\(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)")
        return try await request(url: url)
    }

    func search(query: String, limit: Int = 20) async throws -> [Document] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "q", value: query),
            .init(name: "limit", value: String(limit))
        ]
        return try await request(url: components.url!)
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        let token = try await authService.getAccessToken()

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

struct DocumentListResponse: Codable {
    let documents: [Document]
    let nextCursor: String?
}

enum APIError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case unauthorized
}
```

**AuthService.swift**:
```swift
import Foundation
import AWSCognitoIdentityProvider

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: CognitoUser?

    private let userPool: AWSCognitoIdentityUserPool
    private let keychainService: KeychainService

    init() {
        // Configure Cognito
        let config = AWSCognitoIdentityUserPoolConfiguration(
            clientId: Environment.cognitoClientId,
            clientSecret: nil,
            poolId: Environment.cognitoUserPoolId
        )
        userPool = AWSCognitoIdentityUserPool(configuration: config)
        keychainService = KeychainService()

        // Check for existing session
        Task {
            await checkExistingSession()
        }
    }

    func signIn(email: String, password: String) async throws {
        let user = userPool.getUser(email)
        let session = try await user.authenticatePassword(password)

        // Store tokens securely
        try keychainService.store(token: session.accessToken, forKey: .accessToken)
        try keychainService.store(token: session.refreshToken, forKey: .refreshToken)

        isAuthenticated = true
        currentUser = CognitoUser(email: email)
    }

    func signOut() async {
        keychainService.deleteAll()
        isAuthenticated = false
        currentUser = nil
    }

    func getAccessToken() async throws -> String {
        guard let token = keychainService.retrieve(forKey: .accessToken) else {
            throw AuthError.notAuthenticated
        }

        // Check if token is expired and refresh if needed
        if isTokenExpired(token) {
            return try await refreshToken()
        }

        return token
    }

    private func refreshToken() async throws -> String {
        guard let refreshToken = keychainService.retrieve(forKey: .refreshToken) else {
            throw AuthError.notAuthenticated
        }

        let session = try await userPool.refresh(refreshToken: refreshToken)
        try keychainService.store(token: session.accessToken, forKey: .accessToken)

        return session.accessToken
    }

    private func checkExistingSession() async {
        if let token = keychainService.retrieve(forKey: .accessToken),
           !isTokenExpired(token) {
            isAuthenticated = true
        }
    }

    private func isTokenExpired(_ token: String) -> Bool {
        // Decode JWT and check exp claim
        // Implementation omitted for brevity
        return false
    }
}

enum AuthError: Error {
    case notAuthenticated
    case invalidCredentials
    case networkError
}

struct CognitoUser {
    let email: String
}
```

### 2.4 Main Views

**DocumentListView.swift**:
```swift
import SwiftUI

struct DocumentListView: View {
    @StateObject private var viewModel: DocumentListViewModel
    @State private var showingFilter = false

    init(apiClient: APIClient) {
        _viewModel = StateObject(wrappedValue: DocumentListViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView()

                case .loaded(let documents):
                    documentList(documents)

                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadDocuments() }
                    }

                case .empty:
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Documents",
                        message: "Your vault is empty"
                    )
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilter) {
                FilterSheet(
                    selectedClassification: $viewModel.selectedClassification,
                    onApply: {
                        Task { await viewModel.loadDocuments() }
                    }
                )
            }
            .searchable(text: $viewModel.searchText)
            .refreshable {
                await viewModel.loadDocuments()
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
    }

    private func documentList(_ documents: [Document]) -> some View {
        List {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .task {
                        await viewModel.loadNextPage()
                    }
            }
        }
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document, apiClient: viewModel.apiClient)
        }
    }
}

struct DocumentRowView: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: document.metadata.classification.icon)
                    .foregroundStyle(.secondary)
                Text(document.displayTitle)
                    .font(.headline)
            }

            if !document.metadata.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(document.metadata.tags, id: \.self) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
            }

            Text(document.metadata.modified, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

**DocumentDetailView.swift**:
```swift
import SwiftUI
import MarkdownUI

struct DocumentDetailView: View {
    let document: Document
    let apiClient: APIClient

    @StateObject private var viewModel: DocumentDetailViewModel

    init(document: Document, apiClient: APIClient) {
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

                Divider()

                // Markdown content
                switch viewModel.contentState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()

                case .loaded(let content):
                    Markdown(content)
                        .markdownTheme(.gitHub)
                        .padding(.horizontal)

                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadContent() }
                    }
                }
            }
        }
        .navigationTitle(document.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Classification badge
            HStack {
                Image(systemName: document.metadata.classification.icon)
                Text(document.metadata.classification.displayName)
            }
            .font(.subheadline)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.2))
            .clipShape(Capsule())

            // Tags
            if !document.metadata.tags.isEmpty {
                FlowLayout(spacing: 4) {
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
                Label(document.metadata.created, style: .date)
                Spacer()
                Text("Modified: \(document.metadata.modified, style: .relative)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func entitiesSection(_ entities: DocumentEntities) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let people = entities.people, !people.isEmpty {
                entityRow(icon: "person", label: "People", items: people)
            }
            if let orgs = entities.organizations, !orgs.isEmpty {
                entityRow(icon: "building.2", label: "Organizations", items: orgs)
            }
            if let concepts = entities.concepts, !concepts.isEmpty {
                entityRow(icon: "lightbulb", label: "Concepts", items: concepts)
            }
            if let locations = entities.locations, !locations.isEmpty {
                entityRow(icon: "mappin", label: "Locations", items: locations)
            }
        }
    }

    private func entityRow(icon: String, label: String, items: [String]) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .frame(width: 20)
            Text(items.joined(separator: ", "))
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
```

---

## Phase 3: Implementation Roadmap

### Sprint 1: Backend Foundation (Week 1-2)

| Task | Priority | Effort |
|------|----------|--------|
| Add Cognito user pool and identity pool | High | Medium |
| Create API Gateway with Cognito authorizer | High | Medium |
| Implement `pkm-api-list-documents` Lambda | High | Low |
| Implement `pkm-api-get-document` Lambda | High | Low |
| Add API infrastructure to Terraform | High | Medium |
| Write integration tests for API | Medium | Medium |

**Deliverables**:
- Terraform modules for Cognito + API Gateway
- 2 working API endpoints with authentication
- API documentation

### Sprint 2: Core iOS App (Week 3-4)

| Task | Priority | Effort |
|------|----------|--------|
| Create Xcode project with SwiftUI | High | Low |
| Implement AuthService with Cognito SDK | High | High |
| Implement APIClient | High | Medium |
| Build DocumentListView + ViewModel | High | Medium |
| Build DocumentDetailView with Markdown rendering | High | Medium |
| Add local caching with SwiftData | Medium | Medium |

**Deliverables**:
- Working iOS app with login
- Document list and detail views
- Offline reading capability for cached docs

### Sprint 3: Enhanced Features (Week 5-6)

| Task | Priority | Effort |
|------|----------|--------|
| Implement search API + SearchView | High | Medium |
| Implement tags API + TagsView | Medium | Medium |
| Add summaries/reports endpoints and views | Medium | Medium |
| Build SettingsView | Low | Low |
| Add pull-to-refresh and pagination | Medium | Low |
| Polish UI and add loading states | Medium | Medium |

**Deliverables**:
- Full-featured read-only PKM app
- Search functionality
- Browse by tags and classifications

### Sprint 4: Polish & Release (Week 7-8)

| Task | Priority | Effort |
|------|----------|--------|
| Add error handling and retry logic | High | Medium |
| Implement offline mode indicators | Medium | Low |
| Add accessibility support | Medium | Medium |
| Write unit and UI tests | Medium | High |
| App Store submission preparation | High | Medium |
| Documentation | Medium | Low |

**Deliverables**:
- Production-ready iOS app
- App Store submission
- User documentation

---

## Technical Decisions

### Why Cognito?
- Native AWS integration with existing infrastructure
- Built-in user management, MFA support
- Free tier covers initial usage
- Easy integration with API Gateway

### Why REST vs GraphQL?
- Simpler implementation for read-only use case
- Better caching with HTTP semantics
- Consistent with existing Lambda patterns in codebase
- Can migrate to GraphQL/AppSync later if needed

### Why SwiftUI?
- Modern, declarative UI framework
- Better async/await support
- Less boilerplate than UIKit
- iOS 16+ is acceptable minimum deployment target

### Why SwiftData for Caching?
- Native Apple framework (iOS 17+)
- Automatic CloudKit sync potential
- Type-safe Swift integration
- Alternative: Core Data for iOS 16 support

### Markdown Rendering
- Use `MarkdownUI` package (swift-markdown-ui)
- Supports GitHub Flavored Markdown
- Customizable themes
- Good performance

---

## Dependencies

### iOS App
```swift
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
    .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm", from: "2.33.0"),
]
```

### Backend (Clojure/Babashka)
- Existing dependencies sufficient
- May need additional JSON schema validation

---

## Security Considerations

1. **Authentication**: All API endpoints require valid Cognito JWT
2. **Authorization**: Single-tenant initially (one user pool = one vault)
3. **Token Storage**: iOS Keychain for secure token storage
4. **HTTPS**: All API traffic over TLS
5. **Rate Limiting**: API Gateway throttling (1000 req/sec default)
6. **Audit Logging**: CloudWatch logs for all API calls

---

## Future Enhancements (Post-MVP)

1. **Write Support**: Create/edit documents from mobile
2. **Offline Sync**: Full offline capability with conflict resolution
3. **Push Notifications**: Alerts for new summaries/reports
4. **Widgets**: iOS home screen widgets for recent docs
5. **Spotlight Integration**: Search PKM from iOS Spotlight
6. **Share Extension**: Save content to PKM from other apps
7. **iPad Support**: Optimized layout for larger screens
8. **macOS App**: Catalyst or native SwiftUI Mac app

---

## File Locations Summary

### New Backend Files
```
terraform/
├── cognito.tf           # User authentication
├── api_gateway.tf       # REST API
└── api_lambda.tf        # API Lambda functions

lambda/functions/
├── api_list_documents/
│   └── handler.clj
├── api_get_document/
│   └── handler.clj
├── api_search/
│   └── handler.clj
└── api_list_tags/
    └── handler.clj
```

### New iOS App Files
```
ios/
├── PKMReader/           # Main app target
├── PKMReader.xcodeproj/ # Xcode project
├── PKMReaderTests/      # Unit tests
└── README.md            # iOS-specific docs
```

---

## Success Metrics

1. **Functional**: Can browse and read all vault documents
2. **Performance**: Document list loads in < 2 seconds
3. **Reliability**: 99.9% API uptime
4. **Usability**: Clean, intuitive interface
5. **Security**: No unauthorized access possible
