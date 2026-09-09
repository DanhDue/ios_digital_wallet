import Factory
import Platform

public extension Container {
    var scannerRepository: Factory<any ScannerRepository> {
        self {
            MainActor.assumeIsolated {
                ScannerRepositoryImpl()
            }
        }
    }

    var getScannerDataUseCase: Factory<GetScannerDataUseCase> {
        self {
            MainActor.assumeIsolated {
                GetScannerDataUseCase(repository: self.scannerRepository())
            }
        }
    }
}
