import Foundation

/// Single-shot side-effect events emitted by MyPluginViewModel.
public enum MyPluginEvent: UiEvent {
    case showError(String)
}
