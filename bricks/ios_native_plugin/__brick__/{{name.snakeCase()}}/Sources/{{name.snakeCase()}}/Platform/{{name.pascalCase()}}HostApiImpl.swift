// Copyright (c) 2026, one of DanhDue ExOICTIF projects. All rights reserved.

import FactoryKit
import Flutter
import UIKit

/// [has_ui=false] The Pigeon `HostApi` implementation. Resolves its domain
/// repository from the plugin's own container, so tests swap it with
/// `{{name.pascalCase()}}Container.shared.repository.register { Mock() }`.
final class {{name.pascalCase()}}HostApiImpl: {{name.pascalCase()}}HostApi {
    @Injected(\{{name.pascalCase()}}Container.repository) private var repository

    func getPlatformVersion() throws -> String {
        _ = repository
        return MainActor.assumeIsolated {
            "iOS " + UIDevice.current.systemVersion
        }
    }
}
