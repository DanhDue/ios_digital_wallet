import Foundation
import SwiftUI
import XCTest
@testable import AppUIKit

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

// MARK: - Render smoke helper

/// Hosts `view` in a real hosting controller and forces a layout pass, so the
/// SwiftUI `body` actually executes. On a host without AppKit/UIKit it falls
/// back to evaluating `body` directly. Any crash fails the calling test.
@MainActor
func assertRenders(
    _ view: some View,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    #if canImport(AppKit)
        let host = NSHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        host.view.layoutSubtreeIfNeeded()
        XCTAssertNotNil(host.view, file: file, line: line)
    #elseif canImport(UIKit)
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, file: file, line: line)
    #else
        _ = view.body
    #endif
}

// MARK: - Package source scanning

enum PackageSources {
    /// `Packages/AppUIKit` — three parents up from this file
    /// (`…/Tests/AppUIKitTests/TestSupport.swift`).
    static let root: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // AppUIKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // AppUIKit

    static let sourcesDir: URL = root
        .appendingPathComponent("Sources")
        .appendingPathComponent("AppUIKit")

    static let componentsDir: URL = sourcesDir.appendingPathComponent("Components")

    static let manifest: URL = root.appendingPathComponent("Package.swift")

    /// Every `.swift` file under `directory`, recursively.
    static func swiftFiles(under directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        return files
    }

    static func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}
