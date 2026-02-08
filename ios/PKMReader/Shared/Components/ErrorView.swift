import SwiftUI

/// A view displaying an error with an optional retry button
struct ErrorView: View {
    let error: Error
    var retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            if let retryAction {
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityIdentifier("ErrorView")
    }
}

#Preview {
    ErrorView(error: APIError.networkError) {
        print("Retry tapped")
    }
}
