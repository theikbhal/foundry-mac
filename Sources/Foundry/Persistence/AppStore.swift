import Foundation

/// Stores apps and templates as JSON in Application Support, plus app-owned
/// SQLite databases under Databases/<app-id>/.
final class AppStore {
    static let shared = AppStore()

    let rootURL: URL
    let appsURL: URL
    let templatesURL: URL
    let databasesURL: URL

    private let fileManager = FileManager.default

    init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        rootURL = base.appendingPathComponent("Foundry", isDirectory: true)
        appsURL = rootURL.appendingPathComponent("Apps", isDirectory: true)
        templatesURL = rootURL.appendingPathComponent("Templates", isDirectory: true)
        databasesURL = rootURL.appendingPathComponent("Databases", isDirectory: true)

        for url in [rootURL, appsURL, templatesURL, databasesURL] {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - Apps

    func listApps() -> [AppDocument] {
        guard let urls = try? fileManager.contentsOfDirectory(at: appsURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var documents: [AppDocument] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let document = try? decoder.decode(AppDocument.self, from: data) else { continue }
            documents.append(document)
        }
        return documents.sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadApp(id: UUID) -> AppDocument? {
        guard let data = try? Data(contentsOf: appURL(id: id)) else { return nil }
        return try? decoder.decode(AppDocument.self, from: data)
    }

    func save(_ document: AppDocument) throws {
        let data = try encoder.encode(document)
        try data.write(to: appURL(id: document.id), options: .atomic)
    }

    func deleteApp(_ document: AppDocument) {
        try? fileManager.removeItem(at: appURL(id: document.id))
        try? fileManager.removeItem(at: databasesURL.appendingPathComponent(document.id.uuidString, isDirectory: true))
    }

    func createBlankApp(name: String = "Untitled app") -> AppDocument {
        var document = AppDocument(name: name)
        document.pages = [AppPage(name: "Page 1")]
        try? save(document)
        return document
    }

    func cloneApp(_ source: AppDocument) -> AppDocument {
        let newID = UUID()
        var copy = source
        copy.id = newID
        copy.name = source.name + " copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()

        copy.pages = source.pages.map { page in
            var newPage = page
            newPage.id = UUID()
            newPage.components = page.components.map { component in
                var newComponent = component
                newComponent.id = UUID()
                return newComponent
            }
            return newPage
        }

        let sourceDirectory = databasesURL.appendingPathComponent(source.id.uuidString, isDirectory: true)
        let newDirectory = databasesURL.appendingPathComponent(newID.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: sourceDirectory.path) {
            try? fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
            if let items = try? fileManager.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil) {
                for item in items {
                    try? fileManager.copyItem(at: item, to: newDirectory.appendingPathComponent(item.lastPathComponent))
                }
            }
        }

        var connectionMap: [UUID: UUID] = [:]
        copy.connections = source.connections.map { connection in
            var newConnection = connection
            newConnection.id = UUID()
            if connection.path.hasPrefix(sourceDirectory.path) {
                newConnection.path = connection.path.replacingOccurrences(of: sourceDirectory.path, with: newDirectory.path)
            }
            connectionMap[connection.id] = newConnection.id
            return newConnection
        }

        copy.queries = source.queries.map { query in
            var newQuery = query
            newQuery.id = UUID()
            newQuery.connectionId = query.connectionId.flatMap { connectionMap[$0] }
            return newQuery
        }

        try? save(copy)
        return copy
    }

    // MARK: - Templates

    func instantiate(_ template: AppTemplate, name: String? = nil) -> AppDocument {
        let newID = UUID()
        var document = AppDocument(id: newID, name: name ?? template.name)
        document.createdAt = Date()
        document.updatedAt = Date()

        var connection: AppConnection? = nil
        if let seedSQL = template.seedSQL, !seedSQL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let directory = databasesURL.appendingPathComponent(newID.uuidString, isDirectory: true)
            let path = directory.appendingPathComponent("data.sqlite").path
            do {
                try SQLiteEngine.createDatabase(at: path, seedSQL: seedSQL)
                let newConnection = AppConnection(name: "Sample Database", path: path)
                connection = newConnection
                document.connections = [newConnection]
            } catch {
                NSLog("Foundry: failed to create template database: \(error.localizedDescription)")
            }
        }

        document.pages = template.pages.map { templatePage in
            var page = AppPage(name: templatePage.name)
            page.backgroundHex = templatePage.backgroundHex
            page.width = templatePage.width
            page.height = templatePage.height
            page.components = templatePage.components.map { component in
                var copy = component
                copy.id = UUID()
                return copy
            }
            return page
        }
        if document.pages.isEmpty {
            document.pages = [AppPage(name: "Page 1")]
        }

        var usedNames = Set<String>()
        document.queries = template.queries.map { templateQuery in
            var name = templateQuery.name
            var counter = 2
            while usedNames.contains(name) {
                name = "\(templateQuery.name)\(counter)"
                counter += 1
            }
            usedNames.insert(name)
            return AppQuery(
                name: name,
                connectionId: connection?.id,
                sql: templateQuery.sql,
                runOnLoad: templateQuery.runOnLoad,
                readOnly: templateQuery.readOnly
            )
        }

        document.state = template.state
        try? save(document)
        return document
    }

    func listUserTemplates() -> [AppTemplate] {
        guard let urls = try? fileManager.contentsOfDirectory(at: templatesURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var templates: [AppTemplate] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  var template = try? decoder.decode(AppTemplate.self, from: data) else { continue }
            template.isBuiltIn = false
            templates.append(template)
        }
        return templates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func saveUserTemplate(_ template: AppTemplate) throws {
        let data = try encoder.encode(template)
        try data.write(to: templateURL(id: template.id), options: .atomic)
    }

    func deleteUserTemplate(id: String) {
        try? fileManager.removeItem(at: templateURL(id: id))
    }

    func forkTemplate(_ template: AppTemplate) -> AppTemplate {
        var copy = template
        copy.id = UUID().uuidString
        copy.name = template.name + " (fork)"
        copy.isBuiltIn = false
        copy.category = "My templates"
        if copy.badges.isEmpty {
            copy.badges = ["Forked"]
        }
        try? saveUserTemplate(copy)
        return copy
    }

    func exportTemplate(_ template: AppTemplate, to url: URL) throws {
        let data = try encoder.encode(template)
        try data.write(to: url, options: .atomic)
    }

    func importTemplate(from url: URL) throws -> AppTemplate {
        let data = try Data(contentsOf: url)
        var template = try decoder.decode(AppTemplate.self, from: data)
        template.id = UUID().uuidString
        template.isBuiltIn = false
        if template.category.isEmpty { template.category = "Imported" }
        if template.icon.isEmpty { template.icon = "shippingbox" }
        try saveUserTemplate(template)
        return template
    }

    func makeTemplate(from document: AppDocument, name: String? = nil, includeData: Bool = true) -> AppTemplate {
        var seedSQL: String? = nil
        if let connection = document.connections.first, fileManager.fileExists(atPath: connection.path) {
            seedSQL = try? SQLiteEngine.dump(at: connection.path, includeData: includeData)
        }

        return AppTemplate(
            id: UUID().uuidString,
            name: name ?? (document.name + " Template"),
            summary: "Exported from \(document.name) · \(document.pages.count) page\(document.pages.count == 1 ? "" : "s")",
            category: "My templates",
            icon: "shippingbox",
            badges: ["Exported"],
            isBuiltIn: false,
            seedSQL: seedSQL,
            pages: document.pages.map { page in
                TemplatePage(
                    name: page.name,
                    backgroundHex: page.backgroundHex,
                    width: page.width,
                    height: page.height,
                    components: page.components
                )
            },
            queries: document.queries.map { query in
                TemplateQuery(name: query.name, sql: query.sql, runOnLoad: query.runOnLoad, readOnly: query.readOnly)
            },
            state: document.state
        )
    }

    // MARK: - Paths

    func appURL(id: UUID) -> URL {
        appsURL.appendingPathComponent("\(id.uuidString).json")
    }

    private func templateURL(id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "-")
        return templatesURL.appendingPathComponent("\(safe).json")
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
