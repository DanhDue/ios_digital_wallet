import Foundation

/// Wire representation of translation overrides from the backend.
struct TranslationOverrideDTO: Codable, Equatable, Sendable {
    let version: String
    let translations: [String: String]
    let mode: String?
    let checksum: String?

    enum CodingKeys: String, CodingKey {
        case version
        case translations
        case changes
        case mode
        case checksum
    }

    init(
        version: String,
        translations: [String: String],
        mode: String? = nil,
        checksum: String? = nil
    ) {
        self.version = version
        self.translations = translations
        self.mode = mode
        self.checksum = checksum
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decode(String.self, forKey: .version)) ?? "1.0.0"
        mode = try? container.decode(String.self, forKey: .mode)
        checksum = try? container.decode(String.self, forKey: .checksum)

        // Support both "translations" and "changes" keys
        if let direct = try? container.decode([String: String].self, forKey: .translations) {
            translations = direct
        } else if let directChanges = try? container.decode([String: String].self, forKey: .changes) {
            translations = directChanges
        } else {
            // Decode arbitrary nested dictionary and flatten it with dot-notation
            var flattened: [String: String] = [:]
            if let rawTranslations = try? container.decode(NestedDictionary.self, forKey: .translations) {
                flattened = rawTranslations.flattened()
            } else if let rawChanges = try? container.decode(NestedDictionary.self, forKey: .changes) {
                flattened = rawChanges.flattened()
            }
            translations = flattened
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(translations, forKey: .translations)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(checksum, forKey: .checksum)
    }
}

/// Helper to decode arbitrary nested JSON dictionaries into flat dot-notation keys.
private enum NestedJSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case dictionary([String: NestedJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let dict = try? container.decode([String: NestedJSONValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }
}

private struct NestedDictionary: Decodable {
    let values: [String: NestedJSONValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: NestedJSONValue].self)
    }

    func flattened() -> [String: String] {
        Self.flatten(values, prefix: "")
    }

    private static func flatten(_ dict: [String: NestedJSONValue], prefix: String) -> [String: String] {
        var result: [String: String] = [:]
        for (dictKey, jsonValue) in dict {
            let key = prefix.isEmpty ? dictKey : "\(prefix).\(dictKey)"
            switch jsonValue {
            case let .string(str):
                result[key] = str
            case let .number(num):
                result[key] = String(num)
            case let .bool(boolValue):
                result[key] = String(boolValue)
            case let .dictionary(nested):
                let sub = flatten(nested, prefix: key)
                result.merge(sub) { _, new in new }
            }
        }
        return result
    }
}
