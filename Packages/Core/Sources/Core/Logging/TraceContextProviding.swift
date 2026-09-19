/// The distributed trace context seam.
///
/// Defined in `Core` so network interceptors can inject W3C `traceparent` headers
/// without taking an architectural dependency on concrete logging backends.
public protocol TraceContextProviding: Sendable {
    /// Returns the current or freshly-spawned W3C `traceparent` header string
    /// (`00-{traceId}-{spanId}-01`), or `nil` if tracing is uninitialised or disabled.
    func traceparentHeader() -> String?
}
