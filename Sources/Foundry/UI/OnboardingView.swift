import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var shell: AppShell

    @State private var step = 0
    @State private var appeared = false

    private let stepCount = OnboardingStep.all.count

    var body: some View {
        ZStack {
            backdrop
            card
        }
        .onAppear {
            step = min(max(shell.onboardingStartStep, 0), stepCount - 1)
            withAnimation(.easeOut(duration: 0.24)) { appeared = true }
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.58)
            Circle()
                .fill(Theme.accent.opacity(0.22))
                .frame(width: 700, height: 700)
                .blur(radius: 180)
                .offset(x: -420, y: -260)
            Circle()
                .fill(Theme.blue.opacity(0.12))
                .frame(width: 520, height: 520)
                .blur(radius: 160)
                .offset(x: 480, y: 280)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
    }

    private var card: some View {
        HStack(spacing: 0) {
            rail
            Rectangle()
                .fill(Theme.borderSoft)
                .frame(width: 1)
            content
        }
        .frame(width: 940, height: 540)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.55), radius: 40, y: 20)
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Rail

    private var rail: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#191D2A"), Theme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    brandMark
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Foundry")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("A quick tour")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 19)

                Hairline()

                VStack(spacing: 4) {
                    ForEach(Array(OnboardingStep.all.enumerated()), id: \.offset) { index, item in
                        stepRow(index: index, item: item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 9.5))
                        Text("Local-first · nothing leaves this Mac")
                            .font(.system(size: 9.5))
                    }
                    .foregroundStyle(Theme.textFaint)

                    Button("Skip for now") {
                        shell.finishOnboarding()
                    }
                    .buttonStyle(EditorButtonStyle(variant: .ghost, small: true))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 296)
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

    private func stepRow(index: Int, item: OnboardingStep) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { step = index }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(index == step ? Theme.accent : Theme.panelRaised)
                    Circle()
                        .stroke(index == step ? Color.clear : Theme.border, lineWidth: 1)
                    if index < step {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.green)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(index == step ? .white : Theme.textDim)
                    }
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index == step ? Theme.text : Theme.textDim)
                    Text(item.eyebrow)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer(minLength: 0)

                if index == step {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.accentBright)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(index == step ? Theme.accent.opacity(0.13) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(index == step ? Theme.accent.opacity(0.32) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "Step \(step + 1) of \(stepCount)")
                Spacer()
                Button {
                    shell.finishOnboarding()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.panelRaised))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close the tour")
            }
            .padding(.horizontal, 32)
            .frame(height: 56)
            .overlay(alignment: .bottom) { Hairline() }

            stepBody
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        Group {
            switch step {
            case 0: welcomeStep
            case 1: bindingStep
            default: startStep
            }
        }
        .id(step)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                heading("Build internal tools without leaving your Mac.")
                Text("Foundry is a local app builder for SQLite-backed tools. Design a screen, wire it to data, and put it to work.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textDim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                featureCard(
                    icon: "rectangle.3.group",
                    tint: Theme.accentBright,
                    title: "Drag-and-drop canvas",
                    detail: "Buttons, inputs, tables and more, arranged on a resizable page."
                )
                featureCard(
                    icon: "cylinder.split.1x2",
                    tint: Theme.blue,
                    title: "SQLite, natively",
                    detail: "Connect an existing .db file, or let Foundry seed a sample database."
                )
                featureCard(
                    icon: "chevron.left.forwardslash.chevron.right",
                    tint: Theme.green,
                    title: "Live bindings",
                    detail: "Reference query rows, component values and app state with {{ }}."
                )
                featureCard(
                    icon: "square.grid.2x2",
                    tint: Theme.amber,
                    title: "Templates",
                    detail: "CRUD, search, pagination and dashboards — ready to fork."
                )
            }

            HStack(spacing: 7) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.green)
                Text("No account, no cloud. Apps, templates and databases live in Application Support.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }

    private var bindingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                heading("Connect data, then bind the screen to it.")
                Text("Queries run against a SQLite file. Components read the results through expressions, so the UI stays in sync after every run.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textDim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    TagChip(text: "SQL")
                    Text("list_customers")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                        Text("read-only")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundStyle(Theme.green)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Theme.panelRaised)

                Hairline()

                sqlSample
                    .font(.system(size: 11, design: .monospaced))
                    .lineSpacing(3)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.borderSoft, lineWidth: 1)
            )

            VStack(spacing: 6) {
                bindingRow(code: "{{ queries.list_customers.data }}", use: "table rows", tint: Theme.blue)
                bindingRow(code: "{{ components.searchInput.value }}", use: "filter value", tint: Theme.accentBright)
                bindingRow(code: "{{ state.selectedCustomer.name }}", use: "detail title", tint: Theme.amber)
            }

            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.green)
                Text("Use double braces for escaped SQL values and triple braces for trusted fragments like ORDER BY.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }

    private var sqlSample: Text {
        Text("SELECT id, name, email, mrr\nFROM customers\nWHERE name LIKE '%' || ")
            .foregroundColor(Theme.text)
            + Text("{{ components.searchInput.value }}")
            .foregroundColor(Theme.accentBright)
            + Text("\nORDER BY ")
            .foregroundColor(Theme.text)
            + Text("{{{ state.sortOrder }}}")
            .foregroundColor(Theme.amber)
            + Text("\nLIMIT 25;")
            .foregroundColor(Theme.text)
    }

    private var startStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                heading("Pick a starting point.")
                Text("Every template ships with a seeded database, working queries and a finished layout. Fork it, rename it, or start from an empty canvas.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textDim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 9
            ) {
                ForEach(TemplateCatalog.builtIns) { template in
                    TemplateStartCard(template: template) {
                        shell.finishOnboarding()
                        shell.createApp(from: template)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Browse all templates") {
                    shell.finishOnboarding()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        shell.showTemplates = true
                    }
                }
                .buttonStyle(EditorButtonStyle(variant: .secondary))

                Button("Start with a blank app") {
                    shell.finishOnboarding()
                    shell.newBlankApp()
                }
                .buttonStyle(EditorButtonStyle(variant: .ghost))

                Spacer(minLength: 0)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Theme.accent : Theme.border)
                    .frame(width: index == step ? 18 : 6, height: 6)
            }

            Spacer()

            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.22)) { step -= 1 }
                }
                .buttonStyle(EditorButtonStyle(variant: .secondary))
            }

            Button(step == stepCount - 1 ? "Finish tour" : "Continue") {
                advance()
            }
            .buttonStyle(EditorButtonStyle(variant: .primary))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 32)
        .frame(height: 68)
        .background(Theme.panelRaised.opacity(0.32))
        .overlay(alignment: .top) { Hairline() }
    }

    // MARK: - Pieces

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(Theme.text)
            .lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func featureCard(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textDim)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.panelRaised.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Theme.borderSoft, lineWidth: 1)
        )
    }

    private func bindingRow(code: String, use: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text(code)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(use)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.field.opacity(0.7)))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Theme.borderSoft, lineWidth: 1)
        )
    }

    private func advance() {
        if step >= stepCount - 1 {
            shell.finishOnboarding()
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) { step += 1 }
    }
}

private struct OnboardingStep {
    let title: String
    let eyebrow: String

    static let all = [
        OnboardingStep(title: "Welcome", eyebrow: "What Foundry is"),
        OnboardingStep(title: "Data & bindings", eyebrow: "SQLite + live values"),
        OnboardingStep(title: "Start building", eyebrow: "Templates or blank")
    ]
}

private struct TemplateStartCard: View {
    let template: AppTemplate
    let onUse: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onUse) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accent.opacity(0.16))
                    Image(systemName: template.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accentBright)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(template.badges.prefix(2).joined(separator: " · "))
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(hovering ? Theme.accentBright : Theme.textFaint)
            }
            .padding(.horizontal, 11)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.panelRaised.opacity(hovering ? 0.9 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(hovering ? Theme.accent.opacity(0.5) : Theme.borderSoft, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
