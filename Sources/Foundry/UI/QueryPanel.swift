import SwiftUI
import AppKit

struct QueryPanel: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        Group {
            if let query = model.selectedQuery {
                panel(query)
            } else {
                Color.clear
            }
        }
        .background(Theme.panel)
    }

    private func panel(_ query: AppQuery) -> some View {
        VStack(spacing: 0) {
            toolbar(query)
            Hairline()
            HStack(spacing: 0) {
                sqlEditor(query)
                Rectangle()
                    .fill(Theme.borderSoft)
                    .frame(width: 1)
                resultsPane(query)
            }
        }
    }

    // MARK: - Toolbar

    private func toolbar(_ query: AppQuery) -> some View {
        let state = model.runtime.queryStates[query.name]
        return HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.accent.opacity(0.2))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accentBright)
            }
            .frame(width: 22, height: 22)

            QueryNameField(value: query.name) { name in
                model.setQueryName(query.id, name)
            }
            .frame(width: 148)

            Menu {
                if model.document.connections.isEmpty {
                    Text("No connections")
                } else {
                    ForEach(model.document.connections) { connection in
                        Button {
                            model.setQueryConnection(query.id, connection.id)
                        } label: {
                            if connection.id == query.connectionId {
                                Label(connection.name, systemImage: "checkmark")
                            } else {
                                Text(connection.name)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 8))
                    Text(model.connectionName(id: query.connectionId))
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6.5, weight: .bold))
                }
                .foregroundStyle(Theme.textDim)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.panelRaised)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            if query.runOnLoad {
                TagChip(text: "on load")
            }
            if query.readOnly {
                TagChip(text: "read-only")
            }

            Spacer(minLength: 4)

            if let state {
                if state.loading {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Running…")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                } else if state.ranAt != nil {
                    Text("\(state.rowCount) rows · \(Int(state.durationMS.rounded())) ms")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            Button {
                Task { await model.runQuery(query) }
            } label: {
                Label("Run", systemImage: "play.fill")
            }
            .buttonStyle(EditorButtonStyle(variant: .primary, small: true))
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(state?.loading == true)

            Menu {
                Button {
                    model.setQueryRunOnLoad(query.id, !query.runOnLoad)
                } label: {
                    Label(query.runOnLoad ? "Don't run on app load" : "Run on app load", systemImage: query.runOnLoad ? "checkmark" : "circle")
                }
                Button {
                    model.setQueryReadOnly(query.id, !query.readOnly)
                } label: {
                    Label(query.readOnly ? "Allow writes" : "Make read-only", systemImage: query.readOnly ? "checkmark" : "circle")
                }
                Divider()
                Button("Delete query", role: .destructive) {
                    model.deleteQuery(query.id)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.panelRaised))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                model.selectedQueryID = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.panelRaised))
            }
            .buttonStyle(.plain)
            .help("Close query")
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }

    // MARK: - SQL editor

    private func sqlEditor(_ query: AppQuery) -> some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel(text: "SQL")
                Spacer()
                Text(URL(fileURLWithPath: model.document.connection(id: query.connectionId)?.path ?? "").lastPathComponent)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 12)
            .frame(height: 26)

            TextEditor(text: Binding(
                get: { model.document.query(id: query.id)?.sql ?? query.sql },
                set: { model.setQuerySQL(query.id, $0) }
            ))
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Theme.text)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Theme.field)
            .overlay(alignment: .topLeading) {
                if query.sql.isEmpty {
                    Text("SELECT * FROM your_table LIMIT 100;")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 7.5))
                    .foregroundStyle(Theme.textFaint)
                Text("{{ value }} · {{{ raw_sql }}} · queries are safe-bound")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
                Spacer()
                if let state = model.runtime.queryStates[query.name], !state.executedSQL.isEmpty {
                    Text("⌘⏎ to run")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 22)
            .background(Theme.field)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.borderSoft).frame(height: 1)
            }
        }
        .frame(width: 370)
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsPane(_ query: AppQuery) -> some View {
        let state = model.runtime.queryStates[query.name]

        VStack(spacing: 0) {
            HStack(spacing: 6) {
                SectionLabel(text: "Results")
                if let state, state.error == nil, !state.data.isEmpty {
                    Text("\(state.data.count)")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.panelRaised))
                }
                Spacer()
                if let state, !state.executedSQL.isEmpty, state.error == nil {
                    Text("\(state.data.count) rows · \(state.columns.count) cols")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 26)

            Group {
                if let state {
                    if state.loading && state.data.isEmpty {
                        centeredMessage(icon: "hourglass", text: "Running query…", tint: Theme.textFaint)
                    } else if let error = state.error {
                        ScrollView {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.red)
                                Text(error)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Theme.red.opacity(0.9))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                        }
                    } else if state.data.isEmpty {
                        centeredMessage(
                            icon: state.affectedRows > 0 ? "checkmark.circle" : "tray",
                            text: state.affectedRows > 0 ? "\(state.affectedRows) row\(state.affectedRows == 1 ? "" : "s") affected" : "No rows returned",
                            tint: state.affectedRows > 0 ? Theme.green : Theme.textFaint
                        )
                    } else {
                        resultGrid(state)
                    }
                } else {
                    centeredMessage(icon: "play.circle", text: "Run the query to see results", tint: Theme.textFaint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func resultGrid(_ state: QueryRuntimeState) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(state.columns, id: \.self) { column in
                        HStack(spacing: 3) {
                            Text(column)
                                .font(.system(size: 8.5, weight: .semibold))
                                .tracking(0.3)
                                .foregroundStyle(Theme.textDim)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(width: 138, height: 24, alignment: .leading)
                        .background(Theme.panelRaised)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(Theme.border).frame(width: 1)
                        }
                    }
                }

                ForEach(state.data.indices, id: \.self) { rowIndex in
                    let row = state.data[rowIndex]
                    HStack(spacing: 0) {
                        ForEach(state.columns, id: \.self) { column in
                            Text(row[column]?.display ?? "NULL")
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(row[column]?.isNull == true ? Theme.textFaint : Theme.text)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(width: 138, height: 23, alignment: .leading)
                                .overlay(alignment: .trailing) {
                                    Rectangle().fill(Theme.borderSoft).frame(width: 1)
                                }
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : Color.white.opacity(0.02))
                }
            }
        }
    }

    private func centeredMessage(icon: String, text: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct QueryNameField: View {
    let value: String
    let commit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Query name", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(focused ? Theme.accent.opacity(0.7) : Theme.border, lineWidth: 1)
            )
            .focused($focused)
            .onSubmit { commit(text) }
            .onAppear { text = value }
            .onChange(of: value) { _, newValue in
                if !focused { text = newValue }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit(text) }
            }
    }
}
