import SwiftUI
import Textual

/// View for creating and editing documents
struct DocumentEditorView: View {
    @StateObject private var viewModel: DocumentEditorViewModel
    private var onSave: (() -> Void)?

    @Environment(\.dismiss)
    private var dismiss

    init(mode: DocumentEditorViewModel.Mode, apiClient: any APIClientProtocol, onSave: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: DocumentEditorViewModel(
            mode: mode,
            apiClient: apiClient
        ))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if case .create = viewModel.mode {
                    createFormHeader
                    Divider()
                }

                if viewModel.showPreview {
                    previewSection
                } else {
                    editorSection
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.showPreview.toggle()
                        } label: {
                            Image(systemName: viewModel.showPreview ? "pencil" : "eye")
                        }
                        .accessibilityLabel(viewModel.showPreview ? "Edit" : "Preview")

                        Button("Save") {
                            Task { await viewModel.save() }
                        }
                        .disabled(!viewModel.isValid || viewModel.saveState == .saving)
                    }
                }
            }
            .overlay {
                if viewModel.saveState == .saving {
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Error", isPresented: Binding(
                get: {
                    if case .error = viewModel.saveState { return true }
                    return false
                },
                set: { if !$0 { viewModel.resetSaveState() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if case let .error(message) = viewModel.saveState {
                    Text(message)
                }
            }
            .onChange(of: viewModel.saveState) { _, newState in
                if newState == .saved {
                    onSave?()
                    dismiss()
                }
            }
            .accessibilityIdentifier("DocumentEditorView")
        }
    }

    private var createFormHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Document path (e.g. notes/my-note.md)", text: $viewModel.documentKey)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityIdentifier("DocumentKeyField")

            TextField("Title (optional)", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("DocumentTitleField")
        }
        .padding()
    }

    private var editorSection: some View {
        TextEditor(text: $viewModel.content)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 4)
            .accessibilityIdentifier("DocumentContentEditor")
    }

    private var previewSection: some View {
        ScrollView {
            StructuredText(markdown: viewModel.content)
                .padding()
        }
        .accessibilityIdentifier("DocumentPreview")
    }
}
