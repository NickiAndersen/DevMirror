import Foundation

public final class FSEventsWatcher {
    public let sourcePath: String
    public var onEvent: (([String]) -> Void)?

    public init(sourcePath: String) {
        self.sourcePath = sourcePath
    }

    public func start() {}
    public func stop() {}
}
