import SwiftUI
import MirrorCore

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    let viewModel = AppViewModel()
    private var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

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

    // MARK: - Status bar icon + popover menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 260, height: 380)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarContentView(viewModel: viewModel)
                .environment(\.closePopover, { [weak self] in
                    self?.popover?.close()
                })
        )
        updateStatusIcon()

        NotificationCenter.default.addObserver(
            forName: .devmirrorStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusIcon()
        }
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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

// Environment key so menu items can close the popover
struct ClosePopoverKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var closePopover: () -> Void {
        get { self[ClosePopoverKey.self] }
        set { self[ClosePopoverKey.self] = newValue }
    }
}

@main
struct DevMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("DevMirror Settings", id: "settings") {
            SettingsView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
    }
}
