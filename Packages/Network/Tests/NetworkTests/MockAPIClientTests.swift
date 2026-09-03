import Foundation
import XCTest
@testable import Network

/// `MockAPIClient` — FIFO queue, `artificialDelay`, exhaustion.
final class MockAPIClientTests: XCTestCase {
    private let anyRequest = APIRequest(method: .get, path: "/x")

    func testServesQueuedResultsInFIFOOrderThenThrowsNoMoreResponses() async throws {
        let client = MockAPIClient()
        client.enqueueError(URLError(.badServerResponse))
        client.enqueueSuccess(Widget(id: 1, name: "first"))
        client.enqueueSuccess(Widget(id: 2, name: "second"))

        await assertThrowsAsync {
            _ = try await client.send(self.anyRequest) as Widget
        } onError: { error in
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
        let first: Widget = try await client.send(anyRequest)
        let second: Widget = try await client.send(anyRequest)
        XCTAssertEqual([first, second], [Widget(id: 1, name: "first"), Widget(id: 2, name: "second")])

        await assertThrowsAsync {
            _ = try await client.send(self.anyRequest) as Widget
        } onError: { error in
            XCTAssertEqual(error as? MockAPIClientError, .noMoreResponses)
            XCTAssertEqual((error as? MockAPIClientError)?.errorDescription, "MockAPIClient: no more responses")
        }
    }

    func testExhaustionFromEmptyQueueThrowsImmediately() async {
        let client = MockAPIClient()
        await assertThrowsAsync {
            _ = try await client.send(self.anyRequest) as Widget
        } onError: { error in
            XCTAssertEqual(error as? MockAPIClientError, .noMoreResponses)
        }
    }

    func testTypeMismatchBetweenQueuedValueAndRequestedTypeThrows() async {
        let client = MockAPIClient()
        client.enqueueSuccess(Widget(id: 1, name: "a"))
        await assertThrowsAsync {
            _ = try await client.send(self.anyRequest) as RequiredFieldModel
        } onError: { error in
            guard case .typeMismatch = (error as? MockAPIClientError) else {
                return XCTFail("expected .typeMismatch, got \(error)")
            }
        }
    }

    func testArtificialDelayIsRespected() async throws {
        let client = MockAPIClient()
        client.artificialDelay = .milliseconds(120)
        client.enqueueSuccess(Widget(id: 1, name: "a"))

        let start = ContinuousClock.now
        _ = try await client.send(anyRequest) as Widget
        let elapsed = ContinuousClock.now - start

        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(110), "artificialDelay should gate the response")
    }

    func testZeroDelayReturnsWithoutMeaningfulWait() async throws {
        let client = MockAPIClient()
        client.enqueueSuccess(Widget(id: 1, name: "a"))

        let start = ContinuousClock.now
        _ = try await client.send(anyRequest) as Widget
        let elapsed = ContinuousClock.now - start

        XCTAssertLessThan(elapsed, .milliseconds(100))
    }

    func testConformsToAPIClientSoItIsUsableFromOtherPackages() {
        let client: APIClient = MockAPIClient()
        XCTAssertNotNil(client)
    }
}
