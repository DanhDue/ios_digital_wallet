// Copyright (c) 2026, one of DanhDue ExOICTIF projects. All rights reserved.

import Foundation

public protocol {{name.pascalCase()}}Repository {
    func getStatus() async throws -> String
}
