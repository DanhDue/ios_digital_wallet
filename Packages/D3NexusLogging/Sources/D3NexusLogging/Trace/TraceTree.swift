import Foundation

/// Re-constructs hierarchical causal execution flows from a flat array of log records.
public func buildTraceTree(_ records: [LogRecord]) -> [TraceNode] {
    guard !records.isEmpty else { return [] }

    let firstIndexBySpanId = buildFirstIndexBySpanId(records)
    let parentMap = buildParentMap(records, firstIndexBySpanId: firstIndexBySpanId)
    let validParentMap = pruneCycles(recordsCount: records.count, parentMap: parentMap)
    let (childrenIndices, rootIndices) = groupChildrenAndRoots(
        recordsCount: records.count,
        validParentMap: validParentMap
    )
    let depths = computeDepths(
        recordsCount: records.count,
        rootIndices: rootIndices,
        childrenIndices: childrenIndices
    )

    let builtNodes = buildNodesBottomUp(
        records: records,
        depths: depths,
        childrenIndices: childrenIndices
    )

    return sortRoots(rootIndices: rootIndices, records: records, builtNodes: builtNodes)
}

// MARK: - Private Helpers

private func buildFirstIndexBySpanId(_ records: [LogRecord]) -> [String: Int] {
    var mapping = [String: Int]()
    for (index, record) in records.enumerated() where mapping[record.spanId] == nil {
        mapping[record.spanId] = index
    }
    return mapping
}

private func buildParentMap(
    _ records: [LogRecord],
    firstIndexBySpanId: [String: Int]
) -> [Int: Int] {
    var parentMap = [Int: Int]()
    for (index, record) in records.enumerated() {
        guard let parentSpanId = record.parentSpanId,
              let parentIndex = firstIndexBySpanId[parentSpanId],
              parentIndex != index
        else {
            continue
        }
        parentMap[index] = parentIndex
    }
    return parentMap
}

private func pruneCycles(recordsCount: Int, parentMap: [Int: Int]) -> [Int: Int] {
    var validParentMap = [Int: Int]()
    for index in 0 ..< recordsCount {
        var current: Int? = parentMap[index]
        var visited = Set<Int>([index])
        var hasCycle = false

        while let parentIndex = current {
            if visited.contains(parentIndex) {
                hasCycle = true
                break
            }
            visited.insert(parentIndex)
            current = parentMap[parentIndex]
        }

        if !hasCycle, let parentIndex = parentMap[index] {
            validParentMap[index] = parentIndex
        }
    }
    return validParentMap
}

private func groupChildrenAndRoots(
    recordsCount: Int,
    validParentMap: [Int: Int]
) -> (childrenIndices: [Int: [Int]], rootIndices: [Int]) {
    var childrenIndices = [Int: [Int]]()
    var rootIndices = [Int]()

    for index in 0 ..< recordsCount {
        if let parent = validParentMap[index] {
            childrenIndices[parent, default: []].append(index)
        } else {
            rootIndices.append(index)
        }
    }
    return (childrenIndices, rootIndices)
}

private func computeDepths(
    recordsCount: Int,
    rootIndices: [Int],
    childrenIndices: [Int: [Int]]
) -> [Int] {
    var depths = Array(repeating: 0, count: recordsCount)
    var queue = rootIndices
    var head = 0
    while head < queue.count {
        let parent = queue[head]
        head += 1
        let nextDepth = depths[parent] + 1
        if let children = childrenIndices[parent] {
            for child in children {
                depths[child] = nextDepth
                queue.append(child)
            }
        }
    }
    return depths
}

private func buildNodesBottomUp(
    records: [LogRecord],
    depths: [Int],
    childrenIndices: [Int: [Int]]
) -> [Int: TraceNode] {
    let sortedByDepthDesc = (0 ..< records.count).sorted { depths[$0] > depths[$1] }
    var builtNodes = [Int: TraceNode]()
    builtNodes.reserveCapacity(records.count)

    for index in sortedByDepthDesc {
        let childIndices = childrenIndices[index] ?? []
        let sortedChildrenIndices = childIndices.sorted { firstIndex, secondIndex in
            isOrderedBefore(records[firstIndex], records[secondIndex])
        }
        let children = sortedChildrenIndices.compactMap { builtNodes[$0] }
        builtNodes[index] = TraceNode(record: records[index], children: children)
    }
    return builtNodes
}

private func sortRoots(
    rootIndices: [Int],
    records: [LogRecord],
    builtNodes: [Int: TraceNode]
) -> [TraceNode] {
    let sortedRoots = rootIndices.sorted { firstIndex, secondIndex in
        isOrderedBefore(records[firstIndex], records[secondIndex])
    }
    return sortedRoots.compactMap { builtNodes[$0] }
}

private func isOrderedBefore(_ firstRecord: LogRecord, _ secondRecord: LogRecord) -> Bool {
    if firstRecord.spanId != secondRecord.spanId {
        return firstRecord.spanId < secondRecord.spanId
    }
    if firstRecord.timestamp != secondRecord.timestamp {
        return firstRecord.timestamp < secondRecord.timestamp
    }
    return firstRecord.message < secondRecord.message
}
