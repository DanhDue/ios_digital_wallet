// Copyright (c) 2026, one of DanhDue ExOICTIF projects. All rights reserved.

import Combine
import FactoryKit
import Foundation

public final class {{name.pascalCase()}}ViewModel: MviViewModel<{{name.pascalCase()}}Action, {{name.pascalCase()}}State, {{name.pascalCase()}}Event> {
    @Injected(\{{name.pascalCase()}}Container.repository) private var repository

    public init() {
        super.init(initialState: {{name.pascalCase()}}State())
    }

    override public func onAction(_ action: {{name.pascalCase()}}Action) {
        switch action {
        case .initialize:
            setState { $0.isLoading = true }
            Task { [weak self] in
                guard let self else { return }
                let data: String
                do {
                    data = try await repository.getStatus()
                } catch {
                    data = "Unavailable"
                }
                await MainActor.run {
                    self.setState {
                        $0.isLoading = false
                        $0.title = data
                    }
                    self.sendEvent(.showToast("Loaded: \(data)"))
                }
            }
        case let .submit(value):
            setState { $0.title = value }
            sendEvent(.showToast("Submitted: \(value)"))
        }
    }
}
