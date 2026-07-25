import Foundation

public final class ReconcileScanner {
    public let config: MirrorConfig

    public init(config: MirrorConfig) {
        self.config = config
    }

    @discardableResult
    public func scan() throws -> [URL] {
        return []
    }
}
