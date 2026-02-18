import SwiftUI
import Textual

/// View for displaying a single document with its content
struct DocumentDetailView: View {
    let document: Document
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: DocumentDetailViewModel
    @State private var wikilinkTarget: Document?

    init(document: Document, apiClient: any APIClientProtocol) {
        self.document = document
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: DocumentDetailViewModel(
            document: document,
            apiClient: apiClient
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata header
                metadataSection
                    .padding(.horizontal)

                Divider()

                // Content
                contentSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(document.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent()
        }
        .accessibilityIdentifier("DocumentDetailView")
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "pkm" {
                let target = url.absoluteString.replacingOccurrences(of: "pkm:", with: "")
                Task {
                    if let doc = try? await apiClient.search(query: target, limit: 1).first {
                        wikilinkTarget = doc
                    }
                }
                return .handled
            }
            return .systemAction
        })
        .navigationDestination(item: $wikilinkTarget) { doc in
            DocumentDetailView(document: doc, apiClient: apiClient)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Classification badge with picker
            classificationBadgeWithPicker

            // Tags
            if !document.metadata.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(document.metadata.tags, id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                }
            }

            // Entities
            if let entities = document.metadata.entities {
                entitiesSection(entities)
            }

            // Dates
            HStack {
                Label {
                    Text(document.metadata.created, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Text("Modified \(document.metadata.modified, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var classificationBadgeWithPicker: some View {
        Menu {
            ForEach(DocumentClassification.allCases, id: \.self) { type in
                Button {
                    Task {
                        await viewModel.updateClassification(to: type)
                    }
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
                .disabled(type == viewModel.classification)
            }
        } label: {
            HStack(spacing: 4) {
                ClassificationBadge(classification: viewModel.classification)
                if viewModel.isUpdatingClassification {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .accessibilityLabel("Change classification, currently \(viewModel.classification.displayName)")
        .alert(
            "Classification Update Failed",
            isPresented: Binding(
                get: { viewModel.classificationUpdateError != nil },
                set: { if !$0 { viewModel.classificationUpdateError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not update the classification. Please try again.")
        }
    }

    @ViewBuilder private var contentSection: some View {
        switch viewModel.contentState {
        case .loading:
            LoadingView(message: "Loading content...")
                .frame(minHeight: 200)

        case .loaded(let content):
            StructuredText(markdown: content)
                .textSelection(.enabled)
                .accessibilityIdentifier("DocumentContent")

        case .error(let error):
            ErrorView(error: error) {
                Task { await viewModel.loadContent() }
            }
        }
    }

    @ViewBuilder
    private func entitiesSection(_ entities: DocumentEntities) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let people = entities.people, !people.isEmpty {
                entityRow(icon: "person", items: people)
            }
            if let orgs = entities.organizations, !orgs.isEmpty {
                entityRow(icon: "building.2", items: orgs)
            }
            if let concepts = entities.concepts, !concepts.isEmpty {
                entityRow(icon: "lightbulb", items: concepts)
            }
            if let locations = entities.locations, !locations.isEmpty {
                entityRow(icon: "mappin", items: locations)
            }
        }
    }

    private func entityRow(icon: String, items: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(.secondary)

            Text(items.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DocumentDetailView(
            document: Document(
                id: "test/sample.md",
                title: "Sample Document",
                content: "# Hello World\n\nThis is a sample document with **bold** and *italic* text.",
                metadata: DocumentMetadata(
                    classification: .reference,
                    tags: ["test", "sample", "preview"],
                    linksTo: [],
                    entities: DocumentEntities(
                        people: ["John Doe", "Jane Smith"],
                        organizations: ["Acme Corp"],
                        concepts: ["Testing"],
                        locations: nil
                    ),
                    created: Date().addingTimeInterval(-86400 * 7),
                    modified: Date(),
                    hasFrontmatter: true
                )
            ),
            apiClient: PreviewAPIClient()
        )
    }
}

/// Preview-only mock API client
private final class PreviewAPIClient: APIClientProtocol, @unchecked Sendable {
    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse {
        DocumentListResponse(documents: [], nextCursor: nil)
    }

    func getDocument(key: String) async throws -> Document {
        Document(
            id: key,
            title: "Preview Document",
            content: "# Preview\n\nThis is a preview document.",
            metadata: DocumentMetadata(
                classification: .reference,
                tags: ["preview"],
                linksTo: [],
                entities: nil,
                created: Date(),
                modified: Date(),
                hasFrontmatter: false
            )
        )
    }

    func search(query: String, limit: Int) async throws -> [Document] { [] }
    func listTags() async throws -> [Tag] { [] }
    func listClassifications() async throws -> [ClassificationCount] { [] }
    func listSummaries(limit: Int) async throws -> [Summary] { [] }
    func listReports(limit: Int) async throws -> [Report] { [] }
    func documentsByTag(tag: String, limit: Int) async throws -> [Document] { [] }
    func updateClassification(documentId: String, classification: DocumentClassification) async throws {}
}
