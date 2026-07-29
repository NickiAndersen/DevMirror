import SwiftUI
import MirrorCore

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    let viewModel = AppViewModel()
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
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

    // MARK: - Status bar icon + popover menu

    @MainActor private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusIcon()

        NotificationCenter.default.addObserver(
            forName: .devmirrorStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateStatusIcon()
            }
        }
    }

    @MainActor @objc private func statusItemClicked() {
        guard let button = statusItem?.button else { return }
        let menu = buildMenu()
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @MainActor private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let vm = viewModel

        // Header
        let headerItem = NSMenuItem()
        headerItem.title = "DevMirror"
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let byItem = NSMenuItem()
        byItem.title = "© 2026 THYRING"
        byItem.isEnabled = false
        byItem.attributedTitle = NSAttributedString(
            string: "© 2026 THYRING",
            attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.tertiaryLabelColor]
        )
        menu.addItem(byItem)
        menu.addItem(.separator())

        // Status
        let statusLabel: String
        if vm.hasError { statusLabel = "Error" }
        else if vm.isPaused { statusLabel = "Paused" }
        else {
            switch vm.syncState {
            case .idle: statusLabel = "● Watching for changes"
            case .scanning: statusLabel = "◉ Scanning..."
            case .syncing(let done, let total): statusLabel = "◉ Syncing \(done)/\(total)"
            case .paused: statusLabel = "● Paused"
            case .error: statusLabel = "● Error"
            }
        }
        let statusItem = NSMenuItem()
        statusItem.title = statusLabel
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Interval
        let intervalItem = NSMenuItem()
        intervalItem.title = "   \(vm.config.syncMode.displayName)"
        intervalItem.isEnabled = false
        intervalItem.attributedTitle = NSAttributedString(
            string: "   \(vm.config.syncMode.displayName)",
            attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.secondaryLabelColor]
        )
        menu.addItem(intervalItem)

        // Folders
        let folderItem = NSMenuItem()
        folderItem.title = "   \(vm.sourceFolderName) → \(vm.destinationFolderName)"
        folderItem.isEnabled = false
        folderItem.attributedTitle = NSAttributedString(
            string: "   \(vm.sourceFolderName) → \(vm.destinationFolderName)",
            attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.secondaryLabelColor]
        )
        menu.addItem(folderItem)

        // Error
        if vm.hasError {
            let errItem = NSMenuItem()
            errItem.title = "⚠ \(vm.errorMessage)"
            errItem.isEnabled = false
            errItem.attributedTitle = NSAttributedString(
                string: "⚠ \(vm.errorMessage)",
                attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                             .foregroundColor: NSColor.systemRed]
            )
            menu.addItem(errItem)
        }

        menu.addItem(.separator())

        // Actions
        let pauseTitle = vm.isPaused ? "Resume Syncing" : "Pause Syncing"
        menu.addItem(NSMenuItem(title: pauseTitle, action: #selector(menuPauseResume), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Sync Now", action: #selector(menuSyncNow), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Backup Folder", action: #selector(menuOpenBackup), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Source Folder", action: #selector(menuOpenSource), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Settings...", action: #selector(menuOpenSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DevMirror", action: #selector(menuQuit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }

        return menu
    }

    @objc private func menuPauseResume() { viewModel.togglePause() }
    @objc private func menuSyncNow() { viewModel.runFullScan() }
    @objc private func menuOpenBackup() { viewModel.openBackupInFinder() }
    @objc private func menuOpenSource() { viewModel.openSourceInFinder() }
    @objc private func menuOpenSettings() { openSettings() }
    @objc private func menuQuit() { viewModel.stopService(); NSApp.terminate(nil) }

    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "DevMirror Settings"
            window.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel))
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor func updateStatusIcon() {
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
@main
struct DevMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
