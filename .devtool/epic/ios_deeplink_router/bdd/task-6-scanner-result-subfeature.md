# BDD Scenarios — Task 6: Scanner Result Subfeature via Mason Brick

Captured from the implementer's QA pass at implementation time (2026-09-10).
Historical record of what was analysed — including partitions deliberately
excluded. The executable form is the XCTest suite; see the task's Relevant
Files. Task: [task_6_scanner_result_subfeature](../../../features/task_6_scanner_result_subfeature.md)

## PHASE 1 — BDD SCENARIOS

### BDD SCENARIOS

```gherkin
Feature: ScannerResultRoute identity (AppRoute Hashable conformance)

  Scenario: Two routes with the same code are equal and hash equally
    Given two ScannerResultRoute values both constructed with code "ABC123"
    When they are compared with ==
    Then they are equal
    And inserting both into a Set collapses to exactly one element

  Scenario: Two routes with different codes are not equal
    Given ScannerResultRoute(code: "ABC123") and ScannerResultRoute(code: "XYZ789")
    When compared with ==
    Then they are not equal
    And inserting both into a Set keeps two elements

  Scenario: ScannerResultRoute never equals AppRoutes.ScannerRoot
    Given ScannerResultRoute(code: "ABC123") and AppRoutes.ScannerRoot()
    When both are boxed into AnyAppRoute (the NavigationPath storage type) and compared
    Then they are not equal

Feature: Code payload partitions (Boundary Value Analysis / Equivalence Partitioning)
  Partitions: empty string, single character, long string (2000 chars),
  unicode ("阿β🎉こんにちは"), a code containing "/" ("abc/def/ghi" — Task 2 can
  hand the router a %2F-decoded code shaped like this), a code that looks
  like a URL ("https://example.com/product?id=42&ref=/promo").

  Scenario Outline: canHandle resolves true for every code partition
    Given a ScannerResultRoute constructed with code "<code>"
    When canHandle(route) is called on ScannerRouteProvider
    Then it returns true

  Scenario Outline: destination(for:) resolves a non-empty view for every code partition
    Given a ScannerResultRoute constructed with code "<code>"
    When destination(for: route) is called
    Then the returned AnyView's description contains "DeferredResultView"
    And it does not contain "EmptyView"

  Scenario Outline: ResultState preserves every code partition unchanged
    Given ResultViewModel constructed with code "<code>"
    Then uiState.code equals "<code>" before dispatch(.onAppear)
    And uiState.code still equals "<code>" after dispatch(.onAppear)
    And viewState is .content after dispatch(.onAppear)

Feature: ScannerRouteProvider resolution

  Scenario: canHandle is true for ScannerResultRoute
  Scenario: canHandle is true for ScannerRoot (regression — pre-existing)
  Scenario: canHandle is false for an unrelated route (AppRoutes.SettingsRoot),
            even after the provider learned ScannerResultRoute
  Scenario: destination(for:) returns the Result view for ScannerResultRoute —
            asserted by exact substring match on the erased view's description,
            not merely non-nil
  Scenario: destination(for:) returns an AnyView wrapping EmptyView for an
            unrelated route — asserted by exact substring match
  Scenario: router.navigate(to: ScannerResultRoute(code: "ABC123")) pushes the
            route onto the tab's NavigationPath (count goes 0 -> 1), and
            router.destination(for:) resolves it to DeferredResultView — the
            concrete proof of blocker D3 / Task 1: before AnyAppRoute erasure,
            ShellView had no destination for a route it didn't statically name

Feature: ResultViewModel behaviour

  Scenario: Initial viewState is .loading before any dispatch
  Scenario: onAppear transitions viewState from .loading to .content
  Scenario: The code the ViewModel was constructed with survives into state
            unchanged, both before and after dispatch(.onAppear)
  Scenario: Two ResultViewModel instances constructed with different codes do
            not share state (no shared/static storage)

Feature: ResultView rendering

  Scenario: The view's body is non-nil for a representative code and for the
            empty-string boundary
  Scenario: Hosting the view in a UIHostingController does not crash for a
            URL-shaped code (UIKit-gated; does not run on the macOS test host,
            matching ScannerViewTests' existing convention)
  Scenario: No raw string literal appears in ResultView for static text — the
            view reads viewModel.uiState.code (dynamic data, not a literal)
            for the scanned code itself, and t.scanner.result.{title,
            codeLabel, errorMessage} for every piece of static text; verified
            by source inspection (no Text("...") or "..." literal in the file
            besides the accessibility identifier and #Preview sample data)
```

Self-review against the brief's Definition of Done:
- `swift test --package-path Features/Scanner` passes → covered by every scenario above; verified (35/35).
- `swift test --package-path ArchTests` passes (K2, K5, K9) → covered by "ScannerRouteProvider resolution" + the route staying feature-private (no Platform.AppRoutes edit); verified (31/31).
- `merge_localizations.py` runs clean, no hard-coded literal in the view → covered by the "ResultView rendering" scenario; verified.
- `router.navigate(to: ScannerResultRoute(code: "ABC123"))` renders the result screen, proven by a test → covered explicitly by `testNavigatingToScannerResultRoutePushesItAndResolvesToTheResultView`.
- SwiftLint `--strict` / SwiftFormat `--lint` clean → verified below.

Every DoD line has a scenario. Proceeding to Phase 2.

