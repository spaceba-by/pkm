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
            return true
        case .httpError(let statusCode):
            return statusCode >= 500 || statusCode == 429
        default:
            return false
        }
    }

    /// Whether this error indicates a network connectivity problem
    var isNetworkError: Bool {
        switch self {
        case .networkError, .timeout:
            return true
        default:
            return false
        }
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request could not be completed due to an invalid URL."
        case .invalidResponse:
            return "The server returned an unexpected response. Please try again."
        case .httpError(let statusCode):
            switch statusCode {
            case 429:
                return "Too many requests. Please wait a moment and try again."
            case 500...599:
                return "The server is temporarily unavailable. Please try again."
            default:
                return "The request failed (error \(statusCode)). Please try again."
            }
        case .decodingError:
            return "The server response could not be read. Please try again."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .networkError:
            return "No internet connection. Check your network settings and try again."
        case .timeout:
            return "The request timed out. Check your connection and try again."
        case .serverError(let message):
            return message
        }
    }
}
