import XCTest
@testable import PKMReader

@MainActor
final class GraphViewModelTests: XCTestCase {
    private var sut: GraphViewModel!  // swiftlint:disable:this implicitly_unwrapped_optional
    private var mockAPIClient: MockAPIClient!  // swiftlint:disable:this implicitly_unwrapped_optional

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
            makeNode(
                id: "doc:test.md",
                type: "document",
                label: "Test",
                path: "test.md",
                classification: "reference"
            ),
            makeNode(id: "tag:swift", type: "tag", label: "swift")
        ]
        let edges = [
            GraphEdge(source: "doc:test.md", target: "tag:swift", type: "tagged", weight: 1)
        ]
        mockAPIClient.getGraphDataResult = .success(
            GraphDataResponse(nodes: nodes, edges: edges, nodeCount: 2, edgeCount: 1)
        )

        await sut.loadGraph()

        XCTAssertEqual(sut.nodes.count, 2)
        XCTAssertEqual(sut.edges.count, 1)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertEqual(mockAPIClient.getGraphDataCallCount, 1)
    }

    func test_loadGraph_success_initializesPositions() async {
        let nodes = [
            makeNode(
                id: "doc:a.md",
                type: "document",
                label: "A",
                path: "a.md",
                classification: "meeting"
            ),
            makeNode(
                id: "doc:b.md",
                type: "document",
                label: "B",
                path: "b.md",
                classification: "idea"
            )
        ]
        mockAPIClient.getGraphDataResult = .success(
            GraphDataResponse(nodes: nodes, edges: [], nodeCount: 2, edgeCount: 0)
        )

        await sut.loadGraph()

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
        mockAPIClient.getGraphDataResult = .success(
            GraphDataResponse(nodes: [], edges: [], nodeCount: 0, edgeCount: 0)
        )

        await sut.loadGraph()

        XCTAssertTrue(sut.nodes.isEmpty)
        XCTAssertTrue(sut.edges.isEmpty)
        XCTAssertNil(sut.error)
    }

    // MARK: - Node Colors

    func test_nodeColor_documentTypes() {
        let meetingNode = makeNode(id: "d1", type: "document", label: "M", classification: "meeting")
        let ideaNode = makeNode(id: "d2", type: "document", label: "I", classification: "idea")
        let refNode = makeNode(id: "d3", type: "document", label: "R", classification: "reference")

        XCTAssertNotEqual(sut.nodeColor(for: meetingNode), sut.nodeColor(for: ideaNode))
        XCTAssertNotEqual(sut.nodeColor(for: meetingNode), sut.nodeColor(for: refNode))
    }

    func test_nodeColor_entityTypes() {
        let personNode = makeNode(id: "e1", type: "entity", label: "Alice", entityType: "people")
        let orgNode = makeNode(id: "e2", type: "entity", label: "Acme", entityType: "organizations")

        XCTAssertNotEqual(sut.nodeColor(for: personNode), sut.nodeColor(for: orgNode))
    }

    func test_nodeColor_tagType() {
        let tagNode = makeNode(id: "t1", type: "tag", label: "swift")
        let color = sut.nodeColor(for: tagNode)
        XCTAssertNotNil(color)
    }

    // MARK: - Node Size

    func test_nodeSize_documentLargerThanEntity() {
        let docNode = makeNode(id: "d1", type: "document", label: "Doc", classification: "reference")
        let entityNode = makeNode(id: "e1", type: "entity", label: "Entity", entityType: "people")

        XCTAssertGreaterThan(sut.nodeSize(for: docNode), sut.nodeSize(for: entityNode))
    }

    // MARK: - Node Icon

    func test_nodeIcon_returnsAppropriateIcons() {
        let docNode = makeNode(id: "d1", type: "document", label: "D", classification: "meeting")
        let personNode = makeNode(id: "e1", type: "entity", label: "P", entityType: "people")
        let tagNode = makeNode(id: "t1", type: "tag", label: "T")

        XCTAssertEqual(sut.nodeIcon(for: docNode), "person.3")
        XCTAssertEqual(sut.nodeIcon(for: personNode), "person")
        XCTAssertEqual(sut.nodeIcon(for: tagNode), "tag")
    }
}
