import Foundation
import Plugin
import XCTest

final class SampleAppTests: XCTestCase {
    func testInfoPlistContainsRequiredBackgroundIdentifier() {
        // Verify identifier matches DataSyncTask
        let expectedIdentifier = DataSyncTask.identifier
        XCTAssertEqual(expectedIdentifier, "com.danhdue.plugin.sync")

        // Read Sample Info.plist directly if running in workspace or bundle
        let possiblePaths = [
            "Sample/Resources/Info.plist",
            "../Sample/Resources/Info.plist",
        ]
        guard let path = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        else {
            return
        }
        let plistObj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let plist = plistObj as? [String: Any] else {
            return
        }

        let identifiers = plist["BGTaskSchedulerPermittedIdentifiers"] as? [String]
        XCTAssertNotNil(identifiers, "BGTaskSchedulerPermittedIdentifiers must be present in Info.plist")
        XCTAssertTrue(
            identifiers?.contains(expectedIdentifier) ?? false,
            "Info.plist must contain \(expectedIdentifier)"
        )
    }
}
