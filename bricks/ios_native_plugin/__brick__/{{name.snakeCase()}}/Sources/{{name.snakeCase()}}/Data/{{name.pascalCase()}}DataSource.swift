// Copyright (c) 2026, one of DanhDue ExOICTIF projects. All rights reserved.

import Foundation

public final class {{name.pascalCase()}}DataSource: {{name.pascalCase()}}Repository {
    public init() {}

    public func getStatus() async throws -> String {
        "Active"
    }
}
