import Core
import D3NexusLogging
import Foundation

/// Conforms to `Core.TraceContextProviding` by generating W3C `traceparent` headers
/// (`00-{traceId}-{spanId}-01`) from `D3NexusLogging.LoggerProtocol` spans.
///
/// Each invocation of `traceparentHeader()` creates a lightweight child span using `withSpan()`,
/// ensuring unique span IDs per network request while preserving distributed trace continuity.
public final class D3NexusTraceContextProvider: TraceContextProviding, @unchecked Sendable {
    private let logger: any LoggerProtocol

    public init(logger: any LoggerProtocol = D3NexusLogger.getLogger("Network")) {
        self.logger = logger
    }

    public func traceparentHeader() -> String? {
        let child = logger.withSpan()
        return "00-\(child.traceId)-\(child.spanId)-01"
    }
}
