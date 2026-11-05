import Foundation

/// A Codable, Hashable representation of arbitrary JSON.
enum JSONValue: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            if value.isFinite {
                try container.encode(value)
            } else {
                try container.encodeNil()
            }
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    init(any: Any) {
        switch any {
        case is NSNull:
            self = .null
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .number(Double(value))
        case let value as Int64:
            self = .number(Double(value))
        case let value as Double:
            self = .number(value)
        case let value as Float:
            self = .number(Double(value))
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else {
                self = .number(value.doubleValue)
            }
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            self = .array(value.map { JSONValue(any: $0) })
        case let value as [String: Any]:
            self = .object(value.mapValues { JSONValue(any: $0) })
        default:
            self = .string(String(describing: any))
        }
    }

    var any: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .array(let value): return value.map { $0.any }
        case .object(let value): return value.mapValues { $0.any }
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return JSONValue.formatNumber(value)
        case .bool(let value): return value ? "true" : "false"
        case .null: return ""
        case .array, .object: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .bool(let value): return value ? 1 : 0
        case .string(let value): return Double(value)
        case .null, .array, .object: return nil
        }
    }

    var intValue: Int? {
        guard let value = doubleValue, value.isFinite else { return nil }
        return Int(value)
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .number(let value): return value != 0
        case .string(let value): return ["true", "1", "yes"].contains(value.lowercased())
        case .null: return false
        case .array, .object: return nil
        }
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    subscript(key: String) -> JSONValue? {
        get { objectValue?[key] }
    }

    subscript(index: Int) -> JSONValue? {
        get {
            guard let values = arrayValue, values.indices.contains(index) else { return nil }
            return values[index]
        }
    }

    var display: String {
        switch self {
        case .null: return ""
        case .bool(let value): return value ? "true" : "false"
        case .number(let value): return JSONValue.formatNumber(value)
        case .string(let value): return value
        case .array(let value): return "\(value.count) items"
        case .object(let value):
            return (try? JSONValue.compactString(from: .object(value))) ?? "\(value.count) fields"
        }
    }

    var compactJSON: String {
        (try? JSONValue.compactString(from: self)) ?? ""
    }

    var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    static func compactString(from value: JSONValue) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func parse(_ text: String) -> JSONValue? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    static func formatNumber(_ value: Double) -> String {
        if !value.isFinite { return "0" }
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int64(value))
        }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Numeric, string, boolean comparison used for table sorting.
    static func compare(_ a: JSONValue, _ b: JSONValue) -> ComparisonResult {
        if let x = a.doubleValue, let y = b.doubleValue {
            if x < y { return .orderedAscending }
            if x > y { return .orderedDescending }
            return .orderedSame
        }
        let x = a.stringValue ?? a.display
        let y = b.stringValue ?? b.display
        return x.localizedCaseInsensitiveCompare(y)
    }
}
