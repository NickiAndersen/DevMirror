import Foundation

public enum SyncState: Equatable, Hashable, Sendable {
    case idle
    case scanning
    case syncing(filesProcessed: Int, totalFiles: Int)
    case paused
    case error(String)
}

public enum DeletionPolicy: String, CaseIterable, Codable, Hashable, Sendable {
    case safeArchive
    case exactMirror
    case never
}

public enum SyncMode: String, CaseIterable, Codable, Hashable, Sendable {
    case realtime
    case every5min
    case every15min
    case every30min
    case everyHour
    case manual

    public var intervalSeconds: TimeInterval? {
        switch self {
        case .realtime: return nil
        case .every5min: return 300
        case .every15min: return 900
        case .every30min: return 1800
        case .everyHour: return 3600
        case .manual: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .realtime: return "Real-time (instant)"
        case .every5min: return "Every 5 minutes"
        case .every15min: return "Every 15 minutes"
        case .every30min: return "Every 30 minutes"
        case .everyHour: return "Every hour"
        case .manual: return "Manual only"
        }
    }
}

public struct MirrorConfig: Codable, Sendable {
    public var sourcePath: String
    public var destinationPath: String
    public var excludedNames: Set<String>
    public var includeGitFolders: Bool
    public var deletionPolicy: DeletionPolicy
    public var syncMode: SyncMode
    public var trashRetentionDays: Int

    public init(
        sourcePath: String,
        destinationPath: String,
        excludedNames: Set<String>,
        includeGitFolders: Bool,
        deletionPolicy: DeletionPolicy,
        syncMode: SyncMode = .realtime,
        trashRetentionDays: Int
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.excludedNames = excludedNames
        self.includeGitFolders = includeGitFolders
        self.deletionPolicy = deletionPolicy
        self.syncMode = syncMode
        self.trashRetentionDays = trashRetentionDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourcePath = try container.decode(String.self, forKey: .sourcePath)
        destinationPath = try container.decode(String.self, forKey: .destinationPath)
        excludedNames = try container.decode(Set<String>.self, forKey: .excludedNames)
        includeGitFolders = try container.decode(Bool.self, forKey: .includeGitFolders)
        deletionPolicy = try container.decode(DeletionPolicy.self, forKey: .deletionPolicy)
        syncMode = (try? container.decode(SyncMode.self, forKey: .syncMode)) ?? .realtime
        trashRetentionDays = (try? container.decode(Int.self, forKey: .trashRetentionDays)) ?? 30
    }

    public static let `default`: MirrorConfig = {
        let home = NSHomeDirectory()
        return MirrorConfig(
            sourcePath: "\(home)/Developer",
            destinationPath: "\(home)/Documents/DevMirror",
            excludedNames: [
                "node_modules", "build", "Pods", "DerivedData",
                ".dart_tool", ".build", ".gradle", "xcuserdata",
                "Index.noindex", ".next", "dist", "target",
                "__pycache__", ".venv", ".DS_Store", ".swiftpm",
                ".idea",
            ],
            includeGitFolders: true,
            deletionPolicy: .safeArchive,
            syncMode: .every30min,
            trashRetentionDays: 30
        )
    }()
}

public struct SyncEvent: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let path: String
    public let action: String
    public let timestamp: Date

    public init(id: UUID = UUID(), path: String, action: String, timestamp: Date = Date()) {
        self.id = id
        self.path = path
        self.action = action
        self.timestamp = timestamp
    }
}
