import Core{{#has_network}}
import Network{{/has_network}}

/// The one `{{name.pascalCase()}}Repository` conformer (Source Spec §4.4).
/// `internal`, a `struct`, reached only through the Domain protocol
/// (ArchTests K4 / K5).
///
/// `load()` never surfaces `.error`: a miss degrades to
/// `{{name.pascalCase()}}Entity.default`, logged once at `.info`. `save()`
/// forwards to the cache write, which is synchronous and total.
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Data/Repository/SettingsRepositoryImpl.swift
struct {{name.pascalCase()}}RepositoryImpl: {{name.pascalCase()}}Repository {
    private let local: {{name.pascalCase()}}LocalDataSource{{#has_network}}
    private let remote: {{name.pascalCase()}}APIService{{/has_network}}
    private let logger: any Logger
{{#has_network}}
    init(cache: any CacheStore, apiClient: any APIClient, logger: any Logger) {
        local = {{name.pascalCase()}}LocalDataSource(cache: cache)
        remote = {{name.pascalCase()}}APIService(apiClient: apiClient)
        self.logger = logger
    }

    func load() async -> DataState<{{name.pascalCase()}}Entity> {
        if case let .success(dto) = await remote.fetch() {
            local.write(dto)
            return .success({{name.pascalCase()}}Mapper.toEntity(dto))
        }
        return loadLocal()
    }{{/has_network}}{{^has_network}}
    init(cache: any CacheStore, logger: any Logger) {
        local = {{name.pascalCase()}}LocalDataSource(cache: cache)
        self.logger = logger
    }

    func load() async -> DataState<{{name.pascalCase()}}Entity> {
        loadLocal()
    }{{/has_network}}

    func save(_ entity: {{name.pascalCase()}}Entity) async -> DataState<Void> {
        local.write({{name.pascalCase()}}Mapper.toDTO(entity))
        return .success(())
    }

    private func loadLocal() -> DataState<{{name.pascalCase()}}Entity> {
        guard let dto = local.read() else {
            logger.info(
                "[{{name.pascalCase()}}Repository] no readable persisted value — using .default",
                file: #file,
                function: #function,
                line: #line
            )
            return .success(.default)
        }
        return .success({{name.pascalCase()}}Mapper.toEntity(dto))
    }
}
