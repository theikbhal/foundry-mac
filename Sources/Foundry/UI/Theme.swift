import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        switch value.count {
        case 8:
            red = Double((number >> 24) & 0xFF) / 255
            green = Double((number >> 16) & 0xFF) / 255
            blue = Double((number >> 8) & 0xFF) / 255
            alpha = Double(number & 0xFF) / 255
        case 6:
            red = Double((number >> 16) & 0xFF) / 255
            green = Double((number >> 8) & 0xFF) / 255
            blue = Double(number & 0xFF) / 255
            alpha = 1
        default:
            red = 0
            green = 0
            blue = 0
            alpha = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexString: String {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

enum Theme {
    static let background = Color(hex: "#0A0B0F")
    static let panel = Color(hex: "#111319")
    static let panelRaised = Color(hex: "#171A21")
    static let field = Color(hex: "#0C0E13")
    static let border = Color(hex: "#242833")
    static let borderSoft = Color(hex: "#1B1E27")
    static let text = Color(hex: "#E9EBF0")
    static let textDim = Color(hex: "#9097A3")
    static let textFaint = Color(hex: "#5E6675")
    static let accent = Color(hex: "#7C6CF5")
    static let accentBright = Color(hex: "#9A8EFF")
    static let blue = Color(hex: "#38BDF8")
    static let green = Color(hex: "#34D399")
    static let amber = Color(hex: "#FBBF24")
    static let red = Color(hex: "#F87171")
    static let canvas = Color(hex: "#07080B")
    static let selection = Color(hex: "#8B7CFF")

    static let mono = Font.system(size: 11.5, design: .monospaced)
}

struct Hairline: View {
    var color: Color = Theme.borderSoft
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.textFaint)
    }
}

struct IconButton: View {
    let icon: String
    var help: String = ""
    var active: Bool = false
    var size: CGFloat = 28
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Color.white : (hovering ? Theme.text : Theme.textDim))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(active ? Theme.accent : (hovering ? Theme.panelRaised : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

enum EditorButtonVariant {
    case primary
    case secondary
    case ghost
    case danger
}

struct EditorButtonStyle: ButtonStyle {
    var variant: EditorButtonVariant = .secondary
    var small: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 11 : 12, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, small ? 9 : 12)
            .frame(height: small ? 27 : 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: variant == .secondary || variant == .ghost ? 1 : 0)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.38)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch variant {
        case .primary, .danger: return .white
        case .secondary: return Theme.text
        case .ghost: return Theme.textDim
        }
    }

    private var background: Color {
        switch variant {
        case .primary: return Theme.accent
        case .secondary: return Theme.panelRaised
        case .ghost: return .clear
        case .danger: return Color(hex: "#DC2626")
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: return Theme.border
        case .ghost: return .clear
        default: return .clear
        }
    }
}

struct DarkFieldModifier: ViewModifier {
    var cornerRadius: CGFloat = 7

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func darkField(cornerRadius: CGFloat = 7) -> some View {
        modifier(DarkFieldModifier(cornerRadius: cornerRadius))
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(toast.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.panelRaised)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
    }

    private var icon: String {
        switch toast.kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch toast.kind {
        case .info: return Theme.blue
        case .success: return Theme.green
        case .error: return Theme.red
        }
    }
}

struct StatusDot: View {
    var color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(Theme.textDim)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.panelRaised)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.borderSoft, lineWidth: 1)
            )
    }
}

enum FileDialogs {
    static var templateType: UTType {
        UTType(filenameExtension: "foundrytemplate") ?? .json
    }

    static func openSQLiteDatabase() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open a SQLite database"
        panel.message = "Choose a local .sqlite or .db file."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.database, .data]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func createSQLiteDatabase() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Create a SQLite database"
        panel.nameFieldStringValue = "database.sqlite"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [.database]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openTemplate() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import template"
        panel.allowedContentTypes = [templateType, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func saveTemplate(named name: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export template"
        panel.nameFieldStringValue = name.replacingOccurrences(of: "/", with: "-") + ".foundrytemplate"
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [templateType]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
