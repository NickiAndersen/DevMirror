import Foundation

public final class SafeDelete {
    public let destinationPath: String
    public let retentionDays: Int

    public init(destinationPath: String, retentionDays: Int) {
        self.destinationPath = destinationPath
        self.retentionDays = retentionDays
    }

    public func archive(fileAt destination: URL) throws {}
    public func purgeExpired() throws {}
}
