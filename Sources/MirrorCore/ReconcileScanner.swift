import Foundation

public struct ReconcileScanner {
    private let config: MirrorConfig
    private let exclusionEngine: ExclusionEngine
    private let syncEngine: SyncEngine
    private let fileManager = FileManager.default

    public init(config: MirrorConfig, exclusionEngine: ExclusionEngine, syncEngine: SyncEngine) {
        self.config = config
        self.exclusionEngine = exclusionEngine
        self.syncEngine = syncEngine
    }

    public struct ScanResult {
        public let toCopy: [String]
        public let toDelete: [String]

        public var isEmpty: Bool { toCopy.isEmpty && toDelete.isEmpty }
        public var totalChanges: Int { toCopy.count + toDelete.count }
    }

    public func scan() throws -> ScanResult {
        var toCopy: [String] = []
        var toDelete: [String] = []

        let sourceURL = URL(fileURLWithPath: config.sourcePath).standardizedFileURL
        let destURL = URL(fileURLWithPath: config.destinationPath).standardizedFileURL

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw SyncError.notFound(path: config.sourcePath)
        }

        let sourcePrefix = sourceURL.path.hasSuffix("/") ? sourceURL.path : sourceURL.path + "/"

        // Walk source, build set of relative paths, detect changed/new files
        var sourcePaths = Set<String>()
        var enumeratedCount = 0
        if let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [],
            errorHandler: { url, error in
                StateStore.shared.logEvent(SyncEvent(
                    path: url.path,
                    action: "enum_error: \(error.localizedDescription)"
                ))
                return true
            }
        ) {
            for case let url as URL in enumerator {
                enumeratedCount += 1
                if enumeratedCount % 1000 == 0 {
                    StateStore.shared.logEvent(SyncEvent(
                        path: "enumerator at \(enumeratedCount)",
                        action: "scanning"
                    ))
                }
                let normalizedURL = url.standardizedFileURL
                let relativePath = normalizedURL.path.replacingOccurrences(of: sourcePrefix, with: "")

                guard !exclusionEngine.isExcluded(relativePath) else {
                    let isDir = (try? normalizedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir { enumerator.skipDescendants() }
                    continue
                }

                let destFileURL = destURL.appendingPathComponent(relativePath)

                if syncEngine.isDirectory(at: url) {
                    // Create directories as needed — symlinks handled in copy
                    if let isSymlink = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
                       isSymlink {
                        if !syncEngine.filesMatch(source: url, dest: destFileURL) {
                            toCopy.append(relativePath)
                        }
                    }
                    // Regular directories are created implicitly during file copy
                    sourcePaths.insert(relativePath)
                    continue
                }

                sourcePaths.insert(relativePath)

                // Pre-check: skip files that are corrupted/unreadable (e.g. decmpfs failures)
                guard syncEngine.isReadable(at: url) else {
                    StateStore.shared.logEvent(SyncEvent(
                        path: relativePath,
                        action: "skipped_unreadable"
                    ))
                    continue
                }

                if !syncEngine.fileExists(at: destFileURL) {
                    toCopy.append(relativePath)
                } else if !syncEngine.filesMatch(source: url, dest: destFileURL) {
                    toCopy.append(relativePath)
                }
            }
        }

        // Walk destination, find stale files (deleted from source)
        if fileManager.fileExists(atPath: destURL.path) {
            let destPrefix = destURL.path.hasSuffix("/") ? destURL.path : destURL.path + "/"
            if let enumerator = fileManager.enumerator(
                at: destURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [],
                errorHandler: { url, error in
                    StateStore.shared.logEvent(SyncEvent(
                        path: url.path,
                        action: "dest_enum_error: \(error.localizedDescription)"
                    ))
                    return true
                }
            ) {
                for case let url as URL in enumerator {
                    let normalizedURL = url.standardizedFileURL
                    let relativePath = normalizedURL.path.replacingOccurrences(of: destPrefix, with: "")

                    if relativePath.hasPrefix("_DevMirrorTrash") {
                        enumerator.skipDescendants()
                        continue
                    }

                    guard !exclusionEngine.isExcluded(relativePath) else { continue }

                    if !sourcePaths.contains(relativePath) {
                        toDelete.append(relativePath)
                    }
                }
            }
        }

        return ScanResult(toCopy: toCopy, toDelete: toDelete)
    }
}
