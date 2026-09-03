import SwiftUI

@main
struct iOSDigitalWalletApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let composition: AppComposition
    private let lifecycleObserver: LifecycleObserver

    init() {
        let composition = AppComposition()
        self.composition = composition
        lifecycleObserver = LifecycleObserver(eventBus: composition.eventBus)
    }

    var body: some Scene {
        WindowGroup {
            RootView(composition: composition)
                .onChange(of: scenePhase) { newPhase in
                    lifecycleObserver.handle(newPhase)
                }
        }
    }
}
