/// A three-state container for asynchronously loaded data.
///
/// Mirrors the Flutter `DataState` / Android sealed `DataState`: exactly one of
/// loading, a success value, or a typed `AppError`.
public enum DataState<T> {
    case success(T)
    case error(AppError)
    case loading
}

public extension DataState {
    /// Transforms a contained success value, leaving `.error` / `.loading`
    /// untouched.
    func map<U>(_ transform: (T) -> U) -> DataState<U> {
        switch self {
        case let .success(value): .success(transform(value))
        case let .error(appError): .error(appError)
        case .loading: .loading
        }
    }

    /// Chains a contained success value into another `DataState`, leaving
    /// `.error` / `.loading` untouched.
    func flatMap<U>(_ transform: (T) -> DataState<U>) -> DataState<U> {
        switch self {
        case let .success(value): transform(value)
        case let .error(appError): .error(appError)
        case .loading: .loading
        }
    }
}
