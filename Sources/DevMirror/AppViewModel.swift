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

    init() {
        let saved = StateStore.shared.loadConfig()
        config = saved
    }

    func startService() {
        stopService()

        syncState = .idle
        isPaused = false
        hasError = false

        let queue = SyncQueue(config: config)
        queue.onStateChange = { [weak self] state in
            let sself: AppViewModel? = self
            DispatchQueue.main.async {
                sself?.syncState = state
                if case .error(let msg) = state {
                    sself?.hasError = true
                    sself?.errorMessage = msg
                }
            }
        }
        syncQueue = queue

        let w = FSEventsWatcher(sourcePath: config.sourcePath)
        w.onEvents = { [weak self] paths in
            let sself: AppViewModel? = self
            sself?.syncQueue?.enqueue(paths)
        }
        w.onOverflow = { [weak self] in
            let sself: AppViewModel? = self
            sself?.runFullScan()
        }

        let lastID = StateStore.shared.lastEventID() ?? UInt64(kFSEventStreamEventIdSinceNow)
        w.start(lastEventID: lastID)
        watcher = w

        runFullScan()
    }

    func stopService() {
        watcher?.stop()
        watcher = nil
        syncQueue = nil
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
        Task.detached(priority: .utility) {
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
        stopService()
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
}
