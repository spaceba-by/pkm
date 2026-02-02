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
            self.error = authError.localizedDescription
        } catch {
            self.error = "An unexpected error occurred"
        }

        isLoading = false
    }
}
