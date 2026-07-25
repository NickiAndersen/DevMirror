import Foundation
import CoreServices

public final class FSEventsWatcher: @unchecked Sendable {
    private let sourcePath: String
    private let queue = DispatchQueue(label: "devmirror.fsevents", qos: .utility)
    private var stream: FSEventStreamRef?
    private var isRunning = false
    private var pendingPaths = Set<String>()
    private var debounceWorkItem: DispatchWorkItem?
    private let lock = NSLock()

    public var onEvents: (([String]) -> Void)?
    public var onOverflow: (() -> Void)?
    public var currentEventID: UInt64? {
        guard let stream = stream else { return nil }
        return FSEventStreamGetLatestEventId(stream)
    }

    public init(sourcePath: String) {
        self.sourcePath = sourcePath
    }

    public func start(lastEventID: UInt64 = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)) {
        lock.withLock {
            guard !isRunning else { return }
            isRunning = true
        }

        let paths = [sourcePath] as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (_, clientInfo, numEvents, eventPathsPtr, eventFlags, eventIds) in
            guard let clientInfo = clientInfo else { return }
            let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
            watcher.handleEvents(
                numEvents: numEvents,
                eventPathsPtr: eventPathsPtr,
                eventFlags: eventFlags,
                eventIds: eventIds
            )
        }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )

        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            lastEventID,
            1.0,
            flags
        )

        guard let stream = stream else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        lock.withLock { isRunning = false }
        debounceWorkItem?.cancel()
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    public func flushEvents() {
        queue.sync {
            let paths = lock.withLock {
                let paths = Array(pendingPaths)
                pendingPaths.removeAll()
                return paths
            }
            if !paths.isEmpty {
                onEvents?(paths)
            }
        }
    }

    // MARK: - Private

    private func handleEvents(
        numEvents: Int,
        eventPathsPtr: UnsafeMutableRawPointer,
        eventFlags flagsPtr: UnsafePointer<FSEventStreamEventFlags>?,
        eventIds idsPtr: UnsafePointer<FSEventStreamEventId>?
    ) {
        guard let paths = unsafeBitCast(eventPathsPtr, to: NSArray.self) as? [String] else { return }

        var hasOverflow = false
        for i in 0..<numEvents {
            if let flags = flagsPtr {
                let flag = UInt32(flags[i])
                if (flag & UInt32(kFSEventStreamEventFlagMustScanSubDirs)) != 0 {
                    hasOverflow = true
                }
            }
        }

        if hasOverflow {
            DispatchQueue.main.async { [weak self] in
                self?.onOverflow?()
            }
            return
        }

        lock.withLock {
            for path in paths {
                pendingPaths.insert(path)
            }
        }

        scheduleDebounce()
    }

    private func scheduleDebounce() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPending()
        }
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func flushPending() {
        let paths = lock.withLock {
            let paths = Array(pendingPaths)
            pendingPaths.removeAll()
            return paths
        }
        guard !paths.isEmpty else { return }
        onEvents?(paths)
    }
}
