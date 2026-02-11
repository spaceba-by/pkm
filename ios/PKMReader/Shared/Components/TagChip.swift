import SwiftUI

/// A small pill-shaped tag display
struct TagChip: View {
    let tag: String

    @ScaledMetric(relativeTo: .caption)
    private var horizontalPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .caption)
    private var verticalPadding: CGFloat = 4

    var body: some View {
        Text("#\(tag)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(.secondary.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Tag: \(tag)")
    }
}

#Preview {
    HStack {
        TagChip(tag: "meeting")
        TagChip(tag: "project")
        TagChip(tag: "idea")
    }
    .padding()
}
