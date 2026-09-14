import Flutter
import UIKit

/// Factory responsible for instantiating MyPlatformView instances for Flutter.
public final class MyPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    public static let viewType = "com.danhdue.plugin/native_view"

    private let messenger: FlutterBinaryMessenger

    public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        MyPlatformView(frame: frame, viewIdentifier: viewId, arguments: args)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
