import Foundation
import Darwin

/// Dev helper: `Foundry --selftest /tmp/foundry-selftest.json` exercises the
/// built-in templates end to end and exits with a non-zero code on failure.
@MainActor
enum SelfTest {
    private struct Check {
        var name: String
        var passed: Bool
        var detail: String
    }

    private static var checks: [Check] = []

    private static func check(_ name: String, _ condition: Bool, _ detail: String = "") {
        checks.append(Check(name: name, passed: condition, detail: detail))
    }

    private static func component(_ model: EditorModel, _ name: String) -> CanvasComponent? {
        model.document.pages.flatMap(\.components).first { $0.name == name }
    }

    @discardableResult
    private static func setValue(_ model: EditorModel, _ name: String, _ value: JSONValue) -> Bool {
        guard let component = component(model, name) else {
            check("component \(name) exists", false, "Missing component \(name)")
            return false
        }
        model.setComponentValue(component, value)
        return true
    }

    private static func rows(_ model: EditorModel, _ query: String) -> [JSONValue] {
        model.runtime.queryStates[query]?.data ?? []
    }

    private static func rowCount(_ model: EditorModel, _ query: String) -> Int {
        model.runtime.queryStates[query]?.rowCount ?? -1
    }

    private static func scalar(_ path: String, _ sql: String) -> Int? {
        guard let result = try? SQLiteEngine.query(sql, path: path, readOnly: true),
              let row = result.rows.first,
              let value = row.first else { return nil }
        return value.intValue.map(Int.init)
    }

    static func run(writingTo url: URL) async {
        checks = []
        let store = AppStore.shared
        var documents: [AppDocument] = []
        var models: [EditorModel] = []
        var userTemplateIDs: [String] = []

        // MARK: CRUD

        let crudDocument = store.instantiate(TemplateCatalog.crud, name: "SelfTest CRUD")
        documents.append(crudDocument)
        let crud = EditorModel(document: crudDocument, store: store)
        models.append(crud)
        await crud.start()

        check("crud reads seeded rows", rowCount(crud, "get_customers") == 30,
              "get_customers returned \(rowCount(crud, "get_customers")) rows")

        if let planField = component(crud, "customerPlan"), let statusField = component(crud, "customerStatus") {
            check("form defaults seeded",
                  crud.componentValue(planField) == .string("Starter")
                      && crud.componentValue(statusField) == .string("active"),
                  "plan=\(crud.componentValue(planField)?.display ?? "nil") status=\(crud.componentValue(statusField)?.display ?? "nil")")
        } else {
            check("form defaults seeded", false, "Detail form fields were not found")
        }

        let insertedEmail = "selftest.\(UUID().uuidString.prefix(8))@foundry.dev"
        setValue(crud, "customerName", .string("Self Test"))
        setValue(crud, "customerEmail", .string(insertedEmail))
        setValue(crud, "customerCompany", .string("Foundry QA"))
        setValue(crud, "customerMrr", .string("321"))
        crud.setStateValue(key: "selectedCustomer", value: .null)

        let inserted = await crud.runQuery(named: "save_customer")
        await crud.runQuery(named: "get_customers")
        let insertedRow = rows(crud, "get_customers").first { $0["email"]?.stringValue == insertedEmail }
        check("crud insert",
              inserted && rowCount(crud, "get_customers") == 31 && insertedRow != nil
                  && insertedRow?["plan"]?.stringValue == "Starter"
                  && insertedRow?["status"]?.stringValue == "active",
              "inserted=\(inserted) rows=\(rowCount(crud, "get_customers")) found=\(insertedRow != nil) plan=\(insertedRow?["plan"]?.stringValue ?? "nil") status=\(insertedRow?["status"]?.stringValue ?? "nil")")

        if let insertedRow, let id = insertedRow["id"] {
            crud.setStateValue(key: "selectedCustomer", value: insertedRow)
            setValue(crud, "customerName", .string("Self Test Updated"))
            setValue(crud, "customerMrr", .string("654"))
            let updated = await crud.runQuery(named: "save_customer")
            await crud.runQuery(named: "get_customers")
            let updatedRow = rows(crud, "get_customers").first { $0["id"] == id }
            let mrr = updatedRow?["mrr"]?.doubleValue
            check("crud update",
                  updated && rowCount(crud, "get_customers") == 31 && mrr == 654
                      && updatedRow?["name"]?.stringValue == "Self Test Updated",
                  "updated=\(updated) rows=\(rowCount(crud, "get_customers")) mrr=\(mrr.map { String($0) } ?? "nil")")

            crud.setStateValue(key: "selectedCustomer", value: insertedRow)
            let deleted = await crud.runQuery(named: "delete_customer")
            await crud.runQuery(named: "get_customers")
            let stillThere = rows(crud, "get_customers").contains { $0["id"] == id }
            check("crud delete",
                  deleted && rowCount(crud, "get_customers") == 30 && !stillThere,
                  "deleted=\(deleted) rows=\(rowCount(crud, "get_customers")) stillThere=\(stillThere)")
        } else {
            check("crud update", false, "Inserted row was not found")
            check("crud delete", false, "Inserted row was not found")
        }

        // MARK: Pagination

        let paginationDocument = store.instantiate(TemplateCatalog.pagination, name: "SelfTest Pagination")
        documents.append(paginationDocument)
        let paging = EditorModel(document: paginationDocument, store: store)
        models.append(paging)
        await paging.start()

        let firstPageNames = rows(paging, "page_customers").compactMap { $0["name"]?.stringValue }
        let totalCustomers = rows(paging, "count_customers").first?["total"]?.intValue
        check("pagination page 1",
              rowCount(paging, "page_customers") == 8 && totalCustomers == 30,
              "rows=\(rowCount(paging, "page_customers")) total=\(totalCustomers.map { String($0) } ?? "nil")")

        paging.setStateValue(key: "page", value: .number(2))
        await paging.runQuery(named: "page_customers")
        let secondPageNames = rows(paging, "page_customers").compactMap { $0["name"]?.stringValue }
        check("pagination page 2",
              secondPageNames.count == 8 && Set(firstPageNames).isDisjoint(with: Set(secondPageNames)),
              "rows=\(secondPageNames.count) overlap=\(!Set(firstPageNames).isDisjoint(with: Set(secondPageNames)))")

        paging.setStateValue(key: "page", value: .number(4))
        await paging.runQuery(named: "page_customers")
        check("pagination last page", rowCount(paging, "page_customers") == 6,
              "rows=\(rowCount(paging, "page_customers"))")

        paging.setStateValue(key: "page", value: .number(1))
        paging.setStateValue(key: "pageSize", value: .number(20))
        await paging.runQuery(named: "page_customers")
        check("pagination page size", rowCount(paging, "page_customers") == 20,
              "rows=\(rowCount(paging, "page_customers"))")

        // MARK: Search

        let searchDocument = store.instantiate(TemplateCatalog.search, name: "SelfTest Search")
        documents.append(searchDocument)
        let search = EditorModel(document: searchDocument, store: store)
        models.append(search)
        await search.start()

        check("search empty returns all", rowCount(search, "search_customers") == 30,
              "rows=\(rowCount(search, "search_customers"))")

        setValue(search, "searchInput", .string("labs"))
        let labsRan = await search.runQuery(named: "search_customers")
        let labsRows = rows(search, "search_customers")
        let allMatch = labsRows.allSatisfy { row in
            ["name", "company", "email", "plan"].contains { key in
                (row[key]?.stringValue ?? "").lowercased().contains("labs")
            }
        }
        check("search filters by company",
              labsRan && !labsRows.isEmpty && labsRows.count < 30 && allMatch,
              "rows=\(labsRows.count) allMatch=\(allMatch)")

        setValue(search, "searchInput", .string("ada"))
        await search.runQuery(named: "search_customers")
        let adaNames = rows(search, "search_customers").compactMap { $0["name"]?.stringValue }
        check("search matches email", adaNames.contains("Ada Lovelace"),
              "matches=\(adaNames.prefix(3).joined(separator: ", "))")

        setValue(search, "searchInput", .string("' OR 1=1; DROP TABLE customers; --"))
        let injectedRan = await search.runQuery(named: "search_customers")
        let tablePath = searchDocument.connections.first?.path ?? ""
        let surviving = scalar(tablePath, "SELECT COUNT(*) FROM customers;")
        check("search escapes quotes",
              injectedRan && rowCount(search, "search_customers") == 0 && surviving == 30,
              "ran=\(injectedRan) rows=\(rowCount(search, "search_customers")) surviving=\(surviving.map { String($0) } ?? "nil")")

        // MARK: Sort

        let sortDocument = store.instantiate(TemplateCatalog.sort, name: "SelfTest Sort")
        documents.append(sortDocument)
        let sort = EditorModel(document: sortDocument, store: store)
        models.append(sort)
        await sort.start()

        let defaultNames = rows(sort, "sort_customers").compactMap { $0["name"]?.stringValue }
        check("sort defaults to name asc",
              rowCount(sort, "sort_customers") == 30 && defaultNames.first == "Ada Lovelace",
              "rows=\(rowCount(sort, "sort_customers")) first=\(defaultNames.first ?? "nil")")

        sort.setStateValue(key: "sortKey", value: .string("mrr"))
        sort.setStateValue(key: "sortDir", value: .string("desc"))
        let sortedRan = await sort.runQuery(named: "sort_customers")
        let mrrValues = rows(sort, "sort_customers").compactMap { $0["mrr"]?.doubleValue }
        let descending = zip(mrrValues, mrrValues.dropFirst()).allSatisfy { $0 >= $1 }
        check("sort orders by mrr desc",
              sortedRan && mrrValues.count == 30 && descending && mrrValues.first == 1500,
              "rows=\(mrrValues.count) descending=\(descending) first=\(mrrValues.first.map { String($0) } ?? "nil")")

        sort.setStateValue(key: "sortKey", value: .string("name; DROP TABLE customers"))
        sort.setStateValue(key: "sortDir", value: .string("asc"))
        let whitelistRan = await sort.runQuery(named: "sort_customers")
        let whitelistNames = rows(sort, "sort_customers").compactMap { $0["name"]?.stringValue }
        let whitelistPath = sortDocument.connections.first?.path ?? ""
        let whitelistSurviving = scalar(whitelistPath, "SELECT COUNT(*) FROM customers;")
        check("sort whitelists columns",
              whitelistRan && whitelistNames.first == "Ada Lovelace" && whitelistSurviving == 30,
              "ran=\(whitelistRan) rows=\(whitelistNames.count) surviving=\(whitelistSurviving.map { String($0) } ?? "nil")")

        // MARK: Dashboard

        let dashboardDocument = store.instantiate(TemplateCatalog.dashboard, name: "SelfTest Dashboard")
        documents.append(dashboardDocument)
        let dashboard = EditorModel(document: dashboardDocument, store: store)
        models.append(dashboard)
        await dashboard.start()

        let planRows = rows(dashboard, "mrr_by_plan")
        check("dashboard queries run",
              rowCount(dashboard, "list_customers") == 30 && planRows.count == 4
                  && planRows.allSatisfy { $0["plan"] != nil && $0["mrr"] != nil },
              "customers=\(rowCount(dashboard, "list_customers")) plans=\(planRows.count)")

        // MARK: Clone / fork / export

        let clone = store.cloneApp(paginationDocument)
        documents.append(clone)
        let clonePath = clone.connections.first?.path ?? ""
        let cloneCount = scalar(clonePath, "SELECT COUNT(*) FROM customers;")
        let connectionRemapped = clone.queries.allSatisfy { query in
            query.connectionId == nil || clone.connections.contains { $0.id == query.connectionId }
        }
        check("clone copies app and database",
              clone.id != paginationDocument.id && cloneCount == 30 && connectionRemapped,
              "id differs=\(clone.id != paginationDocument.id) rows=\(cloneCount.map { String($0) } ?? "nil") remapped=\(connectionRemapped)")

        let fork = store.forkTemplate(TemplateCatalog.sort)
        userTemplateIDs.append(fork.id)
        let forked = store.listUserTemplates().contains { $0.id == fork.id }
        check("fork saves user template", forked, "forked=\(forked) name=\(fork.name)")

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("foundry-selftest-\(UUID().uuidString).json")
        let exportedTemplate = store.makeTemplate(from: crudDocument, name: "SelfTest Export")
        var exportOK = false
        var importOK = false
        do {
            try store.exportTemplate(exportedTemplate, to: exportURL)
            exportOK = FileManager.default.fileExists(atPath: exportURL.path)
            let imported = try store.importTemplate(from: exportURL)
            userTemplateIDs.append(imported.id)
            importOK = store.listUserTemplates().contains { $0.id == imported.id }
                && (imported.seedSQL ?? "").contains("CREATE TABLE")
        } catch {
            check("export error", false, error.localizedDescription)
        }
        check("export and import template", exportOK && importOK,
              "exported=\(exportOK) imported=\(importOK)")
        try? FileManager.default.removeItem(at: exportURL)

        // MARK: Cleanup

        for model in models { model.flush() }
        for document in documents { store.deleteApp(document) }
        for id in userTemplateIDs { store.deleteUserTemplate(id: id) }

        // MARK: Report

        let passed = checks.allSatisfy(\.passed)
        let payload: JSONValue = .object([
            "passed": .bool(passed),
            "checks": .array(checks.map { check in
                .object([
                    "name": .string(check.name),
                    "passed": .bool(check.passed),
                    "detail": .string(check.detail)
                ])
            })
        ])
        let text = payload.prettyJSON
        try? text.write(to: url, atomically: true, encoding: .utf8)
        NSLog("Foundry self-test: \(checks.filter(\.passed).count)/\(checks.count) checks passed")
        exit(passed ? 0 : 1)
    }
}
