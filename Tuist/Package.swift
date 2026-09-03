// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import ProjectDescription

    /// Product-type overrides for external SPM dependencies. Empty for Phase 0.
    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

/// SPM manifest Tuist reads for packages. Phase 0 has none — the marker regions
/// below are the contract Mason bricks (Task 13) insert `.package(path:)` /
/// `.package(url:)` lines into. Keep them verbatim; never hand-edit the graph.
let package = Package(
    name: "iOSDigitalWallet",
    dependencies: [
        // tuist:packages:begin
        .package(path: "../Packages/Core"),
        // tuist:packages:end
    ]
)
