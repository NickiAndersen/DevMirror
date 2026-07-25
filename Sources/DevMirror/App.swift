import SwiftUI
import MirrorCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = AppViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.viewModel.startService()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopService()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct DevMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: appDelegate.viewModel)
        } label: {
            Image(systemName: menuBarIcon)
                .accessibilityLabel(menuBarTitle)
        }

        Settings {
            SettingsView(viewModel: appDelegate.viewModel)
        }
    }

    private var menuBarIcon: String {
        if appDelegate.viewModel.hasError {
            return "externaldrive.badge.xmark"
        }
        if appDelegate.viewModel.isPaused {
            return "externaldrive.badge.minus"
        }
        switch appDelegate.viewModel.syncState {
        case .scanning, .syncing:
            return "externaldrive.badge.plus"
        default:
            return "externaldrive"
        }
    }

    private var menuBarTitle: String {
        if appDelegate.viewModel.hasError { return "DevMirror - Error" }
        if appDelegate.viewModel.isPaused { return "DevMirror - Paused" }
        switch appDelegate.viewModel.syncState {
        case .scanning, .syncing: return "DevMirror - Syncing"
        default: return "DevMirror"
        }
    }
}
