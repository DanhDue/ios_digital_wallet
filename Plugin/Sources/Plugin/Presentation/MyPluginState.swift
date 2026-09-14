import Foundation

/// State representation for MyPluginView.
public enum MyPluginState: UiState {
    case idle
    case loading
    case loaded(PluginData)
    case error(String)
}
