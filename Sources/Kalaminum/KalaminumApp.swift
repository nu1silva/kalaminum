import AppKit
import SwiftUI

@main
struct KalaminumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: appDelegate.model)
        } label: {
            Image(systemName: appDelegate.model.needsAttention ? "clock.badge.exclamationmark" : "clock")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon, even when run straight from `swift run`.
        NSApp.setActivationPolicy(.accessory)
        model.start()
    }
}
