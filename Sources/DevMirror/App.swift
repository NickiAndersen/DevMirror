import SwiftUI
import MirrorCore

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    let viewModel = AppViewModel()
    private var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

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

    // MARK: - Status Item (AppKit with reactive updates)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusIcon()

        // Observe state changes to update the icon
        NotificationCenter.default.addObserver(
            forName: .devmirrorStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusIcon()
        }
    }

    @objc private func statusItemClicked() {
        // MenuBarExtra content handles the menu via SwiftUI
    }

    func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let vm = viewModel

        let dotColor: NSColor
        let iconName: String

        if vm.hasError {
            dotColor = .systemRed; iconName = "externaldrive.badge.xmark"
        } else if vm.isPaused {
            dotColor = .systemYellow; iconName = "externaldrive"
        } else {
            switch vm.syncState {
            case .scanning, .syncing:
                dotColor = .systemBlue; iconName = "externaldrive.badge.plus"
            case .idle:
                dotColor = .systemGreen; iconName = "externaldrive"
            case .paused:
                dotColor = .systemYellow; iconName = "externaldrive"
            case .error:
                dotColor = .systemRed; iconName = "externaldrive.badge.xmark"
            }
        }

        guard let symbol = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) else { return }

        let dotSize: CGFloat = 8
        let pad: CGFloat = 2
        let iconW: CGFloat = 14
        let totalW = dotSize + pad + iconW
        let totalH: CGFloat = 18

        let image = NSImage(size: NSSize(width: totalW, height: totalH))
        image.lockFocus()
        dotColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: (totalH - dotSize) / 2, width: dotSize, height: dotSize)).fill()
        symbol.draw(in: NSRect(x: dotSize + pad, y: 2, width: iconW, height: totalH - 4))
        image.unlockFocus()
        image.isTemplate = false

        button.image = image
        button.imagePosition = .imageOnly
    }

    // MARK: - Onboarding

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

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: appDelegate.viewModel)
        } label: {
            EmptyView()
        }

        Window("DevMirror Settings", id: "settings") {
            SettingsView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
    }
}
