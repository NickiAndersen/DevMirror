import Foundation

public final class SyncQueue: @unchecked Sendable {
    private let config: MirrorConfig
    private let exclusionEngine: ExclusionEngine
    private let syncEngine: SyncEngine
    private let safeDelete: SafeDelete
    private let scanner: ReconcileScanner

    private let workQueue = DispatchQueue(label: "devmirror.syncqueue", qos: .utility)
    private let ioQueue = DispatchQueue(label: "devmirror.syncqueue.io", qos: .utility, attributes: .concurrent)
    private let ioLimiter = DispatchSemaphore(value: 4)
    private let lock = NSLock()

    private var isRunning = false
    private var isPaused = false
    private var pendingPaths = Set<String>()
    private var debounceWorkItem: DispatchWorkItem?
    private var state: SyncState = .idle

    public var onStateChange: ((SyncState) -> Void)?

    public init(config: MirrorConfig) {
        self.config = config
        self.exclusionEngine = ExclusionEngine(config: config)
        self.syncEngine = SyncEngine(config: config)
        self.safeDelete = SafeDelete(
            destinationPath: config.destinationPath,
            retentionDays: config.trashRetentionDays
        )
        self.scanner = ReconcileScanner(
            config: config,
            exclusionEngine: exclusionEngine,
            syncEngine: syncEngine
        )
    }

    // MARK: - Reconcile (full scan)

    public func runFullScan() throws {
        setState(.scanning)

        let result = try scanner.scan()
        guard !result.isEmpty else {
            setState(.idle)
            return
        }

        setState(.syncing(filesProcessed: 0, totalFiles: result.totalChanges))

        processBatch(result.toCopy, mode: .copy)
        processDeletions(result.toDelete)

        try safeDelete.purgeExpired()
        setState(.idle)
    }

    // MARK: - Live events

    public func enqueue(_ paths: [String]) {
        let sourcePrefix = config.sourcePath.hasSuffix("/") ? config.sourcePath : config.sourcePath + "/"
        let relativePaths = paths.compactMap { path -> String? in
            let relative = path.hasPrefix(sourcePrefix)
                ? String(path.dropFirst(sourcePrefix.count))
                : path
            guard !exclusionEngine.isExcluded(relative) else { return nil }
            return relative
        }
        guard !relativePaths.isEmpty else { return }

        lock.withLock {
            for path in relativePaths {
                pendingPaths.insert(path)
            }
        }
        scheduleDebounce()
    }

    // MARK: - Control

    public func pause() {
        lock.withLock { isPaused = true }
        debounceWorkItem?.cancel()
        setState(.paused)
    }

    public func resume() {
        lock.withLock { isPaused = false }
        setState(.idle)
    }

    // MARK: - Private

    private func scheduleDebounce() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPending()
        }
        debounceWorkItem = workItem
        workQueue.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func flushPending() {
        var paths: [String] = lock.withLock {
            guard !isPaused else { return [] }
            let paths = Array(pendingPaths)
            pendingPaths.removeAll()
            return paths
        }
        guard !paths.isEmpty else { return }

        let (stable, unstable) = filterStablePaths(paths)

        lock.withLock {
            for path in unstable {
                pendingPaths.insert(path)
            }
        }
        if !unstable.isEmpty { scheduleDebounce() }

        guard !stable.isEmpty else { return }

        setState(.syncing(filesProcessed: 0, totalFiles: stable.count))
        processBatch(stable, mode: .liveSync)
        setState(.idle)
    }

    private func filterStablePaths(_ paths: [String]) -> (stable: [String], unstable: [String]) {
        let sourceBase = URL(fileURLWithPath: config.sourcePath)

        let firstAttrs: [(String, Int64, Date)] = paths.compactMap { path in
            let url = sourceBase.appendingPathComponent(path)
            guard syncEngine.fileExists(at: url),
                  let attrs = syncEngine.fileSizeAndModificationDate(at: url)
            else { return nil }
            return (path, attrs.size, attrs.mtime)
        }

        guard !firstAttrs.isEmpty else { return (paths, []) }

        Thread.sleep(forTimeInterval: 0.15)

        let firstMap: [String: (Int64, Date)] = Dictionary(
            uniqueKeysWithValues: firstAttrs.map { ($0.0, ($0.1, $0.2)) }
        )

        var stable: [String] = []
        var unstable: [String] = []

        for path in paths {
            let url = sourceBase.appendingPathComponent(path)
            guard let (size1, mtime1) = firstMap[path],
                  let attrs2 = syncEngine.fileSizeAndModificationDate(at: url),
                  size1 == attrs2.size,
                  abs(mtime1.timeIntervalSince(attrs2.mtime)) < 0.1
            else {
                unstable.append(path)
                continue
            }
            stable.append(path)
        }

        return (stable, unstable)
    }

    private enum SyncMode {
        case copy
        case liveSync
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() -> Int {
            lock.withLock { value += 1; return value }
        }
        var current: Int { lock.withLock { value } }
    }

    private func processBatch(_ paths: [String], mode: SyncMode) {
        let group = DispatchGroup()
        let total = paths.count
        let counter = Counter()

        for relativePath in paths {
            guard !isPaused else { break }

            group.enter()
            ioLimiter.wait()

            ioQueue.async { [weak self] in
                defer {
                    self?.ioLimiter.signal()
                    group.leave()
                }

                guard let self = self else { return }

                let sourceURL = URL(fileURLWithPath: self.config.sourcePath)
                    .appendingPathComponent(relativePath)
                let destURL = URL(fileURLWithPath: self.config.destinationPath)
                    .appendingPathComponent(relativePath)

                if mode == .liveSync && !self.syncEngine.fileExists(at: sourceURL) {
                    self.handleDeletion(destURL: destURL, relativePath: relativePath)
                } else if self.syncEngine.fileExists(at: sourceURL) {
                    self.copyWithRetry(source: sourceURL, dest: destURL, relativePath: relativePath)
                }

                let count = counter.increment()
                if count % 10 == 0 {
                    DispatchQueue.main.async { [weak self] in
                        self?.setState(.syncing(filesProcessed: count, totalFiles: total))
                    }
                }
            }
        }

        group.wait()
    }

    private func processDeletions(_ paths: [String]) {
        for relativePath in paths {
            let destURL = URL(fileURLWithPath: config.destinationPath)
                .appendingPathComponent(relativePath)
            handleDeletion(destURL: destURL, relativePath: relativePath)
        }
    }

    private func handleDeletion(destURL: URL, relativePath: String) {
        guard syncEngine.fileExists(at: destURL) else { return }

        switch config.deletionPolicy {
        case .safeArchive:
            do {
                try safeDelete.archive(fileAt: destURL)
            } catch {
                logEvent(action: "delete_archive_error", path: relativePath, error: error)
            }
        case .exactMirror:
            do {
                try syncEngine.removeItem(at: destURL)
            } catch {
                logEvent(action: "delete_error", path: relativePath, error: error)
            }
        case .never:
            break
        }
    }

    private func copyWithRetry(source: URL, dest: URL, relativePath: String) {
        if !syncEngine.isReadable(at: source) {
            logEvent(action: "skipped_corrupted", path: relativePath)
            return
        }

        var lastError: Error?
        for attempt in 1...3 {
            do {
                try syncEngine.copyFile(from: source, to: dest)
                return
            } catch {
                lastError = error
                if attempt < 3 {
                    Thread.sleep(forTimeInterval: TimeInterval(attempt))
                }
            }
        }
        if let error = lastError {
            logEvent(action: "copy_error", path: relativePath, error: error)
        }
    }

    private func logEvent(action: String, path: String, error: Error? = nil) {
        let actionStr = error != nil ? "\(action): \(error!.localizedDescription)" : action
        let event = SyncEvent(path: path, action: actionStr)
        StateStore.shared.logEvent(event)
    }

    private func setState(_ newState: SyncState) {
        lock.withLock { state = newState }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onStateChange?(self.state)
        }
    }
}
