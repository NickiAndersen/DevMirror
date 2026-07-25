import Foundation

public final class SyncQueue {
    public var onStateChange: ((SyncState) -> Void)?

    public func enqueue(_ paths: [String]) {}
    public func start() {}
    public func stop() {}
    public func pause() {}
    public func resume() {}
}
