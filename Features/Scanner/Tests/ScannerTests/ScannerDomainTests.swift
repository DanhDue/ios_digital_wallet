import Core
import XCTest
@testable import Scanner

@MainActor
final class ScannerDomainTests: XCTestCase {
    func testRepositoryImplReturnsTheFixedStub() async {
        let repository = ScannerRepositoryImpl()

        let result = await repository.fetch()

        guard case let .success(entity) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(entity, .stub)
        XCTAssertFalse(entity.isAvailable)
    }

    func testUseCasePassesRepositoryResultThrough() async {
        let repo = SpyScannerRepository()
        let useCase = GetScannerDataUseCase(repository: repo)

        _ = await useCase.execute()
        _ = await useCase()

        XCTAssertEqual(repo.fetchCallCount, 2)
    }
}
