import SwiftUI
import MirrorCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct DevMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            let label = menuBarLabel
            Image(systemName: label.icon)
                .accessibilityLabel(label.text)
        }

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }

    private var menuBarLabel: (icon: String, text: String) {
        if viewModel.hasError {
            return ("externaldrive.badge.xmark", "DevMirror - Error")
        }
        if viewModel.isPaused {
            return ("externaldrive.badge.minus", "DevMirror - Paused")
        }
        switch viewModel.syncState {
        case .scanning, .syncing:
            return ("externaldrive.badge.plus", "DevMirror - Syncing")
        case .idle:
            return ("externaldrive", "DevMirror")
        case .paused:
            return ("externaldrive.badge.minus", "DevMirror - Paused")
        case .error:
            return ("externaldrive.badge.xmark", "DevMirror - Error")
        }
    }
}
