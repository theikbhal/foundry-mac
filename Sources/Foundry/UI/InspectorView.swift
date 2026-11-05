import SwiftUI
import AppKit

struct InspectorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let component = model.selectedComponent {
                        componentInspector(component)
                    } else {
                        pageInspector
                    }
                }
            }
        }
        .background(Theme.panel)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.accent.opacity(0.16))
                Image(systemName: model.selectedComponent?.type.icon ?? "rectangle.portrait")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accentBright)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.selectedComponent?.type.title.uppercased() ?? "PAGE")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.textFaint)

                if let component = model.selectedComponent {
                    InspectorNameField(value: component.name) { name in
                        model.renameComponent(component.id, to: name)
                    }
                } else {
                    Text(model.currentPage?.name ?? "Page 1")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if let component = model.selectedComponent {
                IconButton(icon: "plus.square.on.square", help: "Duplicate", size: 24) {
                    model.duplicateComponent(component.id)
                }
                IconButton(icon: "trash", help: "Delete", size: 24) {
                    model.deleteComponent(component.id)
                }
            } else {
                IconButton(icon: "plus", help: "Add page", size: 24) {
                    model.addPage()
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    // MARK: - Component inspector

    @ViewBuilder
    private func componentInspector(_ component: CanvasComponent) -> some View {
        section("Layout") {
            HStack(spacing: 8) {
                InspectorNumberField(label: "X", value: component.x, range: 0...8000) { value in
                    model.updateComponent(component.id) { $0.x = value }
                }
                InspectorNumberField(label: "Y", value: component.y, range: 0...8000) { value in
                    model.updateComponent(component.id) { $0.y = value }
                }
            }
            HStack(spacing: 8) {
                InspectorNumberField(label: "W", value: component.width, range: 24...8000) { value in
                    model.updateComponent(component.id) { $0.width = max(24, value) }
                }
                InspectorNumberField(label: "H", value: component.height, range: 16...8000) { value in
                    model.updateComponent(component.id) { $0.height = max(16, value) }
                }
            }
            HStack(spacing: 6) {
                Button("Bring front") { model.bringToFront(component.id) }
                    .buttonStyle(EditorButtonStyle(variant: .ghost, small: true))
                Button("Send back") { model.sendToBack(component.id) }
                    .buttonStyle(EditorButtonStyle(variant: .ghost, small: true))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { component.locked },
                    set: { _ in model.toggleLocked(component.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                Image(systemName: "lock")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textFaint)
            }
        }

        section("Properties") {
            VStack(alignment: .leading, spacing: 13) {
                ForEach(ComponentSchema.specs(for: component.type)) { spec in
                    PropEditor(model: model, component: component, spec: spec)
                }
            }
        }

        let events = ComponentSchema.events(for: component.type)
        if !events.isEmpty {
            section("Events") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(events) { event in
                        EventEditor(model: model, component: component, event: event)
                    }
                }
            }
        }

        section("Visibility") {
            HStack {
                Text("Hidden")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { component.hidden },
                    set: { _ in model.toggleHidden(component.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            Text("Hidden components stay in the tree but are skipped in preview.")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textFaint)
        }

        section("Bindings") {
            VStack(alignment: .leading, spacing: 7) {
                bindingHint("{{ queries.get_users.data }}", "Resolve a Javascript expression")
                bindingHint("{{ state.selectedId }}", "Read app state")
                bindingHint("{{ components.searchInput.value }}", "Read another component")
                bindingHint("row.col", "Row fields inside table actions")
            }
        }
    }

    private func bindingHint(_ code: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(code)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Theme.accentBright)
            Text(text)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textFaint)
        }
    }

    // MARK: - Page inspector

    @ViewBuilder
    private var pageInspector: some View {
        if let page = model.currentPage {
            section("Page") {
                HStack(spacing: 8) {
                    Text("Name")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 54, alignment: .leading)
                    InspectorNameField(value: page.name) { name in
                        model.renamePage(page.id, to: name)
                    }
                }
                HStack(spacing: 8) {
                    InspectorNumberField(label: "W", value: page.width, range: 400...5000) { value in
                        model.updatePageSettings(width: value)
                    }
                    InspectorNumberField(label: "H", value: page.height, range: 400...5000) { value in
                        model.updatePageSettings(height: value)
                    }
                }
                HStack {
                    Text("Background")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                    Spacer()
                    Text(page.backgroundHex.uppercased())
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: page.backgroundHex) },
                        set: { model.updatePageSettings(background: $0.hexString) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 36)
                }
                HStack(spacing: 6) {
                    Button("Add page") { model.addPage() }
                        .buttonStyle(EditorButtonStyle(variant: .ghost, small: true))
                    Spacer()
                    Text("\(page.components.count) components")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }

        section("App") {
            HStack(spacing: 8) {
                Text("Name")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 54, alignment: .leading)
                InspectorNameField(value: model.document.name) { name in
                    model.renameApp(name)
                }
            }
            VStack(spacing: 5) {
                metadataRow("Pages", "\(model.document.pages.count)")
                metadataRow("Queries", "\(model.document.queries.count)")
                metadataRow("Connections", "\(model.document.connections.count)")
                metadataRow("Autosaved", model.lastSavedAt.map { Self.timeFormatter.string(from: $0) } ?? "pending")
            }
        }

        section("App state") {
            VStack(alignment: .leading, spacing: 6) {
                let keys = Array(Set(model.document.state.keys).union(model.runtime.appState.keys)).sorted()
                ForEach(keys, id: \.self) { key in
                    InspectorStateRow(model: model, key: key)
                }
                Button {
                    _ = model.addStateKey()
                } label: {
                    Label("Add state key", systemImage: "plus")
                }
                .buttonStyle(EditorButtonStyle(variant: .ghost, small: true))
            }
        }

        section("Shortcuts") {
            VStack(spacing: 6) {
                shortcutRow("Preview", "⌥⌘P")
                shortcutRow("New app", "⌘N")
                shortcutRow("Templates", "⇧⌘T")
                shortcutRow("Import template", "⇧⌘I")
            }
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
            Spacer()
            Text(value)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.textDim)
        }
    }

    private func shortcutRow(_ label: String, _ keys: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
            Spacer()
            Text(keys)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textDim)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.panelRaised))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    // MARK: - Section container

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: title)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.borderSoft).frame(height: 1)
        }
    }
}

// MARK: - Name field

private struct InspectorNameField: View {
    let value: String
    let commit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Name", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.text)
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

// MARK: - Number field

private struct InspectorNumberField: View {
    let label: String
    let value: Double
    var range: ClosedRange<Double> = 0...10000
    let commit: (Double) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
                .frame(width: 10)

            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.field)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(focused ? Theme.accent : Theme.border, lineWidth: 1)
                )
                .focused($focused)
                .onSubmit { apply() }
                .onAppear { text = JSONValue.formatNumber(value) }
                .onChange(of: value) { _, newValue in
                    if !focused { text = JSONValue.formatNumber(newValue) }
                }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { apply() }
                }
        }
    }

    private func apply() {
        guard let parsed = Double(text.trimmingCharacters(in: .whitespaces)) else {
            text = JSONValue.formatNumber(value)
            return
        }
        let clamped = min(max(range.lowerBound, parsed), range.upperBound)
        commit(clamped)
        text = JSONValue.formatNumber(clamped)
    }
}

// MARK: - Prop editor

private struct PropEditor: View {
    @ObservedObject var model: EditorModel
    let component: CanvasComponent
    let spec: PropSpec

    private var prop: PropValue {
        component.props[spec.key] ?? spec.defaultValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(spec.label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textDim)
                Spacer(minLength: 4)
                Button {
                    toggleMode()
                } label: {
                    Text("fx")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(prop.isBinding ? Color.white : Theme.textFaint)
                        .padding(.horizontal, 5)
                        .frame(height: 17)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(prop.isBinding ? Theme.accent : Theme.panelRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(prop.isBinding ? Color.clear : Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(prop.isBinding ? "Switch to literal value" : "Bind to a Javascript expression")
            }

            if let expression = prop.bindingExpression {
                bindingEditor(expression)
            } else {
                literalEditor(prop.literalValue ?? .null)
            }

            if let hint = spec.hint {
                Text(hint)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // Binding mode

    private func bindingEditor(_ expression: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text("{{")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
                TextField("expression", text: Binding(
                    get: { expression },
                    set: { model.setProp(componentID: component.id, key: spec.key, value: .binding($0)) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.accentBright)
                .padding(.horizontal, 5)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.field)
                )
                Text("}}")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )

            preview(expression)
        }
    }

    @ViewBuilder
    private func preview(_ expression: String) -> some View {
        switch model.bindingPreview(expression) {
        case .success(let value):
            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 7.5))
                    .foregroundStyle(Theme.textFaint)
                Text(previewText(value))
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textFaint)
                    .lineLimit(1)
            }
        case .failure(let error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(Theme.red)
                Text(error.message)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.red)
                    .lineLimit(2)
            }
        }
    }

    private func previewText(_ value: JSONValue) -> String {
        switch value {
        case .string(let string): return "\"\(string)\""
        case .array(let items): return "\(items.count) item\(items.count == 1 ? "" : "s")"
        case .object(let object): return "\(object.count) field\(object.count == 1 ? "" : "s")"
        case .null: return "null"
        default: return value.display
        }
    }

    // Literal mode

    @ViewBuilder
    private func literalEditor(_ literal: JSONValue) -> some View {
        switch spec.kind {
        case .boolean:
            Toggle("", isOn: Binding(
                get: { literal.boolValue ?? false },
                set: { newValue in
                    model.setProp(componentID: component.id, key: spec.key, value: .flag(newValue))
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)

        case .number:
            InspectorNumberField(label: "", value: literal.doubleValue ?? 0, range: -10000...10000) { newValue in
                model.setProp(componentID: component.id, key: spec.key, value: .num(newValue))
            }

        case .choice(let options):
            Menu {
                ForEach(options) { option in
                    Button(option.label) {
                        model.setProp(componentID: component.id, key: spec.key, value: .text(option.value))
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(options.first { $0.value == literal.stringValue }?.label ?? literal.display)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.field)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

        case .color:
            HStack(spacing: 7) {
                ColorPicker("", selection: Binding(
                    get: { Color(hex: literal.stringValue ?? "#FFFFFF") },
                    set: { model.setProp(componentID: component.id, key: spec.key, value: .text($0.hexString)) }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 34)

                Text((literal.stringValue ?? "#FFFFFF").uppercased())
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                Spacer()
            }

        case .longText:
            if case .array = literal {
                JSONLiteralEditor(value: literal) { newValue in
                    model.setProp(componentID: component.id, key: spec.key, value: .json(newValue))
                }
            } else if case .object = literal {
                JSONLiteralEditor(value: literal) { newValue in
                    model.setProp(componentID: component.id, key: spec.key, value: .json(newValue))
                }
            } else {
                MultilineTextField(initial: literal.stringValue ?? literal.display) { newText in
                    model.setProp(componentID: component.id, key: spec.key, value: .text(newText))
                }
            }

        case .text:
            TextField("", text: Binding(
                get: { literal.stringValue ?? "" },
                set: { model.setProp(componentID: component.id, key: spec.key, value: .text($0)) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private func toggleMode() {
        if let expression = prop.bindingExpression {
            _ = expression
            let resolved = model.value(component, spec.key)
            model.setProp(componentID: component.id, key: spec.key, value: .literal(literalValue(from: resolved)))
        } else {
            let literal = prop.literalValue ?? .null
            model.setProp(componentID: component.id, key: spec.key, value: .binding(expression(from: literal)))
        }
    }

    private func literalValue(from value: JSONValue) -> JSONValue {
        switch spec.kind {
        case .number: return .number(value.doubleValue ?? 0)
        case .boolean: return .bool(value.boolValue ?? false)
        case .choice, .text, .color: return .string(value.stringValue ?? value.display)
        case .longText: return value
        }
    }

    private func expression(from value: JSONValue) -> String {
        switch value {
        case .string(let string):
            return "'" + string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'"
        case .number(let number):
            return JSONValue.formatNumber(number)
        case .bool(let flag):
            return flag ? "true" : "false"
        case .array, .object:
            return spec.key == "data" ? "queries.get_data.data" : "null"
        case .null:
            return "null"
        }
    }
}

// MARK: - JSON literal editor

private struct JSONLiteralEditor: View {
    let value: JSONValue
    let onChange: (JSONValue) -> Void
    @State private var text = ""
    @State private var invalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            TextEditor(text: $text)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .padding(5)
                .frame(height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.field)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(invalid ? Theme.red : Theme.border, lineWidth: 1)
                )
                .onAppear { text = value.prettyJSON }
                .onChange(of: text) { _, newText in
                    if let parsed = JSONValue.parse(newText) {
                        invalid = false
                        onChange(parsed)
                    } else {
                        invalid = true
                    }
                }

            if invalid {
                Text("Invalid JSON")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.red)
            }
        }
    }
}

private struct MultilineTextField: View {
    let initial: String
    let onChange: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 10))
            .foregroundStyle(Theme.text)
            .scrollContentBackground(.hidden)
            .padding(5)
            .frame(minHeight: 54, maxHeight: 90)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(focused ? Theme.accent : Theme.border, lineWidth: 1)
            )
            .focused($focused)
            .onAppear { text = initial }
            .onChange(of: text) { _, newValue in
                onChange(newValue)
            }
    }
}

// MARK: - Events

private struct EventEditor: View {
    @ObservedObject var model: EditorModel
    let component: CanvasComponent
    let event: EventSpec

    private var actions: [AppAction] {
        model.selectedComponent?.actions(for: event.key) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(event.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                Text("\(actions.count)")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Theme.panelRaised))
                Spacer()

                Menu {
                    ForEach(ActionKind.allCases) { kind in
                        Button {
                            var list = actions
                            list.append(AppAction(kind: kind))
                            model.setActions(componentID: component.id, event: event.key, actions: list)
                        } label: {
                            Label(kind.label, systemImage: kind.icon)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.panelRaised))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add action")
            }

            if actions.isEmpty {
                Text("No actions")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textFaint)
            } else {
                VStack(spacing: 5) {
                    ForEach(actions) { action in
                        ActionEditor(model: model, componentID: component.id, eventKey: event.key, action: action)
                    }
                }
            }
        }
    }
}

private struct ActionEditor: View {
    @ObservedObject var model: EditorModel
    let componentID: UUID
    let eventKey: String
    let action: AppAction

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Menu {
                    ForEach(ActionKind.allCases) { kind in
                        Button {
                            update { item in
                                item.kind = kind
                                if !kind.usesValue { item.value = nil }
                            }
                        } label: {
                            Label(kind.label, systemImage: kind.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: action.kind.icon)
                            .font(.system(size: 7.5))
                        Text(action.kind.label)
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundStyle(Theme.text)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Spacer(minLength: 2)

                Button {
                    remove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: 17, height: 17)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.panelRaised))
                }
                .buttonStyle(.plain)
            }

            targetEditor

            if action.kind.usesValue {
                ActionValueEditor(prop: action.value) { value in
                    update { $0.value = value }
                }
            }
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Theme.borderSoft, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var targetEditor: some View {
        switch action.kind {
        case .runQuery:
            Menu {
                ForEach(model.document.queries) { query in
                    Button(query.name) {
                        update { $0.target = query.name }
                    }
                }
            } label: {
                targetLabel(action.target.isEmpty ? "Choose query" : action.target)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

        case .navigate:
            Menu {
                ForEach(model.document.pages) { page in
                    Button(page.name) {
                        update { $0.target = page.name }
                    }
                }
            } label: {
                targetLabel(action.target.isEmpty ? "Choose page" : action.target)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

        case .setComponentValue:
            Menu {
                ForEach(model.currentPage?.components ?? []) { item in
                    Button(item.name) {
                        update { $0.target = item.name }
                    }
                }
            } label: {
                targetLabel(action.target.isEmpty ? "Choose component" : action.target)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

        default:
            TextField(action.kind.targetLabel, text: Binding(
                get: { action.target },
                set: { newValue in
                    update { $0.target = newValue }
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 6)
            .frame(height: 23)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private func targetLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Theme.textDim)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 6.5, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, 6)
        .frame(height: 23)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func update(_ body: (inout AppAction) -> Void) {
        guard let component = model.selectedComponent else { return }
        var list = component.actions(for: eventKey)
        guard let index = list.firstIndex(where: { $0.id == action.id }) else { return }
        body(&list[index])
        model.setActions(componentID: componentID, event: eventKey, actions: list)
    }

    private func remove() {
        guard let component = model.selectedComponent else { return }
        var list = component.actions(for: eventKey)
        list.removeAll { $0.id == action.id }
        model.setActions(componentID: componentID, event: eventKey, actions: list)
    }
}

private struct ActionValueEditor: View {
    let prop: PropValue?
    let onChange: (PropValue?) -> Void

    @State private var binding = false
    @State private var text = ""

    var body: some View {
        HStack(spacing: 5) {
            Text("Value")
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.textFaint)
                .frame(width: 32, alignment: .leading)

            TextField(binding ? "expression" : "literal", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(binding ? Theme.accentBright : Theme.text)
                .padding(.horizontal, 6)
                .frame(height: 23)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(binding ? Theme.accent.opacity(0.6) : Theme.border, lineWidth: 1)
                )
                .onSubmit { commit() }
                .onChange(of: text) { _, _ in commit() }

            Button {
                binding.toggle()
                if binding {
                    text = literalExpression()
                } else {
                    text = prop?.literalValue?.display ?? ""
                }
                commit()
            } label: {
                Text("fx")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(binding ? Color.white : Theme.textFaint)
                    .frame(width: 20, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(binding ? Theme.accent : Theme.panelRaised)
                    )
            }
            .buttonStyle(.plain)
            .help("Toggle expression")
        }
        .onAppear {
            if let prop {
                switch prop {
                case .binding(let expression):
                    binding = true
                    text = expression
                case .literal(let value):
                    binding = false
                    text = value.display
                }
            } else {
                text = ""
            }
        }
    }

    private func literalExpression() -> String {
        switch prop {
        case .some(.literal(.string(let string))):
            return "'" + string.replacingOccurrences(of: "'", with: "\\'") + "'"
        case .some(.literal(.number(let number))):
            return JSONValue.formatNumber(number)
        case .some(.literal(.bool(let flag))):
            return flag ? "true" : "false"
        default:
            return "row"
        }
    }

    private func commit() {
        if binding {
            onChange(text.isEmpty ? nil : .binding(text))
        } else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                onChange(nil)
            } else if let value = JSONValue.parse(trimmed) {
                onChange(.literal(value))
            } else {
                onChange(.literal(.string(text)))
            }
        }
    }
}

// MARK: - Page state row

private struct InspectorStateRow: View {
    @ObservedObject var model: EditorModel
    let key: String
    @State private var text = ""

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Theme.blue)
                .lineLimit(1)
                .frame(width: 116, alignment: .leading)

            TextField("value", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, design: .monospaced))
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
        .onDisappear {
            commit()
        }
    }

    private var currentValue: JSONValue {
        model.runtime.appState[key] ?? model.document.state[key] ?? .null
    }

    private var displayValue: String {
        if case .string(let string) = currentValue { return string }
        if currentValue.isNull { return "" }
        return currentValue.display
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = JSONValue.parse(trimmed) ?? .string(text)
        guard parsed != currentValue else { return }
        model.setStateValue(key: key, value: parsed)
    }
}
