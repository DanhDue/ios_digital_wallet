import Foundation

/// Defines a rule for masking sensitive credentials, authorization headers, and PII.
public enum RedactionRule: Sendable, Equatable {
    /// Masks the entire value of metadata matching the specified key (case-insensitive).
    case sensitiveHeader(String)

    /// Masks substrings within message text or unclassified metadata matching a regular expression.
    case pattern(regex: String, replacement: String = "[REDACTED]")

    /// Default set of redaction rules covering financial and authorization data.
    public static var defaultRules: [RedactionRule] {
        [
            .sensitiveHeader("Authorization"),
            .sensitiveHeader("Cookie"),
            .sensitiveHeader("X-API-Key"),
            .sensitiveHeader("Session-Token"),
            // Primary Account Number (PAN): 13 to 19 digits, spaced, hyphenated, or contiguous
            .pattern(
                regex: #"(?:\b\d{4}[ -]\d{4}[ -]\d{4}[ -]\d{1,7}\b|\b\d{13,19}\b)"#,
                replacement: "[REDACTED]"
            ),
            // Bearer token patterns within message bodies
            .pattern(
                regex: #"(?i)\bBearer\s+[A-Za-z0-9_\-\.]+\b"#,
                replacement: "Bearer [REDACTED]"
            ),
        ]
    }
}
