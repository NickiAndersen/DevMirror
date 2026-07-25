import Foundation

public final class StateStore: @unchecked Sendable {
    public static let shared = StateStore()

    public func save(config: MirrorConfig) throws {}
    public func loadConfig() -> MirrorConfig { .default }
    public func logEvent(_ event: SyncEvent) {}
    public func loadEvents() -> [SyncEvent] { [] }
    public func lastEventID() -> UInt64? { nil }
    public func saveLastEventID(_ id: UInt64) {}
}
