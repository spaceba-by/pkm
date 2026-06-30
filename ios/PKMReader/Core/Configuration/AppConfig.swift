import Foundation

/// App configuration for the PKMReader app.
/// These are PUBLIC identifiers, not secrets.
/// Cognito client IDs are designed to be embedded in mobile apps.
/// The security comes from user authentication, not hidden identifiers.
///
/// Values populated by scripts/configure-ios.sh from Terraform outputs.
enum AppConfig {
    #if DEBUG
        // Development environment (same deployment for now)
        static let apiBaseURL = URL(string: "https://yv13564xab.execute-api.us-east-1.amazonaws.com/")!
        static let cognitoUserPoolId = "us-east-1_hL1TtgZHP"
        static let cognitoClientId = "3itfc5t9qf390q2k236r5cba5b"
        static let cognitoIdentityPoolId = "us-east-1:1037c9e0-e556-45b6-8ead-983c5a28677f"
    #else
        // Production environment
        static let apiBaseURL = URL(string: "https://yv13564xab.execute-api.us-east-1.amazonaws.com/")!
        static let cognitoUserPoolId = "us-east-1_hL1TtgZHP"
        static let cognitoClientId = "3itfc5t9qf390q2k236r5cba5b"
        static let cognitoIdentityPoolId = "us-east-1:1037c9e0-e556-45b6-8ead-983c5a28677f"
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
