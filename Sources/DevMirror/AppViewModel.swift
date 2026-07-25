import Observation
import Foundation
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

    init() {
        let saved = StateStore.shared.loadConfig()
        config = saved
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

        let lastID = StateStore.shared.lastEventID() ?? UInt64(kFSEventStreamEventIdSinceNow)
        w.start(lastEventID: lastID)
        watcher = w

        runFullScan()
    }

    func stopService() {
        endActivity()
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
