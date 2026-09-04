import Combine
import Core
import XCTest
@testable import Scanner

@MainActor
final class ScannerViewModelTests: XCTestCase {
    func testInitialViewStateIsLoading() {
        let sut = ScannerViewModel(repository: SpyScannerRepository())

        XCTAssertEqual(sut.viewState.tag, "loading")
        XCTAssertEqual(sut.uiState.entity, .stub)
    }

    func testDispatchOnAppearDoesNotCrashAndDoesNotSynchronouslyLeaveLoading() {
        let sut = ScannerViewModel(repository: SpyScannerRepository())

        sut.dispatch(.onAppear)

        // The effect is async; right after dispatch the screen is still loading.
        XCTAssertEqual(sut.viewState.tag, "loading")
    }

    func testOnAppearLoadsTheStubAndTransitionsToContent() async {
        let repo = SpyScannerRepository()
        let sut = ScannerViewModel(repository: repo)
        let events = Recorder(sut.eventSubject)

        sut.dispatch(.onAppear)
        await poll { sut.viewState.tag == "content" }

        XCTAssertEqual(sut.viewState.tag, "content")
        XCTAssertEqual(sut.uiState.entity, .stub)
        XCTAssertEqual(repo.fetchCallCount, 1)
        XCTAssertEqual(events.values, [.dataLoaded])
    }

    func testOnClearCancelsInFlightEffectAndClearsBookkeeping() async {
        let sut = ScannerViewModel(repository: SpyScannerRepository())

        sut.dispatch(.onAppear)
        sut.onClear()
        await poll { sut.effectTasks.isEmpty }

        XCTAssertTrue(sut.effectTasks.isEmpty)
    }

    func testRepositoryErrorSurfacesAsErrorViewState() async {
        let repo = SpyScannerRepository()
        repo.fetchResult = .error(AppError(code: "boom", message: "boom"))
        let sut = ScannerViewModel(repository: repo)

        sut.dispatch(.onAppear)
        await poll { sut.viewState.tag == "error" }

        XCTAssertEqual(sut.viewState.tag, "error")
    }
}
