import SwiftUI

/// Search view with debounced text input and results
struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Search Documents",
                        message: "Enter at least 2 characters to search"
                    )

                case .loading:
                    LoadingView(message: "Searching...")

                case .loaded(let documents):
                    resultsList(documents)

                case .empty:
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No documents match your search"
                    )

                case .error(let errorMessage):
                    ErrorView(error: GenericError(message: errorMessage)) {
                        Task { await viewModel.search() }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search documents..."
            )
            .refreshable {
                await viewModel.search()
            }
        }
        .accessibilityIdentifier("SearchView")
    }

    private func resultsList(_ documents: [Document]) -> some View {
        List {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
                .accessibilityIdentifier("SearchResult_\(document.id)")
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document, apiClient: viewModel.apiClient)
        }
        .accessibilityIdentifier("SearchResultsList")
    }
}

/// Simple error wrapper for displaying error messages
private struct GenericError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
