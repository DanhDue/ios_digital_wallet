import Combine
import Core
import Foundation
import Framework
import Platform
import XCTest
@testable import Settings

// MARK: - ViewState inspection (keeps the shipping enum free of Equatable)

extension ViewState {
    /// Stable discriminator for exact-sequence assertions.
    var tag: String {
        switch self {
        case .loading: "loading"
        case .error: "error"
        case .content: "content"
        }
    }

    var errorValue: Error? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Combine recorder

/// Sinks a `Never`-failing publisher into an ordered array so tests can assert
/// the exact emission *sequence*. Lock-guarded / `@unchecked Sendable` so the
/// sink needs no actor hop. Subscribe BEFORE the action under test.
final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []
    private var cancellable: AnyCancellable?

    init(_ publisher: some Publisher<Value, Never>) {
        cancellable = publisher.sink { [weak self] value in
            guard let self else { return }
            lock.lock()
            storage.append(value)
            lock.unlock()
        }
    }

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int {
        values.count
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}

// MARK: - Spy Logger

/// Records every log line by level so tests can assert "logged at `.error`".
final class SpyLogger: Logger, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var debugMessages: [String] = []
    private(set) var infoMessages: [String] = []
    private(set) var errorMessages: [String] = []

    func debug(_ message: String, file _: String, function _: String, line _: Int) {
        lock.lock(); debugMessages.append(message); lock.unlock()
    }

    func info(_ message: String, file _: String, function _: String, line _: Int) {
        lock.lock(); infoMessages.append(message); lock.unlock()
    }

    func error(_ message: String, file _: String, function _: String, line _: Int) {
        lock.lock(); errorMessages.append(message); lock.unlock()
    }
}

// MARK: - In-memory CacheStore

/// A `CacheStore` fake with a real JSON round-trip in a dictionary. Mirrors
/// `Core.UserDefaultsCacheStore`: a decode failure logs at `.error` and returns
/// `nil`. Test seams (`seedRaw`, `contains`) expose the backing bytes.
final class InMemoryCacheStore: CacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private let logger: any Logger

    init(logger: any Logger) {
        self.logger = logger
    }

    func get<T: Codable>(_: T.Type, key: String) -> T? {
        lock.lock()
        let data = storage[key]
        lock.unlock()
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error(
                "[InMemoryCacheStore] decode failed for '\(key)': \(error)",
                file: #file,
                function: #function,
                line: #line
            )
            return nil
        }
    }

    func set(_ value: some Codable, key: String) {
        let encoded = try? JSONEncoder().encode(value)
        lock.lock()
        storage[key] = encoded
        lock.unlock()
    }

    func remove(key: String) {
        lock.lock()
        storage[key] = nil
        lock.unlock()
    }

    func clearAll() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }

    /// Seed arbitrary (possibly invalid) bytes under `key`.
    func seedRaw(_ data: Data, key: String) {
        lock.lock()
        storage[key] = data
        lock.unlock()
    }

    func contains(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] != nil
    }
}

// MARK: - Async gate

/// A deterministic, sleep-free suspension point. An awaiter calls `wait()` and
/// parks until the test calls `open()`.
actor AsyncGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var opened = false

    func wait() async {
        if opened {
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        let pending = waiters
        waiters.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}

// MARK: - Spy repository

/// Counts calls, records saved entities, lets a test script results and gate the
/// async completion of `load` / `save`.
@MainActor
final class SpySettingsRepository: SettingsRepository {
    private(set) var loadCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var savedEntities: [SettingsEntity] = []

    var loadResult: DataState<SettingsEntity> = .success(.default)
    var saveResult: DataState<Void> = .success(())
    var loadGate: AsyncGate?
    var saveGate: AsyncGate?

    var availableLanguagesResult: DataState<[AvailableLanguage]> = .success(AvailableLanguage.defaultLanguages)
    var cachedLanguages: Set<String> = []
    var localizationOverridesResult: DataState<TranslationOverride?> = .success(nil)
    var localizationOverridesGate: AsyncGate?
    var saveCachedTranslationsResult: DataState<Void> = .success(())
    var updateUserPreferencesResult: DataState<Void> = .success(())

    private(set) var savedTranslations: [String: [String: String]] = [:]
    private(set) var updatedPreferences: [(language: String?, isDarkMode: Bool?)] = []

    func load() async -> DataState<SettingsEntity> {
        loadCallCount += 1
        if let loadGate {
            await loadGate.wait()
        }
        return loadResult
    }

    func save(_ entity: SettingsEntity) async -> DataState<Void> {
        saveCallCount += 1
        if let saveGate {
            await saveGate.wait()
        }
        if Task.isCancelled {
            return .error(AppError(code: "cancelled", message: "cancelled"))
        }
        savedEntities.append(entity)
        return saveResult
    }

    func getAvailableLanguages() async -> DataState<[AvailableLanguage]> {
        availableLanguagesResult
    }

    func isLanguageCached(_ code: String) async -> Bool {
        cachedLanguages.contains(code)
    }

    func getLocalizationOverrides(
        code _: String,
        sinceVersion _: String?,
        eTag _: String?
    ) async -> DataState<TranslationOverride?> {
        if let localizationOverridesGate {
            await localizationOverridesGate.wait()
        }
        return localizationOverridesResult
    }

    func saveCachedTranslations(
        code: String,
        version _: String,
        eTag _: String?,
        translations: [String: String]
    ) async -> DataState<Void> {
        savedTranslations[code] = translations
        return saveCachedTranslationsResult
    }

    func updateUserPreferences(language: String?, isDarkMode: Bool?) async -> DataState<Void> {
        updatedPreferences.append((language: language, isDarkMode: isDarkMode))
        return updateUserPreferencesResult
    }

    var isSettingsCachedResult = true

    func isSettingsCached() async -> Bool {
        isSettingsCachedResult
    }
}

// MARK: - Mock Localization Service

@MainActor
final class MockLocalizationService: LocalizationService {
    var currentLanguageCode: String = "en"
    private(set) var setLocaleCalls: [String] = []
    private(set) var appliedTranslations: [(translations: [String: String], languageCode: String)] = []

    func setLocale(code: String) {
        setLocaleCalls.append(code)
        currentLanguageCode = code
    }

    func applyDynamicTranslations(_ translations: [String: String], languageCode: String) {
        appliedTranslations.append((translations: translations, languageCode: languageCode))
    }
}

// MARK: - System-under-test bundle

@MainActor
struct SettingsEnv {
    let sut: SettingsViewModel
    let repo: SpySettingsRepository
    let themeManager: AppThemeManager
    let localizationService: MockLocalizationService

    init(
        repo: SpySettingsRepository = SpySettingsRepository(),
        themeManager: AppThemeManager? = nil,
        localizationService: MockLocalizationService? = nil
    ) {
        self.repo = repo
        let cache = InMemoryCacheStore(logger: SpyLogger())
        let eventBus = AppEventBus()
        let resolvedTheme = themeManager ?? AppThemeManager(cache: cache, eventBus: eventBus)
        let resolvedLoc = localizationService ?? MockLocalizationService()
        self.themeManager = resolvedTheme
        self.localizationService = resolvedLoc

        sut = SettingsViewModel(
            repository: repo,
            themeManager: resolvedTheme,
            localizationService: resolvedLoc
        )
    }
}

// MARK: - Async helpers

/// Polls `predicate` (cheap sleeps, no busy-spin) until it holds or `timeout`
/// elapses. Bounds failure so a broken implementation fails fast, not hangs.
@MainActor
func poll(
    timeout: TimeInterval = 2,
    _ predicate: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate(), Date() < deadline {
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}

/// Lets already-scheduled main-actor effect tasks run to completion.
func settle(_ iterations: Int = 50) async {
    for _ in 0 ..< iterations {
        await Task.yield()
    }
}
