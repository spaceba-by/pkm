import SwiftUI

/// A view displaying an error with an optional retry button
struct ErrorView: View {
    let error: Error
    var retryAction: (() -> Void)?

    private var isNetworkError: Bool {
        if let apiError = error as? APIError {
            return apiError.isNetworkError
        }
        return false
    }

    private var icon: String {
        isNetworkError ? "wifi.slash" : "exclamationmark.triangle"
    }

    private var title: String {
        isNetworkError ? "No Connection" : "Error"
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(error.localizedDescription)
        } actions: {
            if let retryAction {
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Attempts the failed operation again")
            }
        }
        .accessibilityIdentifier("ErrorView")
    }
}

#Preview("Network Error") {
    ErrorView(error: APIError.networkError) {
        print("Retry tapped")
    }
}

#Preview("Generic Error") {
    ErrorView(error: APIError.decodingError) {
        print("Retry tapped")
    }
}
