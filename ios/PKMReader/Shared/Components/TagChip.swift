import SwiftUI

/// A small pill-shaped tag display
struct TagChip: View {
    let tag: String

    var body: some View {
        Text("#\(tag)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
