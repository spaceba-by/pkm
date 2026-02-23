@testable import PKMReader
import XCTest

@MainActor
final class GraphViewModelTests: XCTestCase {
    private var sut: GraphViewModel! // swiftlint:disable:this implicitly_unwrapped_optional
    private var mockAPIClient: MockAPIClient! // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = GraphViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    // MARK: - Helpers

    private func makeNode(
        id: String,
        type: String,
        label: String,
        path: String? = nil,
        classification: String? = nil,
        entityType: String? = nil
    ) -> GraphNode {
        GraphNode(
            id: id,
            type: type,
            label: label,
            path: path,
            classification: classification,
            entityType: entityType
        )
    }

    private func loadGraphWith(
        nodes: [GraphNode],
        edges: [GraphEdge] = []
    ) async {
        mockAPIClient.getGraphDataResult = .success(
            GraphDataResponse(
                nodes: nodes,
                edges: edges,
                nodeCount: nodes.count,
                edgeCount: edges.count
            )
        )
        await sut.loadGraph()
    }

    // MARK: - Initial State

    func test_initialState_isEmpty() {
        XCTAssertTrue(sut.nodes.isEmpty)
        XCTAssertTrue(sut.edges.isEmpty)
        XCTAssertTrue(sut.positions.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertNil(sut.selectedNode)
    }

    // MARK: - Load Graph

    func test_loadGraph_success_populatesNodesAndEdges() async {
        let nodes = [
            makeNode(id: "doc:test.md", type: "document", label: "Test", path: "test.md", classification: "reference"),
            makeNode(id: "tag:swift", type: "tag", label: "swift"),
        ]
        let edges = [
            GraphEdge(source: "doc:test.md", target: "tag:swift", type: "tagged", weight: 1),
        ]

        await loadGraphWith(nodes: nodes, edges: edges)

        XCTAssertEqual(sut.nodes.count, 2)
        XCTAssertEqual(sut.edges.count, 1)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertEqual(mockAPIClient.getGraphDataCallCount, 1)
    }

    func test_loadGraph_success_initializesPositions() async {
        let nodes = [
            makeNode(id: "doc:a.md", type: "document", label: "A", path: "a.md", classification: "meeting"),
            makeNode(id: "doc:b.md", type: "document", label: "B", path: "b.md", classification: "idea"),
        ]

        await loadGraphWith(nodes: nodes)

        XCTAssertEqual(sut.positions.count, 2)
        XCTAssertNotNil(sut.positions["doc:a.md"])
        XCTAssertNotNil(sut.positions["doc:b.md"])
    }

    func test_loadGraph_failure_setsError() async {
        mockAPIClient.getGraphDataResult = .failure(APIError.networkError)

        await sut.loadGraph()

        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.nodes.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadGraph_empty_setsEmptyState() async {
        await loadGraphWith(nodes: [])

        XCTAssertTrue(sut.nodes.isEmpty)
        XCTAssertTrue(sut.edges.isEmpty)
        XCTAssertNil(sut.error)
    }

    func test_loadGraph_positionsDistributed() async {
        let nodes = (0 ..< 5).map { i in
            makeNode(
                id: "doc:\(i).md",
                type: "document",
                label: "Doc \(i)",
                path: "\(i).md",
                classification: "reference"
            )
        }

        await loadGraphWith(nodes: nodes)

        XCTAssertEqual(sut.positions.count, 5)
        // Positions should be distinct
        let uniquePositions = Set(sut.positions.values.map { "\(Int($0.x)),\(Int($0.y))" })
        XCTAssertEqual(uniquePositions.count, 5)
    }

    func test_loadGraph_twiceClearsOldData() async {
        let nodes1 = [makeNode(id: "doc:a.md", type: "document", label: "A", classification: "meeting")]
        await loadGraphWith(nodes: nodes1)
        XCTAssertEqual(sut.nodes.count, 1)

        let nodes2 = [
            makeNode(id: "doc:x.md", type: "document", label: "X", classification: "idea"),
            makeNode(id: "doc:y.md", type: "document", label: "Y", classification: "journal"),
        ]
        await loadGraphWith(nodes: nodes2)
        XCTAssertEqual(sut.nodes.count, 2)
        XCTAssertEqual(sut.nodes.first?.id, "doc:x.md")
    }

    // MARK: - Node Colors: Document Classifications

    func test_nodeColor_meeting() {
        let node = makeNode(id: "d1", type: "document", label: "M", classification: "meeting")
        XCTAssertEqual(sut.nodeColor(for: node), .orange)
    }

    func test_nodeColor_idea() {
        let node = makeNode(id: "d1", type: "document", label: "I", classification: "idea")
        XCTAssertEqual(sut.nodeColor(for: node), .yellow)
    }

    func test_nodeColor_reference() {
        let node = makeNode(id: "d1", type: "document", label: "R", classification: "reference")
        XCTAssertEqual(sut.nodeColor(for: node), .blue)
    }

    func test_nodeColor_journal() {
        let node = makeNode(id: "d1", type: "document", label: "J", classification: "journal")
        XCTAssertEqual(sut.nodeColor(for: node), .purple)
    }

    func test_nodeColor_project() {
        let node = makeNode(id: "d1", type: "document", label: "P", classification: "project")
        XCTAssertEqual(sut.nodeColor(for: node), .green)
    }

    func test_nodeColor_unknownClassification() {
        let node = makeNode(id: "d1", type: "document", label: "U", classification: "unknown")
        XCTAssertEqual(sut.nodeColor(for: node), .gray)
    }

    func test_nodeColor_nilClassification() {
        let node = makeNode(id: "d1", type: "document", label: "N")
        XCTAssertEqual(sut.nodeColor(for: node), .gray)
    }

    // MARK: - Node Colors: Entity Types

    func test_nodeColor_people() {
        let node = makeNode(id: "e1", type: "entity", label: "Alice", entityType: "people")
        XCTAssertEqual(sut.nodeColor(for: node), .pink)
    }

    func test_nodeColor_organizations() {
        let node = makeNode(id: "e1", type: "entity", label: "Acme", entityType: "organizations")
        XCTAssertEqual(sut.nodeColor(for: node), .cyan)
    }

    func test_nodeColor_concepts() {
        let node = makeNode(id: "e1", type: "entity", label: "AI", entityType: "concepts")
        XCTAssertEqual(sut.nodeColor(for: node), .mint)
    }

    func test_nodeColor_locations() {
        let node = makeNode(id: "e1", type: "entity", label: "NYC", entityType: "locations")
        XCTAssertEqual(sut.nodeColor(for: node), .indigo)
    }

    func test_nodeColor_unknownEntityType() {
        let node = makeNode(id: "e1", type: "entity", label: "X", entityType: "unknown")
        XCTAssertEqual(sut.nodeColor(for: node), .gray)
    }

    // MARK: - Node Colors: Other Types

    func test_nodeColor_tag() {
        let node = makeNode(id: "t1", type: "tag", label: "swift")
        XCTAssertEqual(sut.nodeColor(for: node), .teal)
    }

    func test_nodeColor_unknownType() {
        let node = makeNode(id: "x1", type: "unknown", label: "X")
        XCTAssertEqual(sut.nodeColor(for: node), .gray)
    }

    // MARK: - Node Size

    func test_nodeSize_documentLargerThanEntity() {
        let docNode = makeNode(id: "d1", type: "document", label: "Doc", classification: "reference")
        let entityNode = makeNode(id: "e1", type: "entity", label: "Entity", entityType: "people")

        XCTAssertGreaterThan(sut.nodeSize(for: docNode), sut.nodeSize(for: entityNode))
    }

    func test_nodeSize_documentBase() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "reference")
        XCTAssertEqual(sut.nodeSize(for: node), 20.0)
    }

    func test_nodeSize_entityBase() {
        let node = makeNode(id: "e1", type: "entity", label: "E", entityType: "people")
        XCTAssertEqual(sut.nodeSize(for: node), 14.0)
    }

    func test_nodeSize_growsWithConnections() async {
        let nodes = [
            makeNode(id: "doc:center.md", type: "document", label: "Center", classification: "reference"),
            makeNode(id: "tag:a", type: "tag", label: "a"),
            makeNode(id: "tag:b", type: "tag", label: "b"),
            makeNode(id: "tag:c", type: "tag", label: "c"),
        ]
        let edges = [
            GraphEdge(source: "doc:center.md", target: "tag:a", type: "tagged", weight: 1),
            GraphEdge(source: "doc:center.md", target: "tag:b", type: "tagged", weight: 1),
            GraphEdge(source: "doc:center.md", target: "tag:c", type: "tagged", weight: 1),
        ]

        await loadGraphWith(nodes: nodes, edges: edges)

        let centerSize = sut.nodeSize(for: nodes[0])
        let leafSize = sut.nodeSize(for: nodes[1])

        // Center has 3 connections, leaf has 1
        XCTAssertGreaterThan(centerSize, leafSize)
        XCTAssertEqual(centerSize, 20.0 + 3 * 2.0) // base + 3 connections * 2
        XCTAssertEqual(leafSize, 14.0 + 1 * 2.0) // tag base + 1 connection * 2
    }

    func test_nodeSize_cappedAtTenConnections() async {
        var nodes = [makeNode(id: "doc:hub.md", type: "document", label: "Hub", classification: "reference")]
        var edges: [GraphEdge] = []
        for i in 0 ..< 15 {
            let tagId = "tag:\(i)"
            nodes.append(makeNode(id: tagId, type: "tag", label: "\(i)"))
            edges.append(GraphEdge(source: "doc:hub.md", target: tagId, type: "tagged", weight: 1))
        }

        await loadGraphWith(nodes: nodes, edges: edges)

        let hubSize = sut.nodeSize(for: nodes[0])
        // Capped at 10 connections: 20 + 10 * 2 = 40
        XCTAssertEqual(hubSize, 40.0)
    }

    // MARK: - Node Icons: Document Types

    func test_nodeIcon_meeting() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "meeting")
        XCTAssertEqual(sut.nodeIcon(for: node), "person.3")
    }

    func test_nodeIcon_idea() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "idea")
        XCTAssertEqual(sut.nodeIcon(for: node), "lightbulb")
    }

    func test_nodeIcon_reference() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "reference")
        XCTAssertEqual(sut.nodeIcon(for: node), "book")
    }

    func test_nodeIcon_journal() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "journal")
        XCTAssertEqual(sut.nodeIcon(for: node), "book.closed")
    }

    func test_nodeIcon_project() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "project")
        XCTAssertEqual(sut.nodeIcon(for: node), "folder")
    }

    func test_nodeIcon_unknownClassification() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "other")
        XCTAssertEqual(sut.nodeIcon(for: node), "doc")
    }

    // MARK: - Node Icons: Entity Types

    func test_nodeIcon_people() {
        let node = makeNode(id: "e1", type: "entity", label: "E", entityType: "people")
        XCTAssertEqual(sut.nodeIcon(for: node), "person")
    }

    func test_nodeIcon_organizations() {
        let node = makeNode(id: "e1", type: "entity", label: "E", entityType: "organizations")
        XCTAssertEqual(sut.nodeIcon(for: node), "building.2")
    }

    func test_nodeIcon_concepts() {
        let node = makeNode(id: "e1", type: "entity", label: "E", entityType: "concepts")
        XCTAssertEqual(sut.nodeIcon(for: node), "brain")
    }

    func test_nodeIcon_locations() {
        let node = makeNode(id: "e1", type: "entity", label: "E", entityType: "locations")
        XCTAssertEqual(sut.nodeIcon(for: node), "mappin")
    }

    func test_nodeIcon_unknownEntityType() {
        let node = makeNode(id: "e1", type: "entity", label: "E", entityType: "unknown")
        XCTAssertEqual(sut.nodeIcon(for: node), "circle")
    }

    // MARK: - Node Icons: Other Types

    func test_nodeIcon_tag() {
        let node = makeNode(id: "t1", type: "tag", label: "T")
        XCTAssertEqual(sut.nodeIcon(for: node), "tag")
    }

    func test_nodeIcon_unknownType() {
        let node = makeNode(id: "x1", type: "unknown", label: "X")
        XCTAssertEqual(sut.nodeIcon(for: node), "circle")
    }

    // MARK: - Selected Node

    func test_selectedNode_canBeSet() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "meeting")
        sut.selectedNode = node
        XCTAssertEqual(sut.selectedNode?.id, "d1")
    }

    func test_selectedNode_canBeCleared() {
        let node = makeNode(id: "d1", type: "document", label: "D", classification: "meeting")
        sut.selectedNode = node
        sut.selectedNode = nil
        XCTAssertNil(sut.selectedNode)
    }

    // MARK: - Graph Model Tests

    func test_graphNode_identifiable() {
        let node = makeNode(id: "test-id", type: "document", label: "Test")
        XCTAssertEqual(node.id, "test-id")
    }

    func test_graphNode_hashable() {
        let node1 = makeNode(id: "a", type: "document", label: "A")
        let node2 = makeNode(id: "b", type: "document", label: "B")
        let set: Set<GraphNode> = [node1, node2, node1]
        XCTAssertEqual(set.count, 2)
    }

    func test_graphEdge_hashable() {
        let edge1 = GraphEdge(source: "a", target: "b", type: "mentions", weight: 1)
        let edge2 = GraphEdge(source: "a", target: "c", type: "mentions", weight: 1)
        let set: Set<GraphEdge> = [edge1, edge2, edge1]
        XCTAssertEqual(set.count, 2)
    }

    func test_graphDataResponse_codable() throws {
        let response = GraphDataResponse(
            nodes: [makeNode(id: "d1", type: "document", label: "Doc", path: "test.md", classification: "reference")],
            edges: [GraphEdge(source: "d1", target: "t1", type: "tagged", weight: 1)],
            nodeCount: 1,
            edgeCount: 1
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(GraphDataResponse.self, from: data)
        XCTAssertEqual(decoded.nodes.count, 1)
        XCTAssertEqual(decoded.edges.count, 1)
        XCTAssertEqual(decoded.nodeCount, 1)
        XCTAssertEqual(decoded.edgeCount, 1)
    }

    func test_graphNode_codable() throws {
        let node = makeNode(
            id: "entity:people:alice",
            type: "entity",
            label: "Alice",
            entityType: "people"
        )
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(GraphNode.self, from: data)
        XCTAssertEqual(decoded.id, "entity:people:alice")
        XCTAssertEqual(decoded.type, "entity")
        XCTAssertEqual(decoded.label, "Alice")
        XCTAssertNil(decoded.path)
        XCTAssertNil(decoded.classification)
        XCTAssertEqual(decoded.entityType, "people")
    }

    func test_graphEdge_codable() throws {
        let edge = GraphEdge(source: "doc:a.md", target: "entity:people:bob", type: "mentions", weight: 2)
        let data = try JSONEncoder().encode(edge)
        let decoded = try JSONDecoder().decode(GraphEdge.self, from: data)
        XCTAssertEqual(decoded.source, "doc:a.md")
        XCTAssertEqual(decoded.target, "entity:people:bob")
        XCTAssertEqual(decoded.type, "mentions")
        XCTAssertEqual(decoded.weight, 2)
    }

    func test_graphNode_allFieldsPresent() throws {
        let node = makeNode(
            id: "doc:test.md",
            type: "document",
            label: "Test Doc",
            path: "test.md",
            classification: "meeting",
            entityType: nil
        )
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(GraphNode.self, from: data)
        XCTAssertEqual(decoded.path, "test.md")
        XCTAssertEqual(decoded.classification, "meeting")
    }

    // MARK: - Simulation

    func test_loadGraph_runsSimulation() async {
        let nodes = [
            makeNode(id: "doc:a.md", type: "document", label: "A", classification: "reference"),
            makeNode(id: "doc:b.md", type: "document", label: "B", classification: "idea"),
        ]
        let edges = [
            GraphEdge(source: "doc:a.md", target: "doc:b.md", type: "links_to", weight: 1),
        ]

        await loadGraphWith(nodes: nodes, edges: edges)

        // Give simulation a moment to run
        try? await Task.sleep(for: .milliseconds(200))

        // After simulation, positions should exist and possibly have moved from initial
        XCTAssertNotNil(sut.positions["doc:a.md"])
        XCTAssertNotNil(sut.positions["doc:b.md"])
    }
}
