import SwiftUI
import AppKit

@main
struct FoundryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var shell = AppShell.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(shell)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1460, height: 940)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New App") { shell.newBlankApp() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Browse Templates…") { shell.showTemplates = true }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Import Template…") { shell.importTemplateFromDisk() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Divider()
                Button("Back to Apps") { shell.closeEditor() }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                    .disabled(shell.editor == nil)
            }
            CommandGroup(replacing: .help) {
                Button("Welcome to Foundry") { shell.openOnboarding() }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var snapshotWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        scheduleSnapshotIfRequested()
        runSelfTestIfRequested()
    }

    /// Dev helper: `Foundry --selftest /tmp/results.json` validates the built-in
    /// templates against their seeded SQLite databases and exits with a status.
    private func runSelfTestIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--selftest"), arguments.indices.contains(index + 1) else { return }
        let path = arguments[index + 1]
        Task { @MainActor in
            await SelfTest.run(writingTo: URL(fileURLWithPath: path))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Dev helper: `Foundry --snapshot /tmp/shot.png` captures the first window
    /// through AppKit so layout can be verified without screen-recording access.
    private func scheduleSnapshotIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), arguments.indices.contains(index + 1) else { return }
        let path = arguments[index + 1]

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            func note(_ message: String) {
                let line = "[\(Date())] \(message)\n"
                if let data = line.data(using: .utf8) {
                    let logURL = URL(fileURLWithPath: "/tmp/foundry-snapshot.log")
                    if let handle = try? FileHandle(forWritingTo: logURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    } else {
                        try? data.write(to: logURL)
                    }
                }
            }

            note("args=\(ProcessInfo.processInfo.arguments)")
            var attempts = 0

            func capture() {
                attempts += 1
                note("poll=\(attempts) windows=\(NSApp.windows.count)")
                for window in NSApp.windows {
                    note("window visible=\(window.isVisible) frame=\(window.frame) content=\(window.contentView?.bounds ?? .zero)")
                }

                let candidates = NSApp.windows.filter { $0.contentView != nil && $0.frame.width > 200 }
                let keyWindow = NSApp.keyWindow.flatMap { key in
                    candidates.first(where: { $0 === key }) 
                }
                guard let window = keyWindow ?? candidates.first,
                      let view = window.contentView else {
                    let needsFallback = MainActor.assumeIsolated { self.snapshotWindow == nil }
                    if attempts >= 3, needsFallback {
                        MainActor.assumeIsolated {
                            note("creating fallback window")
                            _ = self.makeFallbackWindow()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { capture() }
                    } else if attempts >= 20 {
                        note("no window found")
                        exit(1)
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { capture() }
                    }
                    return
                }
                view.layoutSubtreeIfNeeded()
                if let cgImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    CGWindowID(window.windowNumber),
                    [.boundsIgnoreFraming, .bestResolution]
                ) {
                    let representation = NSBitmapImageRep(cgImage: cgImage)
                    if let data = representation.representation(using: .png, properties: [:]) {
                        do {
                            try data.write(to: URL(fileURLWithPath: path))
                            note("wrote \(data.count) bytes to \(path)")
                        } catch {
                            note("write failed: \(error)")
                        }
                    }
                } else if let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: representation)
                    if let data = representation.representation(using: .png, properties: [:]) {
                        try? data.write(to: URL(fileURLWithPath: path))
                        note("cg unavailable; wrote cached display")
                    }
                } else {
                    note("no image representation")
                }
                exit(0)
            }

            capture()
        }
    }

    /// SwiftUI can skip creating its initial WindowGroup window when the app is
    /// launched without activation (e.g. by a script). Hosting the root view in
    /// an explicit window keeps the snapshot path deterministic.
    private func makeFallbackWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1460, height: 940),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Foundry"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1)

        let hosting = NSHostingView(rootView: RootView().environmentObject(AppShell.shared))
        hosting.frame = NSRect(x: 0, y: 0, width: 1460, height: 940)
        window.contentView = hosting
        window.setContentSize(NSSize(width: 1460, height: 940))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        snapshotWindow = window
        return window
    }
}
