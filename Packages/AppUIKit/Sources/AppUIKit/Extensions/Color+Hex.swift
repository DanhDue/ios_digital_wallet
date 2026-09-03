import SwiftUI

public extension Color {
    /// Parses a hex color string into an sRGB `Color`.
    ///
    /// Accepted forms:
    /// * `"#RRGGBB"` / `"RRGGBB"` — 6 hex digits, optional leading `#`.
    /// * `"#RGB"` / `"RGB"` — 3 hex digits, each nibble doubled
    ///   (`"#F80"` → `"#FF8800"`).
    ///
    /// Returns `nil` for everything else: non-hex characters, the empty string,
    /// or any other digit count (including the 8-digit `RRGGBBAA` form).
    init?(hex: String) {
        var digits = hex
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }

        guard !digits.isEmpty else {
            return nil
        }

        let isHex = digits.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "0" ... "9", "a" ... "f", "A" ... "F":
                true
            default:
                false
            }
        }
        guard isHex else {
            return nil
        }

        let sixDigits: String
        switch digits.count {
        case 3:
            sixDigits = digits.map { "\($0)\($0)" }.joined()
        case 6:
            sixDigits = digits
        default:
            return nil
        }

        guard let value = UInt32(sixDigits, radix: 16) else {
            return nil
        }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
