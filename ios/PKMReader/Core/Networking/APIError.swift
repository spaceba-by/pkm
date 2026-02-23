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

    /// Whether this error is transient and the request should be retried
    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout:
            true
        case let .httpError(statusCode):
            statusCode >= 500 || statusCode == 429
        default:
            false
        }
    }

    /// Whether this error indicates a network connectivity problem
    var isNetworkError: Bool {
        switch self {
        case .networkError, .timeout:
            true
        default:
            false
        }
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The request could not be completed due to an invalid URL."
        case .invalidResponse:
            "The server returned an unexpected response. Please try again."
        case let .httpError(statusCode):
            switch statusCode {
            case 429:
                "Too many requests. Please wait a moment and try again."
            case 500 ... 599:
                "The server is temporarily unavailable. Please try again."
            default:
                "The request failed (error \(statusCode)). Please try again."
            }
        case .decodingError:
            "The server response could not be read. Please try again."
        case .unauthorized:
            "Your session has expired. Please sign in again."
        case .networkError:
            "No internet connection. Check your network settings and try again."
        case .timeout:
            "The request timed out. Check your connection and try again."
        case let .serverError(message):
            message
        }
    }
}
