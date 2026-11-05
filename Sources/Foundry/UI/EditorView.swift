import SwiftUI

struct EditorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if model.isPreview {
                PreviewView(model: model)
            } else {
                editorChrome
            }

            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 26)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.isPreview)
        .animation(.easeOut(duration: 0.2), value: model.toast)
        .task {
            await model.start()
        }
    }

    private var editorChrome: some View {
        VStack(spacing: 0) {
            EditorTopBar(model: model)
            Hairline()

            HStack(spacing: 0) {
                SidebarView(model: model)
                    .frame(width: 286)

                Rectangle()
                    .fill(Theme.borderSoft)
                    .frame(width: 1)

                VStack(spacing: 0) {
                    CanvasArea(model: model)

                    if model.selectedQuery != nil {
                        Hairline()
                        QueryPanel(model: model)
                            .frame(height: 306)
                            .transition(.move(edge: .bottom))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(Theme.borderSoft)
                    .frame(width: 1)

                InspectorView(model: model)
                    .frame(width: 316)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.selectedQuery != nil)
    }
}

private struct EditorTopBar: View {
    @ObservedObject var model: EditorModel
    @EnvironmentObject private var shell: AppShell

    @State private var renamingPageID: UUID?
    @State private var pageNameDraft = ""
    @State private var showRenameAlert = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                shell.closeEditor()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Apps")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(Theme.textDim)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.panelRaised))
            }
            .buttonStyle(.plain)
            .help("Back to apps")

            Rectangle()
                .fill(Theme.borderSoft)
                .frame(width: 1, height: 24)

            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accentBright, Theme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 26, height: 26)

                TextField("App name", text: Binding(
                    get: { model.document.name },
                    set: { model.renameApp($0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 148)
            }

            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 9))
                Text("Autosave")
                    .font(.system(size: 9.5))
            }
            .foregroundStyle(Theme.textFaint)

            Rectangle()
                .fill(Theme.borderSoft)
                .frame(width: 1, height: 24)

            pageTabs

            IconButton(icon: "plus", help: "Add page", size: 24) {
                model.addPage()
            }

            Spacer(minLength: 8)

            IconButton(icon: "arrow.clockwise", help: "Re-run queries on load") {
                Task { await model.runOnLoadQueries() }
            }

            Button {
                model.isPreview = true
            } label: {
                Label("Preview", systemImage: "play.fill")
            }
            .buttonStyle(EditorButtonStyle(variant: .secondary, small: true))
            .keyboardShortcut("p", modifiers: [.command, .option])

            Menu {
                Button("Clone app") {
                    model.flush()
                    shell.cloneApp(model.document)
                }
                Button("Export as template…") {
                    shell.exportCurrentAppAsTemplate()
                }
                Button("Import template…") {
                    shell.importTemplateFromDisk()
                }
                Divider()
                Button("Browse templates…") {
                    shell.showTemplates = true
                }
                Divider()
                Button("Back to apps") {
                    shell.closeEditor()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.panelRaised))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.leading, 88)
        .padding(.trailing, 14)
        .frame(height: 52)
        .background(Theme.panel)
        .background(WindowDragArea())
        .alert("Rename page", isPresented: $showRenameAlert) {
            TextField("Page name", text: $pageNameDraft)
            Button("Rename") {
                if let id = renamingPageID {
                    model.renamePage(id, to: pageNameDraft)
                }
                renamingPageID = nil
            }
            Button("Cancel", role: .cancel) {
                renamingPageID = nil
            }
        } message: {
            Text("Choose a short name for this page.")
        }
    }

    private var pageTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(model.document.pages) { page in
                    let active = page.id == model.activePageID
                    Button {
                        model.selectPage(page.id)
                    } label: {
                        HStack(spacing: 5) {
                            if active {
                                Circle()
                                    .fill(Theme.accentBright)
                                    .frame(width: 4, height: 4)
                            }
                            Text(page.name)
                                .font(.system(size: 11, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? Theme.text : Theme.textDim)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(active ? Theme.panelRaised : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(active ? Theme.border : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Rename…") {
                            renamingPageID = page.id
                            pageNameDraft = page.name
                            showRenameAlert = true
                        }
                        Button("Delete page", role: .destructive) {
                            model.deletePage(page.id)
                        }
                        .disabled(model.document.pages.count <= 1)
                    }
                }
            }
        }
        .frame(maxWidth: 380)
    }
}

private struct PreviewView: View {
    @ObservedObject var model: EditorModel
    @EnvironmentObject private var shell: AppShell

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    PageCanvas(model: model)
                        .padding(40)
                        .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .center)
                }
            }

            VStack {
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.green)
                        Text("PREVIEW")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textDim)
                        Text(model.document.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(Theme.panelRaised))
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))

                    Spacer()

                    if model.document.pages.count > 1 {
                        Menu {
                            ForEach(model.document.pages) { page in
                                Button(page.name) { model.selectPage(page.id) }
                            }
                        } label: {
                            Label(model.currentPage?.name ?? "Page", systemImage: "rectangle.on.rectangle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(Capsule().fill(Theme.panelRaised))
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }

                    Button {
                        Task { await model.runOnLoadQueries() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.panelRaised))
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh data")

                    Button {
                        model.isPreview = false
                    } label: {
                        Label("Done", systemImage: "pencil")
                    }
                    .buttonStyle(EditorButtonStyle(variant: .primary, small: true))
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(20)

                Spacer()
            }
        }
    }
}
