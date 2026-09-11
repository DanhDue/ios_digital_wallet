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

    // MARK: DeepLinkRoute call sites (K10)

    /// Every `DeepLinkRoute(...)` call in `file` whose first (unlabeled)
    /// argument is a plain, non-interpolated string literal. Calls with an
    /// interpolated or otherwise non-literal first argument are **not**
    /// silently dropped here — they are reported separately by
    /// `unresolvedDeepLinkRouteCalls(in:)`, which K10.6 uses to fail loudly
    /// instead of letting K10.1/K10.3/K10.5 go blind to them.
    public static func deepLinkRouteCalls(in file: SourceFileSyntax) -> [DeepLinkRouteCall] {
        let visitor = DeepLinkRouteCallVisitor(tree: file, viewMode: .sourceAccurate)
        visitor.walk(file)
        return visitor.calls
    }

    /// Every `DeepLinkRoute(...)` (bare or qualified, e.g.
    /// `Platform.DeepLinkRoute(...)`) call in `file` whose first argument is
    /// **not** a static string literal — an interpolated pattern, a `let`
    /// variable, a function parameter, etc. K10.6 fails on any result here.
    public static func unresolvedDeepLinkRouteCalls(in file: SourceFileSyntax) -> [UnresolvedDeepLinkRouteCall] {
        let visitor = DeepLinkRouteCallVisitor(tree: file, viewMode: .sourceAccurate)
        visitor.walk(file)
        return visitor.unresolved
    }
}

/// One `DeepLinkRoute(...)` call site (Source Spec §4.3): the pattern string
/// literal passed as the first argument, and every plain identifier token
/// referenced inside its `build` closure.
///
/// K10.1 (duplicate patterns), K10.2 (every shared `AppRoute` is reachable by
/// URL), K10.3 (segment grammar) and K10.5 (no repeated parameter name) are
/// four different questions about the exact same call sites, so they share
/// this one walk of the tree rather than each re-parsing
/// `DeepLinkRoute(...)` invocations independently.
public struct DeepLinkRouteCall: Equatable {
    /// The raw pattern string, e.g. `/scanner/result/:code` — never
    /// includes the quotes.
    public let pattern: String

    /// Every identifier token referenced inside the `build` closure body
    /// (trailing-closure or labeled `build:` form), e.g. `AppRoutes`,
    /// `SettingsRoot`, `params`. Comments and string-literal contents are
    /// trivia, not identifier tokens, so they never appear here — that is
    /// what keeps K10.2 an AST check rather than a `String.contains`.
    public let referencedIdentifiers: Set<String>

    public init(pattern: String, referencedIdentifiers: Set<String>) {
        self.pattern = pattern
        self.referencedIdentifiers = referencedIdentifiers
    }
}

/// A `DeepLinkRoute(...)` call site (bare or qualified) whose first argument
/// could not be read as a static string literal — K10.6's evidence that a
/// call was seen but its pattern could not be checked, named by source line
/// rather than silently vanishing from K10.1 / K10.3 / K10.5.
public struct UnresolvedDeepLinkRouteCall: Equatable {
    /// 1-based source line the call starts on (after leading trivia).
    public let line: Int

    public init(line: Int) {
        self.line = line
    }
}

/// Walks every `FunctionCallExprSyntax`, collecting the ones that call
/// `DeepLinkRoute` — bare (`DeepLinkRoute(...)`) or qualified
/// (`Platform.DeepLinkRoute(...)`, or any `<expr>.DeepLinkRoute(...)`) — and
/// splits them into resolved (`calls`, a static string-literal pattern) and
/// unresolved (`unresolved`, everything else: interpolation, a variable, a
/// parameter) so a call is never simply absent from both.
private final class DeepLinkRouteCallVisitor: SyntaxVisitor {
    private(set) var calls: [DeepLinkRouteCall] = []
    private(set) var unresolved: [UnresolvedDeepLinkRouteCall] = []

    private let locationConverter: SourceLocationConverter

    init(tree: SourceFileSyntax, viewMode: SyntaxTreeViewMode) {
        locationConverter = SourceLocationConverter(fileName: "", tree: tree)
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard isDeepLinkRouteCallee(node.calledExpression) else {
            return .visitChildren
        }
        guard let firstArgument = node.arguments.first(where: { $0.label == nil }),
              let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self),
              let pattern = stringLiteral.representedLiteralValue
        else {
            let line = node.startLocation(converter: locationConverter).line
            unresolved.append(UnresolvedDeepLinkRouteCall(line: line))
            return .visitChildren
        }

        var identifiers = node.trailingClosure.map(identifierNames(in:)) ?? []
        for argument in node.arguments where argument.label?.text == "build" {
            identifiers.formUnion(identifierNames(in: argument.expression))
        }

        calls.append(DeepLinkRouteCall(pattern: pattern, referencedIdentifiers: identifiers))
        return .visitChildren
    }

    /// Matches `DeepLinkRoute(...)` however it is spelled at the call site:
    /// a bare reference, or a member access whose final component is
    /// `DeepLinkRoute` (`Platform.DeepLinkRoute(...)`). Without the second
    /// branch a fully-qualified call is dropped at the callee-name stage,
    /// before it is ever a candidate for either `calls` or `unresolved`.
    private func isDeepLinkRouteCallee(_ callee: ExprSyntax) -> Bool {
        if let reference = callee.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text == "DeepLinkRoute"
        }
        if let memberAccess = callee.as(MemberAccessExprSyntax.self) {
            return memberAccess.declName.baseName.text == "DeepLinkRoute"
        }
        return false
    }

    private func identifierNames(in node: some SyntaxProtocol) -> Set<String> {
        var names: Set<String> = []
        for token in node.tokens(viewMode: .sourceAccurate) {
            if case let .identifier(text) = token.tokenKind {
                names.insert(text)
            }
        }
        return names
    }
}
