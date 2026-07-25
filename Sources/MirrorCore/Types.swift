import Foundation

public enum SyncState: Equatable, Hashable {
    case idle
    case scanning
    case syncing(filesProcessed: Int, totalFiles: Int)
    case paused
    case error(String)
}

public enum DeletionPolicy: String, CaseIterable, Codable, Hashable {
    case safeArchive
    case exactMirror
    case never
}

public struct MirrorConfig: Codable {
    public var sourcePath: String
    public var destinationPath: String
    public var excludedNames: Set<String>
    public var includeGitFolders: Bool
    public var deletionPolicy: DeletionPolicy
    public var trashRetentionDays: Int

    public init(
        sourcePath: String,
        destinationPath: String,
        excludedNames: Set<String>,
        includeGitFolders: Bool,
        deletionPolicy: DeletionPolicy,
        trashRetentionDays: Int
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.excludedNames = excludedNames
        self.includeGitFolders = includeGitFolders
        self.deletionPolicy = deletionPolicy
        self.trashRetentionDays = trashRetentionDays
    }

    public static let `default`: MirrorConfig = {
        let home = NSHomeDirectory()
        return MirrorConfig(
            sourcePath: "\(home)/Developer",
            destinationPath: "\(home)/Documents/DeveloperBackup",
            excludedNames: [
                "node_modules", "build", "Pods", "DerivedData",
                ".dart_tool", ".build", ".gradle", "xcuserdata",
                "Index.noindex", ".next", "dist", "target",
                "__pycache__", ".venv", ".DS_Store", ".swiftpm",
            ],
            includeGitFolders: true,
            deletionPolicy: .safeArchive,
            trashRetentionDays: 30
        )
    }()
}

public struct SyncEvent: Identifiable, Hashable {
    public let id = UUID()
    public let path: String
    public let action: String
    public let timestamp: Date

    public init(path: String, action: String, timestamp: Date = Date()) {
        self.path = path
        self.action = action
        self.timestamp = timestamp
    }
}
