import SwiftUI

/// A badge showing the document classification
struct ClassificationBadge: View {
    let classification: DocumentClassification

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: classification.icon)
            Text(classification.displayName)
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(classification.color.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityLabel("Classification: \(classification.displayName)")
    }
}

// Add color property to DocumentClassification
extension DocumentClassification {
    var color: Color {
        switch self {
        case .meeting: .blue
        case .idea: .yellow
        case .reference: .green
        case .journal: .purple
        case .project: .orange
        }
    }
}

#Preview {
    VStack {
        ForEach(DocumentClassification.allCases, id: \.self) { classification in
            ClassificationBadge(classification: classification)
        }
    }
    .padding()
}
