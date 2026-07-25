import Foundation

public final class SyncEngine {
    public let config: MirrorConfig

    public init(config: MirrorConfig) {
        self.config = config
    }

    public func copyFile(from source: URL, to destination: URL) throws {
        let destDir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    public func removeItem(at destination: URL) throws {
        try FileManager.default.removeItem(at: destination)
    }
}
