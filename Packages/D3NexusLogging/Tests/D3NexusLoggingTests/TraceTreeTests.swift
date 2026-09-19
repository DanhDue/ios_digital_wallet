import XCTest
@testable import D3NexusLogging

final class TraceTreeTests: XCTestCase {
    private func makeRecord(
        spanId: String,
        parentSpanId: String? = nil,
        message: String = "Test"
    ) -> LogRecord {
        LogRecord(
            module: "Test",
            level: .info,
            message: message,
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: spanId,
            parentSpanId: parentSpanId
        )
    }

    func testThreeLevelTreeFromOrderedRecords() {
        let recordA = makeRecord(spanId: "span_A", parentSpanId: nil, message: "1")
        let recordB = makeRecord(spanId: "span_B", parentSpanId: "span_A", message: "2")
        let recordC = makeRecord(spanId: "span_C", parentSpanId: "span_B", message: "3")

        let forest = buildTraceTree([recordA, recordB, recordC])

        XCTAssertEqual(forest.count, 1)
        let root = forest[0]
        XCTAssertEqual(root.record.spanId, "span_A")
        XCTAssertEqual(root.children.count, 1)

        let child = root.children[0]
        XCTAssertEqual(child.record.spanId, "span_B")
        XCTAssertEqual(child.children.count, 1)

        let grandchild = child.children[0]
        XCTAssertEqual(grandchild.record.spanId, "span_C")
        XCTAssertTrue(grandchild.children.isEmpty)
    }

    func testOutOfOrderRecordsYieldIdenticalTree() {
        let recordA = makeRecord(spanId: "span_A", parentSpanId: nil, message: "1")
        let recordB = makeRecord(spanId: "span_B", parentSpanId: "span_A", message: "2")
        let recordC = makeRecord(spanId: "span_C", parentSpanId: "span_B", message: "3")

        let forestInOrder = buildTraceTree([recordA, recordB, recordC])
        let forestOutOfOrder = buildTraceTree([recordC, recordA, recordB])

        XCTAssertEqual(forestInOrder, forestOutOfOrder)
    }

    func testOrphanPromotedToRootWithZeroRecordsDropped() {
        let orphanRecord = makeRecord(spanId: "span_X", parentSpanId: "span_UNKNOWN", message: "Orphan")
        let rootRecord = makeRecord(spanId: "span_Y", parentSpanId: nil, message: "Root")

        let forest = buildTraceTree([orphanRecord, rootRecord])

        XCTAssertEqual(forest.count, 2)
        let totalCount = countNodes(forest)
        XCTAssertEqual(totalCount, 2)
    }

    func testParentWithMultipleChildrenSortedDeterministically() {
        let parent = makeRecord(spanId: "span_ROOT", parentSpanId: nil, message: "Root")
        let childB = makeRecord(spanId: "span_B", parentSpanId: "span_ROOT", message: "Child B")
        let childA = makeRecord(spanId: "span_A", parentSpanId: "span_ROOT", message: "Child A")

        let forest = buildTraceTree([parent, childB, childA])
        XCTAssertEqual(forest.count, 1)
        XCTAssertEqual(forest[0].children.count, 2)
        XCTAssertEqual(forest[0].children[0].record.spanId, "span_A")
        XCTAssertEqual(forest[0].children[1].record.spanId, "span_B")
    }

    func testEmptyInputYieldsEmptyForest() {
        let forest = buildTraceTree([])
        XCTAssertTrue(forest.isEmpty)
    }

    func testRecordsSharingSpanIdAreAllRetained() {
        let records = (1 ... 5).map { makeRecord(spanId: "span_SAME", parentSpanId: nil, message: "Message \($0)") }
        let forest = buildTraceTree(records)

        XCTAssertEqual(countNodes(forest), 5)
    }

    func testTwoRecordCycleTerminatesWithinTimeout() {
        let cycleRecordP = makeRecord(spanId: "span_P", parentSpanId: "span_Q", message: "P")
        let cycleRecordQ = makeRecord(spanId: "span_Q", parentSpanId: "span_P", message: "Q")

        let forest = buildTraceTree([cycleRecordP, cycleRecordQ])

        XCTAssertEqual(countNodes(forest), 2)
        for node in forest {
            XCTAssertFalse(containsDescendant(node: node, targetSpanId: node.record.spanId))
        }
    }

    func testSelfParentedRecordTreatedAsChildlessRoot() {
        let selfRecord = makeRecord(spanId: "span_S", parentSpanId: "span_S", message: "Self")
        let forest = buildTraceTree([selfRecord])

        XCTAssertEqual(forest.count, 1)
        XCTAssertTrue(forest[0].children.isEmpty)
    }

    func testTenThousandDeepChainCompletesWithoutStackOverflow() {
        var records: [LogRecord] = []
        records.reserveCapacity(10000)

        var previousSpan: String?
        for step in 0 ..< 10000 {
            let spanId = String(format: "span_%05d", step)
            records.append(makeRecord(spanId: spanId, parentSpanId: previousSpan, message: "Node \(step)"))
            previousSpan = spanId
        }

        let forest = buildTraceTree(records)
        XCTAssertEqual(countNodes(forest), 10000)
    }

    /// Helper functions
    private func countNodes(_ nodes: [TraceNode]) -> Int {
        var count = 0
        for node in nodes {
            count += 1 + countNodes(node.children)
        }
        return count
    }

    private func containsDescendant(node: TraceNode, targetSpanId: String) -> Bool {
        for child in node.children {
            if child.record.spanId == targetSpanId {
                return true
            }
            if containsDescendant(node: child, targetSpanId: targetSpanId) {
                return true
            }
        }
        return false
    }
}
