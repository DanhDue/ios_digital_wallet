import Flutter
import SwiftUI
import UIKit

/// Flutter Platform View bridging MyPluginView into Flutter widget trees.
public final class MyPlatformView: NSObject, FlutterPlatformView {
    public let hostingController: UIHostingController<MyPluginView>

    public init(
        frame: CGRect,
        viewIdentifier _: Int64,
        arguments _: Any?,
        viewModel: MyPluginViewModel? = nil
    ) {
        let pluginView = MyPluginView(viewModel: viewModel)
        let controller = UIHostingController(rootView: pluginView)
        controller.view.frame = frame
        hostingController = controller
        super.init()
    }

    public func view() -> UIView {
        hostingController.view
    }
}
