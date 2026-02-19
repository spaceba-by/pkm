import SwiftUI

/// View model for the knowledge graph visualization
@MainActor
final class GraphViewModel: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var edges: [GraphEdge] = []
    @Published var positions: [String: CGPoint] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedNode: GraphNode?

    private let apiClient: any APIClientProtocol
    private var simulationTask: Task<Void, Never>?
    /// Precomputed connection count per node ID for O(1) lookups
    private var degreeMap: [String: Int] = [:]

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func loadGraph() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.getGraphData()
            nodes = response.nodes
            edges = response.edges
            degreeMap = buildDegreeMap()
            initializePositions()
            runSimulation()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func initializePositions() {
        let center = CGPoint.zero
        let radius: CGFloat = 300.0

        for (index, node) in nodes.enumerated() {
            let angle = (CGFloat(index) / CGFloat(nodes.count)) * 2 * .pi
            let jitter = CGFloat.random(in: -50...50)
            positions[node.id] = CGPoint(
                x: center.x + (radius + jitter) * cos(angle),
                y: center.y + (radius + jitter) * sin(angle)
            )
        }
    }

    private func runSimulation() {
        simulationTask?.cancel()

        let nodeIds = nodes.map(\.id)
        let edgesCopy = edges
        let currentPositions = positions

        simulationTask = Task.detached { [weak self] in
            var positions = currentPositions
            let iterations = 150

            for iteration in 0..<iterations {
                if Task.isCancelled { return }

                let temperature = 1.0 - (Double(iteration) / Double(iterations))
                let maxDisplacement = 10.0 * temperature + 0.5

                var forces = Self.computeForces(
                    nodeIds: nodeIds, edges: edgesCopy, positions: positions
                )
                Self.applyForces(
                    &forces, nodeIds: nodeIds, positions: &positions, maxDisplacement: maxDisplacement
                )

                // Update UI every 5 iterations
                if iteration.isMultiple(of: 5) {
                    let snapshot = positions
                    await MainActor.run { [weak self] in
                        self?.positions = snapshot
                    }
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }

            // Final position update
            let finalPositions = positions
            await MainActor.run { [weak self] in
                self?.positions = finalPositions
            }
        }
    }

    nonisolated private static func computeForces(
        nodeIds: [String], edges: [GraphEdge], positions: [String: CGPoint]
    ) -> [String: CGPoint] {
        var forces: [String: CGPoint] = [:]
        for id in nodeIds { forces[id] = .zero }

        // Repulsion between all nodes
        for i in 0..<nodeIds.count {
            for j in (i + 1)..<nodeIds.count {
                let idA = nodeIds[i]
                let idB = nodeIds[j]
                guard let posA = positions[idA], let posB = positions[idB] else { continue }

                let dx = posA.x - posB.x
                let dy = posA.y - posB.y
                let dist = max(sqrt(dx * dx + dy * dy), 1.0)
                let repulsion: CGFloat = 5000.0 / (dist * dist)
                let fx = (dx / dist) * repulsion
                let fy = (dy / dist) * repulsion

                forces[idA] = CGPoint(x: (forces[idA]?.x ?? 0) + fx, y: (forces[idA]?.y ?? 0) + fy)
                forces[idB] = CGPoint(x: (forces[idB]?.x ?? 0) - fx, y: (forces[idB]?.y ?? 0) - fy)
            }
        }

        // Attraction along edges
        for edge in edges {
            guard let posA = positions[edge.source], let posB = positions[edge.target] else { continue }
            let dx = posB.x - posA.x
            let dy = posB.y - posA.y
            let dist = max(sqrt(dx * dx + dy * dy), 1.0)
            let attraction: CGFloat = (dist - 120.0) * 0.05
            let fx = (dx / dist) * attraction
            let fy = (dy / dist) * attraction

            forces[edge.source] = CGPoint(x: (forces[edge.source]?.x ?? 0) + fx, y: (forces[edge.source]?.y ?? 0) + fy)
            forces[edge.target] = CGPoint(x: (forces[edge.target]?.x ?? 0) - fx, y: (forces[edge.target]?.y ?? 0) - fy)
        }

        // Center gravity
        for id in nodeIds {
            guard let pos = positions[id] else { continue }
            let gravity: CGFloat = 0.01
            forces[id] = CGPoint(x: (forces[id]?.x ?? 0) - pos.x * gravity, y: (forces[id]?.y ?? 0) - pos.y * gravity)
        }

        return forces
    }

    nonisolated private static func applyForces(
        _ forces: inout [String: CGPoint],
        nodeIds: [String],
        positions: inout [String: CGPoint],
        maxDisplacement: Double
    ) {
        for id in nodeIds {
            guard let pos = positions[id], let force = forces[id] else { continue }
            let dx = max(-maxDisplacement, min(maxDisplacement, Double(force.x)))
            let dy = max(-maxDisplacement, min(maxDisplacement, Double(force.y)))
            positions[id] = CGPoint(x: pos.x + CGFloat(dx), y: pos.y + CGFloat(dy))
        }
    }

    private func buildDegreeMap() -> [String: Int] {
        var counts: [String: Int] = [:]
        for edge in edges {
            counts[edge.source, default: 0] += 1
            counts[edge.target, default: 0] += 1
        }
        return counts
    }

    func nodeColor(for node: GraphNode) -> Color {
        switch node.type {
        case "document":
            switch node.classification {
            case "meeting": return .orange
            case "idea": return .yellow
            case "reference": return .blue
            case "journal": return .purple
            case "project": return .green
            default: return .gray
            }
        case "entity":
            switch node.entityType {
            case "people": return .pink
            case "organizations": return .cyan
            case "concepts": return .mint
            case "locations": return .indigo
            default: return .gray
            }
        case "tag":
            return .teal
        default:
            return .gray
        }
    }

    func nodeSize(for node: GraphNode) -> CGFloat {
        let connectionCount = degreeMap[node.id] ?? 0
        let base: CGFloat = node.type == "document" ? 20.0 : 14.0
        return base + CGFloat(min(connectionCount, 10)) * 2.0
    }

    func nodeIcon(for node: GraphNode) -> String {
        switch node.type {
        case "document":
            switch node.classification {
            case "meeting": return "person.3"
            case "idea": return "lightbulb"
            case "reference": return "book"
            case "journal": return "book.closed"
            case "project": return "folder"
            default: return "doc"
            }
        case "entity":
            switch node.entityType {
            case "people": return "person"
            case "organizations": return "building.2"
            case "concepts": return "brain"
            case "locations": return "mappin"
            default: return "circle"
            }
        case "tag":
            return "tag"
        default:
            return "circle"
        }
    }
}
