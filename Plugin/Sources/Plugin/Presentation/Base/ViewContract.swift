import Foundation

/// Markers for MVI View Contracts.
public protocol UiState: Equatable, Sendable {}
public protocol UiAction: Sendable {}
public protocol UiEvent: Sendable {}
