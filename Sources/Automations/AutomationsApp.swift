import SwiftUI
import AppKit

@main
struct AutomationsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ShellView()
                .frame(minWidth: 960, minHeight: 620)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 620)
    }
}

/// Top-level shell: sidebar navigation + section content.
struct ShellView: View {
    @State private var section: AppSection = .finance
    @State private var financeStore = FinanceStore()
    @State private var activeAutomation: Automation?

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(selection: $section)
            Group {
                switch section {
                case .finance:
                    FinanceDashboardView(store: financeStore)
                case .automations:
                    automationsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas)
        .onChange(of: section) { _, new in
            if new == .finance { activeAutomation = nil }
        }
    }

    @ViewBuilder
    private var automationsContent: some View {
        if let activeAutomation {
            OutputView(automation: activeAutomation) { self.activeAutomation = nil }
        } else {
            PaletteView(automations: Automation.catalog) { activeAutomation = $0 }
        }
    }
}

/// Makes the SPM-launched executable behave like a real foreground app:
/// shows in the Dock, becomes frontmost, and quits when the window closes.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
