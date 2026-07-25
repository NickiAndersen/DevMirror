import Observation
import Foundation
import AppKit
import MirrorCore
import ServiceManagement
import UserNotifications

@Observable
final class AppViewModel: @unchecked Sendable {
    var syncState: SyncState = .idle
    var config: MirrorConfig
    var recentEvents: [SyncEvent] = []
    var isPaused = false
    var hasError = false
    var errorMessage = ""

    var showNotificationOnComplete: Bool {
        get { UserDefaults.standard.object(forKey: "notifyOnComplete") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "notifyOnComplete") }
    }

    var showNotificationOnError: Bool {
        get {
            if UserDefaults.standard.object(forKey: "notifyOnError") == nil { return true }
            return UserDefaults.standard.bool(forKey: "notifyOnError")
        }
        set { UserDefaults.standard.set(newValue, forKey: "notifyOnError") }
    }

    private var syncQueue: SyncQueue?
    private var watcher: FSEventsWatcher?
    private var activityToken: NSObjectProtocol?
    private var periodicTimer: Timer?
    private var lastSyncFileCount = 0
    private var lastSyncTimestamp: Date?

    init() {
        let saved = StateStore.shared.loadConfig()
        config = saved
        requestNotificationPermission()
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

    // MARK: - Validation

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

    func openSourceInFinder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: config.sourcePath))
    }

    // MARK: - Service

    func startService() {
        guard !isDestinationInsideSource() else {
            hasError = true
            errorMessage = "The backup folder is inside the source folder. This would cause infinite recursion. Please choose a backup folder outside the source folder."
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
        lastSyncFileCount = 0

        let queue = SyncQueue(config: config)
        queue.onStateChange = { [weak self] state in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.syncState = state
                switch state {
                case .scanning, .syncing:
                    self.startActivity()
                    if case .syncing(_, let total) = state {
                        self.lastSyncFileCount = total
                    }
                case .idle:
                    self.endActivity()
                    if self.lastSyncFileCount > 0 {
                        self.lastSyncTimestamp = Date()
                        self.sendCompletionNotification(fileCount: self.lastSyncFileCount)
                        self.lastSyncFileCount = 0
                    }
                case .paused:
                    self.endActivity()
                case .error(let msg):
                    self.hasError = true
                    self.errorMessage = msg
                    self.endActivity()
                    self.sendErrorNotification(msg)
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
            runFullScan()
        } else {
            watcher = w
            startPeriodicTimer()
            sendNotification(title: "DevMirror ready", body: "Syncing every \(config.syncMode.displayName).")
        }
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
            sendNotification(title: "Syncing paused", body: "Tap Resume in the menu bar to continue.")
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

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendCompletionNotification(fileCount: Int) {
        guard showNotificationOnComplete else { return }
        let time = DateFormatter()
        time.timeStyle = .short
        sendNotification(
            title: "Sync complete",
            body: "\(fileCount) files synced at \(time.string(from: Date()))"
        )
    }

    private func sendErrorNotification(_ msg: String) {
        guard showNotificationOnError else { return }
        sendNotification(title: "Sync error", body: msg)
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
