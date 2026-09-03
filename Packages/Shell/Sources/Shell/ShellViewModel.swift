import Framework
import Platform

/// The host ViewModel. An `MviViewModel` so the shell obeys the same MVI
/// discipline every Feature does (Source Spec §5.4, design rationale).
///
/// The `AppRouter` and `AppEventBus` are **injected** by the `App` composition
/// root (Task 12) — the shell creates neither. `router.selectedTab` is the
/// single source of truth for the visible tab; every mutation flows through
/// `dispatch(.selectTab(_:))` so the reduce / router / bus writes stay ordered.
public final class ShellViewModel: MviViewModel<ShellState, ShellAction, ShellEvent> {
    private let config: ShellConfig
    private let router: AppRouter
    private let eventBus: AppEventBus

    public init(config: ShellConfig, router: AppRouter, eventBus: AppEventBus) {
        self.config = config
        self.router = router
        self.eventBus = eventBus
        super.init(initialState: ShellState(selectedTab: config.initialTab))
        // Cold start: the router is the source of truth the view binds to, so
        // align it with the configured initial tab regardless of how the
        // composition root constructed it. No visibility events on cold start.
        router.switchTab(config.initialTab)
    }

    override public func onAction(_ action: ShellAction) {
        switch action {
        case let .selectTab(index):
            selectTab(index)
        }
    }

    private func selectTab(_ index: Int) {
        // Out of `0..<tabCount` → ignore (no crash, no state change).
        guard (0 ..< config.tabCount).contains(index) else { return }

        let previous = uiState.selectedTab

        // Re-tap the active tab → pop that tab to root and ask its root screen
        // to scroll to the top. No reduce, no router switch, no bus publish.
        guard index != previous else {
            router.popToRoot(inTab: index)
            emit(.scrollToTop(tab: index))
            return
        }

        // Switch → reduce first, move the router, then publish the visibility
        // pair in old→new order (hide the tab we left, then show the new one).
        reduce { $0.selectedTab = index }
        router.switchTab(index)
        eventBus.publish(ShellTabVisibilityChanged(tabIndex: previous, isVisible: false))
        eventBus.publish(ShellTabVisibilityChanged(tabIndex: index, isVisible: true))
    }
}
