import Flutter
import SwiftUI
import UIKit

/// Flutter Platform View bridging MyPluginView into Flutter widget trees.
public final class MyPlatformView: NSObject, @preconcurrency FlutterPlatformView, @unchecked Sendable {
    public let hostingController: UIHostingController<MyPluginView>

    public init(
        frame: CGRect,
        viewIdentifier _: Int64,
        arguments _: Any?,
        viewModel: MyPluginViewModel? = nil
    ) {
        let controller = MainActor.assumeIsolated {
            let pluginView = MyPluginView(viewModel: viewModel)
            let ctrl = UIHostingController(rootView: pluginView)
            ctrl.view.frame = frame
            return ctrl
        }
        hostingController = controller
        super.init()
    }

    public func view() -> UIView {
        MainActor.assumeIsolated {
            hostingController.view
        }
    }
}
