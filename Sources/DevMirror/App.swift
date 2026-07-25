import SwiftUI
import MirrorCore

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    let viewModel = AppViewModel()
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if viewModel.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.viewModel.startService()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                MainActor.assumeIsolated {
                    self?.showOnboarding()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopService()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor private func showOnboarding() {
        let vm = viewModel
        let contentView = OnboardingView(viewModel: vm) { [weak self] in
            self?.viewModel.hasCompletedOnboarding = true
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.viewModel.startService()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to DevMirror"
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        window.delegate = self
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if !viewModel.hasCompletedOnboarding {
            NSApp.terminate(nil)
        }
    }
}

@main
struct DevMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: appDelegate.viewModel)
        } label: {
            HStack(spacing: 3) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Image(systemName: statusIcon)
            }
        }

        Window("DevMirror Settings", id: "settings") {
            SettingsView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
    }

    private var statusIcon: String {
        if appDelegate.viewModel.hasError { return "externaldrive.badge.xmark" }
        if appDelegate.viewModel.isPaused { return "externaldrive" }
        switch appDelegate.viewModel.syncState {
        case .scanning, .syncing: return "externaldrive.badge.plus"
        default: return "externaldrive"
        }
    }

    private var statusColor: Color {
        if appDelegate.viewModel.hasError { return .red }
        if appDelegate.viewModel.isPaused { return .yellow }
        switch appDelegate.viewModel.syncState {
        case .scanning, .syncing: return .blue
        case .idle: return .green
        case .paused: return .yellow
        case .error: return .red
        }
    }
}
