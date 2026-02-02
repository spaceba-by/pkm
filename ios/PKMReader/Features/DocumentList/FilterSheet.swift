import SwiftUI

/// Sheet for filtering documents by classification
struct FilterSheet: View {
    @Binding var selectedClassification: DocumentClassification?
    let onApply: () -> Void

    @Environment(\.dismiss)
    private var dismissAction: DismissAction

    var body: some View {
        NavigationStack {
            List {
                Section("Classification") {
                    // All documents option
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
                    .accessibilityIdentifier("Filter_All")

                    // Classification options
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
                        .accessibilityIdentifier("Filter_\(classification.rawValue)")
                    }
                }
            }
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

    init(selectedClassification: Binding<DocumentClassification?>, onApply: @escaping () -> Void) {
        self._selectedClassification = selectedClassification
        self.onApply = onApply
    }
}

#Preview {
    FilterSheet(selectedClassification: Binding.constant(DocumentClassification.meeting)) {
        print("Applied")
    }
}
