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

extension Notification.Name {
    static let devmirrorStateChanged = Notification.Name("devmirrorStateChanged")
}

@main
struct DevMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var dotColor = Color.green
    @State private var barIcon = "externaldrive"

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: appDelegate.viewModel)
        } label: {
            HStack(spacing: 3) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                Image(systemName: barIcon)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .devmirrorStateChanged)) { _ in
            refreshStatus()
        }

        Window("DevMirror Settings", id: "settings") {
            SettingsView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
    }

    private func refreshStatus() {
        let vm = appDelegate.viewModel
        if vm.hasError {
            dotColor = .red; barIcon = "externaldrive.badge.xmark"
        } else if vm.isPaused {
            dotColor = .yellow; barIcon = "externaldrive"
        } else {
            switch vm.syncState {
            case .scanning, .syncing:
                dotColor = .blue; barIcon = "externaldrive.badge.plus"
            case .idle:
                dotColor = .green; barIcon = "externaldrive"
            case .paused:
                dotColor = .yellow; barIcon = "externaldrive"
            case .error:
                dotColor = .red; barIcon = "externaldrive.badge.xmark"
            }
        }
    }
}
