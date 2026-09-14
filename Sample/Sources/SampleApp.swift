import Plugin
import SwiftUI

/// Main entry point for the Sample test runner app.
@main
struct SampleApp: App {
    init() {
        // Register BGTaskScheduler identifier before didFinishLaunching returns
        DataSyncTask.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
