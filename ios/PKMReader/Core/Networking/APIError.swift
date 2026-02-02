import Foundation

/// Errors that can occur when interacting with the API
enum APIError: Error, Equatable, Sendable {
    /// The URL could not be constructed
    case invalidURL

    /// The server response was invalid or could not be parsed
    case invalidResponse

    /// HTTP error with status code
    case httpError(statusCode: Int)

    /// JSON decoding failed
    case decodingError

    /// User is not authenticated
    case unauthorized

    /// Network connection failed
    case networkError

    /// Request timed out
    case timeout

    /// Server returned an error message
    case serverError(String)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Authentication required"
        case .networkError:
            return "Network connection failed"
        case .timeout:
            return "Request timed out"
        case .serverError(let message):
            return message
        }
    }
}
