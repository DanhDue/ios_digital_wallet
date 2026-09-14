import FactoryKit
import Foundation
import XCTest
@testable import Plugin

private final class MockPluginRepository: PluginRepository, @unchecked Sendable {
    func getData() async throws -> PluginData {
        PluginData(id: "mock-id", title: "Mock Data")
    }

    func syncData() async throws {}
}

private final class SecondaryContainer: SharedContainer, @unchecked Sendable {
    static let shared = SecondaryContainer()
    let manager = ContainerManager()

    var repository: Factory<PluginRepository> {
        self { MockPluginRepository() }
    }
}

final class PluginContainerTests: XCTestCase {
    override func tearDown() {
        PluginContainer.shared.manager.reset()
        super.tearDown()
    }

    func testContainerResolvesDefaultImplementation() {
        let repo = PluginContainer.shared.repository()
        XCTAssertTrue(repo is PluginRepositoryImpl)
    }

    func testContainerCanBeOverriddenAndReset() {
        PluginContainer.shared.repository.register {
            MockPluginRepository()
        }

        let overridden = PluginContainer.shared.repository()
        XCTAssertTrue(overridden is MockPluginRepository)

        PluginContainer.shared.manager.reset()

        let restored = PluginContainer.shared.repository()
        XCTAssertTrue(restored is PluginRepositoryImpl)
    }

    func testTwoContainersDoNotCollide() {
        let primary = PluginContainer.shared.repository()
        let secondary = SecondaryContainer.shared.repository()

        XCTAssertTrue(primary is PluginRepositoryImpl)
        XCTAssertTrue(secondary is MockPluginRepository)
    }
}
