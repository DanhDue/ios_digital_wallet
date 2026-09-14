import Foundation
import XCTest
@testable import Plugin

private struct HostApiTestError: Error, LocalizedError {
    let message: String
    var errorDescription: String? {
        message
    }
}

private final class StubHostRepository: PluginRepository, @unchecked Sendable {
    var stubbedData = PluginData(id: "host-id", title: "Host Title")
    var shouldThrow: Error?

    func getData() async throws -> PluginData {
        if let shouldThrow {
            throw shouldThrow
        }
        return stubbedData
    }

    func syncData() async throws {}
}

final class MyPluginHostApiImplTests: XCTestCase {
    func testHostApiDelegatesToDomainLayerSuccessfully() {
        let repo = StubHostRepository()
        let expected = PluginData(id: "pigeon-123", title: "Pigeon Title")
        repo.stubbedData = expected
        let useCase = GetDataUseCase(repository: repo)
        let hostApi = MyPluginHostApiImpl(getDataUseCase: useCase)

        let expectation = expectation(description: "Host API callback")

        hostApi.getData { result in
            switch result {
            case let .success(message):
                XCTAssertEqual(message.id, expected.id)
                XCTAssertEqual(message.title, expected.title)
            case let .failure(error):
                XCTFail("Expected success, got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testHostApiSurfacesErrorsCleanly() {
        let repo = StubHostRepository()
        repo.shouldThrow = HostApiTestError(message: "Host failure")
        let useCase = GetDataUseCase(repository: repo)
        let hostApi = MyPluginHostApiImpl(getDataUseCase: useCase)

        let expectation = expectation(description: "Host API error callback")

        hostApi.getData { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case let .failure(error):
                XCTAssertEqual((error as? HostApiTestError)?.message, "Host failure")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
