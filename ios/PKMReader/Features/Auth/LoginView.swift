import SwiftUI

/// Login screen for user authentication
struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    init(authService: any AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and title
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)

                        Text("PKM Reader")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Sign in to access your vault")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Login form
                    VStack(spacing: 16) {
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .accessibilityIdentifier("EmailField")

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await viewModel.signIn() } }
                            .accessibilityIdentifier("PasswordField")
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                    // Error message
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .accessibilityIdentifier("ErrorMessage")
                    }

                    // Sign in button
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                    .accessibilityHint("Signs in with your email and password")
                    .accessibilityIdentifier("SignInButton")

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    LoginView(authService: PreviewAuthService())
}

/// Preview-only mock auth service
private final class PreviewAuthService: AuthServiceProtocol, @unchecked Sendable {
    var isAuthenticated: Bool { false }

    func signIn(email: String, password: String) async throws {}
    func signOut() async throws {}
    func getAccessToken() async throws -> String { "preview-token" }
}
