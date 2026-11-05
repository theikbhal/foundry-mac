import Foundation
import CoreGraphics

// MARK: - Prop values & actions

enum PropValue: Codable, Hashable {
    case literal(JSONValue)
    case binding(String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        if kind == "binding" {
            self = .binding(try container.decode(String.self, forKey: .value))
        } else {
            self = .literal(try container.decode(JSONValue.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .literal(let value):
            try container.encode("literal", forKey: .kind)
            try container.encode(value, forKey: .value)
        case .binding(let expression):
            try container.encode("binding", forKey: .kind)
            try container.encode(expression, forKey: .value)
        }
    }

    var literalValue: JSONValue? {
        if case .literal(let value) = self { return value }
        return nil
    }

    var bindingExpression: String? {
        if case .binding(let expression) = self { return expression }
        return nil
    }

    var isBinding: Bool { bindingExpression != nil }

    var displayText: String {
        switch self {
        case .literal(let value): return value.display
        case .binding(let expression): return "{{ \(expression) }}"
        }
    }

    static func text(_ value: String) -> PropValue { .literal(.string(value)) }
    static func num(_ value: Double) -> PropValue { .literal(.number(value)) }
    static func flag(_ value: Bool) -> PropValue { .literal(.bool(value)) }
    static func json(_ value: JSONValue) -> PropValue { .literal(value) }
    static func fx(_ expression: String) -> PropValue { .binding(expression) }
}

enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case runQuery
    case setState
    case setComponentValue
    case showToast
    case openURL
    case navigate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .runQuery: return "Run query"
        case .setState: return "Set app state"
        case .setComponentValue: return "Set component value"
        case .showToast: return "Show toast"
        case .openURL: return "Open URL"
        case .navigate: return "Go to page"
        }
    }

    var icon: String {
        switch self {
        case .runQuery: return "bolt.fill"
        case .setState: return "slider.horizontal.3"
        case .setComponentValue: return "character.cursor.ibeam"
        case .showToast: return "checkmark.circle"
        case .openURL: return "arrow.up.right.square"
        case .navigate: return "arrow.right.square"
        }
    }

    var targetLabel: String {
        switch self {
        case .runQuery: return "Query"
        case .setState: return "State key"
        case .setComponentValue: return "Component"
        case .showToast: return "Message"
        case .openURL: return "URL"
        case .navigate: return "Page"
        }
    }

    var usesValue: Bool {
        self == .setState || self == .setComponentValue
    }
}

struct AppAction: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var kind: ActionKind
    var target: String = ""
    var value: PropValue? = nil

    static func run(_ query: String) -> AppAction {
        AppAction(kind: .runQuery, target: query)
    }

    static func state(_ key: String, _ value: PropValue) -> AppAction {
        AppAction(kind: .setState, target: key, value: value)
    }

    static func setValue(component: String, _ value: PropValue) -> AppAction {
        AppAction(kind: .setComponentValue, target: component, value: value)
    }

    static func toast(_ message: String) -> AppAction {
        AppAction(kind: .showToast, target: message)
    }

    static func navigate(_ page: String) -> AppAction {
        AppAction(kind: .navigate, target: page)
    }
}

// MARK: - Components

enum ComponentType: String, Codable, CaseIterable, Identifiable {
    case heading
    case text
    case button
    case textInput
    case numberInput
    case select
    case table
    case stat
    case chart
    case divider
    case panel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heading: return "Heading"
        case .text: return "Text"
        case .button: return "Button"
        case .textInput: return "Text input"
        case .numberInput: return "Number input"
        case .select: return "Select"
        case .table: return "Table"
        case .stat: return "Stat"
        case .chart: return "Chart"
        case .divider: return "Divider"
        case .panel: return "Panel"
        }
    }

    var icon: String {
        switch self {
        case .heading: return "textformat.size"
        case .text: return "text.alignleft"
        case .button: return "cursorarrow.click.2"
        case .textInput: return "character.cursor.ibeam"
        case .numberInput: return "number.square"
        case .select: return "chevron.up.chevron.down.square"
        case .table: return "tablecells"
        case .stat: return "chart.bar.xaxis"
        case .chart: return "chart.xyaxis.line"
        case .divider: return "minus"
        case .panel: return "rectangle.on.rectangle"
        }
    }

    var blurb: String {
        switch self {
        case .heading: return "Section title"
        case .text: return "Rich label text"
        case .button: return "Trigger actions"
        case .textInput: return "String field"
        case .numberInput: return "Numeric field"
        case .select: return "Dropdown"
        case .table: return "Rows with search + sort"
        case .stat: return "Headline metric"
        case .chart: return "Bar or line chart"
        case .divider: return "Horizontal rule"
        case .panel: return "Card surface for layouts"
        }
    }

    var category: String {
        switch self {
        case .heading, .text, .divider: return "Content"
        case .button, .textInput, .numberInput, .select: return "Inputs"
        case .table, .stat, .chart: return "Data"
        case .panel: return "Layout"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .heading: return CGSize(width: 420, height: 48)
        case .text: return CGSize(width: 420, height: 32)
        case .button: return CGSize(width: 150, height: 38)
        case .textInput: return CGSize(width: 260, height: 64)
        case .numberInput: return CGSize(width: 260, height: 64)
        case .select: return CGSize(width: 260, height: 64)
        case .table: return CGSize(width: 680, height: 420)
        case .stat: return CGSize(width: 230, height: 110)
        case .chart: return CGSize(width: 500, height: 300)
        case .divider: return CGSize(width: 420, height: 16)
        case .panel: return CGSize(width: 360, height: 480)
        }
    }
}

struct CanvasComponent: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: ComponentType
    var name: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var props: [String: PropValue] = [:]
    var events: [String: [AppAction]] = [:]
    var hidden: Bool = false
    var locked: Bool = false

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    func prop(_ key: String) -> PropValue? { props[key] }

    func actions(for event: String) -> [AppAction] { events[event] ?? [] }
}

struct AppPage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var backgroundHex: String = "#F7F8FA"
    var width: Double = 1200
    var height: Double = 820
    var components: [CanvasComponent] = []

    func component(named name: String) -> CanvasComponent? {
        components.first { $0.name == name }
    }
}

struct AppQuery: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var connectionId: UUID?
    var sql: String
    var runOnLoad: Bool = true
    var readOnly: Bool = true
}

struct AppConnection: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var readOnly: Bool = false
}

struct AppDocument: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var pages: [AppPage] = [AppPage(name: "Page 1")]
    var queries: [AppQuery] = []
    var connections: [AppConnection] = []
    var state: [String: JSONValue] = [:]

    func page(id: UUID) -> AppPage? {
        pages.first { $0.id == id }
    }

    func pageIndex(id: UUID) -> Int? {
        pages.firstIndex { $0.id == id }
    }

    func query(named name: String) -> AppQuery? {
        queries.first { $0.name == name }
    }

    func query(id: UUID) -> AppQuery? {
        queries.first { $0.id == id }
    }

    func component(named name: String) -> CanvasComponent? {
        for page in pages {
            if let component = page.component(named: name) { return component }
        }
        return nil
    }

    func uniqueComponentName(_ base: String, in page: AppPage) -> String {
        var candidate = base
        var counter = 2
        let existing = Set(page.components.map { $0.name })
        while existing.contains(candidate) {
            candidate = "\(base)\(counter)"
            counter += 1
        }
        return candidate
    }

    func uniqueQueryName(_ base: String) -> String {
        var candidate = base
        var counter = 2
        let existing = Set(queries.map { $0.name })
        while existing.contains(candidate) {
            candidate = "\(base)\(counter)"
            counter += 1
        }
        return candidate
    }

    func uniquePageName(_ base: String) -> String {
        var candidate = base
        var counter = 2
        let existing = Set(pages.map { $0.name })
        while existing.contains(candidate) {
            candidate = "\(base) \(counter)"
            counter += 1
        }
        return candidate
    }

    func connection(id: UUID?) -> AppConnection? {
        guard let id else { return nil }
        return connections.first { $0.id == id }
    }
}
