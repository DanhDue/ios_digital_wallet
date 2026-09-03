import Foundation
import XCTest

/// What the stub should do for a given request.
enum StubOutcome: Sendable {
    /// Deliver an HTTP response with this status / headers / body.
    case response(status: Int, headers: [String: String] = [:], body: Data = Data())
    /// Fail the load with this error (e.g. `URLError(.timedOut)`).
    case failure(any Error)
}

/// Process-wide, lock-guarded storage for `URLProtocolStub`. One `install()` per
/// test, `remove()` in `tearDown`.
final class StubStore: @unchecked Sendable {
    static let shared = StubStore()

    private let lock = NSLock()
    private var handler: (@Sendable (URLRequest) -> StubOutcome)?
    private var delayValue: Duration = .zero
    private var recorded: [URLRequest] = []
    private var startCountValue = 0

    /// Requests that reached `startLoading`, in order.
    var recordedRequests: [URLRequest] {
        lock.withLock { recorded }
    }

    /// How many loads have begun (used to await "the request is in flight").
    var startCount: Int {
        lock.withLock { startCountValue }
    }

    /// Artificial delay applied inside `startLoading` before the outcome is
    /// delivered; the loop polls for cancellation while it waits.
    var delay: Duration {
        get { lock.withLock { delayValue } }
        set { lock.withLock { delayValue = newValue } }
    }

    func setHandler(_ handler: @escaping @Sendable (URLRequest) -> StubOutcome) {
        lock.withLock { self.handler = handler }
    }

    func reset() {
        lock.withLock {
            handler = nil
            delayValue = .zero
            recorded = []
            startCountValue = 0
        }
    }

    fileprivate func outcome(for request: URLRequest) -> StubOutcome? {
        lock.withLock {
            recorded.append(request)
            startCountValue += 1
            return handler?(request)
        }
    }

    /// A `URLSession` whose only protocol is the stub.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }
}

/// `URLProtocol` that answers from `StubStore.shared`. No real network.
///
/// `startLoading` never blocks its thread: any `StubStore.delay` is honoured by
/// scheduling delivery on a concurrent queue, so many stubbed requests can be
/// "in flight" at once (and a cancelled one frees up immediately).
class URLProtocolStub: URLProtocol {
    private static let workQueue = DispatchQueue(label: "URLProtocolStub.work", attributes: .concurrent)

    private let cancelLock = NSLock()
    private var cancelled = false

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        guard let outcome = StubStore.shared.outcome(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let delay = StubStore.shared.delay.seconds
        Self.workQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.isCancelled else { return }
            deliver(outcome, url: url)
        }
    }

    override func stopLoading() {
        cancelLock.withLock { cancelled = true }
    }

    private var isCancelled: Bool {
        cancelLock.withLock { cancelled }
    }

    private func deliver(_ outcome: StubOutcome, url: URL) {
        switch outcome {
        case let .response(status, headers, body):
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

extension Duration {
    /// Whole + fractional seconds as a `TimeInterval`.
    var seconds: TimeInterval {
        let (secs, attos) = components
        return TimeInterval(secs) + TimeInterval(attos) / 1_000_000_000_000_000_000
    }
}
