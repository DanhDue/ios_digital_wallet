import Platform
import SwiftUI

/// The tab layout: a `TabView` whose selection is bound to the router (single
/// source of truth) and routed through `viewModel.dispatch(.selectTab(_:))`, and
/// one `NavigationStack(path:)` per tab so each tab keeps an independent back
/// stack (Source Spec §6.1, Changelog #4).
///
/// Feature-blind: tab-1 and tab-2 roots and every `.navigationDestination` are
/// resolved via `router.destination(for:)`. The shell names only the shared
/// cross-feature route values in `AppRoutes` — never a feature module.
public struct ShellView: View {
    @ObservedObject private var viewModel: ShellViewModel
    @ObservedObject private var router: AppRouter
    @Environment(\.t) private var t: Translations

    public init(viewModel: ShellViewModel, router: AppRouter) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _router = ObservedObject(wrappedValue: router)
    }

    public var body: some View {
        TabView(selection: tabSelection) {
            tabStack(index: 0) { HomeStubView() }
                .tabItem {
                    Label(
                        t.shell.tab.home,
                        systemImage: "house"
                    )
                }
                .tag(0)

            // shell:scanner-tab:begin
            tabStack(index: 1) { router.destination(for: AppRoutes.ScannerRoot()) }
                .tabItem {
                    Label(
                        t.shell.tab.scanner,
                        systemImage: "qrcode.viewfinder"
                    )
                }
                .tag(1)
            // shell:scanner-tab:end

            // shell:settings-tab:begin
            tabStack(index: 2) { router.destination(for: AppRoutes.SettingsRoot()) }
                .tabItem {
                    Label(
                        t.shell.tab.settings,
                        systemImage: "gearshape"
                    )
                }
                .tag(2)
            // shell:settings-tab:end
        }
    }

    /// A `NavigationStack` bound to `router.tabPaths[index]`, with every route
    /// destination delegated back to the router through the single erased
    /// `AnyAppRoute` type — one `.navigationDestination` serves every route,
    /// present and future, shared or feature-private (Source Spec §4.7).
    private func tabStack(index: Int, @ViewBuilder root: () -> some View) -> some View {
        NavigationStack(path: pathBinding(for: index)) {
            root()
                .navigationDestination(for: AnyAppRoute.self) { boxed in
                    router.destination(for: boxed.wrapped)
                }
        }
    }

    /// Getter reads the router; setter funnels the user's tap through the
    /// ViewModel so the reduce / `switchTab` / bus writes stay the single
    /// mutation path (see "If you hit a wall" in the task brief).
    private var tabSelection: Binding<Int> {
        Binding(
            get: { router.selectedTab },
            set: { viewModel.dispatch(.selectTab($0)) }
        )
    }

    /// Range-guarded so an out-of-bounds subscript can never trap the render.
    private func pathBinding(for index: Int) -> Binding<NavigationPath> {
        Binding(
            get: {
                guard router.tabPaths.indices.contains(index) else { return NavigationPath() }
                return router.tabPaths[index]
            },
            set: { newValue in
                guard router.tabPaths.indices.contains(index) else { return }
                router.tabPaths[index] = newValue
            }
        )
    }
}
