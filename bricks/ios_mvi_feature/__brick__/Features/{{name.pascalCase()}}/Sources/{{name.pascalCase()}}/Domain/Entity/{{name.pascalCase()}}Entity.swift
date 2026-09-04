/// The value the `{{name.pascalCase()}}` screen renders and edits.
///
/// Pure value type — no framework imports (ArchTests K3).
/// See: Features/Settings/Sources/Settings/Domain/Entity/SettingsEntity.swift
public struct {{name.pascalCase()}}Entity: Equatable, Sendable {
    /// Headline shown by the screen.
    public var title: String
    /// A simple numeric field the screen can edit; replace with real fields.
    public var count: Int

    public init(title: String, count: Int) {
        self.title = title
        self.count = count
    }

    /// The entity a fresh install (or an unreadable cache) starts from.
    public static let `default` = {{name.pascalCase()}}Entity(title: "{{name.pascalCase()}}", count: 0)

    /// A fixed non-default value handy in previews and tests.
    public static let stub = {{name.pascalCase()}}Entity(title: "{{name.pascalCase()}} stub", count: 42)
}
