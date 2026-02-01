import Foundation

/// Environment configuration for the PKMReader app.
/// These are PUBLIC identifiers, not secrets.
/// Cognito client IDs are designed to be embedded in mobile apps.
/// The security comes from user authentication, not hidden identifiers.
enum Environment {
    #if DEBUG
    static let apiBaseURL = URL(string: "https://api-dev.pkm.spaceba.by")!
    static let cognitoUserPoolId = "us-east-1_DevPoolId"
    static let cognitoClientId = "dev-client-id"
    #else
    static let apiBaseURL = URL(string: "https://api.pkm.spaceba.by")!
    static let cognitoUserPoolId = "us-east-1_ProdPoolId"
    static let cognitoClientId = "prod-client-id"
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
