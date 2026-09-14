import Foundation
import XCTest
@testable import Plugin

private struct TestError: Error, LocalizedError, Equatable {
    let message: String
    var errorDescription: String? {
        message
    }
}

private final class StubRepository: PluginRepository, @unchecked Sendable {
    var stubbedData: PluginData = .init(id: "stub-id", title: "Stubbed Title")
    var shouldThrow: Error?
    var delayNanoseconds: UInt64 = 0

    func getData() async throws -> PluginData {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let shouldThrow {
            throw shouldThrow
        }
        return stubbedData
    }

    func syncData() async throws {
        if let shouldThrow {
            throw shouldThrow
        }
    }
}

@MainActor
final class MyPluginViewModelTests: XCTestCase {
    func testUseCaseMapsDomainDataSuccessfully() async throws {
        let repo = StubRepository()
        let expected = PluginData(id: "test-id", title: "Test Domain")
        repo.stubbedData = expected
        let useCase = GetDataUseCase(repository: repo)

        let result = try await useCase.execute()
        XCTAssertEqual(result, expected)
    }

    func testUseCasePropagatesError() async {
        let repo = StubRepository()
        repo.shouldThrow = TestError(message: "Repo failed")
        let useCase = GetDataUseCase(repository: repo)

        do {
            _ = try await useCase.execute()
            XCTFail("Expected error to be thrown")
        } catch let error as TestError {
            XCTAssertEqual(error.message, "Repo failed")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testViewModelReducesActionsIntoState() async {
        let repo = StubRepository()
        let expected = PluginData(id: "mvi-id", title: "MVI Data")
        repo.stubbedData = expected
        let useCase = GetDataUseCase(repository: repo)
        let viewModel = MyPluginViewModel(getDataUseCase: useCase)

        XCTAssertEqual(viewModel.state, .idle)

        viewModel.dispatch(action: .load)
        XCTAssertEqual(viewModel.state, .loading)

        // Allow async task to settle
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.state, .loaded(expected))
    }

    func testViewModelHandlesErrorState() async {
        let repo = StubRepository()
        repo.shouldThrow = TestError(message: "Network broken")
        let useCase = GetDataUseCase(repository: repo)
        let viewModel = MyPluginViewModel(getDataUseCase: useCase)

        viewModel.dispatch(action: .load)

        try? await Task.sleep(nanoseconds: 50_000_000)

        if case let .error(msg) = viewModel.state {
            XCTAssertEqual(msg, "Network broken")
        } else {
            XCTFail("Expected error state, got \(viewModel.state)")
        }
    }

    func testRapidRepeatActionsDoNotRace() async {
        let repo = StubRepository()
        repo.delayNanoseconds = 100_000_000 // 100ms
        let useCase = GetDataUseCase(repository: repo)
        let viewModel = MyPluginViewModel(getDataUseCase: useCase)

        viewModel.dispatch(action: .load)
        // Immediately dispatch second action before first completes
        viewModel.dispatch(action: .load)

        try? await Task.sleep(nanoseconds: 180_000_000)

        if case .loaded = viewModel.state {
            // Succeeded with single final state
        } else {
            XCTFail("Expected loaded state after repeat dispatch, got \(viewModel.state)")
        }
    }

    func testDomainIsFreeOfFrameworkImports() throws {
        let fileManager = FileManager.default
        let currentFile = URL(fileURLWithPath: #filePath)
        let packageRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let domainURL = packageRoot.appendingPathComponent("Sources/Plugin/Domain")
        let path = domainURL.path

        let enumerator = fileManager.enumerator(atPath: path)
        var checkedFileCount = 0

        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") {
                let fullPath = "\(path)/\(file)"
                let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                XCTAssertFalse(content.contains("import SwiftUI"), "\(file) imports SwiftUI")
                XCTAssertFalse(content.contains("import UIKit"), "\(file) imports UIKit")
                XCTAssertFalse(content.contains("import Combine"), "\(file) imports Combine")
                XCTAssertFalse(content.contains("import Flutter"), "\(file) imports Flutter")
                checkedFileCount += 1
            }
        }

        XCTAssertGreaterThan(checkedFileCount, 0, "Should have checked at least one domain file")
    }
}
