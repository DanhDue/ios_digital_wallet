import Core
import Foundation

/// An empty success payload. Use as `T` for `204 No Content` (or any endpoint
/// with no body).
public struct EmptyResponse: Decodable, Equatable, Sendable {
    public init() {}
}

/// The seam every Feature depends on. Features test against `MockAPIClient`; the
/// app wires `URLSessionAPIClient`.
public protocol APIClient: Sendable {
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
}

/// `URLSession`-backed `APIClient`. Runs interceptors in registration order,
/// maps transport / status failures to `NetworkError`, and — on a first-attempt
/// `401` an interceptor elects to resend — retries the request **exactly once**
/// before decoding or throwing. The `401` → `AuthEventSink` notification now
/// lives in `AuthTokenInterceptor.retry` / `RefreshingAuthInterceptor`, not
/// here.
///
/// `@unchecked Sendable`: `Logger` / `Environment` are injected values the
/// composition root guarantees are thread-safe; all other stored values are
/// `Sendable`.
public final class URLSessionAPIClient: APIClient, @unchecked Sendable {
    /// Total `perform` calls a single `send` may make: the original plus at most
    /// one interceptor-driven resend.
    private static let maxAttempts = 2

    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    private let environment: Environment
    private let logger: Logger
    // 401 notification moved to AuthTokenInterceptor.retry / RefreshingAuthInterceptor
    // (Task 3/4); param removed in Task 6 wiring
    private let authEventSink: AuthEventSink?
    private let decoder: JSONDecoder

    public init(
        session: URLSession = .shared,
        interceptors: [RequestInterceptor] = [],
        environment: Environment,
        logger: Logger,
        authEventSink: AuthEventSink? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.interceptors = interceptors
        self.environment = environment
        self.logger = logger
        self.authEventSink = authEventSink
        self.decoder = decoder
    }

    public func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        var urlRequest = try request.urlRequest(for: environment)
        for interceptor in interceptors {
            urlRequest = await interceptor.adapt(urlRequest)
        }

        let (data, http) = try await performWithBoundedRetry(urlRequest)

        let payload = data.isEmpty ? Data("{}".utf8) : data
        do {
            return try decoder.decode(T.self, from: payload)
        } catch {
            logError("decoding \(T.self) failed: \(error)", url: http.url, body: data)
            throw NetworkError.decoding(error)
        }
    }

    /// Send `initial`, and — only on a first-attempt `401` that an interceptor
    /// elects to resend — send once more. Returns the `(body, response)` of the
    /// attempt whose `validate` passed; otherwise rethrows the mapped
    /// `NetworkError` from the final `validate`. `didReceive` fires for every
    /// physical response; `Task.checkCancellation()` bounds each attempt.
    private func performWithBoundedRetry(_ initial: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var currentRequest = initial

        for attempt in 1 ... Self.maxAttempts {
            try Task.checkCancellation()
            let (data, response) = try await perform(currentRequest)
            try Task.checkCancellation()

            guard let http = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            for interceptor in interceptors {
                interceptor.didReceive(http)
            }

            do {
                try validate(http, body: data)
                return (data, http)
            } catch let validationError {
                guard
                    attempt < Self.maxAttempts,
                    http.statusCode == HTTPStatusCode.unauthorized.rawValue,
                    let resent = await firstResend(of: currentRequest, dueTo: .unauthorized(http))
                else {
                    throw validationError
                }
                currentRequest = resent
            }
        }

        // Unreachable: every iteration either returns on success or throws.
        throw NetworkError.invalidResponse
    }

    /// Ask each interceptor, in registration order, whether to resend; the first
    /// `.retry(newRequest)` wins and later interceptors are not asked.
    private func firstResend(of request: URLRequest, dueTo reason: RetryReason) async -> URLRequest? {
        for interceptor in interceptors {
            if case let .retry(newRequest) = await interceptor.retry(request, dueTo: reason) {
                return newRequest
            }
        }
        return nil
    }

    /// Run the transport, translating `URLError` into `NetworkError` /
    /// `CancellationError`.
    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError {
            switch urlError.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw NetworkError.timeout
            default: throw NetworkError.transport(urlError)
            }
        }
    }

    /// Throw the right `NetworkError` for a non-2xx response. The `401`
    /// notification is no longer raised here — it moved to
    /// `AuthTokenInterceptor.retry` / `RefreshingAuthInterceptor` (Task 3/4),
    /// the one place that knows why the `401` is terminal.
    private func validate(_ http: HTTPURLResponse, body: Data) throws {
        let status = http.statusCode
        if HTTPStatusCode.isSuccess(status) {
            return
        }
        if status == HTTPStatusCode.unauthorized.rawValue {
            logError("401 Unauthorized", url: http.url, body: body)
            throw NetworkError.unauthorized
        }
        logError("HTTP \(status)", url: http.url, body: body)
        if HTTPStatusCode.isClientError(status) {
            throw NetworkError.client(status)
        }
        if HTTPStatusCode.isServerError(status) {
            throw NetworkError.server(status)
        }
        throw NetworkError.invalidResponse
    }

    private func logError(_ summary: String, url: URL?, body: Data) {
        let location = url?.absoluteString ?? "<no url>"
        logger.error(
            "[Network] \(summary) for \(location) — body: \(Self.snippet(body))",
            file: #file,
            function: #function,
            line: #line
        )
    }

    private static func snippet(_ data: Data, limit: Int = 512) -> String {
        guard !data.isEmpty else { return "<empty>" }
        let text = String(bytes: data.prefix(limit), encoding: .utf8) ?? "<\(data.count) bytes>"
        return data.count > limit ? "\(text)…" : text
    }
}
