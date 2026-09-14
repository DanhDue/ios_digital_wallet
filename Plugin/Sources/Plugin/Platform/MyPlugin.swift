@preconcurrency import Flutter
import UIKit

/// Root plugin entry point and composition root for Flutter iOS bindings.
public final class MyPlugin: NSObject, @preconcurrency FlutterPlugin {
    private var messenger: FlutterBinaryMessenger?

    public init(messenger: FlutterBinaryMessenger? = nil) {
        self.messenger = messenger
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let binaryMessenger = registrar.messenger()

        // 1. Setup Headless Host API (Pigeon)
        let hostApi = MyPluginHostApiImpl()
        MyPluginHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: hostApi)

        // 2. Register Platform View Factory (With UI)
        let viewFactory = MyPlatformViewFactory(messenger: binaryMessenger)
        registrar.register(viewFactory, withId: MyPlatformViewFactory.viewType)

        // 3. Register Background Task scheduler before launch completes
        DataSyncTask.register()

        // 4. Register Method Channel delegate
        let channel = FlutterMethodChannel(
            name: "com.danhdue.plugin/methods",
            binaryMessenger: binaryMessenger
        )
        let instance = MyPlugin(messenger: binaryMessenger)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            let version = MainActor.assumeIsolated {
                "iOS " + UIDevice.current.systemVersion
            }
            result(version)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngine(for _: FlutterPluginRegistrar) {
        if let messenger {
            MyPluginHostApiSetup.setUp(binaryMessenger: messenger, api: nil)
        }
        messenger = nil
    }
}
