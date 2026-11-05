import Foundation
import JavaScriptCore

struct BindingError: Error, LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

/// Evaluates user-authored JavaScript expressions with an injected context.
/// Expressions can reference `queries`, `state`, `components`, `page`, `app`,
/// plus helper functions such as `formatCurrency` and `sum`.
final class JSEngine {
    private let context: JSContext

    private struct Envelope: Decodable {
        var ok: Bool
        var value: JSONValue?
        var error: String?
    }

    init() {
        context = JSContext()!
        context.exceptionHandler = { _, _ in }
        context.evaluateScript(Self.bootstrap)
    }

    func evaluate(_ expression: String, contextJSON: String, extrasJSON: String? = nil) -> Result<JSONValue, BindingError> {
        let extras = extrasJSON ?? "{}"
        let script = """
        (function() {
          var __ctx = Object.assign({}, \(Self.jsSafe(contextJSON)), \(Self.jsSafe(extras)));
          try {
            with (__ctx) {
              var __value = ( \(expression) );
              return JSON.stringify({ ok: true, value: (__value === undefined ? null : __value) });
            }
          } catch (__error) {
            return JSON.stringify({ ok: false, error: String(__error && __error.message ? __error.message : __error) });
          }
        })()
        """

        guard let value = context.evaluateScript(script),
              let text = value.toString(),
              text != "undefined",
              let data = text.data(using: .utf8) else {
            let message = context.exception?.toString() ?? "Expression could not be evaluated"
            context.exception = nil
            return .failure(BindingError(message: message))
        }

        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return .failure(BindingError(message: "Expression returned an unsupported value"))
        }
        if envelope.ok {
            return .success(envelope.value ?? .null)
        }
        return .failure(BindingError(message: envelope.error ?? "Unknown expression error"))
    }

    private static func jsSafe(_ json: String) -> String {
        json
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    private static let bootstrap = """
    function __foundryDate(value) {
      if (value === null || value === undefined || value === '') { return null; }
      if (value instanceof Date) { return isNaN(value.getTime()) ? null : value; }
      var text = String(value);
      var parsed = new Date(text.indexOf(' ') > 0 && text.indexOf('T') < 0 ? text.replace(' ', 'T') : text);
      return isNaN(parsed.getTime()) ? null : parsed;
    }
    function formatDate(value, options) {
      var date = __foundryDate(value);
      if (!date) { return ''; }
      var base = options || { year: 'numeric', month: 'short', day: 'numeric' };
      return date.toLocaleDateString('en-US', base);
    }
    function formatDateTime(value) {
      var date = __foundryDate(value);
      if (!date) { return ''; }
      return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) + ' · ' +
             date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    }
    function formatCurrency(value) {
      return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(Number(value) || 0);
    }
    function formatNumber(value, digits) {
      var d = (digits === undefined || digits === null) ? 0 : digits;
      return new Intl.NumberFormat('en-US', { minimumFractionDigits: d, maximumFractionDigits: d }).format(Number(value) || 0);
    }
    function formatPercent(value) {
      return (Number(value) || 0).toFixed(0) + '%';
    }
    function sum(array, key) {
      if (!Array.isArray(array)) { return 0; }
      return array.reduce(function(total, item) {
        var raw = (key === undefined || key === null) ? item : (item ? item[key] : 0);
        return total + (Number(raw) || 0);
      }, 0);
    }
    function avg(array, key) {
      if (!Array.isArray(array) || array.length === 0) { return 0; }
      return sum(array, key) / array.length;
    }
    function count(array) { return Array.isArray(array) ? array.length : 0; }
    function unique(array) {
      if (!Array.isArray(array)) { return []; }
      return array.filter(function(value, index) { return array.indexOf(value) === index; });
    }
    function groupBy(array, key) {
      var groups = {};
      (Array.isArray(array) ? array : []).forEach(function(item) {
        var groupKey = key ? item[key] : item;
        if (!groups[groupKey]) { groups[groupKey] = []; }
        groups[groupKey].push(item);
      });
      return Object.keys(groups).map(function(groupKey) {
        return { key: groupKey, items: groups[groupKey], count: groups[groupKey].length };
      });
    }
    function upper(value) { return String(value === null || value === undefined ? '' : value).toUpperCase(); }
    function lower(value) { return String(value === null || value === undefined ? '' : value).toLowerCase(); }
    function titleCase(value) {
      return String(value || '').replace(/\\w\\S*/g, function(word) {
        return word.charAt(0).toUpperCase() + word.substr(1).toLowerCase();
      });
    }
    function round(value, digits) {
      var factor = Math.pow(10, digits || 0);
      return Math.round((Number(value) || 0) * factor) / factor;
    }
    function today() {
      var now = new Date();
      return now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0') + '-' + String(now.getDate()).padStart(2, '0');
    }
    function json(value) { return JSON.stringify(value); }
    var console = { log: function() {}, error: function() {}, warn: function() {} };
    """
}

enum SQLInterpolator {
    static func interpolate(_ sql: String, evaluate: (String) throws -> JSONValue) throws -> String {
        let regex = try NSRegularExpression(pattern: "\\{\\{\\{([\\s\\S]*?)\\}\\}\\}|\\{\\{\\s*([\\s\\S]*?)\\s*\\}\\}")
        let source = sql as NSString
        let matches = regex.matches(in: sql, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return sql }

        var output = ""
        var location = 0
        for match in matches {
            let prefixRange = NSRange(location: location, length: match.range.location - location)
            output += source.substring(with: prefixRange)

            if match.range(at: 1).location != NSNotFound {
                let expression = source.substring(with: match.range(at: 1))
                output += rawLiteral(for: try evaluate(expression))
            } else {
                let expression = source.substring(with: match.range(at: 2))
                output += literal(for: try evaluate(expression))
            }
            location = match.range.location + match.range.length
        }
        output += source.substring(from: location)
        return output
    }

    static func literal(for value: JSONValue) -> String {
        switch value {
        case .null:
            return "NULL"
        case .bool(let flag):
            return flag ? "1" : "0"
        case .number(let number):
            guard number.isFinite else { return "NULL" }
            return JSONValue.formatNumber(number)
        case .string(let text):
            return "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
        case .array(let values):
            return values.map { literal(for: $0) }.joined(separator: ", ")
        case .object:
            return "'" + value.compactJSON.replacingOccurrences(of: "'", with: "''") + "'"
        }
    }

    /// Triple-brace bindings are inserted as raw SQL (identifiers, clauses).
    static func rawLiteral(for value: JSONValue) -> String {
        switch value {
        case .null:
            return ""
        case .string(let text):
            return text
        case .number(let number):
            return JSONValue.formatNumber(number)
        case .bool(let flag):
            return flag ? "1" : "0"
        case .array, .object:
            return value.compactJSON
        }
    }
}
