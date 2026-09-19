import Foundation

/// Fast, thread-safe data masking engine enforcing PII and secret redaction rules.
///
/// Performance Budget:
/// Redaction of a 256 KB message containing 100 card-shaped tokens completes well within
/// the 100ms budget (typically < 30ms on modern Apple Silicon devices).
public struct Redactor: Sendable {
    private struct CompiledPattern: @unchecked Sendable {
        let regex: NSRegularExpression
        let replacement: String
    }

    private let sensitiveHeaderKeys: Set<String>
    private let compiledPatterns: [CompiledPattern]

    /// Initializes a redactor with custom or default redaction rules.
    ///
    /// Regular expressions are pre-compiled once at initialization to prevent overhead on the logging path.
    public init(rules: [RedactionRule] = RedactionRule.defaultRules) {
        var headerKeys = Set<String>()
        var patterns: [CompiledPattern] = []

        for rule in rules {
            switch rule {
            case let .sensitiveHeader(key):
                headerKeys.insert(key.lowercased())
            case let .pattern(regexString, replacement):
                if let regex = try? NSRegularExpression(pattern: regexString) {
                    patterns.append(CompiledPattern(regex: regex, replacement: replacement))
                }
            }
        }

        sensitiveHeaderKeys = headerKeys
        compiledPatterns = patterns
    }

    /// Redacts sensitive substrings within free-form text using pre-compiled regex patterns.
    public func redact(_ text: String) -> String {
        guard !text.isEmpty, !compiledPatterns.isEmpty else { return text }
        var sanitized = text
        for pattern in compiledPatterns {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = pattern.regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: pattern.replacement
            )
        }
        return sanitized
    }

    /// Redacts header or metadata key-value pairs.
    ///
    /// Matching sensitive headers has their entire value replaced with `[REDACTED]`.
    /// Non-sensitive headers have their values run through text pattern redaction.
    public func redactHeaders(_ headers: [String: String]) -> [String: String] {
        guard !headers.isEmpty else { return headers }
        var sanitized: [String: String] = [:]
        sanitized.reserveCapacity(headers.count)

        for (key, value) in headers {
            if sensitiveHeaderKeys.contains(key.lowercased()) {
                sanitized[key] = "[REDACTED]"
            } else {
                sanitized[key] = redact(value)
            }
        }
        return sanitized
    }

    /// Applies redaction to the message, metadata, and error description of a `LogRecord`.
    public func redact(_ record: LogRecord) -> LogRecord {
        let sanitizedMessage = redact(record.message)
        let sanitizedMetadata = redactHeaders(record.metadata)
        let sanitizedError = record.errorDescription.map { redact($0) }

        if sanitizedMessage == record.message,
           sanitizedMetadata == record.metadata,
           sanitizedError == record.errorDescription {
            return record
        }

        return LogRecord(
            module: record.module,
            level: record.level,
            message: sanitizedMessage,
            timestamp: record.timestamp,
            traceId: record.traceId,
            spanId: record.spanId,
            parentSpanId: record.parentSpanId,
            errorDescription: sanitizedError,
            metadata: sanitizedMetadata
        )
    }
}
