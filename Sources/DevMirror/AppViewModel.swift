import Observation
import Foundation
import AppKit
import MirrorCore
import ServiceManagement

@Observable
final class AppViewModel: @unchecked Sendable {
    var syncState: SyncState = .idle
    var config: MirrorConfig = .default
    var recentEvents: [SyncEvent] = []
    var isPaused = false
    var hasError = false
    var errorMessage = ""

    private var syncQueue: SyncQueue?
    private var watcher: FSEventsWatcher?
    private var activityToken: NSObjectProtocol?
    private var periodicTimer: Timer?

    init() {
        let saved = StateStore.shared.loadConfig()
        config = saved
    }

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding")
            if newValue { try? StateStore.shared.save(config: config) }
        }
    }

    var sourceFolderName: String {
        URL(fileURLWithPath: config.sourcePath).lastPathComponent
    }

    var destinationFolderName: String {
        URL(fileURLWithPath: config.destinationPath).lastPathComponent
    }

    func validatePaths(source: String, destination: String) -> (isValid: Bool, message: String?, isWarning: Bool) {
        guard !source.isEmpty, !destination.isEmpty else {
            return (false, "Both folders must be selected.", false)
        }
        let srcURL = URL(fileURLWithPath: source).standardizedFileURL
        let dstURL = URL(fileURLWithPath: destination).standardizedFileURL

        if srcURL.path == dstURL.path {
            return (false, "Source and destination cannot be the same folder.", false)
        }
        if dstURL.path.hasPrefix(srcURL.path + "/") {
            return (false, "Destination is inside the source folder.", false)
        }
        if srcURL.path.hasPrefix(dstURL.path + "/") {
            return (false, "Source is inside the destination folder.", false)
        }

        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: srcURL.path, isDirectory: &isDir) || !isDir.boolValue {
            return (false, "Source folder does not exist.", false)
        }
        if isCloudSyncedFolder(dstURL.path) {
            return (true, "This folder appears to be synced by iCloud or Dropbox. For best results, use a Google Drive-synced or local folder.", true)
        }
        return (true, nil, false)
    }

    func isCloudSyncedFolder(_ path: String) -> Bool {
        return path.contains("Library/Mobile Documents") ||
               path.contains("/Dropbox/") ||
               path.contains("/OneDrive/")
    }

    func openBackupInFinder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: config.destinationPath))
    }

    func startService() {
        guard !isDestinationInsideSource() else {
            hasError = true
            errorMessage = "The backup folder is inside the source folder. This would cause infinite recursion. Please choose a backup folder outside ~/Developer."
            return
        }

        guard FileManager.default.fileExists(atPath: config.sourcePath) else {
            hasError = true
            errorMessage = "Source folder not found: \(config.sourcePath)"
            return
        }

        stopService()

        syncState = .idle
        isPaused = false
        hasError = false
        errorMessage = ""

        let queue = SyncQueue(config: config)
        queue.onStateChange = { [weak self] state in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.syncState = state
                switch state {
                case .scanning, .syncing:
                    self.startActivity()
                case .idle, .paused:
                    self.endActivity()
                case .error(let msg):
                    self.hasError = true
                    self.errorMessage = msg
                    self.endActivity()
                }
            }
        }
        syncQueue = queue

        let w = FSEventsWatcher(sourcePath: config.sourcePath)
        w.onEvents = { [weak self] paths in
            self?.syncQueue?.enqueue(paths)
        }
        w.onOverflow = { [weak self] in
            self?.runFullScan()
        }

        if config.syncMode == .realtime {
            let lastID = StateStore.shared.lastEventID() ?? UInt64(kFSEventStreamEventIdSinceNow)
            w.start(lastEventID: lastID)
            watcher = w
        } else {
            watcher = w
            startPeriodicTimer()
        }

        runFullScan()
    }

    func stopService() {
        endActivity()
        periodicTimer?.invalidate()
        periodicTimer = nil
        syncQueue = nil
        watcher?.stop()
        watcher = nil
    }

    func togglePause() {
        if isPaused {
            syncQueue?.resume()
            isPaused = false
        } else {
            syncQueue?.pause()
            isPaused = true
        }
    }

    func runFullScan() {
        let queue = syncQueue
        let w = watcher
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                try queue?.runFullScan()
            } catch {
                await MainActor.run {
                    self.syncState = .error(error.localizedDescription)
                    self.hasError = true
                    self.errorMessage = error.localizedDescription
                }
            }
            if let id = w?.currentEventID {
                StateStore.shared.saveLastEventID(id)
            }
        }
    }

    func applyConfig() {
        do {
            try StateStore.shared.save(config: config)
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            hasError = true
        }
        startService()
    }

    func refreshEvents() {
        recentEvents = StateStore.shared.loadEvents()
    }

    func registerLoginItem() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            errorMessage = "Could not register login item: \(error.localizedDescription)"
            hasError = true
        }
    }

    func unregisterLoginItem() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            errorMessage = "Could not unregister login item: \(error.localizedDescription)"
            hasError = true
        }
    }

    var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Private

    private func startPeriodicTimer() {
        guard let interval = config.syncMode.intervalSeconds else { return }
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.runFullScan()
        }
    }

    private func isDestinationInsideSource() -> Bool {
        let src = URL(fileURLWithPath: config.sourcePath).standardizedFileURL.path
        let dst = URL(fileURLWithPath: config.destinationPath).standardizedFileURL.path
        return dst.hasPrefix(src + "/") || dst == src
    }

    private func startActivity() {
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "File synchronization in progress"
        )
    }

    private func endActivity() {
        guard let token = activityToken else { return }
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
    }
}
