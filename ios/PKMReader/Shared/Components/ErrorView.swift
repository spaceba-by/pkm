import SwiftUI

/// A view displaying an error with a retry button
struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry") {
                retryAction()
            }
            .buttonStyle(.bordered)
        }
        .accessibilityIdentifier("ErrorView")
    }
}

#Preview {
    ErrorView(error: APIError.networkError) {
        print("Retry tapped")
    }
}
