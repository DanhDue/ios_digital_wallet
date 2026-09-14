// Copyright (c) 2026, one of DanhDue ExOICTIF projects. All rights reserved.

import Flutter
import UIKit

public final class {{name.pascalCase()}}PlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let makeViewModel: () -> {{name.pascalCase()}}ViewModel

    public init(makeViewModel: @escaping () -> {{name.pascalCase()}}ViewModel) {
        self.makeViewModel = makeViewModel
        super.init()
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        {{name.pascalCase()}}PlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            viewModel: makeViewModel()
        )
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
