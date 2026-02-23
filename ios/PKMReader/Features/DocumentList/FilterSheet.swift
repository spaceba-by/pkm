import SwiftUI

/// Sheet for filtering documents by classification and tag
struct FilterSheet: View {
    @Binding var selectedClassification: DocumentClassification?
    @Binding var selectedTag: Tag?
    let tags: [Tag]
    let onApply: () -> Void

    @Environment(\.dismiss)
    private var dismissAction: DismissAction

    @State private var tagSearchText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Classification") {
                    Button {
                        selectedClassification = nil
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.primary)
                            Text("All Documents")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedClassification == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .accessibilityHint("Shows all document types")
                    .accessibilityIdentifier("Filter_All")

                    ForEach(DocumentClassification.allCases, id: \.self) { classification in
                        Button {
                            selectedClassification = classification
                        } label: {
                            HStack {
                                Image(systemName: classification.icon)
                                    .foregroundStyle(classification.color)
                                Text(classification.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedClassification == classification {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .accessibilityHint("Filters to \(classification.displayName.lowercased()) documents only")
                        .accessibilityIdentifier("Filter_\(classification.rawValue)")
                    }
                }

                if !tags.isEmpty {
                    Section("Tags") {
                        ForEach(filteredTags) { tag in
                            Button {
                                if selectedTag?.id == tag.id {
                                    selectedTag = nil
                                } else {
                                    selectedTag = tag
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundStyle(.secondary)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(tag.documentCount)")
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                    if selectedTag?.id == tag.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .accessibilityIdentifier("Filter_Tag_\(tag.name)")
                        }
                    }
                }
            }
            .searchable(text: $tagSearchText, prompt: "Filter tags...")
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismissAction()
                    }
                    .accessibilityIdentifier("ApplyFilterButton")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissAction()
                    }
                }
            }
        }
    }

    private var filteredTags: [Tag] {
        if tagSearchText.isEmpty {
            return tags
        }
        return tags.filter { $0.name.localizedCaseInsensitiveContains(tagSearchText) }
    }

    init(
        selectedClassification: Binding<DocumentClassification?>,
        selectedTag: Binding<Tag?>,
        tags: [Tag],
        onApply: @escaping () -> Void
    ) {
        _selectedClassification = selectedClassification
        _selectedTag = selectedTag
        self.tags = tags
        self.onApply = onApply
    }
}

#Preview {
    FilterSheet(
        selectedClassification: Binding.constant(DocumentClassification.meeting),
        selectedTag: Binding.constant(nil),
        tags: [
            Tag(id: "meeting", name: "meeting", documentCount: 10),
            Tag(id: "project", name: "project", documentCount: 7),
        ]
    ) {
        print("Applied")
    }
}
