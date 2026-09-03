import Core
import Foundation

/// Logs the outgoing request URL at `info` and any `4xx` / `5xx` response at
/// `error`, via the injected `Core.Logger`. `@unchecked Sendable`: the only
/// stored value is a `Logger`, which the composition root is required to make
/// thread-safe.
public final class LoggingInterceptor: RequestInterceptor, @unchecked Sendable {
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func adapt(_ request: URLRequest) async -> URLRequest {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "<no url>"
        logger.info("[Network] → \(method) \(url)", file: #file, function: #function, line: #line)
        return request
    }

    public func didReceive(_ response: HTTPURLResponse) {
        let url = response.url?.absoluteString ?? "<no url>"
        let status = response.statusCode
        if status >= 400 {
            logger.error("[Network] ← \(status) \(url)", file: #file, function: #function, line: #line)
        } else {
            logger.info("[Network] ← \(status) \(url)", file: #file, function: #function, line: #line)
        }
    }
}
