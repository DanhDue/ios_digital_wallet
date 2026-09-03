/// The logging seam. `Core` never picks a logging backend — the composition
/// root injects one. Call sites pass `#file` / `#function` / `#line`.
///
/// The first parameter is unlabelled; its internal name is `message` (SwiftLint
/// `identifier_name` forbids the one-letter `m` from the design sketch — the
/// external signature `debug(_:file:function:line:)` is unchanged).
public protocol Logger {
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
}
