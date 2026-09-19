#if DEBUG
    import Combine
    import D3NexusLogging
    import Foundation
    import Framework

    @MainActor
    public final class LeakDemoViewModel: MviViewModel<LeakDemoState, LeakDemoAction, LeakDemoEvent> {
        private let stream = PassthroughSubject<String, Never>()
        private var sentinelToken: LeakSentinelToken?
        private let leakSentinel: LeakSentinel
        private let gracePeriod: TimeInterval

        public init(
            leakSentinel: LeakSentinel = .shared,
            gracePeriod: TimeInterval = 3.0
        ) {
            self.leakSentinel = leakSentinel
            self.gracePeriod = gracePeriod
            super.init(initialState: LeakDemoState())
        }

        override public func onAction(_ action: LeakDemoAction) {
            switch action {
            case .triggerLeak:
                triggerLeak()
            case .triggerClean:
                triggerClean()
            case .onAppear:
                sentinelToken?.cancel()
                sentinelToken = nil
            case .onDisappear:
                sentinelToken = leakSentinel.track(self, name: "LeakDemoViewModel", gracePeriod: gracePeriod)
            }
        }

        private func triggerLeak() {
            reduce {
                $0.statusMessage = "Leak triggered: ViewModel strongly captured in Combine sink"
                $0.isLeakingTriggered = true
            }
            // Retain cycle: self -> cancellables -> AnyCancellable -> sink closure -> self
            stream.sink { value in
                self.handleStreamValue(value)
            }
            .store(in: &cancellables)

            emit(.leakTriggered)
        }

        private func triggerClean() {
            reduce {
                $0.statusMessage = "Clean flow triggered: ViewModel captured weakly"
                $0.isCleanTriggered = true
            }
            // Clean deallocation: captures [weak self]
            stream.sink { [weak self] value in
                self?.handleStreamValue(value)
            }
            .store(in: &cancellables)

            emit(.cleanTriggered)
        }

        private func handleStreamValue(_ value: String) {
            _ = value
        }
    }
#endif
