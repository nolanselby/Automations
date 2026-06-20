import SwiftUI
import AppKit

@main
struct AutomationsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(width: 720, height: 460)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

/// Switches between the palette and a single automation's output.
struct RootView: View {
    @State private var active: Automation?

    var body: some View {
        Group {
            if let active {
                OutputView(automation: active) { self.active = nil }
            } else {
                PaletteView(automations: Automation.catalog) { active = $0 }
            }
        }
        .background(Theme.canvas)
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
