import Flutter
import Foundation
import UIKit
import XCTest
@testable import Plugin

private final class StubBinaryMessenger: NSObject, FlutterBinaryMessenger {
    var messageHandlers: [String: FlutterBinaryMessageHandler] = [:]

    func send(onChannel _: String, message _: Data?) {}

    func send(
        onChannel _: String,
        message _: Data?,
        binaryReply _: FlutterBinaryReply? = nil
    ) {}

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
    ) -> FlutterBinaryMessengerConnection {
        messageHandlers[channel] = handler
        return 1
    }

    func cleanUpConnection(_: FlutterBinaryMessengerConnection) {}
}

private final class StubPluginRegistrar: NSObject, FlutterPluginRegistrar {
    let stubMessenger = StubBinaryMessenger()
    var registeredViewType: String?
    var registeredFactory: FlutterPlatformViewFactory?

    func messenger() -> FlutterBinaryMessenger {
        stubMessenger
    }

    var viewController: UIViewController? {
        nil
    }

    func addSceneDelegate(_: any FlutterSceneLifeCycleDelegate) {}

    func textures() -> FlutterTextureRegistry {
        fatalError("Unused in test")
    }

    func register(
        _ factory: FlutterPlatformViewFactory,
        withId factoryId: String
    ) {
        registeredFactory = factory
        registeredViewType = factoryId
    }

    func register(
        _ factory: FlutterPlatformViewFactory,
        withId factoryId: String,
        gestureRecognizersBlockingPolicy _: FlutterPlatformViewGestureRecognizersBlockingPolicy
    ) {
        register(factory, withId: factoryId)
    }

    func publish(_: NSObject) {}

    func addMethodCallDelegate(
        _: FlutterPlugin,
        channel _: FlutterMethodChannel
    ) {}

    func addApplicationDelegate(_: FlutterPlugin) {}

    func lookupKey(forAsset asset: String) -> String {
        asset
    }

    func lookupKey(forAsset asset: String, fromPackage _: String) -> String {
        asset
    }
}

@MainActor
final class MyPlatformViewTests: XCTestCase {
    func testFactoryCreatesPlatformViewWithValidUIView() {
        let messenger = StubBinaryMessenger()
        let factory = MyPlatformViewFactory(messenger: messenger)

        let platformView = factory.create(
            withFrame: CGRect(x: 0, y: 0, width: 320, height: 480),
            viewIdentifier: 42,
            arguments: nil
        )

        XCTAssertTrue(platformView is MyPlatformView)
        let uiView = platformView.view()
        XCTAssertNotNil(uiView)
        XCTAssertEqual(uiView.frame.width, 320)
        XCTAssertEqual(uiView.frame.height, 480)
    }

    func testPlatformViewRetainsHostingController() {
        let platformView = MyPlatformView(
            frame: .zero,
            viewIdentifier: 1,
            arguments: nil
        )

        XCTAssertNotNil(platformView.hostingController)
        XCTAssertNotNil(platformView.view())
    }

    func testPluginRegistersBothHostApiAndPlatformViewFactory() {
        let registrar = StubPluginRegistrar()

        MyPlugin.register(with: registrar)

        XCTAssertEqual(registrar.registeredViewType, "com.danhdue.plugin/native_view")
        XCTAssertTrue(registrar.registeredFactory is MyPlatformViewFactory)
    }

    func testDetachingEngineClearsMessenger() {
        let messenger = StubBinaryMessenger()
        let plugin = MyPlugin(messenger: messenger)
        let registrar = StubPluginRegistrar()

        plugin.detachFromEngine(for: registrar)
        // Successfully detached without crash
    }
}
