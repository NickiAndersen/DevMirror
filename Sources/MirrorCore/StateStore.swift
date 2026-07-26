import Foundation

public final class StateStore: @unchecked Sendable {
    public static let shared = StateStore()

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var cachedConfig: MirrorConfig?
    private let maxEvents = 500
    private var loggedCorrupted = Set<String>()
    private let appSupportDir: URL

    public init(appSupportDir: URL? = nil) {
        if let dir = appSupportDir {
            self.appSupportDir = dir
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.appSupportDir = base.appendingPathComponent("DevMirror", isDirectory: true)
        }
    }

    private var configURL: URL {
        appSupportDir.appendingPathComponent("config.json")
    }

    private var eventsURL: URL {
        appSupportDir.appendingPathComponent("events.json")
    }

    private var lastEventIDURL: URL {
        appSupportDir.appendingPathComponent("lastEventID.txt")
    }

    public func save(config: MirrorConfig) throws {
        try lock.withLock {
            cachedConfig = config
            try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL, options: .atomic)
        }
    }

    public func loadConfig() -> MirrorConfig {
        lock.withLock {
            if let cached = cachedConfig { return cached }
            guard let data = try? Data(contentsOf: configURL),
                  let config = try? JSONDecoder().decode(MirrorConfig.self, from: data)
            else {
                return .default
            }
            cachedConfig = config
            return config
        }
    }

    public func logEvent(_ event: SyncEvent) {
        lock.withLock {
            if event.action == "skipped_corrupted" {
                if loggedCorrupted.contains(event.path) { return }
                loggedCorrupted.insert(event.path)
            }
            var events = loadEventsUnsafe()
            events.append(event)
            if events.count > maxEvents {
                events.removeFirst(events.count - maxEvents)
            }
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(events) {
                try? data.write(to: eventsURL, options: .atomic)
            }
        }
    }

    public func clearEvents() {
        lock.withLock {
            try? fileManager.removeItem(at: eventsURL)
        }
    }

    public func loadEvents() -> [SyncEvent] {
        lock.withLock { loadEventsUnsafe() }
    }

    private func loadEventsUnsafe() -> [SyncEvent] {
        guard let data = try? Data(contentsOf: eventsURL),
              let events = try? JSONDecoder().decode([SyncEvent].self, from: data)
        else { return [] }
        return events
    }

    public func lastEventID() -> UInt64? {
        lock.withLock {
            guard let str = try? String(contentsOf: lastEventIDURL, encoding: .utf8),
                  let id = UInt64(str.trimmingCharacters(in: .whitespacesAndNewlines))
            else { return nil }
            return id
        }
    }

    public func saveLastEventID(_ id: UInt64) {
        lock.withLock {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            try? String(id).write(to: lastEventIDURL, atomically: true, encoding: .utf8)
        }
    }
}
