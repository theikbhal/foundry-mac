import Foundation

struct QueryRuntimeState {
    var data: [JSONValue] = []
    var columns: [String] = []
    var rowCount: Int = 0
    var affectedRows: Int = 0
    var error: String? = nil
    var loading: Bool = false
    var ranAt: Date? = nil
    var durationMS: Double = 0
    var executedSQL: String = ""
}

struct TableRuntimeState {
    var search: String = ""
    var page: Int = 1
    var pageSize: Int = 8
    var sortKey: String? = nil
    var ascending: Bool = true
    var selectedRow: JSONValue? = nil
    var initialized: Bool = false
}

final class AppRuntime {
    var queryStates: [String: QueryRuntimeState] = [:]
    var componentValues: [String: JSONValue] = [:]
    var tableStates: [String: TableRuntimeState] = [:]
    var appState: [String: JSONValue] = [:]

    private var cachedContextJSON: String?

    func invalidate() {
        cachedContextJSON = nil
    }

    func contextJSON(document: AppDocument, pageID: UUID) -> String {
        if let cachedContextJSON { return cachedContextJSON }

        var queries: [String: Any] = [:]
        for query in document.queries {
            let state = queryStates[query.name] ?? QueryRuntimeState()
            queries[query.name] = [
                "data": state.data.map { $0.any },
                "columns": state.columns,
                "rowCount": state.rowCount,
                "affectedRows": state.affectedRows,
                "error": state.error ?? NSNull(),
                "loading": state.loading,
                "ranAt": state.ranAt.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
                "durationMS": state.durationMS
            ]
        }

        var components: [String: Any] = [:]
        for page in document.pages {
            for component in page.components {
                var info: [String: Any] = [
                    "type": component.type.rawValue,
                    "value": componentValues[component.name]?.any ?? NSNull()
                ]
                if let table = tableStates[component.name] {
                    info["search"] = table.search
                    info["page"] = table.page
                    info["pageSize"] = table.pageSize
                    info["sortKey"] = table.sortKey ?? NSNull()
                    info["sortAscending"] = table.ascending
                    info["selectedRow"] = table.selectedRow?.any ?? NSNull()
                } else if component.type == .table {
                    info["selectedRow"] = NSNull()
                }
                components[component.name] = info
            }
        }

        var stateValues = document.state
        for (key, value) in appState {
            stateValues[key] = value
        }

        let page = document.page(id: pageID)
        let payload: [String: Any] = [
            "queries": queries,
            "components": components,
            "state": stateValues.mapValues { $0.any },
            "page": [
                "id": page?.id.uuidString ?? "",
                "name": page?.name ?? ""
            ],
            "app": [
                "id": document.id.uuidString,
                "name": document.name
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            cachedContextJSON = "{}"
            return "{}"
        }
        cachedContextJSON = json
        return json
    }
}
