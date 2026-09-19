import D3NexusLogging
import Foundation
import Pulse

/// Builds instrumented `URLSession` instances with automatic Pulse telemetry and security-tier redaction.
///
/// Ensures all captured headers and request/response payloads pass through `Redactor`
/// before persisting to `Pulse.LoggerStore`.
public enum PulseSessionFactory {
    public static let sensitiveHeaderNames: Set<String> = [
        "authorization", "cookie", "set-cookie", "x-auth-token", "x-refresh-token",
    ]

    /// Creates a `NetworkLogger.Configuration` hooked with pre-storage sanitization.
    public static func makeConfiguration(
        redactor: Redactor = Redactor()
    ) -> NetworkLogger.Configuration {
        var config = NetworkLogger.Configuration()
        config.sensitiveHeaders = [
            "authorization", "Authorization",
            "cookie", "Cookie",
            "set-cookie", "Set-Cookie",
            "x-auth-token", "X-Auth-Token",
            "x-refresh-token", "X-Refresh-Token",
        ]
        config.willHandleEvent = { event in
            sanitize(event: event, redactor: redactor)
        }
        return config
    }

    /// Sanitizes network events by redacting sensitive headers and masking PII in payload bodies.
    public static func sanitize(event: LoggerStore.Event, redactor: Redactor) -> LoggerStore.Event {
        switch event {
        case var .networkTaskCreated(created):
            created.originalRequest = sanitize(request: created.originalRequest)
            if let current = created.currentRequest {
                created.currentRequest = sanitize(request: current)
            }
            return .networkTaskCreated(created)

        case var .networkTaskCompleted(completed):
            completed.originalRequest = sanitize(request: completed.originalRequest)
            if let current = completed.currentRequest {
                completed.currentRequest = sanitize(request: current)
            }
            if let response = completed.response {
                completed.response = sanitize(response: response)
            }
            if let reqBody = completed.requestBody, let str = String(data: reqBody, encoding: .utf8) {
                let redacted = redactor.redact(str)
                completed.requestBody = redacted.data(using: .utf8)
            }
            if let respBody = completed.responseBody, let str = String(data: respBody, encoding: .utf8) {
                let redacted = redactor.redact(str)
                completed.responseBody = redacted.data(using: .utf8)
            }
            return .networkTaskCompleted(completed)

        default:
            return event
        }
    }

    private static func sanitize(request: NetworkLogger.Request) -> NetworkLogger.Request {
        var sanitized = request
        if let headers = sanitized.headers {
            var updated: [String: String] = [:]
            for (headerKey, headerValue) in headers {
                if sensitiveHeaderNames.contains(headerKey.lowercased()) {
                    updated[headerKey] = "[REDACTED]"
                } else {
                    updated[headerKey] = headerValue
                }
            }
            sanitized.headers = updated
        }
        return sanitized
    }

    private static func sanitize(response: NetworkLogger.Response) -> NetworkLogger.Response {
        var sanitized = response
        if let headers = sanitized.headers {
            var updated: [String: String] = [:]
            for (headerKey, headerValue) in headers {
                if sensitiveHeaderNames.contains(headerKey.lowercased()) {
                    updated[headerKey] = "[REDACTED]"
                } else {
                    updated[headerKey] = headerValue
                }
            }
            sanitized.headers = updated
        }
        return sanitized
    }

    /// Factory method building an instrumented `URLSession` reporting to Pulse.
    public static func makeURLSession(
        configuration: URLSessionConfiguration = .default,
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil,
        store: LoggerStore = .shared,
        redactor: Redactor = Redactor()
    ) -> URLSession {
        store.configuration.willHandleEvent = { event in
            sanitize(event: event, redactor: redactor)
        }

        let existing = (configuration.protocolClasses ?? []).filter { $0 != PulseTrackingURLProtocol.self }
        PulseTrackingURLProtocol.configure(store: store, downstream: existing)

        let sessionConfig = configuration.copy() as? URLSessionConfiguration ?? configuration
        sessionConfig.protocolClasses = [PulseTrackingURLProtocol.self] + existing

        return URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: delegateQueue)
    }

    /// Generates a reproducible cURL command string from a captured `NetworkTaskEntity`.
    public static func cURLDescription(for task: NetworkTaskEntity) -> String {
        guard let request = task.currentRequest ?? task.originalRequest,
              let urlString = request.url
        else {
            return "curl command generation failed"
        }

        var components = ["curl -v"]
        components.append("-X \(request.httpMethod ?? "GET")")

        for (key, value) in request.headers.sorted(by: { $0.key < $1.key }) {
            let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
            components.append("-H '\(key): \(escaped)'")
        }

        if let bodyData = task.requestBody?.data, let body = String(data: bodyData, encoding: .utf8) {
            let escaped = body.replacingOccurrences(of: "'", with: "'\\''")
            components.append("-d '\(escaped)'")
        }

        components.append("'\(urlString)'")
        return components.joined(separator: " ")
    }

    /// Generates a cURL command string directly from a `URLRequest`.
    public static func cURLDescription(for request: URLRequest) -> String {
        var components = ["curl -v"]
        if let method = request.httpMethod, method != "GET" {
            components.append("-X \(method)")
        }
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
                components.append("-H '\(key): \(escaped)'")
            }
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let escaped = bodyString.replacingOccurrences(of: "'", with: "'\\''")
            components.append("-d '\(escaped)'")
        }
        if let url = request.url?.absoluteString {
            components.append("'\(url)'")
        }
        return components.joined(separator: " ")
    }
}

final class PulseTrackingURLProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "PulseTrackingURLProtocolHandled"
    private static let lock = NSLock()
    private static var activeStore: LoggerStore?
    private static var downstreamProtocols: [AnyClass] = []

    static func configure(store: LoggerStore, downstream: [AnyClass] = []) {
        lock.withLock {
            activeStore = store
            downstreamProtocols = downstream
        }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        return true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    private var internalDataTask: URLSessionDataTask?

    override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        let forwardRequest = mutableRequest as URLRequest

        let downstream = Self.lock.withLock { Self.downstreamProtocols }
        let downstreamConfig = URLSessionConfiguration.ephemeral
        downstreamConfig.protocolClasses = downstream.isEmpty ? nil : downstream
        let downstreamSession = URLSession(configuration: downstreamConfig)

        internalDataTask = downstreamSession.dataTask(with: forwardRequest) { [weak self] data, response, error in
            guard let self else { return }

            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            if let error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }

            let store = Self.lock.withLock { Self.activeStore }
            store?.storeRequest(
                forwardRequest,
                response: response,
                error: error,
                data: data
            )
        }
        internalDataTask?.resume()
    }

    override func stopLoading() {
        internalDataTask?.cancel()
    }
}
