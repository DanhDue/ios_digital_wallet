import Foundation

/// Generates W3C-compliant trace and span identifiers from random bytes.
public enum TraceIdentifier {
    /// Generates a 32-character lowercase hex string representing a 128-bit trace ID.
    public static func newTraceId() -> String {
        let high = UInt64.random(in: .min ... .max)
        let low = UInt64.random(in: .min ... .max)
        return String(format: "%016llx%016llx", high, low)
    }

    /// Generates a 16-character lowercase hex string representing a 64-bit span ID.
    public static func newSpanId() -> String {
        let val = UInt64.random(in: .min ... .max)
        return String(format: "%016llx", val)
    }
}
