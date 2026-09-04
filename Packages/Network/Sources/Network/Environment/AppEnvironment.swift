import Foundation

/// The three build environments. Every case points at the same **placeholder**
/// host — this is a template; real deployments override `baseURL` with a
/// project-specific `Environment` value or swap these literals.
public enum AppEnvironment: String, Environment, CaseIterable {
    case debug
    case staging
    case production

    /// Configured API host pointing to the backend.
    public static let configuredHost = "https://digital-wallet-93c4ba68a41d.herokuapp.com"

    public var baseURL: URL {
        guard let url = URL(string: Self.configuredHost) else {
            preconditionFailure("AppEnvironment.configuredHost must be a valid URL literal")
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
