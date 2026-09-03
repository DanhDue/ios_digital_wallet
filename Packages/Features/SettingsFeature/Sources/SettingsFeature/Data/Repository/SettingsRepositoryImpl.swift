import Core

/// The one `SettingsRepository` conformer (Source Spec §4.4). `internal`, a
/// `struct`, reached only through the Domain protocol (ArchTests K4 / K5).
///
/// `load()` never surfaces `.error`: a missing or corrupt cache degrades to
/// `SettingsEntity.default` and is logged once at `.info` (the `.error` for a
/// genuine decode failure is emitted by the `CacheStore` itself). `save()`
/// forwards to the cache write, which is synchronous and total.
struct SettingsRepositoryImpl: SettingsRepository {
    private let local: SettingsLocalDataSource
    private let logger: any Logger

    init(cache: any CacheStore, logger: any Logger) {
        local = SettingsLocalDataSource(cache: cache)
        self.logger = logger
    }

    func load() async -> DataState<SettingsEntity> {
        guard let dto = local.read() else {
            logger.info(
                "[SettingsRepository] no readable persisted settings — using SettingsEntity.default",
                file: #file,
                function: #function,
                line: #line
            )
            return .success(.default)
        }
        return .success(SettingsMapper.toEntity(dto))
    }

    func save(_ entity: SettingsEntity) async -> DataState<Void> {
        local.write(SettingsMapper.toDTO(entity))
        return .success(())
    }
}
