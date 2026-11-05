import Foundation

struct TemplatePage: Codable, Hashable {
    var name: String
    var backgroundHex: String = "#F7F8FA"
    var width: Double = 1200
    var height: Double = 820
    var components: [CanvasComponent]
}

struct TemplateQuery: Codable, Hashable {
    var name: String
    var sql: String
    var runOnLoad: Bool = true
    var readOnly: Bool = true
}

struct AppTemplate: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var summary: String
    var category: String
    var icon: String
    var badges: [String] = []
    var isBuiltIn: Bool = false
    var seedSQL: String? = nil
    var pages: [TemplatePage] = []
    var queries: [TemplateQuery] = []
    var state: [String: JSONValue] = [:]
}
