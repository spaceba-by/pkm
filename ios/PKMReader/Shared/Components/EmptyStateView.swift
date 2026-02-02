import SwiftUI

/// A view displaying an empty state with icon, title, and message
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
        .accessibilityIdentifier("EmptyStateView")
    }
}

#Preview {
    EmptyStateView(
        icon: "doc.text",
        title: "No Documents",
        message: "Your vault is empty"
    )
}
