import SwiftUI
import UniformTypeIdentifiers

struct CanvasArea: View {
    @ObservedObject var model: EditorModel
    @State private var zoom: CGFloat = 0.7
    @State private var autoFit = true
    @State private var viewport: CGSize = .zero

    var body: some View {
        ZStack {
            Theme.canvas

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    ZoomedPage(model: model, zoom: zoom)
                        .padding(44)
                        .frame(
                            minWidth: max(0, proxy.size.width),
                            minHeight: max(0, proxy.size.height),
                            alignment: .center
                        )
                }
                .onAppear {
                    viewport = proxy.size
                    fit(to: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    viewport = newSize
                    if autoFit { fit(to: newSize) }
                }
                .onChange(of: model.activePageID) { _, _ in
                    if autoFit { fit(to: proxy.size) }
                }
            }

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    if let page = model.currentPage {
                        Text("\(page.components.count) component\(page.components.count == 1 ? "" : "s")")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.textFaint)
                        Rectangle().fill(Theme.borderSoft).frame(width: 1, height: 12)
                        Text("\(Int(page.width)) × \(Int(page.height))")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                    }

                    Rectangle().fill(Theme.borderSoft).frame(width: 1, height: 12)

                    zoomControl

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 9))
                        Text("Drag to move · grab corner to resize")
                            .font(.system(size: 9.5))
                    }
                    .foregroundStyle(Theme.textFaint)
                }
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.panel)
                        .overlay(Capsule().stroke(Theme.borderSoft, lineWidth: 1))
                )
                .padding(12)
            }
        }
        .onDeleteCommand {
            if let id = model.selectedComponentID {
                model.deleteComponent(id)
            }
        }
    }

    private var zoomControl: some View {
        HStack(spacing: 3) {
            Button {
                autoFit = false
                zoom = max(0.3, zoom - 0.1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)

            Text("\(Int((zoom * 100).rounded()))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textDim)
                .frame(width: 34)

            Button {
                autoFit = false
                zoom = min(1.6, zoom + 0.1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)

            Button("Fit") {
                autoFit = true
                fit(to: viewport)
            }
            .buttonStyle(.plain)
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(autoFit ? Theme.accentBright : Theme.textFaint)
            .padding(.horizontal, 4)
        }
    }

    private func fit(to size: CGSize) {
        guard let page = model.currentPage, size.width > 100, size.height > 100 else { return }
        let availableWidth = max(200, size.width - 104)
        let availableHeight = max(200, size.height - 100)
        let scale = min(availableWidth / page.width, availableHeight / page.height, 1)
        zoom = min(max(0.3, scale), 1)
    }
}

private struct ZoomedPage: View {
    @ObservedObject var model: EditorModel
    let zoom: CGFloat

    var body: some View {
        let page = model.currentPage
        let width = page?.width ?? 1200
        let height = page?.height ?? 820
        PageCanvas(model: model)
            .scaleEffect(zoom, anchor: .topLeading)
            .frame(width: width * zoom, height: height * zoom, alignment: .topLeading)
    }
}

struct PageCanvas: View {
    @ObservedObject var model: EditorModel

    private var page: AppPage {
        model.currentPage ?? AppPage(name: "Page 1")
    }

    private var editable: Bool { !model.isPreview }

    var body: some View {
        ZStack(alignment: .topLeading) {
            pageBackground

            ForEach(page.components) { component in
                if editable || !component.hidden {
                    CanvasNode(model: model, component: component, page: page, editable: editable)
                }
            }

            if editable && page.components.isEmpty {
                emptyHint
                    .frame(width: page.width, height: page.height)
                    .allowsHitTesting(false)
            }

            if editable && model.isDropTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.accent.opacity(0.04))
                    )
                    .allowsHitTesting(false)
            }
        }
        .frame(width: page.width, height: page.height, alignment: .topLeading)
        .onDrop(of: [.plainText], isTargeted: $model.isDropTargeted) { providers, location in
            handleDrop(providers, at: location)
        }
    }

    private var pageBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(hex: page.backgroundHex))
            .overlay {
                if editable {
                    GridDots()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 26, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture {
                if editable {
                    model.selectComponent(nil)
                }
            }
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.1))
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 46, height: 46)

            Text("Drop a component here")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Drag from the Components palette, or click a component to add it.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], at location: CGPoint) -> Bool {
        guard editable, let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let raw = object as? String,
                  raw.hasPrefix("foundry.component."),
                  let type = ComponentType(rawValue: String(raw.dropFirst("foundry.component.".count))) else { return }
            Task { @MainActor in
                model.addComponent(type, centeredAt: location)
            }
        }
        return true
    }
}

private struct GridDots: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                var y: CGFloat = 0
                while y <= size.height {
                    path.addEllipse(in: CGRect(x: x, y: y, width: 1.1, height: 1.1))
                    y += step
                }
                x += step
            }
            context.fill(path, with: .color(Color.black.opacity(0.075)))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Canvas node

private struct CanvasNode: View {
    @ObservedObject var model: EditorModel
    let component: CanvasComponent
    let page: AppPage
    let editable: Bool

    @State private var moveOrigin: CGPoint?
    @State private var resizeOrigin: CGSize?

    private var selected: Bool { model.selectedComponentID == component.id }

    var body: some View {
        ComponentRenderer(model: model, component: component, interactive: !editable)
            .frame(width: component.width, height: component.height)
            .overlay {
                if editable && selected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Theme.selection, lineWidth: 1.5)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topLeading) {
                if editable && selected {
                    nameTag
                        .offset(y: -18)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if editable {
                    editorHitLayer
                }
            }
            .opacity(component.hidden && editable ? 0.35 : 1)
            .offset(x: component.x, y: component.y)
            .contextMenu {
                if editable {
                    contextMenu
                }
            }
    }

    private var nameTag: some View {
        HStack(spacing: 4) {
            if component.hidden {
                Image(systemName: "eye.slash")
                    .font(.system(size: 7, weight: .bold))
            }
            if component.locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
            }
            Text(component.name)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.selection)
        )
        .fixedSize()
    }

    private var editorHitLayer: some View {
        ZStack(alignment: .bottomTrailing) {
            if component.locked {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectComponent(component.id)
                    }
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(moveGesture)
            }

            if selected && !component.locked {
                resizeHandle
            }
        }
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Theme.selection, lineWidth: 2))
            .frame(width: 11, height: 11)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .offset(x: 6, y: 6)
            .contentShape(Circle())
            .gesture(resizeGesture)
            .help("Resize")
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let distance = abs(value.translation.width) + abs(value.translation.height)
                if distance < 2 { return }
                if moveOrigin == nil {
                    moveOrigin = CGPoint(x: component.x, y: component.y)
                    model.selectComponent(component.id)
                }
                guard let origin = moveOrigin else { return }
                let nextX = clamp(snap(origin.x + value.translation.width), 0, page.width - component.width)
                let nextY = clamp(snap(origin.y + value.translation.height), 0, page.height - component.height)
                model.updateComponent(component.id) { item in
                    item.x = nextX
                    item.y = nextY
                }
            }
            .onEnded { value in
                let distance = abs(value.translation.width) + abs(value.translation.height)
                if distance < 2 {
                    model.selectComponent(component.id)
                }
                moveOrigin = nil
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if resizeOrigin == nil {
                    resizeOrigin = CGSize(width: component.width, height: component.height)
                    model.selectComponent(component.id)
                }
                guard let origin = resizeOrigin else { return }
                let width = clamp(snap(origin.width + value.translation.width), 48, page.width - component.x)
                let height = clamp(snap(origin.height + value.translation.height), 24, page.height - component.y)
                model.updateComponent(component.id) { item in
                    item.width = width
                    item.height = height
                }
            }
            .onEnded { _ in
                resizeOrigin = nil
            }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Select") { model.selectComponent(component.id) }
        Button("Duplicate") { model.duplicateComponent(component.id) }
        Button("Bring to front") { model.bringToFront(component.id) }
        Button("Send to back") { model.sendToBack(component.id) }
        Divider()
        Button(component.hidden ? "Show" : "Hide") { model.toggleHidden(component.id) }
        Button(component.locked ? "Unlock" : "Lock") { model.toggleLocked(component.id) }
        Divider()
        Button("Delete", role: .destructive) { model.deleteComponent(component.id) }
    }

    private func snap(_ value: Double) -> Double {
        (value / 8).rounded() * 8
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(lower, value), max(lower, upper))
    }
}
