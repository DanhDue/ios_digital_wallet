// Copyright (c) 2026, one of DanhDue ExOICTIF projects. All rights reserved.

import Flutter
import SwiftUI
import UIKit

public final class {{name.pascalCase()}}PlatformView: NSObject, @preconcurrency FlutterPlatformView, @unchecked Sendable {
    private let hostingController: UIHostingController<{{name.pascalCase()}}View>

    public init(
        frame: CGRect,
        viewIdentifier _: Int64,
        arguments _: Any?,
        viewModel: {{name.pascalCase()}}ViewModel
    ) {
        let controller = MainActor.assumeIsolated {
            let ctrl = UIHostingController(rootView: {{name.pascalCase()}}View(viewModel: viewModel))
            ctrl.view.frame = frame
            ctrl.view.backgroundColor = .clear
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
