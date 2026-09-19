import Core
import Foundation

/// Injects the W3C `traceparent` header into outgoing network requests via the `Core.TraceContextProviding` seam.
///
/// Complies with W3C Trace Context recommendations without coupling `Packages/Network` to any concrete logging
/// framework.
public final class TraceContextInterceptor: RequestInterceptor, @unchecked Sendable {
    private let provider: any TraceContextProviding
    private let logger: (any Logger)?

    public init(provider: any TraceContextProviding, logger: (any Logger)? = nil) {
        self.provider = provider
        self.logger = logger
    }

    public func adapt(_ request: URLRequest) async -> URLRequest {
        if request.value(forHTTPHeaderField: "traceparent") != nil {
            return request
        }

        guard let traceparent = provider.traceparentHeader() else {
            return request
        }

        var modified = request
        modified.setValue(traceparent, forHTTPHeaderField: "traceparent")
        return modified
    }

    public func didReceive(_ response: HTTPURLResponse) {
        let status = response.statusCode
        if status >= 400 {
            logger?.error("[TraceContext] ← \(status)", file: #file, function: #function, line: #line)
        }
    }
}
