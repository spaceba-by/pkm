import SwiftUI

/// View displaying all tags with document counts
struct TagsView: View {
    @StateObject private var viewModel: TagsViewModel

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: TagsViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView(message: "Loading tags...")

                case .loaded(let tags):
                    tagsList(tags)

                case .empty:
                    EmptyStateView(
                        icon: "tag",
                        title: "No Tags",
                        message: "No tags found in your vault"
                    )

                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadTags() }
                    }
                }
            }
            .navigationTitle("Tags")
            .refreshable {
                await viewModel.refresh()
            }
            .navigationDestination(for: Tag.self) { tag in
                TagDocumentsView(tag: tag, apiClient: viewModel.apiClient)
            }
        }
        .task {
            await viewModel.loadTags()
        }
        .accessibilityIdentifier("TagsView")
    }

    private func tagsList(_ tags: [Tag]) -> some View {
        List {
            ForEach(tags) { tag in
                NavigationLink(value: tag) {
                    HStack {
                        Label(tag.name, systemImage: "tag")
                        Spacer()
                        Text("\(tag.documentCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(tag.name), \(tag.documentCount) \(tag.documentCount == 1 ? "document" : "documents")"
                )
                .accessibilityIdentifier("TagRow_\(tag.name)")
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("TagsList")
    }
}
