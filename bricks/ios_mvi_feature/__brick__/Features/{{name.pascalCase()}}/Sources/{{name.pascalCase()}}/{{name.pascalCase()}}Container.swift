import Core
import Factory{{#has_network}}
import Network{{/has_network}}
import Platform

private struct SilentLogger: Logger {
    func debug(_ message: String, file: String, function: String, line: Int) {}
    func info(_ message: String, file: String, function: String, line: Int) {}
    func error(_ message: String, file: String, function: String, line: Int) {}
}

public extension Container {
    var {{name.camelCase()}}Repository: Factory<any {{name.pascalCase()}}Repository> {
        self {
            MainActor.assumeIsolated {
                {{#has_network}}{{name.pascalCase()}}RepositoryImpl(
                    cache: UserDefaultsCacheStore(),
                    apiClient: nil,
                    logger: SilentLogger()
                ){{/has_network}}{{^has_network}}{{name.pascalCase()}}RepositoryImpl(
                    cache: UserDefaultsCacheStore(),
                    logger: SilentLogger()
                ){{/has_network}}
            }
        }
    }

    var get{{name.pascalCase()}}UseCase: Factory<Get{{name.pascalCase()}}UseCase> {
        self {
            MainActor.assumeIsolated {
                Get{{name.pascalCase()}}UseCase(repository: self.{{name.camelCase()}}Repository())
            }
        }
    }

    var save{{name.pascalCase()}}UseCase: Factory<Save{{name.pascalCase()}}UseCase> {
        self {
            MainActor.assumeIsolated {
                Save{{name.pascalCase()}}UseCase(repository: self.{{name.camelCase()}}Repository())
            }
        }
    }
}
