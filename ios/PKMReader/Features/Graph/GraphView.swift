import SwiftUI

/// Interactive knowledge graph visualization with zoom, pan, and node selection
struct GraphView: View {
    let apiClient: any APIClientProtocol
    @StateObject private var viewModel: GraphViewModel
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var navigateDocument: Document?
    @State private var isLoadingDocument = false

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
        _viewModel = StateObject(wrappedValue: GraphViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Building knowledge graph...")
                } else if let error = viewModel.error {
                    ErrorView(error: error) {
                        Task { await viewModel.loadGraph() }
                    }
                } else if viewModel.nodes.isEmpty {
                    EmptyStateView(
                        icon: "circle.hexagongrid",
                        title: "No Graph Data",
                        message: "Add documents with entities to see the knowledge graph."
                    )
                } else {
                    graphCanvas
                }
            }
            .navigationTitle("Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    legendMenu
                }
            }
            .navigationDestination(item: $navigateDocument) { document in
                DocumentDetailView(document: document, apiClient: apiClient)
            }
            .task {
                await viewModel.loadGraph()
            }
            .accessibilityIdentifier("GraphView")
        }
    }

    private var graphCanvas: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            Canvas { context, _ in
                let transform = CGAffineTransform(
                    translationX: center.x + offset.width,
                    y: center.y + offset.height
                ).scaledBy(x: scale, y: scale)

                // Draw edges
                for edge in viewModel.edges {
                    guard let sourcePos = viewModel.positions[edge.source],
                          let targetPos = viewModel.positions[edge.target] else { continue }

                    let from = sourcePos.applying(transform)
                    let to = targetPos.applying(transform)

                    var path = Path()
                    path.move(to: from)
                    path.addLine(to: to)

                    let opacity = edgeOpacity(for: edge)
                    let lineWidth = edge.type == "links_to" ? 1.5 : 0.8
                    context.stroke(path,
                                   with: .color(.secondary.opacity(opacity)),
                                   lineWidth: lineWidth * scale)
                }

                // Draw nodes
                for node in viewModel.nodes {
                    guard let pos = viewModel.positions[node.id] else { continue }
                    let screenPos = pos.applying(transform)
                    let nodeSize = viewModel.nodeSize(for: node) * scale
                    let isSelected = viewModel.selectedNode?.id == node.id

                    let rect = CGRect(x: screenPos.x - nodeSize / 2,
                                      y: screenPos.y - nodeSize / 2,
                                      width: nodeSize,
                                      height: nodeSize)

                    let color = viewModel.nodeColor(for: node)

                    if isSelected {
                        let selectionRect = rect.insetBy(dx: -3 * scale, dy: -3 * scale)
                        context.fill(Circle().path(in: selectionRect),
                                     with: .color(color.opacity(0.3)))
                    }

                    context.fill(Circle().path(in: rect), with: .color(color))

                    // Draw label for larger or selected nodes
                    if nodeSize > 16 * scale || isSelected {
                        let label = Text(node.label)
                            .font(.system(size: max(8, 10 * scale)))
                            .foregroundColor(.primary)
                        let labelPoint = CGPoint(x: screenPos.x, y: screenPos.y + nodeSize / 2 + 8 * scale)
                        context.draw(label, at: labelPoint)
                    }
                }
            }
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.1, min(5.0, value.magnitude))
                        },
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )
            .onTapGesture { location in
                handleTap(at: location, center: center)
            }
            .accessibilityIdentifier("GraphCanvas")

            // Selected node overlay
            if let selected = viewModel.selectedNode {
                nodeDetailOverlay(node: selected)
            }
        }
    }

    private var legendMenu: some View {
        Menu {
            Section("Documents") {
                Label("Meeting", systemImage: "person.3")
                Label("Idea", systemImage: "lightbulb")
                Label("Reference", systemImage: "book")
                Label("Journal", systemImage: "book.closed")
                Label("Project", systemImage: "folder")
            }
            Section("Entities") {
                Label("Person", systemImage: "person")
                Label("Organization", systemImage: "building.2")
                Label("Concept", systemImage: "brain")
                Label("Location", systemImage: "mappin")
            }
            Section("Other") {
                Label("Tag", systemImage: "tag")
            }
        } label: {
            Image(systemName: "info.circle")
        }
        .accessibilityLabel("Graph legend")
    }

    @ViewBuilder
    private func nodeDetailOverlay(node: GraphNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: viewModel.nodeIcon(for: node))
                    .foregroundStyle(viewModel.nodeColor(for: node))
                Text(node.label)
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.selectedNode = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Text(nodeTypeDescription(node))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let connections = connectionCount(for: node)
            Text("\(connections) connection\(connections == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if node.type == "document", let path = node.path {
                Button {
                    openDocument(path: path)
                } label: {
                    if isLoadingDocument {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Open Document")
                    }
                }
                .font(.subheadline)
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingDocument)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityIdentifier("NodeDetailOverlay")
    }

    private func openDocument(path: String) {
        isLoadingDocument = true
        Task {
            do {
                let document = try await apiClient.getDocument(key: path)
                navigateDocument = document
            } catch {
                viewModel.error = error
            }
            isLoadingDocument = false
        }
    }

    private func handleTap(at location: CGPoint, center: CGPoint) {
        let tapRadius: CGFloat = 30.0

        for node in viewModel.nodes {
            guard let pos = viewModel.positions[node.id] else { continue }

            let transform = CGAffineTransform(
                translationX: center.x + offset.width,
                y: center.y + offset.height
            )
                .scaledBy(x: scale, y: scale)
            let screenPos = pos.applying(transform)

            let dx = location.x - screenPos.x
            let dy = location.y - screenPos.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < tapRadius {
                if viewModel.selectedNode?.id == node.id {
                    viewModel.selectedNode = nil
                } else {
                    viewModel.selectedNode = node
                }
                return
            }
        }

        viewModel.selectedNode = nil
    }

    private func edgeOpacity(for edge: GraphEdge) -> Double {
        if let selected = viewModel.selectedNode {
            if edge.source == selected.id || edge.target == selected.id {
                return 0.8
            }
            return 0.1
        }
        return 0.3
    }

    private func nodeTypeDescription(_ node: GraphNode) -> String {
        switch node.type {
        case "document":
            return "Document (\(node.classification?.capitalized ?? "Unknown"))"
        case "entity":
            return "Entity (\(node.entityType?.capitalized ?? "Unknown"))"
        case "tag":
            return "Tag"
        default:
            return node.type.capitalized
        }
    }

    private func connectionCount(for node: GraphNode) -> Int {
        viewModel.edges.filter { $0.source == node.id || $0.target == node.id }.count
    }
}
