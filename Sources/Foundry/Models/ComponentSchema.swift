import Foundation

struct ChoiceOption: Identifiable, Hashable {
    var label: String
    var value: String
    var id: String { value }
}

enum PropKind {
    case text
    case longText
    case number
    case boolean
    case color
    case choice([ChoiceOption])
}

struct PropSpec: Identifiable {
    var key: String
    var label: String
    var kind: PropKind
    var defaultValue: PropValue
    var hint: String? = nil
    var id: String { key }
}

struct EventSpec: Identifiable {
    var key: String
    var label: String
    var id: String { key }
}

enum ComponentSchema {
    private static func options(_ pairs: [(String, String)]) -> [ChoiceOption] {
        pairs.map { ChoiceOption(label: $0.0, value: $0.1) }
    }

    static func events(for type: ComponentType) -> [EventSpec] {
        switch type {
        case .button:
            return [EventSpec(key: "onClick", label: "On click")]
        case .textInput, .numberInput:
            return [EventSpec(key: "onSubmit", label: "On submit")]
        case .select:
            return [EventSpec(key: "onChange", label: "On change")]
        case .table:
            return [EventSpec(key: "onRowClick", label: "On row click")]
        default:
            return []
        }
    }

    static func specs(for type: ComponentType) -> [PropSpec] {
        switch type {
        case .heading:
            return [
                PropSpec(key: "text", label: "Text", kind: .text, defaultValue: .text("Heading")),
                PropSpec(key: "size", label: "Font size", kind: .number, defaultValue: .num(30)),
                PropSpec(key: "weight", label: "Weight", kind: .choice(options([("Regular", "regular"), ("Medium", "medium"), ("Semibold", "semibold"), ("Bold", "bold")])), defaultValue: .text("semibold")),
                PropSpec(key: "color", label: "Color", kind: .color, defaultValue: .text("#111827")),
                PropSpec(key: "align", label: "Alignment", kind: .choice(options([("Left", "left"), ("Center", "center"), ("Right", "right")])), defaultValue: .text("left"))
            ]
        case .text:
            return [
                PropSpec(key: "content", label: "Content", kind: .longText, defaultValue: .text("Supporting copy goes here.")),
                PropSpec(key: "size", label: "Font size", kind: .number, defaultValue: .num(14)),
                PropSpec(key: "color", label: "Color", kind: .color, defaultValue: .text("#4B5563")),
                PropSpec(key: "align", label: "Alignment", kind: .choice(options([("Left", "left"), ("Center", "center"), ("Right", "right")])), defaultValue: .text("left"))
            ]
        case .button:
            return [
                PropSpec(key: "label", label: "Label", kind: .text, defaultValue: .text("Button")),
                PropSpec(key: "style", label: "Style", kind: .choice(options([("Primary", "primary"), ("Secondary", "secondary"), ("Ghost", "ghost"), ("Danger", "danger")])), defaultValue: .text("primary")),
                PropSpec(key: "icon", label: "SF Symbol", kind: .text, defaultValue: .text(""), hint: "Optional SF Symbol name, e.g. plus"),
                PropSpec(key: "disabled", label: "Disabled", kind: .boolean, defaultValue: .flag(false))
            ]
        case .textInput:
            return [
                PropSpec(key: "label", label: "Label", kind: .text, defaultValue: .text("Label")),
                PropSpec(key: "placeholder", label: "Placeholder", kind: .text, defaultValue: .text("Type something…")),
                PropSpec(key: "defaultValue", label: "Default value", kind: .text, defaultValue: .text(""), hint: "Supports {{ expressions }} and state bindings"),
                PropSpec(key: "helper", label: "Helper text", kind: .text, defaultValue: .text(""))
            ]
        case .numberInput:
            return [
                PropSpec(key: "label", label: "Label", kind: .text, defaultValue: .text("Amount")),
                PropSpec(key: "placeholder", label: "Placeholder", kind: .text, defaultValue: .text("0")),
                PropSpec(key: "defaultValue", label: "Default value", kind: .text, defaultValue: .text("")),
                PropSpec(key: "helper", label: "Helper text", kind: .text, defaultValue: .text(""))
            ]
        case .select:
            return [
                PropSpec(key: "label", label: "Label", kind: .text, defaultValue: .text("Select")),
                PropSpec(key: "options", label: "Options", kind: .longText, defaultValue: .json(.array([
                    .object(["label": .string("Option A"), "value": .string("a")]),
                    .object(["label": .string("Option B"), "value": .string("b")])
                ])), hint: "Array of {label, value} objects"),
                PropSpec(key: "defaultValue", label: "Default value", kind: .text, defaultValue: .text("a")),
                PropSpec(key: "helper", label: "Helper text", kind: .text, defaultValue: .text(""))
            ]
        case .table:
            return [
                PropSpec(key: "title", label: "Title", kind: .text, defaultValue: .text("")),
                PropSpec(key: "data", label: "Data", kind: .longText, defaultValue: .json(.array([])), hint: "Expression resolving to an array of objects"),
                PropSpec(key: "columns", label: "Columns", kind: .text, defaultValue: .text(""), hint: "Comma-separated keys; empty = infer from data"),
                PropSpec(key: "searchable", label: "Searchable", kind: .boolean, defaultValue: .flag(true)),
                PropSpec(key: "sortable", label: "Sortable", kind: .boolean, defaultValue: .flag(true)),
                PropSpec(key: "paginate", label: "Paginate", kind: .boolean, defaultValue: .flag(true)),
                PropSpec(key: "pageSize", label: "Rows per page", kind: .number, defaultValue: .num(8)),
                PropSpec(key: "striped", label: "Striped rows", kind: .boolean, defaultValue: .flag(true)),
                PropSpec(key: "emptyMessage", label: "Empty message", kind: .text, defaultValue: .text("No rows to display"))
            ]
        case .stat:
            return [
                PropSpec(key: "label", label: "Label", kind: .text, defaultValue: .text("Metric")),
                PropSpec(key: "value", label: "Value", kind: .text, defaultValue: .text("0")),
                PropSpec(key: "delta", label: "Delta", kind: .text, defaultValue: .text("")),
                PropSpec(key: "accent", label: "Accent", kind: .color, defaultValue: .text("#6366F1"))
            ]
        case .chart:
            return [
                PropSpec(key: "title", label: "Title", kind: .text, defaultValue: .text("")),
                PropSpec(key: "data", label: "Data", kind: .longText, defaultValue: .json(.array([])), hint: "Array of objects with x and y keys"),
                PropSpec(key: "xKey", label: "X key", kind: .text, defaultValue: .text("label")),
                PropSpec(key: "yKey", label: "Y key", kind: .text, defaultValue: .text("value")),
                PropSpec(key: "chartType", label: "Type", kind: .choice(options([("Bar", "bar"), ("Line", "line"), ("Area", "area")])), defaultValue: .text("bar")),
                PropSpec(key: "accent", label: "Accent", kind: .color, defaultValue: .text("#6366F1")),
                PropSpec(key: "showGrid", label: "Gridlines", kind: .boolean, defaultValue: .flag(true))
            ]
        case .divider:
            return [
                PropSpec(key: "color", label: "Color", kind: .color, defaultValue: .text("#E5E7EB"))
            ]
        case .panel:
            return [
                PropSpec(key: "title", label: "Title", kind: .text, defaultValue: .text("Panel")),
                PropSpec(key: "subtitle", label: "Subtitle", kind: .text, defaultValue: .text("")),
                PropSpec(key: "background", label: "Background", kind: .color, defaultValue: .text("#FFFFFF")),
                PropSpec(key: "border", label: "Border", kind: .boolean, defaultValue: .flag(true)),
                PropSpec(key: "radius", label: "Corner radius", kind: .number, defaultValue: .num(14))
            ]
        }
    }

    static func defaults(for type: ComponentType) -> [String: PropValue] {
        var result: [String: PropValue] = [:]
        for spec in specs(for: type) {
            result[spec.key] = spec.defaultValue
        }
        return result
    }

    static func defaultName(for type: ComponentType) -> String {
        switch type {
        case .heading: return "heading"
        case .text: return "text"
        case .button: return "button"
        case .textInput: return "textInput"
        case .numberInput: return "numberInput"
        case .select: return "select"
        case .table: return "table"
        case .stat: return "stat"
        case .chart: return "chart"
        case .divider: return "divider"
        case .panel: return "panel"
        }
    }

    static func makeComponent(
        type: ComponentType,
        name: String,
        x: Double,
        y: Double,
        width: Double? = nil,
        height: Double? = nil,
        props: [String: PropValue] = [:],
        events: [String: [AppAction]] = [:]
    ) -> CanvasComponent {
        var merged = defaults(for: type)
        for (key, value) in props {
            merged[key] = value
        }
        return CanvasComponent(
            type: type,
            name: name,
            x: x,
            y: y,
            width: width ?? type.defaultSize.width,
            height: height ?? type.defaultSize.height,
            props: merged,
            events: events
        )
    }
}
