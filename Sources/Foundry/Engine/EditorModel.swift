import Foundation
import AppKit
import CoreGraphics

enum SidebarTab: String, CaseIterable, Identifiable {
    case components
    case layers
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .components: return "Components"
        case .layers: return "Layers"
        case .data: return "Data"
        }
    }

    var icon: String {
        switch self {
        case .components: return "square.grid.2x2"
        case .layers: return "square.3.layers.3d"
        case .data: return "cylinder.split.1x2"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    enum Kind {
        case info
        case success
        case error
    }

    let id = UUID()
    var text: String
    var kind: Kind = .success
}

struct TableComputation {
    var allRows: [JSONValue] = []
    var pageRows: [JSONValue] = []
    var columns: [String] = []
    var page: Int = 1
    var pageCount: Int = 1
    var totalRows: Int = 0
    var rangeStart: Int = 0
    var rangeEnd: Int = 0
    var paginated: Bool = true
}

@MainActor
final class EditorModel: ObservableObject {
    @Published var document: AppDocument
    @Published var selectedPageID: UUID
    @Published var selectedComponentID: UUID?
    @Published var selectedQueryID: UUID?
    @Published var isPreview = false
    @Published var sidebarTab: SidebarTab = .components
    @Published var toast: ToastMessage?
    @Published var schemaByConnection: [UUID: [SQLiteTable]] = [:]
    @Published var schemaLoading: Set<UUID> = []
    @Published var selectedConnectionID: UUID?
    @Published var lastSavedAt: Date?
    @Published var isDropTargeted = false

    let runtime = AppRuntime()
    let store: AppStore

    private let jsEngine = JSEngine()
    private var saveTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var started = false

    init(document: AppDocument, store: AppStore) {
        self.document = document
        self.store = store
        self.selectedPageID = document.pages.first?.id ?? UUID()
        self.selectedConnectionID = document.connections.first?.id
        runtime.appState = document.state
        lastSavedAt = document.updatedAt
        for query in document.queries {
            runtime.queryStates[query.name] = QueryRuntimeState()
        }
    }

    deinit {
        saveTask?.cancel()
        toastTask?.cancel()
    }

    // MARK: - Lifecycle

    func start() async {
        guard !started else { return }
        started = true
        seedComponentValues()
        refreshAllSchemas()
        await runOnLoadQueries()
    }

    /// Input components fall back to their configured default until the user
    /// touches them. Seeding those defaults into runtime state keeps on-load
    /// queries from binding `NULL` before the first interaction.
    private func seedComponentValues() {
        let inputTypes: Set<ComponentType> = [.textInput, .numberInput, .select]
        for page in document.pages {
            for component in page.components where inputTypes.contains(component.type) {
                guard runtime.componentValues[component.name] == nil else { continue }
                let spec = ComponentSchema.specs(for: component.type).first { $0.key == "defaultValue" }
                guard let prop = component.props["defaultValue"] ?? spec?.defaultValue else { continue }
                switch prop {
                case .literal(let value):
                    runtime.componentValues[component.name] = value
                case .binding(let expression):
                    switch jsEngine.evaluate(expression, contextJSON: contextJSON()) {
                    case .success(let value):
                        runtime.componentValues[component.name] = value
                    case .failure:
                        if let fallback = spec?.defaultValue.literalValue {
                            runtime.componentValues[component.name] = fallback
                        }
                    }
                }
            }
        }
        runtime.invalidate()
    }

    func flush() {
        saveTask?.cancel()
        persistNow()
    }

    private func persistNow() {
        do {
            try store.save(document)
            lastSavedAt = Date()
        } catch {
            showToast("Could not save app: \(error.localizedDescription)", kind: .error)
        }
    }

    private func scheduleSave() {
        document.updatedAt = Date()
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self else { return }
            self.persistNow()
        }
    }

    func touch() {
        runtime.invalidate()
        objectWillChange.send()
    }

    func commit() {
        touch()
        scheduleSave()
    }

    func showToast(_ text: String, kind: ToastMessage.Kind = .success) {
        toast = ToastMessage(text: text, kind: kind)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - Selection & derived state

    var activePageID: UUID {
        if document.pages.contains(where: { $0.id == selectedPageID }) {
            return selectedPageID
        }
        return document.pages.first?.id ?? selectedPageID
    }

    var currentPage: AppPage? {
        document.page(id: activePageID) ?? document.pages.first
    }

    var selectedComponent: CanvasComponent? {
        guard let id = selectedComponentID, let page = currentPage else { return nil }
        return page.components.first { $0.id == id }
    }

    var selectedQuery: AppQuery? {
        guard let id = selectedQueryID else { return nil }
        return document.queries.first { $0.id == id }
    }

    var activeConnection: AppConnection? {
        if let selectedConnectionID, let connection = document.connections.first(where: { $0.id == selectedConnectionID }) {
            return connection
        }
        return document.connections.first
    }

    func schema(for connectionID: UUID?) -> [SQLiteTable] {
        guard let connectionID else { return [] }
        return schemaByConnection[connectionID] ?? []
    }

    func connectionName(id: UUID?) -> String {
        guard let connection = document.connection(id: id) else { return "No connection" }
        return connection.name
    }

    // MARK: - Bindings

    func contextJSON() -> String {
        runtime.contextJSON(document: document, pageID: activePageID)
    }

    func resolveBinding(_ expression: String) -> Result<JSONValue, BindingError> {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .success(.null) }
        return jsEngine.evaluate(trimmed, contextJSON: contextJSON())
    }

    func value(_ component: CanvasComponent, _ key: String) -> JSONValue {
        let spec = ComponentSchema.specs(for: component.type).first { $0.key == key }
        guard let prop = component.props[key] ?? spec?.defaultValue else { return .null }
        switch prop {
        case .literal(let value):
            return value
        case .binding(let expression):
            switch resolveBinding(expression) {
            case .success(let value):
                return value
            case .failure:
                return spec?.defaultValue.literalValue ?? .null
            }
        }
    }

    func stringValue(_ component: CanvasComponent, _ key: String, fallback: String = "") -> String {
        value(component, key).stringValue ?? fallback
    }

    func doubleValue(_ component: CanvasComponent, _ key: String) -> Double {
        value(component, key).doubleValue ?? 0
    }

    func intValue(_ component: CanvasComponent, _ key: String) -> Int {
        value(component, key).intValue ?? 0
    }

    func boolValue(_ component: CanvasComponent, _ key: String) -> Bool {
        value(component, key).boolValue ?? false
    }

    func bindingPreview(_ expression: String) -> Result<JSONValue, BindingError> {
        resolveBinding(expression)
    }

    // MARK: - Component mutations

    func selectComponent(_ id: UUID?) {
        selectedComponentID = id
        if id != nil {
            sidebarTab = sidebarTab == .components ? .layers : sidebarTab
        }
    }

    func addComponent(_ type: ComponentType, centeredAt point: CGPoint? = nil) {
        guard let pageIndex = document.pageIndex(id: activePageID) else { return }
        let page = document.pages[pageIndex]
        let size = type.defaultSize

        var x: Double
        var y: Double
        if let point {
            x = Double(point.x) - Double(size.width) / 2
            y = Double(point.y) - Double(size.height) / 2
        } else {
            let offset = Double(page.components.count % 8) * 24
            x = 64 + offset
            y = 64 + offset
        }
        x = min(max(8, snap(x)), max(8, page.width - Double(size.width) - 8))
        y = min(max(8, snap(y)), max(8, page.height - Double(size.height) - 8))

        let name = document.uniqueComponentName(ComponentSchema.defaultName(for: type), in: page)
        let component = ComponentSchema.makeComponent(type: type, name: name, x: x, y: y)
        document.pages[pageIndex].components.append(component)
        selectedComponentID = component.id
        commit()
        showToast("Added \(type.title)", kind: .info)
    }

    func updateComponent(_ id: UUID, _ body: (inout CanvasComponent) -> Void) {
        guard let pageIndex = document.pageIndex(id: activePageID),
              let componentIndex = document.pages[pageIndex].components.firstIndex(where: { $0.id == id }) else { return }
        body(&document.pages[pageIndex].components[componentIndex])
        commit()
    }

    func deleteComponent(_ id: UUID) {
        guard let pageIndex = document.pageIndex(id: activePageID),
              let componentIndex = document.pages[pageIndex].components.firstIndex(where: { $0.id == id }) else { return }
        document.pages[pageIndex].components.remove(at: componentIndex)
        if selectedComponentID == id { selectedComponentID = nil }
        commit()
    }

    func duplicateComponent(_ id: UUID) {
        guard let pageIndex = document.pageIndex(id: activePageID),
              let component = document.pages[pageIndex].components.first(where: { $0.id == id }) else { return }
        let page = document.pages[pageIndex]
        var copy = component
        copy.id = UUID()
        copy.name = document.uniqueComponentName(component.name, in: page)
        copy.x = min(page.width - copy.width - 8, copy.x + 24)
        copy.y = min(page.height - copy.height - 8, copy.y + 24)
        document.pages[pageIndex].components.append(copy)
        selectedComponentID = copy.id
        commit()
    }

    func renameComponent(_ id: UUID, to rawName: String) {
        let name = Self.sanitizedIdentifier(rawName)
        guard let pageIndex = document.pageIndex(id: activePageID),
              let componentIndex = document.pages[pageIndex].components.firstIndex(where: { $0.id == id }) else { return }
        let page = document.pages[pageIndex]
        let current = page.components[componentIndex].name
        guard name != current else { return }
        let unique = document.uniqueComponentName(name, in: page)
        document.pages[pageIndex].components[componentIndex].name = unique
        if let value = runtime.componentValues.removeValue(forKey: current) {
            runtime.componentValues[unique] = value
        }
        if let tableState = runtime.tableStates.removeValue(forKey: current) {
            runtime.tableStates[unique] = tableState
        }
        commit()
    }

    func bringToFront(_ id: UUID) {
        guard let pageIndex = document.pageIndex(id: activePageID),
              let componentIndex = document.pages[pageIndex].components.firstIndex(where: { $0.id == id }) else { return }
        let component = document.pages[pageIndex].components.remove(at: componentIndex)
        document.pages[pageIndex].components.append(component)
        commit()
    }

    func sendToBack(_ id: UUID) {
        guard let pageIndex = document.pageIndex(id: activePageID),
              let componentIndex = document.pages[pageIndex].components.firstIndex(where: { $0.id == id }) else { return }
        let component = document.pages[pageIndex].components.remove(at: componentIndex)
        document.pages[pageIndex].components.insert(component, at: 0)
        commit()
    }

    func toggleHidden(_ id: UUID) {
        updateComponent(id) { $0.hidden.toggle() }
    }

    func toggleLocked(_ id: UUID) {
        updateComponent(id) { $0.locked.toggle() }
    }

    func setProp(componentID: UUID, key: String, value: PropValue) {
        updateComponent(componentID) { $0.props[key] = value }
    }

    func setActions(componentID: UUID, event: String, actions: [AppAction]) {
        updateComponent(componentID) { $0.events[event] = actions }
    }

    // MARK: - Pages

    func selectPage(_ id: UUID) {
        guard document.pages.contains(where: { $0.id == id }) else { return }
        selectedPageID = id
        selectedComponentID = nil
        touch()
    }

    func addPage() {
        let page = AppPage(name: document.uniquePageName("Page \(document.pages.count + 1)"))
        document.pages.append(page)
        selectedPageID = page.id
        selectedComponentID = nil
        commit()
    }

    func deletePage(_ id: UUID) {
        guard document.pages.count > 1 else {
            showToast("An app needs at least one page", kind: .error)
            return
        }
        document.pages.removeAll { $0.id == id }
        if selectedPageID == id, let first = document.pages.first {
            selectedPageID = first.id
            selectedComponentID = nil
        }
        commit()
    }

    func renamePage(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = document.pageIndex(id: id) else { return }
        document.pages[index].name = trimmed
        commit()
    }

    func updatePageSettings(background: String? = nil, width: Double? = nil, height: Double? = nil) {
        guard let index = document.pageIndex(id: activePageID) else { return }
        if let background { document.pages[index].backgroundHex = background }
        if let width { document.pages[index].width = max(400, width) }
        if let height { document.pages[index].height = max(400, height) }
        commit()
    }

    func renameApp(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        document.name = trimmed
        commit()
    }

    // MARK: - App state

    func setStateValue(key rawKey: String, value: JSONValue) {
        let key = Self.sanitizedIdentifier(rawKey)
        runtime.appState[key] = value
        document.state[key] = value
        commit()
    }

    func removeStateValue(key: String) {
        runtime.appState.removeValue(forKey: key)
        document.state.removeValue(forKey: key)
        commit()
    }

    func addStateKey() -> String {
        var index = 1
        var key = "value1"
        while document.state[key] != nil || runtime.appState[key] != nil {
            index += 1
            key = "value\(index)"
        }
        runtime.appState[key] = .null
        document.state[key] = .null
        commit()
        return key
    }

    // MARK: - Queries

    @discardableResult
    func addQuery(table: String? = nil, connectionID: UUID? = nil) -> AppQuery {
        let connection = connectionID ?? selectedConnectionID ?? document.connections.first?.id
        let baseName: String
        if let table {
            baseName = Self.sanitizedIdentifier("get_" + table)
        } else {
            baseName = "query\(document.queries.count + 1)"
        }
        let name = document.uniqueQueryName(baseName)
        let sql: String
        if let table {
            sql = "SELECT * FROM \(SQLiteEngine.quoteIdentifier(table)) LIMIT 100;"
        } else {
            sql = "SELECT name, type FROM sqlite_master WHERE type = 'table' ORDER BY name;"
        }
        let query = AppQuery(name: name, connectionId: connection, sql: sql, runOnLoad: false, readOnly: true)
        document.queries.append(query)
        runtime.queryStates[name] = QueryRuntimeState()
        selectedQueryID = query.id
        sidebarTab = .data
        commit()
        return query
    }

    func deleteQuery(_ id: UUID) {
        guard let index = document.queries.firstIndex(where: { $0.id == id }) else { return }
        let name = document.queries[index].name
        document.queries.remove(at: index)
        runtime.queryStates.removeValue(forKey: name)
        if selectedQueryID == id { selectedQueryID = nil }
        commit()
    }

    func setQueryName(_ id: UUID, _ rawName: String) {
        let sanitized = Self.sanitizedIdentifier(rawName)
        guard let index = document.queries.firstIndex(where: { $0.id == id }) else { return }
        let current = document.queries[index].name
        guard sanitized != current else { return }
        guard !document.queries.contains(where: { $0.id != id && $0.name == sanitized }) else { return }
        document.queries[index].name = sanitized
        if let state = runtime.queryStates.removeValue(forKey: current) {
            runtime.queryStates[sanitized] = state
        }
        commit()
    }

    func setQuerySQL(_ id: UUID, _ sql: String) {
        guard let index = document.queries.firstIndex(where: { $0.id == id }) else { return }
        document.queries[index].sql = sql
        commit()
    }

    func setQueryConnection(_ id: UUID, _ connectionID: UUID?) {
        guard let index = document.queries.firstIndex(where: { $0.id == id }) else { return }
        document.queries[index].connectionId = connectionID
        commit()
    }

    func setQueryRunOnLoad(_ id: UUID, _ value: Bool) {
        guard let index = document.queries.firstIndex(where: { $0.id == id }) else { return }
        document.queries[index].runOnLoad = value
        commit()
    }

    func setQueryReadOnly(_ id: UUID, _ value: Bool) {
        guard let index = document.queries.firstIndex(where: { $0.id == id }) else { return }
        document.queries[index].readOnly = value
        commit()
    }

    @discardableResult
    func runQuery(_ query: AppQuery) async -> Bool {
        let name = query.name
        guard let connection = document.connection(id: query.connectionId) else {
            var state = runtime.queryStates[name] ?? QueryRuntimeState()
            state.error = "No SQLite connection is attached to this query."
            state.loading = false
            runtime.queryStates[name] = state
            touch()
            return false
        }

        let sql: String
        do {
            let context = contextJSON()
            sql = try SQLInterpolator.interpolate(query.sql) { [jsEngine] expression in
                switch jsEngine.evaluate(expression, contextJSON: context) {
                case .success(let value):
                    return value
                case .failure(let error):
                    throw SQLiteFailure(message: "Binding error in {{ \(expression) }}: \(error)")
                }
            }
        } catch {
            var state = runtime.queryStates[name] ?? QueryRuntimeState()
            state.error = error.localizedDescription
            state.loading = false
            runtime.queryStates[name] = state
            touch()
            return false
        }

        var loading = runtime.queryStates[name] ?? QueryRuntimeState()
        loading.loading = true
        loading.error = nil
        loading.executedSQL = sql
        runtime.queryStates[name] = loading
        touch()

        let path = connection.path
        let start = Date()
        let result = await Task.detached(priority: .userInitiated) { () -> Result<SQLiteResult, Error> in
            Result { try SQLiteEngine.query(sql, path: path, readOnly: query.readOnly) }
        }.value
        let duration = Date().timeIntervalSince(start) * 1000

        var state = runtime.queryStates[name] ?? QueryRuntimeState()
        state.loading = false
        state.ranAt = Date()
        state.durationMS = duration
        state.executedSQL = sql

        switch result {
        case .success(let sqlResult):
            state.data = sqlResult.objectRows
            state.columns = sqlResult.columns
            state.rowCount = sqlResult.rows.count
            state.affectedRows = sqlResult.affectedRows
            state.error = nil
            runtime.queryStates[name] = state
            touch()
            return true
        case .failure(let error):
            state.data = []
            state.columns = []
            state.rowCount = 0
            state.affectedRows = 0
            state.error = error.localizedDescription
            runtime.queryStates[name] = state
            touch()
            return false
        }
    }

    @discardableResult
    func runQuery(named name: String) async -> Bool {
        guard let query = document.query(named: name) else {
            showToast("Query “\(name)” does not exist", kind: .error)
            return false
        }
        return await runQuery(query)
    }

    func runOnLoadQueries() async {
        let queries = document.queries.filter { $0.runOnLoad }
        for query in queries {
            _ = await runQuery(query)
        }
    }

    func refreshBindings() {
        Task {
            await runOnLoadQueries()
        }
    }

    // MARK: - Connections

    @discardableResult
    func addConnection(path: String, name rawName: String, readOnly: Bool = false) -> AppConnection {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent }
        var unique = name
        var counter = 2
        while document.connections.contains(where: { $0.name == unique }) {
            unique = "\(name) \(counter)"
            counter += 1
        }
        let connection = AppConnection(name: unique, path: path, readOnly: readOnly)
        document.connections.append(connection)
        selectedConnectionID = connection.id
        sidebarTab = .data
        commit()
        refreshSchema(connection.id)
        showToast("Connected \(unique)", kind: .success)
        return connection
    }

    func removeConnection(_ id: UUID) {
        document.connections.removeAll { $0.id == id }
        for index in document.queries.indices where document.queries[index].connectionId == id {
            document.queries[index].connectionId = nil
        }
        schemaByConnection.removeValue(forKey: id)
        if selectedConnectionID == id {
            selectedConnectionID = document.connections.first?.id
        }
        commit()
    }

    func selectConnection(_ id: UUID) {
        selectedConnectionID = id
        if schemaByConnection[id] == nil {
            refreshSchema(id)
        }
    }

    func refreshAllSchemas() {
        for connection in document.connections where schemaByConnection[connection.id] == nil {
            refreshSchema(connection.id)
        }
    }

    func refreshSchema(_ id: UUID) {
        guard let connection = document.connections.first(where: { $0.id == id }) else { return }
        guard !schemaLoading.contains(id) else { return }
        schemaLoading.insert(id)
        let path = connection.path
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[SQLiteTable], Error> in
                Result { try SQLiteEngine.tables(at: path) }
            }.value
            self.schemaLoading.remove(id)
            switch result {
            case .success(let tables):
                self.schemaByConnection[id] = tables
            case .failure(let error):
                self.schemaByConnection[id] = []
                self.showToast("Schema error: \(error.localizedDescription)", kind: .error)
            }
        }
    }

    // MARK: - Input values

    func componentValue(_ component: CanvasComponent) -> JSONValue? {
        runtime.componentValues[component.name]
    }

    func ensureComponentValue(_ component: CanvasComponent, _ value: JSONValue) {
        if runtime.componentValues[component.name] == nil {
            runtime.componentValues[component.name] = value
            runtime.invalidate()
        }
    }

    func setComponentValue(_ component: CanvasComponent, _ value: JSONValue) {
        guard runtime.componentValues[component.name] != value else { return }
        runtime.componentValues[component.name] = value
        touch()
    }

    // MARK: - Table state

    func tableState(named name: String, defaultPageSize: Int) -> TableRuntimeState {
        var state = runtime.tableStates[name] ?? TableRuntimeState()
        var changed = false
        if !state.initialized {
            state.initialized = true
            changed = true
        }
        let size = max(1, defaultPageSize)
        if state.pageSize != size {
            state.pageSize = size
            state.page = 1
            changed = true
        }
        if changed {
            runtime.tableStates[name] = state
        }
        return state
    }

    func updateTableSearch(_ component: CanvasComponent, search: String) {
        let defaultSize = max(1, intValue(component, "pageSize"))
        var state = tableState(named: component.name, defaultPageSize: defaultSize)
        state.search = search
        state.page = 1
        runtime.tableStates[component.name] = state
        touch()
    }

    func setTablePage(_ component: CanvasComponent, page: Int) {
        let defaultSize = max(1, intValue(component, "pageSize"))
        var state = tableState(named: component.name, defaultPageSize: defaultSize)
        state.page = max(1, page)
        runtime.tableStates[component.name] = state
        touch()
    }

    func toggleTableSort(_ component: CanvasComponent, key: String) {
        let defaultSize = max(1, intValue(component, "pageSize"))
        var state = tableState(named: component.name, defaultPageSize: defaultSize)
        if state.sortKey == key {
            state.ascending.toggle()
        } else {
            state.sortKey = key
            state.ascending = true
        }
        state.page = 1
        runtime.tableStates[component.name] = state
        touch()
    }

    func selectTableRow(_ component: CanvasComponent, row: JSONValue) {
        let defaultSize = max(1, intValue(component, "pageSize"))
        var state = tableState(named: component.name, defaultPageSize: defaultSize)
        state.selectedRow = row
        runtime.tableStates[component.name] = state
        touch()
        perform(component.actions(for: "onRowClick"), row: row)
    }

    func isRowSelected(_ component: CanvasComponent, row: JSONValue) -> Bool {
        runtime.tableStates[component.name]?.selectedRow == row
    }

    func computeTable(_ component: CanvasComponent) -> TableComputation {
        let data = value(component, "data").arrayValue ?? []
        let searchable = boolValue(component, "searchable")
        let sortable = boolValue(component, "sortable")
        let paginated = boolValue(component, "paginate")
        let defaultSize = max(1, intValue(component, "pageSize"))
        var state = tableState(named: component.name, defaultPageSize: defaultSize)

        var rows = data
        if searchable, !state.search.trimmingCharacters(in: .whitespaces).isEmpty {
            let needle = state.search.lowercased()
            rows = rows.filter { row in
                if let object = row.objectValue {
                    return object.values.contains { $0.display.lowercased().contains(needle) }
                }
                return row.display.lowercased().contains(needle)
            }
        }
        if sortable, let key = state.sortKey {
            let ascending = state.ascending
            rows.sort { first, second in
                let comparison = JSONValue.compare(first[key] ?? .null, second[key] ?? .null)
                if comparison == .orderedSame { return false }
                return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            }
        }

        let configured = stringValue(component, "columns")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var columns = configured
        if columns.isEmpty {
            var seen = Set<String>()
            var inferred: [String] = []
            for row in rows.prefix(20) {
                guard let object = row.objectValue else { continue }
                for key in object.keys where !seen.contains(key) {
                    seen.insert(key)
                    inferred.append(key)
                }
            }
            columns = inferred.isEmpty ? ["value"] : inferred
        }

        let total = rows.count
        let pageSize = max(1, state.pageSize)
        let pageCount = paginated ? max(1, Int(ceil(Double(total) / Double(pageSize)))) : 1
        let page = paginated ? min(max(1, state.page), pageCount) : 1
        if page != state.page {
            state.page = page
            runtime.tableStates[component.name] = state
        }
        let start = paginated ? min(total, (page - 1) * pageSize) : 0
        let end = paginated ? min(total, start + pageSize) : total
        let pageRows = start < end ? Array(rows[start..<end]) : []

        return TableComputation(
            allRows: rows,
            pageRows: pageRows,
            columns: columns,
            page: page,
            pageCount: pageCount,
            totalRows: total,
            rangeStart: total == 0 ? 0 : start + 1,
            rangeEnd: end,
            paginated: paginated
        )
    }

    // MARK: - Actions

    func perform(_ actions: [AppAction], row: JSONValue? = nil) {
        guard !actions.isEmpty else { return }
        Task { [weak self] in
            await self?.performSequentially(actions, row: row)
        }
    }

    private func performSequentially(_ actions: [AppAction], row: JSONValue?) async {
        for action in actions {
            runtime.invalidate()
            switch action.kind {
            case .runQuery:
                _ = await runQuery(named: action.target)
            case .setState:
                let value = actionValue(action.value, row: row)
                runtime.appState[action.target] = value
                touch()
            case .setComponentValue:
                let value = actionValue(action.value, row: row)
                runtime.componentValues[action.target] = value
                touch()
            case .showToast:
                showToast(action.target.isEmpty ? "Done" : action.target)
            case .openURL:
                if let url = URL(string: action.target) {
                    NSWorkspace.shared.open(url)
                }
            case .navigate:
                if let page = document.pages.first(where: { $0.name == action.target || $0.id.uuidString == action.target }) {
                    selectPage(page.id)
                }
            }
        }
    }

    private func actionValue(_ prop: PropValue?, row: JSONValue?) -> JSONValue {
        guard let prop else { return .null }
        switch prop {
        case .literal(let value):
            return value
        case .binding(let expression):
            var extras: String? = nil
            if let row, let data = try? JSONSerialization.data(withJSONObject: ["row": row.any], options: []),
               let json = String(data: data, encoding: .utf8) {
                extras = json
            }
            switch jsEngine.evaluate(expression, contextJSON: contextJSON(), extrasJSON: extras) {
            case .success(let value):
                return value
            case .failure:
                return .null
            }
        }
    }

    // MARK: - Helpers

    static func sanitizedIdentifier(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = trimmed.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        if result.isEmpty { result = "value" }
        if let first = result.first, first.isNumber {
            result = "v" + result
        }
        return result
    }

    private func snap(_ value: Double) -> Double {
        (value / 8).rounded() * 8
    }
}
