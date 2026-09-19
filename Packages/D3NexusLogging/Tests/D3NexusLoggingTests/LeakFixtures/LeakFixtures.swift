import Foundation

final class CyclicLoggerChild: @unchecked Sendable {
    var parent: CyclicLoggerParent?

    init(parent: CyclicLoggerParent? = nil) {
        self.parent = parent
    }
}

final class CyclicLoggerParent: @unchecked Sendable {
    var child: CyclicLoggerChild?

    init() {
        let child = CyclicLoggerChild(parent: self)
        self.child = child
    }
}

final class RetainingAppender: @unchecked Sendable {
    var retainCycleOwner: AnyObject?
}

final class ClassBasedTraceNode: @unchecked Sendable {
    var spanId: String
    var parentSpanId: String?
    var children: [ClassBasedTraceNode] = []

    init(spanId: String, parentSpanId: String? = nil) {
        self.spanId = spanId
        self.parentSpanId = parentSpanId
    }
}
