/// The value the Scanner screen would render (Source Spec §4.3). Pure value
/// type — no framework imports (ArchTests K3).
///
/// The template ships Scanner as a stub, so the entity is trivial and the
/// feature never mutates it beyond the initial `stub` load.
public struct ScannerEntity: Equatable, Sendable {
    /// Headline shown by the placeholder screen.
    public let title: String
    /// Whether a real scanner implementation is wired up. Always `false` in the
    /// template stub.
    public let isAvailable: Bool

    public init(title: String, isAvailable: Bool) {
        self.title = title
        self.isAvailable = isAvailable
    }

    /// The fixed value the stub repository returns.
    public static let stub = ScannerEntity(title: "Scanner coming soon", isAvailable: false)
}
