import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var shell: AppShell

    @State private var apps: [AppDocument] = []
    @State private var pendingDelete: AppDocument?
    @State private var showDeleteConfirm = false
    @State private var notice: String?

    private let columns = [GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 16)]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        appsSection
                        templatesSection
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 30)
                    .padding(.bottom, 44)
                    .frame(maxWidth: 1240, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                footer
            }
        }
        .onAppear(perform: reload)
        .alert("Delete “\(pendingDelete?.name ?? "app")”?", isPresented: $showDeleteConfirm, presenting: pendingDelete) { app in
            Button("Delete", role: .destructive) {
                shell.deleteApp(app)
                reload()
                flash("App deleted")
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This removes the app and its app-owned sample database. External SQLite files are not touched.")
        }
        .overlay(alignment: .bottom) {
            if let notice {
                Text(notice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Theme.panelRaised))
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                    .padding(.bottom, 22)
                    .transition(.opacity)
            }
        }
    }

    private var background: some View {
        ZStack {
            Theme.background
            Circle()
                .fill(Theme.accent.opacity(0.16))
                .frame(width: 620, height: 620)
                .blur(radius: 150)
                .offset(x: -520, y: -340)
            Circle()
                .fill(Theme.blue.opacity(0.08))
                .frame(width: 520, height: 520)
                .blur(radius: 140)
                .offset(x: 560, y: 320)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 14) {
            brandMark
            VStack(alignment: .leading, spacing: 2) {
                Text("Foundry")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Local app builder for macOS")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }

            Spacer()

            Button {
                shell.showTemplates = true
            } label: {
                Label("Templates", systemImage: "square.grid.2x2")
            }
            .buttonStyle(EditorButtonStyle(variant: .secondary))

            Button {
                shell.importTemplateFromDisk()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(EditorButtonStyle(variant: .ghost))

            Button {
                shell.newBlankApp()
            } label: {
                Label("New app", systemImage: "plus")
            }
            .buttonStyle(EditorButtonStyle(variant: .primary))
        }
        .padding(.leading, 92)
        .padding(.trailing, 28)
        .frame(height: 64)
        .background(Theme.panel.opacity(0.65))
        .background(WindowDragArea())
        .overlay(alignment: .bottom) {
            Hairline()
        }
    }

    private var brandMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accentBright, Theme.accent, Color(hex: "#4338CA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "hammer.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 32, height: 32)
        .shadow(color: Theme.accent.opacity(0.45), radius: 12, y: 4)
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your apps")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("\(apps.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.panelRaised))
                Spacer()
                Text("Stored locally · no accounts, no cloud")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }

            if apps.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(apps) { app in
                        GalleryAppCard(
                            app: app,
                            onOpen: { shell.openApp(id: app.id) },
                            onClone: {
                                shell.cloneApp(app)
                            },
                            onExport: { export(app) },
                            onDelete: {
                                pendingDelete = app
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.panelRaised)
                Image(systemName: "hammer")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Theme.accentBright)
            }
            .frame(width: 64, height: 64)

            VStack(spacing: 5) {
                Text("Build your first app")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Drag components onto a canvas, connect a SQLite database, and ship an internal tool.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 10) {
                Button("New blank app") { shell.newBlankApp() }
                    .buttonStyle(EditorButtonStyle(variant: .primary))
                Button("Browse templates") { shell.showTemplates = true }
                    .buttonStyle(EditorButtonStyle(variant: .secondary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(Theme.border)
        )
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Start from a template")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("Browse all") { shell.showTemplates = true }
                    .buttonStyle(EditorButtonStyle(variant: .ghost, small: true))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TemplateCatalog.builtIns) { template in
                        TemplateStripCard(template: template) {
                            shell.createApp(from: template)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 10))
            Text("Apps, templates and app-owned SQLite files live in ~/Library/Application Support/Foundry")
                .font(.system(size: 10))
            Spacer()
            Text("v1.0")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Theme.textFaint)
        .padding(.horizontal, 32)
        .frame(height: 36)
        .background(Theme.panel.opacity(0.5))
        .overlay(alignment: .top) { Hairline() }
    }

    private func reload() {
        apps = shell.store.listApps()
    }

    private func export(_ app: AppDocument) {
        let template = shell.store.makeTemplate(from: app)
        guard let url = FileDialogs.saveTemplate(named: template.name) else { return }
        do {
            try shell.store.exportTemplate(template, to: url)
            flash("Exported \(url.lastPathComponent)")
        } catch {
            flash("Export failed: \(error.localizedDescription)")
        }
    }

    private func flash(_ message: String) {
        withAnimation(.easeOut(duration: 0.15)) { notice = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard notice == message else { return }
            withAnimation(.easeIn(duration: 0.2)) { notice = nil }
        }
    }
}

private struct GalleryAppCard: View {
    let app: AppDocument
    let onOpen: () -> Void
    let onClone: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewArt

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Menu {
                        Button("Open", action: onOpen)
                        Button("Clone app", action: onClone)
                        Button("Export as template…", action: onExport)
                        Divider()
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textDim)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panelRaised))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                HStack(spacing: 12) {
                    Label("\(app.pages.count) page\(app.pages.count == 1 ? "" : "s")", systemImage: "rectangle.on.rectangle")
                    Label("\(app.queries.count) quer\(app.queries.count == 1 ? "y" : "ies")", systemImage: "bolt")
                    Spacer()
                    Text(relativeDate(app.updatedAt))
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
            }
            .padding(13)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hovering ? Theme.accent.opacity(0.55) : Theme.borderSoft, lineWidth: 1)
        )
        .shadow(color: .black.opacity(hovering ? 0.35 : 0.18), radius: hovering ? 20 : 10, y: hovering ? 10 : 5)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: onOpen)
        .onHover { hovering = $0 }
    }

    private var previewArt: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: "#232840"), Color(hex: "#12141C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill((palette.first ?? Theme.accent).opacity(0.38))
                .frame(width: 130, height: 130)
                .blur(radius: 40)
                .offset(x: 160, y: -30)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<7, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(index == 0 ? 0.42 : 0.13))
                            .frame(width: index == 0 ? 34 : CGFloat(20 + (index * 7) % 16), height: 3)
                    }
                }
                .frame(width: 42, alignment: .leading)

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(palette[index % palette.count].opacity(0.28))
                                .overlay(alignment: .topLeading) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.22)).frame(width: 12, height: 2)
                                        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.5)).frame(width: 24, height: 4)
                                    }
                                    .padding(5)
                                }
                                .frame(height: 30)
                        }
                    }

                    VStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { index in
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.22)).frame(width: 34, height: 3)
                                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.14)).frame(width: 42, height: 3)
                                RoundedRectangle(cornerRadius: 2).fill((palette.first ?? Theme.accent).opacity(0.5)).frame(width: 18, height: 3)
                                Spacer(minLength: 0)
                            }
                            .opacity(index == 0 ? 0.9 : 0.6)
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.22)))
                }
            }
            .padding(14)
        }
        .frame(height: 112)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 14, style: .continuous))
        .overlay(alignment: .bottom) {
            Hairline(color: Theme.borderSoft)
        }
    }

    private var palette: [Color] {
        let palettes: [[Color]] = [
            [Theme.accent, Theme.blue, Theme.green],
            [Color(hex: "#F472B6"), Theme.accent, Theme.blue],
            [Theme.amber, Color(hex: "#FB7185"), Theme.accent],
            [Theme.green, Theme.blue, Theme.accentBright]
        ]
        let index = abs(app.id.uuidString.hashValue) % palettes.count
        return palettes[index]
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct TemplateStripCard: View {
    let template: AppTemplate
    let onUse: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onUse) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Theme.accent.opacity(0.16))
                        Image(systemName: template.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accentBright)
                    }
                    .frame(width: 28, height: 28)

                    Text(template.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text(template.summary)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .top)

                HStack(spacing: 5) {
                    ForEach(template.badges.prefix(3), id: \.self) { badge in
                        TagChip(text: badge)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(hovering ? Theme.accentBright : Theme.textFaint)
                }
            }
            .padding(12)
            .frame(width: 262, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.panel.opacity(hovering ? 0.95 : 0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(hovering ? Theme.accent.opacity(0.5) : Theme.borderSoft, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
