import Core

/// Reads the scanner data (Source Spec §4.3). A one-line pass-through to
/// `ScannerRepository.fetch()` today; the seam exists so policy has a home that
/// never leaks into the ViewModel.
@MainActor
public struct GetScannerDataUseCase {
    private let repository: ScannerRepository

    public init(repository: ScannerRepository) {
        self.repository = repository
    }

    public func execute() async -> DataState<ScannerEntity> {
        await repository.fetch()
    }

    public func callAsFunction() async -> DataState<ScannerEntity> {
        await execute()
    }
}
