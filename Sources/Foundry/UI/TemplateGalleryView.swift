import SwiftUI

struct TemplateGalleryView: View {
    @EnvironmentObject private var shell: AppShell
    @Environment(\.dismiss) private var dismiss

    @State private var templates: [AppTemplate] = []
    @State private var pendingDelete: AppTemplate?
    @State private var showDeleteConfirm = false
    @State private var notice: String?

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 340), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section(title: "Built-in", subtitle: "Production-shaped starting points with seeded SQLite data.", items: builtIns)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("My templates")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("Forked or exported from your apps")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textFaint)
                        }

                        if userTemplates.isEmpty {
                            emptyMyTemplates
                        } else {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                                ForEach(userTemplates) { template in
                                    TemplateGalleryCard(
                                        template: template,
                                        onUse: { use(template) },
                                        onFork: { fork(template) },
                                        onExport: { export(template) },
                                        onDelete: {
                                            pendingDelete = template
                                            showDeleteConfirm = true
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(28)
            }
        }
        .frame(width: 1080, height: 748)
        .background(Theme.background)
        .onAppear(perform: reload)
        .alert("Delete template “\(pendingDelete?.name ?? "")”?", isPresented: $showDeleteConfirm, presenting: pendingDelete) { template in
            Button("Delete", role: .destructive) {
                shell.store.deleteUserTemplate(id: template.id)
                reload()
                flash("Template deleted")
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This only removes the saved template. Apps created from it are unaffected.")
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
                    .padding(.bottom, 20)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accent.opacity(0.18))
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentBright)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Templates")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Use one as-is, fork it into your library, or export it to share.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }

            Spacer()

            Button {
                importTemplate()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(EditorButtonStyle(variant: .secondary))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.panelRaised))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .background(Theme.panel.opacity(0.7))
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var builtIns: [AppTemplate] {
        templates.filter { $0.isBuiltIn }
    }

    private var userTemplates: [AppTemplate] {
        templates.filter { !$0.isBuiltIn }
    }

    @ViewBuilder
    private func section(title: String, subtitle: String, items: [AppTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(items) { template in
                    TemplateGalleryCard(
                        template: template,
                        onUse: { use(template) },
                        onFork: { fork(template) },
                        onExport: { export(template) },
                        onDelete: nil
                    )
                }
            }
        }
    }

    private var emptyMyTemplates: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textFaint)
            VStack(alignment: .leading, spacing: 3) {
                Text("No custom templates yet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Fork a built-in template, or export an app as a template from its card menu.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            Button("Browse apps") {
                dismiss()
            }
            .buttonStyle(EditorButtonStyle(variant: .secondary, small: true))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.panel.opacity(0.55)))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(Theme.border)
        )
    }

    private func reload() {
        templates = shell.allTemplates()
    }

    private func use(_ template: AppTemplate) {
        shell.createApp(from: template)
        dismiss()
    }

    private func fork(_ template: AppTemplate) {
        _ = shell.forkTemplate(template)
        reload()
        flash("Forked to My templates")
    }

    private func export(_ template: AppTemplate) {
        guard let url = FileDialogs.saveTemplate(named: template.name) else { return }
        do {
            try shell.store.exportTemplate(template, to: url)
            flash("Exported \(url.lastPathComponent)")
        } catch {
            flash("Export failed: \(error.localizedDescription)")
        }
    }

    private func importTemplate() {
        guard let url = FileDialogs.openTemplate() else { return }
        do {
            let template = try shell.store.importTemplate(from: url)
            reload()
            flash("Imported \(template.name)")
        } catch {
            flash("Import failed: \(error.localizedDescription)")
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

private struct TemplateGalleryCard: View {
    let template: AppTemplate
    let onUse: () -> Void
    let onFork: () -> Void
    let onExport: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(accent.opacity(0.16))
                    Image(systemName: template.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(template.isBuiltIn ? "Built-in · \(template.category)" : template.category)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer(minLength: 0)

                if template.isBuiltIn {
                    TagChip(text: "BUILT-IN")
                }
            }

            Text(template.summary)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textDim)
                .lineLimit(3)
                .frame(height: 46, alignment: .top)
                .multilineTextAlignment(.leading)

            HStack(spacing: 5) {
                ForEach(template.badges.prefix(4), id: \.self) { badge in
                    TagChip(text: badge)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 20)

            Spacer(minLength: 0)

            Hairline()

            HStack(spacing: 8) {
                Button("Use template", action: onUse)
                    .buttonStyle(EditorButtonStyle(variant: .primary, small: true))

                Button("Fork", action: onFork)
                    .buttonStyle(EditorButtonStyle(variant: .secondary, small: true))

                Spacer(minLength: 0)

                Menu {
                    Button("Export template…", action: onExport)
                    if let onDelete {
                        Divider()
                        Button("Delete", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 25, height: 25)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panelRaised))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(16)
        .frame(height: 238, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.borderSoft, lineWidth: 1)
        )
    }

    private var accent: Color {
        switch template.category {
        case "Dashboards": return Theme.amber
        case "Data apps": return Theme.accentBright
        default: return Theme.blue
        }
    }
}
