import Foundation

/// HTTP client for PKM API with authentication
actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let authService: any AuthServiceProtocol
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = AppConfig.apiBaseURL,
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
