import Foundation

/// HTTP client for PKM API with authentication and retry logic
actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let authService: any AuthServiceProtocol
    private let session: URLSession
    private let decoder: JSONDecoder
    private let maxRetries: Int
    private let baseRetryDelay: TimeInterval
    private let networkMonitor: NetworkMonitor

    init(
        baseURL: URL = AppConfig.apiBaseURL,
        authService: any AuthServiceProtocol,
        networkMonitor: NetworkMonitor,
        session: URLSession = .shared,
        maxRetries: Int = 3,
        baseRetryDelay: TimeInterval = 1.0
    ) {
        self.baseURL = baseURL
        self.authService = authService
        self.networkMonitor = networkMonitor
        self.session = session
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay

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

        return try await performRequestWithRetry(url: url)
    }

    func getDocument(key: String) async throws -> Document {
        guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }

        let url = baseURL.appendingPathComponent("documents/\(encodedKey)")
        return try await performRequestWithRetry(url: url)
    }

    func search(query: String, limit: Int, mode: SearchMode = .keyword) async throws -> [Document] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "mode", value: mode.rawValue)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: SearchResponse = try await performRequestWithRetry(url: url)
        return response.results
    }

    func listTags() async throws -> [Tag] {
        let url = baseURL.appendingPathComponent("tags")
        let response: TagListResponse = try await performRequestWithRetry(url: url)
        return response.tags
    }

    func listClassifications() async throws -> [ClassificationCount] {
        let url = baseURL.appendingPathComponent("classifications")
        let response: ClassificationListResponse = try await performRequestWithRetry(url: url)
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

        let response: SummaryListResponse = try await performRequestWithRetry(url: url)
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

        let response: ReportListResponse = try await performRequestWithRetry(url: url)
        return response.reports
    }

    func updateClassification(
        documentId: String,
        classification: DocumentClassification
    ) async throws {
        guard let encodedKey = documentId.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) else {
            throw APIError.invalidURL
        }

        let url = baseURL.appendingPathComponent("documents/classification/\(encodedKey)")
        let body = ["classification": classification.rawValue]
        try await performPutRequestWithRetry(url: url, body: body)
    }

    func documentsByTag(tag: String, limit: Int) async throws -> [Document] {
        let tagDocumentsURL = baseURL
            .appendingPathComponent("tags")
            .appendingPathComponent(tag)
            .appendingPathComponent("documents")

        var components = URLComponents(
            url: tagDocumentsURL,
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: DocumentsByTagResponse = try await performRequestWithRetry(url: url)
        return response.documents
    }

    // MARK: - Private

    private func performPutRequestWithRetry(url: URL, body: [String: String]) async throws {
        guard await networkMonitor.isConnected else {
            throw APIError.networkError
        }

        var lastError: Error = APIError.networkError

        for attempt in 0...maxRetries {
            do {
                try await performPutRequest(url: url, body: body)
                return
            } catch let error as APIError where error.isRetryable && attempt < maxRetries {
                lastError = error
                guard await networkMonitor.isConnected else {
                    throw APIError.networkError
                }
                let delay = baseRetryDelay * pow(2.0, Double(attempt))
                try await Task.sleep(for: .seconds(delay))
                continue
            } catch {
                throw error
            }
        }

        throw lastError
    }

    private func performPutRequest(url: URL, body: [String: String]) async throws {
        let token = try await authService.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw APIError.timeout
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                throw APIError.networkError
            default:
                throw APIError.networkError
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.httpError(statusCode: 404)
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func performRequestWithRetry<T: Decodable>(url: URL) async throws -> T {
        // Fail fast if offline
        guard await networkMonitor.isConnected else {
            throw APIError.networkError
        }

        var lastError: Error = APIError.networkError

        for attempt in 0...maxRetries {
            do {
                let result: T = try await performRequest(url: url)
                return result
            } catch let error as APIError where error.isRetryable && attempt < maxRetries {
                lastError = error
                // Don't retry if we've gone offline
                guard await networkMonitor.isConnected else {
                    throw APIError.networkError
                }
                let delay = baseRetryDelay * pow(2.0, Double(attempt))
                try await Task.sleep(for: .seconds(delay))
                continue
            } catch {
                throw error
            }
        }

        throw lastError
    }

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let token = try await authService.getAccessToken()

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw APIError.timeout
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                throw APIError.networkError
            default:
                throw APIError.networkError
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError
            }
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.httpError(statusCode: 404)
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

struct DocumentsByTagResponse: Codable, Sendable {
    let tag: String
    let documents: [Document]
    let count: Int
}
