import SwiftUI

/// A row displaying document information in a list
struct DocumentRowView: View {
    let document: Document

    @ScaledMetric(relativeTo: .body)
    private var verticalPadding: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with classification icon
            HStack(spacing: 8) {
                Image(systemName: document.metadata.classification.icon)
                    .foregroundStyle(document.metadata.classification.color)
                    .accessibilityHidden(true)

                Text(document.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
            }

            // Tags
            if !document.metadata.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(document.metadata.tags.prefix(5), id: \.self) { tag in
                            TagChip(tag: tag)
                        }
                        if document.metadata.tags.count > 5 {
                            Text("+\(document.metadata.tags.count - 5)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Modified date
            Text(document.metadata.modified, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, verticalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.displayTitle), \(document.metadata.classification.displayName)")
    }
}

#Preview {
    List {
        DocumentRowView(document: Document(
            id: "test/sample.md",
            title: "Sample Document with a Long Title That Might Wrap",
            content: nil,
            metadata: DocumentMetadata(
                classification: .meeting,
                tags: ["meeting", "weekly", "team", "planning", "Q1", "review"],
                linksTo: [],
                entities: nil,
                created: Date(),
                modified: Date().addingTimeInterval(-3600),
                hasFrontmatter: true
            )
        ))
    }
    .listStyle(.plain)
}
