import SwiftUI
import AppKit

struct SidebarView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Hairline()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch model.sidebarTab {
                    case .components:
                        ComponentsPalette(model: model)
                    case .layers:
                        LayersPanel(model: model)
                    case .data:
                        DataPanel(model: model)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }

            Hairline()
            footer
        }
        .background(Theme.panel)
    }

    private var tabBar: some View {
        HStack(spacing: 3) {
            ForEach(SidebarTab.allCases) { tab in
                let active = model.sidebarTab == tab
                Button {
                    model.sidebarTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundStyle(active ? Theme.text : Theme.textFaint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(active ? Theme.panelRaised : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
            Text(model.activeConnection?.name ?? "No database")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textDim)
                .lineLimit(1)
            Spacer()
            if let connection = model.activeConnection {
                StatusDot(color: FileManager.default.fileExists(atPath: connection.path) ? Theme.green : Theme.red)
                Text("SQLite")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }
}

// MARK: - Components palette

private struct ComponentsPalette: View {
    @ObservedObject var model: EditorModel

    private var groups: [(String, [ComponentType])] {
        let order = ["Content", "Inputs", "Data", "Layout"]
        return order.map { category in
            (category, ComponentType.allCases.filter { $0.category == category })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionLabel(text: "Components")
                Spacer()
                Text("drag onto canvas")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textFaint)
            }

            ForEach(groups.indices, id: \.self) { index in
                let group = groups[index]
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.0)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)

                    ForEach(group.1) { type in
                        PaletteCard(type: type) {
                            model.addComponent(type)
                        }
                    }
                }
            }

            hint
        }
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline()
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.amber)
                Text("Linked props use Javascript, e.g. `queries.get_users.data`.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.panelRaised)
            )
        }
    }
}

private struct PaletteCard: View {
    let type: ComponentType
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hovering ? Theme.accent.opacity(0.18) : Theme.panelRaised)
                    Image(systemName: type.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(hovering ? Theme.accentBright : Theme.textDim)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(type.title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(type.blurb)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(hovering ? Theme.textDim : Color.clear)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? Theme.panelRaised : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(hovering ? Theme.border : Theme.borderSoft, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onDrag {
            NSItemProvider(object: "foundry.component.\(type.rawValue)" as NSString)
        }
        .help("Click or drag \(type.title) onto the canvas")
    }
}

// MARK: - Layers

private struct LayersPanel: View {
    @ObservedObject var model: EditorModel

    private var components: [CanvasComponent] {
        Array((model.currentPage?.components ?? []).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: model.currentPage?.name ?? "Layers")
                Spacer()
                Text("\(components.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
            }

            if components.isEmpty {
                emptyState
            } else {
                VStack(spacing: 2) {
                    ForEach(components) { component in
                        layerRow(component)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.textFaint)
            Text("No components yet")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.textDim)
            Text("Drag a component from the Components tab.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func layerRow(_ component: CanvasComponent) -> some View {
        let selected = component.id == model.selectedComponentID
        return HStack(spacing: 7) {
            Image(systemName: component.type.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(component.hidden ? Theme.textFaint : Theme.textDim)
                .frame(width: 16)

            Text(component.name)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundStyle(component.hidden ? Theme.textFaint : Theme.text)
                .lineLimit(1)

            Spacer(minLength: 2)

            if component.locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.textFaint)
            }

            Button {
                model.toggleHidden(component.id)
            } label: {
                Image(systemName: component.hidden ? "eye.slash" : "eye")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 18, height: 20)
            }
            .buttonStyle(.plain)
            .help(component.hidden ? "Show" : "Hide")
        }
        .padding(.horizontal, 7)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.22) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectComponent(component.id)
        }
        .contextMenu {
            Button("Select") { model.selectComponent(component.id) }
            Button("Duplicate") { model.duplicateComponent(component.id) }
            Button("Bring to front") { model.bringToFront(component.id) }
            Button("Send to back") { model.sendToBack(component.id) }
            Divider()
            Button(component.hidden ? "Show" : "Hide") { model.toggleHidden(component.id) }
            Button(component.locked ? "Unlock" : "Lock") { model.toggleLocked(component.id) }
            Divider()
            Button("Delete", role: .destructive) { model.deleteComponent(component.id) }
        }
    }
}

// MARK: - Data browser

private struct DataPanel: View {
    @ObservedObject var model: EditorModel
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            connectionsSection
            schemaSection
            queriesSection
            stateSection
        }
    }

    // Connections

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Connections")
                Spacer()
                IconButton(icon: "folder", help: "Open a SQLite database", size: 22) {
                    openDatabase()
                }
                IconButton(icon: "plus", help: "Create a SQLite database", size: 22) {
                    createDatabase()
                }
            }

            if model.document.connections.isEmpty {
                Text("No databases connected yet.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.vertical, 3)
            } else {
                VStack(spacing: 2) {
                    ForEach(model.document.connections) { connection in
                        connectionRow(connection)
                    }
                }
            }
        }
    }

    private func connectionRow(_ connection: AppConnection) -> some View {
        let active = (model.activeConnection?.id == connection.id)
        let exists = FileManager.default.fileExists(atPath: connection.path)
        return HStack(spacing: 7) {
            StatusDot(color: exists ? Theme.green : Theme.red)
            VStack(alignment: .leading, spacing: 1) {
                Text(connection.name)
                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(URL(fileURLWithPath: connection.path).lastPathComponent)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if model.schemaLoading.contains(connection.id) {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(active ? Theme.panelRaised : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectConnection(connection.id)
        }
        .contextMenu {
            Button("Browse schema") { model.selectConnection(connection.id) }
            Button("Refresh schema") { model.refreshSchema(connection.id) }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: connection.path)])
            }
            Divider()
            Button("Remove connection", role: .destructive) {
                model.removeConnection(connection.id)
            }
        }
    }

    // Schema

    private var schemaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Schema")
                Spacer()
                if let connection = model.activeConnection {
                    IconButton(icon: "arrow.clockwise", help: "Refresh schema", size: 22) {
                        model.refreshSchema(connection.id)
                    }
                }
            }

            let tables = model.schema(for: model.activeConnection?.id)

            if model.activeConnection == nil {
                Text("Connect a database to browse tables.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
            } else if tables.isEmpty {
                Text(model.schemaLoading.contains(model.activeConnection?.id ?? UUID()) ? "Reading schema…" : "No tables found.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
            } else {
                VStack(spacing: 1) {
                    ForEach(tables) { table in
                        tableRow(table)
                    }
                }
            }
        }
    }

    private func tableRow(_ table: SQLiteTable) -> some View {
        let isOpen = expanded.contains(table.name)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    if isOpen {
                        expanded.remove(table.name)
                    } else {
                        expanded.insert(table.name)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.textFaint)
                            .frame(width: 10)
                        Image(systemName: table.kind == "view" ? "eye" : "tablecells")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textDim)
                        Text(table.name)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text("\(table.rowCount)")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textFaint)

                Button {
                    let query = model.addQuery(table: table.name, connectionID: model.activeConnection?.id)
                    model.showToast("Created \(query.name)", kind: .info)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.plain)
                .help("New query for \(table.name)")
            }
            .padding(.horizontal, 7)
            .frame(height: 27)

            if isOpen {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(table.columns) { column in
                        HStack(spacing: 6) {
                            Image(systemName: column.primaryKey ? "key.fill" : "smallcircle.filled.circle")
                                .font(.system(size: 6.5))
                                .foregroundStyle(column.primaryKey ? Theme.amber : Theme.textFaint)
                            Text(column.name)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(Theme.textDim)
                            Spacer(minLength: 0)
                            Text(column.type.isEmpty ? "any" : column.type.lowercased())
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(Theme.textFaint)
                            if column.notNull {
                                Text("NN")
                                    .font(.system(size: 7.5, weight: .bold))
                                    .foregroundStyle(Theme.textFaint)
                            }
                        }
                        .padding(.leading, 22)
                    }
                }
                .padding(.bottom, 5)
            }
        }
    }

    // Queries

    private var queriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Queries")
                Spacer()
                IconButton(icon: "plus", help: "New query", size: 22) {
                    model.addQuery()
                }
            }

            if model.document.queries.isEmpty {
                Text("No queries yet. Add one or generate from a table.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
            } else {
                VStack(spacing: 1) {
                    ForEach(model.document.queries) { query in
                        queryRow(query)
                    }
                }
            }
        }
    }

    private func queryRow(_ query: AppQuery) -> some View {
        let state = model.runtime.queryStates[query.name]
        let selected = model.selectedQueryID == query.id
        return HStack(spacing: 6) {
            Circle()
                .fill(queryStatusColor(state))
                .frame(width: 5, height: 5)
            Text(query.name)
                .font(.system(size: 10.5, weight: selected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(selected ? Theme.text : Theme.textDim)
                .lineLimit(1)

            Spacer(minLength: 2)

            if state?.loading == true {
                ProgressView()
                    .controlSize(.mini)
            } else if let state, state.error == nil, state.rowCount > 0 {
                Text("\(state.rowCount)")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.textFaint)
            }

            Button {
                Task { await model.runQuery(query) }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 18, height: 20)
            }
            .buttonStyle(.plain)
            .help("Run query")
        }
        .padding(.horizontal, 7)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Theme.accent.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectedQueryID = query.id
        }
        .contextMenu {
            Button("Open") { model.selectedQueryID = query.id }
            Button("Run") { Task { await model.runQuery(query) } }
            Divider()
            Button("Delete query", role: .destructive) { model.deleteQuery(query.id) }
        }
    }

    private func queryStatusColor(_ state: QueryRuntimeState?) -> Color {
        guard let state else { return Theme.textFaint }
        if state.loading { return Theme.amber }
        if state.error != nil { return Theme.red }
        if state.ranAt != nil { return Theme.green }
        return Theme.textFaint
    }

    // App state

    private var stateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "App state")
                Spacer()
                IconButton(icon: "plus", help: "Add state key", size: 22) {
                    _ = model.addStateKey()
                }
            }

            let keys = Array(Set(model.document.state.keys).union(model.runtime.appState.keys)).sorted()

            if keys.isEmpty {
                Text("State persists across pages and can be bound in props and SQL.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 4) {
                    ForEach(keys, id: \.self) { key in
                        AppStateRow(model: model, key: key)
                    }
                }
            }
        }
    }

    // Actions

    private func openDatabase() {
        guard let url = FileDialogs.openSQLiteDatabase() else { return }
        _ = model.addConnection(path: url.path, name: url.deletingPathExtension().lastPathComponent)
    }

    private func createDatabase() {
        guard let url = FileDialogs.createSQLiteDatabase() else { return }
        do {
            try SQLiteEngine.createDatabase(at: url.path, seedSQL: nil)
            _ = model.addConnection(path: url.path, name: url.deletingPathExtension().lastPathComponent)
        } catch {
            model.showToast("Could not create database: \(error.localizedDescription)", kind: .error)
        }
    }
}

private struct AppStateRow: View {
    @ObservedObject var model: EditorModel
    let key: String
    @State private var text = ""

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Theme.blue)
                .lineLimit(1)
                .frame(width: 78, alignment: .leading)

            TextField("value", text: $text)
                .font(.system(size: 10.5, design: .monospaced))
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.field)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .onSubmit { commit() }

            Button {
                model.removeStateValue(key: key)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 16, height: 20)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            text = displayValue
        }
        .onChange(of: key) { _, _ in
            text = displayValue
        }
        .onDisappear {
            commit()
        }
    }

    private var currentValue: JSONValue {
        model.runtime.appState[key] ?? model.document.state[key] ?? .null
    }

    private var displayValue: String {
        if let string = currentValue.stringValue, case .string = currentValue {
            return string
        }
        if currentValue.isNull { return "" }
        return currentValue.display
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: JSONValue
        if let value = JSONValue.parse(trimmed) {
            parsed = value
        } else {
            parsed = .string(text)
        }
        guard parsed != currentValue else { return }
        model.setStateValue(key: key, value: parsed)
    }
}
