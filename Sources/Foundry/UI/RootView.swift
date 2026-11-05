import SwiftUI

struct RootView: View {
    @EnvironmentObject private var shell: AppShell

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let editor = shell.editor {
                EditorView(model: editor)
                    .id(editor.document.id)
                    .transition(.opacity)
            } else {
                GalleryView()
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 1180, minHeight: 760)
        .preferredColorScheme(.dark)
        .onAppear {
            if shell.presentOnboardingOnLaunch {
                shell.presentOnboardingOnLaunch = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    shell.showOnboarding = true
                }
            }
            if shell.presentTemplatesOnLaunch {
                shell.presentTemplatesOnLaunch = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    shell.showTemplates = true
                }
            }
        }
        .overlay {
            if shell.showOnboarding {
                OnboardingView()
                    .environmentObject(shell)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: shell.showOnboarding)
        .sheet(isPresented: $shell.showTemplates) {
            TemplateGalleryView()
                .environmentObject(shell)
        }
        .alert("Foundry", isPresented: Binding(
            get: { shell.alertMessage != nil },
            set: { if !$0 { shell.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { shell.alertMessage = nil }
        } message: {
            Text(shell.alertMessage ?? "")
        }
    }
}
