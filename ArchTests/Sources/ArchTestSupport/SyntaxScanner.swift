import Foundation
import SwiftParser
import SwiftSyntax

/// A minimal, SwiftSyntax-free description of a top-level declaration, so rule
/// tests never have to import SwiftSyntax themselves.
public struct DeclInfo: Equatable {
    /// Declaration kind: `struct`, `class`, `enum`, `actor`, `protocol`,
    /// `extension`, `func`, or `typealias`.
    public let kind: String
    /// The declared name (for `extension`, the extended type).
    public let name: String
    /// Declaration modifiers in source order (e.g. `["public", "final"]`).
    public let modifiers: [String]
    /// Names in the inheritance / conformance clause (empty for `func`,
    /// `typealias`).
    public let inheritedTypeNames: [String]

    public init(kind: String, name: String, modifiers: [String], inheritedTypeNames: [String]) {
        self.kind = kind
        self.name = name
        self.modifiers = modifiers
        self.inheritedTypeNames = inheritedTypeNames
    }
}

/// Thin wrapper over SwiftParser / SwiftSyntax: walk a directory of `.swift`
/// files, parse each one, and pull out the handful of facts the architecture
/// rules care about (imports, top-level declarations). The SwiftSyntax surface
/// stays inside this file.
public enum SyntaxScanner {
    /// Every `.swift` file under `directory`, recursively, sorted by path.
    /// Returns an empty array when `directory` does not exist.
    public static func swiftFiles(under directory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let entry as URL in enumerator where entry.pathExtension == "swift" {
            files.append(entry)
        }
        return files.sorted { $0.path < $1.path }
    }

    /// Parses `source` into a syntax tree. Never throws — the parser always
    /// yields a tree, using error nodes for invalid input.
    public static func parse(source: String) -> SourceFileSyntax {
        Parser.parse(source: source)
    }

    /// Reads and parses the file at `url`.
    public static func parse(fileAt url: URL) throws -> SourceFileSyntax {
        let source = try String(contentsOf: url, encoding: .utf8)
        return parse(source: source)
    }

    /// Names of the modules imported by `file`, in source order. A dotted import
    /// (`import struct Foo.Bar`) is reported as `Foo.Bar`.
    public static func importedModuleNames(in file: SourceFileSyntax) -> [String] {
        file.statements.compactMap { statement in
            guard let importDecl = statement.item.as(ImportDeclSyntax.self) else { return nil }
            return importDecl.path
                .map { component in component.name.text }
                .joined(separator: ".")
        }
    }

    /// The top-level declarations of `file` as `DeclInfo` values. Nested
    /// declarations are not descended into.
    public static func topLevelDeclarations(in file: SourceFileSyntax) -> [DeclInfo] {
        file.statements.compactMap { statement in declInfo(for: statement.item) }
    }

    private static func declInfo(for item: CodeBlockItemSyntax.Item) -> DeclInfo? {
        if let info = namedGroup(item, StructDeclSyntax.self, kind: "struct") {
            return info
        }
        if let info = namedGroup(item, ClassDeclSyntax.self, kind: "class") {
            return info
        }
        if let info = namedGroup(item, EnumDeclSyntax.self, kind: "enum") {
            return info
        }
        if let info = namedGroup(item, ActorDeclSyntax.self, kind: "actor") {
            return info
        }
        if let info = namedGroup(item, ProtocolDeclSyntax.self, kind: "protocol") {
            return info
        }
        if let decl = item.as(ExtensionDeclSyntax.self) {
            return DeclInfo(
                kind: "extension",
                name: decl.extendedType.trimmedDescription,
                modifiers: names(of: decl.modifiers),
                inheritedTypeNames: names(of: decl.inheritanceClause)
            )
        }
        if let decl = item.as(FunctionDeclSyntax.self) {
            return DeclInfo(
                kind: "func",
                name: decl.name.text,
                modifiers: names(of: decl.modifiers),
                inheritedTypeNames: []
            )
        }
        if let decl = item.as(TypeAliasDeclSyntax.self) {
            let modifiers = names(of: decl.modifiers)
            return DeclInfo(kind: "typealias", name: decl.name.text, modifiers: modifiers, inheritedTypeNames: [])
        }
        return nil
    }

    private static func namedGroup(
        _ item: CodeBlockItemSyntax.Item,
        _ type: (some DeclGroupSyntax & NamedDeclSyntax).Type,
        kind: String
    ) -> DeclInfo? {
        guard let decl = item.as(type) else {
            return nil
        }
        return DeclInfo(
            kind: kind,
            name: decl.name.text,
            modifiers: names(of: decl.modifiers),
            inheritedTypeNames: names(of: decl.inheritanceClause)
        )
    }

    private static func names(of modifiers: DeclModifierListSyntax) -> [String] {
        modifiers.map { modifier in modifier.name.text }
    }

    private static func names(of clause: InheritanceClauseSyntax?) -> [String] {
        guard let clause else { return [] }
        return clause.inheritedTypes.map { inherited in inherited.type.trimmedDescription }
    }
}
