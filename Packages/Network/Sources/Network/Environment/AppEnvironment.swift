import Foundation

/// The three build environments. Every case points at the same **placeholder**
/// host — this is a template; real deployments override `baseURL` with a
/// project-specific `Environment` value or swap these literals.
public enum AppEnvironment: String, Environment, CaseIterable {
    case debug
    case staging
    case production

    /// Placeholder API host. Intentionally identical across cases so the
    /// template ships no real infrastructure URLs.
    private static let placeholderHost = "https://api.example.com"

    public var baseURL: URL {
        guard let url = URL(string: Self.placeholderHost) else {
            preconditionFailure("AppEnvironment.placeholderHost must be a valid URL literal")
        }
        return url
    }

    public var defaultHeaders: [String: String] {
        [
            "Accept": "application/json",
            "X-App-Environment": rawValue,
        ]
    }
}
