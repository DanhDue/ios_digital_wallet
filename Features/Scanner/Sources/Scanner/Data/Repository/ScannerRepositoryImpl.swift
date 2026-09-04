import Core

/// The one `ScannerRepository` conformer (Source Spec §4.3). `internal`, a
/// `struct`, reached only through the Domain protocol (ArchTests K4 / K5).
///
/// The Scanner feature ships as a stub: `fetch()` returns the fixed
/// `ScannerEntity.stub` and performs no I/O — there is deliberately no `Network`
/// dependency (Source Spec Changelog — "Scanner has no network").
struct ScannerRepositoryImpl: ScannerRepository {
    func fetch() async -> DataState<ScannerEntity> {
        .success(.stub)
    }
}
