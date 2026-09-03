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

    public init(viewModel: ShellViewModel, router: AppRouter) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _router = ObservedObject(wrappedValue: router)
    }

    public var body: some View {
        TabView(selection: tabSelection) {
            tabStack(index: 0) { HomeStubView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            tabStack(index: 1) { router.destination(for: AppRoutes.ScannerRoot()) }
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
                .tag(1)

            tabStack(index: 2) { router.destination(for: AppRoutes.SettingsRoot()) }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
    }

    /// A `NavigationStack` bound to `router.tabPaths[index]`, with the shared
    /// route destinations delegated back to the router.
    private func tabStack(index: Int, @ViewBuilder root: () -> some View) -> some View {
        NavigationStack(path: pathBinding(for: index)) {
            root()
                .navigationDestination(for: AppRoutes.SettingsRoot.self) { route in
                    router.destination(for: route)
                }
                .navigationDestination(for: AppRoutes.ScannerRoot.self) { route in
                    router.destination(for: route)
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
