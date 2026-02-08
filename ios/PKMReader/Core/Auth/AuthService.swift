import Amplify
import AWSCognitoAuthPlugin
import Foundation

/// Manages authentication state and operations using AWS Cognito via Amplify
@MainActor
final class AuthService: AuthServiceProtocol, ObservableObject {
    /// Shared instance for app-wide use
    static let shared = AuthService()

    /// Published authentication state
    @Published private(set) var authState: AuthState = .unknown

    private init() {}

    /// Configure Amplify - call once at app startup
    func configure() async throws {
        // Validate Cognito config before Amplify tries to parse pool IDs.
        // Amplify force-unwraps on the "_" separator in pool IDs, so placeholder
        // values like "COGNITO_USER_POOL_ID" cause a crash.
        try Self.validateCognitoConfiguration()

        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
            await checkAuthStatus()
        } catch {
            authState = .signedOut
            throw AuthError.unknown("Failed to configure Amplify: \(error.localizedDescription)")
        }
    }

    /// Validate that amplifyconfiguration.json contains real Cognito IDs, not placeholders.
    private static func validateCognitoConfiguration() throws {
        guard let configURL = Bundle.main.url(forResource: "amplifyconfiguration", withExtension: "json"),
              let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.unknown(
                "Missing amplifyconfiguration.json. Run scripts/configure-ios.sh from the terraform/ directory."
            )
        }

        // Navigate to CognitoUserPool.Default.PoolId
        guard let auth = json["auth"] as? [String: Any],
              let plugins = auth["plugins"] as? [String: Any],
              let cognito = plugins["awsCognitoAuthPlugin"] as? [String: Any],
              let pool = cognito["CognitoUserPool"] as? [String: Any],
              let defaultPool = pool["Default"] as? [String: Any],
              let poolId = defaultPool["PoolId"] as? String else {
            throw AuthError.unknown(
                "Invalid amplifyconfiguration.json structure. Run scripts/configure-ios.sh from the terraform/ directory."
            )
        }

        // Cognito pool IDs must contain "_" (e.g. "us-east-1_AbCdEfGhI")
        guard poolId.contains("_") else {
            throw AuthError.unknown(
                "Cognito User Pool ID is not configured (found \"\(poolId)\"). "
                + "Run scripts/configure-ios.sh from the terraform/ directory to populate real values."
            )
        }
    }

    /// Check current authentication status
    func checkAuthStatus() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            authState = session.isSignedIn ? .signedIn : .signedOut
        } catch {
            authState = .signedOut
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
    nonisolated func signIn(email: String, password: String) async throws {
        do {
            let result = try await Amplify.Auth.signIn(username: email, password: password)

            if result.isSignedIn {
                await MainActor.run {
                    self.authState = .signedIn
                }
            } else if case .confirmSignUp = result.nextStep {
                throw AuthError.accountNotConfirmed
            } else {
                throw AuthError.invalidCredentials
            }
        } catch let authError as AuthError {
            throw authError
        } catch let amplifyError as AmplifyError {
            throw mapAmplifyError(amplifyError)
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    /// Sign out the current user
    nonisolated func signOut() async throws {
        _ = await Amplify.Auth.signOut()
        await MainActor.run {
            self.authState = .signedOut
        }
    }

    /// Get the current access token for API requests
    nonisolated func getAccessToken() async throws -> String {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()

            // Cast to AWSAuthCognitoSession to access Cognito-specific tokens
            guard let cognitoSession = session as? AWSAuthCognitoSession else {
                throw AuthError.notAuthenticated
            }

            let tokensResult = cognitoSession.getCognitoTokens()
            switch tokensResult {
            case .success(let tokens):
                return tokens.accessToken
            case .failure:
                throw AuthError.notAuthenticated
            }
        } catch let authError as AuthError {
            throw authError
        } catch {
            throw AuthError.notAuthenticated
        }
    }

    /// Map Amplify errors to our AuthError type
    nonisolated private func mapAmplifyError(_ error: AmplifyError) -> AuthError {
        let description = error.errorDescription.lowercased()

        if description.contains("not authorized") || description.contains("incorrect") {
            return .invalidCredentials
        } else if description.contains("not confirmed") {
            return .accountNotConfirmed
        } else if description.contains("user not found") {
            return .invalidCredentials
        } else if description.contains("password") {
            return .invalidPassword
        } else if description.contains("already exists") {
            return .userAlreadyExists
        } else {
            return .unknown(error.errorDescription)
        }
    }
}
