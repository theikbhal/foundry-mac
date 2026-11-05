import Foundation
import SwiftUI

@MainActor
final class AppShell: ObservableObject {
    static let shared = AppShell()

    @Published var editor: EditorModel?
    @Published var showTemplates = false
    @Published var alertMessage: String?
    var presentTemplatesOnLaunch = false

    let store = AppStore.shared

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--demo") {
            let base: AppDocument
            if let existing = store.listApps().first {
                base = existing
            } else {
                base = store.instantiate(TemplateCatalog.crud)
            }
            let document = arguments.contains("--dashboard") ? Self.dashboardPreview(base: base) : base
            let model = EditorModel(document: document, store: store)
            if arguments.contains("--preview") {
                model.isPreview = true
            }
            if arguments.contains("--query"), let query = document.queries.first {
                model.selectedQueryID = query.id
            }
            editor = model
        } else if arguments.contains("--templates") {
            presentTemplatesOnLaunch = true
        }
    }

    /// Dev-only: render the dashboard template against the demo app's seeded
    /// database without persisting any changes.
    private static func dashboardPreview(base: AppDocument) -> AppDocument {
        let template = TemplateCatalog.dashboard
        var document = base
        document.pages = template.pages.map { templatePage in
            var page = AppPage(name: templatePage.name)
            page.backgroundHex = templatePage.backgroundHex
            page.width = templatePage.width
            page.height = templatePage.height
            page.components = templatePage.components
            return page
        }
        document.queries = template.queries.map { query in
            AppQuery(
                name: query.name,
                connectionId: base.connections.first?.id,
                sql: query.sql,
                runOnLoad: query.runOnLoad,
                readOnly: query.readOnly
            )
        }
        document.state = template.state
        return document
    }

    func open(_ document: AppDocument) {
        editor?.flush()
        editor = EditorModel(document: document, store: store)
    }

    func openApp(id: UUID) {
        guard let document = store.loadApp(id: id) else {
            alertMessage = "That app could not be loaded."
            return
        }
        open(document)
    }

    func closeEditor() {
        editor?.flush()
        editor = nil
    }

    func newBlankApp() {
        open(store.createBlankApp())
    }

    func createApp(from template: AppTemplate) {
        showTemplates = false
        open(store.instantiate(template))
    }

    func cloneApp(_ document: AppDocument) {
        open(store.cloneApp(document))
    }

    func deleteApp(_ document: AppDocument) {
        if editor?.document.id == document.id {
            editor = nil
        }
        store.deleteApp(document)
    }

    func exportAsTemplate(_ document: AppDocument) {
        let template = store.makeTemplate(from: document)
        guard let url = FileDialogs.saveTemplate(named: template.name) else { return }
        do {
            try store.exportTemplate(template, to: url)
            alertMessage = "Template exported to \(url.lastPathComponent)."
        } catch {
            alertMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func exportCurrentAppAsTemplate() {
        guard let editor else { return }
        editor.flush()
        let template = store.makeTemplate(from: editor.document)
        guard let url = FileDialogs.saveTemplate(named: template.name) else { return }
        do {
            try store.exportTemplate(template, to: url)
            editor.showToast("Template exported")
        } catch {
            editor.showToast("Export failed: \(error.localizedDescription)", kind: .error)
        }
    }

    func importTemplateFromDisk() {
        guard let url = FileDialogs.openTemplate() else { return }
        do {
            _ = try store.importTemplate(from: url)
            showTemplates = true
        } catch {
            alertMessage = "Could not import template: \(error.localizedDescription)"
        }
    }

    func forkTemplate(_ template: AppTemplate) -> AppTemplate {
        store.forkTemplate(template)
    }

    func allTemplates() -> [AppTemplate] {
        TemplateCatalog.builtIns + store.listUserTemplates()
    }
}
