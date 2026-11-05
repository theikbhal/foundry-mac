import SwiftUI
import Charts

struct ComponentRenderer: View {
    @ObservedObject var model: EditorModel
    let component: CanvasComponent
    let interactive: Bool

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        switch component.type {
        case .heading:
            heading
        case .text:
            bodyText
        case .button:
            buttonView
        case .textInput:
            textInputView(numeric: false)
        case .numberInput:
            textInputView(numeric: true)
        case .select:
            selectView
        case .table:
            tableView
        case .stat:
            statView
        case .chart:
            chartView
        case .divider:
            dividerView
        case .panel:
            panelView
        }
    }

    // MARK: - Helpers

    private func prop(_ key: String) -> JSONValue {
        model.value(component, key)
    }

    private func string(_ key: String, _ fallback: String = "") -> String {
        prop(key).stringValue ?? fallback
    }

    private func double(_ key: String) -> Double {
        prop(key).doubleValue ?? 0
    }

    private func boolean(_ key: String) -> Bool {
        prop(key).boolValue ?? false
    }

    private func color(_ key: String, fallback: String) -> Color {
        Color(hex: model.stringValue(component, key, fallback: fallback))
    }

    private func alignment(_ key: String) -> Alignment {
        switch string(key, "left") {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private func textAlignment(_ key: String) -> TextAlignment {
        switch string(key, "left") {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private func fontWeight(_ key: String) -> Font.Weight {
        switch string(key, "regular") {
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .regular
        }
    }

    private func perform(_ event: String) {
        guard interactive else { return }
        model.perform(component.actions(for: event))
    }

    // MARK: - Content

    private var heading: some View {
        Text(string("text", "Heading"))
            .font(.system(size: max(10, double("size")), weight: fontWeight("weight")))
            .foregroundStyle(color("color", fallback: "#111827"))
            .multilineTextAlignment(textAlignment("align"))
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment("align"))
    }

    private var bodyText: some View {
        Text(string("content"))
            .font(.system(size: max(8, double("size"))))
            .foregroundStyle(color("color", fallback: "#4B5563"))
            .multilineTextAlignment(textAlignment("align"))
            .lineSpacing(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment("align"))
    }

    private var dividerView: some View {
        VStack {
            Spacer(minLength: 0)
            Rectangle()
                .fill(color("color", fallback: "#E5E7EB"))
                .frame(height: 1)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Button

    private var buttonView: some View {
        Button {
            perform("onClick")
        } label: {
            HStack(spacing: 6) {
                if !string("icon").isEmpty {
                    Image(systemName: string("icon"))
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(string("label", "Button"))
                    .font(.system(size: 12.5, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(buttonForeground)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(buttonBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(buttonBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(boolean("disabled") ? 0.5 : 1)
        .allowsHitTesting(interactive && !boolean("disabled"))
    }

    private var buttonVariant: String { string("style", "primary") }

    private var buttonBackground: Color {
        switch buttonVariant {
        case "primary": return Color(hex: "#6366F1")
        case "secondary": return .white
        case "ghost": return .clear
        case "danger": return Color(hex: "#DC2626")
        default: return Color(hex: "#6366F1")
        }
    }

    private var buttonForeground: Color {
        switch buttonVariant {
        case "primary", "danger": return .white
        case "secondary": return Color(hex: "#111827")
        default: return Color(hex: "#4B5563")
        }
    }

    private var buttonBorder: Color {
        switch buttonVariant {
        case "secondary", "ghost": return Color(hex: "#DCE1E9")
        default: return .clear
        }
    }

    // MARK: - Inputs

    private func textInputView(numeric: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !string("label").isEmpty {
                Text(string("label"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color(hex: "#374151"))
            }

            TextField(string("placeholder"), text: inputBinding(numeric: numeric))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#111827"))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(hex: "#FFFFFF"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(hex: "#DCE1E9"), lineWidth: 1)
                )
                .onSubmit { perform("onSubmit") }
                .allowsHitTesting(interactive)

            if !string("helper").isEmpty {
                Text(string("helper"))
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func inputBinding(numeric: Bool) -> Binding<String> {
        Binding(
            get: {
                if let value = model.componentValue(component) {
                    return value.stringValue ?? ""
                }
                return model.stringValue(component, "defaultValue")
            },
            set: { newValue in
                guard interactive else { return }
                if numeric {
                    if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        model.setComponentValue(component, .null)
                    } else if let number = Double(newValue) {
                        model.setComponentValue(component, .number(number))
                    } else {
                        model.setComponentValue(component, .string(newValue))
                    }
                } else {
                    model.setComponentValue(component, .string(newValue))
                }
            }
        )
    }

    private var selectOptions: [ChoiceOption] {
        let raw = prop("options")
        switch raw {
        case .array(let values):
            return values.enumerated().map { index, item in
                if let object = item.objectValue {
                    return ChoiceOption(
                        label: object["label"]?.stringValue ?? object["value"]?.stringValue ?? "Option \(index + 1)",
                        value: object["value"]?.stringValue ?? item.display
                    )
                }
                return ChoiceOption(label: item.display, value: item.display)
            }
        default:
            return []
        }
    }

    private var selectValue: String {
        model.componentValue(component)?.stringValue ?? model.stringValue(component, "defaultValue")
    }

    private var selectView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !string("label").isEmpty {
                Text(string("label"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color(hex: "#374151"))
            }

            ZStack {
                HStack(spacing: 6) {
                    Text(selectOptions.first { $0.value == selectValue }?.label ?? "Select…")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#111827"))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                .padding(.horizontal, 9)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(hex: "#DCE1E9"), lineWidth: 1)
                )

                Menu {
                    ForEach(selectOptions) { option in
                        Button {
                            guard interactive else { return }
                            model.setComponentValue(component, .string(option.value))
                            perform("onChange")
                        } label: {
                            if option.value == selectValue {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .allowsHitTesting(interactive)
            }
            .frame(height: 30)

            if !string("helper").isEmpty {
                Text(string("helper"))
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Stat

    private var statView: some View {
        let accent = color("accent", fallback: "#6366F1")
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(string("label", "Metric").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Color(hex: "#6B7280"))
                    .lineLimit(1)
            }

            Text(string("value", "0"))
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#111827"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if !string("delta").isEmpty {
                Text(string("delta"))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#E8EBF0"), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(accent.opacity(0.09))
                .frame(width: 54, height: 54)
                .offset(x: 14, y: 14)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Panel

    private var panelView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !string("title").isEmpty {
                Text(string("title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#111827"))
                    .lineLimit(1)
            }
            if !string("subtitle").isEmpty {
                Text(string("subtitle"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(hex: "#9CA3AF"))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: max(0, double("radius")), style: .continuous)
                .fill(color("background", fallback: "#FFFFFF"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: max(0, double("radius")), style: .continuous)
                .stroke(boolean("border") ? Color(hex: "#E8EBF0") : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Table

    private var tableView: some View {
        let computation = model.computeTable(component)
        let tableState = model.runtime.tableStates[component.name] ?? TableRuntimeState()
        let showHeader = !string("title").isEmpty || boolean("searchable")

        return VStack(spacing: 0) {
            if showHeader {
                HStack(spacing: 10) {
                    if !string("title").isEmpty {
                        Text(string("title"))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color(hex: "#111827"))
                            .lineLimit(1)
                        Text("\(computation.totalRows)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "#6B7280"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "#F1F3F7")))
                    }

                    Spacer(minLength: 6)

                    if boolean("searchable") {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "#9CA3AF"))
                            TextField("Search…", text: Binding(
                                get: { tableState.search },
                                set: { model.updateTableSearch(component, search: $0) }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color(hex: "#111827"))
                            .allowsHitTesting(interactive)
                            if !tableState.search.isEmpty {
                                Button {
                                    model.updateTableSearch(component, search: "")
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color(hex: "#9CA3AF"))
                                }
                                .buttonStyle(.plain)
                                .allowsHitTesting(interactive)
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(width: 176, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: "#F5F6F9"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(hex: "#E4E7ED"), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
            }

            tableHeader(computation: computation, state: tableState)

            if computation.pageRows.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "tray")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color(hex: "#C3C9D3"))
                    Text(string("emptyMessage", "No rows to display"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(computation.pageRows.indices, id: \.self) { index in
                            tableRow(computation.pageRows[index], index: index, columns: computation.columns, state: tableState)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if computation.paginated {
                tableFooter(computation)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: "#E8EBF0"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func tableHeader(computation: TableComputation, state: TableRuntimeState) -> some View {
        HStack(spacing: 0) {
            ForEach(computation.columns, id: \.self) { column in
                Button {
                    guard interactive else { return }
                    model.toggleTableSort(component, key: column)
                } label: {
                    HStack(spacing: 4) {
                        Text(columnLabel(column))
                            .font(.system(size: 8.5, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Color(hex: "#6B7280"))
                            .lineLimit(1)
                        if boolean("sortable") {
                            Image(systemName: sortIcon(column: column, state: state))
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(state.sortKey == column ? Color(hex: "#6366F1") : Color(hex: "#C2C8D2"))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(interactive && boolean("sortable"))
            }
        }
        .frame(height: 27)
        .background(Color(hex: "#F7F8FA"))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: "#E8EBF0")).frame(height: 1)
        }
    }

    private func tableRow(_ row: JSONValue, index: Int, columns: [String], state: TableRuntimeState) -> some View {
        let selected = state.selectedRow == row
        return HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                cell(row[column] ?? .null, column: column)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(height: 31)
        .background(rowBackground(index: index, selected: selected))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: "#F0F2F5")).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard interactive else { return }
            model.selectTableRow(component, row: row)
        }
    }

    @ViewBuilder
    private func cell(_ value: JSONValue, column: String) -> some View {
        let key = column.lowercased()
        if key == "status" || key == "state" || key == "stage" {
            statusPill(value.display)
        } else if key.contains("mrr") || key.contains("revenue") || key.contains("amount") || key.contains("price") {
            Text(currency(value))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#111827"))
                .lineLimit(1)
        } else if key.contains("email") {
            Text(value.display)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(hex: "#4F46E5"))
                .lineLimit(1)
        } else if key == "id" || key.hasSuffix("_id") {
            Text(value.display)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: "#6B7280"))
                .lineLimit(1)
        } else {
            Text(value.display)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(hex: "#1F2937"))
                .lineLimit(1)
        }
    }

    private func statusPill(_ text: String) -> some View {
        let tone = statusTone(text)
        return Text(text.isEmpty ? "—" : text.capitalized)
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(tone.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tone.background))
            .lineLimit(1)
    }

    private func statusTone(_ status: String) -> (text: Color, background: Color) {
        switch status.lowercased() {
        case "active", "paid", "won", "complete", "completed":
            return (Color(hex: "#047857"), Color(hex: "#D1FAE5"))
        case "pending", "trial", "review":
            return (Color(hex: "#B45309"), Color(hex: "#FEF3C7"))
        case "churned", "cancelled", "canceled", "failed", "overdue":
            return (Color(hex: "#B91C1C"), Color(hex: "#FEE2E2"))
        case "new", "prospect":
            return (Color(hex: "#1D4ED8"), Color(hex: "#DBEAFE"))
        default:
            return (Color(hex: "#4B5563"), Color(hex: "#F1F3F7"))
        }
    }

    private func rowBackground(index: Int, selected: Bool) -> Color {
        if selected { return Color(hex: "#EEF0FF") }
        if boolean("striped"), index % 2 == 1 { return Color(hex: "#FAFBFC") }
        return .white
    }

    private func tableFooter(_ computation: TableComputation) -> some View {
        HStack(spacing: 8) {
            Text("\(computation.rangeStart)–\(computation.rangeEnd) of \(computation.totalRows)")
                .font(.system(size: 9.5))
                .foregroundStyle(Color(hex: "#6B7280"))

            Spacer(minLength: 0)

            Text("Page \(computation.page) of \(computation.pageCount)")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color(hex: "#6B7280"))

            HStack(spacing: 2) {
                footerButton(icon: "chevron.left", enabled: computation.page > 1) {
                    model.setTablePage(component, page: computation.page - 1)
                }
                footerButton(icon: "chevron.right", enabled: computation.page < computation.pageCount) {
                    model.setTablePage(component, page: computation.page + 1)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(hex: "#E8EBF0")).frame(height: 1)
        }
    }

    private func footerButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard interactive else { return }
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(enabled ? Color(hex: "#374151") : Color(hex: "#C7CCD5"))
                .frame(width: 21, height: 21)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(hex: "#F5F6F9"))
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
    }

    private func sortIcon(column: String, state: TableRuntimeState) -> String {
        if state.sortKey == column {
            return state.ascending ? "chevron.up" : "chevron.down"
        }
        return "arrow.up.arrow.down"
    }

    private func columnLabel(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private func currency(_ value: JSONValue) -> String {
        guard let number = value.doubleValue else { return value.display }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = number == number.rounded() ? 0 : 2
        return formatter.string(from: NSNumber(value: number)) ?? value.display
    }

    // MARK: - Chart

    private struct ChartPoint {
        var label: String
        var value: Double
    }

    private var chartPoints: [ChartPoint] {
        let rows = prop("data").arrayValue ?? []
        let xKey = string("xKey", "label")
        let yKey = string("yKey", "value")
        return rows.compactMap { row in
            guard let y = row[yKey]?.doubleValue else { return nil }
            return ChartPoint(label: row[xKey]?.display ?? "", value: y)
        }
    }

    private var chartView: some View {
        let points = chartPoints
        let accent = color("accent", fallback: "#6366F1")
        let type = string("chartType", "bar")

        return VStack(alignment: .leading, spacing: 6) {
            if !string("title").isEmpty {
                Text(string("title"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color(hex: "#111827"))
            }

            if points.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color(hex: "#C3C9D3"))
                    Text("No chart data")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    if type == "line" {
                        ForEach(points.indices, id: \.self) { index in
                            LineMark(
                                x: .value("X", points[index].label),
                                y: .value("Y", points[index].value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        }
                    } else if type == "area" {
                        ForEach(points.indices, id: \.self) { index in
                            AreaMark(
                                x: .value("X", points[index].label),
                                y: .value("Y", points[index].value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent.opacity(0.45), accent.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        ForEach(points.indices, id: \.self) { index in
                            LineMark(
                                x: .value("X", points[index].label),
                                y: .value("Y", points[index].value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(accent)
                        }
                    } else {
                        ForEach(points.indices, id: \.self) { index in
                            BarMark(
                                x: .value("X", points[index].label),
                                y: .value("Y", points[index].value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.62)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(3)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                            .foregroundStyle(boolean("showGrid") ? Color(hex: "#EDEFF3") : Color.clear)
                        AxisValueLabel()
                            .font(.system(size: 8.5))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 8.5))
                    }
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: "#E8EBF0"), lineWidth: 1)
        )
    }
}
