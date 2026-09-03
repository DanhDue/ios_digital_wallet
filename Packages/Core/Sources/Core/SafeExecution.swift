/// Runs a throwing block, and on failure logs once (at `error`) with a caller
/// supplied `label` and returns `fallback`. The escape hatch for "this must not
/// crash the app, degrade instead".
public enum SafeExecution {
    public static func run<T>(
        logger: Logger? = nil,
        label: String = "",
        fallback: T,
        _ block: () throws -> T
    ) -> T {
        do {
            return try block()
        } catch {
            logger?.error("[\(label)] \(error)", file: #file, function: #function, line: #line)
            return fallback
        }
    }
}
